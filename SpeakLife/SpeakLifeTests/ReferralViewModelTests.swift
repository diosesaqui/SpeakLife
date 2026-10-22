//
//  ReferralViewModelTests.swift
//  SpeakLifeTests
//
//  docs/REFERRAL_FE_TDD.md §8, rows FE-VM-01 to FE-VM-14. One test per row.
//
//  The page's state machine is tested in Core (`ReferralPageReducerTests`).
//  These check the glue: that the view model runs the reducer's effects in the
//  right order against the right seams, and that nothing secret ever reaches
//  analytics. FE-VM-10 to 12 and 14 are the friend side, so they drive
//  `ReferralClaimCoordinator`, which owns the claim.
//

import XCTest
@testable import SpeakLife

@MainActor
final class ReferralViewModelTests: XCTestCase {

    private var log: ReferralCallLog!
    private var service: FakeReferralService!
    private var account: FakeReferralAccount!
    private var tokens: FakeDeviceTokenProvider!
    private var analytics: SpyAnalytics!
    private var store: InMemoryReferralKeyValueStore!
    private var opener: FakeURLOpener!
    private var pasteboard: FakePasteboard!
    private var redemptionSheetCount = 0
    private var isPremium = false

    override func setUp() async throws {
        log = ReferralCallLog()
        service = FakeReferralService(log: log)
        account = FakeReferralAccount(log: log)
        tokens = FakeDeviceTokenProvider()
        analytics = SpyAnalytics()
        store = InMemoryReferralKeyValueStore()
        opener = FakeURLOpener()
        pasteboard = FakePasteboard()
        redemptionSheetCount = 0
        isPremium = false
    }

    // MARK: - Builders

    private func makeDependencies(domain: String = "speaklife.app.link") -> ReferralDependencies {
        var deps = ReferralDependencies(
            service: service,
            account: account,
            deviceToken: tokens,
            analytics: analytics,
            store: store,
            flags: StaticFeatureFlags(
                [ReferralConfigKey.enabled: true],
                strings: [ReferralConfigKey.linkDomain: domain]),
            urlOpener: opener,
            pasteboard: pasteboard,
            cardRenderer: StubShareCardRenderer(),
            presentCodeRedemption: { [unowned self] in self.redemptionSheetCount += 1 },
            isPremium: { [unowned self] in self.isPremium },
            now: { ReferralFixtures.fixedNow }
        )
        deps.loadingTimeout = 60
        return deps
    }

    private func makeViewModel(entry: ReferralEntry = .postOnboarding,
                               onDismiss: @escaping () -> Void = {}) -> ReferralViewModel {
        ReferralViewModel(entry: entry, dependencies: makeDependencies(), onDismiss: onDismiss)
    }

    private func makeCoordinator(pending: PendingReferralStore) -> ReferralClaimCoordinator {
        ReferralClaimCoordinator(
            pending: pending,
            keyValueStore: store,
            service: service,
            account: account,
            deviceToken: tokens,
            analytics: analytics,
            now: { ReferralFixtures.fixedNow })
    }

    private func pendingStore(capturing code: String? = ReferralFixtures.code,
                              source: ReferralSource = .deferred) -> PendingReferralStore {
        let pending = PendingReferralStore(store: store, now: { ReferralFixtures.fixedNow })
        if let code { pending.capture(code: code, source: source) }
        return pending
    }

    /// Opens the page with no account, taps Invite, and waits for the sheet.
    private func enrollAndShare(_ vm: ReferralViewModel) async {
        vm.onAppear()
        vm.inviteTapped()
        await waitUntil { vm.sharePayload != nil }
    }

    // MARK: - FE-VM-01

    func test_FE_VM_01_inviteWithNoUserEnsuresAccountBeforeGetOrCreateOnce() async {
        account.currentUid = nil
        let vm = makeViewModel()
        vm.onAppear()
        vm.inviteTapped()
        await waitUntil { self.log.entries.contains("getOrCreate") }

        XCTAssertEqual(log.entries, ["ensureAccount", "getOrCreate"])
        XCTAssertEqual(account.ensureCount, 1)
    }

    // MARK: - FE-VM-02

    func test_FE_VM_02_getOrCreateCarriesTokenAndStillGoesOutWithoutOne() async {
        tokens.tokenValue = "dc-token"
        let first = makeViewModel()
        first.onAppear()
        first.inviteTapped()
        await waitUntil { self.service.getOrCreateTokens.count == 1 }
        XCTAssertEqual(service.getOrCreateTokens.first ?? nil, "dc-token")

        // Token provider fails: the call still goes out, without a token
        // (BE-ENR-08).
        tokens.tokenValue = nil
        store = InMemoryReferralKeyValueStore()
        account.currentUid = nil
        let second = makeViewModel()
        second.onAppear()
        second.inviteTapped()
        await waitUntil { self.service.getOrCreateTokens.count == 2 }
        XCTAssertNil(service.getOrCreateTokens[1])
    }

    // MARK: - FE-VM-03

