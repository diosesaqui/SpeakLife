//
//  AIAnalyticsService.swift
//  SpeakLife
//
//  Comprehensive analytics for AI features to track performance and improvements
//

import Foundation
import FirebaseAnalytics
import FirebaseRemoteConfig

final class AIAnalyticsService: ObservableObject {
    
    static let shared = AIAnalyticsService()
    
    // MARK: - Analytics Events
    
    private init() {}
    
    // MARK: - AI Feature Performance Tracking
    
    func trackAIFeatureUsage(
        feature: AIFeature,
        action: AIAction,
        context: [String: Any] = [:],
        userTier: UserTier
    ) {
        var parameters: [String: Any] = [
            "ai_feature": feature.rawValue,
            "ai_action": action.rawValue,
            "user_tier": userTier.rawValue,
            "timestamp": Date().iso8601String,
            "app_version": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        ]
        
        parameters.merge(context) { (_, new) in new }
        
        Analytics.logEvent("ai_feature_usage", parameters: parameters)
        
        // Also track with existing analytics
        AnalyticsService.shared.trackUserAction(
            "ai_\(feature.rawValue)_\(action.rawValue)",
            category: "ai_features",
            metadata: parameters
        )
        
        print("🤖 AI Analytics: \(feature.rawValue) - \(action.rawValue)")
    }
    
    // MARK: - Recommendation Performance
    
    func trackRecommendationPerformance(
        recommendationId: String,
        category: SpiritualContentCategory,
        confidence: Double,
        userAction: RecommendationUserAction,
        timeSinceRecommended: TimeInterval,
        metadata: [String: Any] = [:]
    ) {
        let performanceData: [String: Any] = [
            "recommendation_id": recommendationId,
            "category": category.rawValue,
            "confidence": confidence,
            "user_action": userAction.rawValue,
            "time_to_action": timeSinceRecommended,
            "engagement_quality": calculateEngagementQuality(action: userAction, time: timeSinceRecommended),
            "timestamp": Date().iso8601String
        ]
        
        Analytics.logEvent("ai_recommendation_performance", parameters: performanceData)
        
        // Track conversion funnel
        trackRecommendationFunnel(userAction: userAction, confidence: confidence)
        
        print("📊 Recommendation Performance: \(userAction.rawValue) (confidence: \(confidence))")
    }
    
    func trackPersonalizedCategoryPerformance(
        categoryName: String,
        contentCount: Int,
        userEngagement: Double,
        confidenceScore: Double,
        sessionDuration: TimeInterval,
        completionRate: Double
    ) {
        let categoryData: [String: Any] = [
            "category_name": categoryName,
            "content_count": contentCount,
            "user_engagement": userEngagement,
            "confidence_score": confidenceScore,
            "session_duration": sessionDuration,
            "completion_rate": completionRate,
            "category_effectiveness": calculateCategoryEffectiveness(engagement: userEngagement, completion: completionRate),
            "timestamp": Date().iso8601String
        ]
        
        Analytics.logEvent("ai_personalized_category_performance", parameters: categoryData)
        
        print("🎯 Category Performance: \(categoryName) - engagement: \(userEngagement)")
    }
    
    // MARK: - AI Learning & Adaptation
    
    func trackMLModelPerformance(
        modelType: MLModelType,
        accuracy: Double,
        trainingDataSize: Int,
        inferenceTime: TimeInterval,
        memoryUsage: Double
    ) {
        let modelData: [String: Any] = [
            "model_type": modelType.rawValue,
            "accuracy": accuracy,
            "training_data_size": trainingDataSize,
            "inference_time_ms": inferenceTime * 1000,
            "memory_usage_mb": memoryUsage,
            "performance_score": calculateModelPerformanceScore(accuracy: accuracy, speed: inferenceTime),
            "timestamp": Date().iso8601String
        ]
        
        Analytics.logEvent("ai_model_performance", parameters: modelData)
        
        print("🧠 Model Performance: \(modelType.rawValue) - accuracy: \(accuracy)")
    }
    
