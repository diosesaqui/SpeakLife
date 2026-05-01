//
//  PrayerWallPostTests.swift
//  SpeakLifeTests
//
//  Unit tests for the PrayerWallPost model — counts, gap attribution
//  for legacy posts, top-reactions ordering, and Codable round-trips
//  across the v1 → v2 boundary.
//

import XCTest
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

    func testDecodingLegacyJSONWithoutNewFieldsSucceeds() throws {
        // Simulates a cached post stored before v2 shipped: no `category`,
        // no `reactionCounts`.
        let legacyJSON = """
        {
          "id": "legacy-1",
          "text": "Praying for healing.",
          "displayName": "A sister in Christ",
          "deviceId": "device-xyz",
          "timestamp": { "seconds": 1714400000, "nanoseconds": 0 },
          "prayerCount": 5,
          "reports": 0,
          "isHidden": false,
          "isAnswered": false
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let post = try decoder.decode(PrayerWallPost.self, from: legacyJSON)

        XCTAssertEqual(post.text, "Praying for healing.")
        XCTAssertEqual(post.prayerCount, 5)
        XCTAssertNil(post.category)
        XCTAssertNil(post.reactionCounts)
        XCTAssertEqual(post.count(for: .standing), 5)
    }

    func testV2PostRoundTripsThroughJSON() throws {
        let original = v2Post(category: .breakthrough,
                              counts: [.standing: 3, .alreadyDone: 1])
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(PrayerWallPost.self, from: data)

        XCTAssertEqual(decoded.category, "breakthrough")
        XCTAssertEqual(decoded.categoryEnum, .breakthrough)
        XCTAssertEqual(decoded.count(for: .standing), 3)
        XCTAssertEqual(decoded.count(for: .alreadyDone), 1)
        XCTAssertEqual(decoded.totalReactions, 4)
    }
}
