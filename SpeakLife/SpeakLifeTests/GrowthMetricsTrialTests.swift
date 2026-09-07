//
//  GrowthMetricsTrialTests.swift
//  SpeakLifeTests
//
//  Guards the trial → paid state machine.
//
//  `trial_activated` is the last step of the Activation → Trial funnel and was
//  documented as live for months while never firing: the transition happens on
//  day 3 with the app shut, and nothing survived the launch to compare against.
//  The rules below are what replaced that, and each one has a way of failing
//  silently — a missed conversion looks exactly like a person who did not
//  convert, and a false one looks exactly like a person who did.
//
//  These cover `trialTransition` rather than `reconcileTrialState` on purpose:
//  the decision is the whole of the logic, and the recorder touches
//  `AnalyticsService.shared`, which registers live providers on first access.
//

import XCTest
@testable import SpeakLife

final class GrowthMetricsTrialTests: XCTestCase {

    private typealias Transition = GrowthMetrics.TrialTransition

    private func transition(
        premium: Bool,
        inTrial: Bool,
        product: String? = "yearly",
        pending: String? = nil
    ) -> Transition {
        GrowthMetrics.trialTransition(
            isPremium: premium,
            isInTrial: inTrial,
            productId: product,
            pending: pending
        )
    }

    // MARK: - Recording the trial

    func testActiveTrialIsRemembered() {
        XCTAssertEqual(transition(premium: true, inTrial: true), .pending(productId: "yearly"))
    }

    func testActiveTrialKeepsTheKnownSKUWhenTheProductHasNotLoaded() {
        // StoreKit products load asynchronously, so an early entitlement update
        // can arrive with no product id. Overwriting the remembered SKU with
        // "unknown" would lose the plan the conversion is attributed to.
        XCTAssertEqual(
            transition(premium: true, inTrial: true, product: nil, pending: "yearly"),
            .pending(productId: "yearly")
        )
    }

    // MARK: - The conversion

    func testTrackedTrialGoingPaidConverts() {
        XCTAssertEqual(
            transition(premium: true, inTrial: false, pending: "yearly"),
            .converted(productId: "yearly")
        )
    }

    func testConversionFallsBackToTheRememberedSKU() {
        XCTAssertEqual(
            transition(premium: true, inTrial: false, product: nil, pending: "monthly"),
            .converted(productId: "monthly")
        )
    }

    // MARK: - What must NOT fire

    /// The case that would corrupt the metric on the day this ships: everyone
    /// already paying looks exactly like a converted trial except for the
    /// pending flag, which they do not have.
    func testExistingSubscriberDoesNotConvert() {
        XCTAssertEqual(transition(premium: true, inTrial: false), .none)
    }

    func testDirectPurchaseWithNoTrialDoesNotConvert() {
        // A discounted intro offer charges immediately, so the person is
        // premium and was never in a trial period.
        XCTAssertEqual(transition(premium: true, inTrial: false, pending: nil), .none)
    }

    func testFreeUserProducesNothing() {
        XCTAssertEqual(transition(premium: false, inTrial: false), .none)
    }

    func testTrialThatLapsesIsEndedNotConverted() {
        XCTAssertEqual(transition(premium: false, inTrial: false, pending: "yearly"), .ended)
    }

    /// Both resolutions clear the pending flag, so a second entitlement update
    /// on the same trial sees `pending: nil` and reports nothing. This is the
    /// dedupe, and RevenueCat's delegate fires on every launch.
    func testResolvedTrialCannotFireTwice() {
        let first = transition(premium: true, inTrial: false, pending: "yearly")
        XCTAssertEqual(first, .converted(productId: "yearly"))

        // The recorder removes the key on `.converted`; this is that state.
        XCTAssertEqual(transition(premium: true, inTrial: false, pending: nil), .none)
    }
}
