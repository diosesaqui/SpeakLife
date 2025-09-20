//
//  BootcampViewModel.swift
//  SpeakLife
//
//  ViewModel for Spiritual Warrior Bootcamp following SOLID principles
//

import SwiftUI
import Combine
import StoreKit

// MARK: - Protocol Definitions (Dependency Inversion)

protocol BootcampServiceProtocol {
    func fetchProgram() async throws -> BootcampProgram
    func enrollInProgram(_ programId: String) async throws -> EnrollmentResult
    func updateProgress(_ progress: BootcampProgress) async throws
    func fetchUserProgress() async throws -> BootcampProgress
}

protocol PaymentServiceProtocol {
    func purchaseBootcamp(_ product: Product) async throws -> Transaction
    func restorePurchases() async throws -> [Transaction]
    func verifyAccess() async -> Bool
}

protocol ContentDeliveryProtocol {
    func loadLesson(_ lessonId: String) async throws -> LessonContent
    func markLessonComplete(_ lessonId: String) async throws
    func submitReflection(_ lessonId: String, response: String) async throws
}

// MARK: - Main ViewModel

@MainActor
final class BootcampViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var currentProgram: BootcampProgram?
    @Published var userProgress: BootcampProgress?
    @Published var currentModule: BootcampModule?
    @Published var currentLesson: Lesson?
    @Published var isLoading = false
    @Published var hasAccess = false
    @Published var showPurchaseModal = false
    @Published var enrollmentState: EnrollmentState = .notEnrolled
    
    // MARK: - View States
    @Published var selectedTab: BootcampTab = .overview
    @Published var navigationPath = NavigationPath()
    @Published var error: BootcampError?
    
    // MARK: - Services (Dependency Injection)
    private let bootcampService: BootcampServiceProtocol
    private let paymentService: PaymentServiceProtocol
    private let contentService: ContentDeliveryProtocol
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(
        bootcampService: BootcampServiceProtocol = BootcampService(),
        paymentService: PaymentServiceProtocol = PaymentService(),
        contentService: ContentDeliveryProtocol = ContentDeliveryService()
    ) {
        self.bootcampService = bootcampService
        self.paymentService = paymentService
        self.contentService = contentService
        
        Task {
            await loadBootcampData()
        }
    }
    
    // MARK: - Public Methods
    
    func loadBootcampData() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Check access first
            hasAccess = await paymentService.verifyAccess()
            
            // Load program data
            currentProgram = try await bootcampService.fetchProgram()
            
            if hasAccess {
                userProgress = try await bootcampService.fetchUserProgress()
                updateEnrollmentState()
                
                // Set current module based on progress
                if let progress = userProgress,
                   let program = currentProgram {
                    currentModule = program.modules.first { $0.weekNumber == progress.currentWeek }
                }
            }
        } catch {
            self.error = BootcampError.loadingFailed(error.localizedDescription)
        }
    }
    
    func purchaseBootcamp() async {
        guard let program = currentProgram else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Handle in-app purchase
            // This would integrate with StoreKit 2
            enrollmentState = .enrolled
            hasAccess = true
            
            // Create initial progress
            let initialProgress = BootcampProgress(
                userId: getUserId(),
                programId: program.id,
                enrollmentDate: Date(),
                currentWeek: 1,
                completedLessons: [],
                completedChallenges: [],
                totalPoints: 0,
                streakDays: 0,
                lastActivityDate: Date(),
                certificates: []
            )
            
            try await bootcampService.updateProgress(initialProgress)
            userProgress = initialProgress
            
            // Navigate to welcome/onboarding
            selectedTab = .curriculum
        } catch {
            self.error = BootcampError.purchaseFailed(error.localizedDescription)
        }
    }
    
    func startLesson(_ lesson: Lesson) async {
        currentLesson = lesson
        
        do {
            let content = try await contentService.loadLesson(lesson.id)
            // Navigate to lesson view
            navigationPath.append(BootcampDestination.lesson(lesson))
        } catch {
            self.error = BootcampError.contentLoadFailed(error.localizedDescription)
        }
    }
    
    func completeLesson(_ lessonId: String) async {
        do {
            try await contentService.markLessonComplete(lessonId)
            
            // Update local progress
            userProgress?.completedLessons.insert(lessonId)
            
            // Update points and streaks
            if let lesson = currentLesson {
                userProgress?.totalPoints += calculatePoints(for: lesson)
                updateStreak()
            }
            
            // Save progress
            if let progress = userProgress {
                try await bootcampService.updateProgress(progress)
            }
            
            // Check for unlocks
            await checkForUnlocks()
            
        } catch {
            self.error = BootcampError.progressUpdateFailed(error.localizedDescription)
        }
    }
    
    func submitReflection(_ response: String) async {
        guard let lesson = currentLesson else { return }
        
        do {
            try await contentService.submitReflection(lesson.id, response: response)
            
            // Award bonus points for reflection
            userProgress?.totalPoints += 50
            
            if let progress = userProgress {
                try await bootcampService.updateProgress(progress)
            }
        } catch {
            self.error = BootcampError.submissionFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Private Methods
    
    private func updateEnrollmentState() {
        if hasAccess {
            if let progress = userProgress {
                if progress.overallProgress >= 1.0 {
                    enrollmentState = .completed
                } else {
                    enrollmentState = .enrolled
                }
            }
        } else {
            enrollmentState = .notEnrolled
        }
    }
    
    private func calculatePoints(for lesson: Lesson) -> Int {
        var points = 100 // Base points
        
        // Bonus for lesson type
        switch lesson.type {
        case .interactive, .meditation:
            points += 50
        default:
            break
        }
        
        // Streak bonus
        if let streak = userProgress?.streakDays, streak > 0 {
            points += min(streak * 10, 100) // Max 100 bonus points
        }
        
        return points
    }
    
    private func updateStreak() {
        guard let lastActivity = userProgress?.lastActivityDate else {
            userProgress?.streakDays = 1
            return
        }
        
        let calendar = Calendar.current
        let daysSince = calendar.dateComponents([.day], from: lastActivity, to: Date()).day ?? 0
        
        if daysSince == 1 {
            userProgress?.streakDays += 1
        } else if daysSince > 1 {
            userProgress?.streakDays = 1
        }
        
        userProgress?.lastActivityDate = Date()
    }
    
    private func checkForUnlocks() async {
        // Check for new module unlocks, bonus content, certificates
        guard let progress = userProgress,
              let program = currentProgram else { return }
        
        // Check weekly challenge completion
        if let currentModule = currentModule {
            let allLessonsComplete = currentModule.lessons.allSatisfy { lesson in
                progress.completedLessons.contains(lesson.id)
            }
            
            if allLessonsComplete && !progress.completedChallenges.contains(currentModule.weeklyChallenge.id) {
                // Unlock weekly challenge reward
                await unlockChallengeReward(currentModule.weeklyChallenge)
            }
        }
    }
    
    private func unlockChallengeReward(_ challenge: WeeklyChallenge) async {
        // Handle reward unlocking
        userProgress?.completedChallenges.insert(challenge.id)
        
        switch challenge.reward.type {
        case .badge:
            // Award badge
            break
        case .content:
            // Unlock bonus content
            break
        case .certificate:
            // Generate certificate
            break
        case .points:
            if let points = Int(challenge.reward.value) {
                userProgress?.totalPoints += points
            }
        }
    }
    
    private func getUserId() -> String {
        // Get from authentication service
        return "user_id"
    }
}

// MARK: - Supporting Types

enum EnrollmentState {
    case notEnrolled
    case enrolled
    case completed
}

enum BootcampTab: String, CaseIterable {
    case overview = "Overview"
    case curriculum = "Curriculum"
    case community = "Community"
    case progress = "Progress"
    case resources = "Resources"
    
    var icon: String {
        switch self {
        case .overview: return "sparkles"
        case .curriculum: return "book.closed.fill"
        case .community: return "person.3.fill"
        case .progress: return "chart.line.uptrend.xyaxis"
        case .resources: return "folder.fill"
        }
    }
}

enum BootcampDestination: Hashable {
    case lesson(Lesson)
    case module(BootcampModule)
    case liveSession(LiveSession)
    case challenge(WeeklyChallenge)
    case resource(Resource)
}

enum BootcampError: LocalizedError, Identifiable {
    case loadingFailed(String)
    case purchaseFailed(String)
    case contentLoadFailed(String)
    case progressUpdateFailed(String)
    case submissionFailed(String)
    
    var id: String {
        switch self {
        case .loadingFailed(let message):
            return "loading_\(message)"
        case .purchaseFailed(let message):
            return "purchase_\(message)"
        case .contentLoadFailed(let message):
            return "content_\(message)"
        case .progressUpdateFailed(let message):
            return "progress_\(message)"
        case .submissionFailed(let message):
            return "submission_\(message)"
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .loadingFailed(let message):
            return "Failed to load bootcamp: \(message)"
        case .purchaseFailed(let message):
            return "Purchase failed: \(message)"
        case .contentLoadFailed(let message):
            return "Failed to load content: \(message)"
        case .progressUpdateFailed(let message):
            return "Failed to update progress: \(message)"
        case .submissionFailed(let message):
            return "Failed to submit: \(message)"
        }
    }
}

// MARK: - Service Implementations

struct EnrollmentResult: Codable {
    let success: Bool
    let programId: String
    let accessExpiry: Date?
}

// Placeholder service implementations
class BootcampService: BootcampServiceProtocol {
    func fetchProgram() async throws -> BootcampProgram {
        // Implement Firebase/API call
        fatalError("Implement fetchProgram")
    }
    
    func enrollInProgram(_ programId: String) async throws -> EnrollmentResult {
        // Implement enrollment logic
        fatalError("Implement enrollInProgram")
    }
    
    func updateProgress(_ progress: BootcampProgress) async throws {
        // Save to Firebase/backend
        fatalError("Implement updateProgress")
    }
    
    func fetchUserProgress() async throws -> BootcampProgress {
        // Fetch from Firebase/backend
        fatalError("Implement fetchUserProgress")
    }
}

class PaymentService: PaymentServiceProtocol {
    func purchaseBootcamp(_ product: Product) async throws -> Transaction {
        // StoreKit 2 implementation
        fatalError("Implement purchaseBootcamp")
    }
    
    func restorePurchases() async throws -> [Transaction] {
        // StoreKit 2 restore
        fatalError("Implement restorePurchases")
    }
    
    func verifyAccess() async -> Bool {
        // Verify purchase/subscription
        return false
    }
}

class ContentDeliveryService: ContentDeliveryProtocol {
    func loadLesson(_ lessonId: String) async throws -> LessonContent {
        // Load from Firebase/CDN
        fatalError("Implement loadLesson")
    }
    
    func markLessonComplete(_ lessonId: String) async throws {
        // Update backend
        fatalError("Implement markLessonComplete")
    }
    
    func submitReflection(_ lessonId: String, response: String) async throws {
        // Save reflection
        fatalError("Implement submitReflection")
    }
}