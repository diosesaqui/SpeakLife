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
    case testimonials = 0
    case emotionalRecognition = 1
    case internalExperience = 2
    case beliefGap = 3
    case authorityReframe = 4
    case practiceAwareness = 5
    case ahaMoment = 6
    case identityAspiration = 7
    case futurePacing = 8
    case coreMessage = 9
    case transitionToPaywall = 10
    case notification = 12
    case review = 13
    case subscription = 11
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
