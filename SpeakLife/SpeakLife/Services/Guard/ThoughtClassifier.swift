//
//  ThoughtClassifier.swift
//  SpeakLife
//
//  The escape hatch's brain: turns "something else is on my mind" into a
//  category and a declaration to speak.
//
//  **There are two paths, and they differ in whether the words leave the
//  phone.**
//
//  Free: everything here runs on device, exactly as it always has. Keyword
//  match, terrain map, a counter drawn from the bundled bank. Nothing is sent
//  anywhere.
//
//  Premium: the words are sent to Claude, which writes a counter-declaration
//  for the actual thought instead of picking the nearest one from a fixed
//  bank. See `GuardThoughtWriter`.
//
//  This file used to say a network call may never be added to it, and that was
//  the right rule while the promise on screen was "it stays on this phone".
//  The promise moved, so the rule moved with it — and the copy moved FIRST.
//  `AskForThoughtView.privacyLine` now says which of the two is happening, and
//  it is keyed off the same flag this class is. If a future change makes the
//  network path run without that line changing, the app is lying to someone in
//  the worst moment it has.
//
//  What did not move: the raw sentence is still never stored, never synced,
//  never written to the log, and never attached to an analytics event. It
//  exists for the length of one call. `CapturedThought` still has no text
//  field. Only the matched terrain is ever recorded.
//
//  And crisis screening still runs locally, first, before any network call can
//  be made. That ordering is not an optimisation.
//
//  The classifier reuses `MatchRule.defaults` — the same keyword table the
//  personal-declaration matcher runs on — rather than growing a second, rival
//  list of keywords that would drift out of agreement with it. It maps the
//  resulting `DeclarationCategory` onto one of the nine Guard terrains.
//
//  Crisis routing runs FIRST, before any matching, via the shared
//  `SituationScreen`. Same screen, same words, same support address as the
//  campaign card and the personal-declaration flow, so the app cannot say two
//  different things in the worst moment it has.
//

import Foundation

/// What the escape hatch decided to do with what someone typed.
enum ThoughtClassification: Equatable {
    /// A category was found, with a declaration to speak against it.
    case matched(ThoughtCategory, IncomingThought, confidence: Confidence)
    /// Someone said they want to end their life. The drill does not continue.
    /// There is no scripture argument here and no campaign — the honest answer
    /// is a person.
    case reachOut

    enum Confidence: String, Equatable {
        /// Claude read the thought and wrote a counter for it.
        case written
        /// A keyword rule fired and it mapped cleanly onto a terrain.
        case high
        /// Nothing matched, or the match didn't map. A general identity
        /// declaration is served — never an error state, because someone who
        /// just typed a real thought must not be handed a dead end.
        case low
    }
}

/// Classifies free text into one of the nine terrains, entirely on device.
struct ThoughtClassifier {

    private let matcher: KeywordDeclarationMatcher
    private let bank: [IncomingThought]
    private let writer: GuardThoughtWriter

    init(bank: [IncomingThought],
         matcher: KeywordDeclarationMatcher = KeywordDeclarationMatcher(),
         writer: GuardThoughtWriter = GuardThoughtWriter()) {
        self.bank = bank
        self.matcher = matcher
        self.writer = writer
    }

    /// Whether the premium path can actually run right now.
    ///
    /// Premium alone is not enough — the key arrives from Remote Config at
    /// launch and can be empty. The ASK screen reads this to decide which
    /// privacy line to show, so it must answer "will the words be sent", not
    /// "is this user entitled to have them sent".
    func sendsThoughtOffDevice(isPremium: Bool) -> Bool {
        isPremium && writer.isConfigured
    }

    /// The premium path: Claude reads the thought and writes the counter.
    ///
    /// - Parameter isPremium: false runs the on-device path unchanged.
    ///
    /// Crisis screening happens here, locally, BEFORE the request. It is the
    /// first thing in the function for the same reason it always was: no
    /// matching, no quota, no paywall, and now no network call either, may run
    /// ahead of it.
    func classify(_ text: String, isPremium: Bool) async -> ThoughtClassification {
        if case .reachOut = SituationScreen.screen(text) {
            return .reachOut
        }

        guard sendsThoughtOffDevice(isPremium: isPremium) else {
            return classify(text)
        }

        do {
            let written = try await writer.write(thought: text)
            // Generated lines are the only declarations in the app that have not
            // been through review. Every line in `declarationsv10.json` was
            // checked against the house rules by a person; this one was checked
            // by a prompt that describes them and verifies nothing. The prompt
            // is not a guarantee, so the output is inspected before it reaches
            // someone's mouth, and a line that breaks the rules loses to the
            // reviewed bank.
            guard Self.followsHouseRules(written.declaration) else {
                AnalyticsService.shared.track("guard_written_rejected",
                                              parameters: ["terrain": written.category.rawValue])
                return classify(text)
            }
            return .matched(written.category,
                            IncomingThought(
                                id: CapturedThought.escapeHatchDeclarationId,
                                text: text,
                                category: written.category,
                                intensity: 1,
                                counterDeclaration: written.declaration,
                                verseText: written.verseText,
                                book: written.book,
                                declarationCategory: written.category.rawValue
                            ),
                            confidence: .written)
        } catch GuardWriterError.declined {
            // A refusal is a verdict, not a failure, so it must not fall
            // through to the keyword matcher — that would answer "I won't write
            // this" with a written declaration. The local path is what a free
            // user gets and it is grounded in the reviewed bank, so it is the
            // honest floor here: their own standing, not the thing declined.
            return classifyDeclined(text)
        } catch {
            // Offline, no key, a timeout, a malformed answer. Never a dead end.
            return classify(text)
        }
    }

