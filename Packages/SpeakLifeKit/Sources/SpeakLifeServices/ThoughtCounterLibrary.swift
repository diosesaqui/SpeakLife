//
//  ThoughtCounterLibrary.swift
//  SpeakLifeServices
//
//  Finds the reviewed declaration that speaks to the exact thing the user just
//  named, out of the whole shipped library rather than the 135-entry thought
//  bank.
//
//  **Why this exists.** The escape hatch used to answer every typed thought out
//  of `thoughts.json`, and the picker only ever saw the intensity-1 slice — five
//  lines per terrain, forty-five in all. Nine terrains is the right shape for
//  "where did I take ground", and the wrong shape for "what am I up against".
//  Someone typing that they have been trying for a baby for four years landed on
//  "I am complete in Christ", while twenty-five reviewed FERTILITY declarations
//  sat in the library unreachable. Eighty-four REST lines, forty-five PARENTING,
//  twenty-five DEBT, twenty-five GRIEF, twenty-five DIVORCE, same story.
//
//  So the counter is drawn from `declarationsv10.json` — every line of which has
//  already passed the fifteen rules in CLAUDE.md — and the terrain is derived
//  from the line that was chosen, instead of the choice being confined to the
//  terrain.
//
//  **Category is the signal, not word overlap, and that is by design.** Rule 12
//  says a declaration never names the low thing. The user's sentence is almost
//  entirely low things. So the words they type mostly CANNOT appear in the line
//  that answers them, and scoring on overlap alone is close to noise once you
//  are inside the right category. Overlap still runs, because when it does fire
//  ("I sow with tears, and I reap with songs of joy" against a sentence about
//  crying) it is decisive. Below the floor, the category decides and the
//  shortest line in it wins — rule 13, the most compressed line in the exact
//  domain.
//
//  Nothing here goes near the network and nothing is stored. It is the path a
//  user gets when they are offline, when the key is missing, when Claude
//  declines, and when a written line fails the house rules — so it has to be
//  good on its own.
//

import Foundation
import SpeakLifeCore

public enum ThoughtCounterLibrary {

    /// The reviewed line that answers what they typed, or nil when the library
    /// cannot serve this sentence at all — in which case the caller falls back
    /// to the thought bank, which is never empty in a shipped build.
    ///
    /// - Parameters:
    ///   - text: the user's own words. Read, scored, and dropped. Never stored,
    ///     never logged, never sent anywhere from here.
    ///   - library: `declarationsv10.json`, as the app has it in memory.
    public static func counter(for text: String, in library: [Declaration]) -> IncomingThought? {
        let pool = speakable(library)
        guard !pool.isEmpty else { return nil }

        let ranked = categories(for: text)
        guard !ranked.isEmpty else { return nil }

        var byCategory: [DeclarationCategory: [Declaration]] = [:]
        for declaration in pool {
            byCategory[declaration.category, default: []].append(declaration)
        }

        let typed = meaningfulWords(text)
        let frequency = wordFrequency(in: pool)

        var best: (declaration: Declaration, score: Double)?
        // Only the strongest few. Past that the "category" is a stray keyword,
        // and a fifth-place category answering someone's sentence is how the
        // old picker sent a thought about a marriage to a line about a body.
        for (rank, category) in ranked.prefix(Self.categoriesConsidered).enumerated() {
            let weight = 1.0 - (Double(rank) * 0.15)
            for declaration in byCategory[category] ?? [] {
                let score = relevance(of: declaration, to: typed, frequency: frequency) * weight
                guard score > (best?.score ?? 0) else { continue }
                best = (declaration, score)
            }
        }

        if let best, best.score >= Self.relevanceFloor {
            return thought(from: best.declaration, text: text)
        }

        // Below the floor the overlap is noise, and the category is the real
        // answer. The shortest line in it goes: same domain, fewest words,
        // easiest to say out loud with the whole chest.
        guard let shortest = shortestLine(in: ranked, of: byCategory) else { return nil }
        return thought(from: shortest, text: text)
    }

