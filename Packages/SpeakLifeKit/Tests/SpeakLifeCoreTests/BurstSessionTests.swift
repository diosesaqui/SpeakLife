//
//  BurstSessionTests.swift
//  SpeakLifeTests
//
//  Burst composition and theme resolution. This is the policy that used to live
//  inside a SwiftUI view, where the only way to test it was to render five
//  environment objects and read private state — so in practice it was not
//  tested at all, and the theme silently disagreed with the declarations.
//

import XCTest
@testable import SpeakLifeCore

final class BurstSessionTests: XCTestCase {

    // MARK: - Helpers

    private func declaration(_ text: String, _ category: DeclarationCategory) -> Declaration {
        Declaration(text: text, book: "Book 1:1", category: category)
    }

    private func enforcement(
        theme: DeclarationCategory,
        id: String = "assembled_test",
        days: Int = Enforcement.length
    ) -> Enforcement {
        Enforcement(
            id: id,
            title: "Enforcing Test",
            tagline: "t",
            theme: theme,
            days: (1...max(days, 1)).prefix(days).map { n in
                EnforcementDay(dayNumber: n, anchorText: "Anchor \(n)", anchorVerse: "v",
                               anchorBook: "Book \(n):\(n)", anchorTranslation: "ESV",
                               audioId: "a.mp3", audioTitle: "A", audioMinutes: 3)
            }
        )
    }

    /// Pins the draw so pool tests assert on selection, not on luck.
    private func builder(count: Int = 7) -> BurstSessionBuilder {
        BurstSessionBuilder(declarationCount: count, shuffle: { $0 })
    }

    // MARK: - Campaign ownership

    func testActiveCampaignOwnsTheBurst() {
        let session = builder().build(
            enforcement: enforcement(theme: .health),
            currentDay: 3,
            favorites: [declaration("fav", .wealth)],
            custom: [],
            categoryPool: [declaration("pool", .wealth)],
            selected: .wealth
        )

        XCTAssertEqual(session.origin, .enforcement(.health))
        XCTAssertEqual(session.theme, .health)
        XCTAssertEqual(session.declarations.count, 7)
        // Not one line from the pool, even though the pool had plenty.
        XCTAssertTrue(session.declarations.allSatisfy { $0.category == .health })
        XCTAssertTrue(session.declarations.allSatisfy { $0.text.hasPrefix("Anchor") })
    }

    func testTodaysAnchorLeadsTheCampaignBurst() {
        let session = builder().build(
            enforcement: enforcement(theme: .anxiety), currentDay: 5,
            favorites: [], custom: [], categoryPool: [], selected: nil
        )
        XCTAssertEqual(session.declarations.first?.text, "Anchor 5")
        // The rest of the week fills in behind it. Asserted as a set, not a
        // sequence: the comparator only guarantees that today sorts first.
        XCTAssertEqual(Set(session.declarations.dropFirst().map(\.text)),
                       ["Anchor 1", "Anchor 2", "Anchor 3", "Anchor 4", "Anchor 6", "Anchor 7"])
    }

    func testCampaignDeclarationsCarryBothTheEnumAndTheLabel() {
        // The whole point of the rework: the label is a browse string that does
        // not parse back into a category, so the enum has to travel with it.
        let session = builder().build(
            enforcement: enforcement(theme: .warfare), currentDay: 1,
            favorites: [], custom: [], categoryPool: [], selected: nil
        )
        XCTAssertEqual(session.declarations.first?.category, .warfare)
        XCTAssertEqual(session.declarations.first?.categoryLabel, "Warfare & Victory")
        XCTAssertNil(DeclarationCategory("Warfare & Victory"),
                     "if this ever parses, the label/enum split is no longer load-bearing")
    }

    func testShortCampaignFallsBackToThePoolAndDoesNotClaimTheTheme() {
        // A campaign is always seven days. If one ever is not, the burst must not
        // claim a theme whose words it never spoke.
        let session = builder().build(
            enforcement: enforcement(theme: .health, days: 3),
            currentDay: 1,
            favorites: [],
            custom: [],
            categoryPool: (1...7).map { declaration("pool \($0)", .wealth) },
            selected: .wealth
        )

        XCTAssertEqual(session.origin, .pool)
        XCTAssertEqual(session.theme, .wealth)
        XCTAssertEqual(session.declarations.count, 7)
        XCTAssertFalse(session.declarations.contains { $0.text.hasPrefix("Anchor") })
    }

    func testNoCampaignDrawsFromThePool() {
        let session = builder().build(
            enforcement: nil, currentDay: 1,
            favorites: [], custom: [],
            categoryPool: (1...7).map { declaration("pool \($0)", .joy) },
            selected: .joy
        )
        XCTAssertEqual(session.origin, .pool)
        XCTAssertEqual(session.theme, .joy)
    }

    // MARK: - Pool composition

    func testFavoritesAndCustomAreWeightedAheadOfTheCategory() {
        // With the shuffle pinned, weighting shows up as ordering: favorites are
        // appended first, then the user's own, then the selected category.
        let session = builder().build(
            enforcement: nil, currentDay: 1,
            favorites: [declaration("favorite", .rest)],
            custom: [declaration("mine", .destiny)],
            categoryPool: (1...7).map { declaration("pool \($0)", .joy) },
            selected: .joy
        )
        XCTAssertEqual(session.declarations.first?.text, "favorite")
        XCTAssertEqual(session.declarations.dropFirst().first?.text, "mine")
    }

