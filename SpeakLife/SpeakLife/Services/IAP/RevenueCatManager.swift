//
//  RevenueCatManager.swift
//  SpeakLife
//
//  Created via RevenueCat integration — feat/revenuecat-integration
//

import RevenueCat
import StoreKit

/// Thin singleton wrapper around Purchases SDK.
/// SubscriptionStore uses this to purchase, restore, and check entitlements.
final class RevenueCatManager {

    static let shared = RevenueCatManager()

    // MARK: - Entitlement IDs (match RC dashboard)
    static let premiumEntitlement   = "premium"
    static let devotionalEntitlement = "devotional"

    private init() {}

    // MARK: - Offerings

    /// Fetches current RC offering and returns all packages.
    func fetchOffering() async throws -> Offering? {
        let offerings = try await Purchases.shared.offerings()
        return offerings.current
    }

    // MARK: - Customer Info / Entitlements

    func customerInfo() async throws -> CustomerInfo {
        try await Purchases.shared.customerInfo()
    }

    /// Stable per-install identity RevenueCat uses for this user. The Bible Chat
    /// proxy keys server-side entitlement checks and usage metering off this.
    var appUserID: String {
        // Purchases.shared traps if accessed before configure(). Guard so chat
        // code paths in previews/tests/early-launch don't crash.
        Purchases.isConfigured ? Purchases.shared.appUserID : ""
    }

    func isPremiumActive(_ info: CustomerInfo) -> Bool {
        info.entitlements[Self.premiumEntitlement]?.isActive == true
    }

    func isDevotionalActive(_ info: CustomerInfo) -> Bool {
        info.entitlements[Self.devotionalEntitlement]?.isActive == true
    }

    /// True iff the premium entitlement is currently in a free-trial introductory
    /// period (RC's `periodType == .trial`). Returns false for normal paid
    /// periods, intro-pricing periods, and for users who don't have the
    /// entitlement at all. Used to distinguish "actually on trial right now"
    /// from "subscribed for any reason" so the trial-end push sequence can be
    /// gated correctly.
    func isPremiumInTrial(_ info: CustomerInfo) -> Bool {
        guard let entitlement = info.entitlements[Self.premiumEntitlement],
              entitlement.isActive else { return false }
        return entitlement.periodType == .trial
    }

    /// First time the user ever purchased premium, surviving cancel/resubscribe.
    /// Used to compute subscription anniversaries.
    func premiumOriginalPurchaseDate(_ info: CustomerInfo) -> Date? {
        info.entitlements[Self.premiumEntitlement]?.originalPurchaseDate
    }

    /// When Apple last failed to bill this subscriber, `nil` while billing is
    /// healthy. Apple keeps serving the entitlement through the billing-retry
    /// window, so the user still has access and hears nothing about it — which
    /// is exactly why a third of our trial cancellations arrive as
    /// `BILLING_ERROR` instead of a decision. Surfacing this is the difference
    /// between a lost subscriber and a two-tap card update.
    func billingIssueDetectedAt(_ info: CustomerInfo) -> Date? {
        let premium = info.entitlements[Self.premiumEntitlement]?.billingIssueDetectedAt
        let devotional = info.entitlements[Self.devotionalEntitlement]?.billingIssueDetectedAt
        // Earliest wins: the first failure is when the retry window started.
        return [premium, devotional].compactMap { $0 }.min()
    }

    // MARK: - Analytics Identity

    /// Reserved RevenueCat subscriber attribute naming the PostHog person this
    /// subscriber belongs to. RevenueCat's PostHog integration reads it when it
    /// forwards server-side lifecycle events.
    private static let postHogUserIDAttribute = "$posthogUserId"

    /// Last value we sent, so repeat launches don't re-post an unchanged
    /// attribute. In UserDefaults rather than memory because the pre-purchase
    /// call runs off the main actor — this keeps the check free of a mutable
    /// singleton property two threads could touch at once.
    private static let lastLinkedPostHogIDKey = "rc_linked_posthog_id"

