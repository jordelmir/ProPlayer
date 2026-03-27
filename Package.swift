// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ProPlayer",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "ProPlayerEngine", targets: ["ProPlayerEngine"]),
        .executable(name: "ProPlayer", targets: ["ProPlayer"]),
        .executable(name: "player-cli", targets: ["PlayerCLI"])
    ],
    targets: [
        .target(
            name: "ProPlayerEngine",
            path: "Sources/ProPlayer/Engine",
            resources: [
                .process("Renderer/Shaders.metal")
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .executableTarget(
            name: "ProPlayer",
            dependencies: ["ProPlayerEngine"],
            path: "Sources/ProPlayer",
            exclude: ["Engine"],
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .executableTarget(
            name: "PlayerCLI",
            dependencies: ["ProPlayerEngine"],
            path: "Sources/PlayerCLI",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        )
    ]
)
