import Foundation
import FirebaseAnalytics
import TikTokBusinessSDK
import FacebookCore
#if canImport(PostHog)
import PostHog
#endif

// MARK: - Analytics Event Model
//
// Every analytics call in the app is normalized into a single `AnalyticsEvent`
// before it is fanned out to the registered providers. `name` + `parameters`
// is the generic payload that destinations like Firebase / Amplitude / PostHog
// log verbatim. `semantic` is an optional, strongly-typed hint that lets
// channel-specific providers (TikTok, Meta) fire their special conversion /
// engagement events with the right native event names.

struct AnalyticsEvent {
    let name: String
    let parameters: [String: Any]
    let semantic: AnalyticsSemantic?

    init(name: String, parameters: [String: Any] = [:], semantic: AnalyticsSemantic? = nil) {
        self.name = name
        self.parameters = parameters
        self.semantic = semantic
    }
}

/// Strongly-typed business meaning behind an event. Generic providers ignore
/// this; ad/attribution providers switch on it to emit their native events.
enum AnalyticsSemantic {
    case screenView(name: String)
    case contentView(type: String, id: String)
    case share(contentType: String)
    case purchase(value: Double, currency: String)
    case trialStarted(productId: String, currency: String)
    case trialConverted(productId: String, price: Double?, currency: String)
    case subscriptionRenewal(price: Double, currency: String)
    case featureUsage(name: String)
    case engagement(action: String, category: String?)
}

// MARK: - Analytics Provider Interface
//
// Implement this protocol to add a new destination (Amplitude, Mixpanel,
// PostHog, a custom backend, …) and register it once with
// `AnalyticsService.shared.register(MyProvider())`. Nothing else in the app
// needs to change — every existing call site flows through here automatically.

protocol AnalyticsProvider: AnyObject {
    /// Stable identifier, useful for logging / debugging.
    var id: String { get }

    /// Toggle a provider off without unregistering it (e.g. behind consent).
    var isEnabled: Bool { get }

    /// Called once when the provider is registered. Do SDK setup here.
    func configure()

    /// Record a normalized event.
    func log(_ event: AnalyticsEvent)

    /// Attach a durable user property / trait.
    func setUserProperty(_ value: Any, forName name: String)

    /// Associate subsequent events with a known user id (identify / alias).
    func setUserId(_ id: String?)

    /// The id this provider currently files events under, when it has one that
    /// other systems need to join against. `nil` for providers whose identity
    /// is private to them.
    var currentDistinctId: String? { get }
}

extension AnalyticsProvider {
    var isEnabled: Bool { true }
    func configure() {}
    func setUserProperty(_ value: Any, forName name: String) {}
    func setUserId(_ id: String?) {}
    var currentDistinctId: String? { nil }
}

// MARK: - Analytics Service (Dispatcher)
//
// Public API is unchanged from the original single-Firebase implementation —
// it now builds an `AnalyticsEvent` and fans it out to every registered
// provider instead of calling Firebase directly.

final class AnalyticsService: AnalyticsTracking {

    static let shared = AnalyticsService()

    private var sessionStartTime: Date?
    private var currentScreen: String?
    private var userProperties: [String: Any] = [:]

    private var providers: [AnalyticsProvider] = []
    private let providersLock = NSLock()

    private init() {
        registerDefaultProviders()
        applyGlobalUserProperties()
        startSession()
    }

    /// Mirror the durable slice of `AnalyticsContext` onto the person record so
    /// cohorts work at the user level too, not just as event filters.
    /// Uses `self` rather than `.shared` because this runs inside `init`.
    private func applyGlobalUserProperties() {
        let context = AnalyticsContext.shared
        setUserProperty(AnalyticsContext.Key.appVersion, value: context.appVersion)
        setUserProperty(AnalyticsContext.Key.appBuild, value: context.appBuild)
        setUserProperty(AnalyticsContext.Key.subscriptionStatus,
                        value: context.currentSubscriptionStatus.rawValue)
    }

