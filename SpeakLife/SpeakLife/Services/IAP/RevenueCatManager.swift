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

    /// Current premium state as a plain Bool, safe to call from anywhere.
    ///
    /// For the AI proxies' `isPremiumClaim`: they are not main-actor bound and
    /// have no route to `SubscriptionStore`, and they must not import
    /// RevenueCat just to name `CustomerInfo`. False on any doubt (Purchases
    /// not configured, lookup failed) — the claim is only a hint anyway, since
    /// the Cloud Function re-checks with RevenueCat server-side and its answer
    /// wins whenever RC responds.
    func isPremiumActiveNow() async -> Bool {
        guard Purchases.isConfigured else { return false }
        guard let info = try? await Purchases.shared.customerInfo() else { return false }
        return isPremiumActive(info)
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
