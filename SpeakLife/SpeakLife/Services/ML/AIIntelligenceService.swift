//
//  AIIntelligenceService.swift
//  SpeakLife
//
//  Main AI orchestrator service that coordinates all ML components
//

import Foundation
import Combine
import SwiftUI

final class AIIntelligenceService: ObservableObject {
    
    static let shared = AIIntelligenceService()
    
    // MARK: - Published Properties
    @Published var isAIReady = false
    @Published var currentlyProcessing = false
    @Published var lastUpdateDate: Date?
    @Published var aiPerformanceMetrics = AIPerformanceMetrics()
    
    // MARK: - Service Dependencies
    private let contentCategorization = ContentCategorizationService.shared
    private let recommendationEngine = RecommendationEngine.shared
    private let enhancedAnalytics = EnhancedAnalyticsService.shared
    private let mlTaskLibrary = MLTaskLibrary.shared
    private let trainingPipeline = CreateMLTrainingPipeline.shared
    private let notificationService = AINotificationService.shared
    
    // MARK: - State Management
    private var cancellables = Set<AnyCancellable>()
    private let processingQueue = DispatchQueue(label: "ai.intelligence", qos: .userInitiated)
    
    // Timer references for proper cleanup
    private var dailyTaskTimer: Timer?
    private var weeklyTaskTimer: Timer?
    
    private init() {
        setupAIServices()
        observeServiceReadiness()
    }
    
    deinit {
        // Clean up timers to prevent memory leaks
        dailyTaskTimer?.invalidate()
        weeklyTaskTimer?.invalidate()
        dailyTaskTimer = nil
        weeklyTaskTimer = nil
    }
    
    // MARK: - Service Initialization
    
    private func setupAIServices() {
        Task {
            await initializeAIServices()
        }
    }
    
    private func initializeAIServices() async {
        currentlyProcessing = true
        
        do {
            // Initialize services in parallel
            async let contentReady = contentCategorization.categorizeContent("sample")
            async let analyticsReady = enhancedAnalytics.trackSpiritualJourney(
                currentMood: "initialization",
                prayerRequests: [],
                journalSentiment: 0.0,
                recommendationAccepted: false
            )
            
            _ = await (contentReady, analyticsReady)
            
            // Start background AI tasks
            await startBackgroundProcessing()
            
            DispatchQueue.main.async {
                self.isAIReady = true
                self.currentlyProcessing = false
                self.lastUpdateDate = Date()
            }
            
            print("✅ AI Intelligence Service initialized successfully")
            
        } catch {
            print("❌ AI initialization failed: \(error)")
            DispatchQueue.main.async {
                self.currentlyProcessing = false
            }
        }
    }
    
