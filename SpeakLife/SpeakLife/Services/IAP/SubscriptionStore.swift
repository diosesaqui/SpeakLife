//
//  SubscriptionStore.swift
//  SpeakLife
//
//  Created by Riccardo Washington on 12/17/22.
//

import StoreKit
import Combine
import FirebaseAnalytics
import FacebookCore
import SwiftUI
import FirebaseRemoteConfig

typealias Transaction = StoreKit.Transaction
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
    var updateListenerTask: Task<Void, Error>? = nil
    var cancellable: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Start a transaction listener as close to app launch as possible
        updateListenerTask = listenForTransactions()
        
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
                // During store initialization, request products from the App Store
                await self?.requestProducts()
                
                // Deliver products that the customer purchases
                await self?.updateCustomerProductStatus()
            }
        }
        
        cancellable = Publishers.CombineLatest3($subscriptionGroupStatus, $purchasedNonConsumables, $purchasedSubscriptions)
            .sink { [weak self] subscriptionStatus, nonConsumables, purchasedSubscriptions in
                guard let self = self else { return }
                // Update isPremium based on subscription state and purchased non-consumables
                self.isInDevotionalPremium = checkIsDevotionalActive(nonConsumables: nonConsumables)
                // Fix: Check purchased non-consumables, not all available non-consumables
                self.isPremium = (subscriptionStatus == .subscribed) || self.purchasedNonConsumables.contains( where: { $0.id == lifetimeID })
                
            }
        
    }

    deinit {
        updateListenerTask?.cancel()
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
    
    func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            // Iterate through any transactions that don't come from a direct call to `purchase()`
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    
                    // Track subscription events based on transaction type
                    if transaction.productType == .autoRenewable {
                        // Check if this is a renewal or trial conversion
                        let originalTransactionId = transaction.originalID
                        
                        // Get previous transactions for this subscription
                        var previousTransactions: [Transaction] = []
                        for await entitlement in Transaction.currentEntitlements {
                            if let verifiedTransaction = try? self.checkVerified(entitlement),
                               verifiedTransaction.originalID == originalTransactionId,
                               verifiedTransaction.id != transaction.id {
                                previousTransactions.append(verifiedTransaction)
                            }
                        }
                        
                        if !previousTransactions.isEmpty {
                                // This is a renewal or trial conversion
                                // Get the product to extract price
                                if let product = self.subscriptions.first(where: { $0.id == transaction.productID }) ?? self.nonConsumables.first(where: { $0.id == transaction.productID }) {
                                    let priceValue = NSDecimalNumber(decimal: product.price).doubleValue
                                    
                                    if transaction.offerType == .introductory {
                                        // Trial conversion
                                        AnalyticsService.shared.trackTrialActivated(
                                            productId: transaction.productID,
                                            metadata: [
                                                "transaction_id": transaction.id,
                                                "original_transaction_id": originalTransactionId,
                                                "price": priceValue,
                                                "currency": "USD"
                                            ]
                                        )
                                        
                                        // Track conversion with revenue
                                        Analytics.logEvent("app_store_subscription_convert", parameters: [
                                            "product_id": transaction.productID,
                                            "value": priceValue,
                                            "currency": "USD"
                                        ])
                                        Event.trackTikTokPremiumPurchase(value: priceValue, currency: "USD")
                                    } else {
                                        // Regular renewal
                                        AnalyticsService.shared.trackSubscriptionRenewal(
                                            productId: transaction.productID,
                                            price: priceValue,
                                            metadata: [
                                                "transaction_id": transaction.id,
                                                "original_transaction_id": originalTransactionId
                                            ]
                                        )
                                        
                                        // Track renewal with revenue
                                        Analytics.logEvent("app_store_subscription_renew", parameters: [
                                            "product_id": transaction.productID,
                                            "value": priceValue,
                                            "currency": "USD"
                                        ])
                                    }
                                } else {
                                    // Fallback without price if product not found
                                    if transaction.offerType == .introductory {
                                        AnalyticsService.shared.trackTrialActivated(
                                            productId: transaction.productID,
                                            metadata: [
                                                "transaction_id": transaction.id,
                                                "original_transaction_id": originalTransactionId
                                            ]
                                        )
                                    } else {
                                        AnalyticsService.shared.trackSubscriptionRenewal(
                                            productId: transaction.productID,
                                            metadata: [
                                                "transaction_id": transaction.id,
                                                "original_transaction_id": originalTransactionId
                                            ]
                                        )
                                    }
                                }
                        }
                    }

                    // Deliver products to the user
                    await self.updateCustomerProductStatus()

                    // Always finish a transaction
                    await transaction.finish()
                } catch {
                    // StoreKit has a transaction that fails verification; don't deliver content
                    print("Transaction failed verification")
                }
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

    
    func purchaseWithID(_ ids: [String], paywallName: String = "unknown") async throws -> Transaction? {
        guard let id = ids.first else { return nil }
        let productFromID = await products(for: [id])
        guard let product = productFromID?.first else { return nil }
        let transaction = try await purchase(product, paywallName: paywallName)
        return transaction
    }

    func purchase(_ product: Product, paywallName: String = "unknown") async throws -> Transaction? {
        let priceValue = NSDecimalNumber(decimal: product.price).doubleValue
        let isTrialProduct = product.subscription?.introductoryOffer != nil
        let currency = product.priceFormatStyle.currencyCode ?? "USD"

        // NOTE: Do NOT fire analytics here — Apple has not confirmed the purchase yet.
        // All event tracking belongs inside case .success after checkVerified().

        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updateCustomerProductStatus()

            // Ensure premium unlocks immediately after verified purchase
            await MainActor.run { self.isPremium = true }

            if isTrialProduct {
                // ─── TRIAL START ──────────────────────────────────────────────
                // Fire Meta StartTrial event — $0 value (trial is free)
                // This is the primary optimization event for Meta ad campaigns
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

                // Firebase: trial started (correctly placed after Apple confirmation)
                Analytics.logEvent("trial_started", parameters: [
                    "product_id": product.id,
                    "paywall_name": paywallName,
                    "value": priceValue,
                    "currency": currency,
                    "transaction_id": transaction.id
                ])

                // TikTok
                Event.trackTikTokEngagement(action: "trial_started", category: "subscription")

            } else {
                // ─── PAID SUBSCRIPTION (no trial / direct purchase) ───────────
                // Fire Meta Subscribe event with actual revenue value
                AppEvents.shared.logEvent(
                    AppEvents.Name("Subscribe"),
                    valueToSum: priceValue,
                    parameters: [
                        AppEvents.ParameterName("product_id"): product.id as NSString,
                        AppEvents.ParameterName("currency"): currency as NSString,
                        AppEvents.ParameterName("paywall_name"): paywallName as NSString
                    ]
                )

                // Meta generic purchase (belt + suspenders)
                AppEvents.shared.logPurchase(amount: priceValue, currency: currency)

                // TikTok
                Event.trackTikTokPremiumPurchase(value: priceValue, currency: currency)
            }

            // Firebase: purchase succeeded (fires for both trial and direct)
            Analytics.logEvent(Event.premiumSucceeded, parameters: [
                "product_id": product.id,
                "value": priceValue,
                "currency": currency,
                "transaction_id": transaction.id,
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

            await transaction.finish()

            // MARK: - Post-Purchase Email Capture
            // Show email capture sheet once per user, after their first successful purchase/trial
            let hasShownEmailCapture = UserDefaults.standard.bool(forKey: "hasShownEmailCapture")
            if !hasShownEmailCapture {
                DispatchQueue.main.async {
                    self.showEmailCaptureAfterPurchase = true
                }
            }

            return transaction

        case .userCancelled, .pending:
            Analytics.logEvent("purchase_cancelled", parameters: [
                "product_id": product.id,
                "paywall_name": paywallName
            ])
            return nil
        default:
            return nil
        }
    }

    func isPurchased(_ product: Product) async throws -> Bool {
        // Determine whether the user purchased a given product
        switch product.type {
        case .autoRenewable:
            return purchasedSubscriptions.contains(product)
        case .nonConsumable:
            return purchasedNonConsumables.contains(product) // Check for non-consumables
        default:
            return false
        }
    }

    func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    @MainActor
    func updateCustomerProductStatus() async {
        var purchasedSubscriptions: [Product] = []
        var purchasedNonConsumables: [Product] = [] // New list for purchased non-consumables
        
        // Store previous subscription state to detect cancellations
        let previousSubscriptions = self.purchasedSubscriptions
        let previousStatus = self.subscriptionGroupStatus

        // Iterate through all of the user's purchased products
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                switch transaction.productType {
                case .autoRenewable:
                    if let subscription = subscriptions.first(where: { $0.id == transaction.productID }) {
                        purchasedSubscriptions.append(subscription)
                    }
                case .nonConsumable:
                    if let nonConsumable = nonConsumables.first(where: { $0.id == transaction.productID }) {
                        purchasedNonConsumables.append(nonConsumable)
                    }
                default:
                    break
                }
            } catch {
                print("Transaction verification failed")
            }
        }

        self.purchasedNonConsumables = purchasedNonConsumables

        // Determine subscription group status robustly:
        // 1. Try the purchased product first (most reliable after a purchase)
        // 2. Fall back to any product in the subscriptions list
        // 3. If we have verified entitlements but status query fails, treat as subscribed
        var newStatus: RenewalState? = nil

        // Try purchased products first — they're in the active subscription group
        for product in purchasedSubscriptions {
            if let statuses = try? await product.subscription?.status,
               let status = statuses.first?.state {
                newStatus = status
                break
            }
        }

        // Fall back to checking all available subscription products
        if newStatus == nil {
            for product in subscriptions {
                if let statuses = try? await product.subscription?.status,
                   let status = statuses.first?.state {
                    newStatus = status
                    break
                }
            }
        }

        // Safety net: if we have verified active entitlements but status query
        // failed for all products, the user IS subscribed — don't lock them out
        if newStatus == nil && !purchasedSubscriptions.isEmpty {
            newStatus = .subscribed
        }

        self.purchasedSubscriptions = purchasedSubscriptions
        subscriptionGroupStatus = newStatus
        
        // Track subscription cancellation
        if previousStatus == .subscribed && newStatus != .subscribed && !previousSubscriptions.isEmpty {
            // User had a subscription but no longer does
            if let lastSubscription = previousSubscriptions.first {
                AnalyticsService.shared.trackSubscriptionCancelled(
                    productId: lastSubscription.id,
                    metadata: [
                        "previous_status": String(describing: previousStatus),
                        "new_status": String(describing: newStatus)
                    ]
                )
            }
        }
        
        // Also check for expired or revoked subscriptions
        if newStatus == .expired || newStatus == .revoked {
            if let currentSubscription = purchasedSubscriptions.first {
                AnalyticsService.shared.trackSubscriptionCancelled(
                    productId: currentSubscription.id,
                    metadata: [
                        "cancellation_reason": String(describing: newStatus)
                    ]
                )
            }
        }
    }
    
    func products(for ids: [String]) async -> [Product]? {
        do {
            let products = try await Product.products(for: ids)
            return products
        } catch {
            print("Failed product request from the App Store server: \(error)")
        }
        return nil
    }

    func sortByPrice(_ products: [Product]) -> [Product] {
        products.sorted(by: { return $0.price < $1.price })
    }
    
    func restore() async {
        await updateCustomerProductStatus()
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
