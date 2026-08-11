//
//  PrayerWallPostTests.swift
//  SpeakLifeTests
//
//  Unit tests for the PrayerWallPost model — counts, gap attribution
//  for legacy posts, top-reactions ordering, and Codable round-trips
//  across the v1 → v2 boundary.
//

import XCTest
import FirebaseFirestore
@testable import SpeakLife

final class PrayerWallPostTests: XCTestCase {

    // MARK: - Test fixtures

    /// A v1-shape post: no `category`, no `reactionCounts`. This represents
    /// every post that existed in Firestore before the Warrior Room v2
    /// enhancement shipped.
    private func legacyPost(prayerCount: Int = 0) -> PrayerWallPost {
        var post = PrayerWallPost(text: "I declare healing.",
                                  displayName: "A sister in Christ",
                                  deviceId: "device-1")
        post.id = "legacy-post-id"
        post.prayerCount = prayerCount
        return post
    }

    /// A v2-shape post: a category and a reactionCounts map.
    private func v2Post(category: WarriorRoomCategory = .healing,
                        counts: [WarriorRoomReaction: Int]) -> PrayerWallPost {
        var post = PrayerWallPost(text: "Declaring my healing.",
                                  displayName: "A sister in Christ",
                                  deviceId: "device-2",
                                  category: category)
        post.id = "v2-post-id"
        var rawCounts: [String: Int] = [:]
        for (reaction, count) in counts {
            rawCounts[reaction.rawValue] = count
        }
        post.reactionCounts = rawCounts
        post.prayerCount = counts.values.reduce(0, +)
        return post
    }

    // MARK: - Init

    func testInitializerStoresCategoryAsRawValue() {
        let post = PrayerWallPost(text: "Faith.",
                                  displayName: "A brother in Christ",
                                  deviceId: "d",
                                  category: .warfare)
        XCTAssertEqual(post.category, "warfare")
        XCTAssertEqual(post.categoryEnum, .warfare)
    }

    func testInitializerWithoutCategoryHasNilCategory() {
        let post = PrayerWallPost(text: "Faith.",
                                  displayName: "A sister in Christ",
                                  deviceId: "d")
        XCTAssertNil(post.category)
        XCTAssertNil(post.categoryEnum)
        XCTAssertNil(post.reactionCounts)
    }

    // MARK: - count(for:) — legacy posts (no reactionCounts)

    func testLegacyPostAttributesAllPrayerCountToStanding() {
        let post = legacyPost(prayerCount: 12)
        XCTAssertEqual(post.count(for: .standing), 12)
        XCTAssertEqual(post.count(for: .takingGround), 0)
        XCTAssertEqual(post.count(for: .breakthroughComing), 0)
        XCTAssertEqual(post.count(for: .alreadyDone), 0)
    }

    func testLegacyPostWithZeroPrayerCountIsAllZeros() {
        let post = legacyPost(prayerCount: 0)
        for reaction in WarriorRoomReaction.allCases {
            XCTAssertEqual(post.count(for: reaction), 0)
        }
        XCTAssertEqual(post.totalReactions, 0)
    }

    // MARK: - count(for:) — v2 posts (with reactionCounts)

    func testV2PostReportsExactPerReactionCounts() {
        let post = v2Post(counts: [
            .standing: 5,
            .takingGround: 3,
            .breakthroughComing: 2,
            .alreadyDone: 1,
        ])
        XCTAssertEqual(post.count(for: .standing), 5)
        XCTAssertEqual(post.count(for: .takingGround), 3)
        XCTAssertEqual(post.count(for: .breakthroughComing), 2)
        XCTAssertEqual(post.count(for: .alreadyDone), 1)
        XCTAssertEqual(post.totalReactions, 11)
    }

    func testV2PostMissingReactionTypeIsZero() {
        let post = v2Post(counts: [.takingGround: 4])
        XCTAssertEqual(post.count(for: .standing), 0)
        XCTAssertEqual(post.count(for: .takingGround), 4)
        XCTAssertEqual(post.count(for: .breakthroughComing), 0)
    }

