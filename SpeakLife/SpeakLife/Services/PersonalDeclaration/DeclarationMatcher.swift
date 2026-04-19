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
        // Physical healing
        MatchRule(keywords: ["heal", "sick", "health", "body", "cancer", "pain", "disease", "recover", "ill", "chronic", "diagnosis", "surgery", "hospital", "medicine", "condition", "symptom"], category: .health),

        // Finances & provision
        MatchRule(keywords: ["money", "financ", "debt", "provid", "wealth", "income", "broke", "bills", "afford", "rent", "mortgage", "loan", "savings", "invest", "poverty", "need money", "can't pay"], category: .wealth),

        // Work & career (before wealth so "job" routes here specifically)
        MatchRule(keywords: ["job", "career", "work", "boss", "cowork", "fired", "unemploy", "promot", "interview", "business", "entrepren", "client", "office", "laid off", "profession"], category: .work),

        // Anxiety & stress
        MatchRule(keywords: ["anxiet", "anxious", "panic", "worry", "stress", "overwhelm", "dread", "nervous", "tension", "spiral", "racing thoughts", "can't stop thinking"], category: .anxiety),

        // Fear (distinct from anxiety — phobias, spiritual fear)
        MatchRule(keywords: ["afraid", "scared", "terrif", "phobia", "fear of", "frightened", "coward", "too scared"], category: .fear),

        // Believing FOR a spouse (check BEFORE marriage rule — more specific)
        MatchRule(keywords: ["a wife", "a husband", "future wife", "future husband", "future spouse", "find a partner", "meet someone", "right person", "still single", "want a wife", "want a husband", "send me a", "bring me a", "praying for a spouse", "godly wife", "godly husband", "my future partner"], category: .love),

        // Protecting / restoring an existing marriage
        MatchRule(keywords: ["my marriage", "my husband", "my wife", "our marriage", "my spouse", "save my marriage", "divorce", "reconcil", "cheating", "infidelity", "separation", "broken marriage", "my relationship"], category: .marriage),

        // Parenting & family
        MatchRule(keywords: ["child", "son", "daughter", "parent", "kids", "family", "children", "prodigal", "teen", "newborn", "grandchild", "motherhood", "fatherhood"], category: .parenting),

        // Purpose & calling
        MatchRule(keywords: ["purpose", "calling", "destiny", "direction", "lost", "confus", "mission", "next step", "what am i supposed", "don't know what", "unfulfilled", "stuck", "stagnant", "wasted"], category: .destiny),

        // Identity & self-worth
        MatchRule(keywords: ["identity", "worth", "enough", "value", "who am i", "self-worth", "self-esteem", "insecure", "inadequate", "not good enough", "imposter", "ugly", "unlovable"], category: .identity),

        // Peace & rest
        MatchRule(keywords: ["peace", "rest", "sleep", "calm", "still", "quiet", "burnout", "exhausted", "tired of fighting", "worn out", "no rest", "can't sleep", "weary"], category: .rest),

        // Joy & depression
        MatchRule(keywords: ["joy", "happy", "depress", "sad", "grief", "mourn", "hopeless", "joyless", "empty", "numb", "dark season", "no hope", "crying", "tears", "sorrow"], category: .joy),

        // Favor & open doors
        MatchRule(keywords: ["favor", "opportunit", "promot", "door", "open door", "breakthrough", "bless", "advance", "recognition", "seen", "overlooked", "passed over"], category: .favor),

        // Grace, forgiveness of self, shame
        MatchRule(keywords: ["forgiv", "guilt", "shame", "past", "mistake", "failure", "condemn", "regret", "mess", "not worthy", "too far gone", "can't forgive myself"], category: .grace),

        // God's protection
        MatchRule(keywords: ["protect", "safe", "danger", "enemy", "attack", "threat", "unsafe", "fear for family", "accident", "harm"], category: .godsprotection),

        // Spiritual warfare
        MatchRule(keywords: ["warfare", "demonic", "spiritual battle", "under attack", "oppression", "darkness", "curse", "witchcraft", "bound", "torment"], category: .warfare),

        // Addiction & freedom
        MatchRule(keywords: ["addict", "substance", "alcohol", "drug", "porn", "pornograph", "compulsion", "habit", "chain", "enslaved", "can't stop", "relapse"], category: .addiction),

        // Confidence & boldness
        MatchRule(keywords: ["confiden", "bold", "courage", "timid", "shy", "speak up", "afraid to speak", "introvert", "public speaking", "feel small", "hold back"], category: .confidence),

        // Wisdom & decisions
        MatchRule(keywords: ["wisdom", "decision", "clarity", "guidance", "know what to do", "unsure", "which way", "crossroads", "confused about", "discernment", "direction"], category: .wisdom),

        // Inner healing & emotional wounds
        MatchRule(keywords: ["trauma", "wounded", "broken heart", "hurt", "betrayed", "abandon", "abuse", "rejection", "inner healing", "childhood", "emotional pain", "trust issues", "heartbreak"], category: .innerHealing),

        // Spiritual growth
        MatchRule(keywords: ["grow", "closer to god", "spiritual", "faith weak", "doubt", "believe more", "prayer life", "read bible", "know god", "deeper", "on fire", "lukewarm", "backslid"], category: .spiritualGrowth),

        // Miracles
        MatchRule(keywords: ["miracle", "impossible", "need a miracle", "supernatural", "nothing else worked", "last hope", "no natural answer", "only god can"], category: .miracles),

        // Hard times & perseverance
        MatchRule(keywords: ["suffering", "trial", "hard season", "going through", "difficult", "storm", "valley", "don't understand why", "why is this happening", "losing faith", "giving up"], category: .hardtimes),

        // Loneliness & friendship
        MatchRule(keywords: ["lonely", "alone", "no friends", "isolated", "community", "friend", "belong", "outcas", "social", "disconnected", "no one understands"], category: .friendship),

        // Purity
        MatchRule(keywords: ["purity", "lust", "sexual", "temptation", "clean", "holiness", "holy", "impure", "struggle with sin", "moral failure"], category: .purity),

        // Hope
        MatchRule(keywords: ["hope", "hopeless", "give up", "lost hope", "no point", "future", "things will get better", "waiting", "patience", "delayed", "not yet"], category: .hope),

        // Love (God's love, feeling unloved)
        MatchRule(keywords: ["love", "unloved", "unworthy of love", "god loves me", "does god care", "feel forgotten", "feel invisible", "accepted", "unconditional"], category: .love),
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
