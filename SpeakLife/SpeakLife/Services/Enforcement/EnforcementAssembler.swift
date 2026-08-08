//
//  EnforcementAssembler.swift
//  SpeakLife
//
//  Builds a seven-day campaign for ANY life-situation category by drawing from
//  the reviewed declaration pool the app already ships.
//
//  Why assemble rather than generate: every line in declarationsv10.json has
//  already passed the fifteen rules in CLAUDE.md. A user speaks these aloud over
//  their own body, marriage, or finances — nothing unreviewed should reach that
//  moment. Assembly gives per-user campaigns without per-user theology.
//
//  The four hand-authored campaigns in enforcements.json still win when their
//  category is the top match; they have a deliberate day-to-day arc a draw
//  cannot reproduce. Assembly covers the other twenty-five.
//

import Foundation

enum EnforcementAssembler {

    /// Categories that describe a life situation rather than a book of the Bible.
    /// `declarationsv10.json` also buckets content by book (genesis, luke, romans…)
    /// and nobody is walking through "a hard week of Leviticus", so those are
    /// excluded from campaign matching.
    static let bookCategories: Set<String> = [
        "genesis", "exodus", "leviticus", "joshua", "judges", "ruth",
        "samuel1", "samuel2", "kings1", "kings2", "chronicles1", "chronicles2",
        "ezra", "psalms", "proverbs", "matthew", "mark", "luke", "john",
        "romans", "corinthians1", "corinthians2", "galatians", "ephesians",
        "philippians", "colossians", "thessalonians1", "thessalonians2",
        "hebrews", "james", "peter1", "peter2", "revelation"
    ]

    static func isCampaignable(_ category: DeclarationCategory) -> Bool {
        !bookCategories.contains(category.rawValue.lowercased())
    }

    /// Builds a campaign, blending the matched categories across the seven days.
    ///
    /// - Parameters:
    ///   - primary: the strongest match; gets the largest share of the week.
    ///   - secondaries: weaker matches, in rank order. Real weeks are rarely one
    ///     thing — "my marriage is falling apart and I can't sleep" should not
    ///     produce seven days that ignore the sleep.
    ///   - pool: every reviewed declaration (`declarationsv10.json`).
    ///   - seed: makes the draw stable. Day 3 must be the same line every time
    ///     the user opens the app, or the campaign stops feeling like a campaign.
    /// - Returns: nil when the matched categories can't fill seven days.
    static func assemble(primary: DeclarationCategory,
                         secondaries: [DeclarationCategory] = [],
                         pool: [Declaration],
                         seed: String) -> Enforcement? {

        let categories = ([primary] + secondaries)
            .filter(isCampaignable)
            .reduced()

        guard let lead = categories.first else { return nil }

        // How many days each category owns. The lead keeps the majority so the
        // week still reads as being about one thing.
        let shares = dayShares(for: categories.count)

        var picked: [(Declaration, DeclarationCategory)] = []
        var usedTexts = Set<String>()

        for (category, share) in zip(categories, shares) where share > 0 {
            let candidates = candidates(in: pool, category: category,
                                        excluding: usedTexts, seed: seed)
            for declaration in candidates.prefix(share) {
                picked.append((declaration, category))
                usedTexts.insert(declaration.text)
            }
        }

        // Top up from the lead category if a secondary was thin.
        if picked.count < Enforcement.length {
            let filler = candidates(in: pool, category: lead,
                                    excluding: usedTexts, seed: seed)
            for declaration in filler.prefix(Enforcement.length - picked.count) {
                picked.append((declaration, lead))
                usedTexts.insert(declaration.text)
            }
        }

        guard picked.count == Enforcement.length else { return nil }

        let ordered = interleave(picked, leadCategory: lead)
        let days = ordered.enumerated().map { index, entry -> EnforcementDay in
            let (declaration, category) = entry
            let audio = audioFor(category)
            return EnforcementDay(
                dayNumber: index + 1,
                anchorText: declaration.text,
                anchorVerse: declaration.bibleVerseText ?? "",
                anchorBook: declaration.book ?? "",
                anchorTranslation: "",
                audioId: audio.audioId,
                audioTitle: audio.title,
                audioMinutes: audio.durationMinutes
            )
        }

        return Enforcement(
            id: "assembled_" + categories.map(\.rawValue).joined(separator: "_"),
            title: "Enforcing " + lead.name,
            tagline: "Seven days standing on what Jesus already won.",
            theme: lead.rawValue,
            days: days
        )
    }

    // MARK: - Internals

    /// Split out and explicitly typed: as one chained filter/filter/sorted the
    /// Swift type-checker times out on it.
    private static func candidates(in pool: [Declaration],
                                   category: DeclarationCategory,
                                   excluding usedTexts: Set<String>,
                                   seed: String) -> [Declaration] {
        var matching: [Declaration] = []
        for declaration in pool {
            guard declaration.category == category else { continue }
            guard declaration.contentType == .affirmation else { continue }
            guard !usedTexts.contains(declaration.text) else { continue }
            matching.append(declaration)
        }
        return matching.sorted { a, b in
            stableHash(seed + a.text) < stableHash(seed + b.text)
        }
    }

    /// Day allocation per category count. The lead always holds the majority.
    static func dayShares(for categoryCount: Int) -> [Int] {
        switch max(categoryCount, 1) {
        case 1:  return [7]
        case 2:  return [4, 3]
        default: return [3, 2, 2]   // never split finer than three themes
        }
    }

    /// Spreads the secondary days through the week instead of stacking them at
    /// the end, but opens and closes on the lead category so the arc still
    /// belongs to the thing they actually named.
    private static func interleave(_ picked: [(Declaration, DeclarationCategory)],
                                   leadCategory: DeclarationCategory) -> [(Declaration, DeclarationCategory)] {
        var lead = picked.filter { $0.1 == leadCategory }
        var rest = picked.filter { $0.1 != leadCategory }
        guard !rest.isEmpty else { return lead }

        var result: [(Declaration, DeclarationCategory)] = []
        if !lead.isEmpty { result.append(lead.removeFirst()) }   // open on the lead

        // Alternate, favouring the lead so it never disappears for long.
        while !lead.isEmpty || !rest.isEmpty {
            if !lead.isEmpty { result.append(lead.removeFirst()) }
            if !rest.isEmpty { result.append(rest.removeFirst()) }
        }
        return result
    }

    /// The audio that speaks to this category, falling back to Psalm 91 — free,
    /// universal, and always present in the catalog.
    private static func audioFor(_ category: DeclarationCategory) -> FoundationAudio {
        FoundationAudioPlan.categoryAudio[category.rawValue.lowercased()]
            ?? FoundationAudioPlan.psalm91
    }

    /// FNV-1a. Swift's `hashValue` is seeded per process, so it would reshuffle
    /// the campaign on every launch — day 3 would be a different line each time
    /// the user opened the app.
    ///
    /// Callers must hash `seed + text`, never `text + seed`. FNV-1a walks bytes
    /// left to right, so a seed appended at the end barely perturbs the ordering:
    /// two seeds differing only in their last character produced byte-identical
    /// campaigns, which silently defeated per-user variation. Seeding the front
    /// changes the running state before any content byte is mixed in.
    static func stableHash(_ string: String) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return hash
    }
}

private extension Array where Element == DeclarationCategory {
    /// Order-preserving de-duplication.
    func reduced() -> [DeclarationCategory] {
        var seen = Set<DeclarationCategory>()
        return filter { seen.insert($0).inserted }
    }
}
