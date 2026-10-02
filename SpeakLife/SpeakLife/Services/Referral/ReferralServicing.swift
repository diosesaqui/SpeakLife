//
//  ReferralServicing.swift
//  SpeakLife
//
//  The seams for "invite friends, get a year free". Spec:
//  docs/REFERRAL_YEAR_FREE_SPEC.md, test plan docs/REFERRAL_FE_TDD.md §1.
//
//  Every decision the feature makes lives in SpeakLifeCore (`ReferralPageReducer`,
//  `ReferralClaimPolicy`, `ReferralEligibility`). What is left in the app is
//  I/O: Firebase, DeviceCheck, the share sheet, opening a URL. Each of those
//  sits behind a protocol here so `ReferralViewModel` and
//  `ReferralClaimCoordinator` run under XCTest with fakes and no network.
//
//  ⚠️ THE SERVER DECIDES EVERYTHING THAT MATTERS (spec §2.2). Nothing behind
//  these protocols ever writes a count, a target or a reward. If a write shows
//  up here, `firestore.rules` will reject it, and that is correct.
//

import Foundation
import SpeakLifeCore

// MARK: - Backend

/// The three callables in functions/referral.js plus the owner's live record.
@MainActor
protocol ReferralServicing: AnyObject {

    /// `getOrCreateReferral`. Idempotent server-side: calling it twice never
    /// mints a second code, so a retry after a timeout is always safe.
    func getOrCreate(deviceToken: String?, isDevelopment: Bool) async throws -> ReferralSnapshot

    /// `claimReferral`. Throws only for transport and callable errors; every
    /// answer the server actually gives comes back as an outcome.
    func claim(_ request: ReferralClaimRequest) async throws -> ReferralClaimOutcome

    /// `reissueReferralReward`. Once per referrer, ever (spec §8.3).
    func reissue() async throws -> ReferralReward

    /// Live `referrals/{uid}`. `nil` means the document does not exist yet.
    /// The handler is called on the main actor.
    func observe(uid: String, onChange: @escaping @MainActor (ReferralSnapshot?) -> Void) -> ReferralObservation
}

/// Returned by `observe` so the caller owns the listener's lifetime.
@MainActor
protocol ReferralObservation: AnyObject {
    func cancel()
}

/// Everything `claimReferral` needs. `capturedAt` goes over the wire as
/// milliseconds since 1970, which is what the server's window check reads.
struct ReferralClaimRequest: Equatable {
    let code: String
    let capturedAt: Date
    let source: ReferralSource
    let deviceToken: String?
    let isDevelopment: Bool

    var payload: [String: Any] {
        var body: [String: Any] = [
            "code": code,
            "capturedAt": Int64((capturedAt.timeIntervalSince1970 * 1000).rounded()),
            "source": source.rawValue,
            "isDevelopment": isDevelopment,
        ]
        if let deviceToken { body["deviceToken"] = deviceToken }
        return body
    }
}

/// Callable failures, already sorted into what the app does about them.
///
/// Mapped from `FunctionsErrorCode` in `FirebaseReferralService` and nowhere
/// else, so the view model and the claim coordinator never import Firebase and
/// can be driven by a fake that throws these directly.
enum ReferralServiceError: Error, Equatable {
    /// `failed-precondition`: the server kill switch is off (spec D10). Not
    /// retryable from the page; the copy is "Not available right now".
    case serverDisabled
    /// `resource-exhausted`: throttled, or the one reissue is already spent.
    case exhausted
    /// `unauthenticated`.
    case unauthenticated
    /// `unavailable`, `deadline-exceeded`, or a URL error. Try again later.
    case unavailable
    /// The callable answered with something we could not read.
    case malformedResponse
    /// Anything else, with the wire reason for analytics.
    case other(String)

    /// Short and stable, for `reason` properties. Never carries a code or uid.
    var analyticsReason: String {
        switch self {
        case .serverDisabled:    return "failed_precondition"
        case .exhausted:         return "resource_exhausted"
        case .unauthenticated:   return "unauthenticated"
        case .unavailable:       return "unavailable"
        case .malformedResponse: return "malformed"
        case .other:             return "other"
        }
    }

    /// Wraps whatever was thrown. Already-mapped errors pass through; anything
    /// from URLSession reads as offline.
    static func wrap(_ error: Error) -> ReferralServiceError {
        if let mapped = error as? ReferralServiceError { return mapped }
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain { return .unavailable }
        return .other(ns.domain)
    }
}

// MARK: - Account

/// Wraps `StandAuthCoordinator.ensureAccount()`, which mints an anonymous
/// Firebase user on demand. It is the same account Stand uses: one person, one
/// uid, whichever feature asked first.
@MainActor
protocol ReferralAccountProviding: AnyObject {
    @discardableResult
    func ensureAccount() async throws -> String
    var currentUid: String? { get }
}

extension StandAuthCoordinator: ReferralAccountProviding {}

// MARK: - DeviceCheck

/// Wraps `DCDevice`. The token proves to the server that this is a real Apple
/// device and lets it read and set the two per-device bits (spec §7).
@MainActor
protocol DeviceTokenProviding: AnyObject {
    /// Nil when the device cannot produce one (simulator, unsupported, or
    /// Apple's service failed). Callers send the request without it rather
    /// than not sending it at all (BE-ENR-08).
    func token() async -> String?
    /// Which DeviceCheck environment the server must query with this token.
    var isDevelopment: Bool { get }
}

// MARK: - UIKit side effects

@MainActor
protocol ReferralURLOpening: AnyObject {
    /// True when the system accepted the URL.
    func open(_ url: URL) async -> Bool
}

@MainActor
protocol ReferralPasteboard: AnyObject {
    func copy(_ string: String)
}