    func trackUserBehaviorChange(
        changeType: BehaviorChangeType,
        previousValue: Double,
        newValue: Double,
        confidence: Double,
        triggeredAdaptation: Bool
    ) {
        let changeData: [String: Any] = [
            "change_type": changeType.rawValue,
            "previous_value": previousValue,
            "new_value": newValue,
            "change_magnitude": abs(newValue - previousValue),
            "change_direction": newValue > previousValue ? "increase" : "decrease",
            "confidence": confidence,
            "triggered_adaptation": triggeredAdaptation,
            "timestamp": Date().iso8601String
        ]
        
        Analytics.logEvent("ai_behavior_change_detected", parameters: changeData)
        
        print("📈 Behavior Change: \(changeType.rawValue) - \(previousValue) → \(newValue)")
    }
    
    // MARK: - User Experience & Satisfaction
    
    func trackAIUserExperience(
        feature: AIFeature,
        satisfactionScore: Int, // 1-5
        usabilityScore: Int, // 1-5
        relevanceScore: Int, // 1-5
        feedbackText: String? = nil,
        sessionContext: [String: Any] = [:]
    ) {
        var experienceData: [String: Any] = [
            "ai_feature": feature.rawValue,
            "satisfaction_score": satisfactionScore,
            "usability_score": usabilityScore,
            "relevance_score": relevanceScore,
            "overall_score": (satisfactionScore + usabilityScore + relevanceScore) / 3,
            "has_feedback": feedbackText != nil,
            "timestamp": Date().iso8601String
        ]
        
        experienceData.merge(sessionContext) { (_, new) in new }
        
        if let feedback = feedbackText {
            experienceData["feedback_length"] = feedback.count
            experienceData["feedback_sentiment"] = analyzeFeedbackSentiment(feedback)
        }
        
        Analytics.logEvent("ai_user_experience", parameters: experienceData)
        
        print("⭐ User Experience: \(feature.rawValue) - satisfaction: \(satisfactionScore)/5")
    }
    
    // MARK: - Conversion & Business Impact
    
    func trackAIConversionImpact(
        conversionType: ConversionType,
        attributedToAI: Bool,
        aiFeatureUsed: AIFeature?,
        conversionValue: Double? = nil,
        userJourneySteps: Int,
        timeToConversion: TimeInterval
    ) {
        var conversionData: [String: Any] = [
            "conversion_type": conversionType.rawValue,
            "attributed_to_ai": attributedToAI,
            "user_journey_steps": userJourneySteps,
            "time_to_conversion_hours": timeToConversion / 3600,
            "timestamp": Date().iso8601String
        ]
        
        if let aiFeature = aiFeatureUsed {
            conversionData["ai_feature_used"] = aiFeature.rawValue
        }
        
        if let value = conversionValue {
            conversionData["conversion_value"] = value
        }
        
        Analytics.logEvent("ai_conversion_impact", parameters: conversionData)
        
        // Track revenue attribution
        if attributedToAI && conversionType == .subscription {
            trackAIRevenueAttribution(value: conversionValue ?? 0, feature: aiFeatureUsed)
        }
        
        print("💰 Conversion Impact: \(conversionType.rawValue) - AI attributed: \(attributedToAI)")
    }
    
    // MARK: - A/B Testing & Feature Flags
    
    func trackABTestResult(
        testName: String,
        variant: String,
        metric: String,
        value: Double,
        isSignificant: Bool
    ) {
        let testData: [String: Any] = [
            "test_name": testName,
            "variant": variant,
            "metric": metric,
            "value": value,
            "is_significant": isSignificant,
            "timestamp": Date().iso8601String
        ]
        
        Analytics.logEvent("ai_ab_test_result", parameters: testData)
        
        print("🧪 A/B Test: \(testName) - \(variant) - \(metric): \(value)")
    }
    
    func trackFeatureFlagUsage(
        flagName: String,
        isEnabled: Bool,
        userSegment: String,
        featureUsed: Bool
    ) {
        let flagData: [String: Any] = [
            "flag_name": flagName,
            "is_enabled": isEnabled,
            "user_segment": userSegment,
            "feature_used": featureUsed,
            "timestamp": Date().iso8601String
        ]
        
        Analytics.logEvent("ai_feature_flag_usage", parameters: flagData)
        
        print("🚩 Feature Flag: \(flagName) - enabled: \(isEnabled), used: \(featureUsed)")
    }
    
