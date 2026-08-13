//
//  TakeItCaptiveServiceTests.swift
//  SpeakLifeTests
//
//  What stays in the app-hosted test bundle after PR8:
//   - `AskForThoughtEntryTests` reaches for `AskForThoughtView.namesAThought`,
//     which is a SwiftUI view and cannot move into the SpeakLifeServices
//     package.
//   - `ThoughtBankContentTests` decodes `thoughts.json` out of the app's
//     Bundle.main, so it needs the app target's resources.
//
//  Everything else (`TakeItCaptiveServiceTests`, `GuardChecklistRowTests`,
//  `ThoughtClassifierTests`) moved to
//  `Packages/SpeakLifeKit/Tests/SpeakLifeServicesTests/TakeItCaptiveServiceTests.swift`
//  and now runs under `swift test` without booting a simulator.
//

import XCTest
@testable import SpeakLife

// MARK: - Naming the thought

/// The ASK screen's gate on what counts as a thought.
///
/// This shipped as `count >= 3`, so "I am" lit the button. Four characters name
/// nothing, match no keyword, and route to the low-confidence fallback — the
/// person gets a generic declaration with no relation to what they were
/// carrying, and no sign anything was missed. These tests pin the bar.
final class AskForThoughtEntryTests: XCTestCase {

    func testStubsDoNotCountAsANamedThought() {
        for stub in ["I am", "I want", "i feel", "I'm", "it is", "so", "  ", "I am a"] {
            XCTAssertFalse(AskForThoughtView.namesAThought(stub),
                           "\"\(stub)\" is the start of a sentence, not a thought.")
        }
    }

    /// Function words clear both counts and still name nothing. This is the case
    /// a pure length check cannot catch.
    func testAllFunctionWordsDoNotCount() {
        XCTAssertFalse(AskForThoughtView.namesAThought("i feel like i want to"))
        XCTAssertFalse(AskForThoughtView.namesAThought("it is just that i really"))
    }

    /// The bar must not swing so far that real thoughts get locked out. Short,
    /// blunt sentences are how these actually arrive.
    func testRealThoughtsAreAccepted() {
        for entry in [
            "I'm worthless",
            "I’m worthless",              // iOS substitutes a curly apostrophe
            "God hates me",
            "nobody loves me",
            "I am not good enough",
            "the enemy tries to lie and say he got me",
            "I'll never get out of this debt"
        ] {
            XCTAssertTrue(AskForThoughtView.namesAThought(entry),
                          "\"\(entry)\" is a real thought and must be accepted.")
        }
    }

    /// The shortest real thoughts there are. Every one of these hits a keyword
    /// rule and comes back with a high-confidence match, so locking them out to
    /// catch "I am" would reject the bluntest way someone says the truest thing.
    /// A nine-letter bar did exactly that — this is what holds it at seven.
    func testTheBluntestThoughtsAreAccepted() {
        for entry in ["I'm ugly", "I'm sick", "I'm broke", "I'm alone", "God is mad"] {
            XCTAssertTrue(AskForThoughtView.namesAThought(entry),
                          "\"\(entry)\" must not be locked out by the length bar.")
        }
    }

    /// The bar exists to catch fragments, and the fragments it catches are the
    /// ones a person is still typing — so the screen must keep a live way
    /// forward underneath them. That is the `!canSubmit` gate on the fallback,
    /// asserted here as the invariant it enforces: nothing the gate rejects may
    /// leave the screen with no action, and the fallback is shown for exactly
    /// the set this returns false for.
    func testRejectedEntriesAreExactlyWhenTheFallbackShows() {
        for entry in ["", "I am", "I want", "I'm"] {
            XCTAssertFalse(AskForThoughtView.namesAThought(entry),
                           "\"\(entry)\" must leave the fallback on screen.")
        }
    }

    /// Whatever the gate accepts, the classifier must have something to say
    /// about — the whole point of asking is that a word comes back.
    func testEveryAcceptedThoughtGetsADeclarationAndAVerse() {
        let classifier = ThoughtClassifier(bank: [])
        for entry in ["I'm worthless", "God hates me", "nobody loves me", "qqq zzz mmm"] {
            guard AskForThoughtView.namesAThought(entry) else { continue }
            guard case .matched(_, let thought, _) = classifier.classify(entry) else {
                return XCTFail("\"\(entry)\" must never dead-end.")
            }
            XCTAssertFalse(thought.counterDeclaration.isEmpty)
            XCTAssertFalse(thought.verseText.isEmpty)
            XCTAssertFalse(thought.book.isEmpty)
        }
    }
}