    // MARK: Provider Registration

    /// Register the destinations that ship with the app. To add a new analytics
    /// tool, implement `AnalyticsProvider` and append a `register(...)` line here
    /// (or call `AnalyticsService.shared.register(...)` from app startup).
    private func registerDefaultProviders() {
        register(FirebaseAnalyticsProvider())
        register(TikTokAnalyticsProvider())
        register(MetaAnalyticsProvider())

        // Product analytics (funnels / retention / session replay). Add the
        // PostHog Swift package, then uncomment with your project API key:
         register(PostHogAnalyticsProvider(
             apiKey: "phc_D4qLgjTSwfzKpbgCNTdUn7Hx9QoS7ur3BWwpwubVLdG7",
             host: "https://us.i.posthog.com",
             enableSessionReplay: true
         ))
    }

    /// Register a new analytics destination. Safe to call at any time; the
    /// provider is configured immediately and receives all subsequent events.
    func register(_ provider: AnalyticsProvider) {
        provider.configure()
        providersLock.lock()
        providers.append(provider)
        providersLock.unlock()

        // Replay known user properties so a late-registered provider starts
        // with the same context as the others.
        for (key, value) in userProperties {
            provider.setUserProperty(value, forName: key)
        }
    }

    /// PostHog's distinct id for this install. RevenueCat stamps this onto the
    /// subscriber (see `RevenueCatManager.linkAnalyticsIdentity`) so the
    /// lifecycle events RC forwards server-side resolve to the same person as
    /// the in-app events instead of a separate anonymous ghost.
    var postHogDistinctID: String? {
        snapshotProviders().first { $0.id == "posthog" }?.currentDistinctId
    }

    private func snapshotProviders() -> [AnalyticsProvider] {
        providersLock.lock()
        defer { providersLock.unlock() }
        return providers
    }

    /// Core fan-out, and the single choke point every analytics call in the app
    /// flows through. Global metadata from `AnalyticsContext` (app version,
    /// build, session id, subscription status, days since install, timestamp) is
    /// merged in here so no call site has to remember it. The call site wins on
    /// key collisions, so any event can still override a global value.
    private func dispatch(_ name: String, parameters: [String: Any], semantic: AnalyticsSemantic? = nil) {
        var enriched = AnalyticsContext.shared.properties()
        enriched.merge(parameters) { _, callSiteValue in callSiteValue }

        let event = AnalyticsEvent(name: name, parameters: enriched, semantic: semantic)
        for provider in snapshotProviders() where provider.isEnabled {
            provider.log(event)
        }
    }

    // MARK: Session

    private func startSession() {
        sessionStartTime = Date()
        dispatch("session_started", parameters: [
            "timestamp": Date().iso8601String,
            "platform": "ios"
        ])
    }

    func endSession() {
        guard let startTime = sessionStartTime else { return }
        let duration = Date().timeIntervalSince(startTime)

        dispatch("session_ended", parameters: [
            "session_duration": duration,
            "timestamp": Date().iso8601String
        ])
    }

    func trackScreenView(_ screenName: String, metadata: [String: Any] = [:]) {
        var params: [String: Any] = [
            "screen_name": screenName,
            "timestamp": Date().iso8601String,
            "previous_screen": currentScreen ?? "none"
        ]

        params.merge(metadata) { (_, new) in new }

        currentScreen = screenName

        dispatch("screen_viewed", parameters: params, semantic: .screenView(name: screenName))
    }

    func trackUserAction(_ action: String, category: String? = nil, metadata: [String: Any] = [:]) {
        var params: [String: Any] = [
            "action": action,
            "screen": currentScreen ?? "unknown",
            "timestamp": Date().iso8601String
        ]

        if let category = category {
            params["category"] = category
        }

        params.merge(metadata) { (_, new) in new }

        dispatch("user_action", parameters: params)
    }

