//
//  DeclarationArcBuilder.swift
//  SpeakLife
//
//  Builds the 30-day arc exactly once, at onboarding completion, and never
//  blocks it.
//
//  CONTRACT — this must never throw, never block, and never cost us a completed
//  onboarding. `buildAtOnboardingCompletion` returns immediately; everything
//  after it runs on a detached task whose only failure mode is "no arc", which
//  leaves the feed exactly as it is today.
//
//  THE LADDER:
//    1. `declarationArcEnabled` off  → nothing at all. No arc, no call, no
//       write. This is the default, and it is what makes the feature safe to
//       ship dark: with no arc stored, DeclarationViewModel takes the path it
//       has always taken.
//    2. Flag on, AI on, remote call succeeds and enough IDs resolve locally
//       → a curated arc.
//    3. Anything else — AI kill switch off, network down, rate limited, a
//       response we can't use → a keyword arc from DeclarationArcSelector.
//       Retrieval either way, so rung 3 is a weaker ranking, not a weaker
//       promise.
//

import Foundation

enum DeclarationArcBuilder {

    /// Remote Config key, mirrored into UserDefaults by
    /// `SubscriptionStore.updateConfigValues`. DEFAULT OFF.
    static let featureFlagKey = "declarationArcEnabled"

    /// How many of the server's IDs must resolve against the library actually
    /// on this device before we trust the curated selection.
    ///
    /// The server computes IDs from its own copy of declarationsv10.json. If a
    /// device is running a different declarations file, some ids simply won't
    /// exist here. A handful missing is a shorter arc; most of them missing
    /// means the two libraries have diverged and the local selector will do a
    /// better job than a mostly-empty curated list.
    private static let minimumResolvedIDs = 20

    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: featureFlagKey)
    }

    // MARK: - Trigger

    /// Called from `SoulProfileBuilder.captureAtOnboardingCompletion`, right
    /// after the profile is persisted. Returns instantly.
    static func buildAtOnboardingCompletion(profile: SoulProfile) {
        guard isEnabled else { return }
        guard !DeclarationArcRepository.hasArc() else { return }

        // Detached rather than a child of whatever onboarding task is running:
        // this must outlive the view that triggered it and must never be
        // cancelled by it. Utility priority — nothing is waiting on the result.
        Task.detached(priority: .utility) {
            await DeclarationArcBuilder.buildIfNeeded(profile: profile)
        }
    }

    /// The whole build, awaited. Separated from the trigger so it can be called
    /// again later (a launch-time retry for a user whose onboarding call
    /// failed) without duplicating the ladder. Idempotent: no-ops when an arc
    /// already exists.
    static func buildIfNeeded(
        profile: SoulProfile?,
        repository: DeclarationArcRepositoryProtocol = DeclarationArcRepository(),
        remote: DeclarationArcRemoteSelecting = DeclarationArcService(),
        selector: DeclarationArcSelector = DeclarationArcSelector()
    ) async {
        guard isEnabled else { return }
        guard await repository.load() == nil else { return }

        let pool = await loadDeclarations()
        // The library not being loaded yet is the one case worth NOT falling
        // back for: an arc built from an empty pool is an empty arc, and it
        // would then block the real one from ever being built.
        guard !pool.isEmpty else {
            AnalyticsService.shared.track("declaration_arc_skipped", parameters: ["reason": "empty_library"])
            return
        }

        // The user's own words. The profile's anchor is the same text the
        // personal declaration was matched from; fall back to reading it out of
        // that record for profiles captured before the anchor was stored.
        let beliefText = profile?.anchorBeliefText ?? PersonalDeclarationRepository.activeBeliefText()

        var selection: DeclarationArcSelection?
        var source: DeclarationArcSource = .keyword

        // The existing AI kill switch gates the network leg. Off means keyword
        // selection, not no arc — this feature does not need an LLM to work,
        // it only gets better with one.
        if UserDefaults.standard.bool(forKey: "enableAIFeatures"),
           let remoteSelection = await remote.selectArc(beliefText: beliefText, profile: profile) {

            // ─── Second validation, on device ─────────────────────────────
            // The function already bounds-checks every pick against the
            // candidate set it built, so nothing invented can arrive here.
            // This checks something different: that the IDs it computed from
            // ITS copy of the library resolve against THIS device's copy.
            let known = Set(pool.filter { $0.contentType == .affirmation }.map { $0.id })
            var seen = Set<String>()
            let resolved = remoteSelection.declarationIDs.filter {
                known.contains($0) && seen.insert($0).inserted
            }

            if resolved.count >= minimumResolvedIDs {
                selection = DeclarationArcSelection(
                    declarationIDs: resolved,
                    categoryRaw: remoteSelection.categoryRaw
                )
                source = .curated
            } else {
                AnalyticsService.shared.track("declaration_arc_unresolved", parameters: [
                    "returned": remoteSelection.declarationIDs.count,
                    "resolved": resolved.count
                ])
            }
        }

        if selection == nil {
            selection = selector.select(beliefText: beliefText, profile: profile, from: pool)
            source = .keyword
        }

        guard let selection, !selection.declarationIDs.isEmpty else {
            AnalyticsService.shared.track("declaration_arc_skipped", parameters: ["reason": "no_selection"])
            return
        }

        let arc = DeclarationArc(
            declarationIDs: selection.declarationIDs,
            categoryRaw: selection.categoryRaw,
            source: source
        )

        do {
            try await repository.save(arc)
        } catch {
            AnalyticsService.shared.track("declaration_arc_skipped", parameters: ["reason": "save_failed"])
            return
        }

        AnalyticsService.shared.track("declaration_arc_built", parameters: [
            "source": source.rawValue,
            "category": arc.categoryRaw,
            "days": arc.declarationIDs.count,
            "has_belief_text": (beliefText?.isEmpty == false) as NSNumber
        ])
    }

    // MARK: - Library

    /// Bridges `LocalAPIClient`'s completion-handler API into async. Same shape
    /// as `LocalDeclarationProvider` in WeeklyFocusBuilder — duplicated rather
    /// than shared so this workstream owns its own loader and neither feature
    /// can break the other by changing one.
    private static func loadDeclarations() async -> [Declaration] {
        await withCheckedContinuation { continuation in
            // `LocalAPIClient.declarations` resumes from a cached hit
            // synchronously and from a network load asynchronously; either way
            // it is documented to call back once. The latch makes that a
            // guarantee rather than a trust — a second resume is a hard crash.
            let latch = ResumeLatch()
            LocalAPIClient.shared.declarations { declarations, _, _ in
                guard latch.claim() else { return }
                continuation.resume(returning: declarations)
            }
        }
    }

    /// Minimal single-shot latch. `NSLock` rather than a bare Bool because the
    /// callback can arrive on LocalAPIClient's loading queue.
    private final class ResumeLatch {
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
