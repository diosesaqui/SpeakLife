//
//  UserDefaultsReferralStore.swift
//  SpeakLife
//
//  Local state for the referral feature, and the Remote Config keys it reads.
//
//  Everything stored here is a CACHE or a once-ever flag. The server is the
//  truth for counts, targets and rewards (spec §2.2); a tampered value here can
//  at most change what this one screen shows until the next snapshot lands.
//

import Foundation
import SpeakLifeCore

// MARK: - Key-value store

/// `ReferralKeyValueStore` over `UserDefaults`, which is what the Core types
/// persist through in the app. Tests use `InMemoryReferralKeyValueStore`.
final class UserDefaultsReferralStore: ReferralKeyValueStore {

    static let shared = UserDefaultsReferralStore()

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func data(forKey key: String) -> Data? {
        defaults.data(forKey: key)
    }

    func set(_ data: Data?, forKey key: String) {
        if let data {
            defaults.set(data, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    func bool(forKey key: String) -> Bool {
        defaults.bool(forKey: key)
    }

    func set(_ value: Bool, forKey key: String) {
        defaults.set(value, forKey: key)
    }
}

// MARK: - Keys

enum ReferralKeys {
    /// Spec §9.1. Set the moment the page is presented automatically, and
    /// never cleared: the page does not come back on its own.
    static let autoShown = "referralAutoShown"
    /// Last-known `referrals/{uid}`, so the page opens instantly and offline.
    static let snapshotCache = ReferralSnapshot.cacheKey
    /// What the page has already told this person (`ReferralPageMemory`), so
    /// `referral_progress_seen` and `referral_reward_unlocked` fire once.
    static let pageMemory = "referralPageMemory"
    /// Set when an iCloud restore skipped onboarding. Such an install is not a
    /// new user and never claims (FE-CLM-12).
    static let onboardingSkipped = "referralOnboardingSkipped"
    /// Set when this device has seen the page reach `.redeemed`. The Profile
    /// row hides only after that (`ReferralEligibility.showsProfileRow`'s
    /// `rewardRedeemed`), so a D7 subscriber still holding an unredeemed
    /// code keeps a way back to it.
    static let rewardRedeemed = "referralRewardRedeemed"
}

// MARK: - Snapshot cache

/// The last snapshot the server sent, round-tripped through Codable.
///
/// Corrupt data reads as nil and is cleared, never a crash (FE-SNP-06).
enum ReferralSnapshotCache {

    static func load(from store: ReferralKeyValueStore) -> ReferralSnapshot? {
        guard let data = store.data(forKey: ReferralKeys.snapshotCache) else { return nil }
        guard let snapshot = ReferralSnapshot.fromCache(data) else {
            store.set(nil as Data?, forKey: ReferralKeys.snapshotCache)
            return nil
        }
        return snapshot
    }

    static func save(_ snapshot: ReferralSnapshot?, to store: ReferralKeyValueStore) {
        store.set(snapshot?.cacheData(), forKey: ReferralKeys.snapshotCache)
    }
}

// MARK: - Page memory

/// `ReferralPageMemory` persisted field by field, so the app does not depend on
/// the Core type being Codable.
enum ReferralPageMemoryStore {

    private struct Stored: Codable {
        var lastSeenCount: Int
        var rewardUnlockedSeen: Bool
        var lastRedeemTapAt: Date?
        var rewardRedeemed: Bool?
        var premiumAtRedeemTap: Bool?
    }

    static func load(from store: ReferralKeyValueStore) -> ReferralPageMemory {
        let stored = store.data(forKey: ReferralKeys.pageMemory)
            .flatMap { try? JSONDecoder().decode(Stored.self, from: $0) }
        return ReferralPageMemory(
            lastSeenCount: stored?.lastSeenCount ?? 0,
            rewardUnlockedSeen: stored?.rewardUnlockedSeen ?? false,
            lastRedeemTapAt: stored?.lastRedeemTapAt,
            rewardRedeemed: stored?.rewardRedeemed ?? false,
            premiumAtRedeemTap: stored?.premiumAtRedeemTap
        )
    }

    static func save(_ memory: ReferralPageMemory, to store: ReferralKeyValueStore) {
        let stored = Stored(lastSeenCount: memory.lastSeenCount,
                            rewardUnlockedSeen: memory.rewardUnlockedSeen,
                            lastRedeemTapAt: memory.lastRedeemTapAt,
                            rewardRedeemed: memory.rewardRedeemed,
                            premiumAtRedeemTap: memory.premiumAtRedeemTap)
        store.set(try? JSONEncoder().encode(stored), forKey: ReferralKeys.pageMemory)
    }
}

// MARK: - Remote Config

/// The referral Remote Config values, read from any `FeatureFlagProviding`.
///
/// A value type rather than statics so `ReferralViewModel` can be handed a
/// `StaticFeatureFlags` in tests. The app reads it through
/// `DefaultFeatureFlags.shared`, which AppDelegate wires to Remote Config.
/// Defaults here must match the in-app defaults in AppDelegate (spec §12).
struct ReferralConfig {

    /// Off by default. Hides every referral ENTRY POINT. It never hides a
    /// reward somebody already earned (FE-FLG-02), and it never stops link
    /// capture or claims (FE-FLG-03): the server has its own switch, and a
    /// friend must not be lost to a client flag.
    let enabled: Bool

    /// Off by default. Adds the "Or invite N friends" link to the hard paywall
    /// (spec D4).
    let onHardPaywall: Bool

    /// The share copy, with `{link}` standing in for the link.
    let shareTemplate: String

    /// The host referral links are minted on. Read the `StandLink.shareHost`
    /// warning before ever changing it.
    let linkDomain: String

    /// The target to SHOW before somebody has a record: the not-enrolled page
    /// and the hard-paywall link. Display only.
    ///
    /// Once they enroll, the number comes from their own record, where the
    /// server locked it at enrollment (spec D3), and this is never read for
    /// them again. Keep it equal to `referralConfig/current.target` so the
    /// promise on the first screen is the one the server then keeps.
    ///
    /// Read as a string because the flag seam has no integer accessor. Anything
    /// that is not a positive integer falls back to the server's own default.
    let displayTarget: Int

    init(flags: FeatureFlagProviding) {
        enabled = flags.bool(ReferralConfigKey.enabled, default: false)
        onHardPaywall = flags.bool(ReferralConfigKey.onHardPaywall, default: false)
        let template = flags.string(ReferralConfigKey.shareText,
                                    default: ReferralConfigKey.defaultShareText)
        shareTemplate = template.isEmpty ? ReferralConfigKey.defaultShareText : template
        let domain = flags.string(ReferralConfigKey.linkDomain,
                                  default: ReferralConfigKey.defaultLinkDomain)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        linkDomain = domain.isEmpty ? ReferralConfigKey.defaultLinkDomain : domain
        let raw = flags.string(ReferralConfigKey.displayTarget,
                               default: ReferralConfigKey.defaultDisplayTarget)
        if let value = Int(raw.trimmingCharacters(in: .whitespaces)), value > 0 {
            displayTarget = value
        } else {
            displayTarget = Int(ReferralConfigKey.defaultDisplayTarget) ?? 5
        }
    }

    static var current: ReferralConfig { ReferralConfig(flags: DefaultFeatureFlags.shared) }
}

/// Same shape as `FeatureFlag.standTogetherEnabled`, for call sites that only
/// need the switches.
extension FeatureFlag {
    static var referralYearFreeEnabled: Bool { ReferralConfig.current.enabled }
    static var referralOnHardPaywall: Bool { ReferralConfig.current.onHardPaywall }
}

enum ReferralConfigKey {
    static let enabled = "referralYearFreeEnabled"
    static let onHardPaywall = "referralOnHardPaywall"
    static let shareText = "referralShareText"
    static let linkDomain = "referralLinkDomain"
    static let displayTarget = "referralDisplayTarget"
    static let defaultDisplayTarget = "5"

    static let defaultShareText = ReferralShareText.defaultTemplate
    static let defaultLinkDomain = "speaklife.app.link"
}
