// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HyperChat",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0")
    ],
    targets: [
        .target(
            name: "HyperChat",
            dependencies: ["Sparkle"]
        )
    ]
)