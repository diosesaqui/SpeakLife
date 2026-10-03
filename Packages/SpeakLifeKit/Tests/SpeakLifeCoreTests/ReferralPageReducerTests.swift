//
//  ReferralPageReducerTests.swift
//  SpeakLifeCoreTests
//
//  FE-PAG rows from docs/REFERRAL_FE_TDD.md §6. The page's state machine:
//  the server always wins, a cache only fills an empty page, the share sheet
//  opens once, and `referral_reward_unlocked` fires once per install.
//
//  Copy-only parts of rows (FE-PAG-08 "Not available right now", FE-PAG-14
//  "applies at renewal", FE-PAG-16 "Contact support" and the prefilled email)
//  are the view model's. The reducer's half, the state each one lands in, is
//  asserted here.
//

import XCTest
@testable import SpeakLifeCore

final class ReferralPageReducerTests: XCTestCase {

    private let code = "K7MQ2XPA"
    private let t0 = Date(timeIntervalSince1970: 1_790_000_000)
    private let reward = ReferralReward(code: "ABCD1234EFGH", expiresAt: Date(timeIntervalSince1970: 1_806_000_000), reissueCount: 0)

    private func snap(_ count: Int, of target: Int = 10,
                      _ status: ReferralStatus = .active,
                      reward: ReferralReward? = nil) -> ReferralSnapshot {
        ReferralSnapshot(code: code, count: count, target: target, status: status, reward: reward)
    }

    private func reduce(_ state: ReferralPageState,
                        _ event: ReferralPageEvent,
                        _ memory: inout ReferralPageMemory,
                        isPremium: Bool = false) -> (ReferralPageState, [ReferralPageEffect]) {
        ReferralPageReducer.reduce(state: state, event: event, memory: &memory, isPremium: isPremium)
    }

    private func trackedEvents(_ effects: [ReferralPageEffect]) -> [String] {
        effects.compactMap { effect -> String? in
            if case .track(let name, _) = effect { return name }
            return nil
        }
    }

    // MARK: - Loading

    func test_FE_PAG_01_noSnapshotIsNotEnrolled() {
        var memory = ReferralPageMemory()
        XCTAssertEqual(reduce(.loading, .snapshotLoaded(nil, fromCache: false), &memory).0, .notEnrolled)
        XCTAssertEqual(reduce(.loading, .snapshotLoaded(nil, fromCache: true), &memory).0, .notEnrolled)
    }

    func test_FE_PAG_02_cachedActiveShowsImmediately() {
        var memory = ReferralPageMemory(lastSeenCount: 4)
        let (state, effects) = reduce(.loading, .snapshotLoaded(snap(4), fromCache: true), &memory)
        XCTAssertEqual(state, .active(count: 4, target: 10, code: code))
        XCTAssertEqual(effects, [])
    }

    func test_FE_PAG_03_serverProgressReplacesCacheAndIsSeen() {
        var memory = ReferralPageMemory(lastSeenCount: 4)
        let (state, effects) = reduce(.active(count: 4, target: 10, code: code),
                                      .snapshotLoaded(snap(6), fromCache: false), &memory)
        XCTAssertEqual(state, .active(count: 6, target: 10, code: code))
        XCTAssertEqual(effects, [.track(event: "referral_progress_seen", properties: ["count": "6", "target": "10"])])
        XCTAssertEqual(memory.lastSeenCount, 6)
    }

    func test_FE_PAG_04_serverWinsEvenWhenLower() {
        var memory = ReferralPageMemory(lastSeenCount: 6)
        let (state, effects) = reduce(.active(count: 6, target: 10, code: code),
                                      .snapshotLoaded(snap(4), fromCache: false), &memory)
        XCTAssertEqual(state, .active(count: 4, target: 10, code: code))
        XCTAssertFalse(trackedEvents(effects).contains("referral_progress_seen"))
        XCTAssertEqual(memory.lastSeenCount, 6)
    }

    func test_cacheNeverOverridesServer() {
        var memory = ReferralPageMemory(lastSeenCount: 6)
        let (state, effects) = reduce(.active(count: 6, target: 10, code: code),
                                      .snapshotLoaded(snap(4), fromCache: true), &memory)
        XCTAssertEqual(state, .active(count: 6, target: 10, code: code))
        XCTAssertEqual(effects, [])
    }

    // MARK: - Enrolling

