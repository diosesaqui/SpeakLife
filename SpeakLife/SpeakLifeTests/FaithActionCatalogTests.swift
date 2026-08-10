//
//  FaithActionCatalogTests.swift
//  SpeakLifeTests
//
//  The eighth slat of the Daily Burst asks for one action mapped to the theme the
//  user just spoke over. Two things have to hold for that to work: the theme has
//  to be resolved from what was actually said, and the ask has to sit still while
//  someone is reading it.
//

import XCTest
@testable import SpeakLife

final class FaithActionCatalogTests: XCTestCase {

    // MARK: - Theme resolution

    func testEnforcementThemeWinsOverEverythingElse() {
        // An active campaign fills all seven slots, so it is the only honest
        // answer even when the picker says otherwise.
        let theme = FaithActionCatalog.resolveTheme(
            enforcement: .health,
            spoken: [.wealth, .wealth, .wealth],
            selected: .warfare
        )
        XCTAssertEqual(theme, .health)
    }

    func testDominantSpokenCategoryWinsOverSelectedCategory() {
        // What came out of their mouth outranks what is selected in the picker.
        let theme = FaithActionCatalog.resolveTheme(
            enforcement: nil,
            spoken: [.marriage, .marriage, .joy],
            selected: .wealth
        )
        XCTAssertEqual(theme, .marriage)
    }

    func testTiesBreakOnFirstAppearance() {
        // Dictionary iteration order is not stable, so a tie must not be able to
        // hand the same burst a different theme on a re-render.
        let spoken: [DeclarationCategory] = [.fear, .joy, .fear, .joy]
        for _ in 0..<25 {
            XCTAssertEqual(
                FaithActionCatalog.resolveTheme(enforcement: nil, spoken: spoken, selected: nil),
                .fear
            )
        }
    }

    func testContainerCategoriesNeverWinTheme() {
        // favorites / myOwn / general are bins, not themes. A burst drawn mostly
        // from favorites should still land on the real subject underneath.
        let theme = FaithActionCatalog.resolveTheme(
            enforcement: nil,
            spoken: [.favorites, .favorites, .myOwn, .general, .anxiety],
            selected: nil
        )
        XCTAssertEqual(theme, .anxiety)
    }

    func testBibleBookCategoriesNeverWinTheme() {
        // "Read Romans" is not a corresponding action — it is the thing they were
        // already doing. A book-only burst falls through to the selected theme.
        let theme = FaithActionCatalog.resolveTheme(
            enforcement: nil,
            spoken: [.romans, .psalms, .john],
            selected: .work
        )
        XCTAssertEqual(theme, .work)
    }

    func testBookEnforcementDoesNotHijackTheme() {
        let theme = FaithActionCatalog.resolveTheme(
            enforcement: .psalms,
            spoken: [.grief, .grief],
            selected: nil
        )
        XCTAssertEqual(theme, .grief)
    }

    func testFallsBackToFaithWhenNothingIsActionable() {
        let theme = FaithActionCatalog.resolveTheme(
            enforcement: nil,
            spoken: [.psalms, .favorites],
            selected: .general
        )
        XCTAssertEqual(theme, .faith)
    }

    func testEmptyBurstStillResolves() {
        let theme = FaithActionCatalog.resolveTheme(enforcement: nil, spoken: [], selected: nil)
        XCTAssertEqual(theme, .faith)
    }

    // MARK: - Action selection

    func testActionIsStableWithinTheSameDay() {
        // The ask must not shuffle underneath someone who is reading it.
        let date = Date()
        let first = FaithActionCatalog.action(for: .health, on: date)
        for _ in 0..<25 {
            XCTAssertEqual(FaithActionCatalog.action(for: .health, on: date), first)
        }
    }

