// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Ejectus",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Ejectus",
            linkerSettings: [.linkedFramework("DiskArbitration")]
        )
    ]
)