    func test_FE_PAG_05_inviteStartsEnrolling() {
        var memory = ReferralPageMemory()
        let (state, effects) = reduce(.notEnrolled, .inviteTapped, &memory)
        XCTAssertEqual(state, .enrolling)
        XCTAssertEqual(effects, [.enroll])
    }

    func test_FE_PAG_06_enrollSuccessOpensShareSheet() {
        var memory = ReferralPageMemory()
        let (state, effects) = reduce(.enrolling, .enrollSucceeded(snap(0)), &memory)
        XCTAssertEqual(state, .active(count: 0, target: 10, code: code))
        XCTAssertEqual(effects, [.presentShareSheet(code: code)])
    }

    func test_FE_PAG_07_networkFailureIsRetryableAndNoSheet() {
        var memory = ReferralPageMemory()
        let (state, effects) = reduce(.enrolling, .enrollFailed(retryable: true), &memory)
        XCTAssertEqual(state, .error(retryable: true))
        XCTAssertEqual(effects, [])
    }

    func test_FE_PAG_08_serverSwitchOffIsNotRetryable() {
        var memory = ReferralPageMemory()
        let (state, effects) = reduce(.enrolling, .enrollFailed(retryable: false), &memory)
        XCTAssertEqual(state, .error(retryable: false))
        XCTAssertEqual(effects, [])
        // Retry does nothing on a non-retryable error.
        XCTAssertEqual(reduce(.error(retryable: false), .retryTapped, &memory).0, .error(retryable: false))
    }

    func test_FE_PAG_09_secondInviteWhileEnrollingIgnored() {
        var memory = ReferralPageMemory()
        let (state, effects) = reduce(.enrolling, .inviteTapped, &memory)
        XCTAssertEqual(state, .enrolling)
        XCTAssertEqual(effects, [])
        // A racing listener snapshot does not pre-empt the enroll result either,
        // so the sheet still opens exactly once when it lands.
        let (raced, racedEffects) = reduce(.enrolling, .snapshotLoaded(snap(0), fromCache: false), &memory)
        XCTAssertEqual(raced, .enrolling)
        XCTAssertEqual(racedEffects, [])
    }

    // MARK: - Unlocking

    func test_FE_PAG_10_unlockedFiresOnceAcrossRelaunches() {
        var memory = ReferralPageMemory(lastSeenCount: 9)
        let unlockedSnap = snap(10, of: 10, .unlocked, reward: reward)

        let (state, effects) = reduce(.active(count: 9, target: 10, code: code),
                                      .snapshotLoaded(unlockedSnap, fromCache: false), &memory)
        XCTAssertEqual(state, .unlocked(code: code, reward: reward, alreadyPremium: false))
        XCTAssertEqual(trackedEvents(effects).filter { $0 == "referral_reward_unlocked" }.count, 1)
        XCTAssertTrue(effects.contains(.markRewardUnlockedSeen))
        XCTAssertTrue(memory.rewardUnlockedSeen)

        // Relaunch: memory is persisted, the page loads again.
        let (_, cacheEffects) = reduce(.loading, .snapshotLoaded(unlockedSnap, fromCache: true), &memory)
        let (again, serverEffects) = reduce(.unlocked(code: code, reward: reward, alreadyPremium: false),
                                            .snapshotLoaded(unlockedSnap, fromCache: false), &memory)
        XCTAssertEqual(again, .unlocked(code: code, reward: reward, alreadyPremium: false))
        XCTAssertFalse(trackedEvents(cacheEffects + serverEffects).contains("referral_reward_unlocked"))
        XCTAssertFalse((cacheEffects + serverEffects).contains(.markRewardUnlockedSeen))
    }

    func test_FE_PAG_11_pendingCodeState() {
        var memory = ReferralPageMemory(lastSeenCount: 9)
        let (state, effects) = reduce(.active(count: 9, target: 10, code: code),
                                      .snapshotLoaded(snap(10, of: 10, .unlockedPendingCode), fromCache: false), &memory)
        XCTAssertEqual(state, .unlockedPendingCode)
        XCTAssertTrue(trackedEvents(effects).contains("referral_reward_unlocked"))
    }

    func test_FE_PAG_12_pendingCodeThenCodeArrives() {
        var memory = ReferralPageMemory(lastSeenCount: 10, rewardUnlockedSeen: true)
        let (state, effects) = reduce(.unlockedPendingCode,
                                      .snapshotLoaded(snap(10, of: 10, .unlocked, reward: reward), fromCache: false), &memory)
        XCTAssertEqual(state, .unlocked(code: code, reward: reward, alreadyPremium: false))
        XCTAssertFalse(trackedEvents(effects).contains("referral_reward_unlocked"))
    }

