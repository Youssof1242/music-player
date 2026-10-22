// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Melody",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Melody",
            path: "Sources/Melody"
        )
    ]
)
