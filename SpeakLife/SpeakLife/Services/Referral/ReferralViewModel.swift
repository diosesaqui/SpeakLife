//
//  ReferralViewModel.swift
//  SpeakLife
//
//  The referral page's runtime. Spec §5 (J1 to J3), §9.3, §11; tests FE-VM-*.
//
//  It decides NOTHING. `ReferralPageReducer` (SpeakLifeCore) owns every state
//  transition and says what should happen next as effects; this type executes
//  them: enroll through the server, open the share sheet, open Apple's redeem
//  page, write the cache, send analytics. The page view does nothing but
//  `switch` on `state`.
//
//  If a bug can only be caught by tapping through the app, the logic is in the
//  wrong place. Move it into the reducer and test it there.
//

import Foundation
import UIKit
import SpeakLifeCore

// MARK: - Supporting types

/// Where the page was opened from. The `entry` property on every page event.
enum ReferralEntry: String, Identifiable {
    case postOnboarding = "post_onboarding"
    case profile
    case hardPaywall = "hard_paywall"
    case push

    var id: String { rawValue }
}

/// What the share sheet carries: the card FIRST, then one line of copy with the
/// link. Same reasoning as `StandInviteSheet.shareItems`, including why this is
/// not a `ShareLink` (it can carry only one of the two).
struct ReferralSharePayload: Identifiable {
    let id = UUID()
    let image: UIImage?
    let text: String

    var activityItems: [Any] {
        var items: [Any] = []
        if let image { items.append(image) }
        items.append(text)
        return items
    }
}

/// A one-line message the page shows under its main content.
enum ReferralNotice: Equatable {
    /// Apple's redeem page did not open, so the code went to the clipboard.
    case codeCopied
    /// A fresh code replaced the one that did not work.
    case reissued
    /// The one reissue is spent. Support gets the last four of the code.
    case contactSupport(lastFour: String)
    /// Reissue failed for a reason worth retrying.
    case reissueFailed
}

/// Draws the share card. `ReferralShareCardRenderer` in the app; a stub in tests.
@MainActor
protocol ReferralShareCardRendering {
    func render(formattedCode: String) -> UIImage?
}

/// Everything the view model touches outside itself.
@MainActor
struct ReferralDependencies {
    var service: ReferralServicing
    var account: ReferralAccountProviding
    var deviceToken: DeviceTokenProviding
    var analytics: AnalyticsTracking
    var store: ReferralKeyValueStore
    var flags: FeatureFlagProviding
    var urlOpener: ReferralURLOpening
    var pasteboard: ReferralPasteboard
    var cardRenderer: ReferralShareCardRendering
    /// RevenueCat's code redemption sheet, the fallback when Apple's redeem
    /// URL will not open.
    var presentCodeRedemption: @MainActor () -> Void
    var isPremium: @MainActor () -> Bool
    var now: () -> Date
    /// How long the page waits on the listener before treating a missing cache
    /// as "no record". Short in tests.
    var loadingTimeout: TimeInterval = 6

    static func live(subscriptionStore: SubscriptionStore) -> ReferralDependencies {
        ReferralDependencies(
            service: FirebaseReferralService.shared,
            account: StandAuthCoordinator.shared,
            deviceToken: DeviceCheckTokenProvider.shared,
            analytics: AnalyticsService.shared,
            store: UserDefaultsReferralStore.shared,
            flags: DefaultFeatureFlags.shared,
            urlOpener: SystemReferralURLOpener.shared,
            pasteboard: SystemReferralPasteboard.shared,
            cardRenderer: LiveReferralShareCardRenderer(),
            presentCodeRedemption: { subscriptionStore.redeemOfferCode() },
            isPremium: { subscriptionStore.isPremium },
            now: { Date() }
        )
    }
}

// MARK: - View model

@MainActor
final class ReferralViewModel: ObservableObject {

    @Published private(set) var state: ReferralPageState = .loading
    /// Non-nil while the share sheet should be on screen.
    @Published var sharePayload: ReferralSharePayload?
    @Published private(set) var notice: ReferralNotice?
    @Published private(set) var isReissuing = false

    let entry: ReferralEntry

    private let deps: ReferralDependencies
    private let onDismiss: () -> Void

