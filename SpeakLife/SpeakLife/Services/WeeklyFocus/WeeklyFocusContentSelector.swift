//
//  WeeklyFocusContentSelector.swift
//  SpeakLife
//
//  Retrieval, not generation.
//
//  Phase 1 selects the week's declarations from the ~3,100 already shipped in
//  declarationsv10.json using keyword scoring — no LLM, no network, no cost.
//  Nothing is generated, so there is no hallucinated verse reference, no
//  doctrinal risk, and every line already passes the CLAUDE.md rules. Only IDs
//  are stored.
//
//  Phase 2 replaces `select` internals with an LLM call behind the Cloud
//  Function proxy. The signature is the seam: `needText`, `needBucket`,
//  `angle`, and `carryOverCount` are exactly what that call will be given, so
//  swapping the body does not move any caller.
//

import Foundation

// MARK: - Input / Output

struct WeeklyFocusSelectionInput {
    /// Their words, verbatim, when they answered. nil on every fallback rung.
    let needText: String?
    let needBucket: String
    /// The theme. Always leads the ranking.
    let primaryCategory: DeclarationCategory
    /// Behavioral variety seed — breaks ties so two consecutive profile-driven
    /// weeks don't look identical. nil when there is no engagement signal.
    let varietyCategory: DeclarationCategory?
    let angle: WeeklyFocusAngle
    let carryOverCount: Int
    /// Seeds the deterministic shuffle: the same week always resolves to the
    /// same declarations (so a rebuild is stable), a different week does not.
    let weekStart: Date
}

struct WeeklyFocusSelection {
    /// Flat, in day order. Count is always 14 or 21 so `declarationIDs(forDay:)`
    /// slices evenly.
    let declarationIDs: [String]
    let audioCategoryRaw: String
}

// MARK: - Selector

final class WeeklyFocusContentSelector {

    /// Three a day. Enough to carry a week without turning the feed into
    /// homework; the spec's 14–21 band with the top of it as the target.
    private static let preferredCount = 21
    /// Two a day. Used when the scored pool genuinely can't fill 21.
    private static let minimumCount = 14
    /// No single category may own more than this many of the week's slots, so
    /// even a wide category can't flatten the week into one note.
    private static let perCategoryCap = 9

