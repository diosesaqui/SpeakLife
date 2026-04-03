//
//  BootcampModels.swift
//  SpeakLife
//
//  Spiritual Warrior Bootcamp Data Models
//

import Foundation
import SwiftUI

// MARK: - Core Models

struct BootcampProgram: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let duration: ProgramDuration
    let price: Price
    let modules: [BootcampModule]
    let bonusContent: [BonusContent]
    let communityFeatures: CommunityFeatures
    let startDate: Date?
    let enrollmentDeadline: Date?
    let maxParticipants: Int?
    
    var isActive: Bool {
        guard let deadline = enrollmentDeadline else { return true }
        return Date() < deadline
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(title)
        hasher.combine(subtitle)
        hasher.combine(duration)
        hasher.combine(price)
        hasher.combine(modules)
        hasher.combine(bonusContent)
        hasher.combine(communityFeatures)
        hasher.combine(startDate)
        hasher.combine(enrollmentDeadline)
        hasher.combine(maxParticipants)
    }
    
    static func == (lhs: BootcampProgram, rhs: BootcampProgram) -> Bool {
        return lhs.id == rhs.id &&
               lhs.title == rhs.title &&
               lhs.subtitle == rhs.subtitle &&
               lhs.duration == rhs.duration &&
               lhs.price == rhs.price &&
               lhs.modules == rhs.modules &&
               lhs.bonusContent == rhs.bonusContent &&
               lhs.communityFeatures == rhs.communityFeatures &&
               lhs.startDate == rhs.startDate &&
               lhs.enrollmentDeadline == rhs.enrollmentDeadline &&
               lhs.maxParticipants == rhs.maxParticipants
    }
}

enum ProgramDuration: String, Codable, CaseIterable {
    case eightWeeks = "8_weeks"
    case twelveWeeks = "12_weeks"
    
    var displayName: String {
        switch self {
        case .eightWeeks: return "8-Week Intensive"
        case .twelveWeeks: return "12-Week Transformation"
        }
    }
    
    var weeks: Int {
        switch self {
        case .eightWeeks: return 8
        case .twelveWeeks: return 12
        }
    }
}

struct Price: Codable, Hashable, Equatable {
    let amount: Double
    let currency: String
    let originalAmount: Double? // For showing discounts
    let paymentPlans: [PaymentPlan]
    
    var displayPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
}

struct PaymentPlan: Codable, Identifiable, Hashable, Equatable {
    let id: String
    let name: String
    let installments: Int
    let amountPerInstallment: Double
    let frequency: PaymentFrequency
}

enum PaymentFrequency: String, Codable {
    case weekly, biweekly, monthly
}

// MARK: - Module Structure

struct BootcampModule: Codable, Identifiable, Hashable, Equatable {
    let id: String
    let weekNumber: Int
    let phase: BootcampPhase
    let title: String
    let scripture: String
    let description: String
    let lessons: [Lesson]
    let weeklyChallenge: WeeklyChallenge
    let liveSession: LiveSession?
    
    var isUnlocked: Bool {
        // Logic to determine if module is available based on date/progress
        return true
    }
    
    var completionPercentage: Double {
        let completedLessons = lessons.filter { $0.isCompleted }.count
        return Double(completedLessons) / Double(lessons.count)
    }
}

enum BootcampPhase: String, Codable, CaseIterable {
    case foundation = "foundation"
    case warfare = "warfare"
    case advanced = "advanced"
    case leadership = "leadership"
    
    var displayName: String {
        switch self {
        case .foundation: return "Foundation: Armor of God"
        case .warfare: return "Warfare Training: Battle Ready"
        case .advanced: return "Advanced: Walking in Victory"
        case .leadership: return "Leadership: Kingdom Impact"
        }
    }
    
    var color: Color {
        switch self {
        case .foundation: return .blue
        case .warfare: return .red
        case .advanced: return .purple
        case .leadership: return .orange
        }
    }
    
    var icon: String {
        switch self {
        case .foundation: return "shield.fill"
        case .warfare: return "flame.fill"
        case .advanced: return "star.fill"
        case .leadership: return "crown.fill"
        }
    }
}

// MARK: - Lesson Content

struct Lesson: Codable, Identifiable, Hashable, Equatable {
    let id: String
    let dayNumber: Int
    let title: String
    let type: LessonType
    let duration: Int // in minutes
    let content: LessonContent
    let resources: [Resource]
    let reflection: ReflectionPrompt?
    var isCompleted: Bool = false
    var completedAt: Date?
    var notes: String?
}

enum LessonType: String, Codable {
    case video = "video"
    case audio = "audio"
    case reading = "reading"
    case interactive = "interactive"
    case prayer = "prayer"
    case meditation = "meditation"
    
