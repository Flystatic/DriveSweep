import Foundation
let p = "/Volumes/DSPROBE"
print("url enum:", (FileManager.default.enumerator(at: URL(fileURLWithPath: p), includingPropertiesForKeys: nil)?.allObjects as! [URL]).map{$0.lastPathComponent})
print("path enum:", FileManager.default.enumerator(atPath: p)!.allObjects)
print("contents:", try! FileManager.default.contentsOfDirectory(atPath: p + "/A"))