    /// The shortest reviewed line in a terrain, chosen without reading the
    /// sentence at all.
    ///
    /// For the one caller that must NOT answer what was typed: a thought Claude
    /// declined to write for. It still ends in a true word about the speaker,
    /// and this is how that word stays a reviewed one.
    public static func counter(inTerrain terrain: ThoughtCategory,
                               in library: [Declaration]) -> IncomingThought? {
        let pool = speakable(library)
        guard !pool.isEmpty else { return nil }
        var byCategory: [DeclarationCategory: [Declaration]] = [:]
        for declaration in pool {
            byCategory[declaration.category, default: []].append(declaration)
        }
        guard let shortest = shortestLine(in: terrain.declarationCategories, of: byCategory) else {
            return nil
        }
        return thought(from: shortest, text: "")
    }

    private static func shortestLine(in categories: [DeclarationCategory],
                                     of byCategory: [DeclarationCategory: [Declaration]]) -> Declaration? {
        for category in categories {
            guard let candidates = byCategory[category], !candidates.isEmpty else { continue }
            return candidates.min {
                let left = wordCount($0.text), right = wordCount($1.text)
                // Ties break on the text so two devices handed the same
                // sentence speak the same line, and a re-type never shuffles it.
                return left == right ? $0.text < $1.text : left < right
            }
        }
        return nil
    }

    /// Every category the sentence touches, strongest first: the 42-rule table
    /// scored properly, then the nine-terrain lexicon's own answer folded in.
    ///
    /// Both tables score in the same unit — matched keyword length — so they can
    /// be compared directly rather than one being forced to win by position.
    /// That comparison is load-bearing. "The doctor says my blood pressure is
    /// dangerous" fires `godsprotection` on "danger" in the rule table and
    /// `sickness` on "blood pressure" plus "doctor" in the lexicon; the longer,
    /// more specific match is the honest one, and it is the one that wins.
    static func categories(for text: String) -> [DeclarationCategory] {
        var scores: [DeclarationCategory: Double] = [:]
        for hit in KeywordCategoryMatcher.ranked(text) {
            scores[hit.category] = max(scores[hit.category] ?? 0, Double(hit.score))
        }

        if let terrain = TerrainLexicon.terrain(for: text) {
            // Discounted against a direct rule hit, and stepped down across the
            // terrain's own categories, so the lexicon breaks ties and rescues
            // sentences the rule table never learned without overruling a rule
            // that matched the sentence outright.
            for (rank, category) in terrain.category.declarationCategories.enumerated() {
                let score = Double(terrain.score) * (0.9 - Double(rank) * 0.1)
                scores[category] = max(scores[category] ?? 0, score)
            }
        }

        return scores
            .sorted {
                if $0.value != $1.value { return $0.value > $1.value }
                return $0.key.rawValue < $1.key.rawValue
            }
            .map { $0.key }
    }

    // MARK: - Shaping

    private static func thought(from declaration: Declaration, text: String) -> IncomingThought {
        IncomingThought(
            id: CapturedThought.escapeHatchDeclarationId,
            text: text,
            category: ThoughtCategory.from(declaration.category) ?? .inadequacy,
            intensity: 1,
            counterDeclaration: declaration.text,
            verseText: declaration.bibleVerseText ?? "",
            book: declaration.book ?? "",
            declarationCategory: declaration.category.rawValue
        )
    }