    func testActionRotatesAcrossDays() {
        // Same errand every morning becomes wallpaper. Over a week, a theme with
        // multiple actions must offer more than one.
        let calendar = Calendar.current
        let start = Date()
        var seen = Set<String>()
        for offset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
            seen.insert(FaithActionCatalog.action(for: .health, on: day).headline)
        }
        XCTAssertGreaterThan(seen.count, 1)
    }

    func testUnmappedCategoryBorrowsFaithActions() {
        let borrowed = FaithActionCatalog.actionSet(for: .romans)
        XCTAssertEqual(borrowed, FaithActionCatalog.actionSet(for: .faith))
        XCTAssertFalse(borrowed.actions.isEmpty)
    }

    // MARK: - Catalog coverage and copy hygiene

    func testEveryCategoryResolvesToAUsableAsk() {
        for category in DeclarationCategory.allCases {
            let set = FaithActionCatalog.actionSet(for: category)
            XCTAssertFalse(set.premise.isEmpty, "\(category.rawValue) has no premise")
            XCTAssertFalse(set.actions.isEmpty, "\(category.rawValue) has no actions")
            for action in set.actions {
                XCTAssertFalse(action.icon.isEmpty, "\(category.rawValue) has an action with no icon")
                XCTAssertFalse(action.headline.isEmpty, "\(category.rawValue) has an action with no headline")
                XCTAssertFalse(action.detail.isEmpty, "\(category.rawValue) has an action with no detail")
            }
        }
    }

    func testHighTrafficThemesHaveTheirOwnActions() {
        // The themes people actually pick must never quietly borrow faith's
        // generic ask — a theme-mapped action is the entire point of the slat.
        let mustBeMapped: [DeclarationCategory] = [
            .health, .wealth, .anxiety, .marriage, .work, .fear,
            .warfare, .addiction, .parenting, .grief, .identity, .destiny
        ]
        for category in mustBeMapped {
            XCTAssertNotEqual(
                FaithActionCatalog.actionSet(for: category),
                FaithActionCatalog.actionSet(for: .faith),
                "\(category.rawValue) is falling back to faith instead of having its own actions"
            )
        }
    }

    func testEveryMappedThemeOffersARotation() {
        for category in FaithActionCatalog.mappedThemes {
            XCTAssertGreaterThanOrEqual(
                FaithActionCatalog.actionSet(for: category).actions.count, 2,
                "\(category.rawValue) has nothing to rotate to"
            )
        }
    }

    func testNoDashesInAnyCopy() {
        // CLAUDE.md rule 7: em and en dashes build run-on compound thoughts. This
        // copy sits in the same breath as the declarations, so it holds the line.
        for category in FaithActionCatalog.mappedThemes {
            let set = FaithActionCatalog.actionSet(for: category)
            let strings = [set.premise] + set.actions.flatMap { [$0.headline, $0.detail] }
            for string in strings {
                XCTAssertFalse(string.contains("\u{2014}"), "em dash in \(category.rawValue): \(string)")
                XCTAssertFalse(string.contains("\u{2013}"), "en dash in \(category.rawValue): \(string)")
            }
        }
    }

    func testHeadlinesStayShortEnoughToReadAtAGlance() {
        for category in FaithActionCatalog.mappedThemes {
            for action in FaithActionCatalog.actionSet(for: category).actions {
                let words = action.headline.split(separator: " ").count
                XCTAssertLessThanOrEqual(
                    words, 10,
                    "\(category.rawValue) headline runs long: \(action.headline)"
                )
            }
        }
    }

    // MARK: - Commitment store

    func testCommitmentIsRecordedForToday() {
        let defaults = UserDefaults(suiteName: "FaithActionCatalogTests.commit")!
        defaults.removePersistentDomain(forName: "FaithActionCatalogTests.commit")
        let store = FaithActionCommitmentStore(defaults: defaults)

        XCTAssertFalse(store.hasCommittedToday())

        let action = FaithActionCatalog.action(for: .health)
        store.commit(to: action, theme: .health)

        XCTAssertTrue(store.hasCommittedToday())
        XCTAssertEqual(store.todaysCommitment?.headline, action.headline)
        XCTAssertEqual(store.todaysCommitment?.theme, DeclarationCategory.health.rawValue)
    }

    func testYesterdaysCommitmentDoesNotCountAsTodays() {
        // A stale yes must not show up on the next morning's celebration screen.
        let defaults = UserDefaults(suiteName: "FaithActionCatalogTests.stale")!
        defaults.removePersistentDomain(forName: "FaithActionCatalogTests.stale")
        let store = FaithActionCommitmentStore(defaults: defaults)

        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        store.commit(to: FaithActionCatalog.action(for: .wealth), theme: .wealth, on: yesterday)

        XCTAssertFalse(store.hasCommittedToday())
    }

    func testCommitmentDoesNotSurviveIntoANewDay() {
        let suite = "FaithActionCatalogTests.reload"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        FaithActionCommitmentStore(defaults: defaults)
            .commit(to: FaithActionCatalog.action(for: .joy), theme: .joy, on: yesterday)

        // A fresh launch the next morning starts clean.
        let reloaded = FaithActionCommitmentStore(defaults: defaults)
        XCTAssertNil(reloaded.todaysCommitment)
    }
}
