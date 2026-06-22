//
//  AINotificationService.swift
//  SpeakLife
//
//  AI-powered notification scheduling and personalization
//

import Foundation
import UserNotifications

final class AINotificationService {
    
    static let shared = AINotificationService()
    
    private let notificationCenter = UNUserNotificationCenter.current()
    
    private init() {}
    
    // MARK: - AI-Enhanced Notification Scheduling
    
    func schedulePersonalizedNotifications(
        count: Int = 3,
        timeRange: ClosedRange<Int> = 7...21
    ) async {
        guard await requestNotificationPermission() else {
            // Warning: 
            print("⚠️ Notification permission not granted")
            return
        }
        
        // Generate AI-powered notifications
        // NOTE: previously called removeAllPendingNotificationRequests() here, which
        // wiped lifecycle pushes (D1-D30), streak triggers, daily burst rotations,
        // AND the personal_declaration_reminder. That entry point is currently
        // unreachable (registerAINotifications has no callers), but leaving the
        // wipe in place is a landmine: anyone wiring this in would silently break
        // the entire retention system. Schedule by stable ID like everything else.
        let aiNotifications = await generatePersonalizedNotifications(
            count: count,
            timeRange: timeRange
        )
        
        // Schedule notifications
        for notification in aiNotifications {
            await scheduleAINotification(notification)
        }
        
        print("✅ Scheduled \(aiNotifications.count) AI-personalized notifications")
    }
    
    func generatePersonalizedNotifications(
        count: Int,
        timeRange: ClosedRange<Int>
    ) async -> [AINotification] {
        let userBehavior = EnhancedAnalyticsService.shared.userBehaviorProfile
        var notifications: [AINotification] = []
        
        // Get optimal times from user behavior
        let optimalTimes = await getOptimalNotificationTimes(
            count: count,
            timeRange: timeRange,
            userBehavior: userBehavior
        )
        
        for (index, time) in optimalTimes.enumerated() {
            let notification = await createPersonalizedNotification(
                for: time,
                index: index,
                userBehavior: userBehavior
            )
            notifications.append(notification)
        }
        
        return notifications
    }
    
    // MARK: - Contextual Notification Generation
    
    private func createPersonalizedNotification(
        for date: Date,
        index: Int,
        userBehavior: UserBehaviorFeatures
    ) async -> AINotification {
        let hour = Calendar.current.component(.hour, from: date)
        let notificationType = determineNotificationType(hour: hour, userBehavior: userBehavior)
        
        // Get contextual content for this time/user
        let declarationId = await getContextualDeclaration(
            hour: hour,
            userBehavior: userBehavior,
            type: notificationType
        )
        
        // Determine category based on user behavior or notification type
        let category = determineDeclarationCategory(userBehavior: userBehavior, type: notificationType)
        
        // Generate personalized message
        let (title, message) = await generatePersonalizedMessage(
            hour: hour,
            type: notificationType,
            userBehavior: userBehavior
        )
        
        // Create reasoning
        let reason = await generateNotificationReason(
            hour: hour,
            type: notificationType,
            userBehavior: userBehavior
        )
        
        return AINotification(
            declarationId: declarationId,
            declarationCategory: category,
            personalizedTitle: title,
            personalizedMessage: message,
            optimalTime: date,
            reason: reason,
            spiritualContext: userBehavior.currentLifeSeason,
            confidence: calculateNotificationConfidence(hour: hour, userBehavior: userBehavior),
            notificationType: notificationType
        )
    }
    
    private func determineNotificationType(hour: Int, userBehavior: UserBehaviorFeatures) -> AINotification.NotificationType {
        switch hour {
        case 5...9:
            return .morning
        case 10...14:
            return .midday
        case 15...21:
            return .evening
        default:
            return .reminder
        }
    }
    
