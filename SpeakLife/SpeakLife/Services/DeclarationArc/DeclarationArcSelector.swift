//
//  DeclarationArcSelector.swift
//  SpeakLife
//
//  The arc that gets built when the network doesn't answer.
//
//  Same premise as `WeeklyFocusContentSelector`, and deliberately the same
//  mechanics: keyword scoring over the shipped declarations, a seeded
//  generator so the arc is reproducible, a per-category cap so one wide
//  category can't flatten the thirty days into one note. Retrieval either way —
//  the only difference between this and the Cloud Function is who does the
//  ranking, never whether text is written.
//
//  This is what makes the trigger safe to fire and forget. The remote call can
//  fail, rate limit, or come back unusable and the user still gets thirty days
//  chosen around what they told us; nothing about onboarding depends on a
//  network round trip completing.
//

import Foundation

final class DeclarationArcSelector {

    /// One declaration per day.
    private static let targetCount = DeclarationArc.dayCount
    /// Below this an arc isn't worth building — the caller keeps the flat feed.
    private static let minimumCount = 12
    /// No single category may own more than this many of the thirty days.
    private static let perCategoryCap = 10

    /// - Parameters:
    ///   - beliefText: the user's own words, when we have them.
    ///   - profile: onboarding capture. Supplies the primary category.
    ///   - pool: the full shipped library (`allDeclarations`).
    func select(
        beliefText: String?,
        profile: SoulProfile?,
        from pool: [Declaration]
    ) -> DeclarationArcSelection? {
        let primary = Self.primaryCategory(profile: profile, beliefText: beliefText)

        // Journal entries share `.myOwn` with personal affirmations and the two
        // pseudo-categories aren't content at all — none of them belong in an
        // arc. Same filter WeeklyFocusContentSelector applies.
        let candidates = pool.filter {
            $0.contentType == .affirmation
                && $0.category != .favorites
                && $0.category != .myOwn
        }
        guard !candidates.isEmpty else { return nil }

        let keywords = Self.keywords(from: beliefText)
        let support = Self.supportCategories(for: primary)
        var generator = SeededGenerator(seed: Self.seed(profile: profile, category: primary))

        var scored: [(declaration: Declaration, score: Double)] = []
        scored.reserveCapacity(candidates.count)
        for declaration in candidates {
            var score = 0.0
            if declaration.category == primary {
                score += Weight.primaryCategory
            }
            if let index = support.firstIndex(of: declaration.category) {
                score += Weight.supportCategory * pow(0.8, Double(index))
            }
            if let index = Self.spine.firstIndex(of: declaration.category) {
                score += Weight.spineCategory * pow(0.9, Double(index))
            }
            if !keywords.isEmpty {
                let text = declaration.text.lowercased()
                let verse = declaration.bibleVerseText?.lowercased() ?? ""
                for keyword in keywords {
                    if text.contains(keyword) { score += Weight.keywordInText }
                    if verse.contains(keyword) { score += Weight.keywordInVerse }
                }
            }
            guard score > 0 else { continue }
            score += Double.random(in: 0..<Weight.jitter, using: &generator)
            scored.append((declaration: declaration, score: score))
        }

        scored.sort { $0.score > $1.score }

        var perCategory: [DeclarationCategory: Int] = [:]
        var picked: [Declaration] = []
        var pickedIDs = Set<String>()
        for entry in scored {
            guard picked.count < Self.targetCount else { break }
            let used = perCategory[entry.declaration.category, default: 0]
            guard used < Self.perCategoryCap else { continue }
            guard pickedIDs.insert(entry.declaration.id).inserted else { continue }
            perCategory[entry.declaration.category] = used + 1
            picked.append(entry.declaration)
        }

        // Top up from the whole pool if scoring came back thin, so a narrow
        // category can never produce a five-day "thirty-day" arc.
        if picked.count < Self.targetCount {
            var filler = candidates.shuffled(using: &generator)
            filler.removeAll { pickedIDs.contains($0.id) }
            for declaration in filler {
                guard picked.count < Self.targetCount else { break }
                guard pickedIDs.insert(declaration.id).inserted else { continue }
                picked.append(declaration)
            }
        }

        guard picked.count >= Self.minimumCount else { return nil }

        return DeclarationArcSelection(
            declarationIDs: Self.sequence(picked).map { $0.id },
            categoryRaw: primary.rawValue
        )
    }

    // MARK: - Sequencing

    /// Ranked order carries the first days; category round-robin carries the
    /// rest.
    ///
    /// Taking the ranked list as-is would put the ten strongest matches — all
    /// from the same category, by construction — on days 1 through 10, and the
    /// user would read the same note for a week and a half. Dealing round-robin
    /// across categories, with the categories themselves in rank order, keeps
    /// the best match on day 1 and then alternates the note day to day.
    private static func sequence(_ picked: [Declaration]) -> [Declaration] {
        var order: [DeclarationCategory] = []
        var groups: [DeclarationCategory: [Declaration]] = [:]
        for declaration in picked {
            if groups[declaration.category] == nil {
                groups[declaration.category] = []
                order.append(declaration.category)
            }
            groups[declaration.category]?.append(declaration)
        }

        var result: [Declaration] = []
        result.reserveCapacity(picked.count)
        var round = 0
        while result.count < picked.count {
            var placedThisRound = false
            for category in order {
                guard let group = groups[category], round < group.count else { continue }
                result.append(group[round])
                placedThisRound = true
            }
            // Defensive: every group is non-empty and `round` only grows, so
            // this is unreachable. It exists so a future edit to the grouping
            // can't turn this into an infinite loop.
            guard placedThisRound else { break }
            round += 1
        }
        return result
    }