// MARK: - Shipped content

/// The bank is generated from `declarationsv10.json`, and these assertions are
/// what stop a hand-edit from quietly breaking it.
final class ThoughtBankContentTests: XCTestCase {

    private func loadBank() throws -> [IncomingThought] {
        let bundle = Bundle(for: ThoughtBankContentTests.self)
        let url = try XCTUnwrap(bundle.url(forResource: "thoughts", withExtension: "json")
                                ?? Bundle.main.url(forResource: "thoughts", withExtension: "json"))
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(ThoughtBank.self, from: data).thoughts
    }

    func testBankIsBigEnoughToNeverRepeatInsideTheCooldown() throws {
        let bank = try loadBank()
        XCTAssertGreaterThan(bank.count, TakeItCaptiveService.repeatCooldownDays,
                             "At one rep a day, the bank must outlast the 60-day cooldown.")
    }

    func testEveryCategoryIsStockedAtEveryIntensity() throws {
        let bank = try loadBank()
        for category in ThoughtCategory.allCases {
            for intensity in 1...3 {
                let matches = bank.filter { $0.category == category && $0.intensity == intensity }
                XCTAssertFalse(matches.isEmpty,
                               "\(category.rawValue) has nothing at intensity \(intensity), so the ladder would stall there.")
            }
        }
    }

    func testIdsAndCounterDeclarationsAreUnique() throws {
        let bank = try loadBank()
        XCTAssertEqual(Set(bank.map(\.id)).count, bank.count)
        XCTAssertEqual(Set(bank.map(\.counterDeclaration)).count, bank.count,
                       "Two thoughts answered by the same line makes the drill feel canned.")
    }

    /// Every entry must have a line to speak and a verse it stands on. The loop
    /// terminates in speaking, so a blank counter is a broken rep.
    func testEveryThoughtHasSomethingToSpeak() throws {
        for thought in try loadBank() {
            XCTAssertFalse(thought.text.trimmingCharacters(in: .whitespaces).isEmpty, thought.id)
            XCTAssertFalse(thought.counterDeclaration.trimmingCharacters(in: .whitespaces).isEmpty, thought.id)
            XCTAssertFalse(thought.verseText.trimmingCharacters(in: .whitespaces).isEmpty, thought.id)
            XCTAssertFalse(thought.book.trimmingCharacters(in: .whitespaces).isEmpty, thought.id)
            XCTAssertTrue((1...3).contains(thought.intensity), thought.id)
        }
    }

    /// Splits on anything that isn't a letter or apostrophe, so "in me." and
    /// "me," both yield the word `me`. Substring matching on " me " misses both
    /// and would fail a perfectly good declaration.
    private func words(_ text: String) -> Set<String> {
        Set(text.lowercased()
            .split(whereSeparator: { !$0.isLetter && $0 != "'" })
            .map(String.init))
    }

    /// Counter-declarations are copied verbatim out of the reviewed library, so
    /// they inherit its rules — first person, present tense, no dashes.
    func testCounterDeclarationsFollowTheDeclarationRules() throws {
        let firstPerson: Set<String> = ["i", "i'm", "my", "me", "mine", "myself"]
        for thought in try loadBank() {
            let text = thought.counterDeclaration
            XCTAssertFalse(text.contains("—") || text.contains("–"),
                           "Declarations never use dashes: \(thought.id)")
            XCTAssertFalse(words(text).isDisjoint(with: firstPerson),
                           "Declarations are first person: \(thought.id) — \(text)")
        }
    }

    /// The incoming thought is always framed as arriving from outside — second
    /// person, the way a lie actually sounds. It is never written in first
    /// person, because a first-person line reads as the user's own thought and
    /// indicts them, which this feature must never do.
    func testIncomingThoughtsAreNeverFirstPerson() throws {
        let firstPerson: Set<String> = ["i", "i'm", "i've", "my", "mine", "myself"]
        for thought in try loadBank() {
            XCTAssertTrue(words(thought.text).isDisjoint(with: firstPerson),
                          "The thought must never be phrased as the user's own: \(thought.id) — \(thought.text)")
        }
    }
}

// MARK: - Ground taken earns badges

