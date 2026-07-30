//
//  EnhancedAnalyticsService.swift
//  SpeakLife
//
//  Enhanced analytics for ML training data collection
//

import Foundation
import FirebaseAnalytics
import Combine

final class EnhancedAnalyticsService: ObservableObject {
    
    static let shared = EnhancedAnalyticsService()
    
    private let userDefaults = UserDefaults.standard
    private let mlDataKey = "ml_user_behavior_data"
    private let trainingEventsKey = "ml_training_events"
    
    @Published var userBehaviorProfile = UserBehaviorFeatures()
    private var trainingEvents: [MLTrainingEvent] = []
    private var currentSessionId = UUID().uuidString
    private var sessionStartTime = Date()
    
    private init() {
        loadUserBehaviorProfile()
        startNewSession()
    }
    
    // MARK: - Session Management
    private func startNewSession() {
        currentSessionId = UUID().uuidString
        sessionStartTime = Date()
        userBehaviorProfile.lastActiveDate = Date()
    }
    
    func endSession() {
        let sessionDuration = Date().timeIntervalSince(sessionStartTime)
        userBehaviorProfile.sessionDuration = sessionDuration
        saveUserBehaviorProfile()
        
        // Send batch of training events
        if !trainingEvents.isEmpty {
            processBatchTrainingEvents()
        }
    }
    
    // MARK: - ML-Enhanced Content Tracking
    func trackContentResonance(
        contentId: String,
        declaration: Declaration,
        action: MLUserAction,
        engagementScore: Double,
        spiritualContext: [String: Any] = [:]
    ) {
        // Update user behavior profile
        updateBehaviorProfile(for: declaration, action: action, engagementScore: engagementScore)
        
        // Create ML training event
        let mlEvent = MLTrainingEvent(
            userId: getCurrentUserId(),
            contentId: contentId,
            action: action,
            spiritualContext: createSpiritualContext(from: spiritualContext),
            timestamp: Date(),
            sessionId: currentSessionId,
            deviceContext: createDeviceContext()
        )
        
        trainingEvents.append(mlEvent)
        
        // Also track in original analytics
        AnalyticsService.shared.trackContentInteraction(
            contentType: "declaration",
            contentId: contentId,
            action: action.rawValue,
            metadata: [
                "engagement_score": engagementScore,
                "ml_enhanced": true
            ]
        )
    }
    
    func trackSpiritualJourney(
        currentMood: String,
        prayerRequests: [String],
        journalSentiment: Double,
        recommendationAccepted: Bool,
        strugglingAreas: [String] = [],
        growthAreas: [String] = []
    ) {
        // Update spiritual journey indicators
        userBehaviorProfile.currentLifeSeason = currentMood
        userBehaviorProfile.prayerRequestTopics = prayerRequests
        userBehaviorProfile.strugglingAreas = strugglingAreas
        userBehaviorProfile.growthAreas = growthAreas
        
        // Infer spiritual maturity based on patterns
        updateSpiritualMaturityLevel()
        
        saveUserBehaviorProfile()
        
        AnalyticsService.shared.track("spiritual_journey_tracked", parameters: [
            "mood": currentMood,
            "journal_sentiment": journalSentiment,
            "recommendation_accepted": recommendationAccepted,
            "struggling_areas_count": strugglingAreas.count,
            "growth_areas_count": growthAreas.count
        ])
    }
    
    func trackContextualUsage(
        timeOfDay: Int,
        dayOfWeek: Int,
        sessionType: String, // "morning_devotion", "crisis_support", "evening_reflection"
        duration: TimeInterval
    ) {
        // Update temporal patterns
        if !userBehaviorProfile.preferredListeningTimes.contains(timeOfDay) {
            userBehaviorProfile.preferredListeningTimes.append(timeOfDay)
        }
        
        userBehaviorProfile.weeklyPattern[dayOfWeek - 1] += 14
        userBehaviorProfile.dailyUsageFrequency += 1
        
        saveUserBehaviorProfile()
        
        AnalyticsService.shared.track("contextual_usage", parameters: [
            "time_of_day": timeOfDay,
            "day_of_week": dayOfWeek,
            "session_type": sessionType,
            "duration": duration
        ])
    }
    