    // MARK: - Scoring weights

    private enum Weight {
        /// What they told us they are carrying. Nothing else outranks it.
        static let primaryCategory = 100.0
        /// The categories that sit closest to the primary one.
        static let supportCategory = 34.0
        /// Identity, grace, destiny — the spine every arc needs for its back
        /// half, regardless of what brought the person in.
        static let spineCategory = 16.0
        static let keywordInText = 9.0
        static let keywordInVerse = 4.0
        /// Below the smallest meaningful score gap, so jitter reorders peers
        /// and never promotes a weaker match over a stronger one.
        static let jitter = 3.0
    }

    // MARK: - Categories

    /// The back half of any arc. Mirrors SPINE_CATEGORIES in
    /// `functions/declarationArc.js` so the two paths produce arcs of the same
    /// shape.
    private static let spine: [DeclarationCategory] = [
        .identity, .grace, .faith, .destiny, .love, .warfare, .gratitude
    ]

    /// goalWord first (the axis every onboarding arm collects), then the burden
    /// it was derived from, then the user's own words, then faith. Same ladder
    /// as `WeeklyFocusBuilder.category(from:)` and the Cloud Function's
    /// `resolveCategory`.
    private static func primaryCategory(profile: SoulProfile?, beliefText: String?) -> DeclarationCategory {
        if let raw = profile?.goalWord, let goalWord = SurveyGoalWord(rawValue: raw) {
            return goalWord.declarationCategory
        }
        if let raw = profile?.heaviestBurden, let burden = HeaviestBurden(rawValue: raw) {
            return burden.goalWord.declarationCategory
        }
        if let beliefText, !beliefText.isEmpty {
            let matched = KeywordDeclarationMatcher().matchAll(input: beliefText)
            if let first = matched.first { return first }
        }
        return .faith
    }

    /// The goal word's own supporting set when we can resolve it (it is the
    /// same set onboarding already uses to seed notification categories), minus
    /// the primary, which scores higher on its own.
    private static func supportCategories(for primary: DeclarationCategory) -> [DeclarationCategory] {
        let goalWord = SurveyGoalWord.allCases.first { $0.declarationCategory == primary }
        let base = goalWord?.notificationCategories ?? [.faith, .grace, .hope, .identity]
        // Sorted by rawValue, not by `DeclarationCategory.<` (which compares
        // display names with `<=` and is therefore not a strict ordering), and
        // sorted at all because Set iteration order is not stable across
        // launches — an unsorted support list would silently reweight the arc
        // on a rebuild.
        return base.filter { $0 != primary }.sorted { $0.rawValue < $1.rawValue }
    }

    // MARK: - Keywords

    /// Content words from the user's own sentence. Deliberately crude: a
    /// relevance nudge on top of category scoring, not a classifier. Copied in
    /// spirit from `WeeklyFocusContentSelector.keywords(from:)`.
    private static func keywords(from beliefText: String?) -> [String] {
        guard let beliefText, !beliefText.isEmpty else { return [] }
        let stopWords: Set<String> = [
            "that", "this", "with", "from", "have", "been", "will", "just",
            "about", "what", "when", "they", "them", "there", "their",
            "would", "could", "should", "because", "myself", "really", "going",
            "need", "want", "help", "please", "thing", "things", "lord", "god",
            "jesus", "pray", "prayer", "praying", "life", "more", "over",
            "into", "know", "feel", "like", "much"
        ]
        var seen = Set<String>()
        var result: [String] = []
        for raw in beliefText.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted) {
            guard raw.count >= 4, !stopWords.contains(raw) else { continue }
            guard seen.insert(raw).inserted else { continue }
            result.append(raw)
            if result.count == 10 { break }
        }
        return result
    }

    // MARK: - Seed

    /// Stable for a given person, different across people. `hashValue` is
    /// deliberately avoided — Swift seeds it per launch, so a rebuild after a
    /// relaunch would produce a different arc.
    private static func seed(profile: SoulProfile?, category: DeclarationCategory) -> UInt64 {
        var value: UInt64 = 0xcbf29ce484222325
        value = value &* 31 &+ fnv1a(category.rawValue)
        value = value &* 31 &+ fnv1a(profile?.heaviestBurden ?? "")
        value = value &* 31 &+ fnv1a(profile?.victoryOutcome ?? "")
        value = value &* 31 &+ fnv1a(profile?.anchorBeliefText ?? "")
        return value
    }

    /// FNV-1a: tiny, deterministic across launches and OS versions.
    private static func fnv1a(_ string: String) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return hash
    }
}