    func select(input: WeeklyFocusSelectionInput, from pool: [Declaration]) -> WeeklyFocusSelection {
        let audioCategoryRaw = input.primaryCategory.rawValue

        // Journal entries share `.myOwn` with personal affirmations and the
        // two pseudo-categories aren't content at all — none of them belong in
        // a week.
        let candidates = pool.filter {
            $0.contentType == .affirmation
                && $0.category != .favorites
                && $0.category != .myOwn
        }
        guard !candidates.isEmpty else {
            return WeeklyFocusSelection(declarationIDs: [], audioCategoryRaw: audioCategoryRaw)
        }

        let keywords = Self.keywords(from: input.needText)
        let support = Self.supportCategories(for: input)

        var generator = SeededGenerator(seed: Self.seed(for: input))

        // Score once, then sort. The random tie-break is drawn per declaration
        // from the seeded generator, which is what makes week N+1 a different
        // set rather than the same 21 reshuffled — the scores are identical,
        // the jitter is not.
        var scored: [(declaration: Declaration, score: Double)] = []
        scored.reserveCapacity(candidates.count)
        for declaration in candidates {
            var score = 0.0
            if declaration.category == input.primaryCategory {
                score += Weight.primaryCategory
            }
            if let index = support.firstIndex(of: declaration.category) {
                score += Weight.supportCategory * pow(0.75, Double(index))
            }
            if declaration.category == input.varietyCategory {
                score += Weight.varietyCategory
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

        // Take in rank order under a per-category cap.
        var perCategory: [DeclarationCategory: Int] = [:]
        var picked: [Declaration] = []
        var pickedIDs = Set<String>()
        for entry in scored {
            guard picked.count < Self.preferredCount else { break }
            let used = perCategory[entry.declaration.category, default: 0]
            guard used < Self.perCategoryCap else { continue }
            guard pickedIDs.insert(entry.declaration.id).inserted else { continue }
            perCategory[entry.declaration.category] = used + 1
            picked.append(entry.declaration)
        }

        // Top up from the whole pool if scoring came back thin — the week is
        // always built, so a narrow category can never produce an empty one.
        if picked.count < Self.minimumCount {
            var filler = candidates.shuffled(using: &generator)
            filler.removeAll { pickedIDs.contains($0.id) }
            for declaration in filler {
                guard picked.count < Self.preferredCount else { break }
                guard pickedIDs.insert(declaration.id).inserted else { continue }
                picked.append(declaration)
            }
        }

        // Land on a count divisible by 7 so every day gets the same number of
        // declarations and the day slices stay exact.
        let target = picked.count >= Self.preferredCount ? Self.preferredCount : Self.minimumCount
        if picked.count > target {
            picked = Array(picked.prefix(target))
        } else if picked.count < target && !picked.isEmpty {
            // Pathologically small pool (only reachable in tests / a corrupt
            // content file). Cycle over a fixed base rather than ship a ragged
            // week — reading from `picked` while appending to it would walk a
            // moving target.
            let base = picked
            var index = 0
            while picked.count < target {
                picked.append(base[index % base.count])
                index += 1
            }
        }

        return WeeklyFocusSelection(
            declarationIDs: Self.sequence(picked).map { $0.id },
            audioCategoryRaw: audioCategoryRaw
        )
    }

    // MARK: - Sequencing

    /// Deals the ranked list across the seven days round-robin, then flattens
    /// in day order. Day 1 gets ranks 0, 7, 14; day 2 gets 1, 8, 15; and so on.
    ///
    /// The alternative — three contiguous slices — front-loads every strongest
    /// declaration into Sunday and leaves Saturday with the weakest of the set.
    /// Round-robin gives every day one strong line, one middle, one tail.
    private static func sequence(_ picked: [Declaration]) -> [Declaration] {
        guard picked.count >= 7 else { return picked }
        var days: [[Declaration]] = Array(repeating: [], count: 7)
        for (rank, declaration) in picked.enumerated() {
            days[rank % 7].append(declaration)
        }
        return days.flatMap { $0 }
    }

    // MARK: - Scoring weights

    private enum Weight {
        /// The theme leads. Nothing else can outrank a primary-category match
        /// on keywords alone.
        static let primaryCategory = 100.0
        /// The angle's supporting categories, decaying by position.
        static let supportCategory = 34.0
        /// Behavioral variety — enough to break ties, not enough to steer.
        static let varietyCategory = 14.0
        static let keywordInText = 9.0
        static let keywordInVerse = 4.0
        /// Below the smallest meaningful score gap, so jitter reorders peers
        /// and never promotes a weaker match over a stronger one.
        static let jitter = 3.0
    }

    // MARK: - Keywords

    /// Content words from the user's own sentence. Deliberately crude: this is
    /// a relevance nudge on top of category scoring, not a classifier — the
    /// classifier is `KeywordDeclarationMatcher`, which already picked the
    /// category before we got here.
    private static func keywords(from needText: String?) -> [String] {
        guard let needText, !needText.isEmpty else { return [] }
        let stopWords: Set<String> = [
            "that", "this", "with", "from", "have", "been", "will", "just",
            "about", "what", "when", "they", "them", "there", "their",
            "would", "could", "should", "because", "myself", "really", "going",
            "need", "want", "help", "please", "thing", "things", "lord", "god",
            "jesus", "pray", "prayer", "praying"
        ]
        var seen = Set<String>()
        var result: [String] = []
        for raw in needText.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted) {
            guard raw.count >= 4, !stopWords.contains(raw) else { continue }
            guard seen.insert(raw).inserted else { continue }
            result.append(raw)
            if result.count == 8 { break }
        }
        return result
    }

    // MARK: - Categories

    /// The angle's categories, minus the primary (it already scores higher) and
    /// with the variety category folded in at the back.
    private static func supportCategories(for input: WeeklyFocusSelectionInput) -> [DeclarationCategory] {
        var result = input.angle.supportCategories.filter { $0 != input.primaryCategory }
        if let variety = input.varietyCategory,
           variety != input.primaryCategory,
           !result.contains(variety) {
            result.append(variety)
        }
        return result
    }

    // MARK: - Seed

    /// Stable within a week, different across weeks and across carry-over
    /// counts. `hashValue` is deliberately avoided — Swift seeds it per launch,
    /// so a rebuild after a relaunch would produce a different week.
    private static func seed(for input: WeeklyFocusSelectionInput) -> UInt64 {
        var value = UInt64(bitPattern: Int64(input.weekStart.timeIntervalSince1970.rounded()))
        value = value &* 31 &+ UInt64(truncatingIfNeeded: input.carryOverCount)
        value = value &* 31 &+ fnv1a(input.needBucket)
        value = value &* 31 &+ fnv1a(input.primaryCategory.rawValue)
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

// MARK: - Deterministic RNG

/// SplitMix64. Reproducible for a given seed, which is the whole point —
/// `SystemRandomNumberGenerator` would hand the same user a different week
/// every time the record was rebuilt.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
