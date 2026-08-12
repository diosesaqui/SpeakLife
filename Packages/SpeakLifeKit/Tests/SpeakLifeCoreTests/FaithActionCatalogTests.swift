//
//  FaithActionCatalogTests.swift
//  SpeakLifeTests
//
//  Content and selection for the eighth slat of the Daily Burst. Deciding WHICH
//  theme a burst was about is `BurstThemeResolver`, covered in
//  BurstSessionTests; this file covers the ask itself: that it sits still while
//  someone is reading it, that every theme has one, and that the copy holds the
//  declaration rules.
//

import XCTest
@testable import SpeakLifeCore

final class FaithActionCatalogTests: XCTestCase {

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

    func testEveryCategoryReturnsAnActionOnEveryDay() {
        // The picker runs one line after the streak is written, so a trap here
        // would lose the app at the worst possible moment. Sweep every category
        // across a full rotation of days.
        let calendar = Calendar.current
        let start = Date()
        for category in DeclarationCategory.allCases {
            for offset in 0..<10 {
                guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
                XCTAssertFalse(
                    FaithActionCatalog.action(for: category, on: day).headline.isEmpty,
                    "\(category.rawValue) returned an empty action"
                )
            }
        }
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

    func testNoAskPrescribesADose() {
        // The ask names the KIND of action the declaration implies and lets the
        // speaker pick the act. A measured one ("walk for fifteen minutes") fits
        // whoever wrote it and nobody else, and hands a failure to anyone whose
        // day or body does not match the number.
        let dose = try! NSRegularExpression(
            pattern: #"\b(minutes?|hours?|miles?)\b|[0-9]"#, options: .caseInsensitive
        )
        for category in FaithActionCatalog.mappedThemes {
            let set = FaithActionCatalog.actionSet(for: category)
            for string in [set.premise] + set.actions.flatMap({ [$0.headline, $0.detail] }) {
                let range = NSRange(string.startIndex..., in: string)
                XCTAssertNil(
                    dose.firstMatch(in: string, range: range),
                    "\(category.rawValue) prescribes a dose: \(string)"
                )
            }
        }
    }

    func testNoAskNamesTheActForTheSpeaker() {
        // Rule 12's sibling. These verbs turn an invitation into an errand, and
        // every one of them was in the shipped copy before this rule existed.
        let prescriptions = ["walk for", "train for", "drink water", "go to bed",
                             "study for", "breathe slowly", "pack one box"]
        for category in FaithActionCatalog.mappedThemes {
            for action in FaithActionCatalog.actionSet(for: category).actions {
                let headline = action.headline.lowercased()
                for prescription in prescriptions {
                    XCTAssertFalse(
                        headline.contains(prescription),
                        "\(category.rawValue) names the act for them: \(action.headline)"
                    )
                }
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
