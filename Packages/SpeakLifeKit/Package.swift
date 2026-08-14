// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SpeakLifeKit",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [
        .library(name: "SpeakLifeCore", targets: ["SpeakLifeCore"]),
        .library(name: "SpeakLifePersistence", targets: ["SpeakLifePersistence"]),
        .library(name: "SpeakLifeServices", targets: ["SpeakLifeServices"]),
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
        .target(
            name: "SpeakLifeServices",
            dependencies: ["SpeakLifeCore", "SpeakLifePersistence"],
            path: "Sources/SpeakLifeServices"
        ),
        .plugin(name: "CompileModel", capability: .buildTool()),
        // Waiting helpers shared by all three test targets. A plain target
        // rather than a test target, because a test target cannot be a
        // dependency of another test target. Only test targets depend on it,
        // so its `import XCTest` never reaches the app.
        .target(name: "SpeakLifeTestSupport", path: "Sources/SpeakLifeTestSupport"),
        .testTarget(
            name: "SpeakLifeCoreTests",
            dependencies: ["SpeakLifeCore", "SpeakLifeTestSupport"],
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
            dependencies: ["SpeakLifePersistence", "SpeakLifeTestSupport"],
            path: "Tests/SpeakLifePersistenceTests"
        ),
        .testTarget(
            name: "SpeakLifeServicesTests",
            dependencies: ["SpeakLifeServices", "SpeakLifeTestSupport"],
            path: "Tests/SpeakLifeServicesTests"
        ),
    ]
)
