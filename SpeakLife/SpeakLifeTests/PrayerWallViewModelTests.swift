//
//  PrayerWallViewModelTests.swift
//  SpeakLifeTests
//
//  Unit tests for the pure-logic surface of PrayerWallViewModel — the
//  legacy-prayedPostIds → reactions migration, the category filter,
//  and per-post reaction lookup. Tests deliberately stay clear of the
//  Firestore-bound write paths (toggleReaction's network side-effects,
//  fetchPosts, etc.) which are integration territory.
//

import XCTest
import FirebaseFirestore
@testable import SpeakLife

final class PrayerWallViewModelTests: XCTestCase {

    // MARK: - Test fixtures

    /// A scratch UserDefaults suite isolated per test so we never pollute
    /// the device's standard suite.
    private var defaults: UserDefaults!
    private let suiteName = "WarriorRoomTests"

    override func setUp() {
        super.setUp()
        UserDefaults().removePersistentDomain(forName: suiteName)
        defaults = UserDefaults(suiteName: suiteName)

        // PrayerWallViewModel.init() calls fetchPostsIfNeeded(), which kicks
        // off a Firestore query if the cooldown timer has elapsed. Set both
        // last-fetch timestamps to "now" in the standard suite so the
        // auto-fetch is suppressed during tests — otherwise an async network
        // response can overwrite the `posts` we set in the test body.
        let now = Date().timeIntervalSince1970
        UserDefaults.standard.set(now, forKey: "prayerWallLastFetch")
        UserDefaults.standard.set(now, forKey: "prayerWallDailyFetch")
    }

