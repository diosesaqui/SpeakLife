//
//  ThoughtClassifier.swift
//  SpeakLifeServices
//
//  The escape hatch's brain: turns "something else is on my mind" into a
//  category and a declaration to speak.
//
//  **Whatever someone is up against, the line they speak has to be about that
//  exact thing.** That is the whole job of this file, and everything below is
//  arranged around it.
//
//  First path — written. The words go to Claude, which writes the counter for
//  the thought they actually typed. This runs for EVERY user, not only premium:
//  the moment someone names what they are carrying is the moment the app either
//  answers it or hands them something adjacent, and "adjacent" is what this
//  change exists to end. See `GuardThoughtWriter`. Premium still buys what it
//  always bought — unlimited extra reps and the full bank — it just no longer
//  buys being answered accurately.
//
//  Second path — the reviewed library. Offline, no key, a refusal, a generated
//  line that broke the house rules: the counter is chosen out of every reviewed
//  declaration the app ships, by what the sentence is about. See
//  `ThoughtCounterLibrary`.
//
//  Third path — the bank. Only when the library is empty or cannot place the
//  sentence at all. Forty-five gentle entries across nine terrains, which is
//  where this feature started and is no longer where it stops.
//
//  This file used to say a network call may never be added to it, and that was
//  the right rule while the promise on screen was "it stays on this phone".
//  The promise moved, so the rule moved with it — and the copy moved FIRST.
//  `AskForThoughtView.privacyLine` says which of the two is happening, and it
//  is keyed off the same call this class branches on. If a future change makes
//  the network path run without that line changing, the app is lying to someone
//  in the worst moment it has.
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
//  list of keywords that would drift out of agreement with it.
//
//  Crisis routing runs FIRST, before any matching, via the shared
//  `SituationScreen`. Same screen, same words, same support address as the
//  campaign card and the personal-declaration flow, so the app cannot say two
//  different things in the worst moment it has.
//

import Foundation
import SpeakLifeCore

/// The keyword matcher the classifier consults, exposed as a closure so
/// `ThoughtClassifier` does not have to move `KeywordDeclarationMatcher` and
/// its `DeclarationContent` / `MatchRule.defaults` neighbourhood into the
/// package. The app installs the real matcher at startup; tests inject their
/// own or pass one straight into the initializer.
public typealias ThoughtCategoryMatcher = (String) -> [DeclarationCategory]

public enum ThoughtMatcherProvider {
    /// Defaults to `KeywordCategoryMatcher.matchAll` — the same keyword
    /// table the app's `KeywordDeclarationMatcher` uses, sitting in
    /// SpeakLifeCore so the package builds and tests it directly. The
    /// app can still swap this out at startup if a future matcher
    /// implementation lives elsewhere.
    public static var matchAll: ThoughtCategoryMatcher = { input in
        KeywordCategoryMatcher.matchAll(input)
    }
}

/// What the escape hatch decided to do with what someone typed.
public enum ThoughtClassification: Equatable {
    /// A category was found, with a declaration to speak against it.
    case matched(ThoughtCategory, IncomingThought, confidence: Confidence)
    /// Someone said they want to end their life. The drill does not continue.
    /// There is no scripture argument here and no campaign — the honest answer
    /// is a person.
    case reachOut

    public enum Confidence: String, Equatable {
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

/// Turns what someone typed into the line they will speak against it: written
/// for that exact thought when the writer can run, chosen out of the reviewed
/// library when it cannot, and drawn from the bundled bank when there is no
/// library in memory.
public struct ThoughtClassifier {

    private let matchAll: ThoughtCategoryMatcher
    private let bank: [IncomingThought]
    private let library: [Declaration]
    private let writer: GuardThoughtWriter

    /// - Parameter library: the reviewed declaration pool, passed in by the
    ///   view that presents the drill. It lives app-side (the app refreshes it
    ///   from the network and merges it with what shipped in the bundle), so
    ///   the package takes it rather than reaching for it. Empty is a supported
    ///   state and simply falls through to the bank.
    public init(bank: [IncomingThought],
                library: [Declaration] = [],
                matchAll: @escaping ThoughtCategoryMatcher = ThoughtMatcherProvider.matchAll,
                writer: GuardThoughtWriter = GuardThoughtWriter()) {
        self.bank = bank
        self.library = library
        self.matchAll = matchAll
        self.writer = writer
    }

