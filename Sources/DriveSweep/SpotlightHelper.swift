import Foundation
import ServiceManagement

/// macOS locks `.Spotlight-V100`; only root can remove it (via `mdutil -X`).
/// The same binary, launched by launchd with `--helper`, runs as a root daemon whose
/// only ability is: run `mdutil -X` on a verified external volume. It never deletes files itself.
@objc protocol SpotlightHelperProtocol {
    func removeSpotlightIndex(atPath path: String, reply: @escaping (Bool, String) -> Void)
}

enum SpotlightHelper {
    static let label = "local.drivesweep.helper"
    static let service = SMAppService.daemon(plistName: "\(label).plist")

    static var isReady: Bool { service.status == .enabled }

    // MARK: Client (app side)

    /// Removes the volume's Spotlight folder via the helper. Returns nil if there was nothing
    /// to remove, true/false for success.
    static func removeIndex(on volume: URL, timeout: TimeInterval = 8) -> Bool? {
        let spotlight = volume.appendingPathComponent(".Spotlight-V100").path
        guard FileManager.default.fileExists(atPath: spotlight) else { return nil }
        guard isReady else { return false }

        let connection = NSXPCConnection(machServiceName: label, options: .privileged)
        connection.remoteObjectInterface = NSXPCInterface(with: SpotlightHelperProtocol.self)
        connection.resume()
        defer { connection.invalidate() }

        let done = DispatchSemaphore(value: 0)
        var ok = false
        let proxy = connection.remoteObjectProxyWithErrorHandler { _ in done.signal() }
        (proxy as? SpotlightHelperProtocol)?.removeSpotlightIndex(atPath: volume.standardizedFileURL.path) { success, _ in
            ok = success
            done.signal()
        }
        _ = done.wait(timeout: .now() + timeout)
        return ok && !FileManager.default.fileExists(atPath: spotlight)
    }

    // MARK: Server (root daemon side)

    static func runDaemon() -> Never {
        let listener = NSXPCListener(machServiceName: label)
        let server = Server()
        listener.delegate = server
        listener.resume()
        RunLoop.main.run()
        exit(0)
    }

    /// Strict check the root side applies before acting: the path must be exactly the mount
    /// point of a local, writable, non-root volume under /Volumes that the app would clean.
    static func isSafeMountPoint(_ path: String) -> Bool {
        guard path.hasPrefix("/Volumes/"), !path.contains("/../"), !path.hasSuffix("/..") else { return false }
        var st = statfs()
        guard statfs(path, &st) == 0 else { return false }
        let mountedOn = withUnsafeBytes(of: &st.f_mntonname) {
            String(cString: $0.bindMemory(to: CChar.self).baseAddress!)
        }
        let flags = UInt32(st.f_flags)
        guard mountedOn == path,
              flags & UInt32(MNT_LOCAL) != 0,
              flags & UInt32(MNT_ROOTFS) == 0,
              flags & UInt32(MNT_RDONLY) == 0
        else { return false }
        return Volumes.isEligible(URL(fileURLWithPath: path))
    }

    private final class Server: NSObject, NSXPCListenerDelegate, SpotlightHelperProtocol {
        func listener(_ listener: NSXPCListener, shouldAcceptNewConnection c: NSXPCConnection) -> Bool {
            c.setCodeSigningRequirement("identifier \"local.drivesweep\"")
            c.exportedInterface = NSXPCInterface(with: SpotlightHelperProtocol.self)
            c.exportedObject = self
            c.resume()
            return true
        }

        func removeSpotlightIndex(atPath path: String, reply: @escaping (Bool, String) -> Void) {
            guard SpotlightHelper.isSafeMountPoint(path) else { return reply(false, "Refused: \(path)") }
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/mdutil")
            p.arguments = ["-X", path]
            p.standardOutput = FileHandle.nullDevice
            p.standardError = FileHandle.nullDevice
            do {
                try p.run()
                p.waitUntilExit()
                reply(p.terminationStatus == 0, "mdutil exit \(p.terminationStatus)")
            } catch {
                reply(false, "\(error)")
            }
        }
    }
}

extension Sweeper {
    /// Everything: Spotlight folder via the helper, then the normal sweep.
    static func fullClean(volume: URL, deadline: Date = .distantFuture) -> SweepResult {
        var result = clean(volume: volume, deadline: deadline)
        switch SpotlightHelper.removeIndex(on: volume) {
        case true?: result.removed += 1
        case false?: result.spotlightLeft = true
        case nil: break
        }
        return result
    }
}
