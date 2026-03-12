//
//  SubscriptionStore.swift
//  SpeakLife
//
//  Created by Riccardo Washington on 12/17/22.
//  Updated: RevenueCat integration — purchase/restore/entitlements via RC,
//           StoreKit products still used for price display in views.
//

import StoreKit
import Combine
import FirebaseAnalytics
import FacebookCore
import SwiftUI
import FirebaseRemoteConfig
import RevenueCat

// Keep these typealiases only for the Product extension at the bottom of the file.
// Transaction is no longer used directly — RC manages the transaction lifecycle.
typealias RenewalInfo = StoreKit.Product.SubscriptionInfo.RenewalInfo
typealias RenewalState = StoreKit.Product.SubscriptionInfo.RenewalState

public enum StoreError: Error {
    case failedVerification
}
var yearlyID = ""
var monthlyID = ""
var discountID = ""
let currentYearlyID = "SpeakLife1YR19"
let currentMonthlyID = "SpeakLife1MO4"
let currentMonthlyPremiumID = "SpeakLife1MO9"
let currentPremiumID = "SpeakLife1YR29"
let lifetimeID = "SpeakLifeLifetime"
let devotionals = "Devotionals30SL"
let weeklyID = "SpeakLife1Wk5"
final class SubscriptionStore: ObservableObject {

    @Published var isPremium: Bool = false
    @Published private(set) var subscriptions: [Product] = []
    @Published private(set) var nonConsumables: [Product] = [] // New list for non-consumables
    @Published private(set) var purchasedSubscriptions: [Product] = []
    @Published private(set) var purchasedNonConsumables: [Product] = [] // New list for purchased non-consumables
    @Published private(set) var subscriptionGroupStatus: RenewalState?
    @Published var currentOfferedDiscount: Product? = nil
    @Published var currentOfferedLifetime: Product? = nil
    @Published var currentOfferedMonthly: Product? = nil
    @Published var currentOfferedPremium: Product? = nil
    @Published var currentOfferedPremiumMonthly: Product? = nil
    @Published var currentOfferedWeekly: Product? = nil
    @Published var currentOfferedDevotionalPremium: Product? = nil
    @Published var isInDevotionalPremium = false
    @AppStorage("lastDevotionalPurchase") var lastDevotionalPurchaseDate: Date?
    
    // MARK: - Email Capture / Confirmation After Purchase
    @Published var showEmailCaptureAfterPurchase = false   // premium, no email stored
    @Published var showEmailConfirmAfterPurchase = false   // premium, email already stored → confirm + tag post_purchase

    @Published var showDevotionalSubscription = false
    @Published var showOneTimeSubscription = false
    @Published var showSubscription = false
    @Published var showSubscriptionFirst = false
    @Published var showYearlyOption = false
    @Published var onlyShowYearly = false
    @Published var showMostPopularBadge = false
    @Published var showTestimonyTab = false
    @Published var offerFreeTrial = false
    
    // MARK: - Enhanced Onboarding Toggle
    @Published var useEnhancedOnboarding = false
    
    // MARK: - Spiritual Warfare Onboarding Toggle
    @Published var useSpiritualWarfareOnboarding: Bool? = false
    
    // MARK: - AI Feature Flag
    @Published var enableAIFeatures = false
    
    // MARK: - High Conversion Paywall Flag
    @Published var useHighConversionPaywall = false
    
    @Published var yearlySubscription = ""
    @Published var monthlySubscription = ""
    @Published var discountSubscription = ""
    
    @Published var onboardingBGImage = "moonlight2"
    @Published var backgroundImage = "moonlight2"
    
    @Published var currentDevotionalVersion: Int = 0
    @Published var remoteVersion: Int = 0
    @Published var audioRemoteVersion: Int = 0
   
    private var remoteConfig = RemoteConfig.remoteConfig()
    var cancellable: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Listen for audio version updates via push notifications
        NotificationCenter.default
            .publisher(for: .audioVersionUpdated)
            .sink { [weak self] notification in
                if let version = notification.userInfo?["version"] as? Int {
                    DispatchQueue.main.async {
                        self?.audioRemoteVersion = version
                    }
                }
            }
            .store(in: &cancellables)

        // Set up Remote Config real-time listener for automatic updates
        setupRemoteConfigListener()