    func test_FE_VM_03_enrollPresentsImageAndTextWithExactlyOneLink() async {
        let vm = makeViewModel()
        await enrollAndShare(vm)

        let payload = try? XCTUnwrap(vm.sharePayload)
        XCTAssertNotNil(payload?.image)
        let text = payload?.text ?? ""
        XCTAssertTrue(text.contains("https://speaklife.app.link/r/K7MQ2XPA"), text)
        XCTAssertEqual(text.components(separatedBy: "https://").count - 1, 1, "exactly one link")
        // The card travels first, then the text.
        XCTAssertTrue(payload?.activityItems.first is UIImage)
        XCTAssertTrue(payload?.activityItems.last is String)
    }

    // MARK: - FE-VM-04

    func test_FE_VM_04_completedShareTracksShareCompletedWithActivityType() async {
        let vm = makeViewModel()
        await enrollAndShare(vm)

        vm.shareFinished(activityType: "com.apple.UIKit.activity.Message", completed: true)

        let event = analytics.last("referral_share_completed")
        XCTAssertEqual(event?["activity_type"] as? String, "com.apple.UIKit.activity.Message")
        XCTAssertNil(vm.sharePayload)
    }

    // MARK: - FE-VM-05

    func test_FE_VM_05_cancelledShareTracksNothing() async {
        let vm = makeViewModel()
        await enrollAndShare(vm)

        vm.shareFinished(activityType: nil, completed: false)

        XCTAssertTrue(analytics.events(named: "referral_share_completed").isEmpty)
        XCTAssertNil(vm.sharePayload)
    }

    // MARK: - FE-VM-06

    func test_FE_VM_06_pageShownCarriesEachEntryPoint() {
        let entries: [ReferralEntry] = [.postOnboarding, .profile, .hardPaywall, .push]
        for entry in entries {
            makeViewModel(entry: entry).onAppear()
        }
        let shown = analytics.events(named: "referral_page_shown").compactMap { $0["entry"] as? String }
        XCTAssertEqual(shown, ["post_onboarding", "profile", "hard_paywall", "push"])
        XCTAssertEqual(analytics.last("referral_page_shown")?["state"] as? String, "not_enrolled")
    }

    // MARK: - FE-VM-07

    func test_FE_VM_07_notNowTracksDismissSetsAutoShownAndCallsOnDismiss() {
        var dismissed = 0
        let vm = makeViewModel(onDismiss: { dismissed += 1 })
        vm.onAppear()

        vm.notNowTapped()

        let event = analytics.last("referral_page_dismissed")
        XCTAssertEqual(event?["entry"] as? String, "post_onboarding")
        XCTAssertNotNil(event?["seconds_on_page"])
        XCTAssertTrue(store.bool(forKey: ReferralKeys.autoShown))
        XCTAssertEqual(dismissed, 1)

        // A later disappear does not report the same dismissal twice.
        vm.onDisappear()
        XCTAssertEqual(analytics.events(named: "referral_page_dismissed").count, 1)
    }

    // MARK: - FE-VM-08

    func test_FE_VM_08_redeemOpensExactAppleURLAndFallsBackToCopyAndSheet() async {
        XCTAssertEqual(ReferralViewModel.redeemURL(code: ReferralFixtures.rewardCode)?.absoluteString,
                       "https://apps.apple.com/redeem?ctx=offercodes&id=1617492998&code=ABCD1234EFGH")

        ReferralSnapshotCache.save(ReferralFixtures.unlocked(), to: store)
        let vm = makeViewModel(entry: .profile)
        vm.onAppear()
        guard case .unlocked = vm.state else {
            return XCTFail("expected unlocked, got \(vm.state)")
        }

        vm.redeemTapped()
        await waitUntil { !self.opener.opened.isEmpty }
        XCTAssertEqual(opener.opened.first?.absoluteString,
                       "https://apps.apple.com/redeem?ctx=offercodes&id=1617492998&code=ABCD1234EFGH")
        XCTAssertTrue(pasteboard.copied.isEmpty)
        XCTAssertEqual(redemptionSheetCount, 0)

        // Apple's page refuses to open: copy the code, open RevenueCat's sheet.
        opener.result = false
        let fallback = makeViewModel(entry: .profile)
        fallback.onAppear()
        fallback.redeemTapped()
        await waitUntil { self.redemptionSheetCount == 1 }
        XCTAssertEqual(pasteboard.copied, [ReferralFixtures.rewardCode])
        XCTAssertEqual(fallback.notice, .codeCopied)
    }

    // MARK: - FE-VM-09

    func test_FE_VM_09_serverSnapshotIsWrittenToCache() {
        account.currentUid = "uid-referrer-1"
        let vm = makeViewModel(entry: .profile)
        vm.onAppear()
        XCTAssertEqual(service.observedUids, ["uid-referrer-1"])

        service.push(ReferralFixtures.active(count: 2))

        XCTAssertEqual(ReferralSnapshotCache.load(from: store), ReferralFixtures.active(count: 2))
        XCTAssertEqual(vm.state, .active(count: 2, target: 5, code: ReferralFixtures.code))
    }