    var icon: String {
        switch self {
        case .video: return "play.rectangle.fill"
        case .audio: return "headphones"
        case .reading: return "book.fill"
        case .interactive: return "hand.tap.fill"
        case .prayer: return "hands.sparkles.fill"
        case .meditation: return "brain.head.profile"
        }
    }
}

struct LessonContent: Codable, Hashable, Equatable {
    let mainContent: String // URL or text content
    let scriptureReferences: [ScriptureReference]
    let keyPoints: [String]
    let prayerFocus: String?
    let actionSteps: [ActionStep]
}

struct ScriptureReference: Codable, Identifiable, Hashable, Equatable {
    let id: String
    let book: String
    let chapter: Int
    let verses: String
    let text: String
    let translation: String
}

struct ActionStep: Codable, Identifiable, Hashable, Equatable {
    let id: String
    let description: String
    var isCompleted: Bool = false
    let points: Int // Gamification points
}

struct ReflectionPrompt: Codable, Hashable, Equatable {
    let question: String
    let guidedPrompts: [String]
    var userResponse: String?
    var submittedAt: Date?
}

// MARK: - Challenges & Engagement

struct WeeklyChallenge: Codable, Identifiable, Hashable, Equatable {
    let id: String
    let title: String
    let description: String
    let objectives: [ChallengeObjective]
    let reward: ChallengeReward
    let deadline: Date
    var isCompleted: Bool = false
    var completedAt: Date?
}

struct ChallengeObjective: Codable, Identifiable, Hashable, Equatable {
    let id: String
    let description: String
    let targetCount: Int?
    var currentCount: Int = 0
    
    var isCompleted: Bool {
        guard let target = targetCount else { return currentCount > 0 }
        return currentCount >= target
    }
}

struct ChallengeReward: Codable, Hashable, Equatable {
    let type: RewardType
    let value: String
    let description: String
}

enum RewardType: String, Codable {
    case badge = "badge"
    case content = "bonus_content"
    case certificate = "certificate"
    case points = "points"
}

// MARK: - Live Sessions

struct LiveSession: Codable, Identifiable, Hashable, Equatable {
    let id: String
    let title: String
    let scheduledDate: Date
    let duration: Int // minutes
    let zoomLink: String?
    let recordingAvailable: Bool
    let recordingUrl: String?
    let materials: [SessionMaterial]
}

struct SessionMaterial: Codable, Identifiable, Hashable, Equatable {
    let id: String
    let title: String
    let type: MaterialType
    let url: String
}

enum MaterialType: String, Codable {
    case slides = "slides"
    case workbook = "workbook"
    case notes = "notes"
}

// MARK: - Community Features

struct CommunityFeatures: Codable, Hashable, Equatable {
    let hasDiscussionForum: Bool
    let hasAccountabilityGroups: Bool
    let hasMentorship: Bool
    let hasLiveQA: Bool
    let groupSize: Int?
}

// MARK: - Bonus Content

struct BonusContent: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let description: String
    let type: BonusType
    let unlockCondition: UnlockCondition
    var isUnlocked: Bool = false
}

enum BonusType: String, Codable {
    case ebook = "ebook"
    case masterclass = "masterclass"
    case oneOnOne = "one_on_one"
    case certificate = "certificate"
}

enum UnlockCondition: Codable, Hashable, Equatable {
    case immediate
    case weekCompleted(Int)
    case programCompleted
    case challengeCompleted(String)
}

// MARK: - Progress Tracking

struct BootcampProgress: Codable {
    let userId: String
    let programId: String
    let enrollmentDate: Date
    var currentWeek: Int
    var completedLessons: Set<String>
    var completedChallenges: Set<String>
    var totalPoints: Int
    var streakDays: Int
    var lastActivityDate: Date
    var certificates: [Certificate]
    
    var overallProgress: Double {
        // Calculate based on completed lessons and challenges
        return 0.0
    }
}

struct Certificate: Codable, Identifiable, Hashable, Equatable {
    let id: String
    let type: CertificateType
    let earnedDate: Date
    let validationCode: String
}

enum CertificateType: String, Codable {
    case completion = "completion"
    case excellence = "excellence"
    case leadership = "leadership"
}

// MARK: - Resources

struct Resource: Codable, Identifiable, Hashable, Equatable {
    let id: String
    let title: String
    let type: ResourceType
    let url: String?
    let content: String?
}

enum ResourceType: String, Codable {
    case pdf = "pdf"
    case video = "video"
    case audio = "audio"
    case article = "article"
    case worksheet = "worksheet"
}
