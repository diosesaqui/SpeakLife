// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SpeakLifeKit",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [
        .library(name: "SpeakLifeCore", targets: ["SpeakLifeCore"]),
        .library(name: "SpeakLifePersistence", targets: ["SpeakLifePersistence"]),
    ],
    dependencies: [
        // ZERO remote dependencies. This empty array is enforced by CI.
    ],
    targets: [
        .target(name: "SpeakLifeCore", path: "Sources/SpeakLifeCore"),
        .target(
            name: "SpeakLifePersistence",
            dependencies: ["SpeakLifeCore"],
            path: "Sources/SpeakLifePersistence",
            // The model is `exclude`d, not processed as a resource: SwiftPM's
            // native build system does not run momc on a `.xcdatamodeld` (PR2
            // spike, scripts/spike-coredata-spm-v2.sh). The CompileModel plugin
            // below shells out to `xcrun momc` and drops the compiled `.momd`
            // into the bundle, which is what `Bundle.module` then serves to
            // PersistenceController.managedObjectModel.
            exclude: ["Resources/SpeakLife.xcdatamodeld"],
            plugins: [.plugin(name: "CompileModel")]
        ),
        .plugin(name: "CompileModel", capability: .buildTool()),
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
        .testTarget(
            name: "SpeakLifePersistenceTests",
            dependencies: ["SpeakLifePersistence"],
            path: "Tests/SpeakLifePersistenceTests"
        ),
    ]
)
