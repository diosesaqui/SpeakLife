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

extension Notification.Name {
    /// Posted when an ad deep link assigns an onboarding variant (see
    /// SubscriptionStore.assignOnboardingVariantFromAd).
    static let adOnboardingVariantAssigned = Notification.Name("adOnboardingVariantAssigned")
}

final class SubscriptionStore: ObservableObject {

    @Published var isPremium: Bool = false
    /// True iff the active premium entitlement is currently in its free-trial
    /// introductory period (vs a paid period). Powers the onboarding conversion
    /// analytics. Source of truth: RevenueCat, refreshed in applyCustomerInfo.
    @Published var isInTrial: Bool = false
    /// First date the user ever activated the premium entitlement (survives
    /// cancel-and-resubscribe). Powers the subscription anniversary overlay.
    @Published var premiumOriginalPurchaseDate: Date?
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

    // MARK: - Quiz Onboarding (legacy boolean, kept as a migration fallback)
    // true  = QuizOnboardingView, false = ProductOnboardingView.
    // Superseded by `onboardingVariant` below; only consulted when that string
    // is empty/unset (see resolvedOnboardingVariant).
    @Published var useQuizOnboarding = true

    // MARK: - Onboarding A/B variant (single switch for which flow shows)
    // Remote Config key `onboardingVariant`: "quiz" | "product" | "identity" | "outcomes" | "warfare".
    // Empty/unset falls back to the legacy useQuizOnboarding boolean so live
    // users are unaffected until the string key is set in Remote Config.
    @Published var onboardingVariant: String = ""

    // MARK: - Ad-matched onboarding override
    // When a user installs from an ad whose deep link carries `ob=<variant>`, that
    // choice is recorded once and WINS over the Remote Config experiment, so the
    // onboarding matches the ad they tapped. Persisted in UserDefaults (stable for
    // the user) and mirrored here so SwiftUI re-renders if the Meta deferred app
    // link resolves after onboarding first appears.
    static let adOnboardingKey = "adOnboardingVariant"
    @Published var adOnboardingVariant: String? =
        UserDefaults.standard.string(forKey: SubscriptionStore.adOnboardingKey)

    enum OnboardingVariant: String {
        case quiz, product, identity, outcomes, warfare
        init?(code: String) { self.init(rawValue: code.lowercased()) }
    }

    // Once onboarding first appears the variant is frozen (lockOnboardingVariant)
    // so a late-resolving ad deep link can't swap the flow mid-run or desync the
    // started/finished analytics variant.
    private var lockedOnboardingVariant: OnboardingVariant?

    var resolvedOnboardingVariant: OnboardingVariant {
        lockedOnboardingVariant ?? computedOnboardingVariant
    }

    private var computedOnboardingVariant: OnboardingVariant {
        // 1) ad-matched override → 2) Remote Config experiment → 3) legacy fallback
        if let ad = adOnboardingVariant, let v = OnboardingVariant(code: ad) { return v }
        if let v = OnboardingVariant(code: onboardingVariant) { return v }
        return useQuizOnboarding ? .quiz : .product
    }

    /// Freeze the onboarding variant the first time onboarding is shown, so an ad
    /// deep link that resolves afterward can't restart the user in a different flow
    /// (and can't desync the started/finished analytics variant). Idempotent.
    func lockOnboardingVariant() {
        if lockedOnboardingVariant == nil { lockedOnboardingVariant = computedOnboardingVariant }
    }

    /// String label for the user's resolved onboarding arm. Stamped onto the
    /// onboarding + conversion analytics so the PostHog/Firebase funnels can pick
    /// a winner per variant.
    var onboardingVariantName: String { resolvedOnboardingVariant.rawValue }

    /// Parse an incoming deep link / app link for the `ob=` param and record the
    /// matched onboarding. Static so the Meta deferred-app-link callback in
    /// AppDelegate can call it without a store instance; the @Published mirror is
    /// updated via `.adOnboardingVariantAssigned`.
    static func handleIncomingURL(_ url: URL, source: String) {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
        // Referral: capture a ?ref=CODE for redemption after onboarding.
        if let ref = items?.first(where: { $0.name == "ref" })?.value {
            ReferralService.capturePendingCode(ref)
        }
        guard let ob = items?.first(where: { $0.name == "ob" })?.value else { return }
        assignOnboardingVariantFromAd(ob, source: source)
    }

