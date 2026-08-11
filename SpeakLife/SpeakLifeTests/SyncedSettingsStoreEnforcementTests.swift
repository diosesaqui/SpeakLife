//
//  SyncedSettingsStoreEnforcementTests.swift
//  SpeakLifeTests
//
//  The campaign-merge rules that keep two devices on the same seven lines.
//
//  These are the hardest rules in the app to notice breaking. Nothing crashes
//  and nothing logs: two devices simply pick different campaigns and each keeps
//  pushing its own answer back, so the user speaks a different day-three anchor
//  on their phone than on their iPad, all week. The only place that can be
//  caught is here.
//
//  `enforcementFingerprint` in particular is a deterministic tiebreak over the
//  bytes two devices actually stored. Any change to what goes into it — even a
//  change that looks like a pure refactor, such as the theme becoming a
//  `DeclarationCategory` — has to leave the string byte-identical, or a device
//  on the new build stops agreeing with one still on the old.
//

import XCTest
@testable import SpeakLife

final class SyncedSettingsStoreEnforcementTests: XCTestCase {

    private let separator = "\u{1}"

    private func day(_ n: Int, anchor: String = "Anchor", audio: String = "a.mp3") -> EnforcementDay {
        EnforcementDay(dayNumber: n, anchorText: "\(anchor) \(n)", anchorVerse: "v",
                       anchorBook: "Book \(n):\(n)", anchorTranslation: "ESV",
                       audioId: audio, audioTitle: "A", audioMinutes: 3)
    }

    private func campaign(
        id: String = "curated_test",
        title: String = "Enforcing Peace",
        theme: DeclarationCategory = .anxiety,
        days: [EnforcementDay] = []
    ) -> Enforcement {
        Enforcement(id: id, title: title, tagline: "t", theme: theme, days: days)
    }

    private func progress(_ enforcement: Enforcement, startedDaysAgo: Int = 1) -> EnforcementProgress {
        var p = EnforcementProgress()
        p.activeEnforcementId = enforcement.id
        p.assembledEnforcement = enforcement
        p.startedOn = Calendar.current.date(byAdding: .day, value: -startedDaysAgo, to: Date())
        return p
    }

    // MARK: - The fingerprint is the bytes on disk

    func testFingerprintIsExactlyTheStoredBytes() {
        // Pinned literally. If this test has to be updated, the change is not a
        // refactor: it is a wire-format change that splits devices across builds.
        let enforcement = campaign(id: "curated_anxiety", title: "Enforcing Peace",
                                   theme: .anxiety, days: [day(1)])
        let expected = [
            "curated_anxiety", "Enforcing Peace", "anxiety",
            "1\(separator)Anchor 1\(separator)a.mp3"
        ].joined(separator: separator)

        XCTAssertEqual(SyncedSettingsStore.enforcementFingerprint(enforcement), expected)
    }

    func testFingerprintUsesTheRawThemeNotTheDisplayName() {
        // The upgrade hazard introduced by typing `theme`. `.name` is a browse
        // label and was never what was written to disk.
        let fingerprint = SyncedSettingsStore.enforcementFingerprint(campaign(theme: .anxiety))
        XCTAssertTrue(fingerprint.contains("anxiety"))
        XCTAssertFalse(fingerprint.contains("Anxiety & Worry"),
                       "the display name reached the fingerprint")
    }

    func testFingerprintUsesTheStoredTitleNotTheDerivedOne() {
        // A generated campaign persisted before the naming fix carries the old
        // title. `displayTitle` re-derives it, which would make the fingerprint
        // depend on app version.
        let stale = campaign(id: "assembled_warfare", title: "Enforcing Warfare & Victory",
                             theme: .warfare)
        XCTAssertEqual(stale.displayTitle, "Enforcing Victory", "precondition")

        let fingerprint = SyncedSettingsStore.enforcementFingerprint(stale)
        XCTAssertTrue(fingerprint.contains("Enforcing Warfare & Victory"))
    }

    func testFingerprintOfACampaignWrittenByAnOlderBuildIsUnchanged() {
        // The actual upgrade question: a campaign already sitting in iCloud, in
        // the format the old build wrote, must fingerprint to the same string
        // once the new build decodes it.
        let legacyJSON = """
        {"id":"curated_anxiety","title":"Enforcing Peace","tagline":"t","theme":"anxiety",
         "days":[{"dayNumber":1,"anchorText":"Anchor 1","anchorVerse":"v","anchorBook":"Book 1:1",
                  "anchorTranslation":"ESV","audioId":"a.mp3","audioTitle":"A","audioMinutes":3}]}
        """.data(using: .utf8)!

        let decoded = try! JSONDecoder().decode(Enforcement.self, from: legacyJSON)
        let expected = [
            "curated_anxiety", "Enforcing Peace", "anxiety",
            "1\(separator)Anchor 1\(separator)a.mp3"
        ].joined(separator: separator)

        XCTAssertEqual(SyncedSettingsStore.enforcementFingerprint(decoded), expected)
    }

