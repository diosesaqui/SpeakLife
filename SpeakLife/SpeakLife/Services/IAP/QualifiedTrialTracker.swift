//
//  QualifiedTrialTracker.swift
//  SpeakLife
//

import Foundation
import RevenueCat

/// Reports a "qualified trial" once per trial: a free trial still set to
/// auto-renew at least 24h after it started. Meta campaigns optimize on it
/// (received as Add Payment Info) instead of raw trial starts, which include
/// people who cancel within the hour. The rule itself is `QualifiedTrialRule`
/// in SpeakLifeCore, where it is tested.
///
/// Client-side, so it fires on the first foreground or customer-info update
/// past the 24h mark. A trialist who never reopens the app is never counted.
/// The first-week coverage check against RevenueCat decides whether that gap
/// needs a server-side sender; never run both, or trials double count.
@MainActor
final class QualifiedTrialTracker {

    static let shared = QualifiedTrialTracker()

    #if DEBUG
    private let delay = QualifiedTrialRule.sandboxDelay
    private let allowSandbox = true
    #else
    private let delay = QualifiedTrialRule.productionDelay
    private let allowSandbox = false
    #endif

    private let defaults = UserDefaults.standard
    private var isChecking = false

    private init() {}

    /// Call on every foreground and every RevenueCat customer-info update.
    /// Cheap when nothing qualifies: it reads the cached info and returns.
    func evaluate(_ cached: CustomerInfo? = nil) async {
        // Purchases.shared traps if accessed before configure().
        guard Purchases.isConfigured, !isChecking else { return }
        isChecking = true
        defer { isChecking = false }

        let current: CustomerInfo
        if let cached {
            current = cached
        } else {
            guard let info = try? await Purchases.shared.customerInfo() else { return }
            current = info
        }
        guard qualifies(current) else { return }

        // The cache can predate a cancel made in Settings minutes ago, and a
        // cancelled trial reported as qualified is exactly the signal this
        // event exists to remove. Confirm against RevenueCat before firing.
        guard let fresh = try? await Purchases.shared.customerInfo(fetchPolicy: .fetchCurrent),
              qualifies(fresh),
              let trial = snapshot(fresh),
              let key = QualifiedTrialRule.sentKey(for: trial),
              let start = trial.trialStart
        else { return }

        // Set before logging so no re-entrant update can ever double-fire.
        defaults.set(true, forKey: key)
        AnalyticsService.shared.trackQualifiedTrial(
            productId: trial.productId,
            hoursSinceTrialStart: Int(Date().timeIntervalSince(start) / 3600)
        )
    }

    private func qualifies(_ info: CustomerInfo) -> Bool {
        guard let trial = snapshot(info) else { return false }
        let alreadySent = QualifiedTrialRule.sentKey(for: trial).map(defaults.bool(forKey:)) ?? false
        return QualifiedTrialRule.qualifies(
            trial,
            now: Date(),
            delay: delay,
            allowSandbox: allowSandbox,
            alreadySent: alreadySent
        )
    }

    private func snapshot(_ info: CustomerInfo) -> TrialEntitlementSnapshot? {
        guard let entitlement = info.entitlements[RevenueCatManager.premiumEntitlement] else { return nil }
        return TrialEntitlementSnapshot(
            productId: entitlement.productIdentifier,
            isActive: entitlement.isActive,
            isTrial: entitlement.periodType == .trial,
            willRenew: entitlement.willRenew,
            isSandbox: entitlement.isSandbox,
            trialStart: entitlement.latestPurchaseDate
        )
    }
}