    override func tearDown() {
        UserDefaults().removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    // MARK: - Migration

    func testMigrationFromLegacyPrayedPostIdsToStandingReactions() {
        defaults.set(["post-a", "post-b"], forKey: "prayedPostIds")

        PrayerWallViewModel.migrateLegacyPrayedPostIds(in: defaults)

        let migrated = defaults.dictionary(forKey: "warriorRoomUserReactions") as? [String: String]
        XCTAssertEqual(migrated?["post-a"], "standing")
        XCTAssertEqual(migrated?["post-b"], "standing")
        XCTAssertTrue(defaults.bool(forKey: "warriorRoomUserReactionsMigrated"))
    }

    func testMigrationIsIdempotent() {
        defaults.set(["post-a"], forKey: "prayedPostIds")

        PrayerWallViewModel.migrateLegacyPrayedPostIds(in: defaults)

        // Simulate the user picking a different reaction on post-a after the
        // migration ran. A second migration must NOT clobber that choice.
        var reactions = defaults.dictionary(forKey: "warriorRoomUserReactions") as? [String: String] ?? [:]
        reactions["post-a"] = "already_done"
        defaults.set(reactions, forKey: "warriorRoomUserReactions")

        PrayerWallViewModel.migrateLegacyPrayedPostIds(in: defaults)

        let final = defaults.dictionary(forKey: "warriorRoomUserReactions") as? [String: String]
        XCTAssertEqual(final?["post-a"], "already_done",
                       "Repeat migration must not overwrite a user's later choice")
    }

    func testMigrationWithNoLegacyDataStillSetsTheFlag() {
        // No prayedPostIds at all — fresh install or already-migrated user.
        PrayerWallViewModel.migrateLegacyPrayedPostIds(in: defaults)

        XCTAssertNil(defaults.dictionary(forKey: "warriorRoomUserReactions"))
        XCTAssertTrue(defaults.bool(forKey: "warriorRoomUserReactionsMigrated"))
    }

    func testMigrationDoesNotOverwriteExistingV2Reactions() {
        // User had pre-existing v2 reactions AND legacy ids on the same post.
        // The v2 reaction should win.
        defaults.set(["post-shared"], forKey: "prayedPostIds")
        defaults.set(["post-shared": "breakthrough_coming"],
                     forKey: "warriorRoomUserReactions")

        PrayerWallViewModel.migrateLegacyPrayedPostIds(in: defaults)

        let migrated = defaults.dictionary(forKey: "warriorRoomUserReactions") as? [String: String]
        XCTAssertEqual(migrated?["post-shared"], "breakthrough_coming")
    }

    // MARK: - Category filter
    //
    // Category filtering is now performed server-side: setting
    // `categoryFilter` triggers a Firestore refetch that includes the
    // category constraint in the query. There's no longer a pure-logic
    // `filteredPosts` to assert against — that path is integration
    // territory. We can still test that `posts` is the View's source of
    // truth and that the filter setter doesn't crash on no-op assignment.

    func testFilterDefaultsToNil() {
        let viewModel = PrayerWallViewModel()
        XCTAssertNil(viewModel.categoryFilter)
    }

    func testSettingFilterToSameValueIsANoOp() {
        // didSet on categoryFilter triggers fetchPosts, but only when the
        // value actually changes — this guards against re-fetch storms
        // when the View re-renders and re-applies the same filter.
        let viewModel = PrayerWallViewModel()
        viewModel.categoryFilter = nil // same as initial; no-op
        viewModel.categoryFilter = .healing
        viewModel.categoryFilter = .healing // same; no-op
        // No assertion target — we just want the test to not crash, and
        // the implementation's `guard oldValue != categoryFilter` keeps
        // this side-effect free in a way that's hard to assert without DI.
        XCTAssertEqual(viewModel.categoryFilter, .healing)
    }

    // MARK: - Agreement chain copy
    //
    // The collapsed row used to derive its label from the lazily-loaded
    // chain, so every card read "View those standing in agreement" until
    // it was tapped — including cards with zero agreements. The count is
    // now prefetched, and nil (not yet resolved) must never be rendered
    // as zero.

    func testAgreementChainTitleIsNeutralWhenCountIsUnknown() {
        XCTAssertEqual(PrayerWallViewModel.agreementChainTitle(count: nil),
                       "View those standing in agreement")
    }

    func testAgreementChainTitleSaysSoWhenChainIsEmpty() {
        XCTAssertEqual(PrayerWallViewModel.agreementChainTitle(count: 0),
                       "No one has stood in agreement yet")
    }

    func testAgreementChainTitleIsSingularForOneVoice() {
        XCTAssertEqual(PrayerWallViewModel.agreementChainTitle(count: 1),
                       "1 voice in agreement")
    }

    func testAgreementChainTitlePluralizesBeyondOne() {
        XCTAssertEqual(PrayerWallViewModel.agreementChainTitle(count: 4),
                       "4 voices in agreement")
    }

    func testAgreementChainTitleTreatsNegativeCountsAsEmpty() {
        // Defensive: an optimistic decrement should never be able to print
        // "-1 voices in agreement".
        XCTAssertEqual(PrayerWallViewModel.agreementChainTitle(count: -2),
                       "No one has stood in agreement yet")
    }

    // MARK: - Agreement count resolution

    func testAgreementCountIsNilBeforeItIsResolved() {
        let viewModel = PrayerWallViewModel()
        var post = PrayerWallPost(text: "Stand with me",
                                  displayName: "A sister in Christ",
                                  deviceId: "device")
        post.id = "post-unresolved"
        XCTAssertNil(viewModel.agreementCount(for: post))
    }

    func testAgreementCountUsesPrefetchedValueBeforeTheChainLoads() {
        let viewModel = PrayerWallViewModel()
        var post = PrayerWallPost(text: "Stand with me",
                                  displayName: "A sister in Christ",
                                  deviceId: "device")
        post.id = "post-prefetched"
        viewModel.agreementCountsByPost["post-prefetched"] = 3
        XCTAssertEqual(viewModel.agreementCount(for: post), 3)
        XCTAssertFalse(viewModel.isAgreementChainLoaded(post))
    }

    func testAgreementCountIgnoresAnOptimisticInsertOnAnUnloadedChain() {
        // A local insert puts one entry in agreementsByPost without the
        // chain ever having been fetched. Counting that dictionary would
        // report "1 voice" on a post that actually has three.
        let viewModel = PrayerWallViewModel()
        var post = PrayerWallPost(text: "Stand with me",
                                  displayName: "A sister in Christ",
                                  deviceId: "device")
        post.id = "post-optimistic"
        viewModel.agreementCountsByPost["post-optimistic"] = 3
        viewModel.agreementsByPost["post-optimistic"] = [
            Agreement(id: nil,
                      userId: "me",
                      displayName: "A brother in Christ",
                      reactionType: "standing",
                      text: "Standing with you.",
                      timestamp: Timestamp())
        ]
        XCTAssertEqual(viewModel.agreementCount(for: post), 3)
    }
}
