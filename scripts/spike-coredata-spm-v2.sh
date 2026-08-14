#!/bin/bash
#
# PR2 spike, round 2.
#
# Round 1 established that SwiftPM's native build system does NOT run momc:
# the log said "Copying SpeakLife.xcdatamodeld", so Bundle.module received the
# uncompiled source directory and NSManagedObjectModel had nothing to load.
#
# That rules out the naive `.process(resource)` route. It does not rule out the
# package. Two workarounds keep PR7 intact, and this script tests both:
#
#   VARIANT A — a SwiftPM prebuild plugin that shells out to `xcrun momc` and
#               emits the .momd into the plugin work directory, which SwiftPM
#               then bundles as a resource. Keeps `swift test` as the runner and
#               keeps the .xcdatamodeld as the single source of truth. This is
#               the outcome we want.
#
#   VARIANT B — drive the same package through `xcodebuild` instead of
#               `swift test`. Xcode's build system compiles .xcdatamodeld
#               natively. Still no app bundle, no simulator, no Firebase — just
#               a different command in CI. The consolation prize.
#
# Nothing here touches the repo.
#
# Usage:  ./scripts/spike-coredata-spm-v2.sh

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODEL="$REPO_ROOT/SpeakLife/SpeakLife/Models/SpeakLife.xcdatamodeld"
ENTITIES="$REPO_ROOT/SpeakLife/SpeakLife/Models/CoreData"
ROOT="$(mktemp -d)"

command -v swift >/dev/null || { echo "❌ swift not found — run on a Mac with Xcode"; exit 1; }
[ -d "$MODEL" ] || { echo "❌ model not found at $MODEL"; exit 1; }

echo "▶ Xcode: $(xcodebuild -version 2>/dev/null | head -1)"
echo "▶ momc:  $(xcrun --find momc 2>/dev/null || echo 'NOT FOUND — this alone would explain round 1')"
echo "▶ Root:  $ROOT"
echo

# ── shared sources ───────────────────────────────────────────────────────────
make_common () {
  local pkg="$1"
  mkdir -p "$pkg/Sources/Persist/Resources" "$pkg/Tests/PersistTests"
  cp -R "$MODEL" "$pkg/Sources/Persist/Resources/"
  cp "$ENTITIES/AffirmationEntry+CoreDataClass.swift" \
     "$ENTITIES/AffirmationEntry+CoreDataProperties.swift" "$pkg/Sources/Persist/"

  cat > "$pkg/Sources/Persist/Stack.swift" <<'SWIFT'
import CoreData
import Foundation

public enum Stack {
    /// Dumps what actually landed in the bundle. Round 1 failed blind; this makes
    /// a failure self-explanatory.
    public static func bundleInventory() -> [String] {
        let root = Bundle.module.bundleURL
        let items = (try? FileManager.default.contentsOfDirectory(atPath: root.path)) ?? []
        return items.sorted()
    }

    public static func makeInMemoryContainer() throws -> NSPersistentContainer {
        guard let url = Bundle.module.url(forResource: "SpeakLife", withExtension: "momd")
                     ?? Bundle.module.url(forResource: "SpeakLife", withExtension: "mom"),
              let model = NSManagedObjectModel(contentsOf: url) else {
            throw NSError(domain: "Spike", code: 1, userInfo: [
                NSLocalizedDescriptionKey:
                    "No .momd/.mom in Bundle.module. Contents: \(bundleInventory())"
            ])
        }
        let container = NSPersistentContainer(name: "SpeakLife", managedObjectModel: model)
        let d = NSPersistentStoreDescription()
        d.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [d]
        var loadError: Error?
        container.loadPersistentStores { _, e in loadError = e }
        if let loadError { throw loadError }
        return container
    }
}
SWIFT

  cat > "$pkg/Tests/PersistTests/Tests.swift" <<'SWIFT'
import XCTest
import CoreData
@testable import Persist

final class Tests: XCTestCase {
    func testModelLoads() throws {
        let c = try Stack.makeInMemoryContainer()
        XCTAssertNotNil(c.managedObjectModel.entitiesByName["AffirmationEntry"])
    }

    func testRoundTrip() throws {
        let c = try Stack.makeInMemoryContainer()
        let ctx = c.viewContext
        let e = AffirmationEntry(context: ctx)
        e.id = UUID(); e.text = "I am rooted and unshakeable."; e.category = "faith"
        try ctx.save()
        let r = AffirmationEntry.fetchRequest()
        r.predicate = NSPredicate(format: "category == %@", "faith")
        XCTAssertEqual(try ctx.fetch(r).count, 1)
    }
}
SWIFT
}

