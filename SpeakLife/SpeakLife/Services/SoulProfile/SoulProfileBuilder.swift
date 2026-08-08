//
//  SoulProfileBuilder.swift
//  SpeakLife
//
//  SurveyResponses → SoulProfile, in one place.
//
//  All 7 onboarding variants run a near-identical `applyResponsesAndComplete()`.
//  The mapping lives here so adding a field means touching one file, not seven.
//  The quiz arm has a different shape (QuizSegment + belief answers instead of
//  the extended quiz) — it goes through the same entry point with the extra
//  signals passed alongside its (sparse) SurveyResponses.
//

import Foundation

enum SoulProfileBuilder {

    // MARK: - Pure mapping

    /// Builds the profile without touching storage or app state. Kept separate
    /// so it stays trivially testable and so callers that only want the value
    /// (analytics, future Weekly Focus) don't get side effects.
    static func build(
        responses: SurveyResponses,
        variant: String,
        quizVersion: String,
        anchorBeliefText: String? = nil,
        burdenOverride: HeaviestBurden? = nil,
        quizSegment: String? = nil,
        beliefAnswers: [SoulProfile.BeliefAnswer] = [],
        wantsCloser: Bool? = nil,
        hasDrifted: Bool? = nil,
        completedAt: Date = Date()
    ) -> SoulProfile {
        // The quiz arm holds its burden in its own @State and only seeds
        // `responses` late, so an explicit override always wins.
        let burden = burdenOverride ?? responses.heaviestBurden

        var profile = SoulProfile()
        profile.heaviestBurden = burden?.rawValue
        profile.burdenDuration = responses.burdenDuration?.rawValue
        // resolvedGoalWord falls back to .peace, so derive from the burden we
        // actually have rather than recording a default nobody chose.
        profile.goalWord = burden?.goalWord.rawValue

        profile.battleDuration = responses.battleDuration
        profile.alreadyTried = responses.alreadyTried
        profile.hitsHardest = responses.hitsHardest
        profile.connectStyle = responses.connectStyle
        profile.dailyMinutes = responses.dailyMinutes
        profile.victoryOutcome = responses.victoryOutcome
        profile.beliefLevel = responses.beliefLevel

        // Sorted so two identical selections always encode identically —
        // Set iteration order is not stable across launches.
        profile.barriers = responses.barriers.map { $0.rawValue }.sorted()
        profile.declarationExperience = responses.declarationExperience?.rawValue

        profile.wantsCloser = wantsCloser
        profile.hasDrifted = hasDrifted

        profile.quizSegment = quizSegment
        profile.beliefAnswers = beliefAnswers

        let trimmedAnchor = anchorBeliefText?.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.anchorBeliefText = (trimmedAnchor?.isEmpty ?? true) ? nil : trimmedAnchor

        profile.onboardingVariant = variant
        profile.quizVersion = quizVersion
        profile.completedAt = completedAt

        return profile
    }

    // MARK: - Capture at onboarding completion

    /// The single call every variant makes on its terminal step. Builds the
    /// profile, persists it, flips `appState.hasSoulProfile`, and fills in a
    /// notification window when the user never picked one.
    ///
    /// Never throws: a failed capture must not cost us a completed onboarding.
    @discardableResult
    static func captureAtOnboardingCompletion(
        responses: SurveyResponses,
        appState: AppState,
        variant: String,
        quizVersion: String,
        anchorBeliefText: String? = nil,
        burdenOverride: HeaviestBurden? = nil,
        quizSegment: String? = nil,
        beliefAnswers: [SoulProfile.BeliefAnswer] = [],
        wantsCloser: Bool? = nil,
        hasDrifted: Bool? = nil
    ) -> SoulProfile {
        let profile = build(
            responses: responses,
            variant: variant,
            quizVersion: quizVersion,
            anchorBeliefText: anchorBeliefText,
            burdenOverride: burdenOverride,
            quizSegment: quizSegment,
            beliefAnswers: beliefAnswers,
            wantsCloser: wantsCloser,
            hasDrifted: hasDrifted
        )

        applyNotificationWindowFallback(responses: responses, appState: appState)

        // Synchronous on purpose. Every variant calls this immediately before
        // requesting notification permission and scheduling, and the scheduler
        // reads `hitsHardest` straight back out of UserDefaults — an awaited
        // write could lose that race and schedule an unbiased first batch.
        // The Firestore mirror inside `saveNow` is the only deferred half.
        DIContainer.shared.soulProfileRepository.saveNow(profile)
        appState.hasSoulProfile = true

        // The 30-day arc, built once, from the profile that was just written.
        // Fire-and-forget by contract: this returns immediately, no-ops
        // entirely while `declarationArcEnabled` is off (the default), and its
        // only failure mode is "no arc", which leaves the feed exactly as it is
        // today. Nothing about onboarding waits on it or can fail because of
        // it — see DeclarationArcBuilder's header for the fallback ladder.
        DeclarationArcBuilder.buildAtOnboardingCompletion(profile: profile)

        AnalyticsService.shared.track("soul_profile_captured", parameters: [
            "variant": variant,
            "quiz_version": quizVersion,
            "hits_hardest": profile.hitsHardest ?? "unknown",
            "has_anchor_text": (profile.anchorBeliefText != nil) as NSNumber,
            "belief_answers": profile.beliefAnswers.count
        ])

        return profile
    }

    // MARK: - Notification window fallback

    /// Half of the `hitsHardest` → scheduling wiring (the other half is the
    /// slot bias in NotificationManager).
    ///
    /// The user's explicit pick on the notification-time screen is authoritative
    /// and is never touched here — each variant has already applied it by the
    /// time we run. This only fills the gap: when they advanced past that screen
    /// without choosing, we use the window implied by *when they told us it hits
    /// hardest* instead of leaving them on the generic all-day default.
    static func applyNotificationWindowFallback(responses: SurveyResponses, appState: AppState) {
        guard responses.notificationTime == nil,
              let suggested = responses.suggestedNotificationTime else { return }
        appState.startTimeIndex = suggested.startTimeIndex
        appState.endTimeIndex = suggested.endTimeIndex
        appState.personalDeclarationTimeIndex = suggested.startTimeIndex
    }
}
