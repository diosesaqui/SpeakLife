//
//  WarriorRoomTypesTests.swift
//  SpeakLifeTests
//
//  Unit tests for Warrior Room enums and the Agreement model.
//  Raw values of these enums are persisted to Firestore — test failures
//  here usually mean a value was renamed and a data migration is required.
//

import XCTest
import FirebaseFirestore
@testable import SpeakLife

final class WarriorRoomTypesTests: XCTestCase {

    // MARK: - WarriorRoomReaction

    func testReactionRawValuesAreStable() {
        // These raw values are written into Firestore and into UserDefaults.
        // Renaming any of them is a breaking data change.
        XCTAssertEqual(WarriorRoomReaction.standing.rawValue,           "standing")
        XCTAssertEqual(WarriorRoomReaction.takingGround.rawValue,       "taking_ground")
        XCTAssertEqual(WarriorRoomReaction.breakthroughComing.rawValue, "breakthrough_coming")
        XCTAssertEqual(WarriorRoomReaction.alreadyDone.rawValue,        "already_done")
    }

    func testAllReactionCasesPresent() {
        XCTAssertEqual(WarriorRoomReaction.allCases.count, 4)
        XCTAssertEqual(Set(WarriorRoomReaction.allCases),
                       Set([.standing, .takingGround, .breakthroughComing, .alreadyDone]))
    }

    func testEveryReactionExposesEmojiLabelAndPlaceholder() {
        for reaction in WarriorRoomReaction.allCases {
            XCTAssertFalse(reaction.emoji.isEmpty,
                           "Reaction \(reaction) is missing an emoji")
            XCTAssertFalse(reaction.label.isEmpty,
                           "Reaction \(reaction) is missing a label")
            XCTAssertFalse(reaction.shortLabel.isEmpty,
                           "Reaction \(reaction) is missing a short label")
            XCTAssertFalse(reaction.agreementPlaceholder.isEmpty,
                           "Reaction \(reaction) is missing an agreement placeholder")
        }
    }

    func testReactionLabelsMatchSpec() {
        XCTAssertEqual(WarriorRoomReaction.standing.label,           "Standing with you")
        XCTAssertEqual(WarriorRoomReaction.takingGround.label,       "Taking ground")
        XCTAssertEqual(WarriorRoomReaction.breakthroughComing.label, "Breakthrough coming")
        XCTAssertEqual(WarriorRoomReaction.alreadyDone.label,        "Already done")
    }

    func testReactionEmojisMatchSpec() {
        XCTAssertEqual(WarriorRoomReaction.standing.emoji,           "🔥")
        XCTAssertEqual(WarriorRoomReaction.takingGround.emoji,       "⚔️")
        XCTAssertEqual(WarriorRoomReaction.breakthroughComing.emoji, "🙌")
        XCTAssertEqual(WarriorRoomReaction.alreadyDone.emoji,        "👑")
    }

    func testReactionRoundTripsThroughRawValue() {
        for reaction in WarriorRoomReaction.allCases {
            let roundTripped = WarriorRoomReaction(rawValue: reaction.rawValue)
            XCTAssertEqual(roundTripped, reaction)
        }
    }

    func testReactionFromUnknownRawValueIsNil() {
        XCTAssertNil(WarriorRoomReaction(rawValue: "totally_made_up"))
        XCTAssertNil(WarriorRoomReaction(rawValue: ""))
    }

    // MARK: - WarriorRoomCategory

    func testCategoryRawValuesAreStable() {
        XCTAssertEqual(WarriorRoomCategory.healing.rawValue,       "healing")
        XCTAssertEqual(WarriorRoomCategory.identity.rawValue,      "identity")
        XCTAssertEqual(WarriorRoomCategory.calling.rawValue,       "calling")
        XCTAssertEqual(WarriorRoomCategory.peace.rawValue,         "peace")
        XCTAssertEqual(WarriorRoomCategory.breakthrough.rawValue,  "breakthrough")
        XCTAssertEqual(WarriorRoomCategory.warfare.rawValue,       "warfare")
        XCTAssertEqual(WarriorRoomCategory.relationships.rawValue, "relationships")
        XCTAssertEqual(WarriorRoomCategory.faith.rawValue,         "faith")
    }

