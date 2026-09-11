//
//  QualifiedTrialRuleTests.swift
//  SpeakLifeCoreTests
//
//  A false positive here trains Meta on people who already cancelled, and a
//  double fire inflates the event campaigns are bid against, so every gate in
//  the rule gets its own case.
//

import XCTest
@testable import SpeakLifeCore

final class QualifiedTrialRuleTests: XCTestCase {

    private let start = Date(timeIntervalSince1970: 1_780_000_000)
    private let day = QualifiedTrialRule.productionDelay

    private func trial(
        isActive: Bool = true,
        isTrial: Bool = true,
        willRenew: Bool = true,
        isSandbox: Bool = false,
        trialStart: Date?? = .none
    ) -> TrialEntitlementSnapshot {
        TrialEntitlementSnapshot(
            productId: "speaklife.yearly",
            isActive: isActive,
            isTrial: isTrial,
            willRenew: willRenew,
            isSandbox: isSandbox,
            trialStart: trialStart ?? start
        )
    }

    private func qualifies(
        _ snapshot: TrialEntitlementSnapshot,
        after elapsed: TimeInterval,
        allowSandbox: Bool = false,
        alreadySent: Bool = false
    ) -> Bool {
        QualifiedTrialRule.qualifies(
            snapshot,
            now: start.addingTimeInterval(elapsed),
            delay: day,
            allowSandbox: allowSandbox,
            alreadySent: alreadySent
        )
    }

    // MARK: - Timing

    func testQualifiesAtExactlyTwentyFourHours() {
        XCTAssertTrue(qualifies(trial(), after: day))
    }

    func testQualifiesDaysLaterWhenTheAppWasNotOpened() {
        // The event fires on the first open past the mark, however late.
        XCTAssertTrue(qualifies(trial(), after: day * 5))
    }

    func testDoesNotQualifyOneSecondEarly() {
        XCTAssertFalse(qualifies(trial(), after: day - 1))
    }

    func testDoesNotQualifyWhenClockIsBehindTrialStart() {
        XCTAssertFalse(qualifies(trial(), after: -60))
    }

    func testDoesNotQualifyWithoutATrialStart() {
        XCTAssertFalse(qualifies(trial(trialStart: .some(nil)), after: day))
    }

    // MARK: - Entitlement state

    func testCancelledTrialDoesNotQualify() {
        XCTAssertFalse(qualifies(trial(willRenew: false), after: day))
    }

    func testInactiveEntitlementDoesNotQualify() {
        XCTAssertFalse(qualifies(trial(isActive: false), after: day))
    }

    func testPaidPeriodDoesNotQualify() {
        // Converted subscribers already fire Subscribe; this is trials only.
        XCTAssertFalse(qualifies(trial(isTrial: false), after: day))
    }

    // MARK: - Sandbox

    func testSandboxRejectedByDefault() {
        // TestFlight runs the release config against the sandbox store.
        XCTAssertFalse(qualifies(trial(isSandbox: true), after: day))
    }

    func testSandboxAllowedWhenDebugOptsIn() {
        XCTAssertTrue(qualifies(trial(isSandbox: true), after: day, allowSandbox: true))
    }

    // MARK: - Dedupe

    func testAlreadySentDoesNotQualify() {
        XCTAssertFalse(qualifies(trial(), after: day, alreadySent: true))
    }

    func testSentKeyIsStablePerTrial() {
        XCTAssertEqual(
            QualifiedTrialRule.sentKey(for: trial()),
            "qualifiedTrialSent.speaklife.yearly.1780000000"
        )
        XCTAssertEqual(QualifiedTrialRule.sentKey(for: trial()), QualifiedTrialRule.sentKey(for: trial()))
    }

    func testSentKeyDiffersForALaterTrial() {
        let later = trial(trialStart: .some(start.addingTimeInterval(day * 30)))
        XCTAssertNotEqual(QualifiedTrialRule.sentKey(for: trial()), QualifiedTrialRule.sentKey(for: later))
    }

    func testSentKeyIsNilWithoutATrialStart() {
        XCTAssertNil(QualifiedTrialRule.sentKey(for: trial(trialStart: .some(nil))))
    }
}
