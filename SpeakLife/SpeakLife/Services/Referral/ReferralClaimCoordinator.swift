//
//  ReferralClaimCoordinator.swift
//  SpeakLife
//
//  The FRIEND side: somebody installs through a referrer's link or code, and
//  this app tells the server so the referrer's count can go up. Spec §5 J4 to
//  J6, §9.5; tests FE-CAP-*, FE-VM-10 to FE-VM-14.
//
//  Two halves, deliberately separate:
//
//   1. CAPTURE (`ReferralCapture`). A code arrives from a universal link
//      (`onOpenURL`), a deferred Branch link (`BranchAttribution.apply`), or
//      typing. It is stored as a pending referral and NOTHING is presented:
//      on a fresh install this runs before onboarding has started.
//
//   2. CLAIM (`ReferralClaimCoordinator`). Once onboarding has really finished,
//      and again on later foregrounds while the server says "retry later", the
//      pending code is sent. `ReferralClaimPolicy` (Core) decides when.
//
//  The friend never sees referral UI because of any of this, success or
//  failure (FE-CLM-08). They did not ask for it.
//
//  ⚠️ NOT GATED ON `referralYearFreeEnabled` (FE-FLG-03). The client flag hides
//  entry points; it must never lose a friend. The server has its own switch,
//  and a `disabled` answer keeps the code for later.
//

import Foundation
import SpeakLifeCore

// MARK: - Capture

/// What a referral link open turned into. The `outcome` on `referral_link_opened`.
enum ReferralLinkOpenOutcome: String, Equatable {
    case captured
    case existingUser = "existing_user"
    case alreadyPending = "already_pending"
    case invalid
}

/// Pure entry functions for every way a code arrives, shaped like
/// `BranchAttribution.attribution(from:)` so each is testable without Branch,
/// SwiftUI or a launch.
///
/// Nonisolated on purpose: `BranchAttribution.apply` runs inside Branch's
/// callback, which is not a main-actor context.
enum ReferralCapture {

    /// The one pending-referral store in the app. Capture and claim must share
    /// it, or "first capture wins" could be decided by two different objects.
    static let sharedStore = PendingReferralStore(store: UserDefaultsReferralStore.shared)

    /// `onOpenURL`. Nil when the URL is not a referral link at all, including
    /// every Stand link (FE-CAP-04): the path segment decides, never the host.
    @discardableResult
    static func handleOpenURL(_ url: URL,
                              isOnboarded: Bool,
                              store: PendingReferralStore = sharedStore,
                              analytics: AnalyticsTracking = AnalyticsService.shared) -> ReferralLinkOpenOutcome? {
        guard let code = ReferralLink.code(from: url) else { return nil }
        return capture(code: code, source: .universalLink, isOnboarded: isOnboarded,
                       store: store, analytics: analytics)
    }

    /// `BranchAttribution.apply`, for a DEFERRED link: the friend did not have
    /// the app, went through the App Store, and this is their first launch.
    ///
    /// Silent for somebody already onboarded. Branch calls back on every link
    /// open, and an installed app's link open ALSO reaches `onOpenURL`, which
    /// already records `existing_user`. Reporting it here too would count
    /// every existing-user tap twice.
    @discardableResult
    static func handleBranchParams(_ params: [String: Any],
                                   isOnboarded: Bool,
                                   store: PendingReferralStore = sharedStore,
                                   analytics: AnalyticsTracking = AnalyticsService.shared) -> ReferralLinkOpenOutcome? {
        guard !isOnboarded else { return nil }
        guard let code = ReferralLink.code(fromBranchParams: params) else { return nil }
        return capture(code: code, source: .deferred, isOnboarded: isOnboarded,
                       store: store, analytics: analytics)
    }

    /// The shared body. A link opened by somebody already onboarded is not a
    /// new install and is never captured (spec J6). A typed code is the
    /// exception: "Have an invite code?" only appears AFTER onboarding.
    @discardableResult
    static func capture(code: String,
                        source: ReferralSource,
                        isOnboarded: Bool,
                        store: PendingReferralStore,
                        analytics: AnalyticsTracking) -> ReferralLinkOpenOutcome {
        let outcome: ReferralLinkOpenOutcome
        if isOnboarded && source != .manual {
            outcome = .existingUser
        } else {
            switch store.capture(code: code, source: source) {
            case .captured:       outcome = .captured
            case .alreadyPending: outcome = .alreadyPending
            // A claim already went through on this install. Whatever this new
            // code is, they are not a new user any more.
            case .alreadyClaimed: outcome = .existingUser
            case .invalid:        outcome = .invalid
            }
        }
        analytics.track("referral_link_opened", parameters: [
            "source": source.rawValue,
            "outcome": outcome.rawValue,
        ])
        return outcome
    }

    /// `onboarding_finished` gains `referral_pending` (FE-VM-14), so the
    /// friend side of the funnel is visible in the A/B read.
    static func onboardingFinishedParameters(_ base: [String: Any],
                                             store: PendingReferralStore = sharedStore) -> [String: Any] {
        var parameters = base
        parameters["referral_pending"] = store.pending != nil
        return parameters
    }
}

// MARK: - Claim

/// What typing a code into "Have an invite code?" produced.
enum InviteCodeEntryResult: Equatable {
    /// Not a well-formed code. Inline error, nothing stored, button stays live.
    case invalid
    /// Stored and sent. The outcome is nil only if the policy held the claim.
    case submitted(ReferralClaimOutcome?)
    /// This install already has a pending or completed claim.
    case alreadyUsed
    /// Well formed, but no referrer has it (a typo). The server records
    /// nothing, the pending value is dropped, and the field stays usable.
    case notFound
}

