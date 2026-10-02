// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DriveSweep",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "DriveSweep",
            linkerSettings: [.linkedFramework("DiskArbitration")]
        )
    ]
)
