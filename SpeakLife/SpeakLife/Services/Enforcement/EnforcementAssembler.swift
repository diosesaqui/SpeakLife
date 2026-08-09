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

    /// Where to draw from when the matched category has no declarations of its
    /// own. Seventeen of the categories the matcher can return — `business`,
    /// `grief`, `debt`, `mentalHealth` and the rest — were added as routes
    /// without content behind them, so a perfectly clear sentence like "I want
    /// to start a business" used to dead-end on "couldn't build a week from
    /// that". These are ordered nearest-truth-first: the week still gets built
    /// out of lines that speak to the same thing, and the campaign keeps the
    /// name of what the person actually said.
    ///
    /// Book categories are deliberately absent: `isCampaignable` already keeps
    /// them out of matching, so an entry for them would never be read.
    static let contentFallbacks: [DeclarationCategory: [DeclarationCategory]] = [
        // Vision and calling — someone with no storm, only something they're
        // believing God for.
        .business:        [.destiny, .work, .wealth, .favor],
        .newSeason:       [.destiny, .hope, .identity],
        .education:       [.wisdom, .destiny, .favor],
        .confidence:      [.identity, .faith, .fear],
        .spiritualGrowth: [.obedience, .identity, .grace],

        // Provision.
        .debt:            [.wealth, .favor, .hardtimes],
        .housing:         [.wealth, .godsprotection, .favor],

        // Loss and repair.
        .grief:           [.hope, .innerHealing, .hardtimes],
        .divorce:         [.innerHealing, .hope, .identity],
        .forgiveness:     [.grace, .innerHealing, .love],
        .anger:           [.rest, .innerHealing, .obedience],

        // Body and mind.
        .wellness:        [.health, .rest, .identity],
        .mentalHealth:    [.innerHealing, .rest, .anxiety],

        // People.
        .relationship:    [.love, .marriage, .purity],
        .singleParent:    [.parenting, .godsprotection, .favor],
        .salvation:       [.faith, .love, .miracles],
        .fertility:       [.miracles, .hope, .faith]
    ]

    /// The last resort, drawn on only when everything above is somehow empty.
    /// Each of these carries well over seven referenced declarations in the
    /// shipped pool, so the chain cannot run dry.
    static let universalFallback: [DeclarationCategory] = [.faith, .hardtimes, .godsprotection, .hope]

    /// Every category worth drawing from for this match, in priority order:
    /// what they matched, then the nearest siblings of each, then the backstop.
    static func fallbackChain(for categories: [DeclarationCategory]) -> [DeclarationCategory] {
        var chain = categories
        for category in categories {
            chain += contentFallbacks[category] ?? []
        }
        chain += universalFallback
        return chain.filter(isCampaignable).reduced()
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
    /// - Returns: nil only when the pool itself is empty. Any category the
    ///   matcher can return reaches seven days via `fallbackChain`.
    static func assemble(primary: DeclarationCategory,
                         secondaries: [DeclarationCategory] = [],
                         pool: [Declaration],
                         seed: String) -> Enforcement? {

        let categories = ([primary] + secondaries)
            .filter(isCampaignable)
            .reduced()

        guard let named = categories.first else { return nil }

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

        // Top up: the matched categories first, then their nearest siblings,
        // then the backstop. This is what makes the week unfailable — a matched
        // category with no content of its own still fills seven days.
        for source in fallbackChain(for: categories) where picked.count < Enforcement.length {
            let needed = Enforcement.length - picked.count
            // A matched category can carry the whole remainder: it is what they
            // said. A substitute is capped so an empty match blends its siblings
            // rather than becoming seven days of one borrowed theme.
            let take = categories.contains(source) ? needed : min(needed, 3)
            let filler = candidates(in: pool, category: source,
                                    excluding: usedTexts, seed: seed)
            for declaration in filler.prefix(take) {
                picked.append((declaration, source))
                usedTexts.insert(declaration.text)
            }
        }

        guard picked.count == Enforcement.length else { return nil }

        // Open and close on what they actually named, unless the named category
        // contributed nothing — then the arc belongs to whatever carried it.
        let lead = picked.contains { $0.1 == named } ? named : picked[0].1
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

        // Named after what they said, not after where the lines came from.
        // Someone who typed "I want to start a business" gets a week called
        // Business even when it is carried by destiny and work.
        return Enforcement(
            id: "assembled_" + categories.map(\.rawValue).joined(separator: "_"),
            title: "Enforcing " + named.name,
            tagline: "Seven days standing on what Jesus already won.",
            theme: named.rawValue,
            days: days
        )
    }

    /// Builds a campaign from an explicit, already-ordered set of declarations —
    /// the path used when Claude has curated the week from the user's own words.
    /// The declarations still come from the reviewed pool; only the choosing and
    /// the ordering came from the model.
    static func assemble(curated: [Declaration],
                         primary: DeclarationCategory) -> Enforcement? {
        guard curated.count == Enforcement.length else { return nil }
        let days = curated.enumerated().map { index, declaration -> EnforcementDay in
            let audio = audioFor(declaration.category)
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
            id: "curated_" + primary.rawValue,
            title: "Enforcing " + primary.name,
            tagline: "Seven days built around what you're walking through.",
            theme: primary.rawValue,
            days: days
        )
    }

    /// The reviewed declarations worth putting in front of the curator: right
    /// categories, affirmations only, and each carrying a scripture reference.
    ///
    /// Walks the same fallback chain the assembler does, so a matched category
    /// with no content still gives Claude a real shortlist to choose from
    /// instead of an empty one that silently drops the curation step.
    static func candidates(for categories: [DeclarationCategory],
                           in pool: [Declaration],
                           seed: String) -> [Declaration] {
        var result: [Declaration] = []
        var used = Set<String>()
        for category in fallbackChain(for: categories) {
            result += candidates(in: pool, category: category, excluding: used, seed: seed)
            used.formUnion(result.map(\.text))
            // Enough to choose well. Walking the whole chain would bury the
            // matched category's own lines under four buckets of filler.
            if result.count >= EnforcementCurator.candidateLimit { break }
        }
        return result
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
            // ~98 declarations in the pool carry no scripture reference. The card
            // shows the reference under the line and the push appends it, so an
            // empty one leaves a blank row and a push trailing in " ~ ".
            // Every offered category has well over seven referenced declarations,
            // so requiring one costs no coverage.
            guard let book = declaration.book, !book.isEmpty else { continue }
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