        fetchRemoteConfig() { [weak self] in
            Task {
                // Fetch StoreKit products for price display in views (unchanged)
                await self?.requestProducts()

                // ── RevenueCat: sync then check entitlements on launch ────────
                // syncPurchases() forces a fresh Apple receipt sync — catches
                // promo code redemptions and purchases made outside the app
                // (e.g. gifted codes, Family Sharing) that may be in RC cache.
                try? await Purchases.shared.syncPurchases()
                await self?.updateEntitlementsFromRC()
            }
        }

        // ── RevenueCat: listen for customerInfo changes (renewals, cancellations, etc.)
        setupRCCustomerInfoListener()
    }
    
    func fetchRemoteConfig() async {
        await withCheckedContinuation { continuation in
            remoteConfig.fetchAndActivate { _, _ in
                continuation.resume()
            }
        }
    }
    
    func fetchRemoteConfig(completion: @escaping() -> Void) {
        
        remoteConfig.fetchAndActivate { [weak self] status, error in
            guard let self = self else { return }
            if let error = error {
                print("Remote Config fetch failed: \(error.localizedDescription)")
                completion()
                return
            }
            
            self.updateConfigValues(completion: completion)
        }
    }
    
    private func setupRemoteConfigListener() {
        // Add listener for Remote Config updates
        remoteConfig.addOnConfigUpdateListener { [weak self] configUpdate, error in
            guard error == nil else {
                return
            }
            
            
            // Automatically fetch and activate when config updates
            self?.remoteConfig.fetchAndActivate { _, _ in
                DispatchQueue.main.async {
                    let oldAudioVersion = self?.audioRemoteVersion ?? 0
                    let oldDevotionalVersion = self?.currentDevotionalVersion ?? 0
                    self?.updateConfigValues {}
                    let newAudioVersion = self?.audioRemoteVersion ?? 0
                    let newDevotionalVersion = self?.currentDevotionalVersion ?? 0
                    
                    // If audio version changed, notify the app
                    if newAudioVersion > oldAudioVersion && newAudioVersion > 0 {
                        NotificationCenter.default.post(
                            name: .audioVersionUpdated,
                            object: nil,
                            userInfo: ["version": newAudioVersion]
                        )
                    }
                    
                    // If devotional version changed, notify the app
                    if newDevotionalVersion > oldDevotionalVersion && newDevotionalVersion > 0 {
                        NotificationCenter.default.post(
                            name: .devotionalVersionUpdated,
                            object: nil,
                            userInfo: ["version": newDevotionalVersion]
                        )
                    }
                }
            }
        }
    }
    
    private func updateConfigValues(completion: @escaping() -> Void) {
        showDevotionalSubscription = remoteConfig["showDevotionalSubscription"].boolValue
        showOneTimeSubscription = remoteConfig["showOneTimeSubscription"].boolValue
        yearlySubscription = remoteConfig["currentPremiumID"].stringValue
        monthlySubscription = remoteConfig["currentPremiumMonthly"].stringValue
        discountSubscription = remoteConfig["discountID"].stringValue
        showSubscription = remoteConfig["showSubscription"].boolValue
        onboardingBGImage = remoteConfig["onboardingImage"].stringValue
        backgroundImage = remoteConfig["backgroundImage"].stringValue
        currentDevotionalVersion = remoteConfig["currentDevotionalVersion"].numberValue.intValue
        remoteVersion = remoteConfig["remoteVersion"].numberValue.intValue
        audioRemoteVersion = remoteConfig["audioRemoteVersion"].numberValue.intValue
        showSubscriptionFirst = remoteConfig["showSubscriptionFirst"].boolValue
        showYearlyOption = remoteConfig["showYearlyOption"].boolValue
        onlyShowYearly = remoteConfig["onlyShowYearly"].boolValue
        showMostPopularBadge = remoteConfig["showMostPopularBadge"].boolValue
        showTestimonyTab = remoteConfig["showTestimonyTab"].boolValue
        offerFreeTrial = remoteConfig["offerFreeTrial"].boolValue
        
        // Enhanced Onboarding Toggle from Remote Config
        useEnhancedOnboarding = remoteConfig["useEnhancedOnboarding"].boolValue
        
        // Spiritual Warfare Onboarding Toggle from Remote Config
        useSpiritualWarfareOnboarding = remoteConfig["useSpiritualWarfareOnboarding"].boolValue
        
        // High Conversion Paywall Flag
        useHighConversionPaywall = remoteConfig["useHighConversionPaywall"].boolValue
        
        // AI Feature Flag from Remote Config
        enableAIFeatures = remoteConfig["enableAIFeatures"].boolValue
        
        // Sync to UserDefaults for TaskLibrary access
        UserDefaults.standard.set(enableAIFeatures, forKey: "enableAIFeatures")
        
        // Declarations file name from Remote Config
        let declarationsFileName = remoteConfig["declarationsFileName"].stringValue
        if !declarationsFileName.isEmpty {
            UserDefaults.standard.set(declarationsFileName, forKey: "declarationsFileName")
        }
        
        yearlyID = yearlySubscription
        monthlyID = monthlySubscription
        discountID = discountSubscription
        completion()

    }
    
    func checkIsDevotionalActive(nonConsumables: [Product]) -> Bool {
        if nonConsumables.contains( where: { $0 == self.currentOfferedDevotionalPremium }), let purchaseDate = lastDevotionalPurchaseDate {
            return isWithin30Days(from: purchaseDate)
        }
        return false
    }
    
    private func isWithin30Days(from date: Date) -> Bool {
        // Get the current date
        let currentDate = Date()
        
        // Calculate the date 30 days ago
        guard let date30DaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: currentDate) else {
            return false
        }
        
        // Check if the given date is after or on the date 30 days ago
        return date >= date30DaysAgo
    }
    
    // MARK: - AI Feature Eligibility Methods
    
    var isAIEnabled: Bool {
        let aiEnabled = enableAIFeatures
        // Sync to UserDefaults for TaskLibrary access
        UserDefaults.standard.set(aiEnabled, forKey: "enableAIFeatures")
        return aiEnabled
    }
    
    // MARK: - RevenueCat Customer Info Listener

    /// Sets up a Purchases delegate so we react to background renewals,
    /// cancellations, and billing retries without polling.
    private func setupRCCustomerInfoListener() {
        Purchases.shared.delegate = RCCustomerInfoDelegate { [weak self] customerInfo in
            guard let self else { return }
            Task { @MainActor in
                self.applyCustomerInfo(customerInfo)
            }
        }
    }

    /// Fetches entitlements from RC and updates all published state.
    func updateEntitlementsFromRC() async {
        do {
            let info = try await RevenueCatManager.shared.customerInfo()
            await MainActor.run { applyCustomerInfo(info) }
        } catch {
            print("RC entitlement fetch failed: \(error)")
        }
    }

    @MainActor
    private func applyCustomerInfo(_ info: RevenueCat.CustomerInfo) {
        let premiumActive   = RevenueCatManager.shared.isPremiumActive(info)
        let devotionalActive = RevenueCatManager.shared.isDevotionalActive(info)

        isPremium          = premiumActive
        isInDevotionalPremium = devotionalActive

        // Mirror into purchasedSubscriptions / purchasedNonConsumables so any
        // view code that checks those arrays keeps working.
        // We use the already-fetched StoreKit products for the Product objects.
        if premiumActive {
            // If no StoreKit products loaded yet, leave arrays as-is
            if purchasedSubscriptions.isEmpty, let activeSub = subscriptions.first {
                purchasedSubscriptions = [activeSub]
            }
        } else {
            purchasedSubscriptions = []
        }

        // Sync subscriptionGroupStatus
        subscriptionGroupStatus = premiumActive ? .subscribed : nil

        // Track cancellations
        if !premiumActive && subscriptionGroupStatus != nil {
            if let last = purchasedSubscriptions.first {
                AnalyticsService.shared.trackSubscriptionCancelled(
                    productId: last.id,
                    metadata: ["source": "rc_customer_info_update"]
                )
            }
        }
    }

    @MainActor
    func requestProducts() async {
        do {
            // Request products from the App Store using the identifiers defined in InAppId
            let storeProducts = try await Product.products(for: InAppId.all)

            var newSubscriptions: [Product] = []
            var newNonConsumables: [Product] = [] // New list for non-consumables

            // Filter the products into categories based on their type
            for product in storeProducts {
                switch product.type {
                case .autoRenewable:
                    newSubscriptions.append(product)
                    if product.id == discountSubscription {
                        currentOfferedDiscount = product
                    }
                    if product.id == monthlySubscription {
                        currentOfferedPremiumMonthly = product
                    }
                    if product.id == weeklyID {
                        currentOfferedWeekly = product
                    }
                    if product.id == yearlySubscription {
                        currentOfferedPremium = product
                    }
                case .nonConsumable:
                    if product.id == lifetimeID {
                        currentOfferedLifetime = product
                    }
                    if product.id == devotionals {
                        currentOfferedDevotionalPremium = product
                    }
                    newNonConsumables.append(product)
                default:
                    print("Unknown product type")
                }
            }

            // Sort products by price
            subscriptions = sortByPrice(newSubscriptions)
            nonConsumables = sortByPrice(newNonConsumables)
        } catch {
            print("Failed product request from the App Store server: \(error)")
        }
    }

    
    // MARK: - Purchase (via RevenueCat)

    /// Purchase by product ID — used by paywalls that pass raw ID strings.
    @discardableResult
    func purchaseWithID(_ ids: [String], paywallName: String = "unknown") async throws -> Bool {
        guard let id = ids.first else { return false }
        let productFromID = await products(for: [id])
        guard let product = productFromID?.first else { return false }
        return try await purchase(product, paywallName: paywallName)
    }

    /// Purchase a StoreKit Product — views call this with the product they fetched.
    /// Internally routes through RC so all entitlements are tracked on the RC dashboard.
    @discardableResult
    func purchase(_ product: Product, paywallName: String = "unknown") async throws -> Bool {
        let priceValue   = NSDecimalNumber(decimal: product.price).doubleValue
        let isTrialProduct = product.subscription?.introductoryOffer != nil
        let currency     = product.priceFormatStyle.currencyCode ?? "USD"

        // NOTE: Do NOT fire analytics before RC confirms — RC validates the receipt.
        let customerInfo = try await RevenueCatManager.shared.purchase(storeProduct: product)

        let purchased = RevenueCatManager.shared.isPremiumActive(customerInfo)
            || RevenueCatManager.shared.isDevotionalActive(customerInfo)

        guard purchased else {
            // User cancelled or purchase is pending
            Analytics.logEvent("purchase_cancelled", parameters: [
                "product_id": product.id,
                "paywall_name": paywallName
            ])
            return false
        }

        // ── Unlock premium immediately ────────────────────────────────────
        await MainActor.run {
            self.isPremium = RevenueCatManager.shared.isPremiumActive(customerInfo)
            self.isInDevotionalPremium = RevenueCatManager.shared.isDevotionalActive(customerInfo)
            self.subscriptionGroupStatus = .subscribed
        }

        if isTrialProduct {
            // ─── TRIAL START ─────────────────────────────────────────────
            AppEvents.shared.logEvent(
                AppEvents.Name("StartTrial"),
                valueToSum: 0.00,
                parameters: [
                    AppEvents.ParameterName("product_id"): product.id as NSString,
                    AppEvents.ParameterName("currency"): currency as NSString,
                    AppEvents.ParameterName("paywall_name"): paywallName as NSString,
                    AppEvents.ParameterName("predicted_value"): priceValue as NSNumber
                ]
            )
            Analytics.logEvent("trial_started", parameters: [
                "product_id": product.id,
                "paywall_name": paywallName,
                "value": priceValue,
                "currency": currency
            ])
            Event.trackTikTokEngagement(action: "trial_started", category: "subscription")
        } else {
            // ─── PAID SUBSCRIPTION ────────────────────────────────────────
            AppEvents.shared.logEvent(
                AppEvents.Name("Subscribe"),
                valueToSum: priceValue,
                parameters: [
                    AppEvents.ParameterName("product_id"): product.id as NSString,
                    AppEvents.ParameterName("currency"): currency as NSString,
                    AppEvents.ParameterName("paywall_name"): paywallName as NSString
                ]
            )
            AppEvents.shared.logPurchase(amount: priceValue, currency: currency)
            Event.trackTikTokPremiumPurchase(value: priceValue, currency: currency)
        }

        Analytics.logEvent(Event.premiumSucceeded, parameters: [
            "product_id": product.id,
            "value": priceValue,
            "currency": currency,
            "paywall_name": paywallName,
            "is_trial": isTrialProduct
        ])
        Analytics.logEvent("subscription_started", parameters: [
            "product_id": product.id,
            "value": priceValue,
            "currency": currency,
            "paywall_name": paywallName,
            "is_trial": isTrialProduct
        ])

        // Post-purchase email capture (unchanged)
        let hasShownEmailCapture = UserDefaults.standard.bool(forKey: "hasShownEmailCapture")
        if !hasShownEmailCapture {
            DispatchQueue.main.async { self.showEmailCaptureAfterPurchase = true }
        }

        return true
    }

    // MARK: - Helpers

    func isPurchased(_ product: Product) async -> Bool {
        isPremium || purchasedNonConsumables.contains(product)
    }

    func products(for ids: [String]) async -> [Product]? {
        do {
            return try await Product.products(for: ids)
        } catch {
            print("StoreKit product request failed: \(error)")
            return nil
        }
    }

    func sortByPrice(_ products: [Product]) -> [Product] {
        products.sorted { $0.price < $1.price }
    }

    // MARK: - Restore (via RevenueCat)

    func restore() async {
        do {
            let info = try await RevenueCatManager.shared.restorePurchases()
            await MainActor.run { applyCustomerInfo(info) }
        } catch {
            print("RC restore failed: \(error)")
        }
    }
}

