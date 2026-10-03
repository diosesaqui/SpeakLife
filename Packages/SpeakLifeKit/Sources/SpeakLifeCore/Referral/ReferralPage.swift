//
//  ReferralPage.swift
//  SpeakLifeCore
//
//  The referral page's state machine (spec §9.3, FE TDD §6):
//  (state, event, memory, isPremium) → (state, effects).
//
//  The view model feeds it events and performs its effects: calling the
//  service, presenting the share sheet, opening the redeem URL, tracking
//  analytics, persisting `ReferralPageMemory`. The view only switches on the
//  state. Nothing here touches the network, a clock or UserDefaults.
//
//  Rules this file owns:
//   - The server always wins. A server snapshot replaces whatever is shown,
//     even a lower count. A cached snapshot only fills the empty page while
//     loading.
//   - While enrolling, snapshots are ignored, so the enroll result is the one
//     that lands and the share sheet opens exactly once.
//   - Analytics effects never carry a referral code, a reward code or a uid.
//     The VM adds `entry` and `days_since_enrolled`, which it alone knows.
//

import Foundation

public enum ReferralPageState: Equatable {
    case loading
    case notEnrolled
    case enrolling
    case active(count: Int, target: Int, code: String)
    case unlocked(code: String, reward: ReferralReward, alreadyPremium: Bool)
    case unlockedPendingCode
    case redeemed
    case error(retryable: Bool)
}

public enum ReferralPageEvent: Equatable {
    case snapshotLoaded(ReferralSnapshot?, fromCache: Bool)
    case inviteTapped
    case retryTapped
    case enrollSucceeded(ReferralSnapshot)
    case enrollFailed(retryable: Bool)
    case redeemTapped(at: Date)
    case premiumChanged(isPremium: Bool, at: Date)
    case reissueSucceeded(ReferralReward)
    case reissueFailed(exhausted: Bool)
}

public enum ReferralPageEffect: Equatable {
    case enroll
    case presentShareSheet(code: String)
    /// Carries the reward (offer) code for the redeem URL. Not analytics.
    case openRedeem(code: String)
    case track(event: String, properties: [String: String])
    case markRewardUnlockedSeen
}

/// What the page remembers across launches. The VM persists it after every
/// reduce.
public struct ReferralPageMemory: Equatable {
    /// Highest count a server snapshot has shown. Never lowered, so a stale or
    /// corrected snapshot cannot re-fire `referral_progress_seen`.
    public var lastSeenCount: Int
    /// `referral_reward_unlocked` has fired on this install.
    public var rewardUnlockedSeen: Bool
    public var lastRedeemTapAt: Date?
    /// Set only by an observed redemption: premium turning ON within the
    /// attribution window of a redeem tap. Being premium after a tap is not
    /// enough (a D7 subscriber who backs out of Apple's sheet still holds an
    /// unredeemed code).
    public var rewardRedeemed: Bool

    public init(lastSeenCount: Int = 0, rewardUnlockedSeen: Bool = false, lastRedeemTapAt: Date? = nil,
                rewardRedeemed: Bool = false) {
        self.lastSeenCount = lastSeenCount
        self.rewardUnlockedSeen = rewardUnlockedSeen
        self.lastRedeemTapAt = lastRedeemTapAt
        self.rewardRedeemed = rewardRedeemed
    }
}

public enum ReferralPageReducer {

    /// `isPremium` turning true within this long of a redeem tap counts as the
    /// redemption (spec §11 `referral_reward_redeemed`).
    public static let redeemAttributionWindow: TimeInterval = 30 * 60

    public enum AnalyticsEvent {
        public static let progressSeen = "referral_progress_seen"
        public static let rewardUnlocked = "referral_reward_unlocked"
        public static let redeemTapped = "referral_redeem_tapped"
        public static let rewardRedeemed = "referral_reward_redeemed"
        public static let reissueRequested = "referral_reissue_requested"
    }

