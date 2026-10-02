//
//  ReferralCaptureTests.swift
//  SpeakLifeTests
//
//  docs/REFERRAL_FE_TDD.md §9, rows FE-CAP-01 to FE-CAP-07, plus FE-LNK-07
//  (StandLink lives in the app target, so its half of "a Stand code is never a
//  referral code" is tested here). FE-CAP-08 and 09 are in
//  AcquisitionAttributionTests, next to the rest of the Branch attribution.
//
//  Each `onOpenURL` and `BranchAttribution.apply` branch is a static function in
//  `ReferralCapture` taking its dependencies, the same way
//  `BranchAttribution.attribution(from:)` is, so none of this needs a launch.
//

import XCTest
@testable import SpeakLife

@MainActor
final class ReferralCaptureTests: XCTestCase {

    private var store: InMemoryReferralKeyValueStore!
    private var pending: PendingReferralStore!
    private var analytics: SpyAnalytics!

    override func setUp() async throws {
        store = InMemoryReferralKeyValueStore()
        pending = PendingReferralStore(store: store, now: { ReferralFixtures.fixedNow })
        analytics = SpyAnalytics()
    }

    private func linkOpened() -> [String: Any]? {
        analytics.last("referral_link_opened")
    }

    // MARK: - FE-CAP-01

    func test_FE_CAP_01_deferredBranchReferralLinkIsCapturedBeforeOnboarding() {
        let params: [String: Any] = [
            "+clicked_branch_link": true,
            "+is_first_session": true,
            "~referring_link": "https://speaklife.app.link/r/K7MQ2XPA",
        ]

        let outcome = ReferralCapture.handleBranchParams(
            params, isOnboarded: false, store: pending, analytics: analytics)

        XCTAssertEqual(outcome, .captured)
        XCTAssertEqual(pending.pending?.code, "K7MQ2XPA")
        XCTAssertEqual(pending.pending?.source, .deferred)
        XCTAssertEqual(linkOpened()?["source"] as? String, "deferred")
        XCTAssertEqual(linkOpened()?["outcome"] as? String, "captured")
    }

    // MARK: - FE-CAP-02

    func test_FE_CAP_02_openURLReferralLinkIsCapturedAsUniversalLink() {
        let url = URL(string: "https://speaklife.app.link/r/K7MQ2XPA")!

        let outcome = ReferralCapture.handleOpenURL(
            url, isOnboarded: false, store: pending, analytics: analytics)

        XCTAssertEqual(outcome, .captured)
        XCTAssertEqual(pending.pending?.source, .universalLink)
        XCTAssertEqual(linkOpened()?["source"] as? String, "universal_link")
    }

    // MARK: - FE-CAP-03

    func test_FE_CAP_03_openURLWhenAlreadyOnboardedIsExistingUserAndNotCaptured() {
        let url = URL(string: "https://speaklife.app.link/r/K7MQ2XPA")!

        let outcome = ReferralCapture.handleOpenURL(
            url, isOnboarded: true, store: pending, analytics: analytics)

        XCTAssertEqual(outcome, .existingUser)
        XCTAssertNil(pending.pending)
        XCTAssertEqual(linkOpened()?["outcome"] as? String, "existing_user")

        // The Branch callback for the same tap stays silent, so one tap is
        // never reported twice.
        let params: [String: Any] = [
            "+clicked_branch_link": true,
            "~referring_link": "https://speaklife.app.link/r/K7MQ2XPA",
        ]
        XCTAssertNil(ReferralCapture.handleBranchParams(
            params, isOnboarded: true, store: pending, analytics: analytics))
        XCTAssertEqual(analytics.events(named: "referral_link_opened").count, 1)
    }

    // MARK: - FE-CAP-04