@MainActor
final class ReferralClaimCoordinator {

    static let shared = ReferralClaimCoordinator(
        pending: ReferralCapture.sharedStore,
        keyValueStore: UserDefaultsReferralStore.shared,
        service: FirebaseReferralService.shared,
        account: StandAuthCoordinator.shared,
        deviceToken: DeviceCheckTokenProvider.shared,
        analytics: AnalyticsService.shared,
        now: { Date() }
    )

    let pending: PendingReferralStore
    private let keyValueStore: ReferralKeyValueStore
    private let service: ReferralServicing
    private let account: ReferralAccountProviding
    private let deviceToken: DeviceTokenProviding
    private let analytics: AnalyticsTracking
    private let now: () -> Date

    /// One claim at a time. `finishOnboarding` and the foreground that
    /// follows it can both arrive inside a second.
    private var inFlight = false

    init(pending: PendingReferralStore,
         keyValueStore: ReferralKeyValueStore,
         service: ReferralServicing,
         account: ReferralAccountProviding,
         deviceToken: DeviceTokenProviding,
         analytics: AnalyticsTracking,
         now: @escaping () -> Date) {
        self.pending = pending
        self.keyValueStore = keyValueStore
        self.service = service
        self.account = account
        self.deviceToken = deviceToken
        self.analytics = analytics
        self.now = now
    }

    var hasPending: Bool { pending.pending != nil }

    /// An iCloud restore skipped onboarding on this device. Such an install is
    /// a returning person, not a new one, and never claims (FE-CLM-12).
    func markOnboardingSkipped() {
        keyValueStore.set(true, forKey: ReferralKeys.onboardingSkipped)
    }

    var onboardingSkipped: Bool {
        keyValueStore.bool(forKey: ReferralKeys.onboardingSkipped)
    }

    /// Send the pending claim if `ReferralClaimPolicy` says now is the time.
    ///
    /// Called from `finishOnboarding()` and on every foreground. The policy is
    /// what stops this hammering the server (one attempt an hour), claiming
    /// mid-onboarding, or claiming on a debug replay.
    @discardableResult
    func claimIfNeeded(isOnboarded: Bool, isDebugReplay: Bool) async -> ReferralClaimOutcome? {
        guard !inFlight else { return nil }

        let decision = ReferralClaimPolicy.decide(
            pending: pending.pending,
            isOnboarded: isOnboarded,
            skippedOnboarding: onboardingSkipped,
            isDebugReplay: isDebugReplay,
            now: now())

        switch decision {
        case .wait:
            return nil
        case .discard:
            pending.clear()
            return nil
        case .claim:
            break
        }
        // `.claim` is only ever decided once onboarding has finished, so this
        // is the moment to stamp it (once; a later retry keeps the first).
        pending.markOnboarded()
        guard let current = pending.pending else { return nil }

        inFlight = true
        defer { inFlight = false }

        // The number of THIS call, read before `apply` touches the store.
        let attempt = current.attempts + 1

        var errorReason = ""
        let outcome: ReferralClaimOutcome
        do {
            // Friends are usually brand new, with no Firebase user yet
            // (FE-VM-11). The callable rejects an unauthenticated caller.
            try await account.ensureAccount()
            let token = await deviceToken.token()
            outcome = try await service.claim(ReferralClaimRequest(
                code: current.code,
                capturedAt: current.capturedAt,
                source: current.source,
                deviceToken: token,
                isDevelopment: deviceToken.isDevelopment,
                onboardedAt: current.onboardedAt))
        } catch {
            // Kept for the next foreground (FE-VM-12). Never shown to the
            // friend: they did not ask for any of this.
            errorReason = ReferralServiceError.wrap(error).analyticsReason
            outcome = .transportError
        }

        // Final outcomes close the claim for good; everything else records the
        // attempt, which is what the one-hour retry interval reads.
        ReferralClaimPolicy.apply(outcome, to: pending)

        let reason = Self.reason(for: outcome)
        analytics.track("referral_claim_result", parameters: [
            "outcome": outcome.analyticsValue,
            "reason": reason.isEmpty ? errorReason : reason,
            "source": current.source.rawValue,
            "attempt": attempt,
        ])
        return outcome
    }

    /// "Have an invite code?" (spec J5). The row only appears after
    /// onboarding, so the claim fires straight away (FE-CAP-06).
    func submitTypedCode(_ raw: String) async -> InviteCodeEntryResult {
        guard let code = ReferralLink.normalize(raw) else {
            analytics.track("referral_link_opened", parameters: [
                "source": ReferralSource.manual.rawValue,
                "outcome": ReferralLinkOpenOutcome.invalid.rawValue,
            ])
            return .invalid
        }
        let captured = ReferralCapture.capture(code: code, source: .manual, isOnboarded: true,
                                               store: pending, analytics: analytics)
        switch captured {
        case .captured:
            let outcome = await claimIfNeeded(isOnboarded: true, isDebugReplay: false)
            if case .rejected(let reason)? = outcome,
               ReferralClaimPolicy.discardRejectionReasons.contains(reason) {
                return .notFound
            }
            return .submitted(outcome)
        case .invalid:
            return .invalid
        case .alreadyPending, .existingUser:
            return .alreadyUsed
        }
    }

    /// The `reason` on `referral_claim_result`: the server's short reason
    /// string, or the unknown outcome's raw name. Never a code or a uid.
    static func reason(for outcome: ReferralClaimOutcome) -> String {
        switch outcome {
        case .rejected(let reason): return reason
        case .unknown(let raw):     return raw
        case .credited, .retryLater, .transportError: return ""
        }
    }
}
