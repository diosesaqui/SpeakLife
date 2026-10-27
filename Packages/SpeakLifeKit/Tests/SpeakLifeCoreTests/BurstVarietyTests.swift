//
//  BurstVarietyTests.swift
//  SpeakLifeTests
//
//  A burst should never say the same thing twice. These pin the case that
//  shipped: a campaign anchor on James 4:7 followed, two slats later, by the
//  warfare declaration on James 4:7.
//

import XCTest
@testable import SpeakLifeCore

final class BurstVarietyTests: XCTestCase {

    private func line(_ text: String, _ verse: String, _ scripture: String? = nil) -> BurstDeclaration {
        BurstDeclaration(text: text, verse: verse, scripture: scripture, category: .warfare)
    }

    // MARK: - Scripture references

    func testReferencesOverlapAcrossRangesAndLetteredVerses() {
        func ref(_ raw: String) -> ScriptureReference? { ScriptureReference(raw) }

        XCTAssertTrue(ref("Luke 10:19")!.overlaps(ref("Luke 10:18-19")!))
        XCTAssertTrue(ref("Ruth 2:20")!.overlaps(ref("Ruth 2:20b")!))
        XCTAssertTrue(ref("Psalms 23:1")!.overlaps(ref("Psalm 23:1-3")!))
        XCTAssertTrue(ref("1 Corinthians 13:4")!.overlaps(ref("1 Corinthians 13:4-7")!))
        XCTAssertFalse(ref("Luke 4:18")!.overlaps(ref("Luke 4:19")!))
        XCTAssertFalse(ref("1 John 4:4")!.overlaps(ref("John 4:4")!))
        XCTAssertFalse(ref("Psalm 23:1")!.overlaps(ref("Psalm 24:1")!))
        XCTAssertNil(ref("Jesus"), "a Jesus-voice line is matched on its scripture instead")
        XCTAssertNil(ref(""))
    }

    // MARK: - Closeness

    func testSameVerseIsTooCloseEvenInDifferentWords() {
        let anchor = line("I am submitted to God, so I resist the devil. Enemy, you flee. That is settled.",
                          "James 4:7")
        let warfare = line("Devil, I submit to God and resist you, so flee.", "James 4:7")
        XCTAssertTrue(BurstVariety.isTooClose(anchor, warfare))
    }

    func testJesusVoiceTwinIsTooCloseByItsScripture() {
        let first = line("Jesus' joy is in me, and my joy is complete.", "John 15:11",
                         "I have told you this so that my joy may be in you and that your joy may be complete.")
        let jesus = line("My joy is in you, and your joy is complete.", "Jesus",
                         "I have told you this so that my joy may be in you and that your joy may be complete.")
        XCTAssertTrue(BurstVariety.isTooClose(first, jesus))
    }

    func testNearlySameWordingIsTooClose() {
        let a = line("God has given me authority over every demonic force. I am not fighting for victory. I am advancing from it.",
                     "Luke 10:19")
        let b = line("God has given me authority over every demonic force. I am not fighting for victory. I am fighting from it.",
                     "Mark 16:17")
        XCTAssertTrue(BurstVariety.isTooClose(a, b))
    }

    func testDifferentTruthsOnDifferentVersesAreFine() {
        let a = line("No weapon formed against me prospers.", "Isaiah 54:17")
        let b = line("Greater is He who is in me than he who is in the world.", "1 John 4:4")
        XCTAssertFalse(BurstVariety.isTooClose(a, b))
    }

    // MARK: - Picking

    func testPickSkipsARepeatWhileFresherLinesRemain() {
        let anchor = line("I am submitted to God, so I resist the devil.", "James 4:7")
        let picked = BurstVariety.pick(
            [
                line("Devil, I submit to God and resist you, so flee.", "James 4:7"),
                line("No weapon formed against me prospers.", "Isaiah 54:17"),
                line("Greater is He who is in me than he who is in the world.", "1 John 4:4"),
            ],
            limit: 2,
            alongside: [anchor]
        )
        XCTAssertEqual(picked.map(\.verse), ["Isaiah 54:17", "1 John 4:4"])
    }