// MARK: - RC Delegate Adapter

/// Lightweight Purchases delegate that forwards customerInfo updates to a closure.
private final class RCCustomerInfoDelegate: NSObject, PurchasesDelegate {
    private let onUpdate: (RevenueCat.CustomerInfo) -> Void

    init(onUpdate: @escaping (RevenueCat.CustomerInfo) -> Void) {
        self.onUpdate = onUpdate
    }

    func purchases(_ purchases: Purchases, receivedUpdated customerInfo: RevenueCat.CustomerInfo) {
        onUpdate(customerInfo)
    }
}

extension Product {
    
    var title: String {
        if id == lifetimeID {
            return "One time fee of \(displayPrice) for lifetime access."
        } else if id == currentYearlyID {
            return "$\(price/12)/mo."
        } else if id == currentPremiumID {
            return "$\(price/12)/mo."
        } else {
            return "\(displayPrice)/month. Cancel anytime."
        }
    }
    
    var ctaDurationTitle: String {
        if id == lifetimeID {
            return "Lifetime"
        } else if id == currentYearlyID {
            return "Pro - Save 50%"
        } else if id == yearlyID {
                return "Yearly"
        } else if id == monthlyID {
            return "Monthly"
        } else {
           return "Weekly"
        }
    }
    
    var ctaButtonTitle: String {
        if id == lifetimeID {
            return "Get Lifetime Access"
        } else if id == currentYearlyID {
            return "Start My Free Trial Now"
        } else if id == yearlyID {
                return "Try It Free"
        } else {
           return "Subscribe"
        }
    }
    
    
    