    /// What may be spoken out loud in this drill.
    ///
    /// Four exclusions, each for its own reason:
    ///
    /// - **Book categories** (psalms, john, romans…) are read-through-a-book
    ///   content, written to the older two-sentence expository standard. CLAUDE.md
    ///   rule 13 says so explicitly and says not to "fix" them. They are not
    ///   lines someone speaks over their marriage at 2am.
    /// - **Anything the user wrote themselves** — `myOwn`, `favorites`, journal
    ///   entries. The app's in-memory pool carries them, and they have not been
    ///   through review. The whole reason this draws from the library is that
    ///   every line in it was checked by a person.
    /// - **Lines with no first person, or too long to say in one breath.** The
    ///   drill ends in a mouth, not on a page.
    /// - **Lines with no verse behind them.** The REPLACE screen puts the
    ///   scripture under the declaration, and a hundred-odd entries in the
    ///   library carry no reference. An empty half-card is not what someone
    ///   gets for naming the hardest thing in their week.
    static func speakable(_ library: [Declaration]) -> [Declaration] {
        library.filter { declaration in
            guard declaration.contentType == .affirmation else { return false }
            guard let verse = declaration.bibleVerseText, !verse.isEmpty,
                  let book = declaration.book, !book.isEmpty else { return false }
            guard !excludedCategories.contains(declaration.category) else { return false }
            guard EnforcementAssembler.isCampaignable(declaration.category) else { return false }
            let text = declaration.text
            guard !text.contains("—"), !text.contains("–") else { return false }
            let words = text.lowercased()
                .split(whereSeparator: { !$0.isLetter && $0 != "'" })
                .map(String.init)
            guard words.count >= 4, words.count <= 30 else { return false }
            return !Set(words).isDisjoint(with: firstPerson)
        }
    }

    private static let excludedCategories: Set<DeclarationCategory> = [
        .myOwn, .favorites, .general, .speaklife
    ]

    private static let firstPerson: Set<String> = ["i", "i'm", "i've", "i'll", "my", "me", "mine", "myself"]

    // MARK: - Relevance

    /// Rarity-weighted word overlap, carried over from the bank picker it
    /// replaces and for the same reason: plain counting lets a word that appears
    /// in half the library outscore the one word that actually names the
    /// situation.
    private static func relevance(of declaration: Declaration,
                                  to typed: Set<String>,
                                  frequency: [String: Int]) -> Double {
        guard !typed.isEmpty else { return 0 }
        let haystack = meaningfulWords("\(declaration.text) \(declaration.bibleVerseText ?? "")")
        return typed.intersection(haystack).reduce(0.0) { total, word in
            total + 1.0 / Double(frequency[word] ?? 1)
        }
    }

    private static func wordFrequency(in pool: [Declaration]) -> [String: Int] {
        var frequency: [String: Int] = [:]
        for declaration in pool {
            for word in meaningfulWords("\(declaration.text) \(declaration.bibleVerseText ?? "")") {
                frequency[word, default: 0] += 1
            }
        }
        return frequency
    }

    private static func wordCount(_ text: String) -> Int {
        text.split(whereSeparator: { !$0.isLetter && $0 != "'" }).count
    }

    /// Words worth scoring on. Drops the function words that appear in every
    /// sentence, and the names of God, which appear in nearly every declaration
    /// and would otherwise score against the whole library at once.
    static func meaningfulWords(_ text: String) -> Set<String> {
        let stop: Set<String> = [
            "i", "me", "my", "mine", "myself", "im", "i'm", "a", "an", "the",
            "is", "am", "are", "was", "were", "be", "been", "being", "it", "its",
            "this", "that", "and", "but", "or", "not", "no", "of", "to", "in",
            "on", "for", "with", "about", "at", "as", "so", "if", "then", "than",
            "do", "does", "did", "have", "has", "had", "will", "would", "can",
            "could", "should", "he", "his", "him", "she", "her", "they", "them",
            "you", "your", "we", "us", "our", "god", "lord", "jesus", "christ"
        ]
        return Set(
            text.lowercased()
                .split(whereSeparator: { !$0.isLetter && $0 != "'" })
                .map(String.init)
                .filter { $0.count > 2 && !stop.contains($0) }
        )
    }

    /// How many ranked categories get to offer a line.
    private static let categoriesConsidered = 4

    /// Tuned against the shipped library: one distinctive shared word clears it,
    /// a pair of words that turn up everywhere does not.
    private static let relevanceFloor = 0.35
}