    static func assignOnboardingVariantFromAd(_ rawCode: String?, source: String) {
        guard let code = rawCode?.lowercased(),
              OnboardingVariant(code: code) != nil,
              UserDefaults.standard.string(forKey: adOnboardingKey) == nil  // first assignment wins
        else { return }
        UserDefaults.standard.set(code, forKey: adOnboardingKey)
        AnalyticsService.shared.track("onboarding_variant_assigned",
                                      parameters: ["variant": code, "source": source])
        NotificationCenter.default.post(name: .adOnboardingVariantAssigned, object: code)
    }

    // MARK: - AI Feature Flag
    @Published var enableAIFeatures = false

    // MARK: - Checklist Home Tab Flag
    // Kill switch for the "Today" checklist home tab. Defaults true (registered
    // in AppDelegate's Remote Config defaults); set `checklistHomeEnabled` to
    // false in Remote Config to revert to the feed-as-home layout.
    @Published var checklistHomeEnabled = true
    
    // MARK: - High Conversion Paywall Flag
    @Published var useHighConversionPaywall = false
    // Soft-onboarding-paywall switch. RC key kept as "showPayWhatYouCanLink" for
    // back-compat with the existing Remote Config setup. When true, the
    // onboarding paywall stays soft: it shows the close button and, on dismiss,
    // the one-time welcome-offer discount. When false, onboarding callsites
    // (isHardPaywall: true) render a hard wall (no X, and therefore no exit
    // discount). NOTE: this no longer controls the visible "pay what you can"
    // link — that moved to showPayWhatYouCanCTA below.
    @Published var showPayWhatYouCanLink = true
    // Gates ONLY the "Can't afford full price? Pay what you can →" CTA link,
    // independent of the soft/hard wall and the welcome offer. Default OFF: the
    // link stays hidden everywhere until Remote Config sets showPayWhatYouCanCTA.
    @Published var showPayWhatYouCanCTA = false

    // MARK: - Paywall Value Props A/B Test
    // false = benefit-based personalized props (high_conversion_v1)
    // true  = succinct feature-based props (high_conversion_succinct_v1)
    @Published var useSuccinctPaywallValueProps = false

    // MARK: - Weekly Plan A/B Test
    // false = show Monthly as the non-annual option (default)
    // true  = show Weekly ($SpeakLife1Wk5) instead of Monthly on the paywall
    @Published var useWeeklyPlan = false

    // MARK: - Quiz v2 A/B Test (warfare + product onboarding quiz)
    // false = current quiz: connect_style question, no belief step (default)
    // true  = outcome question ("victory_looks_like") replaces connect_style,
    //         a belief question follows it, and the plan reveal echoes the outcome
    @Published var useQuizV2 = false

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

