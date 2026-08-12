// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SpeakLifeKit",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [
        .library(name: "SpeakLifeCore", targets: ["SpeakLifeCore"]),
    ],
    dependencies: [
        // ZERO remote dependencies. This empty array is enforced by CI.
    ],
    targets: [
        .target(name: "SpeakLifeCore", path: "Sources/SpeakLifeCore"),
        .testTarget(
            name: "SpeakLifeCoreTests",
            dependencies: ["SpeakLifeCore"],
            path: "Tests/SpeakLifeCoreTests",
            resources: [
                // Mirrored from the app's Preview Content bundle so the assembler
                // and devotional decoders can decode the real shipped content
                // under `swift test` (no simulator, no app bundle).
                .process("Resources"),
            ]
        ),
    ]
)
