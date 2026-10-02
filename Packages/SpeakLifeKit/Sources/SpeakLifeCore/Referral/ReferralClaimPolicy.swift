//
//  ReferralClaimPolicy.swift
//  SpeakLifeCore
//
//  When the friend's app sends its claim, and what it does with the answer
//  (spec §7, J4 step 4). Pure functions: no store, no clock, no network.
//
//  The one-way rule: a friend is never dropped by anything the client is
//  unsure about. Only an answer the server meant as final (credited, or
//  rejected for a reason other than `disabled`) clears the pending code.
//  Transport errors, `retry_later` and outcome strings from a newer server
//  all keep it for a later launch.
//

import Foundation

public enum ReferralClaimOutcome: Equatable {
    case credited
    case rejected(reason: String)
    case retryLater
    /// An outcome string this build does not know. Kept, never dropped.
    case unknown(String)
    /// Network failure, timeout, `unavailable`, `unauthenticated`,
    /// `resource-exhausted`, or any thrown error.
    case transportError

    /// Maps the callable's `{ outcome, reason }` response.
    public static func parse(outcome: String?, reason: String?) -> ReferralClaimOutcome {
        let raw = outcome ?? ""
        switch raw {
        case "credited":
            return .credited
        case "rejected":
            return .rejected(reason: reason ?? "")
        case "retry_later":
            return .retryLater
        default:
            return .unknown(raw)
        }
    }

    /// The `outcome` analytics value. Never carries a code or uid.
    public var analyticsValue: String {
        switch self {
        case .credited: return "credited"
        case .rejected: return "rejected"
        case .retryLater: return "retry_later"
        case .unknown: return "unknown"
        case .transportError: return "error"
        }
    }
}

public enum ReferralClaimDecision: Equatable {
    /// Send the claim now.
    case claim
    /// Keep the pending code, try on a later launch or foreground.
    case wait
    /// Clear the pending code without claiming (expired, or not a new install).
    case discard
}

public enum ReferralClaimPolicy {

    /// No more than one attempt an hour, so a foreground never hammers the
    /// server (FE-CLM-05).
    public static let minRetryInterval: TimeInterval = 3600

    /// Rejection reasons the server does not record as final (spec §7 rows 1
    /// and 11). `disabled` is the kill switch; `retry_later` is listed as a
    /// belt-and-braces guard in case a server ever reports it as a rejection.
    public static let nonFinalRejectionReasons: Set<String> = ["disabled", "retry_later"]

    /// - Parameters:
    ///   - isOnboarded: `finishOnboarding()` has run, this launch or an earlier one.
    ///   - skippedOnboarding: an iCloud-restored user. Not a new install, so
    ///     their pending code is discarded.
    ///   - windowDays: the attribution window (D8). The store already hides an
    ///     expired value; this guards a value handed in from elsewhere.
    public static func decide(pending: PendingReferral?,
                              isOnboarded: Bool,
                              skippedOnboarding: Bool,
                              isDebugReplay: Bool,
                              now: Date,
                              windowDays: Int = 14) -> ReferralClaimDecision {
        guard let pending = pending else { return .wait }
        if isDebugReplay { return .wait }
        if skippedOnboarding { return .discard }
        if pending.isExpired(now: now, windowDays: windowDays) { return .discard }
        if !isOnboarded { return .wait }
        if let last = pending.lastAttemptAt,
           now.timeIntervalSince(last) < minRetryInterval {
            return .wait
        }
        return .claim
    }

    /// True when the pending code should be cleared and capture blocked for good.
    public static func shouldMarkFinal(after outcome: ReferralClaimOutcome) -> Bool {
        switch outcome {
        case .credited:
            return true
        case .rejected(let reason):
            return !nonFinalRejectionReasons.contains(reason)
        case .retryLater, .unknown, .transportError:
            return false
        }
    }

    /// Applies an outcome to the store: final answers mark it final, anything
    /// else records the attempt so the retry throttle starts counting.
    public static func apply(_ outcome: ReferralClaimOutcome, to store: PendingReferralStore) {
        if shouldMarkFinal(after: outcome) {
            store.markFinal()
        } else {
            store.recordAttempt()
        }
    }
}
