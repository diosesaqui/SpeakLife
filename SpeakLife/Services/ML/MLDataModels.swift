//
//  MLDataModels.swift
//  SpeakLife
//
//  ML-specific data models for training and inference
//

import Foundation
import CoreML
//import CreateML

// MARK: - Spiritual Content Categories for AI
enum SpiritualContentCategory: String, CaseIterable, Codable {
    case faith = "faith"
    case healing = "healing"
    case prosperity = "prosperity"
    case protection = "protection"
    case relationships = "relationships"
    case purpose = "purpose"
    case peace = "peace"
    case strength = "strength"
    case wisdom = "wisdom"
    case gratitude = "gratitude"
    case deliverance = "deliverance"
    case breakthrough = "breakthrough"
    case identity = "identity"
    case worship = "worship"
    case warfare = "warfare"
    
    var displayName: String {
        switch self {
        case .faith: return "Faith & Trust"
        case .healing: return "Healing & Restoration"
        case .prosperity: return "Provision & Prosperity"
        case .protection: return "God's Protection"
        case .relationships: return "Relationships & Love"
        case .purpose: return "Purpose & Calling"
        case .peace: return "Peace & Rest"
        case .strength: return "Strength & Power"
        case .wisdom: return "Wisdom & Understanding"
        case .gratitude: return "Gratitude & Praise"
        case .deliverance: return "Freedom & Deliverance"
        case .breakthrough: return "Breakthrough & Victory"
        case .identity: return "Identity in Christ"
        case .worship: return "Worship & Adoration"
        case .warfare: return "Spiritual Warfare"
        }
    }
}

enum EmotionalTone: String, CaseIterable, Codable {
    case encouraging = "encouraging"
    case powerful = "powerful"
    case gentle = "gentle"
    case urgent = "urgent"
    case peaceful = "peaceful"
    case bold = "bold"
    case comforting = "comforting"
    
    var description: String {
        switch self {
        case .encouraging: return "Uplifting and motivational"
        case .powerful: return "Strong and authoritative"
        case .gentle: return "Soft and nurturing"
        case .urgent: return "Immediate and pressing"
        case .peaceful: return "Calm and soothing"
        case .bold: return "Confident and fearless"
        case .comforting: return "Consoling and supportive"
        }
    }
}

enum SpiritualMaturity: String, CaseIterable, Codable {
    case newBeliever = "new_believer"
    case growing = "growing"
    case mature = "mature"
    case leadership = "leadership"
    
    var displayName: String {
        switch self {
        case .newBeliever: return "New in Faith"
        case .growing: return "Growing Believer"
        case .mature: return "Mature in Faith"
        case .leadership: return "Spiritual Leader"
        }
    }
}

// MARK: - User Behavior Models
struct UserBehaviorFeatures: Codable {
    // Temporal patterns
    var preferredListeningTimes: [Int] // Hours of day (0-23)
    var sessionDuration: TimeInterval
    var dailyUsageFrequency: Int
    var weeklyPattern: [Int] // Day of week usage
    
    // Content preferences
    var topCategories: [String: Double] // Category engagement scores
    var audioToTextRatio: Double
    var favoriteDeclarationIds: [String]
    var completionRates: [String: Double] // Category -> completion rate
    
    // Spiritual journey indicators
    var journalEntryFrequency: Int
    var prayerRequestTopics: [String]
    var shareFrequency: Double
    var streakLength: Int
    var spiritualMaturityLevel: SpiritualMaturity
    
    // Engagement patterns
    var audioCompletionRate: Double
    var skipPatterns: [String: Double] // Content type -> skip rate
    var searchQueries: [String]
    var timeSpentPerCategory: [String: TimeInterval]
    var relistenFrequency: Double
    
    // Contextual data
    var currentLifeSeason: String // "healing", "breakthrough", "growth"
    var strugglingAreas: [String]
    var growthAreas: [String]
    var lastActiveDate: Date
    
    init() {
        self.preferredListeningTimes = []
        self.sessionDuration = 0
        self.dailyUsageFrequency = 0
        self.weeklyPattern = Array(repeating: 0, count: 7)
        self.topCategories = [:]
        self.audioToTextRatio = 0.5
        self.favoriteDeclarationIds = []
        self.completionRates = [:]
        self.journalEntryFrequency = 0
        self.prayerRequestTopics = []
        self.shareFrequency = 0
        self.streakLength = 0
        self.spiritualMaturityLevel = .newBeliever
        self.audioCompletionRate = 0
        self.skipPatterns = [:]
        self.searchQueries = []
        self.timeSpentPerCategory = [:]
        self.relistenFrequency = 0
        self.currentLifeSeason = "growth"
        self.strugglingAreas = []
        self.growthAreas = []
        self.lastActiveDate = Date()
    }
}

// MARK: - ML Training Data Models
struct DeclarationTrainingExample: Codable {
    let id: String
    let text: String
    let originalCategory: String
    let spiritualCategories: [SpiritualContentCategory]
    let emotionalTone: EmotionalTone
    let maturityLevel: SpiritualMaturity
    let engagementScore: Double
    let userInteractions: UserInteractionData
    
