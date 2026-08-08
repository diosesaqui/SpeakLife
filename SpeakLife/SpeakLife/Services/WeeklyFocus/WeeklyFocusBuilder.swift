//
//  WeeklyFocusBuilder.swift
//  SpeakLife
//
//  The fallback ladder.
//
//  Most users will not answer most weeks. The unanswered week still has to be
//  good, and it must not be a copy of last week — so five rungs are resolved in
//  order and the first hit wins:
//
//    1. .carryOver   last week's answer, not marked resolved
//    2. .anchor      the personal declaration
//    3. .profile     SoulProfile (onboarding)
//    4. .behavioral  ≥5 content interactions in the last 14 days
//    5. .default     declared notification categories — always available
//
//  Rungs 3 and 4 blend: the profile picks the theme, behavior breaks ties and
//  adds variety, so two consecutive profile-driven weeks don't look identical.
//
//  This can never return nil and can never return an empty week. Every early
//  exit below falls through to the next rung; the last rung has no failure
//  mode, because `.faith` always exists and the declaration pool is bundled.
//

import Foundation

final class WeeklyFocusBuilder: WeeklyFocusBuilderProtocol {

    private let repository: WeeklyFocusRepositoryProtocol
    private let personalDeclarationRepository: PersonalDeclarationRepositoryProtocol
    private let soulProfileRepository: SoulProfileRepositoryProtocol
    /// Wired to `KeywordDeclarationMatcher`, NOT to `DIContainer.declarationMatcher`.
    /// That one is `ClaudeDeclarationMatcher`, which makes a network call — and
    /// the whole point of Phase 1 is that a week costs zero LLM calls so the
    /// answer rate can be measured before any generation spend.
    private let matcher: DeclarationMatcherProtocol
    /// `WeeklyFocusSelecting`, not the concrete keyword selector: Phase 2 wires
    /// `WeeklyFocusRemoteSelector` here behind a Remote Config flag and the
    /// ladder must not be able to tell the difference. The remote one wraps the
    /// keyword one as its own fallback, so this stays "cannot fail" either way.
    private let selector: WeeklyFocusSelecting
    private let declarationProvider: WeeklyFocusDeclarationProviding
    private let defaults: UserDefaults

    init(repository: WeeklyFocusRepositoryProtocol,
         personalDeclarationRepository: PersonalDeclarationRepositoryProtocol,
         soulProfileRepository: SoulProfileRepositoryProtocol,
         matcher: DeclarationMatcherProtocol = KeywordDeclarationMatcher(),
         selector: WeeklyFocusSelecting = WeeklyFocusContentSelector(),
         declarationProvider: WeeklyFocusDeclarationProviding,
         defaults: UserDefaults = .standard) {
        self.repository = repository
        self.personalDeclarationRepository = personalDeclarationRepository
        self.soulProfileRepository = soulProfileRepository
        self.matcher = matcher
        self.selector = selector
        self.declarationProvider = declarationProvider
        self.defaults = defaults
    }

    // MARK: - WeeklyFocusBuilderProtocol

    func build(for weekStart: Date, answer: String?) async -> WeeklyFocus {
        let theme = await resolveTheme(for: weekStart, answer: answer)
        let pool = await declarationProvider.loadDeclarations()

        let selection = await selector.selectWeek(
            input: WeeklyFocusSelectionInput(
                needText: theme.needText,
                needBucket: theme.needBucket,
                primaryCategory: theme.category,
                varietyCategory: theme.varietyCategory,
                angle: theme.angle,
                carryOverCount: theme.carryOverCount,
                weekStart: weekStart,
                // ONLY the `.userAnswered` rung. This single flag is what keeps
                // "an unanswered week costs zero LLM calls" true after Phase 2 —
                // the remote selector refuses to leave the device without it, so
                // carry-over, anchor, profile, behavioral and default weeks stay
                // local and free no matter which selector is wired in.
                isFreshAnswer: theme.source == .userAnswered
            ),
            from: pool
        )

        // A selector that classified the need itself (the remote one) knows
        // better than the keyword matcher that produced `theme`. It reads the
        // whole sentence rather than scanning for words, and the bucket it
        // returns is the key of the devotional cache shared across users — so
        // when it answers, its answer wins. The keyword selector returns nil
        // here and the theme stands, which is Phase 1 unchanged.
        let categoryRaw = selection.categoryRaw ?? theme.category.rawValue
        let needBucket = selection.needBucket ?? theme.needBucket

        return WeeklyFocus(
            weekStart: weekStart,
            source: theme.source,
            angle: theme.angle,
            needText: theme.needText,
            needBucket: needBucket,
            categoryRaw: categoryRaw,
            declarationIDs: selection.declarationIDs,
            audioCategoryRaw: selection.audioCategoryRaw,
            framingLine: selection.framingLine,
            carryOverCount: theme.carryOverCount,
            answeredAt: theme.source == .userAnswered ? Date() : nil
        )
    }

