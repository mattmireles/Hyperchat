// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Hyperchat",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Hyperchat", targets: ["Hyperchat"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0")
    ],
    targets: [
        .executableTarget(
            name: "Hyperchat",
            dependencies: ["Sparkle"],
            resources: [
                .process("Assets.xcassets"),
                .process("Orbitron-Bold.ttf")
            ]
        ),
        .testTarget(
            name: "HyperchatTests",
            dependencies: ["Hyperchat"]
        ),
        .testTarget(
            name: "HyperchatUITests",
            dependencies: ["Hyperchat"]
        )
    ]
)