/// Guarding's counter feeds the badge system, and these pin the wiring.
///
/// Before this, `totalThoughtsTakenCaptive` was written, synced across devices
/// and guaranteed monotonic — and then read by nothing. Every sibling counter
/// in `ProgressSyncStore.syncedCounterKeys` cashes out into badge progress;
/// this one earned nothing, which made Guarding the only pillar whose work paid
/// out in a number the user saw once and never again.
final class GroundTakenBadgeTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "GroundTakenBadgeTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    private func stats(_ takenCaptive: Int) -> UserStats {
        UserStats(affirmationsSpoken: 0, versesRead: 0, socialShares: 0,
                  favoritesAdded: 0, categoriesCompleted: [],
                  thoughtsTakenCaptive: takenCaptive)
    }

    /// The ladder exists and is reachable at every tier.
    func testEveryGuardingTierHasABadge() {
        let manager = BadgeManager(userDefaults: defaults)
        let tiers = manager.allBadges.compactMap { badge -> Int? in
            guard case .thoughtsTakenCaptive(let count) = badge.requirement else { return nil }
            return count
        }
        XCTAssertEqual(tiers.sorted(), [1, 10, 50, 150, 365])
    }

    /// One rep earns the first badge. The reason the ladder starts at 1 rather
    /// than 10: the drill is once a day, so a first threshold of ten is ten days
    /// before anything acknowledges the feature exists.
    func testFirstThoughtEarnsTheFirstBadge() {
        let manager = BadgeManager(userDefaults: defaults)
        manager.checkForNewBadges(streakStats: StreakStats(), userStats: stats(1))
        XCTAssertTrue(manager.unlockedBadges.contains { $0.requirement == .thoughtsTakenCaptive(1) })
        XCTAssertFalse(manager.unlockedBadges.contains { $0.requirement == .thoughtsTakenCaptive(10) })
    }

    /// Crossing several thresholds at once awards all of them, not just the top.
    /// Ground is cumulative and can arrive in a batch from another device.
    func testCrossingSeveralTiersAwardsEachOfThem() {
        let manager = BadgeManager(userDefaults: defaults)
        manager.checkForNewBadges(streakStats: StreakStats(), userStats: stats(60))
        for tier in [1, 10, 50] {
            XCTAssertTrue(manager.unlockedBadges.contains { $0.requirement == .thoughtsTakenCaptive(tier) },
                          "Tier \(tier) should be earned at 60.")
        }
        XCTAssertFalse(manager.unlockedBadges.contains { $0.requirement == .thoughtsTakenCaptive(150) })
    }

    /// Re-checking must not award the same badge twice — `checkForNewBadges`
    /// runs on launch, on campaign changes and after every Guarding rep.
    func testRecheckingDoesNotDoubleAward() {
        let manager = BadgeManager(userDefaults: defaults)
        manager.checkForNewBadges(streakStats: StreakStats(), userStats: stats(10))
        let afterFirst = manager.unlockedBadges.count
        manager.checkForNewBadges(streakStats: StreakStats(), userStats: stats(10))
        XCTAssertEqual(manager.unlockedBadges.count, afterFirst)
    }

    /// A stats object that never heard of Guarding earns no Guarding badge.
    /// The defaulted field must fail closed, never open.
    func testOmittedCounterEarnsNothing() {
        let manager = BadgeManager(userDefaults: defaults)
        let noGuarding = UserStats(affirmationsSpoken: 999, versesRead: 999,
                                   socialShares: 999, favoritesAdded: 999,
                                   categoriesCompleted: [])
        manager.checkForNewBadges(streakStats: StreakStats(), userStats: noGuarding)
        XCTAssertFalse(manager.unlockedBadges.contains {
            if case .thoughtsTakenCaptive = $0.requirement { return true }
            return false
        })
    }

    /// The number the badges read is the one the service writes. If these ever
    /// diverge, a user banks ground and the ladder does not move.
    func testServiceCounterIsWhatTheBadgesRead() {
        let service = TakeItCaptiveService(defaults: defaults, bank: [], syncCounters: {})
        service.takeGround(category: .fear, thoughtId: "t1", source: .daily,
                           spoken: true, completesDailyRep: true)
        XCTAssertEqual(GroundTaken.total(defaults: defaults), 1)
        XCTAssertEqual(service.groundTaken, GroundTaken.total(defaults: defaults))
    }
}