    func trackRecommendationInteraction(
        recommendationId: String,
        accepted: Bool,
        reason: String,
        confidence: Double,
        userFeedback: String? = nil
    ) {
        AnalyticsService.shared.track("recommendation_interaction", parameters: [
            "recommendation_id": recommendationId,
            "accepted": accepted,
            "reason": reason,
            "confidence": confidence,
            "has_feedback": userFeedback != nil
        ])
        
        // Update recommendation acceptance patterns for future learning
        let key = "recommendation_\(reason)_acceptance"
        let currentRate = userDefaults.double(forKey: key)
        let newRate = accepted ? (currentRate + 0.1) : (currentRate - 0.1)
        userDefaults.set(max(0.0, min(1.0, newRate)), forKey: key)
    }
    
    // MARK: - Personal Category Generation Data
    func trackPersonalCategoryCreation(
        categoryName: String,
        contentIds: [String],
        userEngagement: Double,
        spiritualFocus: [SpiritualContentCategory]
    ) {
        AnalyticsService.shared.track("personal_category_created", parameters: [
            "category_name": categoryName,
            "content_count": contentIds.count,
            "engagement_score": userEngagement,
            "spiritual_focus_count": spiritualFocus.count
        ])
    }
    
    func trackAITaskCompletion(
        taskId: String,
        taskType: String,
        completionRate: Double,
        userSatisfaction: Int // 1-5 rating
    ) {
        AnalyticsService.shared.track("ai_task_completed", parameters: [
            "task_id": taskId,
            "task_type": taskType,
            "completion_rate": completionRate,
            "satisfaction": userSatisfaction
        ])
    }
    
    // MARK: - Behavior Profile Updates
    private func updateBehaviorProfile(for declaration: Declaration, action: MLUserAction, engagementScore: Double) {
        let categoryKey = declaration.category.rawValue
        
        // Update category engagement
        let currentScore = userBehaviorProfile.topCategories[categoryKey] ?? 0.0
        userBehaviorProfile.topCategories[categoryKey] = currentScore + engagementScore
        
        // Update completion rates
        if action == .completed {
            let currentRate = userBehaviorProfile.completionRates[categoryKey] ?? 0.0
            userBehaviorProfile.completionRates[categoryKey] = (currentRate + 1.0) / 2.0
        }
        
        // Track favorites
        if action == .favorited {
            if !userBehaviorProfile.favoriteDeclarationIds.contains(declaration.id) {
                userBehaviorProfile.favoriteDeclarationIds.append(declaration.id)
            }
        }
        
        // Update audio vs text preferences
        if action == .played || action == .completed {
            userBehaviorProfile.audioToTextRatio = min(1.0, userBehaviorProfile.audioToTextRatio + 0.1)
        }
    }
    
    private func updateSpiritualMaturityLevel() {
        let favoriteCount = userBehaviorProfile.favoriteDeclarationIds.count
        let categoryEngagement = userBehaviorProfile.topCategories.count
        let streakLength = userBehaviorProfile.streakLength
        
        // Simple heuristic for spiritual maturity
        if favoriteCount > 50 && categoryEngagement > 10 && streakLength > 30 {
            userBehaviorProfile.spiritualMaturityLevel = .leadership
        } else if favoriteCount > 20 && categoryEngagement > 5 && streakLength > 14 {
            userBehaviorProfile.spiritualMaturityLevel = .mature
        } else if favoriteCount > 5 && categoryEngagement > 2 && streakLength > 3 {
            userBehaviorProfile.spiritualMaturityLevel = .growing
        } else {
            userBehaviorProfile.spiritualMaturityLevel = .newBeliever
        }
    }
    
    // MARK: - Data Collection for Training
    func collectTrainingData() -> [DeclarationTrainingExample] {
        // This would be called periodically to prepare data for CreateML training
        // Implementation would collect anonymized user interaction data
        return []
    }
    
    func getPersonalizedInsights() -> [PersonalInsight] {
        var insights: [PersonalInsight] = []
        
        // Generate insights based on behavior patterns
        if let topCategory = userBehaviorProfile.topCategories.max(by: { $0.value < $1.value }) {
            let insight = PersonalInsight(
                contextualMessage: "You've been drawn to \(topCategory.key) content lately",
                applicationSuggestion: "Consider setting aside 10 minutes each morning for \(topCategory.key) declarations",
                connectionToJourney: "This aligns with your current spiritual focus",
                supportingScripture: nil,
                confidence: 0.8
            )
            insights.append(insight)
        }
        
        return insights
    }
    