# ── VARIANT A: prebuild plugin running momc ──────────────────────────────────
A="$ROOT/VariantA"; make_common "$A"
mkdir -p "$A/Plugins/CompileModel"

cat > "$A/Package.swift" <<'SWIFT'
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Persist",
    platforms: [.macOS(.v13), .iOS(.v17)],
    targets: [
        .target(
            name: "Persist",
            // Excluded, not processed: the plugin owns compiling it. Leaving it as
            // a resource would reproduce round 1 and copy the source directory.
            exclude: ["Resources/SpeakLife.xcdatamodeld"],
            plugins: [.plugin(name: "CompileModel")]
        ),
        .plugin(name: "CompileModel", capability: .buildTool()),
        .testTarget(name: "PersistTests", dependencies: ["Persist"]),
    ]
)
SWIFT

cat > "$A/Plugins/CompileModel/plugin.swift" <<'SWIFT'
import PackagePlugin
import Foundation

@main
struct CompileModel: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        guard let target = target as? SourceModuleTarget else { return [] }

        let input = target.directory.appending(subpath: "Resources/SpeakLife.xcdatamodeld")
        let outDir = context.pluginWorkDirectory.appending(subpath: "CoreDataModels")
        try? FileManager.default.createDirectory(
            atPath: outDir.string, withIntermediateDirectories: true)

        // xcrun rather than context.tool(named:) — momc lives inside Xcode and is
        // not on the plugin's default tool search path.
        return [
            .prebuildCommand(
                displayName: "momc SpeakLife.xcdatamodeld",
                executable: Path("/usr/bin/xcrun"),
                arguments: [
                    "momc",
                    "--sdkroot", "/",
                    input.string,
                    outDir.appending(subpath: "SpeakLife.momd").string,
                ],
                outputFilesDirectory: outDir
            )
        ]
    }
}
SWIFT

echo "═══ VARIANT A — SwiftPM prebuild plugin + momc ═══"
(cd "$A" && swift test 2>&1 | tail -25)
A_STATUS=$?
echo

# ── VARIANT B: same package, driven by xcodebuild ────────────────────────────
B="$ROOT/VariantB"; make_common "$B"
cat > "$B/Package.swift" <<'SWIFT'
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Persist",
    platforms: [.macOS(.v13), .iOS(.v17)],
    targets: [
        .target(name: "Persist", resources: [.process("Resources/SpeakLife.xcdatamodeld")]),
        .testTarget(name: "PersistTests", dependencies: ["Persist"]),
    ]
)
SWIFT

echo "═══ VARIANT B — same package via xcodebuild (macOS) ═══"
(cd "$B" && xcodebuild test -scheme Persist -destination 'platform=macOS' 2>&1 \
  | grep -E "Compiling|Copying|momc|Test Case|error:|BUILD|TEST|failed|passed" | tail -25)
B_STATUS=$?
echo

# ── verdict ──────────────────────────────────────────────────────────────────
echo "───────────────────────────────────────────────"
[ "$A_STATUS" -eq 0 ] \
  && echo "✅ VARIANT A PASS — plugin compiles the model; 'swift test' works. PR7 as written." \
  || echo "❌ VARIANT A FAIL — see output above."
[ "$B_STATUS" -eq 0 ] \
  && echo "✅ VARIANT B PASS — xcodebuild compiles the model; CI runs xcodebuild, still no app/simulator." \
  || echo "❌ VARIANT B FAIL — see output above."
echo
echo "If A passed, take A. If only B passed, PR7 stands but CI uses xcodebuild for the"
echo "persistence target. If both failed, fall back to the reduced simulator job and"
echo "keep SpeakLifeCore on 'swift test' regardless — PR6 was never at risk."
echo
echo "Spike root (delete when done): $ROOT"