    func test_FE_CAP_04_standLinkTakesTheStandPathOnly() {
        let url = URL(string: "https://speaklife.app.link/stand/K7MQ2XPA")!

        XCTAssertNil(ReferralCapture.handleOpenURL(
            url, isOnboarded: false, store: pending, analytics: analytics))
        XCTAssertNil(pending.pending)
        XCTAssertTrue(analytics.events(named: "referral_link_opened").isEmpty)
        XCTAssertEqual(StandLink.code(from: url), "K7MQ2XPA")
    }

    // MARK: - FE-CAP-05

    func test_FE_CAP_05_referralLinkWithOnboardingArmHandlesBoth() {
        let url = URL(string: "https://speaklife.app.link/r/K7MQ2XPA?ob=warfare")!

        let outcome = ReferralCapture.handleOpenURL(
            url, isOnboarded: false, store: pending, analytics: analytics)

        XCTAssertEqual(outcome, .captured)
        XCTAssertEqual(pending.pending?.code, "K7MQ2XPA")
        // The referral capture does not consume the link: the same URL still
        // carries an arm `SubscriptionStore.handleIncomingURL` will route,
        // which onOpenURL calls next, unconditionally.
        let ob = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == "ob" }?.value
        XCTAssertEqual(ob, "warfare")
        XCTAssertNotNil(OnboardingVariant(code: "warfare"))
    }

    // MARK: - FE-CAP-06

    func test_FE_CAP_06_typedValidCodeIsCapturedAsManualAndClaimedImmediately() async {
        let service = FakeReferralService()
        let coordinator = makeCoordinator(service: service)

        let result = await coordinator.submitTypedCode("k7mq-2xpa")

        XCTAssertEqual(result, .submitted(.credited))
        XCTAssertEqual(service.claimRequests.count, 1)
        XCTAssertEqual(service.claimRequests.first?.code, "K7MQ2XPA")
        XCTAssertEqual(service.claimRequests.first?.source, .manual)
        XCTAssertEqual(analytics.events(named: "referral_link_opened").first?["source"] as? String, "manual")
        XCTAssertTrue(pending.isFinal)
    }

    // MARK: - FE-CAP-07

    func test_FE_CAP_07_typedInvalidCodeCapturesNothingAndStaysUsable() async {
        let service = FakeReferralService()
        let coordinator = makeCoordinator(service: service)

        let bad = await coordinator.submitTypedCode("K7MQ0XPA") // `0` is not in the alphabet

        XCTAssertEqual(bad, .invalid)
        XCTAssertNil(pending.pending)
        XCTAssertTrue(service.claimRequests.isEmpty)
        XCTAssertEqual(linkOpened()?["outcome"] as? String, "invalid")

        // The button stays usable: a corrected code goes straight through.
        let good = await coordinator.submitTypedCode("K7MQ2XPA")
        XCTAssertEqual(good, .submitted(.credited))
    }

    // MARK: - FE-LNK-07

    func test_FE_LNK_07_standLinkNeverReadsAReferralLink() {
        XCTAssertNil(StandLink.code(from: URL(string: "https://speaklife.app.link/r/K7MQ2XPA")!))
        XCTAssertNil(StandLink.code(from: URL(string: "speaklife://r/K7MQ2XPA")!))
        XCTAssertNil(StandLink.code(from: URL(string: "https://speaklife.app.link/?ref=K7MQ2XPA")!))
        // And the reverse, for completeness (FE-LNK-06 in Core).
        XCTAssertNil(ReferralLink.code(from: URL(string: "https://speaklife.app.link/stand/K7MQ2XPA")!))
    }

    // MARK: - Helpers

    private func makeCoordinator(service: FakeReferralService) -> ReferralClaimCoordinator {
        ReferralClaimCoordinator(
            pending: pending,
            keyValueStore: store,
            service: service,
            account: FakeReferralAccount(uid: "uid-friend"),
            deviceToken: FakeDeviceTokenProvider(),
            analytics: analytics,
            now: { ReferralFixtures.fixedNow })
    }
}