    // MARK: - Redeeming

    func test_FE_PAG_13_premiumWithinThirtyMinutesOfRedeemTapIsRedeemed() {
        var memory = ReferralPageMemory(lastSeenCount: 10, rewardUnlockedSeen: true)
        let unlocked = ReferralPageState.unlocked(code: code, reward: reward, alreadyPremium: false)

        let (afterTap, tapEffects) = reduce(unlocked, .redeemTapped(at: t0), &memory)
        XCTAssertEqual(afterTap, unlocked)
        XCTAssertEqual(tapEffects, [
            .track(event: "referral_redeem_tapped", properties: [:]),
            .openRedeem(code: reward.code),
        ])
        XCTAssertEqual(memory.lastRedeemTapAt, t0)

        let (state, effects) = reduce(afterTap, .premiumChanged(isPremium: true, at: t0.addingTimeInterval(10 * 60)), &memory)
        XCTAssertEqual(state, .redeemed)
        XCTAssertEqual(effects, [.track(event: "referral_reward_redeemed", properties: [:])])
    }

    func test_FE_PAG_13_premiumLongAfterTapIsNotAttributed() {
        var memory = ReferralPageMemory(lastSeenCount: 10, rewardUnlockedSeen: true, lastRedeemTapAt: t0)
        let unlocked = ReferralPageState.unlocked(code: code, reward: reward, alreadyPremium: false)
        let (state, effects) = reduce(unlocked, .premiumChanged(isPremium: true, at: t0.addingTimeInterval(31 * 60)), &memory)
        XCTAssertEqual(state, .unlocked(code: code, reward: reward, alreadyPremium: true))
        XCTAssertEqual(effects, [])
    }

    /// Review fix: a D7 subscriber who taps Redeem and backs out must keep the
    /// code. Premium plus a past tap is not a redemption.
    func test_FE_PAG_14b_alreadyPremiumTapThenReloadStaysUnlocked() {
        var memory = ReferralPageMemory(lastSeenCount: 10, rewardUnlockedSeen: true, lastRedeemTapAt: t0)
        let (state, _) = reduce(.loading, .snapshotLoaded(snap(10, of: 10, .unlocked, reward: reward), fromCache: false),
                                &memory, isPremium: true)
        XCTAssertEqual(state, .unlocked(code: code, reward: reward, alreadyPremium: true))
        XCTAssertFalse(memory.rewardRedeemed)
    }

    /// Premium that was already on is not a redemption, even right after a tap.
    func test_FE_PAG_14c_premiumAlreadyOnIsNotARedemption() {
        var memory = ReferralPageMemory(lastSeenCount: 10, rewardUnlockedSeen: true, lastRedeemTapAt: t0)
        let unlocked = ReferralPageState.unlocked(code: code, reward: reward, alreadyPremium: true)
        let (state, effects) = reduce(unlocked, .premiumChanged(isPremium: true, at: t0.addingTimeInterval(60)), &memory)
        XCTAssertEqual(state, unlocked)
        XCTAssertEqual(effects, [])
        XCTAssertFalse(memory.rewardRedeemed)
    }

    /// Once seen redeemed, a reload stays redeemed.
    func test_FE_PAG_14d_redeemedIsRememberedAcrossReloads() {
        var memory = ReferralPageMemory(lastSeenCount: 10, rewardUnlockedSeen: true, lastRedeemTapAt: t0)
        let unlocked = ReferralPageState.unlocked(code: code, reward: reward, alreadyPremium: false)
        let (redeemed, _) = reduce(unlocked, .premiumChanged(isPremium: true, at: t0.addingTimeInterval(60)), &memory)
        XCTAssertEqual(redeemed, .redeemed)
        XCTAssertTrue(memory.rewardRedeemed)
        let (reloaded, _) = reduce(.loading, .snapshotLoaded(snap(10, of: 10, .unlocked, reward: reward), fromCache: false),
                                   &memory, isPremium: true)
        XCTAssertEqual(reloaded, .redeemed)
    }

    func test_FE_PAG_14_alreadyPremiumWhenPageOpensStaysUnlocked() {
        var memory = ReferralPageMemory()
        let (state, _) = reduce(.loading, .snapshotLoaded(snap(10, of: 10, .unlocked, reward: reward), fromCache: false),
                                &memory, isPremium: true)
        XCTAssertEqual(state, .unlocked(code: code, reward: reward, alreadyPremium: true))
    }

