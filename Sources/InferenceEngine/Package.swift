// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "InferenceEngine",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "InferenceEngine",
            targets: ["InferenceEngine"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "CMistral", // We are keeping this name for now
            dependencies: [],
            path: "Sources/CMistral",
            linkerSettings: [
                // Link against the llama static library
                .linkedLibrary("llama"),
                // Specify the search path for the library, relative to the target's source directory
                .unsafeFlags(["-L", "Sources/CMistral"]),
                // Link against the system frameworks llama.cpp requires
                .linkedFramework("Accelerate"),
                .linkedFramework("Foundation"),
                .linkedLibrary("c++"),
            ]
        ),
        
        // This is our main Swift target. It depends on the C library.
        .target(
            name: "InferenceEngine",
            dependencies: ["CMistral"]),
    ]
)