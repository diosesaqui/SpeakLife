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

// Open for extension via new MatchRules, closed for modification
struct MatchRule {
    let keywords: [String]
    let category: DeclarationCategory

    static let defaults: [MatchRule] = [
        MatchRule(keywords: ["heal", "sick", "health", "body", "cancer", "pain", "disease", "recover", "ill", "chronic"], category: .health),
        MatchRule(keywords: ["job", "money", "financ", "debt", "provid", "business", "wealth", "income", "broke", "bills", "afford"], category: .wealth),
        MatchRule(keywords: ["anxiet", "anxious", "fear", "panic", "worry", "stress", "overwhelm", "dread", "nervous"], category: .anxiety),
        MatchRule(keywords: ["marriage", "husband", "wife", "spouse", "relationship", "divorce", "partner"], category: .marriage),
        MatchRule(keywords: ["child", "son", "daughter", "parent", "kids", "family", "children"], category: .parenting),
        MatchRule(keywords: ["purpose", "calling", "destiny", "direction", "lost", "confus", "mission", "next step"], category: .destiny),
        MatchRule(keywords: ["identity", "worth", "enough", "value", "belong", "who am i", "self"], category: .identity),
        MatchRule(keywords: ["peace", "rest", "sleep", "calm", "still", "quiet"], category: .rest),
        MatchRule(keywords: ["joy", "happy", "depress", "sad", "grief", "mourn", "hopeless"], category: .joy),
        MatchRule(keywords: ["favor", "door", "opportunit", "promot", "open", "bless", "breakthrough"], category: .favor),
        MatchRule(keywords: ["forgiv", "guilt", "shame", "past", "mistake", "failure", "condemn"], category: .grace),
        MatchRule(keywords: ["protect", "safe", "danger", "enemy", "attack", "warfare"], category: .godsprotection),
        MatchRule(keywords: ["addict", "substance", "alcohol", "porn", "habit", "free", "chain"], category: .addiction),
        MatchRule(keywords: ["confiden", "bold", "courage", "timid", "shy", "afraid to"], category: .confidence),
        MatchRule(keywords: ["wisdom", "decision", "clarity", "guidance", "know what to do", "unsure"], category: .wisdom),
        MatchRule(keywords: ["love", "lonely", "alone", "belong", "accepted", "rejected"], category: .love),
    ]
}

final class KeywordDeclarationMatcher: DeclarationMatcherProtocol {
    private let rules: [MatchRule]

    init(rules: [MatchRule] = MatchRule.defaults) {
        self.rules = rules
    }

    func match(input: String) -> DeclarationMatch {
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
}
