//
//  WeeklyFocusViewModel.swift
//  SpeakLife
//
//  Drives the Sunday check-in sheet, the feed card, and the week overview.
//  Same shape as PersonalDeclarationViewModel — injected use cases, no logic in
//  views, no dependency instantiated inside.
//
//  The premium gate lives here rather than in the sheet, because it is a
//  *state transition* and not a piece of layout: free and premium users take
//  the same path right up to the moment the week would be handed over.
//

import Foundation
import SwiftUI

enum WeeklyFocusStep: Equatable {
    /// Mic / text entry.
    case input
    /// Input was too vague — ask for a little more.
    case clarify
    /// Brief pause so the result lands as an answer, not a lookup.
    case matching
    /// Their need echoed back with one matched verse + declaration. Both tiers
    /// reach this step; it is the last one free users get.
    case result
    /// Free tier only. "Here's your week" is the locked door.
    case paywall
    /// Premium. The seven days, laid out.
    case week
}

@MainActor
final class WeeklyFocusViewModel: ObservableObject {

    // MARK: - State

    @Published var step: WeeklyFocusStep = .input
    @Published var inputText: String = ""
    @Published var isRecording: Bool = false
    @Published var showTextInput: Bool = false
    @Published var match: DeclarationMatch? = nil
    @Published var errorMessage: String? = nil
    @Published var isSubmitting: Bool = false

    /// This week's record. Present as soon as `load()` runs — the week is
    /// always built, so this is nil only before the first load completes.
    @Published private(set) var focus: WeeklyFocus? = nil

    /// True when the answer landed after days of the week had already been
    /// consumed, which changes the confirmation copy to "the rest of your week".
    @Published private(set) var didRebuildPartialWeek = false

    /// This week's bucket devotional, shared by everyone carrying the same kind
    /// of need. nil until it resolves, and nil forever when the flag is off,
    /// the user is free, or the fetch failed — the week is complete without it,
    /// so the overview simply omits the section.
    @Published private(set) var devotional: WeeklyFocusDevotional? = nil

    /// Where this presentation was opened from — push | card | interstitial.
    /// Stamped onto every check-in event so answer rate can be split by surface.
    var surface: String = "card"

    // MARK: - Dependencies (injected — never instantiated inside)

    private let repository: WeeklyFocusRepositoryProtocol
    private let buildUseCase: BuildWeeklyFocusUseCase
    private let answerUseCase: AnswerWeeklyFocusUseCase
    private let completeDayUseCase: CompleteWeeklyDayUseCase
    private let matchUseCase: MatchDeclarationUseCase
    private let speechService: SpeechTranscriptionProtocol
    /// Phase 3. Its own kill switch, defaulted off, and every failure returns
    /// nil rather than throwing — so this dependency cannot affect the week.
    private let devotionalService: WeeklyFocusDevotionalService
    private let defaults: UserDefaults

    private var openedAt = Date()
    private var inputMethod = "text"

    init(repository: WeeklyFocusRepositoryProtocol,
         buildUseCase: BuildWeeklyFocusUseCase,
         answerUseCase: AnswerWeeklyFocusUseCase,
         completeDayUseCase: CompleteWeeklyDayUseCase,
         matchUseCase: MatchDeclarationUseCase,
         speechService: SpeechTranscriptionProtocol,
         devotionalService: WeeklyFocusDevotionalService = WeeklyFocusDevotionalService(),
         defaults: UserDefaults = .standard) {
        self.repository = repository
        self.buildUseCase = buildUseCase
        self.answerUseCase = answerUseCase
        self.completeDayUseCase = completeDayUseCase
        self.matchUseCase = matchUseCase
        self.speechService = speechService
        self.devotionalService = devotionalService
        self.defaults = defaults
    }

    // MARK: - Storage keys

    /// How many Sundays this user has answered while on the free tier. Reported
    /// on both paywall events: if answering three Sundays running converts
    /// materially better than answering once, the free ask is earning its place.
    private static let freeAnswerCountKey = "weekly_focus_free_answers"
    /// A free user's answer, held until they subscribe. Subscribing mid-week
    /// must not make them say it all over again.
    private static let pendingAnswerKey = "weekly_focus_pending_answer"
    /// `weekStart` the pending answer was given for. An answer to last week's
    /// question is not an answer to this week's.
    private static let pendingAnswerWeekKey = "weekly_focus_pending_answer_week"