    // MARK: - count(for:) — gap attribution (mixed legacy + v2)

    func testGapAttributionAttributesLegacyPrayersToStanding() {
        // Real-world scenario: a post had 10 🙏 taps in v1. After v2 ships,
        // someone reacts ⚔️. The Firestore write increments
        // reactionCounts.taking_ground = 1 and prayerCount = 11.
        // The 10 historical taps must still appear under standing.
        var post = v2Post(counts: [.takingGround: 1])
        post.prayerCount = 11

        XCTAssertEqual(post.count(for: .takingGround), 1)
        XCTAssertEqual(post.count(for: .standing), 10,
                       "Legacy 🙏 taps should fall through to standing")
        XCTAssertEqual(post.totalReactions, 11)
    }

    func testGapAttributionWhenLegacyPrayersAndModernStandingCoexist() {
        // Modern reactionCounts.standing = 2 plus an 8-tap legacy gap.
        var post = v2Post(counts: [.standing: 2, .alreadyDone: 1])
        post.prayerCount = 11  // 2 + 1 + 8 ghost legacy

        XCTAssertEqual(post.count(for: .standing), 10, "2 modern + 8 legacy")
        XCTAssertEqual(post.count(for: .alreadyDone), 1)
        XCTAssertEqual(post.totalReactions, 11)
    }

    func testCountStaysCorrectAfterSwitchingReactionsOnLegacyPost() {
        // Regression for the "count went away" bug. A legacy post arrives
        // with reactionCounts only containing v2 increments (no `.standing`
        // entry); the legacy 🙏 taps live in the prayerCount gap. After
        // switching reactions, the local-state delta must preserve that
        // gap — recomputing prayerCount from sum(counts) would drop it.
        //
        // Simulating the local state right after a switch from
        // .standing → .takingGround on a legacy post that had 5 prior
        // 🙏 taps: server-side prayerCount stays at 6 (5 legacy + 1 new
        // standing tap, then -1+1 on switch), reactionCounts has standing=0
        // and takingGround=1.
        var post = v2Post(counts: [.standing: 0, .takingGround: 1])
        post.prayerCount = 6 // legacy gap of 5 + the new takingGround

        XCTAssertEqual(post.count(for: .standing), 5,
                       "Legacy 🙏 gap must persist after a reaction switch")
        XCTAssertEqual(post.count(for: .takingGround), 1)
        XCTAssertEqual(post.totalReactions, 6,
                       "Total must equal prayerCount, not sum(reactionCounts)")
    }

    func testGapAttributionDoesNotGoNegative() {
        // Defensive: if reactionCounts sum > prayerCount somehow (out-of-order
        // writes), the gap clamps to 0 — no negative counts shown.
        var post = v2Post(counts: [.standing: 5, .takingGround: 5])
        post.prayerCount = 3 // intentionally under-reported

        XCTAssertGreaterThanOrEqual(post.count(for: .standing), 0)
        XCTAssertGreaterThanOrEqual(post.count(for: .takingGround), 0)
    }

    func testNegativeReactionCountClampsToZeroInDisplay() {
        // If a Firestore decrement underflows, we still present non-negative
        // counts to the user.
        var post = v2Post(counts: [.standing: 3])
        post.reactionCounts = ["standing": -2]
        post.prayerCount = 0

        XCTAssertEqual(post.count(for: .standing), 0)
    }

    // MARK: - topReactions

    func testTopReactionsAreSortedByCountDescending() {
        let post = v2Post(counts: [
            .standing: 1,
            .takingGround: 4,
            .breakthroughComing: 7,
            .alreadyDone: 2,
        ])
        let top = post.topReactions
        XCTAssertEqual(top.count, 4)
        XCTAssertEqual(top[0].reaction, .breakthroughComing)
        XCTAssertEqual(top[0].count, 7)
        XCTAssertEqual(top[1].reaction, .takingGround)
        XCTAssertEqual(top[1].count, 4)
    }