    func trackContentInteraction(
        contentType: String,
        contentId: String,
        action: String,
        metadata: [String: Any] = [:]
    ) {
        var params: [String: Any] = [
            "content_type": contentType,
            "content_id": contentId,
            "action": action,
            "screen": currentScreen ?? "unknown",
            "timestamp": Date().iso8601String
        ]

        params.merge(metadata) { (_, new) in new }

        dispatch("content_interaction", parameters: params,
                 semantic: .contentView(type: contentType, id: contentId))
    }

    func trackAudioPlayback(
        audioId: String,
        audioTitle: String,
        action: AudioPlaybackAction,
        metadata: [String: Any] = [:]
    ) {
        var params: [String: Any] = [
            "audio_id": audioId,
            "audio_title": audioTitle,
            "action": action.rawValue,
            "screen": currentScreen ?? "unknown",
            "timestamp": Date().iso8601String
        ]

        params.merge(metadata) { (_, new) in new }

        dispatch("audio_playback", parameters: params)

        ListenerMetricsService.shared.trackListen(contentId: audioId, contentType: .audio)
    }

    func trackNavigation(from: String, to: String, method: NavigationMethod) {
        dispatch("navigation", parameters: [
            "from_screen": from,
            "to_screen": to,
            "method": method.rawValue,
            "timestamp": Date().iso8601String
        ])
    }

    func trackConversion(
        event: String,
        value: Double? = nil,
        currency: String = "USD",
        metadata: [String: Any] = [:]
    ) {
        var params: [String: Any] = [
            "conversion_event": event,
            "screen": currentScreen ?? "unknown",
            "timestamp": Date().iso8601String
        ]

        if let value = value {
            params["value"] = value
            params["currency"] = currency
        }

        params.merge(metadata) { (_, new) in new }

        let isPurchaseLike = event.contains("purchase") || event.contains("subscription") || event.contains("trial")
        let semantic: AnalyticsSemantic? = (isPurchaseLike && value != nil)
            ? .purchase(value: value!, currency: currency)
            : nil

        dispatch("conversion", parameters: params, semantic: semantic)
    }

    func trackShare(
        contentType: String,
        contentId: String,
        shareMethod: String,
        metadata: [String: Any] = [:]
    ) {
        var params: [String: Any] = [
            "content_type": contentType,
            "content_id": contentId,
            "share_method": shareMethod,
            "screen": currentScreen ?? "unknown",
            "timestamp": Date().iso8601String
        ]

        params.merge(metadata) { (_, new) in new }

        dispatch("content_shared", parameters: params, semantic: .share(contentType: contentType))
    }

    func trackFeatureUsage(_ featureName: String, metadata: [String: Any] = [:]) {
        var params: [String: Any] = [
            "feature_name": featureName,
            "screen": currentScreen ?? "unknown",
            "timestamp": Date().iso8601String
        ]

        params.merge(metadata) { (_, new) in new }

        dispatch("feature_used", parameters: params, semantic: .featureUsage(name: featureName))
    }

    func trackError(_ errorType: String, message: String, metadata: [String: Any] = [:]) {
        var params: [String: Any] = [
            "error_type": errorType,
            "error_message": message,
            "screen": currentScreen ?? "unknown",
            "timestamp": Date().iso8601String
        ]

        params.merge(metadata) { (_, new) in new }

        dispatch("error_occurred", parameters: params)
    }

    func setUserProperty(_ key: String, value: Any) {
        userProperties[key] = value

        for provider in snapshotProviders() {
            provider.setUserProperty(value, forName: key)
        }
    }

    /// Associate subsequent events with a known user id across all providers.
    func setUserId(_ id: String?) {
        for provider in snapshotProviders() {
            provider.setUserId(id)
        }
    }

    /// Generic passthrough for events that don't have a dedicated typed method.
    /// Fans out to every registered provider (Firebase, PostHog, …). Prefer this
    /// over calling `Analytics.logEvent` directly so new destinations — and the
    /// PostHog funnels built on them — actually receive the event.
    func track(_ name: String, parameters: [String: Any] = [:]) {
        dispatch(name, parameters: parameters)
    }

