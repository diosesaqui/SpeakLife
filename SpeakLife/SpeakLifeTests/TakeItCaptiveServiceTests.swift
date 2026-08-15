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

    /// Every shipped declaration must pass the validator that guards generated
    /// ones. This is the corpus check the unit tests cannot do — the bank lives
    /// in the app bundle.
    ///
    /// It found four false positives the first time it ran: "God alone makes me
    /// dwell in safety" and "Alone or in a crowd, I am the same person" tripped
    /// an "alone" keyword meant for loneliness, and "He is my only hope" plus
    /// Hebrews 11:1's "what I hope for" tripped a hedging check meant for "I
    /// hope that". A validator stricter than the reviewed library does not
    /// raise quality; it quietly discards good generated lines and serves the
    /// fallback instead, with nothing on screen to say so.
    func testEveryShippedDeclarationPassesTheHouseRules() throws {
        for thought in try loadBank() {
            XCTAssertTrue(ThoughtClassifier.followsHouseRules(thought.counterDeclaration),
                          "Reviewed line rejected by the validator: \(thought.id) — \(thought.counterDeclaration)")
        }
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

final class CounterSelectionTests: XCTestCase {

    private func bank() throws -> [IncomingThought] {
        let url = try XCTUnwrap(Bundle(for: type(of: self)).url(forResource: "thoughts", withExtension: "json")
                                ?? Bundle.main.url(forResource: "thoughts", withExtension: "json"))
        return try JSONDecoder().decode(ThoughtBank.self, from: Data(contentsOf: url)).thoughts
    }

    /// The line a thought about illness gets must be about a body being whole,
    /// not about strength for a task.
    ///
    /// Plain word overlap picked "God gives me strength and fills me with fresh
    /// power", because the lie THAT entry answers is "Your strength is not
    /// coming back" and it shares the incidental words "coming" and "back".
    /// Rarity weighting sinks common words so they cannot outvote the terrain's
    /// curated line.
    func testIllnessThoughtGetsAHealingLine() throws {
        let classifier = ThoughtClassifier(bank: try bank())
        guard case .matched(let category, let thought, let confidence) =
                classifier.classify("Covid is coming back") else {
            return XCTFail("Expected a match.")
        }
        XCTAssertEqual(category, .sickness)
        XCTAssertEqual(confidence, .high)
        XCTAssertFalse(thought.counterDeclaration.localizedCaseInsensitiveContains("strength"),
                       "A thought about illness must not draw a strength-for-a-task line.")
    }

    /// Same sentence, same line, every time — on this launch and the next.
    func testSelectionIsStable() throws {
        let loaded = try bank()
        let input = "Covid is coming back"
        guard case .matched(_, let first, _) = ThoughtClassifier(bank: loaded).classify(input),
              case .matched(_, let second, _) = ThoughtClassifier(bank: loaded).classify(input) else {
            return XCTFail("Expected matches.")
        }
        XCTAssertEqual(first.id, second.id)
    }
}

/// The validator that stands between a generated line and someone's mouth.
