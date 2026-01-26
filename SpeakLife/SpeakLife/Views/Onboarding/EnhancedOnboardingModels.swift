//
//  EnhancedOnboardingModels.swift
//  SpeakLife
//
//  Shared models and types for enhanced onboarding
//

import SwiftUI
import FirebaseAnalytics

// MARK: - Enhanced Tab Enum
enum EnhancedTab: Int {
    case emotionalRecognition = 0
    case internalExperience = 1
    case beliefGap = 2
    case authorityReframe = 3
    case practiceAwareness = 4
    case ahaMoment = 5
    case identityAspiration = 6
    case futurePacing = 7
    case coreMessage = 8
    case transitionToPaywall = 9
    case notification = 11
    case review = 12
    case subscription = 10
}

// MARK: - User Journey View Model
class OnboardingUserJourneyViewModel: ObservableObject {
    @Published var emotionalNeeds: Set<String> = []
    @Published var internalExperience: String = ""
    @Published var beliefGap: String = ""
    @Published var authorityReframe: String = ""
    @Published var practiceLevel: String = ""
    @Published var desiredIdentity: String = ""
    @Published var futureOutcome: String = ""
    @Published var commitment: String = ""
    
    var journey: OnboardingUserJourney {
        OnboardingUserJourney(
            emotionalNeeds: emotionalNeeds,
            internalExperience: internalExperience,
            beliefGap: beliefGap,
            authorityReframe: authorityReframe,
            practiceLevel: practiceLevel,
            desiredIdentity: desiredIdentity,
            futureOutcome: futureOutcome,
            commitment: commitment
        )
    }
}

// MARK: - User Journey Model
struct OnboardingUserJourney {
    var emotionalNeeds: Set<String> = []
    var internalExperience: String = ""
    var beliefGap: String = ""
    var authorityReframe: String = ""
    var practiceLevel: String = ""
    var desiredIdentity: String = ""
    var futureOutcome: String = ""
    var commitment: String = ""
}