    private var memory: ReferralPageMemory
    private var snapshot: ReferralSnapshot?
    private var observation: ReferralObservation?
    private var openedAt: Date?
    private var dismissTracked = false

    init(entry: ReferralEntry,
         dependencies: ReferralDependencies,
         onDismiss: @escaping () -> Void) {
        self.entry = entry
        self.deps = dependencies
        self.onDismiss = onDismiss
        self.memory = ReferralPageMemoryStore.load(from: dependencies.store)
    }

    // MARK: - Display helpers (no decisions, only formatting)

    private var config: ReferralConfig { ReferralConfig(flags: deps.flags) }

    /// The number in "Invite 5 friends". The person's own locked target once
    /// they have a record; the configured display value before that.
    var displayTarget: Int {
        snapshot?.effectiveTarget ?? config.displayTarget
    }

    /// `K7MQ-2XPA`, for reading aloud.
    func formatted(_ code: String) -> String {
        ReferralLink.formatted(code)
    }

    // MARK: - Lifecycle

    func onAppear() {
        guard openedAt == nil else { return }
        openedAt = deps.now()
        dismissTracked = false

        // Cache first, so the page opens instantly and works offline (§9.3).
        // The server snapshot replaces it the moment it lands.
        let cached = ReferralSnapshotCache.load(from: deps.store)
        if let cached {
            snapshot = cached
            dispatch(.snapshotLoaded(cached, fromCache: true))
        } else if deps.account.currentUid == nil {
            // No account means no record can exist. Do not wait on a listener
            // there is nothing to attach to.
            dispatch(.snapshotLoaded(nil, fromCache: false))
        }

        track("referral_page_shown", [
            "entry": entry.rawValue,
            "state": Self.name(of: state),
            "count": snapshot?.displayCount ?? 0,
            "target": displayTarget,
        ])

        if let uid = deps.account.currentUid {
            startObserving(uid: uid)
            scheduleLoadingFallback()
        }
    }

    /// Swipe-down, or the cover going away for any other reason.
    func onDisappear() {
        trackDismissIfNeeded()
        stopObserving()
        openedAt = nil
    }

    // MARK: - User actions

    func inviteTapped() {
        let effects = dispatch(.inviteTapped)
        // Ignored taps (already enrolling) are not shares.
        guard !effects.isEmpty, !Self.contains(effects, track: "referral_share_tapped") else { return }
        track("referral_share_tapped", [
            "entry": entry.rawValue,
            "count": snapshot?.displayCount ?? 0,
        ])
    }

    func retryTapped() {
        dispatch(.retryTapped)
    }

    /// "Not now" and the close button. Never comes back automatically after
    /// this (§5 J1.5).
    func notNowTapped() {
        deps.store.set(true, forKey: ReferralKeys.autoShown)
        trackDismissIfNeeded()
        stopObserving()
        onDismiss()
    }

    func redeemTapped() {
        let effects = dispatch(.redeemTapped(at: deps.now()))
        if !Self.contains(effects, track: "referral_redeem_tapped") {
            track("referral_redeem_tapped", [:])
        }
    }

    /// "My code didn't work". Allowed once per referrer, server-side.
    func reissueTapped() {
        guard !isReissuing else { return }
        isReissuing = true
        notice = nil
        Task { await reissue() }
    }

    /// From the share sheet's completion handler. Only a completed share is
    /// reported; a cancel says nothing (FE-VM-05).
    func shareFinished(activityType: String?, completed: Bool) {
        sharePayload = nil
        guard completed else { return }
        track("referral_share_completed", [
            "activity_type": activityType ?? "unknown",
        ])
    }

    /// From `SubscriptionStore.isPremium`. Drives `unlocked` → `redeemed`.
    func premiumChanged(_ isPremium: Bool) {
        dispatch(.premiumChanged(isPremium: isPremium, at: deps.now()))
    }

    // MARK: - Reducer

    @discardableResult
    private func dispatch(_ event: ReferralPageEvent) -> [ReferralPageEffect] {
        let (next, effects) = ReferralPageReducer.reduce(
            state: state, event: event, memory: &memory, isPremium: deps.isPremium())
        state = next
        ReferralPageMemoryStore.save(memory, to: deps.store)
        if next == .redeemed {
            deps.store.set(true, forKey: ReferralKeys.rewardRedeemed)
        }
        for effect in effects { perform(effect) }
        return effects
    }