    func test_FE_PAG_15_reissueReplacesTheCode() {
        var memory = ReferralPageMemory(rewardUnlockedSeen: true)
        let fresh = ReferralReward(code: "WXYZ5678JKLM", expiresAt: nil, reissueCount: 1)
        let (state, effects) = reduce(.unlocked(code: code, reward: reward, alreadyPremium: false),
                                      .reissueSucceeded(fresh), &memory)
        XCTAssertEqual(state, .unlocked(code: code, reward: fresh, alreadyPremium: false))
        XCTAssertEqual(effects, [.track(event: "referral_reissue_requested", properties: ["result": "success"])])
    }

    func test_FE_PAG_16_reissueExhaustedKeepsOldCode() {
        var memory = ReferralPageMemory(rewardUnlockedSeen: true)
        let unlocked = ReferralPageState.unlocked(code: code, reward: reward, alreadyPremium: false)
        let (state, effects) = reduce(unlocked, .reissueFailed(exhausted: true), &memory)
        XCTAssertEqual(state, unlocked)
        XCTAssertEqual(effects, [.track(event: "referral_reissue_requested", properties: ["result": "exhausted"])])
    }

    // MARK: - Defensive

    func test_FE_PAG_17_countPastTargetIsClamped() {
        var memory = ReferralPageMemory()
        let (state, _) = reduce(.loading, .snapshotLoaded(snap(12, of: 10), fromCache: false), &memory)
        XCTAssertEqual(state, .active(count: 10, target: 10, code: code))
    }

    func test_FE_PAG_18_zeroOrMissingTargetIsFive() {
        var memory = ReferralPageMemory()
        let (state, _) = reduce(.loading, .snapshotLoaded(snap(2, of: 0), fromCache: false), &memory)
        XCTAssertEqual(state, .active(count: 2, target: 5, code: code))

        let missing = ReferralSnapshot(dictionary: ["code": code, "count": 3, "status": "active"])
        XCTAssertEqual(missing?.effectiveTarget, 5)
    }

    func test_FE_PAG_19_retryFromErrorEnrolls() {
        var memory = ReferralPageMemory()
        let (state, effects) = reduce(.error(retryable: true), .retryTapped, &memory)
        XCTAssertEqual(state, .enrolling)
        XCTAssertEqual(effects, [.enroll])
    }

    func test_shareAgainFromActive() {
        var memory = ReferralPageMemory()
        let active = ReferralPageState.active(count: 2, target: 5, code: code)
        let (state, effects) = reduce(active, .inviteTapped, &memory)
        XCTAssertEqual(state, active)
        XCTAssertEqual(effects, [.presentShareSheet(code: code)])
    }

    /// FE-VM-13 in spirit: no analytics effect carries a referral code, a
    /// reward code or a uid, across every event this reducer can emit.
    func test_analyticsEffectsNeverCarryCodes() {
        var memory = ReferralPageMemory()
        var all: [ReferralPageEffect] = []
        let fresh = ReferralReward(code: "WXYZ5678JKLM", expiresAt: nil, reissueCount: 1)
        var state = ReferralPageState.loading
        let events: [ReferralPageEvent] = [
            .snapshotLoaded(nil, fromCache: true),
            .inviteTapped,
            .enrollSucceeded(snap(0, of: 5)),
            .snapshotLoaded(snap(3, of: 5), fromCache: false),
            .snapshotLoaded(snap(5, of: 5, .unlocked, reward: reward), fromCache: false),
            .reissueFailed(exhausted: false),
            .reissueSucceeded(fresh),
            .redeemTapped(at: t0),
            .premiumChanged(isPremium: true, at: t0.addingTimeInterval(60)),
        ]
        for event in events {
            let result = reduce(state, event, &memory)
            state = result.0
            all.append(contentsOf: result.1)
        }
        XCTAssertEqual(state, .redeemed)

        let secrets = [code, reward.code, fresh.code]
        var trackCount = 0
        for effect in all {
            guard case .track(let name, let properties) = effect else { continue }
            trackCount += 1
            let haystack = ([name] + Array(properties.keys) + Array(properties.values)).joined(separator: " ")
            for secret in secrets {
                XCTAssertFalse(haystack.contains(secret), "\(name) carries \(secret)")
            }
        }
        XCTAssertGreaterThan(trackCount, 4)
    }
}