    func trackOnboarding(step: String, action: OnboardingAction, metadata: [String: Any] = [:]) {
        var params: [String: Any] = [
            "onboarding_step": step,
            "action": action.rawValue,
            "timestamp": Date().iso8601String
        ]

        params.merge(metadata) { (_, new) in new }

        dispatch("onboarding_event", parameters: params)
    }

    func trackSearch(query: String, resultCount: Int, category: String? = nil) {
        var params: [String: Any] = [
            "search_query": query.lowercased(),
            "result_count": resultCount,
            "screen": currentScreen ?? "unknown",
            "timestamp": Date().iso8601String
        ]

        if let category = category {
            params["category"] = category
        }

        dispatch("search_performed", parameters: params)
    }

    func trackEngagementMetric(
        metricType: EngagementMetric,
        value: Double,
        metadata: [String: Any] = [:]
    ) {
        var params: [String: Any] = [
            "metric_type": metricType.rawValue,
            "metric_value": value,
            "screen": currentScreen ?? "unknown",
            "timestamp": Date().iso8601String
        ]

        params.merge(metadata) { (_, new) in new }

        dispatch("engagement_metric", parameters: params)
    }

    // MARK: - Subscription Events

    func trackTrialStarted(productId: String, price: Double? = nil, metadata: [String: Any] = [:]) {
        var params: [String: Any] = [
            "product_id": productId,
            "screen": currentScreen ?? "unknown",
            "timestamp": Date().iso8601String
        ]

        if let price = price {
            params["value"] = price
            params["currency"] = "USD"
        }

        params.merge(metadata) { (_, new) in new }

        dispatch("trial_started", parameters: params,
                 semantic: .trialStarted(productId: productId, currency: "USD"))
    }

    func trackTrialActivated(productId: String, metadata: [String: Any] = [:]) {
        var params: [String: Any] = [
            "product_id": productId,
            "screen": currentScreen ?? "unknown",
            "timestamp": Date().iso8601String
        ]

        params.merge(metadata) { (_, new) in new }

        let price = metadata["price"] as? Double

        dispatch("trial_activated", parameters: params,
                 semantic: .trialConverted(productId: productId, price: price, currency: "USD"))
    }

    func trackPaywallImpression(paywallId: String, metadata: [String: Any] = [:]) {
        var params: [String: Any] = [
            "paywall_id": paywallId,
            "screen": currentScreen ?? "unknown",
            "timestamp": Date().iso8601String
        ]

        params.merge(metadata) { (_, new) in new }

        dispatch("paywall_impression", parameters: params,
                 semantic: .contentView(type: "paywall", id: paywallId))
    }

    func trackPaywallConversion(productId: String, paywallId: String, price: Double? = nil, metadata: [String: Any] = [:]) {
        var params: [String: Any] = [
            "product_id": productId,
            "paywall_id": paywallId,
            "screen": currentScreen ?? "unknown",
            "timestamp": Date().iso8601String
        ]

        if let price = price {
            params["price"] = price
            params["currency"] = "USD"
        }

        params.merge(metadata) { (_, new) in new }

        let semantic: AnalyticsSemantic? = price.map { .purchase(value: $0, currency: "USD") }

        dispatch("paywall_conversion", parameters: params, semantic: semantic)
    }

    func trackSubscriptionRenewal(productId: String, price: Double? = nil, metadata: [String: Any] = [:]) {
        var params: [String: Any] = [
            "product_id": productId,
            "screen": currentScreen ?? "unknown",
            "timestamp": Date().iso8601String
        ]

        if let price = price {
            params["price"] = price
            params["currency"] = "USD"
        }

        params.merge(metadata) { (_, new) in new }

        let semantic: AnalyticsSemantic? = price.map { .subscriptionRenewal(price: $0, currency: "USD") }

        dispatch("subscription_renewal", parameters: params, semantic: semantic)
    }