    /// The house rules from `CLAUDE.md`, applied to a generated line.
    ///
    /// Deliberately only the rules a machine can actually check. Whether a line
    /// is *moving* is not testable and is not attempted; what is testable is
    /// whether it is first person, present, short, dash-free, and whether it
    /// names the thing it is supposed to be displacing. Rule 12 is the one worth
    /// the most here — "I am not afraid of this sickness" is a perfectly fluent
    /// sentence that breaks the single most important rule the feature has.
    static func followsHouseRules(_ declaration: String) -> Bool {
        let trimmed = declaration.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        // Rule 7: no dashes.
        guard !trimmed.contains("—"), !trimmed.contains("–") else { return false }

        let words = trimmed.lowercased()
            .split(whereSeparator: { !$0.isLetter && $0 != "'" })
            .map(String.init)

        // Rule 13: one sentence, 10 to 18 words. Allowed a little slack either
        // side; a hard 18 would reject good lines over a conjunction.
        guard words.count >= 5, words.count <= 26 else { return false }
        let sentences = trimmed.split(whereSeparator: { ".!?".contains($0) })
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard sentences.count <= 2 else { return false }

        // Rule 1: first person.
        let firstPerson: Set<String> = ["i", "i'm", "i've", "i'll", "my", "me", "mine", "myself"]
        guard !Set(words).isDisjoint(with: firstPerson) else { return false }

        // Rule 6: no hedging.
        let hedges: Set<String> = ["maybe", "hope", "hoping", "try", "trying", "might", "someday", "wish"]
        guard Set(words).isDisjoint(with: hedges) else { return false }

        // Rule 12: never name the low thing. A declaration does not mention the
        // fear, the sickness, the lack or the shame, even to overrule it.
        let lowThings: Set<String> = [
            "afraid", "fear", "fears", "fearful", "anxious", "anxiety", "worry",
            "worried", "panic", "scared", "sick", "sickness", "illness", "ill",
            "disease", "cancer", "covid", "virus", "infection", "pain", "dying",
            "shame", "ashamed", "guilt", "guilty", "condemned", "unworthy",
            "worthless", "failure", "broke", "poverty", "debt", "lack",
            "lonely", "alone", "abandoned", "rejected", "lust", "porn",
            "addiction", "depressed", "depression", "hopeless"
        ]
        guard Set(words).isDisjoint(with: lowThings) else { return false }

        return true
    }

    /// A declined request still ends in something true about the speaker, drawn
    /// from the reviewed bank rather than generated.
    private func classifyDeclined(_ text: String) -> ThoughtClassification {
        let category = ThoughtCategory.inadequacy
        let thought = counter(for: category, matching: text) ?? Self.lastResort
        return .matched(category, thought, confidence: .low)
    }

    /// - Parameter text: the user's own words. Never stored, never synced,
    ///   never logged — it exists for the length of this call.
    func classify(_ text: String) -> ThoughtClassification {
        // Safety first, and unconditionally. Placing this above every other
        // branch is the whole point: no matching, no quota check, and no
        // premium check can run ahead of it and route someone in crisis into a
        // drill.
        if case .reachOut = SituationScreen.screen(text) {
            return .reachOut
        }

        // A redirect verdict (someone else's marriage, harm to another) is NOT
        // treated as a crisis and is not corrected here either. This screen is
        // about a thought coming at them, not a request we are agreeing to
        // build a week on — so it falls through to matching and they get a
        // declaration about their own standing, which is the right answer.

        // The nine-terrain lexicon leads, because it answers the question this
        // feature actually asks. `MatchRule.defaults` sorts prayer needs into 42
        // DeclarationCategory values and gets mapped down; it stays as a second
        // opinion for sentences the lexicon does not recognise, since its
        // vocabulary is large and there is no reason to throw it away.
        if let hit = TerrainLexicon.terrain(for: text),
           let thought = counter(for: hit.category, matching: text) {
            return .matched(hit.category, thought, confidence: .high)
        }

        let matched = matcher.matchAll(input: text)
            .compactMap(ThoughtCategory.from)
            .first

        if let category = matched, let thought = counter(for: category, matching: text) {
            return .matched(category, thought, confidence: .high)
        }

        // Low confidence: a general identity declaration, which is true of them
        // whatever the thought was. `.inadequacy` is the identity terrain, so
        // the fallback stays inside the same nine and needs no special case
        // downstream.
        let fallbackCategory = ThoughtCategory.inadequacy
        let thought = counter(for: fallbackCategory, matching: text) ?? Self.lastResort
        return .matched(fallbackCategory, thought, confidence: .low)
    }