    // MARK: - FE-VM-10

    func test_FE_VM_10_claimOnOnboardingFinishSendsCaptureAndTracksAttempt() async {
        tokens.tokenValue = "friend-token"
        let pending = pendingStore(source: .deferred)
        let coordinator = makeCoordinator(pending: pending)

        let outcome = await coordinator.claimIfNeeded(isOnboarded: true, isDebugReplay: false)

        XCTAssertEqual(outcome, .credited)
        let request = service.claimRequests.first
        XCTAssertEqual(request?.code, ReferralFixtures.code)
        XCTAssertEqual(request?.capturedAt, ReferralFixtures.fixedNow)
        XCTAssertEqual(request?.source, .deferred)
        XCTAssertEqual(request?.deviceToken, "friend-token")
        XCTAssertEqual(request?.payload["capturedAt"] as? Int64,
                       Int64(ReferralFixtures.fixedNow.timeIntervalSince1970 * 1000))

        let event = analytics.last("referral_claim_result")
        XCTAssertEqual(event?["outcome"] as? String, "credited")
        XCTAssertEqual(event?["source"] as? String, "deferred")
        XCTAssertEqual(event?["attempt"] as? Int, 1)
        XCTAssertTrue(pending.isFinal)
    }

    // MARK: - FE-VM-11

    func test_FE_VM_11_claimWithNoUserEnsuresAccountFirst() async {
        account.currentUid = nil
        let coordinator = makeCoordinator(pending: pendingStore())

        await coordinator.claimIfNeeded(isOnboarded: true, isDebugReplay: false)

        XCTAssertEqual(log.entries, ["ensureAccount", "claim"])
    }

    // MARK: - FE-VM-12

    func test_FE_VM_12_claimThatThrowsKeepsPendingAndTracksError() async {
        service.claimResult = .failure(FakeServiceError())
        let pending = pendingStore()
        let coordinator = makeCoordinator(pending: pending)

        let outcome = await coordinator.claimIfNeeded(isOnboarded: true, isDebugReplay: false)

        XCTAssertEqual(outcome, .transportError)
        XCTAssertNotNil(pending.pending, "a failed claim keeps the friend for a retry")
        XCTAssertFalse(pending.isFinal)
        XCTAssertEqual(analytics.last("referral_claim_result")?["outcome"] as? String, "error")
    }

    // MARK: - FE-VM-13

    func test_FE_VM_13_noEventEverCarriesAReferralCodeRewardCodeOrUid() async {
        account.currentUid = "uid-secret-777"
        let vm = makeViewModel(entry: .profile)
        vm.onAppear()
        service.push(ReferralFixtures.active(count: 1))
        vm.inviteTapped()
        await waitUntil { vm.sharePayload != nil }
        vm.shareFinished(activityType: "com.apple.UIKit.activity.Message", completed: true)
        service.push(ReferralFixtures.unlocked())
        vm.redeemTapped()
        await waitUntil { !self.opener.opened.isEmpty }
        service.reissueResult = .failure(ReferralServiceError.exhausted)
        vm.reissueTapped()
        await waitUntil { !vm.isReissuing }
        vm.notNowTapped()

        // Friend side too.
        let coordinator = makeCoordinator(pending: pendingStore(capturing: "Q2W3E4R5"))
        await coordinator.claimIfNeeded(isOnboarded: true, isDebugReplay: false)

        let secrets = [ReferralFixtures.code, ReferralLink.formatted(ReferralFixtures.code),
                       ReferralFixtures.rewardCode, "Q2W3E4R5", "uid-secret-777"]
        XCTAssertFalse(analytics.events.isEmpty)
        for event in analytics.events {
            for (key, value) in event.parameters {
                let text = "\(value)"
                for secret in secrets {
                    XCTAssertFalse(text.contains(secret), "\(event.name).\(key) leaked \(secret)")
                }
            }
        }

        // And the scrubber itself drops a code even if a caller passes one.
        let scrubbed = ReferralViewModel.scrub(
            ["code": "K7MQ2XPA", "note": "has K7MQ2XPA inside", "count": 2],
            secrets: [ReferralFixtures.code])
        XCTAssertNil(scrubbed["code"])
        XCTAssertNil(scrubbed["note"])
        XCTAssertEqual(scrubbed["count"] as? Int, 2)
    }

    // MARK: - FE-VM-14

    func test_FE_VM_14_onboardingFinishedIncludesReferralPending() {
        let base: [String: Any] = ["variant": "warfare", "converted": false]

        let without = ReferralCapture.onboardingFinishedParameters(base, store: pendingStore(capturing: nil))
        XCTAssertEqual(without["referral_pending"] as? Bool, false)
        XCTAssertEqual(without["variant"] as? String, "warfare")

        let with = ReferralCapture.onboardingFinishedParameters(base, store: pendingStore())
        XCTAssertEqual(with["referral_pending"] as? Bool, true)
    }
}