    private func determineDeclarationCategory(userBehavior: UserBehaviorFeatures, type: AINotification.NotificationType) -> String {
        // Determine category based on user's struggling areas, growth areas, or time of day
        if !userBehavior.strugglingAreas.isEmpty {
            let area = userBehavior.strugglingAreas.first!
            switch area {
            case "Fear": return "fear"
            case "Anxiety": return "anxiety"
            case "Hard Times": return "hardtimes"
            case "Faith": return "faith"
            case "Hope": return "hope"
            default: return "general"
            }
        } else if !userBehavior.growthAreas.isEmpty {
            let area = userBehavior.growthAreas.first!
            switch area {
            case "Wisdom": return "wisdom"
            case "Love": return "love"
            case "Joy": return "joy"
            case "Identity": return "identity"
            default: return "general"
            }
        } else {
            // Default categories based on time of day
            switch type {
            case .morning: return "gratitude"
            case .midday: return "strength"
            case .evening: return "rest"
            default: return "general"
            }
        }
    }
    
    private func generatePersonalizedMessage(
        hour: Int,
        type: AINotification.NotificationType,
        userBehavior: UserBehaviorFeatures
    ) async -> (title: String, message: String) {
        let primaryStruggle = userBehavior.strugglingAreas.first
        let primaryGrowth = userBehavior.growthAreas.first
        let maturityLevel = userBehavior.spiritualMaturityLevel
        
        switch type {
        case .morning:
            if let struggle = primaryStruggle {
                return (
                    title: "Morning Strength for Your Journey",
                    message: "Here's encouragement for your \(struggle) breakthrough today"
                )
            } else if let growth = primaryGrowth {
                return (
                    title: "Your Daily Growth Moment",
                    message: "Strengthening your \(growth) walk this morning"
                )
            } else {
                return (
                    title: "Start Strong Today",
                    message: "Your morning declaration is ready to empower your day"
                )
            }
            
        case .midday:
            if userBehavior.preferredListeningTimes.contains(where: { abs($0 - hour) <= 1 }) {
                return (
                    title: "Your Perfect Timing",
                    message: "It's your usual time for spiritual encouragement"
                )
            } else {
                return (
                    title: "Midday Boost",
                    message: "A moment of spiritual strength for your day"
                )
            }
            
        case .evening:
            switch maturityLevel {
            case .newBeliever:
                return (
                    title: "Evening Peace",
                    message: "End your day with God's love and rest"
                )
            case .growing:
                return (
                    title: "Reflect & Grow",
                    message: "Evening wisdom for your spiritual journey"
                )
            case .mature:
                return (
                    title: "Deep Rest",
                    message: "Mature reflection for tonight's peace"
                )
            case .leadership:
                return (
                    title: "Leader's Rest",
                    message: "Restorative truth for those who serve"
                )
            }
            
        case .crisis:
            return (
                title: "Immediate Comfort",
                message: "God's strength for whatever you're facing right now"
            )
            
        case .celebration:
            return (
                title: "Praise & Gratitude",
                message: "Celebrating God's goodness in your life"
            )
            
        case .reminder:
            return (
                title: "Your Spiritual Moment",
                message: "A gentle reminder of God's love for you"
            )
        }
    }
    
    private func generateNotificationReason(
        hour: Int,
        type: AINotification.NotificationType,
        userBehavior: UserBehaviorFeatures
    ) async -> String {
        if userBehavior.preferredListeningTimes.contains(where: { abs($0 - hour) <= 1 }) {
            return "Based on your preferred listening time"
        } else if !userBehavior.strugglingAreas.isEmpty {
            return "Supporting your current spiritual focus"
        } else if userBehavior.streakLength > 7 {
            return "Maintaining your \(userBehavior.streakLength)-day streak"
        } else {
            return "Optimal timing for spiritual encouragement"
        }
    }
    
    // MARK: - Optimal Timing Calculation
    
    private func getOptimalNotificationTimes(
        count: Int,
        timeRange: ClosedRange<Int>,
        userBehavior: UserBehaviorFeatures
    ) async -> [Date] {
        var optimalTimes: [Date] = []
        let calendar = Calendar.current
        
        // Start with user's preferred times
        let userPreferredTimes = userBehavior.preferredListeningTimes
            .filter { timeRange.contains($0) }
            .sorted()
        
        for hour in userPreferredTimes.prefix(count) {
            if let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) {
                optimalTimes.append(date)
            }
        }
        
