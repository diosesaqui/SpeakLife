//
//  DeclarationMatcher.swift
//  SpeakLife
//

import Foundation

struct DeclarationMatch {
    let category: DeclarationCategory
    let declarationText: String
    let verse: String
    let verseReference: String
    /// True when at least one keyword rule matched. False = fell through to default.
    let isConfident: Bool
    /// Claude read the request and refused to write for it.
    ///
    /// Needed because the refusal has to survive the fallback: without it, a
    /// declined request threw, was caught by the same handler as a network
    /// error, and came back from the keyword matcher as a written declaration —
    /// which made the whole second safety layer inert.
    var isDeclined: Bool = false
}

// MARK: - Input Validator

enum DeclarationInputError: Error, LocalizedError {
    case tooShort
    case gibberish
    case noMeaningfulContent

    var errorDescription: String? {
        switch self {
        case .tooShort:
            return "Tell us a bit more — what are you trusting God for?"
        case .gibberish:
            return "We couldn't understand that. Try typing or speaking your need clearly."
        case .noMeaningfulContent:
            return "Be specific — what area of your life are you believing God for?"
        }
    }

    var prompt: String {
        switch self {
        case .tooShort:
            return "Tell us more — what are you trusting God for?"
        case .gibberish:
            return "We couldn't understand that. Try speaking clearly or type your need."
        case .noMeaningfulContent:
            return "Be specific — healing, finances, peace, relationships?"
        }
    }
}

struct DeclarationInputValidator {
    // Words that by themselves tell us nothing meaningful
    private static let stopWords: Set<String> = [
        "i", "me", "my", "a", "an", "the", "is", "am", "are", "was", "be",
        "to", "of", "and", "in", "it", "for", "on", "with", "this", "that",
        "do", "don't", "just", "so", "um", "uh", "like", "yeah", "ok", "okay",
        "yes", "no", "hi", "hey", "please", "thank", "thanks", "help", "need",
        "want", "something", "anything", "everything", "nothing", "idk", "dunno"
    ]

    static func validate(_ input: String) throws {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. Too short
        guard trimmed.count >= 8 else { throw DeclarationInputError.tooShort }

        // 2. Gibberish — less than 60% of characters are letters or spaces
        let letters = trimmed.filter { $0.isLetter || $0.isWhitespace }.count
        let ratio = Double(letters) / Double(max(trimmed.count, 1))
        guard ratio >= 0.60 else { throw DeclarationInputError.gibberish }

        // 3. Must have at least 2 meaningful (non-stop) words
        let words = trimmed.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        let meaningfulWords = words.filter { !stopWords.contains($0) && $0.count >= 3 }
        guard meaningfulWords.count >= 2 else { throw DeclarationInputError.noMeaningfulContent }
    }
}

// `MatchRule` and its shared `defaults` table moved into
// `Sources/SpeakLifeCore/KeywordMatchRules.swift` so `ThoughtClassifier`
// (now in SpeakLifeServices) can consult the same table without dragging
// this file's DeclarationContent / async matcher neighborhood into the
// package. Both callers read `MatchRule.defaults` from Core; there is
// only one source of truth.

final class KeywordDeclarationMatcher: DeclarationMatcherProtocol {
    private let rules: [MatchRule]

    init(rules: [MatchRule] = MatchRule.defaults) {
        self.rules = rules
    }

    func match(input: String) async -> DeclarationMatch {
        let lower = input.lowercased()
        let matchedRule = rules.first(where: { rule in
            rule.keywords.contains(where: { lower.contains($0) })
        })
        let category = matchedRule?.category ?? .faith

        return DeclarationMatch(
            category: category,
            declarationText: DeclarationContent.declaration(for: category),
            verse: DeclarationContent.verse(for: category),
            verseReference: DeclarationContent.verseReference(for: category),
            isConfident: matchedRule != nil
        )
    }

    /// Returns all distinct matched categories — used to detect when someone named multiple needs.
    func matchAll(input: String) -> [DeclarationCategory] {
        KeywordCategoryMatcher.matchAll(input, rules: rules)
    }
}