    private func perform(_ effect: ReferralPageEffect) {
        switch effect {
        case .enroll:
            Task { await enroll() }
        case .presentShareSheet(let code):
            presentShare(code: code)
        case .openRedeem(let code):
            Task { await openRedeem(code: code) }
        case .track(let event, let properties):
            var converted: [String: Any] = [:]
            for (key, value) in properties { converted[key] = value }
            track(event, converted)
        case .markRewardUnlockedSeen:
            // Usually already set by the reducer through `inout memory`; this
            // makes the once-ever guarantee independent of that detail.
            memory.rewardUnlockedSeen = true
            ReferralPageMemoryStore.save(memory, to: deps.store)
        }
    }

    // MARK: - Snapshot

    private func startObserving(uid: String) {
        observation?.cancel()
        observation = deps.service.observe(uid: uid) { [weak self] snapshot in
            self?.serverSnapshot(snapshot)
        }
    }

    private func stopObserving() {
        observation?.cancel()
        observation = nil
    }

    private func serverSnapshot(_ incoming: ReferralSnapshot?) {
        // The record does not exist until `getOrCreateReferral` commits, so a
        // nil arriving mid-enroll is the old truth, not news.
        if incoming == nil, state == .enrolling { return }
        snapshot = incoming
        // Server state is cached whenever it lands (FE-VM-09), and a missing
        // record clears the cache so a deleted account does not haunt the page.
        ReferralSnapshotCache.save(incoming, to: deps.store)
        dispatch(.snapshotLoaded(incoming, fromCache: false))
    }

