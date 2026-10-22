//
//  PostOnboardingPresenter.swift
//  SpeakLifeCore
//
//  Who goes first once onboarding finishes (FE TDD §10), decided here rather
//  than by whichever SwiftUI modifier happens to fire first. Never two full
//  screen covers at once.
//
//   1. A pending Stand invite: the Stand join sheet. The referral page is
//      skipped this time and does not queue (spec §9.1).
//   2. Otherwise, if eligible: the referral page.
//   3. The welcome offer (D5) and the personal declaration prompt wait until
//      the referral page is closed.
//

import Foundation

public enum PostOnboardingStep: Equatable {
    case standJoin
    case referral
    case none
}

public enum PostOnboardingPresenter {

    public static func next(hasPendingStandCode: Bool, referralEligible: Bool) -> PostOnboardingStep {
        if hasPendingStandCode { return .standJoin }
        if referralEligible { return .referral }
        return .none
    }

    /// The welcome offer still arms after the first Daily Burst (D5), but waits
    /// while the referral page is on screen (FE-ORD-04).
    public static func canPresentWelcomeOffer(referralPageOpen: Bool) -> Bool {
        !referralPageOpen
    }

    /// The personal declaration prompt follows the referral page and never
    /// covers it (FE-ORD-05).
    public static func canPresentPersonalDeclarationPrompt(referralPageOpen: Bool) -> Bool {
        !referralPageOpen
    }
}