    /// Picks the line in that terrain that best answers what they typed.
    ///
    /// Intensity 1 still leads, because someone naming a live thought already
    /// has the weight and the counter should not add to it. Within that pool
    /// the choice is now RELEVANCE, not a hash.
    ///
    /// The hash was the second half of the "Covid" bug and the half that
    /// survived fixing the terrain. `pool[stableHash(text) % pool.count]` is
    /// stable and deterministic, which is why it looked reasonable — but
    /// nothing about the sentence influenced it. Land in the right terrain and
    /// you still got an arbitrary line from it. Someone typing about their body
    /// could draw a declaration about strength for a task.
    ///
    /// Scoring is word overlap against everything the entry carries: the lie it
    /// was written for, the declaration, and the verse. Ties still break on id,
    /// so two devices handed the same sentence agree, and a re-type never
    /// shuffles the line.
    private func counter(for category: ThoughtCategory, matching text: String) -> IncomingThought? {
        let inCategory = bank.filter { $0.category == category }
        guard !inCategory.isEmpty else { return nil }
        let gentle = inCategory.filter { $0.intensity == 1 }
        let pool = gentle.isEmpty ? inCategory : gentle

        // Bank order is curated, so the first entry in a terrain is its flagship
        // line — healing for sickness, provision for lack, wholeness for
        // identity. That is the right answer when the sentence gives us nothing
        // better to go on, and it is a far better default than a hash.
        let curatedDefault = pool[0]

        let typed = Self.meaningfulWords(text)
        guard !typed.isEmpty else { return curatedDefault }

        // Rarity weighting, and it is load-bearing rather than a refinement.
        //
        // Plain overlap counting picked "God gives me strength and fills me with
        // fresh power" for "Covid is coming back", because the lie that entry
        // answers is "Your strength is not coming back" — two incidental common
        // words, "coming" and "back", outscoring every line actually about a
        // body. Weighting each match by 1/frequency makes a word that appears
        // all over the bank nearly worthless and a rare one decisive.
        var frequency: [String: Int] = [:]
        for entry in bank {
            for word in Self.meaningfulWords(
                "\(entry.text) \(entry.counterDeclaration) \(entry.verseText)"
            ) {
                frequency[word, default: 0] += 1
            }
        }

        var best = curatedDefault
        var bestScore = 0.0
        for entry in pool {
            let haystack = Self.meaningfulWords(
                "\(entry.text) \(entry.counterDeclaration) \(entry.verseText)"
            )
            var score = 0.0
            for word in typed.intersection(haystack) {
                score += 1.0 / Double(frequency[word] ?? 1)
            }
            if score > bestScore {
                bestScore = score
                best = entry
            }
        }

        // Below the floor the "match" is noise. One distinctive word clears it;
        // a pair of words that show up everywhere does not.
        return bestScore >= Self.relevanceFloor ? best : curatedDefault
    }

    /// Tuned against the shipped bank: a single word unique to one entry scores
    /// 1.0, while "coming" plus "back" — the pair that produced the wrong line
    /// for a thought about illness — lands near 0.5.
    private static let relevanceFloor = 0.7

    /// Words worth scoring on. Drops the function words that appear in every
    /// sentence and would otherwise let "I am the of" score against everything.
    private static func meaningfulWords(_ text: String) -> Set<String> {
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

    /// Used only when the bank failed to load at all. Sourced verbatim from
    /// `declarationsv10.json` (identity / 2 Corinthians 5:17) so even the
    /// degenerate path speaks a reviewed line.
    static let lastResort = IncomingThought(
        id: CapturedThought.escapeHatchDeclarationId,
        text: "",
        category: .inadequacy,
        intensity: 1,
        counterDeclaration: "I am a new creation in Christ. The old is gone for good.",
        verseText: "Therefore, if anyone is in Christ, the new creation has come: The old has gone, the new is here!",
        book: "2 Corinthians 5:17",
        declarationCategory: "identity"
    )

}

// `stableHash` lived here and is gone with the hash-based pick it existed for.
// It solved a real problem — `String.hashValue` is seeded per process, so the
// same sentence chose a different line on the next launch — but the answer to
// "which line do we serve" was never supposed to be a hash of the input. It is
// relevance now, with the curated first entry as the floor.