    /// A signed-in user with no cache and a listener that never answers
    /// (offline on first open) would otherwise sit on a spinner. After the
    /// timeout, treat it as "no record": Invite still works, because
    /// `getOrCreateReferral` returns the existing record if there is one.
    private func scheduleLoadingFallback() {
        let timeout = deps.loadingTimeout
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(max(timeout, 0) * 1_000_000_000))
            guard let self, self.state == .loading else { return }
            self.dispatch(.snapshotLoaded(nil, fromCache: true))
        }
    }

    // MARK: - Effects

    private func enroll() async {
        let hadRecord = snapshot != nil
        do {
            // Account FIRST (FE-VM-01). A brand-new install has no Firebase
            // user, and the callable rejects an unauthenticated caller.
            let uid = try await deps.account.ensureAccount()
            // A missing token never blocks enrolling (BE-ENR-08). The server
            // enrolls anyway and logs it.
            let token = await deps.deviceToken.token()
            let created = try await deps.service.getOrCreate(
                deviceToken: token, isDevelopment: deps.deviceToken.isDevelopment)
            snapshot = created
            ReferralSnapshotCache.save(created, to: deps.store)
            if !hadRecord {
                track("referral_enrolled", ["entry": entry.rawValue])
            }
            dispatch(.enrollSucceeded(created))
            if observation == nil { startObserving(uid: uid) }
        } catch {
            let mapped = ReferralServiceError.wrap(error)
            // Server switch off is the one failure retrying cannot fix
            // (FE-PAG-08). Everything else, including no network, can.
            dispatch(.enrollFailed(retryable: mapped != .serverDisabled))
        }
    }

    private func presentShare(code: String) {
        let settings = config
        guard let url = ReferralLink.shareURL(code: code, host: settings.linkDomain) else { return }
        let text = ReferralShareText.render(template: settings.shareTemplate, link: url)
        let image = deps.cardRenderer.render(formattedCode: ReferralLink.formatted(code))
        sharePayload = ReferralSharePayload(image: image, text: text)
    }

    /// Apple's own redeem page, prefilled. When it will not open, the code goes
    /// to the clipboard and RevenueCat's in-app redemption sheet opens instead,
    /// so the person is never left holding a code with nowhere to put it.
    private func openRedeem(code: String) async {
        guard let url = Self.redeemURL(code: code) else { return }
        if await deps.urlOpener.open(url) { return }
        deps.pasteboard.copy(code)
        notice = .codeCopied
        deps.presentCodeRedemption()
    }

    private func reissue() async {
        defer { isReissuing = false }
        do {
            let reward = try await deps.service.reissue()
            dispatch(.reissueSucceeded(reward))
            notice = .reissued
        } catch {
            let exhausted = ReferralServiceError.wrap(error) == .exhausted
            dispatch(.reissueFailed(exhausted: exhausted))
            if exhausted {
                notice = .contactSupport(lastFour: currentRewardLastFour)
            } else {
                notice = .reissueFailed
            }
            // `referral_reissue_requested` comes from the reducer's .track
            // effect. Tracking it here too double-counted every reissue.
        }
    }

    private var currentRewardLastFour: String {
        guard case .unlocked(_, let reward, _) = state else { return "" }
        return String(reward.code.suffix(4))
    }

    // MARK: - Analytics

    private func trackDismissIfNeeded() {
        guard !dismissTracked, let openedAt else { return }
        dismissTracked = true
        let seconds = max(0, Int(deps.now().timeIntervalSince(openedAt)))
        track("referral_page_dismissed", [
            "entry": entry.rawValue,
            "state": Self.name(of: state),
            "seconds_on_page": seconds,
        ])
    }

    /// Every event goes through here, and here is where FE-VM-13 is enforced:
    /// no referral code, reward code or uid ever leaves the device in an event,
    /// whoever built the properties.
    private func track(_ event: String, _ properties: [String: Any]) {
        deps.analytics.track(event, parameters: Self.scrub(properties, secrets: secrets))
    }

    private var secrets: Set<String> {
        var values: Set<String> = []
        if let uid = deps.account.currentUid { values.insert(uid) }
        if let snapshot {
            values.insert(snapshot.code)
            values.insert(ReferralLink.formatted(snapshot.code))
            if let reward = snapshot.reward { values.insert(reward.code) }
        }
        if case .unlocked(let code, let reward, _) = state {
            values.insert(code)
            values.insert(reward.code)
        }
        if case .active(_, _, let code) = state {
            values.insert(code)
        }
        values.remove("")
        return values
    }

    static let forbiddenKeys: Set<String> = [
        "code", "referral_code", "reward_code", "offer_code", "uid", "user_id", "referrer_uid",
    ]

    static func scrub(_ properties: [String: Any], secrets: Set<String>) -> [String: Any] {
        var clean: [String: Any] = [:]
        for (key, value) in properties {
            if forbiddenKeys.contains(key) { continue }
            if let text = value as? String,
               secrets.contains(where: { !$0.isEmpty && text.contains($0) }) { continue }
            clean[key] = value
        }
        return clean
    }

    private static func contains(_ effects: [ReferralPageEffect], track name: String) -> Bool {
        effects.contains { effect in
            if case .track(let event, _) = effect { return event == name }
            return false
        }
    }

    /// The `state` property on page events. Stable strings, no payloads.
    static func name(of state: ReferralPageState) -> String {
        switch state {
        case .loading:             return "loading"
        case .notEnrolled:         return "not_enrolled"
        case .enrolling:           return "enrolling"
        case .active:              return "active"
        case .unlocked:            return "unlocked"
        case .unlockedPendingCode: return "unlocked_pending_code"
        case .redeemed:            return "redeemed"
        case .error:               return "error"
        }
    }

    // MARK: - Redeem URL

    /// The App Store's offer-code page for SpeakLife, prefilled (spec §5 J3.3).
    static let appStoreAppID = "1617492998"

    static func redeemURL(code: String) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "apps.apple.com"
        components.path = "/redeem"
        components.queryItems = [
            URLQueryItem(name: "ctx", value: "offercodes"),
            URLQueryItem(name: "id", value: appStoreAppID),
            URLQueryItem(name: "code", value: code),
        ]
        return components.url
    }
}

// MARK: - Live UIKit seams

@MainActor
final class SystemReferralURLOpener: ReferralURLOpening {
    static let shared = SystemReferralURLOpener()
    private init() {}

    func open(_ url: URL) async -> Bool {
        await UIApplication.shared.open(url)
    }
}

@MainActor
final class SystemReferralPasteboard: ReferralPasteboard {
    static let shared = SystemReferralPasteboard()
    private init() {}

    func copy(_ string: String) {
        UIPasteboard.general.string = string
    }
}
