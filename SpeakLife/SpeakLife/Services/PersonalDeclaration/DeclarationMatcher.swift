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
        let category = rules.first(where: { rule in
            rule.keywords.contains(where: { lower.contains($0) })
        })?.category ?? .faith

        return DeclarationMatch(
            category: category,
            declarationText: DeclarationContent.declaration(for: category),
            verse: DeclarationContent.verse(for: category),
            verseReference: DeclarationContent.verseReference(for: category)
        )
    }
}