    public static func reduce(state: ReferralPageState,
                              event: ReferralPageEvent,
                              memory: inout ReferralPageMemory,
                              isPremium: Bool) -> (ReferralPageState, [ReferralPageEffect]) {
        switch event {

        case .snapshotLoaded(let snapshot, let fromCache):
            return snapshotLoaded(snapshot, fromCache: fromCache, state: state, memory: &memory, isPremium: isPremium)

        case .inviteTapped:
            switch state {
            case .notEnrolled:
                return (.enrolling, [.enroll])
            case .active(_, _, let code):
                return (state, [.presentShareSheet(code: code)])
            default:
                // Enrolling: no double enroll, no double sheet (FE-PAG-09).
                return (state, [])
            }

        case .retryTapped:
            if case .error(let retryable) = state, retryable {
                return (.enrolling, [.enroll])
            }
            return (state, [])

        case .enrollSucceeded(let snapshot):
            guard case .enrolling = state else { return (state, []) }
            let result = applySnapshot(snapshot, memory: &memory, isPremium: isPremium, fromServer: true)
            var effects = result.1
            if case .active(_, _, let code) = result.0 {
                effects.append(.presentShareSheet(code: code))
            }
            return (result.0, effects)

        case .enrollFailed(let retryable):
            guard case .enrolling = state else { return (state, []) }
            return (.error(retryable: retryable), [])

        case .redeemTapped(let at):
            guard case .unlocked(_, let reward, _) = state else { return (state, []) }
            memory.lastRedeemTapAt = at
            return (state, [
                .track(event: AnalyticsEvent.redeemTapped, properties: [:]),
                .openRedeem(code: reward.code),
            ])

        case .premiumChanged(let nowPremium, let at):
            guard case .unlocked(let code, let reward, let wasPremium) = state else { return (state, []) }
            // Only a change from not-premium to premium can be the redemption.
            if nowPremium, !wasPremium, let tap = memory.lastRedeemTapAt {
                let elapsed = at.timeIntervalSince(tap)
                if elapsed >= 0 && elapsed <= redeemAttributionWindow {
                    memory.rewardRedeemed = true
                    return (.redeemed, [.track(event: AnalyticsEvent.rewardRedeemed, properties: [:])])
                }
            }
            return (.unlocked(code: code, reward: reward, alreadyPremium: nowPremium), [])

        case .reissueSucceeded(let newReward):
            guard case .unlocked(let code, _, let alreadyPremium) = state else { return (state, []) }
            return (.unlocked(code: code, reward: newReward, alreadyPremium: alreadyPremium),
                    [.track(event: AnalyticsEvent.reissueRequested, properties: ["result": "success"])])

        case .reissueFailed(let exhausted):
            guard case .unlocked = state else { return (state, []) }
            // The old code stays on screen. The VM shows "Contact support".
            return (state, [.track(event: AnalyticsEvent.reissueRequested,
                                   properties: ["result": exhausted ? "exhausted" : "error"])])
        }
    }

    // MARK: - Snapshots

    private static func snapshotLoaded(_ snapshot: ReferralSnapshot?,
                                       fromCache: Bool,
                                       state: ReferralPageState,
                                       memory: inout ReferralPageMemory,
                                       isPremium: Bool) -> (ReferralPageState, [ReferralPageEffect]) {
        // The enroll result decides what lands next, not a racing listener.
        if case .enrolling = state { return (state, []) }

        let isLoading: Bool
        if case .loading = state { isLoading = true } else { isLoading = false }

        if fromCache {
            // A cache only fills an empty page. It never overrides the server.
            guard isLoading else { return (state, []) }
            guard let snapshot = snapshot else { return (.notEnrolled, []) }
            return applySnapshot(snapshot, memory: &memory, isPremium: isPremium, fromServer: false)
        }

        guard let snapshot = snapshot else {
            // No record on the server. An error stays put so its Retry remains.
            if case .error = state { return (state, []) }
            return (.notEnrolled, [])
        }
        return applySnapshot(snapshot, memory: &memory, isPremium: isPremium, fromServer: true)
    }

    private static func applySnapshot(_ snapshot: ReferralSnapshot,
                                      memory: inout ReferralPageMemory,
                                      isPremium: Bool,
                                      fromServer: Bool) -> (ReferralPageState, [ReferralPageEffect]) {
        var effects: [ReferralPageEffect] = []

        let shown = snapshot.displayCount
        let target = snapshot.effectiveTarget
        if fromServer {
            if shown > memory.lastSeenCount {
                effects.append(.track(event: AnalyticsEvent.progressSeen,
                                      properties: ["count": String(shown), "target": String(target)]))
                memory.lastSeenCount = shown
            }
        }

        let next: ReferralPageState
        switch snapshot.status {
        case .active:
            next = .active(count: shown, target: target, code: snapshot.code)
        case .unlocked:
            if let reward = snapshot.reward {
                if memory.rewardRedeemed {
                    next = .redeemed
                } else {
                    next = .unlocked(code: snapshot.code, reward: reward, alreadyPremium: isPremium)
                }
            } else {
                // Unlocked without a code is the pending-code case in all but name.
                next = .unlockedPendingCode
            }
        case .unlockedPendingCode:
            next = .unlockedPendingCode
        }

        if snapshot.status != .active && !memory.rewardUnlockedSeen {
            memory.rewardUnlockedSeen = true
            effects.append(.track(event: AnalyticsEvent.rewardUnlocked, properties: [:]))
            effects.append(.markRewardUnlockedSeen)
        }

        return (next, effects)
    }
}
