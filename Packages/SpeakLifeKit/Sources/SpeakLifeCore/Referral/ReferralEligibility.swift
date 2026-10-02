//
//  ReferralEligibility.swift
//  SpeakLifeCore
//
//  Every "does this referral entry point appear?" decision (spec §9.1, §9.2,
//  D4, D10), as pure functions so no view has to branch on them.
//
//  Two rules worth knowing before changing anything here:
//   - The kill switch hides entry points, never an earned reward (FE-FLG-02).
//   - The friend-side capture and claim deliberately take no flag at all
//     (FE-FLG-03): the server decides, and a friend is never lost to a client
//     flag. See `PendingReferralStore` and `ReferralClaimPolicy`.
//

import Foundation

public struct ReferralEligibilityInput: Equatable {
    public var flagEnabled: Bool
    public var isDebugReplay: Bool
    public var converted: Bool
    public var hasFullAccess: Bool
    public var autoShownBefore: Bool
    public var hasPendingStandCode: Bool
    public var snapshot: ReferralSnapshot?

    public init(flagEnabled: Bool,
                isDebugReplay: Bool,
                converted: Bool,
                hasFullAccess: Bool,
                autoShownBefore: Bool,
                hasPendingStandCode: Bool,
                snapshot: ReferralSnapshot? = nil) {
        self.flagEnabled = flagEnabled
        self.isDebugReplay = isDebugReplay
        self.converted = converted
        self.hasFullAccess = hasFullAccess
        self.autoShownBefore = autoShownBefore
        self.hasPendingStandCode = hasPendingStandCode
        self.snapshot = snapshot
    }
}

public enum ReferralEligibility {

    /// The "Have an invite code?" row lives this long after first launch (J5).
    public static let inviteCodeEntryWindowDays = 14

    /// The automatic page after onboarding (§9.1). Pure: the caller sets the
    /// `referralAutoShown` flag only when it actually presents the page, so a
    /// Stand code taking this turn does not burn the referral page (FE-ENT-05).
    public static func shouldAutoShow(_ input: ReferralEligibilityInput) -> Bool {
        guard input.flagEnabled,
              !input.isDebugReplay,
              !input.converted,
              !input.hasFullAccess,
              !input.autoShownBefore,
              !input.hasPendingStandCode else { return false }
        if let snapshot = input.snapshot, snapshot.status != .active {
            // Already unlocked (or redeemed): nothing left to invite toward.
            return false
        }
        return true
    }

    /// The Profile "Get a year free" row (§9.2).
    ///
    /// - Redeemed (premium active and a reward exists): hidden (FE-ENT-12).
    /// - Reward earned (unlocked, with or without a code yet): shown even with
    ///   the flag off (FE-FLG-02).
    /// - Otherwise: follows the flag (FE-ENT-10, FE-ENT-11).
    public static func showsProfileRow(flagEnabled: Bool, snapshot: ReferralSnapshot?, isPremium: Bool) -> Bool {
        if let snapshot = snapshot {
            if isPremium && snapshot.reward != nil { return false }
            if snapshot.status == .unlocked || snapshot.status == .unlockedPendingCode { return true }
        }
        return flagEnabled
    }

    /// The Profile "Have an invite code?" row (J5): onboarded, within 14 days
    /// of first launch, nothing pending and no claim settled. An unknown first
    /// launch reads as an older install and hides the row.
    public static func showsInviteCodeEntry(isOnboarded: Bool,
                                            firstLaunchAt: Date?,
                                            now: Date,
                                            hasPending: Bool,
                                            isFinal: Bool) -> Bool {
        guard isOnboarded, !hasPending, !isFinal, let first = firstLaunchAt else { return false }
        let window = TimeInterval(inviteCodeEntryWindowDays) * 86_400
        return now.timeIntervalSince(first) <= window
    }

    /// The "Or invite friends for a free year" link on the hard paywall (D4).
    /// Soft paywalls rely on the automatic page instead.
    public static func showsHardPaywallLink(flagEnabled: Bool, hardPaywallFlag: Bool, isHardPaywall: Bool) -> Bool {
        flagEnabled && hardPaywallFlag && isHardPaywall
    }
}
