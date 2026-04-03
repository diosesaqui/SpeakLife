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

    func isPremiumActive(_ info: CustomerInfo) -> Bool {
        info.entitlements[Self.premiumEntitlement]?.isActive == true
    }

    func isDevotionalActive(_ info: CustomerInfo) -> Bool {
        info.entitlements[Self.devotionalEntitlement]?.isActive == true
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
}