    // MARK: - Helper Methods
    private func createSpiritualContext(from metadata: [String: Any]) -> MLTrainingEvent.SpiritualContext {
        return MLTrainingEvent.SpiritualContext(
            currentStreak: userBehaviorProfile.streakLength,
            timeOfDay: Calendar.current.component(.hour, from: Date()),
            dayOfWeek: Calendar.current.component(.weekday, from: Date()),
            recentJournalSentiment: metadata["journal_sentiment"] as? Double,
            currentLifeSeason: userBehaviorProfile.currentLifeSeason,
            activeStruggles: userBehaviorProfile.strugglingAreas
        )
    }
    
    private func createDeviceContext() -> MLTrainingEvent.DeviceContext {
        return MLTrainingEvent.DeviceContext(
            platform: "ios",
            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
            isBackground: false
        )
    }
    
    private func getCurrentUserId() -> String {
        // Return anonymous user identifier for ML purposes
        return UIDevice.current.identifierForVendor?.uuidString ?? "anonymous"
    }
    
    private func processBatchTrainingEvents() {
        guard !trainingEvents.isEmpty else {
            print("ℹ️ No training events to process")
            return
        }
        
        do {
            // In a real implementation, this would send to ML pipeline
            
            // Only clear events after successful processing
            // For now, we'll just clear them since this is a stub
            trainingEvents.removeAll()
            print("✅ Training events processed successfully")
        } catch {
            // Warning: 
            print("⚠️ Failed to process training events: \(error)")
            // Keep events for retry
        }
    }
    
    // MARK: - Persistence
    private func saveUserBehaviorProfile() {
        do {
            let encoded = try JSONEncoder().encode(userBehaviorProfile)
            userDefaults.set(encoded, forKey: mlDataKey)
        } catch {
            // Warning: 
            print("⚠️ Failed to save user behavior profile: \(error)")
            // Consider fallback or retry logic here
        }
    }
    
    private func loadUserBehaviorProfile() {
        guard let data = userDefaults.data(forKey: mlDataKey) else {
            print("ℹ️ No saved user behavior profile found, using defaults")
            return
        }
        
        do {
            userBehaviorProfile = try JSONDecoder().decode(UserBehaviorFeatures.self, from: data)
            print("✅ User behavior profile loaded successfully")
        } catch {
            // Warning: 
            print("⚠️ Failed to load user behavior profile: \(error)")
            // Keep using default userBehaviorProfile
        }
    }
    
    // MARK: - ML Training Analytics
    
    func trackMLTraining(
        modelType: String,
        dataSize: Int,
        startTime: Date
    ) {
        let trainingData: [String: Any] = [
            "model_type": modelType,
            "data_size": dataSize,
            "timestamp": startTime.timeIntervalSince1970,
            "platform": "iOS"
        ]
        
        AnalyticsService.shared.trackUserAction(
            "ml_training_\(modelType)",
            category: "ai_system",
            metadata: trainingData
        )
        
    }
}

// MARK: - Extensions for Integration
extension Declaration {
    var mlCategories: [SpiritualContentCategory] {
        // Map existing categories to ML categories
        var mlCats: [SpiritualContentCategory] = []
        
        switch self.category {
        case .faith: mlCats.append(.faith)
        case .health, .innerHealing: mlCats.append(.healing)
        case .wealth, .favor: mlCats.append(.prosperity)
        case .godsprotection: mlCats.append(.protection)
        case .marriage, .friendship, .love: mlCats.append(.relationships)
        case .destiny: mlCats.append(.purpose)
        case .rest: mlCats.append(.peace)
        case .confidence: mlCats.append(.strength)
        case .wisdom: mlCats.append(.wisdom)
        case .gratitude, .praise: mlCats.append(.gratitude)
        case .addiction, .fear: mlCats.append(.deliverance)
        case .miracles, .warfare: mlCats.append(.breakthrough)
        case .identity: mlCats.append(.identity)
        default: mlCats.append(.faith)
        }
        
        return mlCats
    }
}