    func trackSubscriptionCancelled(productId: String, metadata: [String: Any] = [:]) {
        var params: [String: Any] = [
            "product_id": productId,
            "screen": currentScreen ?? "unknown",
            "timestamp": Date().iso8601String
        ]

        params.merge(metadata) { (_, new) in new }

        dispatch("subscription_cancelled", parameters: params)
    }
}

// MARK: - Built-in Providers

/// Firebase Analytics: logs the generic event name + parameters verbatim and
/// mirrors user properties. This is the canonical "log everything" sink.
final class FirebaseAnalyticsProvider: AnalyticsProvider {
    let id = "firebase"

    func log(_ event: AnalyticsEvent) {
        Analytics.logEvent(event.name, parameters: event.parameters)
    }

    func setUserProperty(_ value: Any, forName name: String) {
        if let stringValue = value as? String {
            Analytics.setUserProperty(stringValue, forName: name)
        }
    }

    func setUserId(_ id: String?) {
        Analytics.setUserID(id)
    }
}

/// TikTok Business SDK: fires native attribution events for the semantic cases
/// it cares about. Delegates to the existing `Event.trackTikTok*` helpers so
/// behavior is identical to the previous inline calls.
final class TikTokAnalyticsProvider: AnalyticsProvider {
    let id = "tiktok"

    func log(_ event: AnalyticsEvent) {
        guard let semantic = event.semantic else { return }

        switch semantic {
        case .screenView(let name):
            Event.trackTikTokContentView(contentType: "screen", contentId: name)
        case .contentView(let type, let contentId):
            Event.trackTikTokContentView(contentType: type, contentId: contentId)
        case .share(let contentType):
            Event.trackTikTokShare(contentType: contentType)
        case .purchase(let value, let currency):
            Event.trackTikTokPremiumPurchase(value: value, currency: currency)
        case .trialStarted:
            Event.trackTikTokEngagement(action: "trial_started", category: "subscription")
        case .trialConverted:
            Event.trackTikTokEngagement(action: "trial_activated", category: "subscription")
        case .featureUsage(let name):
            Event.trackTikTokEngagement(action: "feature_usage", category: name)
        case .engagement(let action, let category):
            Event.trackTikTokEngagement(action: action, category: category)
        case .subscriptionRenewal:
            break // TikTok does not track renewals.
        }
    }
}

/// Meta (Facebook) App Events: optimizes ad campaigns on subscription funnel
/// events. Only the purchase / trial semantics map to native Meta events.
final class MetaAnalyticsProvider: AnalyticsProvider {
    let id = "meta"

    func log(_ event: AnalyticsEvent) {
        guard let semantic = event.semantic else { return }

        switch semantic {
        case .trialStarted(let productId, let currency):
            // StartTrial is the primary optimization event for FB ad campaigns.
            AppEvents.shared.logEvent(
                AppEvents.Name("StartTrial"),
                valueToSum: 0.00,
                parameters: [
                    AppEvents.ParameterName("product_id"): productId as NSString,
                    AppEvents.ParameterName("currency"): currency as NSString
                ]
            )

        case .trialConverted(let productId, let price, let currency):
            // Trial converted to a paid subscription.
            guard let price = price else { return }
            AppEvents.shared.logEvent(
                AppEvents.Name("Subscribe"),
                valueToSum: price,
                parameters: [
                    AppEvents.ParameterName("product_id"): productId as NSString,
                    AppEvents.ParameterName("currency"): currency as NSString,
                    AppEvents.ParameterName("conversion_type"): "trial_to_paid" as NSString
                ]
            )
            AppEvents.shared.logPurchase(amount: price, currency: currency)

        case .subscriptionRenewal(let price, let currency):
            // Log renewals as purchases for LTV tracking.
            AppEvents.shared.logPurchase(amount: price, currency: currency)

        case .screenView, .contentView, .share, .purchase, .featureUsage, .engagement:
            break // Not optimized via Meta App Events.
        }
    }
}

