//
//  SoulProfile.swift
//  SpeakLife
//
//  Everything onboarding learns about the user, in one place.
//
//  Onboarding collects 12+ signals across 7 A/B variants, emits them as
//  analytics parameters, and then throws them away app-side — the only thing
//  that survived was HeaviestBurden → SurveyGoalWord → one DeclarationCategory.
//  SoulProfile is the durable record: written once at onboarding completion,
//  persisted by SoulProfileRepository (UserDefaults + Firestore mirror), and
//  read by notification scheduling today and Bible Chat / Weekly Focus next.
//
//  Every field is optional or defaulted. The identity arm collects far less
//  than the warfare arm, and quiz v1 never sets the v2 answers, so a partial
//  flow must still produce a valid profile.
//

import Foundation

struct SoulProfile: Codable, Equatable {

    /// Bump when a field changes meaning (not when one is added — decoding
    /// tolerates new optional fields). Readers can branch on this to migrate
    /// old records instead of discarding them.
    static let currentSchemaVersion = 1

    var schemaVersion: Int = SoulProfile.currentSchemaVersion

    // MARK: - Burden axis (collected in every variant)

    /// `HeaviestBurden.rawValue` — the thing the enemy has stolen.
    var heaviestBurden: String?
    /// `BurdenDuration.rawValue` — how long they've walked with Him.
    var burdenDuration: String?
    /// `SurveyGoalWord.rawValue` — PEACE / HEALING / IDENTITY / …
    var goalWord: String?

    // MARK: - Extended quiz (warfare / product / outcomes / promises / closer)
    //
    // Raw analytics values, matching the `value` on each ExtendedQuizOption in
    // SurveyOnboardingScreens.swift. Stored raw on purpose: the copy can be
    // rewritten without invalidating a stored profile.

    /// weeks | months | years | always
    var battleDuration: String?
    /// prayer | devotionals | therapy | willpower | everything
    var alreadyTried: String?
    /// night | morning | midday | evening — drives notification biasing.
    var hitsHardest: String?
    /// speaking | listening | reading | journaling (quiz v1 only)
    var connectStyle: String?
    /// one | three | ten
    var dailyMinutes: String?
    /// Burden-aware "victory_looks_like" value (quiz v2 only)
    var victoryOutcome: String?
    /// yes | want_to | unsure (quiz v2 only)
    var beliefLevel: String?

    // MARK: - Merged barriers screen

    /// `BarrierOption.rawValue`s. The only multi-select pain field.
    var barriers: [String] = []
    /// `DeclarationExperience.rawValue`
    var declarationExperience: String?

    // MARK: - Closer arm only

    var wantsCloser: Bool?
    var hasDrifted: Bool?

    // MARK: - Quiz arm only

    /// `QuizSegment.rawValue` — the ad-match axis.
    var quizSegment: String?
    /// One record per belief question actually answered (up to 6).
    var beliefAnswers: [BeliefAnswer] = []

    // MARK: - The Anchor

    /// The user's own words from the personal declaration step, verbatim. The
    /// single most valuable string in the profile — everything else is a
    /// bucketed enum, this is how they actually talk about their life.
    var anchorBeliefText: String?

    // MARK: - Provenance

    /// product | identity | warfare | outcomes | promises | closer | quiz
    var onboardingVariant: String?
    /// v1 | v2 for the survey arms, `QuizOnboardingView.quizVersion` for quiz.
    var quizVersion: String?
    var completedAt: Date?

    // MARK: - Belief answer

    /// One answer from `BeliefQuestion` (QuizOnboardingView). `isConfident` is
    /// the signal that matters: it separates "yes, He's crazy about me" from
    /// "He loves people, me specifically? not sure" inside the same question.
    struct BeliefAnswer: Codable, Equatable {
        /// `BeliefQuestion.analyticsId` — god_loves, too_messed_up, …
        let questionId: String
        /// `BeliefAnswer.id` — love_yes, love_unearned, …
        let answerId: String
        let isConfident: Bool
    }

    // MARK: - Derived

    /// questionId → isConfident, for callers that only need the shape of their
    /// belief and not which specific answer produced it.
    var beliefConfidence: [String: Bool] {
        Dictionary(beliefAnswers.map { ($0.questionId, $0.isConfident) },
                   uniquingKeysWith: { _, latest in latest })
    }

    /// How many of the answered belief questions came back confident. Nil when
    /// the user never ran the belief sequence (every non-quiz arm).
    var confidentBeliefCount: Int? {
        beliefAnswers.isEmpty ? nil : beliefAnswers.filter { $0.isConfident }.count
    }

    /// True when nothing beyond the schema version was ever captured. Guards
    /// the repository against persisting an empty shell.
    var isEmpty: Bool {
        self == SoulProfile()
    }
}
