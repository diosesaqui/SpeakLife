//
//  MagnifyTests.swift
//  SpeakLifeTests
//
//  What has to live in the app-hosted bundle rather than under `swift test`:
//   - `LiftEntryTests` reaches for `LiftView.namesSomething`, which is a SwiftUI
//     view and cannot move into the SpeakLifeServices package.
//   - `MagnifyBankContentTests` decodes `magnify.json` out of the app's
//     Bundle.main, so it needs the app target's resources. These are the
//     assertions that stop a hand-edit of the generated bank from quietly
//     shipping a broken rep.
//
//  Everything that can run without a simulator lives in
//  `Packages/SpeakLifeKit/Tests/SpeakLifeServicesTests/`.
//

import XCTest
import SpeakLifeCore
@testable import SpeakLife

// MARK: - Naming something on the written route

/// The optional written route's gate on what counts as a real entry.
///
/// The predecessor of this check shipped as `count >= 3`, so "I am" lit the
/// button. Four characters name nothing, match no keyword, and route to the
/// low-confidence fallback — the person gets a generic declaration with no
/// relation to what they were carrying, and no sign anything was missed. These
/// tests pin the bar.
final class LiftEntryTests: XCTestCase {

    func testStubsAreRejected() {
        for stub in ["I am", "im", "i", "a b", "it is", "so", ""] {
            XCTAssertFalse(LiftView.namesSomething(stub),
                           "\"\(stub)\" names nothing and must not light the button.")
        }
    }

    /// The case no length rule catches: every count cleared, nothing named.
    func testFunctionWordsAloneAreRejected() {
        XCTAssertFalse(LiftView.namesSomething("i feel like i want to"))
        XCTAssertFalse(LiftView.namesSomething("it is just that i really"))
    }

    /// The bluntest way someone says the truest thing is the shortest. A bar
    /// that rejects these is worse than the stub it was raised to catch.
    func testShortRealEntriesAreAccepted() {
        for entry in ["I'm sick", "I'm broke", "I'm alone", "I'm scared",
                      "my mom is dying", "we might lose the house"] {
            XCTAssertTrue(LiftView.namesSomething(entry),
                          "\"\(entry)\" is a real thing to carry and must be accepted.")
        }
    }

    /// iOS substitutes a curly apostrophe as you type. Both forms have to
    /// tokenize the same way, or the stub list stops recognising anything.
    func testCurlyApostrophesTokenizeLikeStraightOnes() {
        XCTAssertEqual(LiftView.namesSomething("I\u{2019}m sick"),
                       LiftView.namesSomething("I'm sick"))
        XCTAssertFalse(LiftView.namesSomething("I\u{2019}m"))
    }
}

// MARK: - Shipped content

/// `magnify.json` is generated from `declarationsv10.json`, and these assertions
/// are what stop a hand-edit from quietly breaking the rep.
final class MagnifyBankContentTests: XCTestCase {

    private func loadBank() throws -> MagnifyBank {
        let bundle = Bundle(for: MagnifyBankContentTests.self)
        let url = try XCTUnwrap(bundle.url(forResource: "magnify", withExtension: "json"),
                                "magnify.json must be in the app bundle's Resources.")
        return try JSONDecoder().decode(MagnifyBank.self, from: Data(contentsOf: url))
    }

    /// Fifteen per domain is what every rotation constant assumes: the free
    /// slice takes three of each, and the intensity ladder splits them 5/5/5.
    func testShapeIsFifteenPerDomain() throws {
        let bank = try loadBank()
        XCTAssertEqual(bank.entries.count, 135)
        for domain in MagnifyDomain.allCases {
            let inDomain = bank.entries.filter { $0.domain == domain }
            XCTAssertEqual(inDomain.count, 15, "\(domain.rawValue) must carry 15 entries.")
            for level in 1...3 {
                XCTAssertEqual(inDomain.filter { $0.intensity == level }.count, 5,
                               "\(domain.rawValue) must carry 5 entries at intensity \(level).")
            }
        }
    }

    /// Nothing may be blank. A rep that reaches SPEAK with an empty line is a
    /// dead end the user cannot fix.
    func testNoFieldIsEmpty() throws {
        for entry in try loadBank().entries {
            XCTAssertFalse(entry.nameOfGod.isEmpty, "\(entry.id) has no name of God.")
            XCTAssertFalse(entry.attribute.isEmpty, "\(entry.id) has no attribute.")
            XCTAssertFalse(entry.exaltation.isEmpty, "\(entry.id) has no exaltation.")
            XCTAssertFalse(entry.declaration.isEmpty, "\(entry.id) has no declaration.")
            XCTAssertFalse(entry.verseText.isEmpty, "\(entry.id) has no verse.")
            XCTAssertFalse(entry.book.isEmpty, "\(entry.id) has no reference.")
        }
    }

