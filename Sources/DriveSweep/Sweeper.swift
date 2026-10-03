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
    ///
    /// Every entry is judged on its own path — no "currently deleting" state. (An earlier
    /// version tracked state and, when a junk folder couldn't be read, never left
    /// delete mode and wiped the rest of the drive.)
    static func clean(volume root: URL, deadline: Date = .distantFuture) -> SweepResult {
        var result = SweepResult()
        let rootPath = root.standardizedFileURL.path
        let junkRoots = rootJunk.map { (rootPath as NSString).appendingPathComponent($0) }

        var argv: [UnsafeMutablePointer<CChar>?] = [strdup(rootPath), nil]
        defer { free(argv[0]) }
        guard let fts = fts_open(&argv, FTS_PHYSICAL | FTS_NOCHDIR | FTS_XDEV, nil) else { return result }
        defer { fts_close(fts) }

        while let entry = fts_read(fts) {
            if Date() > deadline { result.timedOut = true; break }
            let e = entry.pointee
            let info = Int32(e.fts_info)
            let path = String(cString: e.fts_path)
            let isTopLevel = e.fts_level == 1
            let size = Int64(e.fts_statp?.pointee.st_blocks ?? 0) * 512

            if junkRoots.contains(where: { path == $0 || path.hasPrefix($0 + "/") }) {
                switch info {
                case FTS_D:
                    break  // handled on the post-order (FTS_DP) visit, once emptied
                case FTS_DP:
                    let ok = rmdir(path) == 0
                    if isTopLevel { if ok { result.removed += 1 } else { result.failed += 1 } }
                case FTS_DNR, FTS_ERR, FTS_NS:
                    if isTopLevel { result.failed += 1 }
                default:
                    let ok = unlink(path) == 0
                    if ok { result.bytes += size }
                    if isTopLevel { if ok { result.removed += 1 } else { result.failed += 1 } }
                }
            } else if info == FTS_F, isJunkFile((path as NSString).lastPathComponent) {
                if unlink(path) == 0 {
                    result.removed += 1
                    result.bytes += size
                } else if errno != ENOENT {  // ENOENT: "._x" already went away with its partner file
                    result.failed += 1
                }
            }
        }
        return result
    }
}
