//
//  ReferralEligibilityTests.swift
//  SpeakLifeCoreTests
//
//  FE-ENT and FE-FLG rows from docs/REFERRAL_FE_TDD.md §5.
//
//  FE-ENT-17 (tapping the hard-paywall link opens the page over the paywall,
//  and closing it returns to the paywall) is presentation wiring in the app
//  target. The decision half, whether the link shows, is FE-ENT-15/16 here.
//

import XCTest
@testable import SpeakLifeCore

final class ReferralEligibilityTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_790_000_000)
    private let day: TimeInterval = 86_400

    /// FE-ENT-01: everything lined up for the automatic page.
    private func eligible() -> ReferralEligibilityInput {
        ReferralEligibilityInput(flagEnabled: true,
                                 isDebugReplay: false,
                                 converted: false,
                                 hasFullAccess: false,
                                 autoShownBefore: false,
                                 hasPendingStandCode: false,
                                 snapshot: nil)
    }

    private func snapshot(_ status: ReferralStatus, reward: Bool) -> ReferralSnapshot {
        ReferralSnapshot(code: "K7MQ2XPA",
                         count: status == .active ? 2 : 5,
                         target: 5,
                         status: status,
                         reward: reward ? ReferralReward(code: "ABCD1234EFGH", expiresAt: nil, reissueCount: 0) : nil)
    }

    // MARK: - 5.1 Automatic page

    func test_FE_ENT_01_showsWhenEverythingLinesUp() {
        XCTAssertTrue(ReferralEligibility.shouldAutoShow(eligible()))
        var withActiveRecord = eligible()
        withActiveRecord.snapshot = snapshot(.active, reward: false)
        XCTAssertTrue(ReferralEligibility.shouldAutoShow(withActiveRecord))
    }

    func test_FE_ENT_02_convertedDoesNotShow() {
        var input = eligible()
        input.converted = true
        XCTAssertFalse(ReferralEligibility.shouldAutoShow(input))
    }

    func test_FE_ENT_03_fullAccessThroughStandPassDoesNotShow() {
        var input = eligible()
        input.hasFullAccess = true
        XCTAssertFalse(ReferralEligibility.shouldAutoShow(input))
    }

    func test_FE_ENT_04_shownBeforeDoesNotShow() {
        var input = eligible()
        input.autoShownBefore = true
        XCTAssertFalse(ReferralEligibility.shouldAutoShow(input))
    }

    func test_FE_ENT_05_standCodeWinsAndDoesNotBurnTheReferralPage() {
        var input = eligible()
        input.hasPendingStandCode = true
        XCTAssertFalse(ReferralEligibility.shouldAutoShow(input))
        XCTAssertEqual(PostOnboardingPresenter.next(hasPendingStandCode: true, referralEligible: true), .standJoin)
        // The decision is pure: nothing was marked shown, so the page is still
        // eligible once the Stand code is gone, and Profile still offers it.
        input.hasPendingStandCode = false
        XCTAssertFalse(input.autoShownBefore)
        XCTAssertTrue(ReferralEligibility.shouldAutoShow(input))
        XCTAssertTrue(ReferralEligibility.showsProfileRow(flagEnabled: true, snapshot: nil, isPremium: false))
    }

    func test_FE_ENT_06_debugReplayDoesNotShow() {
        var input = eligible()
        input.isDebugReplay = true
        XCTAssertFalse(ReferralEligibility.shouldAutoShow(input))
    }

    func test_FE_ENT_07_flagOffDoesNotShow() {
        var input = eligible()
        input.flagEnabled = false
        XCTAssertFalse(ReferralEligibility.shouldAutoShow(input))
    }

    func test_FE_ENT_08_alreadyUnlockedDoesNotShowAutomatically() {
        var input = eligible()
        input.snapshot = snapshot(.unlocked, reward: true)
        XCTAssertFalse(ReferralEligibility.shouldAutoShow(input))
        input.snapshot = snapshot(.unlockedPendingCode, reward: false)
        XCTAssertFalse(ReferralEligibility.shouldAutoShow(input))
    }

    func test_FE_ENT_09_welcomeOfferDoesNotChangeTheResult() {
        // D5: the welcome offer is not an input to eligibility at all, so
        // whether it is armed cannot change the answer. It only waits for the
        // page to close.
        XCTAssertTrue(ReferralEligibility.shouldAutoShow(eligible()))
        XCTAssertEqual(PostOnboardingPresenter.next(hasPendingStandCode: false, referralEligible: true), .referral)
        XCTAssertTrue(PostOnboardingPresenter.canPresentWelcomeOffer(referralPageOpen: false))
    }

    // MARK: - 5.2 Profile rows

    func test_FE_ENT_10_profileRowWithNoRecord() {
        XCTAssertTrue(ReferralEligibility.showsProfileRow(flagEnabled: true, snapshot: nil, isPremium: false))
    }

    func test_FE_ENT_11_profileRowWhileActiveOrUnlocked() {
        XCTAssertTrue(ReferralEligibility.showsProfileRow(flagEnabled: true, snapshot: snapshot(.active, reward: false), isPremium: false))
        XCTAssertTrue(ReferralEligibility.showsProfileRow(flagEnabled: true, snapshot: snapshot(.unlocked, reward: true), isPremium: false))
        XCTAssertTrue(ReferralEligibility.showsProfileRow(flagEnabled: true, snapshot: snapshot(.unlockedPendingCode, reward: false), isPremium: false))
        // A premium user still working toward the reward keeps the row.
        XCTAssertTrue(ReferralEligibility.showsProfileRow(flagEnabled: true, snapshot: snapshot(.active, reward: false), isPremium: true))
    }

    func test_FE_ENT_12_profileRowHiddenOnceRedeemed() {
        XCTAssertFalse(ReferralEligibility.showsProfileRow(flagEnabled: true, snapshot: snapshot(.unlocked, reward: true), isPremium: true))
        XCTAssertFalse(ReferralEligibility.showsProfileRow(flagEnabled: false, snapshot: snapshot(.unlocked, reward: true), isPremium: true))
    }

    func test_FE_ENT_13_inviteCodeEntryWithinFourteenDays() {
        XCTAssertTrue(ReferralEligibility.showsInviteCodeEntry(isOnboarded: true, firstLaunchAt: now.addingTimeInterval(-3 * day),
                                                               now: now, hasPending: false, isFinal: false))
        XCTAssertTrue(ReferralEligibility.showsInviteCodeEntry(isOnboarded: true, firstLaunchAt: now.addingTimeInterval(-14 * day),
                                                               now: now, hasPending: false, isFinal: false))
    }

    func test_FE_ENT_14_inviteCodeEntryHidden() {
        // Day 15.
        XCTAssertFalse(ReferralEligibility.showsInviteCodeEntry(isOnboarded: true, firstLaunchAt: now.addingTimeInterval(-15 * day),
                                                                now: now, hasPending: false, isFinal: false))
        // A pending code.
        XCTAssertFalse(ReferralEligibility.showsInviteCodeEntry(isOnboarded: true, firstLaunchAt: now.addingTimeInterval(-1 * day),
                                                                now: now, hasPending: true, isFinal: false))
        // Already claimed.
        XCTAssertFalse(ReferralEligibility.showsInviteCodeEntry(isOnboarded: true, firstLaunchAt: now.addingTimeInterval(-1 * day),
                                                                now: now, hasPending: false, isFinal: true))
        // Not onboarded.
        XCTAssertFalse(ReferralEligibility.showsInviteCodeEntry(isOnboarded: false, firstLaunchAt: now.addingTimeInterval(-1 * day),
                                                                now: now, hasPending: false, isFinal: false))
        // Unknown first launch: treated as an older install.
        XCTAssertFalse(ReferralEligibility.showsInviteCodeEntry(isOnboarded: true, firstLaunchAt: nil,
                                                                now: now, hasPending: false, isFinal: false))
    }

    // MARK: - 5.3 Hard paywall

    func test_FE_ENT_15_hardPaywallLinkShown() {
        XCTAssertTrue(ReferralEligibility.showsHardPaywallLink(flagEnabled: true, hardPaywallFlag: true, isHardPaywall: true))
    }

    func test_FE_ENT_16_hardPaywallLinkHidden() {
        XCTAssertFalse(ReferralEligibility.showsHardPaywallLink(flagEnabled: true, hardPaywallFlag: false, isHardPaywall: true))
        XCTAssertFalse(ReferralEligibility.showsHardPaywallLink(flagEnabled: true, hardPaywallFlag: true, isHardPaywall: false))
        XCTAssertFalse(ReferralEligibility.showsHardPaywallLink(flagEnabled: false, hardPaywallFlag: true, isHardPaywall: true))
    }

    // MARK: - 5.4 Kill switch

    func test_FE_FLG_01_flagOffAtRuntimeKeepsOpenPageUsableAndAddsNoEntryPoints() {
        // The reducer takes no flag, so an open page keeps working.
        var memory = ReferralPageMemory()
        let (state, effects) = ReferralPageReducer.reduce(state: .notEnrolled, event: .inviteTapped,
                                                          memory: &memory, isPremium: false)
        XCTAssertEqual(state, .enrolling)
        XCTAssertEqual(effects, [.enroll])
        // But no new entry point appears.
        var input = eligible()
        input.flagEnabled = false
        XCTAssertFalse(ReferralEligibility.shouldAutoShow(input))
        XCTAssertFalse(ReferralEligibility.showsProfileRow(flagEnabled: false, snapshot: nil, isPremium: false))
        XCTAssertFalse(ReferralEligibility.showsProfileRow(flagEnabled: false, snapshot: snapshot(.active, reward: false), isPremium: false))
        XCTAssertFalse(ReferralEligibility.showsHardPaywallLink(flagEnabled: false, hardPaywallFlag: true, isHardPaywall: true))
    }

    func test_FE_FLG_02_earnedRewardIsNeverHidden() {
        XCTAssertTrue(ReferralEligibility.showsProfileRow(flagEnabled: false, snapshot: snapshot(.unlocked, reward: true), isPremium: false))
        XCTAssertTrue(ReferralEligibility.showsProfileRow(flagEnabled: false, snapshot: snapshot(.unlockedPendingCode, reward: false), isPremium: false))
    }

    func test_FE_FLG_03_flagOffStillCapturesAndClaims() {
        // Neither the store nor the claim policy takes the flag: the server decides.
        let store = PendingReferralStore(store: InMemoryReferralKeyValueStore(), now: { self.now })
        XCTAssertEqual(store.capture(code: "K7MQ2XPA", source: .deferred), .captured)
        XCTAssertEqual(ReferralClaimPolicy.decide(pending: store.pending, isOnboarded: true,
                                                  skippedOnboarding: false, isDebugReplay: false, now: now), .claim)
    }
}
