//
//  OnboardingTypes.swift
//  SpeakLife
//

import Foundation

enum Tab: String {
    // Survey onboarding (replaces pre-paywall screens)
    case survey

    // Legacy pre-paywall screens (preserved for A/B testing)
    case emotionalHook
    case categorySelect
    case livePreview
    case socialProof
    case dailyCommitment

    // Post-survey
    case subscription
    case notification
}
