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

    /// Picks the gentlest true thing in that terrain: intensity 1 first, because
    /// someone reaching for the escape hatch already has the weight — the
    /// counter should not add to it.
    ///
    /// Selection is stable for a given input (hashed, not random) so re-typing
    /// the same thought does not shuffle the line they are about to speak.
    private func counter(for category: ThoughtCategory, matching text: String) -> IncomingThought? {
        let inCategory = bank.filter { $0.category == category }
        guard !inCategory.isEmpty else { return nil }
        let gentle = inCategory.filter { $0.intensity == 1 }
        let pool = gentle.isEmpty ? inCategory : gentle
        let hashed: Int = Self.stableHash(text)
        let index: Int = hashed % pool.count
        return pool[index]
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

    /// `String.hashValue` is seeded per process, so it would give a different
    /// answer for the same sentence on the next launch. This one doesn't.
    ///
    /// Always non-negative: the wrapping operators can land on a negative value,
    /// and negating `Int.min` traps at runtime — a crash on an unlucky sentence,
    /// typed by someone already carrying something. Masking off the sign bit
    /// costs nothing and makes the modulo below safe by construction.
    private static func stableHash(_ text: String) -> Int {
        var hash = 5381
        for byte in text.lowercased().utf8 {
            hash = (hash &* 33) &+ Int(byte)
        }
        return hash & Int.max
    }
}
