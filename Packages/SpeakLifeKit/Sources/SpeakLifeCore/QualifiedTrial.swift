//
//  QualifiedTrial.swift
//  SpeakLifeCore
//
//  The rule behind the "qualified trial" ad-optimization event: a free trial
//  that is still set to auto-renew a full day after it started.
//
//  Meta optimizes on whatever event it is handed, and raw trial starts include
//  everyone who cancels within the hour. Handing it the survivors instead points
//  campaigns at people who look like payers. The rule lives here, Foundation-only,
//  because RevenueCat's `CustomerInfo` cannot be constructed outside the SDK, so
//  the app-side tracker copies the fields it needs into a snapshot and the
//  decision itself stays testable.
//

import Foundation

/// The facts about one premium entitlement that decide whether its trial
/// qualifies. Mirrors the RevenueCat `EntitlementInfo` fields the tracker reads.
public struct TrialEntitlementSnapshot: Equatable, Sendable {
    public var productId: String
    public var isActive: Bool
    /// RevenueCat `periodType == .trial`. Intro-price and normal periods are false.
    public var isTrial: Bool
    public var willRenew: Bool
    public var isSandbox: Bool
    /// Start of the current trial period (RevenueCat `latestPurchaseDate`).
    public var trialStart: Date?

    public init(
        productId: String,
        isActive: Bool,
        isTrial: Bool,
        willRenew: Bool,
        isSandbox: Bool,
        trialStart: Date?
    ) {
        self.productId = productId
        self.isActive = isActive
        self.isTrial = isTrial
        self.willRenew = willRenew
        self.isSandbox = isSandbox
        self.trialStart = trialStart
    }
}

public enum QualifiedTrialRule {

    /// How long a trial must survive with auto-renew on before it counts.
    public static let productionDelay: TimeInterval = 24 * 60 * 60

    /// Debug builds only. Apple's sandbox compresses a one-week trial to about
    /// three minutes, so a 24h wait could never be observed there.
    public static let sandboxDelay: TimeInterval = 60

    /// True when the trial is live, still set to renew, old enough, and not yet
    /// reported. Sandbox purchases qualify only when `allowSandbox` is set, which
    /// keeps TestFlight (release config, sandbox store) out of the ad data.
    public static func qualifies(
        _ trial: TrialEntitlementSnapshot,
        now: Date,
        delay: TimeInterval,
        allowSandbox: Bool,
        alreadySent: Bool
    ) -> Bool {
        guard trial.isActive,
              trial.isTrial,
              trial.willRenew,
              allowSandbox || !trial.isSandbox,
              !alreadySent,
              let start = trial.trialStart
        else { return false }
        return now.timeIntervalSince(start) >= delay
    }

    /// Once-per-trial dedupe key. Keyed on the trial's start so a later trial
    /// (a different product, or a new start after a lapse) gets its own event.
    /// Nil when the start is unknown, which `qualifies` already rejects.
    public static func sentKey(for trial: TrialEntitlementSnapshot) -> String? {
        guard let start = trial.trialStart else { return nil }
        return "qualifiedTrialSent.\(trial.productId).\(Int(start.timeIntervalSince1970))"
    }
}