    // MARK: - The merge is commutative

    func testTwoDevicesCollidingOnOneIdPickTheSameCampaign() {
        // A curated id is only "curated_" + theme, so two devices that each
        // curated a week collide under one id with different content.
        let mine = progress(campaign(days: [day(1, anchor: "Mine")]))
        let theirs = progress(campaign(days: [day(1, anchor: "Theirs")]))

        let fromThisDevice = SyncedSettingsStore.mergedEnforcementProgress(mine, theirs)
        let fromTheOther = SyncedSettingsStore.mergedEnforcementProgress(theirs, mine)

        XCTAssertEqual(fromThisDevice.assembledEnforcement, fromTheOther.assembledEnforcement,
                       "the two devices chose different campaigns and will never converge")
        XCTAssertNotNil(fromThisDevice.assembledEnforcement)
    }

    func testCollisionIsBrokenByTheRawThemeNotTheDisplayName() {
        // A discriminating pair: by rawValue "parenting" < "rest", but by display
        // name "Peace & Rest" < "Raising children". The two orderings disagree,
        // so this fails if the display name ever reaches the fingerprint.
        XCTAssertLessThan(DeclarationCategory.parenting.rawValue, DeclarationCategory.rest.rawValue)
        XCTAssertLessThan(DeclarationCategory.rest.name, DeclarationCategory.parenting.name)

        let parenting = campaign(theme: .parenting)
        let rest = campaign(theme: .rest)
        let merged = SyncedSettingsStore.mergedEnforcementProgress(
            progress(rest), progress(parenting)
        )

        XCTAssertEqual(merged.assembledEnforcement?.theme, .parenting,
                       "tiebreak did not run on the raw theme")
    }

    func testCollisionIsBrokenByTheStoredTitleNotTheDerivedOne() {
        // By stored title "Alpha" < "Zebra", but by displayTitle
        // "Enforcing Peace" < "Enforcing Victory" — the orderings disagree.
        let zebra = campaign(id: "assembled_x", title: "Zebra", theme: .anxiety)
        let alpha = campaign(id: "assembled_x", title: "Alpha", theme: .warfare)
        XCTAssertEqual(zebra.displayTitle, "Enforcing Peace", "precondition")
        XCTAssertEqual(alpha.displayTitle, "Enforcing Victory", "precondition")

        let merged = SyncedSettingsStore.mergedEnforcementProgress(
            progress(zebra), progress(alpha)
        )
        XCTAssertEqual(merged.assembledEnforcement?.title, "Alpha",
                       "tiebreak did not run on the stored title")
    }

    func testIdenticalCampaignsSurviveTheMergeUntouched() {
        let same = campaign(days: [day(1), day(2)])
        let merged = SyncedSettingsStore.mergedEnforcementProgress(
            progress(same), progress(same)
        )
        XCTAssertEqual(merged.assembledEnforcement, same)
    }

    func testACampaignOnlyOneDeviceHasStillTravels() {
        // The blob has to move with its campaign: a curated id is not in
        // enforcements.json, so a campaign arriving without it cannot be
        // resolved and the user's week silently disappears.
        let onlyMine = progress(campaign(days: [day(1)]))
        let empty = EnforcementProgress()

        for merged in [SyncedSettingsStore.mergedEnforcementProgress(onlyMine, empty),
                       SyncedSettingsStore.mergedEnforcementProgress(empty, onlyMine)] {
            XCTAssertEqual(merged.activeEnforcementId, "curated_test")
            XCTAssertNotNil(merged.assembledEnforcement,
                            "the campaign crossed without its blob and cannot be resolved")
        }
    }

    func testDaysBankedOnEitherDeviceAreBankedOnBoth() {
        var mine = progress(campaign())
        mine.completedDayNumbers = [1, 2]
        var theirs = progress(campaign())
        theirs.completedDayNumbers = [3]

        let merged = SyncedSettingsStore.mergedEnforcementProgress(mine, theirs)
        XCTAssertEqual(merged.completedDayNumbers, [1, 2, 3])
    }
}