// MARK: - PostHog Provider
//
// Product analytics: funnels, retention, cohorts, and session replay — the
// "why aren't users converting" layer that Firebase doesn't surface well.
//
// Setup:
//   1. Add the PostHog Swift package:
//        https://github.com/PostHog/posthog-ios  (File ▸ Add Packages…)
//   2. Register it in `registerDefaultProviders()` with your project API key.
//
// The SDK calls are guarded by `#if canImport(PostHog)`, so this file keeps
// compiling before the package is added; the provider becomes a no-op until
// then and lights up automatically once the dependency is present.
//
// To query / interpret the data programmatically (e.g. let an assistant pull
// funnels via HogQL), create a Personal API Key in PostHog → Settings, and
// hit the query API at `{host}/api/projects/{id}/query/`. That key is a
// server-side secret — do NOT ship it in the app; only the project `apiKey`
// (phc_…) belongs in `configure()`.

final class PostHogAnalyticsProvider: AnalyticsProvider {
    let id = "posthog"

    private let apiKey: String
    private let host: String
    private let enableSessionReplay: Bool

    init(apiKey: String,
         host: String = "https://us.i.posthog.com",
         enableSessionReplay: Bool = true) {
        self.apiKey = apiKey
        self.host = host
        self.enableSessionReplay = enableSessionReplay
    }

    func configure() {
        #if canImport(PostHog)
        let config = PostHogConfig(apiKey: apiKey, host: host)
        config.sessionReplay = enableSessionReplay
        // Mask sensitive text/images in replays by default; relax per-view as needed.
        config.sessionReplayConfig.maskAllTextInputs = true
        config.sessionReplayConfig.maskAllImages = false
        PostHogSDK.shared.setup(config)
        #endif
    }

    func log(_ event: AnalyticsEvent) {
        #if canImport(PostHog)
        // Use PostHog's native screen tracking so screens populate the
        // pageview/funnel UI correctly instead of being generic events.
        if case .screenView(let name) = event.semantic {
            PostHogSDK.shared.screen(name, properties: event.parameters)
            return
        }
        PostHogSDK.shared.capture(event.name, properties: event.parameters)
        #endif
    }

    func setUserProperty(_ value: Any, forName name: String) {
        #if canImport(PostHog)
        // Person properties attach to the current identified/anonymous user.
        PostHogSDK.shared.capture("$set", properties: ["$set": [name: value]])
        #endif
    }

    func setUserId(_ id: String?) {
        #if canImport(PostHog)
        if let id = id {
            PostHogSDK.shared.identify(id)
        } else {
            PostHogSDK.shared.reset()
        }
        #endif
    }

    /// Whatever id PostHog is filing events under right now — the anonymous
    /// install id until something calls `setUserId`, that id afterwards.
    var currentDistinctId: String? {
        #if canImport(PostHog)
        let id = PostHogSDK.shared.getDistinctId()
        return id.isEmpty ? nil : id
        #else
        return nil
        #endif
    }
}

enum AudioPlaybackAction: String {
    case started = "started"
    case paused = "paused"
    case resumed = "resumed"
    case completed = "completed"
    case skipped = "skipped"
    case seeked = "seeked"
    case progressMilestone = "progress_milestone"
    case stopped = "stopped"
}

enum NavigationMethod: String {
    case tab = "tab"
    case button = "button"
    case swipe = "swipe"
    case link = "link"
    case deeplink = "deeplink"
    case notification = "notification"
}

enum OnboardingAction: String {
    case started = "started"
    case completed = "completed"
    case skipped = "skipped"
    case viewed = "viewed"
}

enum EngagementMetric: String {
    case timeSpent = "time_spent"
    case scrollDepth = "scroll_depth"
    case completionRate = "completion_rate"
    case interactionCount = "interaction_count"
}

private extension Date {
    var iso8601String: String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: self)
    }
}
