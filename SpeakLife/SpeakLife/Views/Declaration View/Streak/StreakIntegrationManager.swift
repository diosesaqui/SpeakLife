//
//  StreakIntegrationManager.swift
//  SpeakLife
//
//  Manager to integrate streak tracking with app actions
//

import Foundation
import Combine

final class StreakIntegrationManager: ObservableObject {
    static let shared = StreakIntegrationManager()
    
    private var streakViewModel: EnhancedStreakViewModel?
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupNotificationObservers()
    }
    
    func setStreakViewModel(_ viewModel: EnhancedStreakViewModel) {
        self.streakViewModel = viewModel
    }
    
    // MARK: - Action Tracking Methods
    
    /// Call when user speaks/declares an affirmation
    func trackAffirmationSpoken() {
        streakViewModel?.completeTask(taskId: "speak_affirmation")
        logAction("Affirmation spoken", taskId: "speak_affirmation")
    }

    /// Call when user shares an affirmation
    func trackAffirmationShared() {
        streakViewModel?.completeTask(taskId: "share_affirmation")
        logAction("Affirmation shared", taskId: "share_affirmation")
    }

    /// Call when user reads a devotional
    func trackDevotionalRead() {
        streakViewModel?.completeTask(taskId: "read_devotional")
        logAction("Devotional read", taskId: "read_devotional")
    }

    /// Call when user listens to audio affirmation
    func trackAudioListened() {
        streakViewModel?.completeTask(taskId: "listen_audio")
        logAction("Audio affirmation listened", taskId: "listen_audio")
    }
    
    // MARK: - Notification Observers
    
    private func setupNotificationObservers() {
        // Listen for app events that indicate task completion
        NotificationCenter.default.publisher(for: .affirmationSpoken)
            .sink { [weak self] _ in
                self?.trackAffirmationSpoken()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .affirmationShared)
            .sink { [weak self] _ in
                self?.trackAffirmationShared()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .devotionalCompleted)
            .sink { [weak self] _ in
                self?.trackDevotionalRead()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .audioAffirmationCompleted)
            .sink { [weak self] _ in
                self?.trackAudioListened()
            }
            .store(in: &cancellables)
    }
    
    /// These four event names are display-cased with spaces rather than
    /// snake_case. They are kept verbatim so the existing series stay
    /// continuous, but they used to carry no properties at all — every one of
    /// them was an undifferentiated count. `task_id` makes them joinable to the
    /// streak/checklist tasks they actually complete.
    private func logAction(_ action: String, taskId: String) {
        AnalyticsService.shared.track(action, parameters: [
            "task_id": taskId,
            "streak_source": "streak_integration_manager"
        ])
    }
}

// MARK: - Notification Extensions
extension Notification.Name {
    static let affirmationSpoken = Notification.Name("affirmationSpoken")
    static let affirmationShared = Notification.Name("affirmationShared")
    static let devotionalCompleted = Notification.Name("devotionalCompleted")
    static let audioAffirmationCompleted = Notification.Name("audioAffirmationCompleted")
}

// MARK: - Easy Integration Helpers
extension StreakIntegrationManager {
    
    /// Helper method to post notification for affirmation spoken
    static func notifyAffirmationSpoken() {
        NotificationCenter.default.post(name: .affirmationSpoken, object: nil)
    }
    
    /// Helper method to post notification for affirmation shared
    static func notifyAffirmationShared() {
        NotificationCenter.default.post(name: .affirmationShared, object: nil)
    }
    
    /// Helper method to post notification for devotional completed
    static func notifyDevotionalCompleted() {
        NotificationCenter.default.post(name: .devotionalCompleted, object: nil)
    }
    
    /// Helper method to post notification for audio completed
    static func notifyAudioCompleted() {
        NotificationCenter.default.post(name: .audioAffirmationCompleted, object: nil)
    }
}

// MARK: - Integration Instructions
/*
 To integrate the enhanced streak system with existing app functionality:
 
 1. In DeclarationView.swift, replace the existing countdown timer with:
    EnhancedStreakView()
 
 2. In AudioPlayer or audio playback completion:
    StreakIntegrationManager.notifyAudioCompleted()
 
 3. In share functionality:
    StreakIntegrationManager.notifyAffirmationShared()
 
 4. In devotional reading completion:
    StreakIntegrationManager.notifyDevotionalCompleted()
 
 5. When user speaks/declares affirmations:
    StreakIntegrationManager.notifyAffirmationSpoken()
 
 6. In your main app setup (likely SpeakLifeApp.swift), initialize:
    StreakIntegrationManager.shared.setStreakViewModel(enhancedStreakViewModel)
 
 Example usage in existing views:
 
 // In a share button action:
 Button("Share") {
     // existing share logic...
     StreakIntegrationManager.notifyAffirmationShared()
 }
 
 // In audio player completion:
 func audioDidFinishPlaying() {
     // existing logic...
     StreakIntegrationManager.notifyAudioCompleted()
 }
 
 // In devotional view when user finishes reading:
 func markDevotionalComplete() {
     // existing logic...
     StreakIntegrationManager.notifyDevotionalCompleted()
 }
 */