    func testWeightedDuplicatesAreNotSpokenTwice() {
        // Favorites go into the pool twice and custom three times. Weighting is
        // meant to change the odds, never to repeat a line inside one burst.
        let session = builder().build(
            enforcement: nil, currentDay: 1,
            favorites: [declaration("favorite", .rest)],
            custom: [declaration("mine", .destiny)],
            categoryPool: (1...7).map { declaration("pool \($0)", .joy) },
            selected: .joy
        )
        let texts = session.declarations.map(\.text)
        XCTAssertEqual(Set(texts).count, texts.count, "a declaration was repeated: \(texts)")
    }

    func testPoolIsToppedUpWhenItCannotFillTheBurst() {
        let session = builder().build(
            enforcement: nil, currentDay: 1,
            favorites: [], custom: [],
            categoryPool: [declaration("only one", .joy)],
            selected: .joy
        )
        XCTAssertEqual(session.origin, .fallback)
        XCTAssertEqual(session.declarations.count, 7)
        XCTAssertEqual(session.declarations.first?.text, "only one")
    }

    func testEmptyEverythingStillProducesAFullBurst() {
        let session = builder().build(
            enforcement: nil, currentDay: 1,
            favorites: [], custom: [], categoryPool: [], selected: nil
        )
        XCTAssertEqual(session.declarations.count, 7)
        XCTAssertEqual(session.origin, .fallback)
        XCTAssertFalse(session.declarations.contains { $0.text.isEmpty })
        XCTAssertTrue(session.declarations.allSatisfy { !$0.categoryLabel.isEmpty })
    }

    func testThemeComesFromWhatWasSpokenNotWhatWasSelected() {
        // The pool is mostly marriage even though wealth is selected. The action
        // must follow the mouth.
        let session = builder().build(
            enforcement: nil, currentDay: 1,
            favorites: [], custom: [],
            categoryPool: (1...7).map { declaration("m\($0)", .marriage) },
            selected: .wealth
        )
        XCTAssertEqual(session.theme, .marriage)
    }

    // MARK: - Theme resolution

    func testEnforcementThemeWinsOverEverythingElse() {
        let theme = BurstThemeResolver.resolve(
            enforcement: .health, spoken: [.wealth, .wealth, .wealth], selected: .warfare
        )
        XCTAssertEqual(theme, .health)
    }

    func testDominantSpokenCategoryWinsOverSelectedCategory() {
        let theme = BurstThemeResolver.resolve(
            enforcement: nil, spoken: [.marriage, .marriage, .joy], selected: .wealth
        )
        XCTAssertEqual(theme, .marriage)
    }

    func testTiesBreakOnFirstAppearance() {
        // Dictionary iteration order is not stable, so a tie must not be able to
        // hand the same burst a different theme on a re-render.
        let spoken: [DeclarationCategory] = [.fear, .joy, .fear, .joy]
        for _ in 0..<25 {
            XCTAssertEqual(
                BurstThemeResolver.resolve(enforcement: nil, spoken: spoken, selected: nil), .fear
            )
        }
    }

    func testContainerCategoriesNeverWinTheme() {
        let theme = BurstThemeResolver.resolve(
            enforcement: nil,
            spoken: [.favorites, .favorites, .myOwn, .general, .anxiety],
            selected: nil
        )
        XCTAssertEqual(theme, .anxiety)
    }

    func testBibleBookCategoriesNeverWinTheme() {
        // "Read Romans" is not a corresponding action — it is the thing they were
        // already doing.
        let theme = BurstThemeResolver.resolve(
            enforcement: nil, spoken: [.romans, .psalms, .john], selected: .work
        )
        XCTAssertEqual(theme, .work)
    }

    func testBookEnforcementDoesNotHijackTheme() {
        let theme = BurstThemeResolver.resolve(
            enforcement: .psalms, spoken: [.grief, .grief], selected: nil
        )
        XCTAssertEqual(theme, .grief)
    }

    func testFallsBackToFaithWhenNothingIsActionable() {
        let theme = BurstThemeResolver.resolve(
            enforcement: nil, spoken: [.psalms, .favorites], selected: .general
        )
        XCTAssertEqual(theme, .faith)
    }

    func testEmptyBurstStillResolves() {
        XCTAssertEqual(
            BurstThemeResolver.resolve(enforcement: nil, spoken: [], selected: nil), .faith
        )
    }

    // MARK: - Enforcement theme is typed end to end

    func testEnforcementThemeSurvivesAPersistenceRoundTrip() {
        // Campaigns are persisted whole into UserDefaults and iCloud. The wire
        // format must stay the string it has always been, or in-flight weeks stop
        // decoding on upgrade.
        let original = enforcement(theme: .marriage, id: "assembled_marriage")
        let data = try! JSONEncoder().encode(original)

        let json = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(json["theme"] as? String, "marriage", "wire format changed")

        let decoded = try! JSONDecoder().decode(Enforcement.self, from: data)
        XCTAssertEqual(decoded.theme, .marriage)
        XCTAssertEqual(decoded, original)
    }

    func testUnknownThemeDecodesToFaithRatherThanFailing() {
        // A content typo, or a category renamed out from under a campaign already
        // on disk, must not take the catalog or someone's week down with it.
        let json = """
        {"id":"assembled_typo","title":"T","tagline":"t","theme":"nonsense","days":[]}
        """.data(using: .utf8)!

        let decoded = try? JSONDecoder().decode(Enforcement.self, from: json)
        XCTAssertNotNil(decoded, "an unknown theme must not fail the decode")
        XCTAssertEqual(decoded?.theme, .faith)
    }

    func testThemeNameIsTheBrowseLabelAndDisplayTitleIsTheVictory() {
        let campaign = enforcement(theme: .anxiety, id: "assembled_anxiety")
        XCTAssertEqual(campaign.themeName, "Anxiety & Worry")
        XCTAssertEqual(campaign.displayTitle, "Enforcing Peace")
    }
}