    // MARK: - Theme resolution

    /// Everything the selector needs, resolved before any content is touched.
    private struct Theme {
        let source: WeeklyFocusSource
        let category: DeclarationCategory
        let needText: String?
        let needBucket: String
        let carryOverCount: Int
        let angle: WeeklyFocusAngle
        let varietyCategory: DeclarationCategory?
    }

    private func resolveTheme(for weekStart: Date, answer: String?) async -> Theme {
        // Behavior is resolved once and used two ways: as its own rung, and as
        // the tie-breaker layered onto the profile rung.
        let variety = behavioralCategory()

        if let answered = await answeredTheme(answer: answer) { return answered }
        if let carried = await carryOverTheme(for: weekStart) { return carried }
        if let anchored = await anchorTheme(variety: variety) { return anchored }
        if let profiled = await profileTheme(variety: variety) { return profiled }
        if let behavioral = behavioralTheme(variety: variety) { return behavioral }
        return defaultTheme(variety: variety)
    }

    // MARK: - 0. The answer itself

    private func answeredTheme(answer: String?) async -> Theme? {
        guard let answer else { return nil }
        let trimmed = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let match = await matcher.match(input: trimmed)
        return Theme(
            source: .userAnswered,
            category: match.category,
            needText: trimmed,
            needBucket: WeeklyFocus.bucket(for: match.category),
            // A fresh answer always restarts the progression. Week 1 on a need
            // is the promise, whatever the user said last month.
            carryOverCount: 0,
            angle: .promise,
            varietyCategory: nil
        )
    }

    // MARK: - 1. Carry-over

    private func carryOverTheme(for weekStart: Date) async -> Theme? {
        guard let previous = await repository.previousWeek(before: weekStart) else { return nil }
        // Only a need the user actually stated is worth carrying. A fallback
        // week has nothing to carry — re-running the ladder is strictly better
        // than repeating a guess.
        guard let needText = previous.needText, !needText.isEmpty else { return nil }
        guard previous.resolvedAt == nil else { return nil }

        let carryOverCount = previous.carryOverCount + 1
        let category = previous.category ?? .faith
        return Theme(
            source: .carryOver,
            category: category,
            needText: needText,
            needBucket: previous.needBucket,
            carryOverCount: carryOverCount,
            // promise → identity → authority → escalate. Same need, different
            // angle, so week 2 is not week 1 reshuffled.
            angle: WeeklyFocusAngle.forCarryOver(carryOverCount),
            varietyCategory: nil
        )
    }

    // MARK: - 2. The Anchor

    private func anchorTheme(variety: DeclarationCategory?) async -> Theme? {
        guard defaults.bool(forKey: "hasPersonalDeclaration") else { return nil }
        guard let declaration = await personalDeclarationRepository.load() else { return nil }
        // A declaration that already came to pass is a finished story, not this
        // week's need.
        guard !declaration.isReceived else { return nil }
        guard let category = declaration.category else { return nil }

        let belief = declaration.beliefText.trimmingCharacters(in: .whitespacesAndNewlines)
        return Theme(
            source: .anchor,
            category: category,
            // The Anchor's words are the user's own, so they're safe to echo —
            // but this is not an answer to *this week's* question, and stamping
            // it as one would make every anchor week look answered in the
            // funnel. `source` keeps the two apart.
            needText: belief.isEmpty ? nil : belief,
            needBucket: WeeklyFocus.bucket(for: category),
            carryOverCount: 0,
            angle: .promise,
            varietyCategory: variety
        )
    }

    // MARK: - 3. SoulProfile