    func testPickStillFillsFromRepeatsWhenThePoolIsThin() {
        // A missing slat is worse than a near-repeat, so the burst still fills,
        // and the repeat goes last, as far from its twin as it can get.
        let picked = BurstVariety.pick(
            [
                line("one", "Book 1:1"),
                line("two", "Book 1:1"),
                line("three", "Book 2:1"),
            ],
            limit: 3
        )
        XCTAssertEqual(picked.map(\.text), ["one", "three", "two"])
    }

    func testPickNeverRepeatsExactTextOrBlockedText() {
        let picked = BurstVariety.pick(
            [line("same", "Book 1:1"), line("same", "Book 2:1"), line("blocked", "Book 3:1")],
            limit: 3,
            blockedTexts: ["blocked"]
        )
        XCTAssertEqual(picked.map(\.text), ["same"])
    }

    // MARK: - In a real burst

    func testCampaignFillAvoidsTheAnchorsVerse() {
        let anchorText = "I am submitted to God, so I resist the devil. Enemy, you flee. That is settled."
        let enforcement = Enforcement(
            id: "assembled_warfare",
            title: "Enforcing Victory",
            tagline: "t",
            theme: .warfare,
            days: (1...Enforcement.length).map { n in
                EnforcementDay(
                    dayNumber: n,
                    anchorText: n == 1 ? anchorText : "Anchor \(n)",
                    anchorVerse: n == 1
                        ? "Submit yourselves therefore to God. Resist the devil, and he will flee from you."
                        : "v",
                    anchorBook: n == 1 ? "James 4:7" : "Anchor \(n):\(n)",
                    anchorTranslation: "ESV",
                    audioId: "a.mp3", audioTitle: "A", audioMinutes: 3
                )
            }
        )
        let twin = Declaration(text: "Devil, I submit to God and resist you, so flee.",
                               book: "James 4:7",
                               bibleVerseText: "Submit yourselves, then, to God. Resist the devil, and he will flee from you.",
                               category: .warfare)
        let others = (1...20).map {
            Declaration(text: "warfare line \($0)", book: "Psalm \($0):1", category: .warfare)
        }

        // Every ordering the seeded draw could produce: the twin first, last,
        // and everywhere between.
        for position in 0...others.count {
            var pool = others
            pool.insert(twin, at: position)
            let session = BurstSessionBuilder(shuffle: { $0 }).build(
                enforcement: enforcement, currentDay: 1,
                favorites: [], custom: [], categoryPool: [], selected: nil,
                fullPool: pool
            )
            XCTAssertEqual(session.declarations.count, 7)
            XCTAssertEqual(session.declarations.first?.text, anchorText)
            XCTAssertFalse(session.declarations.contains { $0.text == twin.text },
                           "the James 4:7 twin landed in the same burst as the James 4:7 anchor")
        }
    }

    func testCategoryBurstSpreadsAcrossVerses() {
        let pool = [
            Declaration(text: "I submit to God and the devil flees from me.", book: "James 4:7", category: .warfare),
            Declaration(text: "Devil, I submit to God and resist you, so flee.", book: "James 4:7", category: .warfare),
        ] + (1...6).map {
            Declaration(text: "warfare line \($0)", book: "Psalm \($0):1", category: .warfare)
        }
        let session = BurstSessionBuilder(shuffle: { $0 }).build(
            enforcement: nil, currentDay: 1,
            favorites: [], custom: [], categoryPool: pool, selected: .warfare
        )
        XCTAssertEqual(session.declarations.count, 7)
        XCTAssertEqual(session.declarations.filter { $0.verse == "James 4:7" }.count, 1)
    }
}