    // MARK: - Error & Performance Monitoring
    
    func trackAIError(
        component: AIComponent,
        errorType: String,
        errorMessage: String,
        stackTrace: String? = nil,
        userImpact: ErrorImpact,
        recoveryAction: String? = nil
    ) {
        let errorData: [String: Any] = [
            "ai_component": component.rawValue,
            "error_type": errorType,
            "error_message": errorMessage,
            "user_impact": userImpact.rawValue,
            "has_stack_trace": stackTrace != nil,
            "has_recovery": recoveryAction != nil,
            "timestamp": Date().iso8601String
        ]
        
        Analytics.logEvent("ai_error_occurred", parameters: errorData)
        
        // Also log to existing error tracking
        AnalyticsService.shared.trackError("ai_\(component.rawValue)", message: errorMessage)
        
        print("❌ AI Error: \(component.rawValue) - \(errorType): \(errorMessage)")
    }
    
    func trackAIPerformanceMetrics(
        operation: AIOperation,
        executionTime: TimeInterval,
        memoryUsage: Double,
        cpuUsage: Double,
        batteryImpact: BatteryImpact
    ) {
        let performanceData: [String: Any] = [
            "ai_operation": operation.rawValue,
            "execution_time_ms": executionTime * 1000,
            "memory_usage_mb": memoryUsage,
            "cpu_usage_percent": cpuUsage,
            "battery_impact": batteryImpact.rawValue,
            "performance_score": calculatePerformanceScore(time: executionTime, memory: memoryUsage, cpu: cpuUsage),
            "timestamp": Date().iso8601String
        ]
        
        Analytics.logEvent("ai_performance_metrics", parameters: performanceData)
        
        print("⚡ Performance: \(operation.rawValue) - \(Int(executionTime * 1000))ms")
    }
    
    // MARK: - Helper Methods
    
    private func trackRecommendationFunnel(userAction: RecommendationUserAction, confidence: Double) {
        let funnelStage: String
        switch userAction {
        case .viewed: funnelStage = "recommendation_viewed"
        case .clicked: funnelStage = "recommendation_clicked"
        case .favorited: funnelStage = "recommendation_favorited"
        case .shared: funnelStage = "recommendation_shared"
        case .dismissed: funnelStage = "recommendation_dismissed"
        case .completed: funnelStage = "recommendation_completed"
        }
        
        Analytics.logEvent("ai_recommendation_funnel", parameters: [
            "funnel_stage": funnelStage,
            "confidence": confidence,
            "timestamp": Date().iso8601String
        ])
    }
    
    private func trackAIRevenueAttribution(value: Double, feature: AIFeature?) {
        var revenueData: [String: Any] = [
            "revenue_value": value,
            "attribution_source": "ai_features",
            "timestamp": Date().iso8601String
        ]
        
        if let feature = feature {
            revenueData["specific_ai_feature"] = feature.rawValue
        }
        
        Analytics.logEvent("ai_revenue_attribution", parameters: revenueData)
    }
    
    private func calculateEngagementQuality(action: RecommendationUserAction, time: TimeInterval) -> String {
        switch action {
        case .completed, .favorited, .shared:
            return "high"
        case .clicked:
            return time < 300 ? "medium" : "high" // 5 minutes threshold
        case .viewed:
            return time < 60 ? "low" : "medium" // 1 minute threshold
        case .dismissed:
            return "low"
        }
    }
    
    private func calculateCategoryEffectiveness(engagement: Double, completion: Double) -> String {
        let effectiveness = (engagement * 0.6) + (completion * 0.4)
        if effectiveness > 0.8 { return "high" }
        else if effectiveness > 0.5 { return "medium" }
        else { return "low" }
    }
    
    private func calculateModelPerformanceScore(accuracy: Double, speed: TimeInterval) -> Double {
        // Balance accuracy and speed (accuracy weighted more heavily)
        let speedScore = max(0, 1 - (speed / 5.0)) // 5 seconds max acceptable
        return (accuracy * 0.7) + (speedScore * 0.3)
    }
    