    /// Whether the written path can actually run right now.
    ///
    /// Not a tier check any more. The only thing that decides is whether the
    /// key arrived from Remote Config at launch — it can be empty, in which
    /// case every user runs on device. The ASK screen reads this to decide
    /// which privacy line to show, so it has to answer "will the words be
    /// sent", never "is this user entitled to have them sent".
    public var sendsThoughtOffDevice: Bool {
        writer.isConfigured
    }

    /// The app's answer to what someone just named: Claude writes the counter
    /// for the thought they actually typed, with the reviewed library behind it
    /// whenever that cannot run.
    ///
    /// Deliberately NOT an `async` overload of `classify(_:)`. Swift prefers the
    /// async candidate inside an async function, so an overload would have made
    /// every local call in this file — and `AskForThoughtView`'s crisis
    /// pre-screen, which must resolve instantly with no round trip — either fail
    /// to compile or quietly become a network call. A different name is worth
    /// more than a matching one here.
    ///
    /// Crisis screening happens here, locally, BEFORE the request. It is the
    /// first thing in the function for the same reason it always was: no
    /// matching, no quota, no paywall, and no network call, may run ahead of it.
    public func answer(_ text: String) async -> ThoughtClassification {
        if case .reachOut = SituationScreen.screen(text) {
            return .reachOut
        }

        guard sendsThoughtOffDevice else {
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
                // `CoreAnalytics`, not `AnalyticsService`: this file lives in
                // the package now, and the app's analytics stack is not
                // reachable from here. The app installs the real provider at
                // startup; the package's own build and its tests leave it nil
                // and the call no-ops.
                CoreAnalytics.track("guard_written_rejected",
                                    parameters: ["terrain": written.category.rawValue])
                return classify(text)
            }
            // A rebuke that fails review loses on its own. The declaration it
            // came with is still good, and the terrain's mapped line still
            // names the right thing, so this costs one line rather than the
            // whole written answer.
            let rebuke = Self.followsRebukeRules(written.rebuke)
                ? written.rebuke
                : written.category.rebuke
            return .matched(written.category,
                            IncomingThought(
                                id: CapturedThought.escapeHatchDeclarationId,
                                text: text,
                                category: written.category,
                                intensity: 1,
                                rebuke: rebuke,
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
    public static func followsHouseRules(_ declaration: String) -> Bool {
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

        let lowered = trimmed.lowercased()

        // Rule 6: no hedging.
        //
        // "hope" is NOT in this list, and that is the point. Biblical hope is
        // confident expectation, not a wobble — "He is my only hope" and
        // "certainty about what I hope for" are both shipped, reviewed lines.
        // Only the hedging FORM is caught, as a phrase.
        let hedges: Set<String> = ["maybe", "hoping", "try", "trying", "might", "someday", "wish"]
        guard Set(words).isDisjoint(with: hedges) else { return false }
        // "I hope" hedges; "I hope FOR" does not. Hebrews 11:1 ships as
        // "certainty about what I hope for", where the hope is the object of
        // confidence rather than a wobble about the future. Catching the bare
        // phrase rejected that reviewed line.
        if lowered.contains("i hope"), !lowered.contains("i hope for") { return false }
        guard !lowered.contains("i just") else { return false }

        // Rule 12: never name the low thing. A declaration does not mention the
        // fear, the sickness, the lack or the shame, even to overrule it.
        let lowThings: Set<String> = [
            "afraid", "fear", "fears", "fearful", "anxious", "anxiety", "worry",
            "worried", "panic", "scared", "sick", "sickness", "illness", "ill",
            "disease", "cancer", "covid", "virus", "infection", "pain", "dying",
            "shame", "ashamed", "guilt", "guilty", "condemned", "unworthy",
            "worthless", "failure", "broke", "poverty", "debt", "lack",
            "lonely", "abandoned", "rejected", "lust", "porn",
            "addiction", "depressed", "depression", "hopeless"
        ]
        guard Set(words).isDisjoint(with: lowThings) else { return false }

        // "alone" is a word with two opposite senses and cannot be judged on
        // its own. "God alone makes me dwell in safety" and "Alone or in a
        // crowd, I am the same person" are both shipped, reviewed lines; the
        // loneliness sense only shows up attached to a person. So the sense is
        // decided by the phrase, not the token.
        let lowPhrases = ["feel alone", "feeling alone", "so alone", "all alone",
                          "left alone", "am alone", "never alone", "not alone"]
        guard !lowPhrases.contains(where: { lowered.contains($0) }) else { return false }

        return true
    }

    /// The rebuke's own review, and deliberately not `followsHouseRules`.
    ///
    /// That one rejects a line for naming fear, sickness, shame or lack. This
    /// line exists to name exactly those, so it is checked for the two things
    /// that would make it the wrong kind of sentence instead: asking rather than
    /// commanding, and being aimed at a person rather than at the thing.
    static func followsRebukeRules(_ rebuke: String) -> Bool {
        let trimmed = rebuke.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        guard !trimmed.contains("—"), !trimmed.contains("–") else { return false }

        let lowered = trimmed.lowercased()
        let words = lowered.split(whereSeparator: { !$0.isLetter && $0 != "'" }).map(String.init)
        // Jesus' own were two to seven words. The ceiling leaves room to name
        // the thing and put it out in one breath, and nothing beyond that.
        guard words.count >= 2, words.count <= 14 else { return false }

        // A rebuke commands. Asking God to deal with it is a prayer — a good
        // thing, and not this thing. The premise of the whole drill is that the
        // believer has the authority and uses it.
        let petitions = ["please", "i pray", "i ask", "help me", "would you"]
        guard !petitions.contains(where: { lowered.contains($0) }) else { return false }

        // Never a person. Scripture gives nobody authority over another free
        // will (CLAUDE.md rule 6): the thing over someone can be put out, the
        // person never can.
        let people = ["husband", "wife", "son", "daughter", "mother", "father",
                      "mom", "dad", "child", "kids", "children", "boss", "friend",
                      "brother", "sister", "boyfriend", "girlfriend"]
        let aimedAtAPerson = people.contains { lowered.contains("\($0), you") }
        guard !aimedAtAPerson else { return false }

        return true
    }

    /// A declined request still ends in something true about the speaker, drawn
    /// from the reviewed library rather than generated.
    ///
    /// Deliberately identity rather than the sentence's own subject: Claude
    /// declined because the thought asked for something scripture will not
    /// declare — harm to someone, another person's spouse — and answering it
    /// with a well-matched line about that same subject would hand back a
    /// dressed-up version of the thing just refused. Their own standing is the
    /// honest floor.
    private func classifyDeclined(_ text: String) -> ThoughtClassification {
        let category = ThoughtCategory.inadequacy
        let thought = libraryCounter(for: category)
            ?? counter(for: category, matching: text)
            ?? Self.lastResort
        return .matched(category, thought, confidence: .low)
    }

    /// A line from the reviewed library in this terrain, ignoring the sentence.
    /// Used only by the declined path, which must not answer the subject.
    private func libraryCounter(for category: ThoughtCategory) -> IncomingThought? {
        ThoughtCounterLibrary.counter(inTerrain: category, in: library)
    }

    /// The crisis screen on its own, with no matching behind it.
    ///
    /// The ASK screen runs this before it commits to anything, so the reach-out
    /// card appears the instant someone types that they want to end their life
    /// — no spinner, no round trip, and no scan of the declaration library in
    /// front of it.
    public func screensForCrisis(_ text: String) -> Bool {
        if case .reachOut = SituationScreen.screen(text) { return true }
        return false
    }

    /// - Parameter text: the user's own words. Never stored, never synced,
    ///   never logged — it exists for the length of this call.
    public func classify(_ text: String) -> ThoughtClassification {
        // Safety first, and unconditionally. Placing this above every other
        // branch is the whole point: no matching and no quota check can run
        // ahead of it and route someone in crisis into a drill.
        if case .reachOut = SituationScreen.screen(text) {
            return .reachOut
        }

        // A redirect verdict (someone else's marriage, harm to another) is NOT
        // treated as a crisis and is not corrected here either. This screen is
        // about a thought coming at them, not a request we are agreeing to
        // build a week on — so it falls through to matching and they get a
        // declaration about their own standing, which is the right answer.

        // The reviewed library leads, because it is the only pool big enough to
        // answer the thing they actually named. It reads both keyword tables —
        // the 42-rule one and the nine-terrain lexicon — and returns a line
        // from the category the sentence is really about, which is how someone
        // four years into infertility reaches the twenty-five FERTILITY
        // declarations that ship in the app instead of a general word about
        // being complete in Christ.
        if let thought = ThoughtCounterLibrary.counter(for: text, in: library) {
            return .matched(thought.category, thought, confidence: .high)
        }

        // No library in memory (a cold launch, a failed fetch, a unit test), so
        // fall back to the bundled bank. Same two tables, nine terrains, five
        // gentle lines apiece.
        if let hit = TerrainLexicon.terrain(for: text),
           let thought = counter(for: hit.category, matching: text) {
            return .matched(hit.category, thought, confidence: .high)
        }

        let matched = matchAll(text)
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
    public static let lastResort = IncomingThought(
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
