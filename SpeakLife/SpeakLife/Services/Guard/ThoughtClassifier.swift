//
//  ThoughtClassifier.swift
//  SpeakLife
//
//  The escape hatch's brain: turns "something else is on my mind" into a
//  category and a declaration to speak.
//
//  **Everything here runs on device. Nothing is sent anywhere.** That is not a
//  performance choice, it is the feature's promise — what someone types when a
//  real thought is on them is the most private thing this app ever sees. There
//  is no network call in this file and none may be added: the moment one is,
//  "your thoughts never leave your phone" becomes false, and the raw text is
//  already excluded from sync and analytics on the strength of it.
//
//  The classifier reuses `MatchRule.defaults` — the same keyword table the
//  personal-declaration matcher runs on — rather than growing a second, rival
//  list of keywords that would drift out of agreement with it. It maps the
//  resulting `DeclarationCategory` onto one of the eight Guard terrains.
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
        /// A keyword rule fired and it mapped cleanly onto a terrain.
        case high
        /// Nothing matched, or the match didn't map. A general identity
        /// declaration is served — never an error state, because someone who
        /// just typed a real thought must not be handed a dead end.
        case low
    }
}

/// Classifies free text into one of the eight terrains, entirely on device.
struct ThoughtClassifier {

    private let matcher: KeywordDeclarationMatcher
    private let bank: [IncomingThought]

    init(bank: [IncomingThought], matcher: KeywordDeclarationMatcher = KeywordDeclarationMatcher()) {
        self.bank = bank
        self.matcher = matcher
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
        // the fallback stays inside the same eight and needs no special case
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
        let index = abs(Self.stableHash(text)) % pool.count
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
    private static func stableHash(_ text: String) -> Int {
        var hash = 5381
        for byte in text.lowercased().utf8 {
            hash = (hash &* 33) &+ Int(byte)
        }
        return hash
    }
}
