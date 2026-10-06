import Foundation

enum Volumes {
    private static let keys: [URLResourceKey] = [
        .volumeIsLocalKey, .volumeIsInternalKey, .volumeIsRemovableKey,
        .volumeIsReadOnlyKey, .volumeIsRootFileSystemKey, .volumeLocalizedNameKey,
    ]

    /// External drives we're allowed to clean, as currently mounted.
    static func eligible() -> [URL] {
        let mounted = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) ?? []
        let tm = timeMachineMountPoints()
        return mounted.filter { isEligible($0, timeMachine: tm) }
    }

    static func isEligible(_ url: URL, timeMachine: Set<String>? = nil) -> Bool {
        let url = url.standardizedFileURL
        guard url.path.hasPrefix("/Volumes/"),
              let v = try? url.resourceValues(forKeys: Set(keys)),
              v.volumeIsLocal == true,
              v.volumeIsReadOnly != true,
              v.volumeIsRootFileSystem != true,
              // Built-in SD card slots report internal + removable, so allow those.
              v.volumeIsInternal != true || v.volumeIsRemovable == true
        else { return false }

        if FileManager.default.fileExists(atPath: url.appendingPathComponent("Backups.backupdb").path) {
            return false
        }
        return !(timeMachine ?? timeMachineMountPoints()).contains(url.path)
    }

    /// The volume a file or folder lives on.
    static func volume(containing url: URL) -> URL? {
        (try? url.resourceValues(forKeys: [.volumeURLKey]))?.volume?.standardizedFileURL
    }

    /// Stable identity for per-drive settings: the volume UUID (FAT/exFAT have one too).
    static func id(of url: URL) -> String {
        (try? url.resourceValues(forKeys: [.volumeUUIDStringKey]))?.volumeUUIDString ?? "name:\(name(of: url))"
    }

    static func name(of url: URL) -> String {
        (try? url.resourceValues(forKeys: [.volumeLocalizedNameKey]))?.volumeLocalizedName
            ?? url.lastPathComponent
    }

    private static func timeMachineMountPoints() -> Set<String> {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/tmutil")
        p.arguments = ["destinationinfo"]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        guard (try? p.run()) != nil else { return [] }
        let out = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        p.waitUntilExit()
        var points = Set<String>()
        for line in out.split(separator: "\n") where line.hasPrefix("Mount Point") {
            if let r = line.range(of: ": ") {
                points.insert(String(line[r.upperBound...]).trimmingCharacters(in: .whitespaces))
            }
        }
        return points
    }
}
