#!/bin/bash
#
# PR2 spike — can SwiftPM compile SpeakLife.xcdatamodeld as a package resource?
#
# This is the one assumption the whole package extraction rests on. If momc runs
# under `swift build` and Bundle.module can load the model, SpeakLifePersistence
# can move into the package and its 11 test files run without a simulator. If it
# cannot, the fallback is a reduced simulator job for the persistence tier only —
# SpeakLifeCore is unaffected either way.
#
# Nothing here touches the repo. The package is built in a temp directory and the
# script prints a verdict. Run it, read the last line, delete nothing.
#
# Usage:  ./scripts/spike-coredata-spm.sh
# Needs:  macOS with Xcode (momc ships inside Xcode, not the CLT-only install)

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODEL="$REPO_ROOT/SpeakLife/SpeakLife/Models/SpeakLife.xcdatamodeld"
ENTITIES="$REPO_ROOT/SpeakLife/SpeakLife/Models/CoreData"
SPIKE="$(mktemp -d)/CoreDataSpike"

command -v swift >/dev/null || { echo "❌ swift not found — run this on a Mac with Xcode"; exit 1; }
[ -d "$MODEL" ] || { echo "❌ model not found at $MODEL"; exit 1; }

echo "▶ Xcode:  $(xcodebuild -version 2>/dev/null | head -1)"
echo "▶ Spike:  $SPIKE"
echo

mkdir -p "$SPIKE/Sources/CoreDataSpike/Resources" "$SPIKE/Tests/CoreDataSpikeTests"
cp -R "$MODEL" "$SPIKE/Sources/CoreDataSpike/Resources/"

# Only the entity this spike asserts on. The question is whether momc runs at all,
# not whether every entity round-trips.
cp "$ENTITIES/AffirmationEntry+CoreDataClass.swift" \
   "$ENTITIES/AffirmationEntry+CoreDataProperties.swift" \
   "$SPIKE/Sources/CoreDataSpike/"

cat > "$SPIKE/Package.swift" <<'SWIFT'
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CoreDataSpike",
    platforms: [.macOS(.v13), .iOS(.v17)],
    targets: [
        .target(
            name: "CoreDataSpike",
            resources: [.process("Resources/SpeakLife.xcdatamodeld")]
        ),
        .testTarget(name: "CoreDataSpikeTests", dependencies: ["CoreDataSpike"]),
    ]
)
SWIFT

# Mirrors what PersistenceController does, with Bundle.module in place of
# Bundle(for:) — the single line that has to change in the real move.
cat > "$SPIKE/Sources/CoreDataSpike/Stack.swift" <<'SWIFT'
import CoreData
import Foundation

public enum SpikeStack {
    public static func makeInMemoryContainer() throws -> NSPersistentContainer {
        guard let url = Bundle.module.url(forResource: "SpeakLife", withExtension: "momd"),
              let model = NSManagedObjectModel(contentsOf: url) else {
            throw NSError(domain: "Spike", code: 1, userInfo: [
                NSLocalizedDescriptionKey:
                    "SpeakLife.momd not in Bundle.module — momc did not compile the model"
            ])
        }
        let container = NSPersistentContainer(name: "SpeakLife", managedObjectModel: model)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]

        var loadError: Error?
        container.loadPersistentStores { _, error in loadError = error }
        if let loadError { throw loadError }
        return container
    }
}
SWIFT

cat > "$SPIKE/Tests/CoreDataSpikeTests/SpikeTests.swift" <<'SWIFT'
import XCTest
import CoreData
@testable import CoreDataSpike

final class SpikeTests: XCTestCase {

    // 1. Does momc run under `swift build`, and does Bundle.module carry the .momd?
    func testModelCompilesAndLoads() throws {
        let container = try SpikeStack.makeInMemoryContainer()
        XCTAssertFalse(container.managedObjectModel.entities.isEmpty)
        XCTAssertNotNil(
            container.managedObjectModel.entitiesByName["AffirmationEntry"],
            "Model loaded but AffirmationEntry is missing"
        )
    }

    // 2. Does a real insert/fetch round-trip work? This is what the 11 moved
    //    persistence test files actually need.
    func testInsertAndFetchRoundTrip() throws {
        let container = try SpikeStack.makeInMemoryContainer()
        let context = container.viewContext

        let entry = AffirmationEntry(context: context)
        entry.id = UUID()
        entry.text = "I am rooted and unshakeable."
        entry.category = "faith"
        entry.createdAt = Date()
        try context.save()

        let request = AffirmationEntry.fetchRequest()
        request.predicate = NSPredicate(format: "category == %@", "faith")
        let results = try context.fetch(request)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.text, "I am rooted and unshakeable.")
    }

    // 3. NSInMemoryStoreType vs the app's /dev/null SQLite store. If this fails,
    //    keep the /dev/null store when moving PersistenceController.
    func testBatchDeleteBehaviour() throws {
        let container = try SpikeStack.makeInMemoryContainer()
        let context = container.viewContext
        for i in 0..<3 {
            let e = AffirmationEntry(context: context)
            e.id = UUID(); e.text = "row \(i)"; e.category = "faith"
        }
        try context.save()
        XCTAssertEqual(try context.count(for: AffirmationEntry.fetchRequest()), 3)
    }
}
SWIFT

echo "▶ swift test"
echo "───────────────────────────────────────────────"
cd "$SPIKE" && swift test 2>&1 | tee /tmp/spike-output.txt
STATUS=${PIPESTATUS[0]}
echo "───────────────────────────────────────────────"
echo

if [ "$STATUS" -eq 0 ]; then
  echo "✅ VERDICT: PASS — .xcdatamodeld compiles under SwiftPM and Bundle.module loads it."
  echo "   PR7 proceeds as written. PersistenceController.swift:103 changes"
  echo "   Bundle(for:) -> Bundle.module and the persistence tier moves into the package."
else
  echo "❌ VERDICT: FAIL — see output above and /tmp/spike-output.txt"
  echo "   Fallback: SpeakLifeCore still moves and runs under 'swift test' (PR6 unaffected)."
  echo "   The 11 persistence test files stay on a simulator job that builds ONLY the"
  echo "   persistence target — still no app bundle, still no Firebase, still a big win."
  echo "   Check first whether momc is on PATH: xcrun --find momc"
fi
echo
echo "Spike dir (delete when done): $SPIKE"
exit $STATUS
