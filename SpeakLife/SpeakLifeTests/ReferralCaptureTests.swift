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

    // MARK: - FE-CAP-07b

    /// A typo that is well formed but matches no referrer: inline "not found",
    /// nothing made final, and the corrected code still goes through.
    func test_FE_CAP_07b_typedUnknownCodeIsNotALockout() async {
        let service = FakeReferralService()
        service.claimResult = .success(.rejected(reason: "unknown_code"))
        let coordinator = makeCoordinator(service: service)

        let typo = await coordinator.submitTypedCode("ZZZZZZZZ")

        XCTAssertEqual(typo, .notFound)
        XCTAssertFalse(pending.isFinal)
        XCTAssertNil(pending.pending)

        service.claimResult = .success(.credited)
        let good = await coordinator.submitTypedCode("K7MQ2XPA")
        XCTAssertEqual(good, .submitted(.credited))
        XCTAssertTrue(pending.isFinal)
    }

    // MARK: - FE-JRN-01 (journey)

    /// One friend, in the order the app really runs: the deferred link lands
    /// before onboarding, nothing is claimed until onboarding finishes, the
    /// first claim goes out with no DeviceCheck token and the server says
    /// retry_later, a foreground ten minutes later is throttled, and one an
    /// hour later is credited and closes the claim for good.
    func test_FE_JRN_01_friendJourneyWithTransientTokenFailure() async {
        var clock = ReferralFixtures.fixedNow
        let journeyStore = InMemoryReferralKeyValueStore()
        let journeyPending = PendingReferralStore(store: journeyStore, now: { clock })
        let service = FakeReferralService()
        let tokens = FakeDeviceTokenProvider()
        let coordinator = ReferralClaimCoordinator(
            pending: journeyPending,
            keyValueStore: journeyStore,
            service: service,
            account: FakeReferralAccount(uid: "uid-friend"),
            deviceToken: tokens,
            analytics: analytics,
            now: { clock })

        // First launch: Branch resolves the deferred link before onboarding.
        let params: [String: Any] = [
            "+clicked_branch_link": true,
            "+is_first_session": true,
            "~referring_link": "https://speaklife.app.link/r/K7MQ2XPA",
        ]
        XCTAssertEqual(ReferralCapture.handleBranchParams(params, isOnboarded: false,
                                                          store: journeyPending, analytics: analytics), .captured)

        // A foreground during onboarding never claims.
        let early = await coordinator.claimIfNeeded(isOnboarded: false, isDebugReplay: false)
        XCTAssertNil(early)
        XCTAssertTrue(service.claimRequests.isEmpty)

        // Onboarding finishes 8 minutes later. DeviceCheck fails this once.
        clock = clock.addingTimeInterval(8 * 60)
        tokens.tokenValue = nil
        service.claimResult = .success(.retryLater)
        let first = await coordinator.claimIfNeeded(isOnboarded: true, isDebugReplay: false)
        XCTAssertEqual(first, .retryLater)
        XCTAssertNil(service.claimRequests.last?.deviceToken)
        XCTAssertEqual(service.claimRequests.last?.capturedAt, ReferralFixtures.fixedNow,
                       "capture time is first launch, not the claim")
        let onboardedAt = ReferralFixtures.fixedNow.addingTimeInterval(8 * 60)
        XCTAssertEqual(service.claimRequests.last?.onboardedAt, onboardedAt)
        XCTAssertFalse(journeyPending.isFinal)
        XCTAssertNotNil(journeyPending.pending)

        // Foreground 10 minutes later: inside the retry interval, no call.
        clock = clock.addingTimeInterval(10 * 60)
        let throttled = await coordinator.claimIfNeeded(isOnboarded: true, isDebugReplay: false)
        XCTAssertNil(throttled)
        XCTAssertEqual(service.claimRequests.count, 1)

        // An hour after the first attempt: token works, credited, final.
        clock = clock.addingTimeInterval(55 * 60)
        tokens.tokenValue = "device-token"
        service.claimResult = .success(.credited)
        let second = await coordinator.claimIfNeeded(isOnboarded: true, isDebugReplay: false)
        XCTAssertEqual(second, .credited)
        XCTAssertEqual(service.claimRequests.count, 2)
        XCTAssertEqual(service.claimRequests.last?.onboardedAt, onboardedAt, "stamped once, not moved by the retry")
        XCTAssertTrue(journeyPending.isFinal)
        XCTAssertNil(journeyPending.pending)
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