    private func analyzeFeedbackSentiment(_ feedback: String) -> String {
        let lowercased = feedback.lowercased()
        let positiveWords = ["great", "awesome", "love", "amazing", "helpful", "perfect"]
        let negativeWords = ["bad", "hate", "terrible", "useless", "confusing", "slow"]
        
        let positiveCount = positiveWords.filter { lowercased.contains($0) }.count
        let negativeCount = negativeWords.filter { lowercased.contains($0) }.count
        
        if positiveCount > negativeCount { return "positive" }
        else if negativeCount > positiveCount { return "negative" }
        else { return "neutral" }
    }
    
    private func calculatePerformanceScore(time: TimeInterval, memory: Double, cpu: Double) -> Double {
        let timeScore = max(0, 1 - (time / 10.0)) // 10 seconds max
        let memoryScore = max(0, 1 - (memory / 1000.0)) // 1GB max
        let cpuScore = max(0, 1 - (cpu / 100.0)) // 100% max
        
        return (timeScore * 0.5) + (memoryScore * 0.3) + (cpuScore * 0.2)
    }
}

// MARK: - Analytics Enums

enum AIFeature: String, CaseIterable {
    case personalizedFeed = "personalized_feed"
    case smartRecommendations = "smart_recommendations"
    case personalizedCategories = "personalized_categories"
    case aiNotifications = "ai_notifications"
    case spiritualInsights = "spiritual_insights"
    case contentCategorization = "content_categorization"
    case journalAnalysis = "journal_analysis"
    case crisisSupport = "crisis_support"
    case aiTasks = "ai_tasks"
    case spiritualMaturityTracking = "spiritual_maturity_tracking"
}

enum AIAction: String, CaseIterable {
    case viewed = "viewed"
    case interacted = "interacted"
    case accepted = "accepted"
    case dismissed = "dismissed"
    case customized = "customized"
    case shared = "shared"
    case completed = "completed"
    case failed = "failed"
}

enum UserTier: String, CaseIterable {
    case free = "free"
    case premium = "premium"
    case trial = "trial"
}

enum RecommendationUserAction: String, CaseIterable {
    case viewed = "viewed"
    case clicked = "clicked"
    case favorited = "favorited"
    case shared = "shared"
    case dismissed = "dismissed"
    case completed = "completed"
}

enum MLModelType: String, CaseIterable {
    case contentCategorization = "content_categorization"
    case recommendationEngine = "recommendation_engine"
    case emotionalToneDetection = "emotional_tone_detection"
    case spiritualMaturityAssessment = "spiritual_maturity_assessment"
}

enum BehaviorChangeType: String, CaseIterable {
    case categoryPreference = "category_preference"
    case usageFrequency = "usage_frequency"
    case sessionDuration = "session_duration"
    case spiritualMaturity = "spiritual_maturity"
    case engagementLevel = "engagement_level"
}

enum ConversionType: String, CaseIterable {
    case subscription = "subscription"
    case retention = "retention"
    case engagement = "engagement"
    case referral = "referral"
}

enum AIComponent: String, CaseIterable {
    case recommendationEngine = "recommendation_engine"
    case contentCategorization = "content_categorization"
    case mlTaskLibrary = "ml_task_library"
    case aiNotifications = "ai_notifications"
    case spiritualInsights = "spiritual_insights"
    case trainingPipeline = "training_pipeline"
}

enum ErrorImpact: String, CaseIterable {
    case none = "none"
    case minor = "minor"
    case moderate = "moderate"
    case severe = "severe"
    case critical = "critical"
}

enum AIOperation: String, CaseIterable {
    case contentCategorization = "content_categorization"
    case generateRecommendations = "generate_recommendations"
    case trainModel = "train_model"
    case analyzeJournal = "analyze_journal"
    case generateInsights = "generate_insights"
    case processUserBehavior = "process_user_behavior"
}

enum BatteryImpact: String, CaseIterable {
    case minimal = "minimal"
    case low = "low"
    case moderate = "moderate"
    case high = "high"
}

private extension Date {
    var iso8601String: String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: self)
    }
}