// swift-tools-version: 5.9
import PackageDescription

let ciSettings: [SwiftSetting] = Context.environment["CI"] != nil ? [.unsafeFlags(["-gnone"])] : []

let package = Package(
    name: "ElysiumVanguardProPlayer8K",
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
            path: "Sources/ProPlayerEngine",
            resources: [
                .process("Renderer/Shaders.metal")
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ] + ciSettings
        ),
        .executableTarget(
            name: "ProPlayer",
            dependencies: ["ProPlayerEngine"],
            path: "Sources/ProPlayer",
            exclude: ["export_app.sh"],
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ] + ciSettings
        ),
        .executableTarget(
            name: "PlayerCLI",
            dependencies: ["ProPlayerEngine"],
            path: "Sources/PlayerCLI",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ] + ciSettings
        )
    ]
)