        // Fill remaining slots with strategic times
        let remainingCount = count - optimalTimes.count
        if remainingCount > 0 {
            let strategicTimes = await getStrategicTimes(
                count: remainingCount,
                timeRange: timeRange,
                avoiding: userPreferredTimes,
                userBehavior: userBehavior
            )
            
            optimalTimes.append(contentsOf: strategicTimes)
        }
        
        return optimalTimes.sorted()
    }
    
    private func getStrategicTimes(
        count: Int,
        timeRange: ClosedRange<Int>,
        avoiding: [Int],
        userBehavior: UserBehaviorFeatures
    ) async -> [Date] {
        var strategicTimes: [Date] = []
        let calendar = Calendar.current
        
        // Strategic times based on spiritual research and user patterns
        let potentialTimes: [Int] = [7, 12, 18, 21] // Morning, noon, evening, night
            .filter { timeRange.contains($0) && !avoiding.contains($0) }
        
        // Prioritize based on user's spiritual maturity
        var prioritizedTimes = potentialTimes
        switch userBehavior.spiritualMaturityLevel {
        case .newBeliever:
            prioritizedTimes = [7, 21, 12, 18] // Morning and evening for foundation
        case .growing:
            prioritizedTimes = [7, 12, 18, 21] // Regular intervals for growth
        case .mature:
            prioritizedTimes = [7, 18, 21, 12] // Morning and evening focus
        case .leadership:
            prioritizedTimes = [6, 12, 21, 18] // Early morning for leaders
        }
        
        for hour in prioritizedTimes.prefix(count) {
            if let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) {
                strategicTimes.append(date)
            }
        }
        
        return strategicTimes
    }
    
    // MARK: - Content Selection
    
    private func getContextualDeclaration(
        hour: Int,
        userBehavior: UserBehaviorFeatures,
        type: AINotification.NotificationType
    ) async -> String {
        // This would query your declaration database for the most appropriate content
        // For now, return contextual placeholders
        
        switch type {
        case .morning:
            if !userBehavior.strugglingAreas.isEmpty {
                return "morning_breakthrough_\(userBehavior.strugglingAreas.first!)"
            } else {
                return "morning_strength_general"
            }
            
        case .midday:
            if !userBehavior.growthAreas.isEmpty {
                return "midday_growth_\(userBehavior.growthAreas.first!)"
            } else {
                return "midday_encouragement_general"
            }
            
        case .evening:
            return "evening_peace_\(userBehavior.spiritualMaturityLevel.rawValue)"
            
        case .crisis:
            return "crisis_support_immediate"
            
        case .celebration:
            return "celebration_gratitude_praise"
            
        case .reminder:
            return "gentle_reminder_love"
        }
    }
    
    // MARK: - Notification Scheduling
    
    func scheduleAINotification(_ aiNotification: AINotification) async {
        let content = UNMutableNotificationContent()
        content.title = aiNotification.personalizedTitle
        content.body = aiNotification.personalizedMessage
        content.sound = .default

        // Add AI-specific metadata
        content.userInfo = [
            "declarationId": aiNotification.declarationId,
            "category": aiNotification.declarationCategory,
            "aiGenerated": true,
            "reason": aiNotification.reason,
            "spiritualContext": aiNotification.spiritualContext,
            "confidence": aiNotification.confidence,
            "notificationType": aiNotification.notificationType.rawValue
        ]

        let calendar = Calendar.current
        let trigger: UNCalendarNotificationTrigger
        let identifier: String

        switch aiNotification.notificationType {
        case .morning, .midday, .evening:
            // Daily-slot notifications recur at a fixed time of day.
            let components = calendar.dateComponents([.hour, .minute], from: aiNotification.optimalTime)
            trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            identifier = "ai_notification_\(aiNotification.declarationId)_\(components.hour ?? 0)"

        case .crisis, .celebration, .reminder:
            // One-shot notifications anchored to a specific moment (e.g. crisis
            // support, a celebration, or the re-engagement "We've Missed You"
            // push). These must NEVER repeat — a previous build scheduled them
            // with repeats:true on hour/minute only, which turned a one-time
            // "1 hour from now" re-engagement push into a permanent daily alarm
            // that fired in the middle of the night. Fire once at the exact
            // optimalTime, and skip entirely if that moment has already passed.
            guard aiNotification.optimalTime > Date() else { return }
            let components = calendar.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: aiNotification.optimalTime
            )
            trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            identifier = "ai_notification_\(aiNotification.declarationId)"
        }

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        do {
            try await notificationCenter.add(request)
        } catch {
            print("❌ Failed to schedule notification: \(error)")
        }
    }

    /// Removes legacy AI notifications that an earlier build scheduled as
    /// *repeating* daily alarms when they were meant to fire once — most
    /// visibly the re-engagement "We've Missed You" push, which a near-midnight
    /// schedule pinned to ~1 AM every night. Matches by the stable declarationId
    /// prefixes used for one-shot notifications and removes any that repeat.
    /// Safe and cheap to call on every launch.
    func cleanupLegacyRepeatingOneShots() {
        let oneShotPrefixes = [
            "ai_notification_re_engagement_gentle",
            "ai_notification_crisis_support_immediate",
            "ai_notification_celebration_achievement"
        ]
        notificationCenter.getPendingNotificationRequests { requests in
            let staleIds = requests.compactMap { request -> String? in
                guard oneShotPrefixes.contains(where: { request.identifier.hasPrefix($0) }),
                      (request.trigger as? UNCalendarNotificationTrigger)?.repeats == true else {
                    return nil
                }
                return request.identifier
            }
            guard !staleIds.isEmpty else { return }
            self.notificationCenter.removePendingNotificationRequests(withIdentifiers: staleIds)
            print("🩹 Removed \(staleIds.count) legacy repeating AI re-engagement notification(s)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func calculateNotificationConfidence(hour: Int, userBehavior: UserBehaviorFeatures) -> Double {
        if userBehavior.preferredListeningTimes.contains(where: { abs($0 - hour) <= 1 }) {
            return 0.9 // High confidence for user's preferred times
        } else if [7, 12, 18, 21].contains(hour) {
            return 0.7 // Good confidence for strategic times
        } else {
            return 0.5 // Medium confidence for other times
        }
    }
    
    private func requestNotificationPermission() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            print("❌ Failed to request notification permission: \(error)")
            return false
        }
    }
    
    // MARK: - Crisis & Celebration Detection
    
    func scheduleImmediateSupport(for situation: String) async {
        let supportNotification = AINotification(
            declarationId: "crisis_support_immediate",
            declarationCategory: "hardtimes",
            personalizedTitle: "Strength for Right Now",
            personalizedMessage: "God's power is with you in this moment",
            optimalTime: Date().addingTimeInterval(60), // 1 minute from now
            reason: "Immediate spiritual support needed",
            spiritualContext: situation,
            confidence: 1.0,
            notificationType: .crisis
        )
        
        await scheduleAINotification(supportNotification)
        
        // Track crisis support
        EnhancedAnalyticsService.shared.trackSpiritualJourney(
            currentMood: "crisis",
            prayerRequests: [situation],
            journalSentiment: -0.8,
            recommendationAccepted: true
        )
    }
    
    func scheduleCelebration(for achievement: String) async {
        let celebrationNotification = AINotification(
            declarationId: "celebration_achievement",
            declarationCategory: "gratitude",
            personalizedTitle: "Celebrating Your Victory! 🎉",
            personalizedMessage: "God is rejoicing with you over this breakthrough",
            optimalTime: Date().addingTimeInterval(300), // 5 minutes from now
            reason: "Celebrating spiritual achievement",
            spiritualContext: achievement,
            confidence: 1.0,
            notificationType: .celebration
        )
        
        await scheduleAINotification(celebrationNotification)
        
        // Track celebration
        EnhancedAnalyticsService.shared.trackSpiritualJourney(
            currentMood: "celebration",
            prayerRequests: [],
            journalSentiment: 0.9,
            recommendationAccepted: true
        )
    }
}

