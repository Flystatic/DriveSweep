import Foundation

struct SweepResult {
    var removed = 0
    var bytes: Int64 = 0
    var failed = 0
    var timedOut = false

    var summary: String {
        let size = ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
        var s = removed == 0 ? "Already clean" : "Removed \(removed) junk item\(removed == 1 ? "" : "s") (\(size))"
        if failed > 0 { s += ", \(failed) couldn't be removed" }
        if timedOut { s += ", stopped early (time limit)" }
        return s
    }
}

enum Sweeper {
    /// Folders/files removed only when they sit at the top of the volume.
    static let rootJunk: Set<String> = [
        ".Spotlight-V100", ".fseventsd", ".Trashes", ".TemporaryItems",
        ".DocumentRevisions-V100", ".apdisk",
    ]

    /// Files removed anywhere on the volume.
    static func isJunkFile(_ name: String) -> Bool {
        name == ".DS_Store" || name.hasPrefix("._")
    }

    /// Uses fts + unlink rather than FileManager: Foundation hides "._" files from every
    /// listing, so it can neither find them nor empty a folder that contains them.
    static func clean(volume root: URL, deadline: Date = .distantFuture) -> SweepResult {
        var result = SweepResult()
        var argv: [UnsafeMutablePointer<CChar>?] = [strdup(root.standardizedFileURL.path), nil]
        defer { free(argv[0]) }
        guard let fts = fts_open(&argv, FTS_PHYSICAL | FTS_NOCHDIR | FTS_XDEV, nil) else { return result }
        defer { fts_close(fts) }

        var junkDir: String?  // root-level junk folder currently being emptied

        while let entry = fts_read(fts) {
            if Date() > deadline { result.timedOut = true; break }
            let e = entry.pointee
            let info = Int32(e.fts_info)
            let path = String(cString: e.fts_path)
            let name = (path as NSString).lastPathComponent
            let size = Int64(e.fts_statp?.pointee.st_blocks ?? 0) * 512

            if let dir = junkDir {
                if info == FTS_DP {
                    let ok = rmdir(path) == 0
                    if path == dir {
                        if ok { result.removed += 1 } else { result.failed += 1 }
                        junkDir = nil
                    }
                } else if info != FTS_D, unlink(path) == 0 {
                    result.bytes += size
                }
                continue
            }

            if e.fts_level == 1, rootJunk.contains(name) {
                if info == FTS_D {
                    junkDir = path
                } else {
                    delete(path, size, &result)
                }
                continue
            }

            if info == FTS_F, isJunkFile(name) {
                delete(path, size, &result)
            }
        }
        return result
    }

    private static func delete(_ path: String, _ size: Int64, _ result: inout SweepResult) {
        if unlink(path) == 0 {
            result.removed += 1
            result.bytes += size
        } else if errno != ENOENT {  // ENOENT: "._x" already went away with its partner file
            result.failed += 1
        }
    }
}