    func testAllCategoryCasesPresent() {
        XCTAssertEqual(WarriorRoomCategory.allCases.count, 8)
    }

    func testEveryCategoryHasEmojiLabelAndPlaceholder() {
        for category in WarriorRoomCategory.allCases {
            XCTAssertFalse(category.emoji.isEmpty,
                           "Category \(category) missing emoji")
            XCTAssertFalse(category.label.isEmpty,
                           "Category \(category) missing label")
            XCTAssertFalse(category.composerPlaceholder.isEmpty,
                           "Category \(category) missing composer placeholder")
        }
    }

    func testComposerPlaceholdersAreUnique() {
        // Each category should have a distinct, brand-tuned placeholder —
        // a duplicate likely means a copy-paste error.
        let placeholders = WarriorRoomCategory.allCases.map(\.composerPlaceholder)
        XCTAssertEqual(Set(placeholders).count, placeholders.count,
                       "Composer placeholders should all be unique per category")
    }

    func testCategoryLabelsMatchSpec() {
        XCTAssertEqual(WarriorRoomCategory.healing.label,       "Healing")
        XCTAssertEqual(WarriorRoomCategory.identity.label,      "Identity")
        XCTAssertEqual(WarriorRoomCategory.calling.label,       "Calling")
        XCTAssertEqual(WarriorRoomCategory.peace.label,         "Peace")
        XCTAssertEqual(WarriorRoomCategory.breakthrough.label,  "Breakthrough")
        XCTAssertEqual(WarriorRoomCategory.warfare.label,       "Warfare")
        XCTAssertEqual(WarriorRoomCategory.relationships.label, "Relationships")
        XCTAssertEqual(WarriorRoomCategory.faith.label,         "Faith")
    }

    func testCategoryFromUnknownRawValueIsNil() {
        XCTAssertNil(WarriorRoomCategory(rawValue: "money"))
        XCTAssertNil(WarriorRoomCategory(rawValue: ""))
    }

    // MARK: - Agreement model

    func testAgreementMaxLengthIs150() {
        // Spec: agreements are short — max 150 characters.
        XCTAssertEqual(Agreement.maxLength, 150)
    }

    func testAgreementReactionMapsToKnownEnumCase() throws {
        let agreement = makeAgreement(reactionType: "taking_ground")
        XCTAssertEqual(agreement.reaction, .takingGround)
    }

    func testAgreementReactionWithUnknownTypeIsNil() throws {
        let agreement = makeAgreement(reactionType: "celebrating")
        XCTAssertNil(agreement.reaction)
    }

    func testAgreementForEveryReactionRoundTrips() throws {
        for reaction in WarriorRoomReaction.allCases {
            let agreement = makeAgreement(reactionType: reaction.rawValue)
            XCTAssertEqual(agreement.reaction, reaction,
                           "Agreement.reaction failed to map raw value \(reaction.rawValue)")
        }
    }

    // MARK: - Helpers

    private func makeAgreement(reactionType: String,
                               text: String = "We declare it.",
                               displayName: String = "Sister",
                               userId: String = "user1") -> Agreement {
        // Built directly, not decoded. `Agreement.id` is @DocumentID, and that
        // wrapper cannot be decoded by any coder a unit test can construct: it
        // demands a real DocumentReference in the decoder's userInfo, which
        // only a live DocumentSnapshot supplies. Firestore.Decoder fails the
        // same way JSONDecoder does — "Could not find DocumentReference for
        // user info key".
        //
        // Nothing is lost. What these tests are about is whether
        // `Agreement.reaction` maps its raw string onto the enum, and that is a
        // computed property over `reactionType`. Decoding was only ever
        // scaffolding to reach it.
        Agreement(id: "agreement-1",
                  userId: userId,
                  displayName: displayName,
                  reactionType: reactionType,
                  text: text,
                  timestamp: Timestamp(seconds: 1714400000, nanoseconds: 0))
    }
}