    // MARK: - Lifecycle

    /// Builds this week if it doesn't exist yet and publishes it. Cheap and
    /// idempotent — safe to call on every appear.
    ///
    /// `isPremium` is passed in rather than read here: entitlement lives on
    /// `SubscriptionStore`, which is an `@EnvironmentObject`, and reaching for a
    /// singleton copy of it inside a view model is how the two drift apart.
    func load(isPremium: Bool) async {
        let built = await buildUseCase.execute()
        focus = built
        await applyPendingAnswerIfNeeded(isPremium: isPremium)
        // Deliberately AFTER the pending-answer commit: that can replace the
        // week (and with it the bucket), and fetching against the old bucket
        // first would pay to generate a devotional nobody is going to read.
        guard isPremium else { return }
        Task { [weak self] in await self?.loadDevotional() }
    }

    /// Fetches this week's bucket devotional. Cheap by construction: memoized
    /// per launch, cached on device for the week, and served from a Firestore
    /// document shared by every user in the bucket. Only the first user in a
    /// given `(bucket, week)` pays for a generation.
    private func loadDevotional() async {
        guard let focus else { return }
        devotional = await devotionalService.devotional(for: focus)
    }

    /// Resets the sheet to a fresh ask. Called when the sheet is presented so a
    /// second open doesn't land on the previous result.
    func prepareForPresentation(surface: String) {
        self.surface = surface
        self.openedAt = Date()
        self.inputMethod = "text"
        self.didRebuildPartialWeek = false
        self.errorMessage = nil
        self.match = nil
        self.inputText = ""
        self.showTextInput = false
        self.step = .input
        AnalyticsService.shared.track("weekly_checkin_shown", parameters: [
            "surface": surface,
            "need_bucket": focus?.needBucket ?? "unknown"
        ])
    }

    // MARK: - Copy

    /// Both defined on `WeeklyFocus` so the sheet and the pinned feed card can
    /// never disagree about what is being asked.
    var question: String {
        focus?.question ?? "What do you need God's help\nwith this week?"
    }

    var isEscalating: Bool { focus?.isEscalating ?? false }

    // MARK: - Input

    func startRecording() async {
        let permitted = await speechService.requestPermission()
        guard permitted else {
            showTextInput = true  // graceful fallback if denied
            return
        }
        do {
            try await speechService.startRecording()
            isRecording = true
            inputMethod = "voice"
        } catch {
            showTextInput = true
        }
    }

    func stopRecording() async {
        let transcribed = await speechService.stopRecording()
        isRecording = false
        inputText = transcribed
        do {
            try DeclarationInputValidator.validate(transcribed)
            await runMatch(input: transcribed)
        } catch let error as DeclarationInputError {
            errorMessage = error.prompt
        } catch {
            errorMessage = "We couldn't understand that. Try again."
        }
    }

    func submitTextInput() async {
        inputMethod = "text"
        do {
            try DeclarationInputValidator.validate(inputText)
            await runMatch(input: inputText)
        } catch let error as DeclarationInputError {
            errorMessage = error.prompt
        } catch {
            errorMessage = "Tell us a bit more about this week."
        }
    }

    func skip() {
        AnalyticsService.shared.track("weekly_checkin_skipped", parameters: ["surface": surface])
    }

    private func runMatch(input: String) async {
        step = .matching
        try? await Task.sleep(nanoseconds: 1_200_000_000)
        match = await matchUseCase.execute(input: input)
        step = .result
    }

    // MARK: - The gate
    //
    // The ask is free and the echo is free. The week is not.
    //
    // The gate deliberately sits AFTER the answer: the moment someone has just
    // spoken their need aloud is the highest-investment point of their week,
    // and it is the wrong moment to show them a locked door with nothing behind
    // it. So both tiers reach `.result` — need echoed back, one keyword-matched
    // verse, one declaration — and only the seven-day week is withheld.
    //
    // Enforcement here is presentation-only and Phase 1 has no server call to
    // enforce against. Phase 2's `/weeklyFocus` endpoint is the real boundary
    // (server-side RevenueCat check, `{ needsPaywall: true }` before any model
    // work). Nothing on this path costs an LLM call for either tier.