    struct UserInteractionData: Codable {
        let playCount: Int
        let favoriteCount: Int
        let shareCount: Int
        let completionRate: Double
        let averageListenDuration: TimeInterval
        let skipRate: Double
    }
}

struct JournalTrainingExample: Codable {
    let id: String
    let anonymizedText: String // Sanitized for privacy
    let detectedEmotions: [String]
    let spiritualThemes: [SpiritualContentCategory]
    let suggestedCategories: [String]
    let userSelectedDeclarations: [String] // What they actually chose
    let contextualFactors: [String] // Time of day, season, etc.
}

// MARK: - Recommendation Models
struct ContentRecommendation: Identifiable, Codable {
    let id = UUID()
    let declarationId: String
    let recommendationScore: Double
    let recommendationReason: String
    let personalizedTitle: String?
    let personalizedMessage: String?
    let confidence: Double
    let aiCategories: [SpiritualContentCategory]
    let emotionalTone: EmotionalTone
    let suggestedTiming: RecommendationTiming
    let connectionToJourney: String
}

struct RecommendationTiming: Codable {
    let optimalHour: Int
    let suggestedDuration: TimeInterval
    let contextualSuggestion: String // "before sleep", "morning strength", etc.
}

// MARK: - Personalized Category Models
struct PersonalizedCategory: Identifiable, Codable {
    let id = UUID()
    let name: String
    let description: String
    let contentIds: [String]
    let userReasonExplanation: String
    let confidence: Double
    let createdDate: Date
    let isActive: Bool
    let spiritualFocus: [SpiritualContentCategory]
    
    init(name: String, description: String, contentIds: [String], userReasonExplanation: String, confidence: Double, spiritualFocus: [SpiritualContentCategory]) {
        self.name = name
        self.description = description
        self.contentIds = contentIds
        self.userReasonExplanation = userReasonExplanation
        self.confidence = confidence
        self.createdDate = Date()
        self.isActive = true
        self.spiritualFocus = spiritualFocus
    }
}

// MARK: - AI Task Models
struct SpiritualTask: Identifiable, Codable {
    let id = UUID()
    let title: String
    let description: String
    let aiGeneratedReason: String
    let estimatedMinutes: Int
    let priority: TaskPriority
    let spiritualFocus: SpiritualContentCategory
    let relatedDeclarationIds: [String]
    let completionDate: Date?
    let isCompleted: Bool
    let createdByAI: Bool
    
    enum TaskPriority: String, CaseIterable, Codable {
        case low = "low"
        case medium = "medium"
        case high = "high"
        case urgent = "urgent"
    }
    
    init(title: String, description: String, aiGeneratedReason: String, estimatedMinutes: Int, priority: TaskPriority, spiritualFocus: SpiritualContentCategory, relatedDeclarationIds: [String]) {
        self.title = title
        self.description = description
        self.aiGeneratedReason = aiGeneratedReason
        self.estimatedMinutes = estimatedMinutes
        self.priority = priority
        self.spiritualFocus = spiritualFocus
        self.relatedDeclarationIds = relatedDeclarationIds
        self.completionDate = nil
        self.isCompleted = false
        self.createdByAI = true
    }
}

// MARK: - ML Training Events
struct MLTrainingEvent: Codable {
    let userId: String
    let contentId: String
    let action: MLUserAction
    let spiritualContext: SpiritualContext
    let timestamp: Date
    let sessionId: String
    let deviceContext: DeviceContext
    
    struct SpiritualContext: Codable {
        let currentStreak: Int
        let timeOfDay: Int
        let dayOfWeek: Int
        let recentJournalSentiment: Double? // -1 to 1
        let currentLifeSeason: String
        let activeStruggles: [String]
    }
    
    struct DeviceContext: Codable {
        let platform: String
        let appVersion: String
        let isBackground: Bool
    }
}

enum MLUserAction: String, CaseIterable, Codable {
    case viewed = "viewed"
    case played = "played"
    case completed = "completed"
    case favorited = "favorited"
    case shared = "shared"
    case skipped = "skipped"
    case replayed = "replayed"
    case searchedFor = "searched_for"
    case journalConnected = "journal_connected"
}

// MARK: - Personal Insight Models
struct PersonalInsight: Codable {
    let contextualMessage: String
    let applicationSuggestion: String?
    let connectionToJourney: String
    let supportingScripture: String?
    let confidence: Double
    let generatedDate: Date
    
    init(contextualMessage: String, applicationSuggestion: String?, connectionToJourney: String, supportingScripture: String?, confidence: Double) {
        self.contextualMessage = contextualMessage
        self.applicationSuggestion = applicationSuggestion
        self.connectionToJourney = connectionToJourney
        self.supportingScripture = supportingScripture
        self.confidence = confidence
        self.generatedDate = Date()
    }
}

// MARK: - Notification Models
struct AINotification: Codable {
    let declarationId: String
    let declarationCategory: String
    let personalizedTitle: String
    let personalizedMessage: String
    let optimalTime: Date
    let reason: String
    let spiritualContext: String
    let confidence: Double
    let notificationType: NotificationType
    
    enum NotificationType: String, CaseIterable, Codable {
        case morning = "morning"
        case midday = "midday"
        case evening = "evening"
        case crisis = "crisis"
        case celebration = "celebration"
        case reminder = "reminder"
    }
}
