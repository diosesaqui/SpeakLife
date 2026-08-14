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

    /// A category deep enough to feed a whole week of six-a-day, like the
    /// twenty-eight real categories that carry 45 to 95 referenced lines.
    private func deepPool(_ category: DeclarationCategory, count: Int = 60) -> [Declaration] {
        (1...count).map { declaration("\(category.rawValue) line \($0)", category) }
    }

    // MARK: - Campaign ownership

    func testActiveCampaignOwnsTheBurst() {
        let session = builder().build(
            enforcement: enforcement(theme: .health),
            currentDay: 3,
            favorites: [declaration("fav", .wealth)],
            custom: [],
            categoryPool: [declaration("pool", .wealth)],
            selected: .wealth,
            fullPool: deepPool(.health)
        )

        XCTAssertEqual(session.origin, .enforcement(.health))
        XCTAssertEqual(session.theme, .health)
        XCTAssertEqual(session.declarations.count, 7)
        // Not one line from the browsed category, even though it had plenty:
        // a campaign fills from its own theme, not from what is on screen.
        XCTAssertTrue(session.declarations.allSatisfy { $0.category == .health })
        XCTAssertFalse(session.declarations.contains { $0.text == "pool" || $0.text == "fav" })
    }

    func testTodaysAnchorLeadsAndSixFreshLinesFollow() {
        let session = builder().build(
            enforcement: enforcement(theme: .anxiety), currentDay: 5,
            favorites: [], custom: [], categoryPool: [], selected: nil,
            fullPool: deepPool(.anxiety)
        )
        XCTAssertEqual(session.declarations.first?.text, "Anchor 5")
        // The other six are drawn from the theme, not seated from the week.
        XCTAssertEqual(session.declarations.count, 7)
        XCTAssertFalse(session.declarations.dropFirst().contains { $0.text.hasPrefix("Anchor") })
    }

    func testTheWeekNeverRepeatsALine() {
        // The bug this replaced: every day of the campaign was the same seven
        // lines in a different order. Across a full week the anchors plus the
        // fresh draws must now be forty-nine distinct lines.
        let campaign = enforcement(theme: .anxiety)
        let pool = deepPool(.anxiety)
        var everythingSpoken: [String] = []

        for day in 1...7 {
            let session = builder().build(
                enforcement: campaign, currentDay: day,
                favorites: [], custom: [], categoryPool: [], selected: nil,
                fullPool: pool
            )
            XCTAssertEqual(session.declarations.first?.text, "Anchor \(day)")
            everythingSpoken += session.declarations.map(\.text)
        }

        XCTAssertEqual(everythingSpoken.count, 49)
        XCTAssertEqual(Set(everythingSpoken).count, 49,
                       "a line was spoken on two different days of the same campaign")
    }

    func testTheSameDayAlwaysComposesTheSameBurst() {
        // Day 3 must be the same six lines every time the app is opened, or the
        // campaign stops feeling like a campaign. `shuffled()` would not be.
        let campaign = enforcement(theme: .anxiety)
        let pool = deepPool(.anxiety)
        let first = builder().build(
            enforcement: campaign, currentDay: 3,
            favorites: [], custom: [], categoryPool: [], selected: nil, fullPool: pool
        )
        for _ in 0..<10 {
            let again = builder().build(
                enforcement: campaign, currentDay: 3,
                favorites: [], custom: [], categoryPool: [], selected: nil,
                fullPool: pool.shuffled()
            )
            XCTAssertEqual(again.declarations, first.declarations)
        }
    }

    func testTheWeeksOtherAnchorsNeverSurfaceAsFiller() {
        // Day 6's anchor showing up as day 2's filler would spend the campaign's
        // own material early and then land a second time on day 6.
        let anchorTexts = Set((1...7).map { "Anchor \($0)" })
        var pool = deepPool(.anxiety)
        pool += anchorTexts.map { declaration($0, .anxiety) }

        for day in 1...7 {
            let session = builder().build(
                enforcement: enforcement(theme: .anxiety), currentDay: day,
                favorites: [], custom: [], categoryPool: [], selected: nil, fullPool: pool
            )
            let spokenAnchors = session.declarations.map(\.text).filter { anchorTexts.contains($0) }
            XCTAssertEqual(spokenAnchors, ["Anchor \(day)"],
                           "day \(day) spoke anchors \(spokenAnchors)")
        }
    }

    func testAThinCategoryExtendsIntoItsSiblingsThenFaithAndIdentity() {
        // `grief` ships twenty-five referenced lines and a week wants forty-two,
        // so the back half has to come from somewhere. The order is the whole
        // point: the theme's own lines are spent before a sibling is touched,
        // and faith only after the siblings.
        var pool = deepPool(.grief, count: 25)
        pool += deepPool(.hope, count: 10)          // grief's first mapped sibling
        pool += deepPool(.faith, count: 40)

        var spoken: [String] = []
        for day in 1...7 {
            let session = builder().build(
                enforcement: enforcement(theme: .grief), currentDay: day,
                favorites: [], custom: [], categoryPool: [], selected: nil, fullPool: pool
            )
            XCTAssertEqual(session.declarations.count, 7)
            spoken += session.declarations.dropFirst().map(\.text)
        }

        XCTAssertEqual(spoken.count, 42)
        XCTAssertEqual(Set(spoken).count, 42, "a filler line repeated across the week")

        // All three tiers are reached, in chain order and not before their turn.
        let griefIndices = spoken.indices.filter { spoken[$0].hasPrefix("grief") }
        let hopeIndices = spoken.indices.filter { spoken[$0].hasPrefix("hope") }
        let faithIndices = spoken.indices.filter { spoken[$0].hasPrefix("faith") }
        XCTAssertEqual(griefIndices.count, 25, "every grief line should be used")
        XCTAssertEqual(hopeIndices.count, 10, "every hope line should be used")
        XCTAssertEqual(faithIndices.count, 7, "faith covers only the remainder")
        XCTAssertLessThan(griefIndices.last!, hopeIndices.first!,
                          "a sibling was drawn before the theme was spent")
        XCTAssertLessThan(hopeIndices.last!, faithIndices.first!,
                          "faith was drawn before the mapped siblings were spent")

        // The theme still owns the opening days outright.
        XCTAssertTrue(spoken.prefix(12).allSatisfy { $0.hasPrefix("grief") })
    }

    func testFillerCarriesItsOwnCategoryNotTheCampaignTheme() {
        // A line borrowed from `hope` during Enforcing Comfort is labelled hope.
        // The chip names where the line actually came from; the campaign's claim
        // on the burst lives in `origin` and `theme`, which stay grief.
        var pool = deepPool(.grief, count: 2)
        pool += deepPool(.hope, count: 20)

        let session = builder().build(
            enforcement: enforcement(theme: .grief), currentDay: 1,
            favorites: [], custom: [], categoryPool: [], selected: nil, fullPool: pool
        )
        XCTAssertEqual(session.theme, .grief)
        XCTAssertEqual(session.origin, .enforcement(.grief))
        let borrowed = session.declarations.filter { $0.text.hasPrefix("hope") }
        XCTAssertFalse(borrowed.isEmpty, "this pool forces a borrow")
        XCTAssertTrue(borrowed.allSatisfy { $0.category == .hope })
    }

    func testChainReachesFaithAndIdentityWhenNothingNearerExists() {
        let chain = BurstSessionBuilder.freshChain(for: .grief)
        XCTAssertEqual(chain.first, .grief)
        XCTAssertTrue(chain.contains(.faith))
        XCTAssertTrue(chain.contains(.identity))
        XCTAssertEqual(Set(chain).count, chain.count, "the chain must not repeat a category")
    }

    func testFaithCampaignDoesNotListFaithTwice() {
        let chain = BurstSessionBuilder.freshChain(for: .faith)
        XCTAssertEqual(chain.filter { $0 == .faith }.count, 1)
    }

    func testCampaignBurstDegradesToTheWeeksAnchorsWhenThePoolHasNotLoaded() {
        // The declaration pool loads asynchronously. A burst opened before it
        // lands still owes the user seven lines, so it falls back to the old
        // behaviour for that one session rather than dropping the campaign.
        let session = builder().build(
            enforcement: enforcement(theme: .anxiety), currentDay: 5,
            favorites: [], custom: [], categoryPool: [], selected: nil,
            fullPool: []
        )
        XCTAssertEqual(session.origin, .enforcement(.anxiety))
        XCTAssertEqual(session.declarations.first?.text, "Anchor 5")
        XCTAssertEqual(Set(session.declarations.map(\.text)),
                       Set((1...7).map { "Anchor \($0)" }))
    }

    func testUnreferencedAndJournalLinesNeverFillACampaignBurst() {
        // The slat renders the reference under the line, and journal prompts are
        // not declarations to speak.
        var pool = [Declaration(text: "no reference", book: nil, category: .anxiety)]
        pool.append(Declaration(text: "a journal prompt", book: "Book 1:1",
                                category: .anxiety, contentType: .journal))
        pool += deepPool(.anxiety, count: 6)

        let session = builder().build(
            enforcement: enforcement(theme: .anxiety), currentDay: 1,
            favorites: [], custom: [], categoryPool: [], selected: nil, fullPool: pool
        )
        XCTAssertEqual(session.declarations.count, 7)
        XCTAssertFalse(session.declarations.contains { $0.text == "no reference" })
        XCTAssertFalse(session.declarations.contains { $0.text == "a journal prompt" })
    }

    func testTwoCampaignsOnTheSameThemeDrawDifferently() {
        // The ordering is seeded on the campaign id, so a user who runs Enforcing
        // Peace twice does not get the identical week the second time.
        let pool = deepPool(.anxiety)
        func fresh(_ id: String) -> [String] {
            builder().build(
                enforcement: enforcement(theme: .anxiety, id: id), currentDay: 1,
                favorites: [], custom: [], categoryPool: [], selected: nil, fullPool: pool
            ).declarations.dropFirst().map(\.text)
        }
        XCTAssertNotEqual(fresh("assembled_anxiety_first"), fresh("assembled_anxiety_second"))
    }

    func testAPoolTooThinForTheWeekWrapsRatherThanRepeatingWithinADay() {
        // Ten candidates cannot feed forty-two slots, so later days necessarily
        // reuse earlier days' lines. What must never happen is the same line
        // twice inside one burst.
        let pool = deepPool(.anxiety, count: 10)
        for day in 1...7 {
            let session = builder().build(
                enforcement: enforcement(theme: .anxiety), currentDay: day,
                favorites: [], custom: [], categoryPool: [], selected: nil, fullPool: pool
            )
            let texts = session.declarations.map(\.text)
            XCTAssertEqual(texts.count, 7, "day \(day) came up short")
            XCTAssertEqual(Set(texts).count, 7, "day \(day) repeated a line: \(texts)")
        }
    }

    func testADayOutsideTheCampaignStillComposesAFullBurst() {
        // `currentDay` is clamped to 1...7 upstream, but a burst must not depend
        // on that to avoid an index crash or a short session.
        for day in [0, -1, 9] {
            let session = builder().build(
                enforcement: enforcement(theme: .anxiety), currentDay: day,
                favorites: [], custom: [], categoryPool: [], selected: nil,
                fullPool: deepPool(.anxiety)
            )
            XCTAssertEqual(session.declarations.count, 7, "day \(day)")
            XCTAssertEqual(session.declarations.first?.text, "Anchor 1", "day \(day)")
            XCTAssertEqual(Set(session.declarations.map(\.text)).count, 7, "day \(day)")
        }
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