    /// Called from the result screen's CTA.
    func continueToWeek(isPremium: Bool) async {
        guard !isSubmitting else { return }
        let answer = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !answer.isEmpty else { return }

        guard isPremium else {
            // Hold the answer so subscribing doesn't cost them a second telling.
            defaults.set(answer, forKey: Self.pendingAnswerKey)
            defaults.set(
                (focus?.weekStart ?? WeeklyFocus.weekStart()).timeIntervalSince1970,
                forKey: Self.pendingAnswerWeekKey
            )
            let answeredFree = defaults.integer(forKey: Self.freeAnswerCountKey) + 1
            defaults.set(answeredFree, forKey: Self.freeAnswerCountKey)
            AnalyticsService.shared.track("weekly_focus_paywall_shown", parameters: [
                "need_bucket": match.map { WeeklyFocus.bucket(for: $0.category) } ?? "unknown",
                "weeks_answered_free": answeredFree
            ])
            step = .paywall
            return
        }

        await commit(answer: answer)
    }

    /// Called when the paywall reports a successful purchase.
    func paywallConverted() async {
        AnalyticsService.shared.track("weekly_focus_paywall_converted", parameters: [
            "need_bucket": match.map { WeeklyFocus.bucket(for: $0.category) } ?? "unknown",
            "weeks_answered_free": defaults.integer(forKey: Self.freeAnswerCountKey)
        ])
        let answer = defaults.string(forKey: Self.pendingAnswerKey)
            ?? inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !answer.isEmpty else {
            step = .week
            return
        }
        await commit(answer: answer)
    }

    /// Applies an answer captured on the free tier once the user has premium,
    /// even if that happens on a later launch.
    ///
    /// The spec's edge case, in code: "subscribes mid-week after answering free
    /// → build the week immediately from the answer already captured; don't
    /// make them re-answer." Deliberately NOT limited to the ask window —
    /// converting on Thursday still gets the week they asked for. It IS limited
    /// to the same week: an answer to last Sunday's question is stale, and
    /// silently rewriting a running week with it would be worse than dropping it.
    private func applyPendingAnswerIfNeeded(isPremium: Bool) async {
        guard let pending = defaults.string(forKey: Self.pendingAnswerKey),
              !pending.isEmpty,
              let focus else { return }

        let pendingWeek = defaults.double(forKey: Self.pendingAnswerWeekKey)
        guard pendingWeek == focus.weekStart.timeIntervalSince1970 else {
            clearPendingAnswer()
            return
        }
        guard isPremium, !focus.isAnswered else { return }

        await commit(answer: pending)
    }

    private func clearPendingAnswer() {
        defaults.removeObject(forKey: Self.pendingAnswerKey)
        defaults.removeObject(forKey: Self.pendingAnswerWeekKey)
    }

    private func commit(answer: String) async {
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let result = try await answerUseCase.execute(
                answer: answer,
                surface: surface,
                inputMethod: inputMethod,
                secondsToAnswer: Date().timeIntervalSince(openedAt)
            )
            focus = result.focus
            didRebuildPartialWeek = result.isPartialWeek
            clearPendingAnswer()
            step = .week
            // Detached from the submit path on purpose. A cache MISS here is a
            // live generation, and the seven days arriving instantly is the
            // whole reason anyone answers a second Sunday — the devotional
            // fills in behind the screen that is already on it.
            Task { [weak self] in await self?.loadDevotional() }
        } catch {
            errorMessage = "Something went wrong. Please try again."
        }
    }

    // MARK: - Week

    func completeDay(_ day: Int) async {
        try? await completeDayUseCase.execute(day: day)
        focus = await repository.current()
    }

    /// "This is answered." Stops the carry-over rung from carrying the need
    /// into next week.
    func markResolved() async {
        try? await repository.markResolved()
        focus = await repository.current()
    }

    // MARK: - Card visibility
    //
    // The rule itself lives on `WeeklyFocus` — see the note there. These are
    // the view-model-side wrappers so a caller holding the VM doesn't have to
    // unwrap `focus` to ask.

    func shouldShowCard(weeklyFocusEnabled: Bool, at date: Date = Date()) -> Bool {
        focus?.shouldShowCard(enabled: weeklyFocusEnabled, at: date, defaults: defaults) ?? false
    }

    func dismissCard() {
        focus?.dismissCard(defaults: defaults)
        AnalyticsService.shared.track("weekly_checkin_skipped", parameters: ["surface": "card"])
    }
}