    /// The exaltation is spoken UP, to God, in the second person. This is the
    /// line that replaced the rebuke, and it is the whole reason this pillar no
    /// longer needs an exception to CLAUDE.md rule 12. An exaltation that slipped
    /// into the third person ("He is the God who heals") would quietly turn the
    /// screen back into a statement about God rather than a word said to Him.
    func testEveryExaltationIsAddressedToGod() throws {
        for entry in try loadBank().entries {
            let lowered = entry.exaltation.lowercased()
            XCTAssertTrue(lowered.contains("you") || lowered.contains("your"),
                          "\(entry.id) must be spoken TO God: \(entry.exaltation)")
        }
    }

    /// CLAUDE.md rule 7. Dashes create run-on compound thoughts and this content
    /// is built to be said out loud in one breath.
    func testNoDashesAnywhere() throws {
        for entry in try loadBank().entries {
            for field in [entry.exaltation, entry.declaration, entry.attribute] {
                XCTAssertFalse(field.contains("—") || field.contains("–"),
                               "\(entry.id) must not use dashes: \(field)")
            }
        }
    }

    /// The declaration is spoken over the speaker's own life, so it has to be in
    /// the first person (CLAUDE.md rule 1). The generator filters for this; this
    /// test is what stops a later hand-edit from undoing it.
    func testEveryDeclarationIsFirstPerson() throws {
        for entry in try loadBank().entries {
            let words = Set(entry.declaration.lowercased()
                .split(whereSeparator: { !$0.isLetter && $0 != "'" })
                .map(String.init))
            let firstPerson = ["i", "i'm", "my", "me", "mine"]
            XCTAssertTrue(firstPerson.contains(where: words.contains),
                          "\(entry.id) must be first person: \(entry.declaration)")
        }
    }

    /// The whole rep is one utterance. `ExaltAndDeclareView` primes the verifier
    /// with the two lines joined and splits the matched indices at exactly
    /// `exaltationWords.count`, so the concatenation has to be the plain sum.
    func testSpokenLineIsTheTwoLinesJoined() throws {
        for entry in try loadBank().entries {
            let joined = entry.spokenLine.split(separator: " ").count
            let parts = entry.exaltation.split(separator: " ").count
                + entry.declaration.split(separator: " ").count
            XCTAssertEqual(joined, parts,
                           "\(entry.id) must join cleanly for the highlighter.")
        }
    }

    /// Ids and verses are unique, so the cooldown cannot collide and the same
    /// scripture cannot come round twice under two different names of God.
    func testIdsAndVersesAreUnique() throws {
        let entries = try loadBank().entries
        XCTAssertEqual(Set(entries.map(\.id)).count, entries.count, "Duplicate entry id.")
        XCTAssertEqual(Set(entries.map(\.book)).count, entries.count, "Duplicate verse.")
        XCTAssertEqual(Set(entries.map(\.declaration)).count, entries.count,
                       "Duplicate declaration.")
    }

    /// The teaching layer has to actually be there. `BeholdView` tolerates a nil
    /// line, but shipping without one would silently remove the only surface that
    /// carries the "why" past first run.
    func testWhyLinesAreShipped() throws {
        let bank = try loadBank()
        XCTAssertGreaterThanOrEqual(bank.whyLines.count, 14,
                                    "At least two weeks of reasons before one repeats.")
        for line in bank.whyLines {
            XCTAssertFalse(line.isEmpty)
            XCTAssertFalse(line.contains("—") || line.contains("–"))
        }
    }

    /// Rule 12, enforced on the content rather than trusted to the writer. This
    /// pillar never names the low thing, and the bank is where a slip would hide.
    func testNothingNamesTheLowThing() throws {
        let banned = ["anxiety", "anxious", "depression", "worthless", "shame",
                      "sickness", "fear,", "lust", "failure"]
        for entry in try loadBank().entries {
            let copy = (entry.exaltation + " " + entry.attribute).lowercased()
            for word in banned {
                XCTAssertFalse(copy.contains(word),
                               "\(entry.id) names the low thing (\"\(word)\"): \(copy)")
            }
        }
    }
}
