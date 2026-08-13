//
//  ServiceSeams.swift
//  SpeakLifeServices
//
//  Foundation-typed seams the app registers at startup, so the moved
//  services keep working without pulling UIKit / SwiftUI / Firebase into
//  the package graph. Same pattern as SpeakLifeCore's `CoreAnalytics`,
//  `DefaultFeatureFlags`, `DefaultVendorIdentifier`.
//
//  Every seam has a safe default (nil closure, no-op) so `swift test`
//  green-fields with just the package.
//

import Foundation
import SpeakLifeCore

// MARK: - Personal declaration progress

/// `TaskLibrary.getCoreTasksForStreak(...)` takes a
/// `PersonalDeclaration.Progress?`. The value used to be read via
/// `PersonalDeclarationRepository.todayProgress()` inline, but that
/// repository lives in the app target. The app registers a closure at
/// startup; tests leave it nil so the checklist row shows the default
/// state.
public enum PersonalDeclarationProgressBridge {
    public static var todayProgress: () -> PersonalDeclaration.Progress? = { nil }
}

// MARK: - Personal declaration repository storage key

/// The UserDefaults / sync key the app writes personal-declaration
/// state under, read from `EnhancedStreakViewModel` to decide when to
/// rebuild the checklist. Inlined here to match the same seam PR7 used
/// for `PersonalDeclarationRepository.storageKey`.
public enum PersonalDeclarationStorageKey {
    public static let value = "personal_declarations_v2"
}

// MARK: - Haptics + audio delight

/// Streak completion moments trigger haptics and short audio cues.
/// Both use UIKit and AVFoundation, so route through this seam. Nil
/// means "no side effect", which is exactly what a test wants.
public enum StreakFeedback {
    /// `PremiumHaptics.affirmationCompleted()` — a task inside the checklist ticked.
    public static var onTaskCompleted: () -> Void = {}
    /// `PremiumHaptics.dailyGoalCompleted()` — the streak day was earned.
    public static var onDayCompleted: () -> Void = {}
    /// `PremiumHaptics.newRecordSet()` — the day beat the previous longest.
    public static var onNewRecord: () -> Void = {}
    /// `AudioDelightManager.shared.playGentleSuccess()` — small "tick" cue.
    public static var playGentleSuccess: () -> Void = {}
    /// `AudioDelightManager.shared.playForStreakMilestone(_:)` — bigger cue on milestone days.
    public static var playForStreakMilestone: (Int) -> Void = { _ in }
}

// MARK: - Notification manager APIService seam

/// `NotificationManager.NotificationProcessor` needs an `APIService` to
/// pull declarations. The app's real service (`LocalAPIClient`) imports
/// SwiftUI and Firebase, so we default to a stub that returns no
/// declarations (safe for tests) and let the app install the real one.
public enum NotificationDeclarationSource {
    public static var apiServiceFactory: () -> APIService = { EmptyAPIService() }
}

/// Minimal APIService that always resolves to no declarations. Used only
/// as the default before the app installs its real one.
public final class EmptyAPIService: APIService {
    public init() {}
    public var remoteVersion: Int = 0
    public var localVersion: Int = 0
    public func declarations(completion: @escaping ([Declaration], APIError?, Bool) -> Void) {
        completion([], nil, false)
    }
    public func save(declarations: [Declaration], completion: @escaping (Bool) -> Void) {
        completion(true)
    }
    public func declarationCategories(completion: @escaping (Set<DeclarationCategory>, APIError?) -> Void) {
        completion([], nil)
    }
    public func save(selectedCategories: Set<DeclarationCategory>, completion: @escaping (Bool) -> Void) {
        completion(true)
    }
    public func audio(version: Int, completion: @escaping (WelcomeAudio?, [AudioDeclaration]?) -> Void) {
        completion(nil, nil)
    }
}
