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

    // MARK: - Attribution

    /// Forwards the acquisition channel to RevenueCat's reserved subscriber
    /// attributes.
    ///
    /// Worth doing separately from the PostHog person property because RC's own
    /// PostHog integration stamps these onto the revenue events it sends
    /// server-side. Renewals that happen while the app is shut never touch this
    /// process, so without this they arrive with no channel on them and drop out
    /// of every channel LTV number.
    ///
    /// Safe to call repeatedly — RC only writes changed attributes.
    func setAttribution(
        mediaSource: String?,
        campaign: String?,
        adGroup: String?,
        creative: String?,
        keyword: String?
    ) {
        // Purchases.shared traps if accessed before configure().
        guard Purchases.isConfigured else { return }

        let attribution = Purchases.shared.attribution
        if let mediaSource = mediaSource { attribution.setMediaSource(mediaSource) }
        if let campaign = campaign { attribution.setCampaign(campaign) }
        if let adGroup = adGroup { attribution.setAdGroup(adGroup) }
        if let creative = creative { attribution.setCreative(creative) }
        if let keyword = keyword { attribution.setKeyword(keyword) }
    }

    /// Re-sends the device identifiers RevenueCat's Meta integration matches on.
    ///
    /// AppDelegate.init already calls this, but that runs before the ATT prompt
    /// is answered, so the IDFA it sends is zeroed for everyone. Call again once
    /// ATT resolves, whichever way it went.
    func collectDeviceIdentifiers() {
        guard Purchases.isConfigured else { return }
        Purchases.shared.attribution.collectDeviceIdentifiers()
    }

    /// Pushes PostHog's distinct id into RevenueCat as the reserved
    /// `$posthogUserId` attribute.
    ///
    /// This is what makes RevenueCat the owner of revenue actually work. RC's
    /// PostHog integration fires server-side, on renewals and trial
    /// conversions that happen while the app is shut, and it chooses which
    /// PostHog person to attach the event to by reading this attribute. The
    /// app's own `aliasUser` call joins identities from the client side, which
    /// covers events the app itself sends and nothing else — without this,
    /// server-side revenue keeps landing on RevenueCat-keyed person records
    /// with no behaviour on them, which is the 78-vs-3,914 zero-overlap split
    /// GrowthMetrics documents.
    ///
    /// Safe to call repeatedly — RC only writes changed attributes.
    func setPostHogUserID(_ distinctId: String) {
        guard Purchases.isConfigured, !distinctId.isEmpty else { return }
        Purchases.shared.attribution.setAttributes(["$posthogUserId": distinctId])
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

    /// Store product id behind the active premium entitlement, or nil when
    /// premium is not active. Reflects renewals, restores, offer codes and
    /// App Store-side plan changes, none of which pass through `purchase`.
    func activePremiumProductID(_ info: CustomerInfo) -> String? {
        guard let entitlement = info.entitlements[Self.premiumEntitlement],
              entitlement.isActive,
              !entitlement.productIdentifier.isEmpty else { return nil }
        return entitlement.productIdentifier
    }

    /// True when this user has held premium before (trial or paid) and it is no
    /// longer active. `entitlements[id]` reads from `all`, which keeps expired
    /// entitlements, so a user who never subscribed returns nil and is not lapsed.
    func isPremiumLapsed(_ info: CustomerInfo) -> Bool {
        guard let entitlement = info.entitlements[Self.premiumEntitlement] else { return false }
        return !entitlement.isActive
    }

    /// True when the lapsed premium entitlement's last period was the free
    /// trial, i.e. the user ended a trial without ever paying.
    func lapsedFromTrial(_ info: CustomerInfo) -> Bool {
        guard let entitlement = info.entitlements[Self.premiumEntitlement],
              !entitlement.isActive else { return false }
        return entitlement.periodType == .trial
    }

    // MARK: - Win-Back Offers

    /// The first Apple win-back offer this user is eligible for on `product`,
    /// or nil. Win-back offers are iOS 18+ and StoreKit 2 only; eligibility
    /// rules (minimum paid duration, time since lapse) are set per offer in
    /// App Store Connect, so a trialist who never paid is usually not eligible.
    func eligibleWinBackOffer(for product: StoreKit.Product) async -> WinBackOffer? {
        guard Purchases.isConfigured, #available(iOS 18.0, *) else { return nil }
        do {
            guard let rcProduct = try await Purchases.shared.products([product.id]).first else { return nil }
            return try await Purchases.shared.eligibleWinBackOffers(forProduct: rcProduct).first
        } catch {
            print("RC win-back eligibility failed: \(error)")
            return nil
        }
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

    /// What the Apple sheet actually did. `userCancelled` is RevenueCat's own
    /// signal and the only honest one: inferring a cancel from "no entitlement
    /// afterwards" also counted Ask-to-Buy and entitlement misconfigurations as
    /// cancels, which inflated the sheet-cancel rate the paywall work is aimed at.
    struct StorePurchaseResult {
        let customerInfo: CustomerInfo
        let userCancelled: Bool
    }

    /// Purchase by StoreKit Product — used when views pass a `StoreKit.Product` directly.
    /// Looks up the matching RC Package from current offerings.
    /// - Parameter willPresentSheet: called immediately before Apple's sheet is
    ///   requested, after the offerings lookup, so a lookup failure is never
    ///   counted as a sheet that opened.
    /// - Parameter winBackOffer: an Apple win-back offer from
    ///   `eligibleWinBackOffers(for:)`, applied to the purchase on iOS 18+.
    ///   Ignored below iOS 18, where the user pays the regular price.
    func purchase(storeProduct: StoreKit.Product,
                  winBackOffer: WinBackOffer? = nil,
                  willPresentSheet: () -> Void = {}) async throws -> StorePurchaseResult {
        if let winBackOffer, #available(iOS 18.0, *) {
            guard let rcProduct = try await Purchases.shared.products([storeProduct.id]).first else {
                throw NSError(domain: "RevenueCat", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "Product not found in RC: \(storeProduct.id)"])
            }
            let params = PurchaseParams.Builder(product: rcProduct)
                .with(winBackOffer: winBackOffer)
                .build()
            willPresentSheet()
            let result = try await Purchases.shared.purchase(params)
            return StorePurchaseResult(customerInfo: result.customerInfo, userCancelled: result.userCancelled)
        }

        // Fetch current offering to find the matching package
        let offerings = try await Purchases.shared.offerings()
        let allPackages = offerings.current?.availablePackages ?? []

        if let match = allPackages.first(where: { $0.storeProduct.productIdentifier == storeProduct.id }) {
            willPresentSheet()
            let result = try await Purchases.shared.purchase(package: match)
            return StorePurchaseResult(customerInfo: result.customerInfo, userCancelled: result.userCancelled)
        }

        // Fallback: purchase directly via StoreKit Product wrapper
        let rcProduct = try await Purchases.shared.products([storeProduct.id]).first
        guard let rcProduct else {
            throw NSError(domain: "RevenueCat", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Product not found in RC: \(storeProduct.id)"])
        }
        willPresentSheet()
        let result = try await Purchases.shared.purchase(product: rcProduct)
        return StorePurchaseResult(customerInfo: result.customerInfo, userCancelled: result.userCancelled)
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