    /// Stamps the PostHog distinct id onto the RevenueCat subscriber so the
    /// lifecycle events RC forwards server-side (`rc_trial_started_event`,
    /// `rc_trial_converted_event`, `rc_cancellation_event`, `expiration_event`,
    /// `billing_issue_event`) land on the SAME PostHog person as the in-app
    /// events.
    ///
    /// Without it those events arrive under a `$RCAnonymousID:…` distinct id —
    /// a separate person with no app history — so a trial start can never be
    /// joined to its own outcome. That break is why trial→paid conversion
    /// cannot be attributed to an onboarding variant, a paywall variant, or a
    /// segment today.
    ///
    /// Deliberately an attribute rather than `Purchases.logIn(_:)`: the RC app
    /// user id is what the Bible Chat proxy keys server-side entitlement checks
    /// and usage metering off (see `appUserID`), so changing it would need its
    /// own migration. This carries the link without touching that identity.
    /// - Parameter force: re-send even when the id is unchanged. Used on the
    ///   purchase path, where the cost of a redundant attribute write is nothing
    ///   and the cost of a subscriber created without the link is an unjoinable
    ///   trial — the exact failure this method exists to prevent.
    func linkAnalyticsIdentity(distinctID: String?, force: Bool = false) {
        guard Purchases.isConfigured,
              let distinctID, !distinctID.isEmpty else { return }
        let defaults = UserDefaults.standard
        if !force, defaults.string(forKey: Self.lastLinkedPostHogIDKey) == distinctID { return }
        defaults.set(distinctID, forKey: Self.lastLinkedPostHogIDKey)
        Purchases.shared.attribution.setAttributes([Self.postHogUserIDAttribute: distinctID])
    }

    // MARK: - Purchase

    /// Purchase by RC Package (preferred — used when loading from offerings).
    func purchase(package: RevenueCat.Package) async throws -> CustomerInfo {
        let result = try await Purchases.shared.purchase(package: package)
        return result.customerInfo
    }

    /// Purchase by StoreKit Product — used when views pass a `StoreKit.Product` directly.
    /// Looks up the matching RC Package from current offerings.
    func purchase(storeProduct: StoreKit.Product) async throws -> CustomerInfo {
        // Fetch current offering to find the matching package
        let offerings = try await Purchases.shared.offerings()
        let allPackages = offerings.current?.availablePackages ?? []

        if let match = allPackages.first(where: { $0.storeProduct.productIdentifier == storeProduct.id }) {
            let result = try await Purchases.shared.purchase(package: match)
            return result.customerInfo
        }

        // Fallback: purchase directly via StoreKit Product wrapper
        let rcProduct = try await Purchases.shared.products([storeProduct.id]).first
        guard let rcProduct else {
            throw NSError(domain: "RevenueCat", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Product not found in RC: \(storeProduct.id)"])
        }
        let result = try await Purchases.shared.purchase(product: rcProduct)
        return result.customerInfo
    }

    /// Purchase by product ID string — used by `purchaseWithID()`.
    func purchase(productID: String) async throws -> CustomerInfo {
        let offerings = try await Purchases.shared.offerings()
        let allPackages = offerings.current?.availablePackages ?? []

        if let match = allPackages.first(where: { $0.storeProduct.productIdentifier == productID }) {
            let result = try await Purchases.shared.purchase(package: match)
            return result.customerInfo
        }

        let products = try await Purchases.shared.products([productID])
        guard let rcProduct = products.first else {
            throw NSError(domain: "RevenueCat", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Product not found in RC: \(productID)"])
        }
        let result = try await Purchases.shared.purchase(product: rcProduct)
        return result.customerInfo
    }

    // MARK: - Restore

    func restorePurchases() async throws -> CustomerInfo {
        try await Purchases.shared.restorePurchases()
    }

    // MARK: - Offer Codes

    /// Presents Apple's offer-code redemption sheet. Apple gives no success
    /// callback; the redeemed transaction is picked up automatically by the
    /// Purchases delegate (see SubscriptionStore.setupRCCustomerInfoListener).
    @MainActor
    func presentOfferCodeRedemption() {
        Purchases.shared.presentCodeRedemptionSheet()
    }
}
