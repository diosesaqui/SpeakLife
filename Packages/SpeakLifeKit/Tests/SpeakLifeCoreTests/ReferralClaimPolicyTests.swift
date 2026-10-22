//
//  ReferralClaimPolicyTests.swift
//  SpeakLifeCoreTests
//
//  FE-CLM rows from docs/REFERRAL_FE_TDD.md §4. The friend's claim is sent
//  only after onboarding, at most hourly, and the pending code is dropped only
//  on an answer the server meant as final.
//

import XCTest
@testable import SpeakLifeCore

final class ReferralClaimPolicyTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_790_000_000)
    private let day: TimeInterval = 86_400

    private func pending(capturedDaysAgo days: Double = 1, lastAttemptSecondsAgo: TimeInterval? = nil) -> PendingReferral {
        PendingReferral(code: "K7MQ2XPA",
                        capturedAt: now.addingTimeInterval(-days * day),
                        source: .deferred,
                        attempts: lastAttemptSecondsAgo == nil ? 0 : 1,
                        lastAttemptAt: lastAttemptSecondsAgo.map { now.addingTimeInterval(-$0) })
    }

    private func decide(_ pending: PendingReferral?,
                        onboarded: Bool = true,
                        skipped: Bool = false,
                        debugReplay: Bool = false) -> ReferralClaimDecision {
        ReferralClaimPolicy.decide(pending: pending,
                                   isOnboarded: onboarded,
                                   skippedOnboarding: skipped,
                                   isDebugReplay: debugReplay,
                                   now: now)
    }

    private func makeStore(clockAt date: Date) -> PendingReferralStore {
        PendingReferralStore(store: InMemoryReferralKeyValueStore(), now: { date })
    }

    // MARK: - When to claim

    func test_FE_CLM_01_claimWhenOnboardingJustFinished() {
        XCTAssertEqual(decide(pending()), .claim)
    }

    func test_FE_CLM_02_neverClaimMidOnboarding() {
        XCTAssertEqual(decide(pending(), onboarded: false), .wait)
    }

    func test_FE_CLM_03_nothingPending() {
        XCTAssertEqual(decide(nil), .wait)
        XCTAssertNotEqual(decide(nil), .claim)
    }

    func test_FE_CLM_04_retryOnLaterForegroundAfterRetryLater() {
        // Onboarded on an earlier launch; the last attempt got retry_later two hours ago.
        XCTAssertEqual(decide(pending(lastAttemptSecondsAgo: 2 * 3600)), .claim)
        XCTAssertEqual(decide(pending(lastAttemptSecondsAgo: ReferralClaimPolicy.minRetryInterval)), .claim)
    }

    func test_FE_CLM_05_noHammeringWithinAnHour() {
        XCTAssertEqual(ReferralClaimPolicy.minRetryInterval, 3600)
        XCTAssertEqual(decide(pending(lastAttemptSecondsAgo: 59 * 60)), .wait)
        XCTAssertEqual(decide(pending(lastAttemptSecondsAgo: 1)), .wait)
    }

    func test_FE_CLM_06_expiredPendingIsDiscardedAndCleared() {
        XCTAssertEqual(decide(pending(capturedDaysAgo: 15)), .discard)

        // Through the store, an expired value is gone before the policy sees it.
        let kv = InMemoryReferralKeyValueStore()
        var clockNow = now
        let store = PendingReferralStore(store: kv, now: { clockNow })
        store.capture(code: "K7MQ2XPA", source: .deferred)
        clockNow = now.addingTimeInterval(14 * day + 1)
        XCTAssertNil(store.pending)
        XCTAssertNil(kv.data(forKey: PendingReferralStore.pendingKey))
        XCTAssertEqual(ReferralClaimPolicy.decide(pending: store.pending, isOnboarded: true,
                                                  skippedOnboarding: false, isDebugReplay: false,
                                                  now: clockNow), .wait)
    }

    // MARK: - What to do with the answer

    func test_FE_CLM_07_creditedMarksFinal() {
        XCTAssertTrue(ReferralClaimPolicy.shouldMarkFinal(after: .credited))
        let store = makeStore(clockAt: now)
        store.capture(code: "K7MQ2XPA", source: .deferred)
        ReferralClaimPolicy.apply(.credited, to: store)
        XCTAssertTrue(store.isFinal)
        XCTAssertNil(store.pending)
    }

    func test_FE_CLM_08_everyFinalRejectionMarksFinal() {
        let reasons = [
            "self_referral", "expired",
            "device_already_counted", "device_is_referrer", "device_unverifiable",
        ]
        for reason in reasons {
            XCTAssertTrue(ReferralClaimPolicy.shouldMarkFinal(after: .rejected(reason: reason)), reason)
            let store = makeStore(clockAt: now)
            store.capture(code: "K7MQ2XPA", source: .deferred)
            ReferralClaimPolicy.apply(.rejected(reason: reason), to: store)
            XCTAssertTrue(store.isFinal, reason)
            XCTAssertNil(store.pending, reason)
        }
        XCTAssertEqual(ReferralClaimOutcome.parse(outcome: "rejected", reason: "self_referral"),
                       .rejected(reason: "self_referral"))
    }

    /// A typo'd or unknown code is dropped, NOT made final: a corrected code
    /// can still be captured and claimed.
    func test_FE_CLM_08b_unknownOrInvalidCodeDiscardsButStaysOpen() {
        for reason in ["invalid_code", "unknown_code", "target_reached"] {
            XCTAssertFalse(ReferralClaimPolicy.shouldMarkFinal(after: .rejected(reason: reason)), reason)
            let store = makeStore(clockAt: now)
            store.capture(code: "ZZZZZZZZ", source: .manual)
            ReferralClaimPolicy.apply(.rejected(reason: reason), to: store)
            XCTAssertFalse(store.isFinal, reason)
            XCTAssertNil(store.pending, reason)
            XCTAssertEqual(store.capture(code: "K7MQ2XPA", source: .manual), .captured, reason)
        }
    }

    func test_FE_CLM_09_retryLaterAndDisabledKeepPending() {
        let outcomes: [ReferralClaimOutcome] = [.retryLater, .rejected(reason: "disabled")]
        for outcome in outcomes {
            XCTAssertFalse(ReferralClaimPolicy.shouldMarkFinal(after: outcome))
            let store = makeStore(clockAt: now)
            store.capture(code: "K7MQ2XPA", source: .deferred)
            ReferralClaimPolicy.apply(outcome, to: store)
            XCTAssertFalse(store.isFinal)
            XCTAssertEqual(store.pending?.attempts, 1)
            XCTAssertEqual(store.pending?.lastAttemptAt, now)
        }
        XCTAssertEqual(ReferralClaimOutcome.parse(outcome: "retry_later", reason: nil), .retryLater)
    }

    func test_FE_CLM_10_transportErrorsKeepPending() {
        // Network error, timeout, unavailable, unauthenticated and
        // resource-exhausted all reach the policy as `.transportError`.
        XCTAssertFalse(ReferralClaimPolicy.shouldMarkFinal(after: .transportError))
        let store = makeStore(clockAt: now)
        store.capture(code: "K7MQ2XPA", source: .deferred)
        ReferralClaimPolicy.apply(.transportError, to: store)
        XCTAssertFalse(store.isFinal)
        XCTAssertEqual(store.pending?.code, "K7MQ2XPA")
        XCTAssertEqual(store.pending?.attempts, 1)
        XCTAssertEqual(ReferralClaimOutcome.transportError.analyticsValue, "error")
    }

    func test_FE_CLM_11_unknownOutcomeKeepsPending() {
        let outcome = ReferralClaimOutcome.parse(outcome: "queued_for_review", reason: nil)
        XCTAssertEqual(outcome, .unknown("queued_for_review"))
        XCTAssertFalse(ReferralClaimPolicy.shouldMarkFinal(after: outcome))
        XCTAssertFalse(ReferralClaimPolicy.shouldMarkFinal(after: ReferralClaimOutcome.parse(outcome: nil, reason: nil)))
    }

    func test_FE_CLM_12_iCloudRestoredUserDiscards() {
        XCTAssertEqual(decide(pending(), onboarded: true, skipped: true), .discard)
    }

    func test_FE_CLM_13_debugReplayNeverClaims() {
        XCTAssertEqual(decide(pending(), onboarded: true, debugReplay: true), .wait)
    }
}