        // Ad-matched onboarding: when a deep link / Meta deferred app link assigns
        // a variant, mirror it into the published property so onboarding re-renders
        // even if the (async) deferred link resolves after onboarding first showed.
        NotificationCenter.default
            .publisher(for: .adOnboardingVariantAssigned)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] note in
                self?.adOnboardingVariant = (note.object as? String)
                    ?? UserDefaults.standard.string(forKey: Self.adOnboardingKey)
            }
            .store(in: &cancellables)

        // Set up Remote Config real-time listener for automatic updates
        setupRemoteConfigListener()

        fetchRemoteConfig() { [weak self] in
            Task {
                // Fetch StoreKit products for price display in views (unchanged)
                await self?.requestProducts()

                // ── RevenueCat: check entitlements on launch ──────────────────
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
                    let oldRemoteVersion = self?.remoteVersion ?? 0
                    self?.updateConfigValues {}
                    let newAudioVersion = self?.audioRemoteVersion ?? 0
                    let newDevotionalVersion = self?.currentDevotionalVersion ?? 0
                    let newRemoteVersion = self?.remoteVersion ?? 0

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

                    // If declarations version changed, notify the app
                    if newRemoteVersion > oldRemoteVersion && newRemoteVersion > 0 {
                        NotificationCenter.default.post(
                            name: .declarationsVersionUpdated,
                            object: nil,
                            userInfo: ["version": newRemoteVersion]
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
        checklistHomeEnabled = remoteConfig["checklistHomeEnabled"].boolValue

        // Enhanced Onboarding Toggle from Remote Config
        useEnhancedOnboarding = remoteConfig["useEnhancedOnboarding"].boolValue
        
        // Spiritual Warfare Onboarding Toggle from Remote Config
        useSpiritualWarfareOnboarding = remoteConfig["useSpiritualWarfareOnboarding"].boolValue

        // Quiz Onboarding A/B from Remote Config (key: useQuizOnboarding) — legacy fallback.
        useQuizOnboarding = remoteConfig["useQuizOnboarding"].boolValue

        // Onboarding A/B variant (key: onboardingVariant) — "quiz" | "product" | "identity" | "outcomes".
        // Empty until set in Remote Config; resolvedOnboardingVariant then falls
        // back to useQuizOnboarding so nothing changes for live users.
        onboardingVariant = remoteConfig["onboardingVariant"].stringValue

        // High Conversion Paywall Flag
        useHighConversionPaywall = remoteConfig["useHighConversionPaywall"].boolValue
        showPayWhatYouCanLink = remoteConfig["showPayWhatYouCanLink"].boolValue
        showPayWhatYouCanCTA = remoteConfig["showPayWhatYouCanCTA"].boolValue

        // Paywall Value Props A/B Test
        useSuccinctPaywallValueProps = remoteConfig["useSuccinctPaywallValueProps"].boolValue

        // Weekly Plan A/B Test
        useWeeklyPlan = remoteConfig["useWeeklyPlan"].boolValue

        // Quiz v2 A/B Test (unset key resolves to false, so this ships dormant)
        useQuizV2 = remoteConfig["useQuizV2"].boolValue

        // AI Feature Flag from Remote Config
        enableAIFeatures = remoteConfig["enableAIFeatures"].boolValue

        // Anthropic API key from Remote Config
        AnthropicConfig.apiKey = remoteConfig["anthropic_api_key"].stringValue
        
        // Sync to UserDefaults for TaskLibrary access
        UserDefaults.standard.set(enableAIFeatures, forKey: "enableAIFeatures")
        
        // Declarations file name from Remote Config — only upgrade, never downgrade
        let remoteDeclarationsFileName = remoteConfig["declarationsFileName"].stringValue
        if !remoteDeclarationsFileName.isEmpty {
            let currentFileName = UserDefaults.standard.string(forKey: "declarationsFileName") ?? "declarationsv9.json"
            let currentVer = Int(currentFileName.filter { $0.isNumber }) ?? 0
            let remoteVer = Int(remoteDeclarationsFileName.filter { $0.isNumber }) ?? 0
            if remoteVer >= currentVer {
                UserDefaults.standard.set(remoteDeclarationsFileName, forKey: "declarationsFileName")
            } else {
                print("⚠️ Ignoring Remote Config downgrade: \(remoteDeclarationsFileName) < \(currentFileName)")
            }
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

    // MARK: - Offer Codes

    /// Presents Apple's offer-code redemption sheet, then refreshes entitlements.
    /// RC's delegate (`setupRCCustomerInfoListener`) already flips premium state
    /// when the redeemed transaction lands; this extra refresh is a safety net.
    @MainActor
    func redeemOfferCode() {
        RevenueCatManager.shared.presentOfferCodeRedemption()
        Task {
            try? await Purchases.shared.syncPurchases()
            await updateEntitlementsFromRC()
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
        isInTrial          = premiumActive && RevenueCatManager.shared.isPremiumInTrial(info)
        isInDevotionalPremium = devotionalActive
        premiumOriginalPurchaseDate = premiumActive
            ? RevenueCatManager.shared.premiumOriginalPurchaseDate(info)
            : nil

        // Defensive cleanup for users affected by the pre-fix isTrialProduct
        // bug, where a non-trial purchase scheduled D2/D3 "your trial ends
        // tomorrow" pushes. RC is the source of truth: if the user is premium
        // but NOT in a trial period right now, any pending trial pushes are
        // stale and must be cleared. Idempotent — safe to run on every RC
        // customer-info update.
        if premiumActive && !RevenueCatManager.shared.isPremiumInTrial(info) {
            TrialExperienceService.shared.clearPendingTrialPushes()
        }

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
        // Product has *some* intro offer configured in App Store Connect — but
        // that does NOT mean THIS user gets one. Returning subscribers who
        // already consumed the trial slot on this subscription group pay full
        // price immediately. We must check per-user eligibility BEFORE the
        // purchase resolves, because afterwards Apple flips isEligibleForIntroOffer
        // to false (the slot is now used) and we lose the signal.
        // Only a .freeTrial intro offer is a trial. Discounted pay-as-you-go /
        // pay-up-front intro offers charge immediately and must take the
        // regular Subscribe path, not the StartTrial/trial_started one.
        let hasFreeTrialIntroOffer = product.subscription?.introductoryOffer?.paymentMode == .freeTrial
        let isEligibleForIntroOffer: Bool
        if let subscription = product.subscription {
            isEligibleForIntroOffer = await subscription.isEligibleForIntroOffer
        } else {
            isEligibleForIntroOffer = false
        }
        // True iff this specific purchase actually enters a trial period.
        // Used to gate the Facebook StartTrial event, the analytics is_trial
        // flag, and the D2/D3 trial-ending push scheduling.
        let willStartTrial = hasFreeTrialIntroOffer && isEligibleForIntroOffer
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
            self.isInTrial = self.isPremium && RevenueCatManager.shared.isPremiumInTrial(customerInfo)
            self.isInDevotionalPremium = RevenueCatManager.shared.isDevotionalActive(customerInfo)
            self.subscriptionGroupStatus = .subscribed
        }

        if willStartTrial {
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
            // Single source of truth for trial_started (paywalls must NOT fire
            // their own copy). segment/plan added so the event keeps the
            // properties the HighConversionPaywall version used to carry.
            AnalyticsService.shared.track("trial_started", parameters: [
                "product_id": product.id,
                "paywall_name": paywallName,
                "value": priceValue,
                "currency": currency,
                "variant": onboardingVariantName,
                "segment": UserDefaults.standard.string(forKey: "onboarding_segment") ?? "",
                "plan": planLabel(for: product),
                // Aliases of plan/paywall_name kept so pre-existing dashboards
                // keyed on the old HC-paywall event keys keep working.
                "plan_id": planLabel(for: product),
                "paywall_variant": paywallName
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
            "is_trial": willStartTrial,
            "variant": onboardingVariantName
        ])
        // Routed through AnalyticsService so PostHog (the A/B funnel) receives it
        // too, not just Firebase. variant makes revenue attributable per arm.
        AnalyticsService.shared.track("subscription_started", parameters: [
            "product_id": product.id,
            "value": priceValue,
            "currency": currency,
            "paywall_name": paywallName,
            "is_trial": willStartTrial,
            "variant": onboardingVariantName
        ])

        // Hook into the trial experience push sequence. Without this the D2/D3
        // trial-conversion pushes coded in TrialExperienceService never fire.
        // Critical: gate on willStartTrial (actual per-user eligibility), not
        // on hasIntroOffer — otherwise returning subscribers who pay full price
        // get scheduled "your trial ends tomorrow" pushes for a trial they
        // never started.
        // The trial length is read from THIS product's intro offer (3-day,
        // 7-day, ...) so the reminder offsets track whichever SKU Remote
        // Config pointed the paywall at — never a hardcoded 3 days.
        if willStartTrial {
            TrialExperienceService.shared.onTrialStarted(
                lengthInDays: TrialExperienceService.introTrialDays(for: product)
            )
        } else if TrialExperienceService.shared.isTrialActive {
            // Trial-active user just bought a paid product → mark converted so
            // we cancel the still-pending trial pushes and stop nagging them.
            TrialExperienceService.shared.onTrialConverted()
        } else {
            // Defensive cleanup: a paid (non-trial) purchase by a user who
            // somehow has stale trial pushes pending (e.g. affected by the
            // pre-fix isTrialProduct/willStartTrial bug, or a restore). Clear
            // them so we don't fire bogus "last day of trial" pushes after a
            // paid sale.
            TrialExperienceService.shared.clearPendingTrialPushes()
        }

        return true
    }

    // MARK: - Helpers

    /// Plan label derived from the product's subscription period so conversion
    /// events report annual/monthly/weekly correctly regardless of which
    /// paywall initiated the purchase.
    private func planLabel(for product: Product) -> String {
        guard let unit = product.subscription?.subscriptionPeriod.unit else { return "unknown" }
        switch unit {
        case .year:  return "annual"
        case .month: return "monthly"
        case .week:  return "weekly"
        case .day:   return "daily"
        @unknown default: return "unknown"
        }
    }

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

    /// Returns true when the restore found an active entitlement, so callers can
    /// tell the user "restored" vs "nothing to restore" instead of always
    /// claiming success.
    @discardableResult
    func restore() async -> Bool {
        do {
            let info = try await RevenueCatManager.shared.restorePurchases()
            await MainActor.run { applyCustomerInfo(info) }
            return RevenueCatManager.shared.isPremiumActive(info)
                || RevenueCatManager.shared.isDevotionalActive(info)
        } catch {
            print("RC restore failed: \(error)")
            return false
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