    var subTitle: String {
        if id == lifetimeID {
            return "One time fee of \(displayPrice) for lifetime access."
        } else if id == currentYearlyID {
           return "7 days free then \(displayPrice)/yr."
        } else if id == yearlyID {
            let monthly = getMonthlyAmount(price: price)
            return "First 7 days free, then \(displayPrice)/yr."
        } else if id == weeklyID {
            return "\(displayPrice)/wk."
        } else {
           return "\(displayPrice)/mo."
        }
    }
    
    func getMonthlyAmount(price: Decimal) -> String {
        let twelve = Double(12)
        let floatDecimal: Double = 100
        let priceDouble = NSDecimalNumber(decimal: price).doubleValue

        // Convert Float16 to Decimal

        // Perform Decimal calculation
        let priceDivided = priceDouble / twelve
        let truncatedPrice = (priceDivided * floatDecimal).rounded(.down) / floatDecimal

        // Convert to Double only after rounding down
        let price = (truncatedPrice as Double)
        let roundedPrice = String(format: "%.2f", price)
            return "$\(roundedPrice)/"
    }
    
    
    var costDescription: String {
        if id == yearlyID {
            let monthly = getMonthlyAmount(price: price)
            return "7 days Free, then \(monthly)month, billed annually at \(displayPrice)/year. Cancel anytime."
        } else if id == lifetimeID {
            return "Pay once, own it for life!"
        } else if id == weeklyID {
                return "\(displayPrice)/per week. Cancel anytime."
        } else {
            return "Just \(displayPrice) per month. Cancel anytime."
        }
    }
    
    var discountedPrice: String {
        if id == discountID {
            return displayPrice
            }
        return ""
    }
    
    var discountedMonthlyPrice: String {
        if id == discountID {
            let monthly = getMonthlyAmount(price: price)
            return "\(monthly)month"
        }
        return ""
    }
    
    var percentageOff: String {
        if id == discountID {
            // Step 1: Calculate the raw discount value
            let priceDouble = NSDecimalNumber(decimal: price).doubleValue

            // Adjusted Calculation Formula
            let discount = max(0, Int(((40 - priceDouble) / 40) * 100))
            return "\(discount)%"
        }
        return ""
    }
}
