import Foundation
import FirebaseAnalytics
import TikTokBusinessSDK

final class AnalyticsService {
    
    static let shared = AnalyticsService()
    
    private var sessionStartTime: Date?
    private var currentScreen: String?
    private var userProperties: [String: Any] = [:]
    
    private init() {
        startSession()
    }
    
    private func startSession() {
        sessionStartTime = Date()
        Analytics.logEvent("session_started", parameters: [
            "timestamp": Date().iso8601String,
            "platform": "ios"
        ])
    }
    
    func endSession() {
        guard let startTime = sessionStartTime else { return }
        let duration = Date().timeIntervalSince(startTime)
        
        Analytics.logEvent("session_ended", parameters: [
            "session_duration": duration,
            "timestamp": Date().iso8601String
        ])
    }
    
    func trackScreenView(_ screenName: String, metadata: [String: Any] = [:]) {
        currentScreen = screenName
        
        var params: [String: Any] = [
            "screen_name": screenName,
            "timestamp": Date().iso8601String,
            "previous_screen": currentScreen ?? "none"
        ]
        
        params.merge(metadata) { (_, new) in new }
        
        Analytics.logEvent("screen_viewed", parameters: params)
        
        Event.trackTikTokContentView(contentType: "screen", contentId: screenName)
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
        
        Analytics.logEvent("user_action", parameters: params)
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
        
        Analytics.logEvent("content_interaction", parameters: params)
        
        Event.trackTikTokContentView(contentType: contentType, contentId: contentId)
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
        
        Analytics.logEvent("audio_playback", parameters: params)
        
        ListenerMetricsService.shared.trackListen(contentId: audioId, contentType: .audio)
    }
    
    func trackNavigation(from: String, to: String, method: NavigationMethod) {
        Analytics.logEvent("navigation", parameters: [
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
        
        Analytics.logEvent("conversion", parameters: params)
        
        if event.contains("purchase") || event.contains("subscription") {
            if let value = value {
                Event.trackTikTokPremiumPurchase(value: value, currency: currency)
            }
        }
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
        
        Analytics.logEvent("content_shared", parameters: params)
        
        Event.trackTikTokShare(contentType: contentType)
    }
    
    func trackFeatureUsage(_ featureName: String, metadata: [String: Any] = [:]) {
        var params: [String: Any] = [
            "feature_name": featureName,
            "screen": currentScreen ?? "unknown",
            "timestamp": Date().iso8601String
        ]
        
        params.merge(metadata) { (_, new) in new }
        
        Analytics.logEvent("feature_used", parameters: params)
        
        Event.trackTikTokEngagement(action: "feature_usage", category: featureName)
    }
    
    func trackError(_ errorType: String, message: String, metadata: [String: Any] = [:]) {
        var params: [String: Any] = [
            "error_type": errorType,
            "error_message": message,
            "screen": currentScreen ?? "unknown",
            "timestamp": Date().iso8601String
        ]
        
        params.merge(metadata) { (_, new) in new }
        
        Analytics.logEvent("error_occurred", parameters: params)
    }
    
    func setUserProperty(_ key: String, value: Any) {
        userProperties[key] = value
        
        if let stringValue = value as? String {
            Analytics.setUserProperty(stringValue, forName: key)
        }
    }
    
    func trackOnboarding(step: String, action: OnboardingAction, metadata: [String: Any] = [:]) {
        var params: [String: Any] = [
            "onboarding_step": step,
            "action": action.rawValue,
            "timestamp": Date().iso8601String
        ]
        
        params.merge(metadata) { (_, new) in new }
        
        Analytics.logEvent("onboarding_event", parameters: params)
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
        
        Analytics.logEvent("search_performed", parameters: params)
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
        
        Analytics.logEvent("engagement_metric", parameters: params)
    }
}

enum AudioPlaybackAction: String {
    case started = "started"
    case paused = "paused"
    case resumed = "resumed"
    case completed = "completed"
    case skipped = "skipped"
    case seeked = "seeked"
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