    private func observeServiceReadiness() {
        contentCategorization.$isModelLoaded
            .combineLatest(enhancedAnalytics.$userBehaviorProfile)
            .sink { [weak self] modelLoaded, userProfile in
                if modelLoaded && !userProfile.favoriteDeclarationIds.isEmpty {
                    self?.triggerPersonalizedContentUpdate()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Main AI Operations
    
    func updatePersonalizedContent() async {
        guard isAIReady else {
            // Warning: 
            print("⚠️ AI services not ready")
            return
        }
        
        currentlyProcessing = true
        
        do {
            // Update all personalized content in parallel
            async let personalizedFeed = recommendationEngine.generatePersonalizedFeed()
            async let personalizedCategories = generatePersonalCategories()
            async let optimizedNotifications = optimizeNotificationTiming()
            
            let (feed, categories, notifications) = await (personalizedFeed, personalizedCategories, optimizedNotifications)
            
            // Cache results for quick access
            await cachePersonalizedContent(feed: feed, categories: categories)
            
            DispatchQueue.main.async {
                self.currentlyProcessing = false
                self.lastUpdateDate = Date()
                self.aiPerformanceMetrics.updateSuccess()
            }
            
            print("✅ Personalized content updated successfully")
            
        } catch {
            print("❌ Failed to update personalized content: \(error)")
            DispatchQueue.main.async {
                self.currentlyProcessing = false
                self.aiPerformanceMetrics.updateFailure()
            }
        }
    }
    
    func generatePersonalCategories() async -> [PersonalizedCategory] {
        let userBehavior = enhancedAnalytics.userBehaviorProfile
        return await contentCategorization.generatePersonalizedCategories(for: userBehavior)
    }
    
    func getTodayRecommendations() async -> [Declaration] {
        return await recommendationEngine.generatePersonalizedFeed()
    }
    
    func analyzeContentResonance(for declaration: Declaration, userAction: MLUserAction) async {
        // Calculate engagement score based on action
        let engagementScore = calculateEngagementScore(for: userAction)
        
        // Track with enhanced analytics
        enhancedAnalytics.trackContentResonance(
            contentId: declaration.id,
            declaration: declaration,
            action: userAction,
            engagementScore: engagementScore
        )
        
        // If engagement is high, trigger content learning
        if engagementScore > 0.7 {
            await triggerContentLearning(declaration: declaration, score: engagementScore)
        }
    }
    
    func generateSpiritualInsight(for content: String) async -> PersonalInsight? {
        let categories = await contentCategorization.categorizeContent(content)
        let userBehavior = enhancedAnalytics.userBehaviorProfile
        
        return await createPersonalizedInsight(
            content: content,
            categories: categories,
            userBehavior: userBehavior
        )
    }
    
    // MARK: - Crisis & Celebration Handling
    
    func handleSpiritualCrisis(_ situation: String) async {
        
        // Immediate support notification
        await notificationService.scheduleImmediateSupport(for: situation)
        
        // Update user's current life season
        enhancedAnalytics.trackSpiritualJourney(
            currentMood: "crisis",
            prayerRequests: [situation],
            journalSentiment: -0.8,
            recommendationAccepted: true,
            strugglingAreas: [situation]
        )
        
        // Generate crisis-specific recommendations
        let crisisRecommendations = await generateCrisisSupport(for: situation)
        await cacheEmergencyContent(crisisRecommendations)
        
        // Trigger immediate content update
        await updatePersonalizedContent()
    }
    
    func celebrateAchievement(_ achievement: String) async {
        
        // Celebration notification
        await notificationService.scheduleCelebration(for: achievement)
        
        // Update user's journey
        enhancedAnalytics.trackSpiritualJourney(
            currentMood: "celebration",
            prayerRequests: [],
            journalSentiment: 0.9,
            recommendationAccepted: true,
            growthAreas: [achievement]
        )
        
        // Update spiritual maturity if significant achievement
        await updateSpiritualMaturity(basedOn: achievement)
    }
    
    // MARK: - Learning & Adaptation
    
    func triggerModelRetraining() async {
        guard isAIReady else { return }
        
        
        await mlTaskLibrary.scheduleModelRetraining()
        
        // Update performance metrics
        DispatchQueue.main.async {
            self.aiPerformanceMetrics.lastRetrainingDate = Date()
        }
    }
    
    func optimizeUserExperience() async {
        // Analyze user patterns and optimize recommendations
        let userBehavior = enhancedAnalytics.userBehaviorProfile
        
        // Optimize notification timing
        await optimizeNotificationTiming()
        
        // Adapt content difficulty to spiritual maturity
        await adaptContentToMaturity(userBehavior.spiritualMaturityLevel)
        
        // Personalize category weights
        await personalizeContentWeights(userBehavior)
    }
    
    // MARK: - Background Processing
    
    private func startBackgroundProcessing() async {
        // Schedule periodic tasks
        await schedulePeriodicTasks()
        
        // Start continuous learning
        await enableContinuousLearning()
    }
    
    private func schedulePeriodicTasks() async {
        // Invalidate any existing timers before creating new ones
        await MainActor.run {
            dailyTaskTimer?.invalidate()
            weeklyTaskTimer?.invalidate()
            
            // Schedule daily content updates
            dailyTaskTimer = Timer.scheduledTimer(withTimeInterval: 86400, repeats: true) { [weak self] _ in
                Task {
                    await self?.updatePersonalizedContent()
                }
            }
            
            // Schedule weekly model improvements
            weeklyTaskTimer = Timer.scheduledTimer(withTimeInterval: 604800, repeats: true) { [weak self] _ in
                Task {
                    await self?.triggerModelRetraining()
                }
            }
        }
    }
    
    private func enableContinuousLearning() async {
        // Monitor user interactions and adapt in real-time
        enhancedAnalytics.$userBehaviorProfile
            .debounce(for: .seconds(30), scheduler: DispatchQueue.main)
            .sink { [weak self] updatedProfile in
                Task {
                    await self?.adaptToUserChanges(updatedProfile)
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Helper Methods
    
    private func calculateEngagementScore(for action: MLUserAction) -> Double {
        switch action {
        case .completed: return 1.0
        case .favorited: return 0.9
        case .shared: return 0.8
        case .replayed: return 0.7
        case .played: return 0.6
        case .viewed: return 0.4
        case .searchedFor: return 0.5
        case .journalConnected: return 0.8
        case .skipped: return 0.1
        }
    }
    
    private func triggerContentLearning(declaration: Declaration, score: Double) async {
        // Add to high-engagement content for future recommendations
        let categories = await contentCategorization.categorizeContent(declaration.text)
        
        // Boost similar content in recommendations
        await boostSimilarContent(categories: categories.spiritual, score: score)
    }
    
    private func createPersonalizedInsight(
        content: String,
        categories: ContentCategories,
        userBehavior: UserBehaviorFeatures
    ) async -> PersonalInsight {
        let primaryCategory = categories.spiritual.first ?? .faith
        
        let contextualMessage: String
        if userBehavior.strugglingAreas.contains(where: { $0.contains(primaryCategory.rawValue) }) {
            contextualMessage = "This directly addresses your current focus on \(primaryCategory.displayName.lowercased())"
        } else {
            contextualMessage = "This aligns with your spiritual journey in \(primaryCategory.displayName.lowercased())"
        }
        
        let applicationSuggestion: String?
        if userBehavior.preferredListeningTimes.contains(where: { $0 < 10 }) {
            applicationSuggestion = "Consider meditating on this during your morning routine"
        } else {
            applicationSuggestion = "Perfect for evening reflection"
        }
        
        let connectionToJourney = "Part of your \(userBehavior.spiritualMaturityLevel.displayName.lowercased()) spiritual development"
        
        return PersonalInsight(
            contextualMessage: contextualMessage,
            applicationSuggestion: applicationSuggestion,
            connectionToJourney: connectionToJourney,
            supportingScripture: nil,
            confidence: categories.confidence
        )
    }
    
    private func triggerPersonalizedContentUpdate() {
        Task {
            await updatePersonalizedContent()
        }
    }
    
    private func cachePersonalizedContent(feed: [Declaration], categories: [PersonalizedCategory]) async {
        // Cache for quick access - would use UserDefaults or CoreData
        let encoder = JSONEncoder()
        
        if let feedData = try? encoder.encode(feed.map { $0.id }) {
            UserDefaults.standard.set(feedData, forKey: "cached_personalized_feed")
        }
        
        if let categoriesData = try? encoder.encode(categories) {
            UserDefaults.standard.set(categoriesData, forKey: "cached_personalized_categories")
        }
    }
    
    private func optimizeNotificationTiming() async -> [Date] {
        return await recommendationEngine.getOptimalNotificationTimes()
    }
    
    private func generateCrisisSupport(for situation: String) async -> [Declaration] {
        // Map crisis situations to appropriate spiritual categories
        let crisisCategories: [SpiritualContentCategory]
        let lowercasedSituation = situation.lowercased()
        
        if lowercasedSituation.contains("heal") || lowercasedSituation.contains("sick") || lowercasedSituation.contains("pain") {
            crisisCategories = [.healing, .strength, .peace]
        } else if lowercasedSituation.contains("anxi") || lowercasedSituation.contains("worry") || lowercasedSituation.contains("fear") {
            crisisCategories = [.peace, .strength, .protection]
        } else if lowercasedSituation.contains("depress") || lowercasedSituation.contains("sad") || lowercasedSituation.contains("lonely") {
            crisisCategories = [.peace, .identity, .strength]
        } else if lowercasedSituation.contains("relation") || lowercasedSituation.contains("marriage") || lowercasedSituation.contains("family") {
            crisisCategories = [.relationships, .peace, .wisdom]
        } else if lowercasedSituation.contains("money") || lowercasedSituation.contains("job") || lowercasedSituation.contains("financial") {
            crisisCategories = [.prosperity, .strength, .faith]
        } else {
            crisisCategories = [.strength, .peace, .faith] // Default crisis support
        }
        
        // This would query your actual declaration database
        // For now, return sample crisis-appropriate declarations
        return [
            Declaration(text: "God is my refuge and strength, an ever-present help in trouble", category: .confidence),
            Declaration(text: "The peace of God, which surpasses all understanding, guards my heart and mind", category: .rest),
            Declaration(text: "I can do all things through Christ who strengthens me", category: .confidence)
        ]
    }
    
    private func cacheEmergencyContent(_ content: [Declaration]) async {
        // Cache emergency content for immediate access
        let encoder = JSONEncoder()
        
        if let encodedContent = try? encoder.encode(content.map { $0.id }) {
            UserDefaults.standard.set(encodedContent, forKey: "emergency_content_cache")
            UserDefaults.standard.set(Date(), forKey: "emergency_content_cache_date")
        }
        
    }
    
    private func updateSpiritualMaturity(basedOn achievement: String) async {
        let currentMaturity = enhancedAnalytics.userBehaviorProfile.spiritualMaturityLevel
        let userBehavior = enhancedAnalytics.userBehaviorProfile
        
        // Analyze achievement significance
        let isSignificantAchievement = achievement.lowercased().contains("month") || 
                                     achievement.lowercased().contains("year") ||
                                     achievement.lowercased().contains("breakthrough") ||
                                     achievement.lowercased().contains("leadership")
        
        if isSignificantAchievement {
            let newMaturity: SpiritualMaturity
            
            switch currentMaturity {
            case .newBeliever:
                // Check if they've been consistent for 30+ days
                if userBehavior.streakLength >= 30 && userBehavior.favoriteDeclarationIds.count >= 10 {
                    newMaturity = .growing
                } else {
                    newMaturity = currentMaturity
                }
                
            case .growing:
                // Check if they're engaging deeply and helping others
                if userBehavior.shareFrequency > 0.5 && userBehavior.topCategories.count >= 5 {
                    newMaturity = .mature
                } else {
                    newMaturity = currentMaturity
                }
                
            case .mature:
                // Check if they're in leadership roles or mentoring
                if achievement.lowercased().contains("leadership") || achievement.lowercased().contains("mentor") {
                    newMaturity = .leadership
                } else {
                    newMaturity = currentMaturity
                }
                
            case .leadership:
                newMaturity = currentMaturity // Already at highest level
            }
            
            if newMaturity != currentMaturity {
                // Update the user's maturity level
                enhancedAnalytics.userBehaviorProfile.spiritualMaturityLevel = newMaturity
                
                
                // Trigger content adaptation
                await adaptContentToMaturity(newMaturity)
                
                // Send congratulatory notification
                await notificationService.scheduleCelebration(for: "Spiritual Growth to \(newMaturity.displayName)")
            }
        }
    }
    
    private func adaptContentToMaturity(_ maturity: SpiritualMaturity) async {
        // Adjust recommendation weights based on spiritual maturity
        var categoryWeights: [String: Double] = [:]
        
        switch maturity {
        case .newBeliever:
            // Focus on foundational topics
            categoryWeights = [
                "identity": 1.5,
                "faith": 1.4,
                "peace": 1.3,
                "gratitude": 1.2,
                "protection": 1.1
            ]
            
        case .growing:
            // Balance foundation with growth
            categoryWeights = [
                "wisdom": 1.4,
                "purpose": 1.3,
                "breakthrough": 1.2,
                "relationships": 1.2,
                "strength": 1.1
            ]
            
        case .mature:
            // Focus on deeper spiritual themes
            categoryWeights = [
                "warfare": 1.4,
                "deliverance": 1.3,
                "breakthrough": 1.3,
                "wisdom": 1.2,
                "purpose": 1.2
            ]
            
        case .leadership:
            // Emphasize authority and influence
            categoryWeights = [
                "purpose": 1.5,
                "warfare": 1.4,
                "breakthrough": 1.3,
                "wisdom": 1.2,
                "strength": 1.2
            ]
        }
        
        // Store the weights for use in recommendations
        let encoder = JSONEncoder()
        if let weightsData = try? encoder.encode(categoryWeights) {
            UserDefaults.standard.set(weightsData, forKey: "ai_category_weights_\(maturity.rawValue)")
        }
        
    }
    
    private func personalizeContentWeights(_ userBehavior: UserBehaviorFeatures) async {
        var personalizedWeights: [String: Double] = [:]
        
        // Boost categories the user engages with most
        for (category, engagement) in userBehavior.topCategories {
            let normalizedEngagement = min(engagement / 10.0, 2.0) // Cap at 2x weight
            personalizedWeights[category] = 1.0 + normalizedEngagement
        }
        
        // Boost categories related to current struggles
        for struggle in userBehavior.strugglingAreas {
            let relatedCategories = mapStruggleToCategories(struggle)
            for category in relatedCategories {
                personalizedWeights[category] = (personalizedWeights[category] ?? 1.0) + 0.5
            }
        }
        
        // Boost categories related to growth areas
        for growthArea in userBehavior.growthAreas {
            let relatedCategories = mapGrowthToCategories(growthArea)
            for category in relatedCategories {
                personalizedWeights[category] = (personalizedWeights[category] ?? 1.0) + 0.3
            }
        }
        
        // Store personalized weights
        let encoder = JSONEncoder()
        if let weightsData = try? encoder.encode(personalizedWeights) {
            UserDefaults.standard.set(weightsData, forKey: "personalized_content_weights")
        }
        
        print("⚖️ Updated personalized content weights: \(personalizedWeights.count) categories")
    }
    
    private func adaptToUserChanges(_ updatedProfile: UserBehaviorFeatures) async {
        let lastActiveInterval = updatedProfile.lastActiveDate.timeIntervalSinceNow
        
        if lastActiveInterval < -86400 { // More than 1 day inactive
            await adjustForInactivity()
        }
        
        // Check for significant behavior changes
        let previousWeights = loadPreviousContentWeights()
        let currentWeights = updatedProfile.topCategories
        
        if hasSignificantWeightChanges(previous: previousWeights, current: currentWeights) {
            await personalizeContentWeights(updatedProfile)
            await updatePersonalizedContent()
        }
        
        // Check for new struggles or growth areas
        if !updatedProfile.strugglingAreas.isEmpty || !updatedProfile.growthAreas.isEmpty {
            await personalizeContentWeights(updatedProfile)
        }
    }
    
    private func adjustForInactivity() async {

        // Never tell an actively-engaged user "We've Missed You." A live streak
        // or a recent app open means they're here — a re-engagement push would
        // be wrong and erodes trust. (This guards the reported bug: a user on a
        // 3-day streak receiving "missed you" notifications.)
        let defaults = UserDefaults.standard
        let currentStreak = defaults.integer(forKey: "currentStreak")
        if currentStreak >= 1 {
            return
        }
        if let lastOpen = defaults.object(forKey: "lifecycle_last_open_date") as? Date,
           Date().timeIntervalSince(lastOpen) < 86400 {
            return
        }

        // Schedule a gentle, ONE-TIME re-engagement notification at a humane
        // daytime hour. Firing "1 hour from now" with no time-of-day guard could
        // land in the middle of the night; clamp to the next 10 AM instead.
        let reEngagementNotification = AINotification(
            declarationId: "re_engagement_gentle",
            declarationCategory: "faith",
            personalizedTitle: "We've Missed You",
            personalizedMessage: "Your spiritual journey is waiting - here's some encouragement",
            optimalTime: nextDaytimeReEngagementTime(),
            reason: "Re-engagement after inactivity",
            spiritualContext: "returning_user",
            confidence: 0.8,
            notificationType: .reminder
        )

        // This would use your existing notification scheduling
        await notificationService.scheduleAINotification(reEngagementNotification)

        // Adjust content to be more encouraging and less challenging
        let encouragingWeights = [
            "peace": 1.5,
            "gratitude": 1.4,
            "identity": 1.3,
            "faith": 1.2
        ]
        
        let encoder = JSONEncoder()
        if let weightsData = try? encoder.encode(encouragingWeights) {
            UserDefaults.standard.set(weightsData, forKey: "re_engagement_weights")
        }
    }

    /// Next occurrence of 10 AM. Re-engagement should arrive when a returning
    /// user can actually act on it — never at 1 AM. If it's already past 10 AM
    /// today, target 10 AM tomorrow.
    private func nextDaytimeReEngagementTime() -> Date {
        let calendar = Calendar.current
        let now = Date()
        let todayTen = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: now) ?? now
        if todayTen > now {
            return todayTen
        }
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        return calendar.date(bySettingHour: 10, minute: 0, second: 0, of: tomorrow) ?? tomorrow
    }

    private func boostSimilarContent(categories: [SpiritualContentCategory], score: Double) async {
        // Load current content weights
        var contentWeights = loadCurrentContentWeights()
        
        // Boost similar categories based on engagement score
        let boostAmount = score * 0.3 // Scale boost based on engagement
        
        for category in categories {
            let currentWeight = contentWeights[category.rawValue] ?? 1.0
            contentWeights[category.rawValue] = currentWeight + boostAmount
        }
        
        // Save updated weights
        let encoder = JSONEncoder()
        if let weightsData = try? encoder.encode(contentWeights) {
            UserDefaults.standard.set(weightsData, forKey: "content_boost_weights")
            UserDefaults.standard.set(Date(), forKey: "content_boost_last_update")
        }
        
    }
    
    // MARK: - Helper Methods for Content Weights
    
    private func mapStruggleToCategories(_ struggle: String) -> [String] {
        let lowercased = struggle.lowercased()
        
        if lowercased.contains("anxi") || lowercased.contains("worry") {
            return ["peace", "strength", "protection"]
        } else if lowercased.contains("depress") || lowercased.contains("sad") {
            return ["peace", "identity", "healing"]
        } else if lowercased.contains("relation") || lowercased.contains("marriage") {
            return ["relationships", "wisdom", "peace"]
        } else if lowercased.contains("financial") || lowercased.contains("money") {
            return ["prosperity", "faith", "strength"]
        } else if lowercased.contains("health") || lowercased.contains("sick") {
            return ["healing", "strength", "faith"]
        } else {
            return ["strength", "faith", "peace"]
        }
    }
    
    private func mapGrowthToCategories(_ growthArea: String) -> [String] {
        let lowercased = growthArea.lowercased()
        
        if lowercased.contains("leader") {
            return ["purpose", "wisdom", "strength"]
        } else if lowercased.contains("faith") {
            return ["faith", "breakthrough", "wisdom"]
        } else if lowercased.contains("relation") {
            return ["relationships", "wisdom", "peace"]
        } else if lowercased.contains("purpose") {
            return ["purpose", "wisdom", "breakthrough"]
        } else {
            return ["wisdom", "growth", "breakthrough"]
        }
    }
    
    private func loadPreviousContentWeights() -> [String: Double] {
        guard let weightsData = UserDefaults.standard.data(forKey: "personalized_content_weights"),
              let weights = try? JSONDecoder().decode([String: Double].self, from: weightsData) else {
            return [:]
        }
        return weights
    }
    
    private func loadCurrentContentWeights() -> [String: Double] {
        guard let weightsData = UserDefaults.standard.data(forKey: "content_boost_weights"),
              let weights = try? JSONDecoder().decode([String: Double].self, from: weightsData) else {
            return [:]
        }
        return weights
    }
    
    private func hasSignificantWeightChanges(previous: [String: Double], current: [String: Double]) -> Bool {
        // Check if any category weight has changed by more than 20%
        for (category, currentValue) in current {
            let previousValue = previous[category] ?? 0.0
            let changePercent = abs(currentValue - previousValue) / max(previousValue, 0.1)
            if changePercent > 0.2 {
                return true
            }
        }
        return false
    }
}

// MARK: - Performance Metrics

struct AIPerformanceMetrics {
    var totalRecommendations: Int = 0
    var successfulRecommendations: Int = 0
    var averageConfidence: Double = 0.0
    var lastRetrainingDate: Date?
    var userSatisfactionScore: Double = 0.0
    
    var successRate: Double {
        guard totalRecommendations > 0 else { return 0.0 }
        return Double(successfulRecommendations) / Double(totalRecommendations)
    }
    
    mutating func updateSuccess() {
        totalRecommendations += 1
        successfulRecommendations += 1
    }
    
    mutating func updateFailure() {
        totalRecommendations += 1
    }
}

// MARK: - Integration Extensions

extension AIIntelligenceService {
    
    /// Call this when user interacts with content
    func trackUserInteraction(
        declaration: Declaration,
        action: MLUserAction,
        context: [String: Any] = [:]
    ) {
        Task {
            await analyzeContentResonance(for: declaration, userAction: action)
        }
    }
    
    /// Call this when user writes a journal entry
    func analyzeJournalEntry(_ text: String) async -> [Declaration] {
        return await contentCategorization.getDeclarationsForJournalEntry(text)
    }
    
    /// Call this when user searches
    func enhanceSearch(_ query: String) async -> [SearchSuggestion] {
        return await contentCategorization.interpretSearchIntent(query)
    }
    
    /// Call this when user needs crisis support
    func provideCrisisSupport(_ situation: String) {
        Task {
            await handleSpiritualCrisis(situation)
        }
    }
    
    /// Call this when user achieves something
    func celebrateWithUser(_ achievement: String) {
        Task {
            await celebrateAchievement(achievement)
        }
    }
}

// MARK: - SwiftUI Integration

extension AIIntelligenceService {
    
    /// Returns AI readiness status for UI
    var aiStatusText: String {
        if currentlyProcessing {
            return "AI is learning about you..."
        } else if isAIReady {
            return "AI ready • \(Int(aiPerformanceMetrics.successRate * 100))% accuracy"
        } else {
            return "Initializing AI..."
        }
    }
    
    /// Returns AI performance for debugging/premium users
    var performanceDetails: String {
        """
        Recommendations: \(aiPerformanceMetrics.totalRecommendations)
        Success Rate: \(Int(aiPerformanceMetrics.successRate * 100))%
        Last Update: \(lastUpdateDate?.formatted() ?? "Never")
        """
    }
}