    private func profileTheme(variety: DeclarationCategory?) async -> Theme? {
        guard let profile = await soulProfileRepository.load() else { return nil }
        guard let category = Self.category(from: profile) else { return nil }
        return Theme(
            source: .profile,
            category: category,
            needText: nil,
            needBucket: WeeklyFocus.bucket(for: category),
            carryOverCount: 0,
            angle: .promise,
            // The profile picks the theme; behavior adds the variety that keeps
            // two profile weeks in a row from looking the same.
            varietyCategory: variety
        )
    }

    /// goalWord first (it is the axis every onboarding arm collects), then the
    /// burden it was derived from as a backstop for partially-filled profiles.
    private static func category(from profile: SoulProfile) -> DeclarationCategory? {
        if let raw = profile.goalWord, let goalWord = SurveyGoalWord(rawValue: raw) {
            return goalWord.declarationCategory
        }
        if let raw = profile.heaviestBurden, let burden = HeaviestBurden(rawValue: raw) {
            return burden.goalWord.declarationCategory
        }
        return nil
    }

    // MARK: - 4. Behavioral

    private func behavioralTheme(variety: DeclarationCategory?) -> Theme? {
        guard let category = variety else { return nil }
        return Theme(
            source: .behavioral,
            category: category,
            needText: nil,
            needBucket: WeeklyFocus.bucket(for: category),
            carryOverCount: 0,
            angle: .promise,
            varietyCategory: nil
        )
    }

    /// The strongest category the user has actually engaged with recently, or
    /// nil when the signal is too thin to act on.
    ///
    /// Read straight out of UserDefaults rather than through
    /// `UserPreferencesTracker.shared` so the ladder stays free of the
    /// main-actor-bound singleton and can run from any context.
    private func behavioralCategory() -> DeclarationCategory? {
        guard let raw = defaults.string(forKey: "userTopCategories"),
              let data = raw.data(using: .utf8),
              let preferences = try? JSONDecoder()
                .decode([UserPreferencesTracker.CategoryPreference].self, from: data)
        else { return nil }

        let cutoff = Date().addingTimeInterval(-14 * 86_400)
        let recent = preferences.filter { $0.lastSelected >= cutoff }
        // The spec's bar: fewer than five interactions in two weeks is noise,
        // and a week built on noise is worse than one built on the profile.
        guard recent.reduce(0, { $0 + $1.count }) >= 5 else { return nil }

        return recent
            .sorted { $0.count > $1.count }
            .compactMap { DeclarationCategory(rawValue: $0.category) }
            .first
    }

    // MARK: - 5. Declared categories — always available

    private func defaultTheme(variety: DeclarationCategory?) -> Theme {
        let category = declaredCategory() ?? .faith
        return Theme(
            source: .default,
            category: category,
            needText: nil,
            needBucket: WeeklyFocus.bucket(for: category),
            carryOverCount: 0,
            angle: .promise,
            varietyCategory: variety
        )
    }

    /// First of the user's notification categories. Same source of truth the
    /// audio ordering and the daily push batch already read.
    private func declaredCategory() -> DeclarationCategory? {
        guard let raw = defaults.string(forKey: "selectedNotificationCategories") else { return nil }
        return raw
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .compactMap { DeclarationCategory(rawValue: $0) }
            .first
    }
}

// MARK: - Declaration source

/// Reads the shipped declaration set through the existing content pipeline
/// (bundled file → on-disk cache → Firebase Storage), so the week is selected
/// from exactly the declarations the feed is showing — including a remote
/// content upgrade the user has already downloaded.
final class LocalDeclarationProvider: WeeklyFocusDeclarationProviding {

    func loadDeclarations() async -> [Declaration] {
        await withCheckedContinuation { continuation in
            // `LocalAPIClient.declarations` resumes from a cached hit
            // synchronously and from a network load asynchronously; either way
            // it is documented to call back once. The box makes that a
            // guarantee rather than a trust — a second resume is a hard crash.
            let hasResumed = ResumeOnce()
            LocalAPIClient.shared.declarations { declarations, _, _ in
                guard hasResumed.claim() else { return }
                continuation.resume(returning: declarations)
            }
        }
    }

    /// Minimal single-shot latch. `NSLock` rather than a bare Bool because the
    /// callback can arrive on the loading queue.
    private final class ResumeOnce {
        private let lock = NSLock()
        private var claimed = false

        func claim() -> Bool {
            lock.lock()
            defer { lock.unlock() }
            guard !claimed else { return false }
            claimed = true
            return true
        }
    }
}