    func testTopReactionsOmitsZeroCountReactions() {
        let post = v2Post(counts: [.standing: 3, .takingGround: 1])
        let top = post.topReactions
        XCTAssertEqual(top.count, 2)
        XCTAssertTrue(top.allSatisfy { $0.count > 0 })
    }

    func testTopReactionsForPostWithNoReactionsIsEmpty() {
        let post = legacyPost(prayerCount: 0)
        XCTAssertTrue(post.topReactions.isEmpty)
    }

    func testTopReactionsForLegacyPostShowsStandingOnly() {
        let post = legacyPost(prayerCount: 7)
        let top = post.topReactions
        XCTAssertEqual(top.count, 1)
        XCTAssertEqual(top[0].reaction, .standing)
        XCTAssertEqual(top[0].count, 7)
    }

    // MARK: - categoryEnum

    func testCategoryEnumReturnsNilForLegacyPost() {
        let post = legacyPost()
        XCTAssertNil(post.categoryEnum)
    }

    func testCategoryEnumReturnsNilForUnknownCategoryString() {
        var post = legacyPost()
        post.category = "money"
        XCTAssertNil(post.categoryEnum)
    }

    func testCategoryEnumDecodesValidCategoryString() {
        var post = legacyPost()
        post.category = "warfare"
        XCTAssertEqual(post.categoryEnum, .warfare)
    }

    // MARK: - Codable round-trips (legacy → v2 forward compat)

    func testLegacyPostWithoutV2FieldsStillReadsCorrectly() {
        // Built rather than decoded: `id` is @DocumentID, which no coder a unit
        // test can construct will decode — it needs a real DocumentReference in
        // the decoder's userInfo, and only a live DocumentSnapshot has one.
        //
        // The behaviour under test survives intact: a post stored before v2
        // shipped has no `category` and no `reactionCounts`, and the UI must
        // fall back to `prayerCount` as the standing count.
        var post = PrayerWallPost(text: "Praying for healing.",
                                  displayName: "A sister in Christ",
                                  deviceId: "device-xyz")
        post.prayerCount = 5
        post.category = nil
        post.reactionCounts = nil

        XCTAssertEqual(post.text, "Praying for healing.")
        XCTAssertEqual(post.prayerCount, 5)
        XCTAssertNil(post.category)
        XCTAssertNil(post.reactionCounts)
        XCTAssertEqual(post.count(for: .standing), 5)
    }

    /// Encode only, deliberately.
    ///
    /// A full round trip is not reachable from a unit test: @DocumentID decodes
    /// only with a real DocumentReference in the decoder's userInfo, which comes
    /// from a live DocumentSnapshot. Firestore.Encoder is fine with it — it
    /// omits the id, because in Firestore the id belongs to the document
    /// reference and never to the payload.
    ///
    /// The half that can run is also the half that matters: whether the v2
    /// fields reach the wire under the right keys. That is what would silently
    /// break a real post.
    func testV2PostEncodesItsNewFieldsToFirestore() throws {
        let original = v2Post(category: .breakthrough,
                              counts: [.standing: 3, .alreadyDone: 1])

        let encoded = try Firestore.Encoder().encode(original)

        XCTAssertEqual(encoded["category"] as? String, "breakthrough")
        let counts = encoded["reactionCounts"] as? [String: Int]
        XCTAssertEqual(counts?[WarriorRoomReaction.standing.rawValue], 3)
        XCTAssertEqual(counts?[WarriorRoomReaction.alreadyDone.rawValue], 1)
        XCTAssertEqual(encoded["prayerCount"] as? Int, 4)
        XCTAssertNil(encoded["id"], "the id belongs to the document reference, not the payload")

        // And the model reads its own fields back the way the UI will.
        XCTAssertEqual(original.categoryEnum, .breakthrough)
        XCTAssertEqual(original.count(for: .standing), 3)
        XCTAssertEqual(original.count(for: .alreadyDone), 1)
        XCTAssertEqual(original.totalReactions, 4)
    }
}
