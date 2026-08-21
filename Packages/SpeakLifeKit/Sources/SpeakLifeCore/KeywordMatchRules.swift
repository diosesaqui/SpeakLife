//
//  KeywordMatchRules.swift
//  SpeakLifeCore
//
//  The keyword table that the personal-declaration matcher and the
//  Guard escape hatch's `ThoughtClassifier` both consult.
//
//  Moved to Core (Foundation-only) so `ThoughtClassifier` — which lives
//  in SpeakLifeServices and tests directly against this table — can
//  reach it without the app target being in the graph. The app's
//  `KeywordDeclarationMatcher` still wraps this table for its own
//  async `match(input:)` API (which returns a `DeclarationContent`
//  answer that lives app-side); anything that only needs
//  "which categories fire?" reads through `matchAll(_:)` here.
//

import Foundation

/// One rule in the keyword table: a set of substrings that, if any
/// appear in the user's input, route the input to `category`.
public struct MatchRule {
    public let keywords: [String]
    public let category: DeclarationCategory

    public init(keywords: [String], category: DeclarationCategory) {
        self.keywords = keywords
        self.category = category
    }

    /// Shared keyword table. **Order matters** — the personal-declaration
    /// matcher uses the FIRST matching rule, so more specific rules must
    /// come before more general ones. The comments alongside each rule
    /// name the specificity the ordering is protecting.
    public static let defaults: [MatchRule] = [
        // Physical healing
        MatchRule(keywords: ["heal", "sick", "health", "body", "cancer", "pain", "disease", "recover", "ill", "chronic", "diagnosis", "surgery", "hospital", "medicine", "condition", "symptom"], category: .health),

        // Debt (specific — MUST be before wealth so "debt", "loan", "credit card" route here, not .wealth)
        MatchRule(keywords: ["in debt", "drowning in debt", "credit card", "student loan", "student debt", "owe money", "creditor", "bankruptcy", "can't pay back", "loan shark", "collection agency", "wage garnish", "past due", "behind on payments", "financial bondage", "debt free", "get out of debt"], category: .debt),

        // Finances & provision (general — "debt" keyword removed to avoid stealing from .debt rule above)
        MatchRule(keywords: ["money", "financ", "provid", "wealth", "income", "broke", "bills", "afford", "rent", "mortgage", "loan", "savings", "invest", "poverty", "need money", "can't pay"], category: .wealth),

        // Entrepreneurship & own business (check BEFORE career — more specific)
        MatchRule(keywords: ["my own business", "own business", "start a business", "starting a business", "entrepren", "founder", "startup", "my business", "build a business", "run a business", "business owner", "self-employ", "side business", "brand", "my company", "launch a"], category: .business),

        // Work & career — employment, job-seeking, corporate advancement
        MatchRule(keywords: ["job", "career", "work", "boss", "cowork", "fired", "unemploy", "promot", "interview", "office", "laid off", "profession", "employment", "9 to 5", "corporate", "workplace", "salary", "raise"], category: .work),

        // Anxiety & stress
        MatchRule(keywords: ["anxiet", "anxious", "panic", "worry", "stress", "overwhelm", "dread", "nervous", "tension", "spiral", "racing thoughts", "can't stop thinking"], category: .anxiety),

        // Fear (distinct from anxiety — phobias, spiritual fear)
        MatchRule(keywords: ["afraid", "scared", "terrif", "phobia", "fear of", "frightened", "coward", "too scared"], category: .fear),

        // Believing FOR a spouse (check BEFORE marriage rule — more specific)
        MatchRule(keywords: ["a wife", "a husband", "future wife", "future husband", "future spouse", "find a partner", "meet someone", "right person", "still single", "want a wife", "want a husband", "send me a", "bring me a", "praying for a spouse", "godly wife", "godly husband", "my future partner"], category: .love),

        // Dating / courtship / pre-marriage relationship (check BEFORE marriage — more specific)
        MatchRule(keywords: ["my boyfriend", "my girlfriend", "we're dating", "i'm dating", "person i'm dating", "the guy i'm dating", "the girl i'm dating", "courting", "courtship", "my relationship", "fix my relationship", "in a relationship", "romantic relationship", "my partner and i", "person i like", "someone i'm seeing", "we're not married", "relationship i'm in", "situationship"], category: .relationship),

        // Protecting / restoring an existing marriage ("my relationship" removed — now routes to .relationship)
        MatchRule(keywords: ["my marriage", "my husband", "my wife", "our marriage", "my spouse", "save my marriage", "reconcil", "cheating", "infidelity", "broken marriage", "my marriage is"], category: .marriage),

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

        // Grief & loss
        MatchRule(keywords: ["grief", "griev", "mourn", "mourning", "lost someone", "passed away", "death of", "died", "widow", "widower", "losing a loved one", "lost my mom", "lost my dad", "lost my child", "lost my husband", "lost my wife", "lost my friend", "funeral", "bereavement", "miss them so much", "someone i love died"], category: .grief),

        // Fertility & pregnancy
        MatchRule(keywords: ["fertil", "infertil", "pregnant", "pregnancy", "conceive", "conception", "trying to have a baby", "trying for a baby", "ivf", "miscarriage", "womb", "barren", "no children yet", "want a baby", "believing for a child", "surrogacy", "stillbirth", "ectopic"], category: .fertility),

        // Salvation of loved ones / prodigal (check BEFORE parenting — more specific)
        MatchRule(keywords: ["prodigal", "unsaved", "not saved", "my son left the church", "my daughter left", "walked away from god", "walked away from faith", "left the faith", "backslid", "come back to god", "praying for my family", "praying for my husband to be saved", "praying for my wife to be saved", "praying for my child to be saved", "accept jesus", "come to christ", "lost sheep", "wandering from god", "salvation of", "doesn't believe", "doesn't believe in god", "atheist family", "non-christian spouse"], category: .salvation),

        // Education & school
        MatchRule(keywords: ["school", "college", "university", "exam", "test score", "grades", "graduate", "graduation", "scholarship", "studying", "degree", "pass my test", "pass my exam", "academic", "dissertation", "thesis", "finals", "bar exam", "medical school", "law school", "fail school", "drop out", "student"], category: .education),

        // Housing & home
        MatchRule(keywords: ["house", "home", "housing", "evict", "eviction", "homeless", "apartment", "need a place to live", "need a home", "landlord", "can't afford rent", "no place to stay", "buy a house", "own a home", "mortgage approval", "closing on a house"], category: .housing),

        // Divorce recovery
        MatchRule(keywords: ["divorce", "divorced", "going through a divorce", "separation", "co-parenting", "ex-husband", "ex-wife", "ex-spouse", "single again", "broken marriage that ended", "after my marriage ended", "starting over after divorce"], category: .divorce),

        // Body / wellness / health habits
        MatchRule(keywords: ["weight", "lose weight", "overweight", "obese", "body image", "eating disorder", "binge eating", "food addiction", "diet", "fitness", "healthy habits", "temple of the holy spirit", "can't stop eating", "emotional eating", "body confidence", "self-image"], category: .wellness),

        // Clinical mental health
        MatchRule(keywords: ["bipolar", "ptsd", "schizophrenia", "mental illness", "ocd", "borderline", "personality disorder", "psychiatric", "on medication for", "clinical depression", "clinically depressed", "trauma response", "flashback", "dissociat", "mental health diagnosis", "panic disorder"], category: .mentalHealth),

        // Forgiving others / bitterness (check BEFORE grace to avoid overlap)
        MatchRule(keywords: ["can't forgive them", "can't forgive him", "can't forgive her", "bitter", "bitterness", "resentment", "unforgiveness", "holding a grudge", "rage toward", "angry at them", "angry at him", "angry at her", "what they did to me", "betrayed by", "hurt by", "offended"], category: .forgiveness),

        // New season / fresh start
        MatchRule(keywords: ["fresh start", "new beginning", "starting over", "new chapter", "second chance", "new season", "moving forward", "leaving the past behind", "next chapter", "reinvent", "blank slate", "do-over", "restart my life"], category: .newSeason),

        // Single parenting
        MatchRule(keywords: ["single mom", "single dad", "single parent", "raising kids alone", "raising children alone", "doing it alone", "no father", "no mother", "abandoned with kids", "co-parenting alone", "my kids have no father", "my kids have no mother"], category: .singleParent),

        // Anger & temper
        MatchRule(keywords: ["anger", "angry all the time", "rage", "temper", "short fuse", "explosive", "can't control anger", "outburst", "yelling", "violent", "lose my temper", "hot-headed", "fury", "wrathful"], category: .anger),
    ]
}

/// The "matchAll" side of `KeywordDeclarationMatcher` — collects every rule
/// whose keywords appear in the input, deduplicating on category. Used by
/// `ThoughtClassifier` and by the app's `KeywordDeclarationMatcher.matchAll`.
public enum KeywordCategoryMatcher {
    public static func matchAll(_ input: String, rules: [MatchRule] = MatchRule.defaults) -> [DeclarationCategory] {
        let lower = input.lowercased()
        var seen = Set<DeclarationCategory>()
        var results: [DeclarationCategory] = []
        for rule in rules {
            guard rule.keywords.contains(where: { lower.contains($0) }) else { continue }
            if seen.insert(rule.category).inserted {
                results.append(rule.category)
            }
        }
        return results
    }
}

/// The same table, scored rather than first-rule-wins.
///
/// `matchAll` answers "which rules fired, in file order". That is the right
/// answer for the personal-declaration matcher, whose rule ORDER encodes its
/// priorities (debt before wealth, business before work). It is the wrong
/// answer when the question is "what is this sentence most about", because the
/// first rule in the file wins over the rule that matched a far more specific
/// word.
///
/// Two things differ, and both are deliberate:
///
/// 1. **Score is keyword length**, the same weighting `TerrainLexicon` uses, so
///    a sentence matching "trying for a baby" outranks one that merely brushed
///    "not". Longer key, more specific claim.
/// 2. **Single-word keys must START a word**, rather than appearing anywhere in
///    the sentence. `matchAll`'s plain `contains` routes "Nobody at church
///    likes me" to HEALTH, because "body" is inside "Nobody" — and "past" is
///    inside "pastor", and "mess" inside "message". Prefix matching keeps the
///    stemming the table is written for ("anxiet", "financ", "diagnos") and
///    drops the mid-word accidents. Multi-word keys stay substrings, because
///    that is what they are.
///
/// `matchAll` is deliberately left alone: the campaign matcher has been tuned
/// against its exact behaviour, and this is an addition, not a replacement.
extension KeywordCategoryMatcher {

    /// Every category the input touches, strongest first. Ties break on the
    /// rawValue so two devices handed the same sentence agree.
    public static func ranked(_ input: String,
                              rules: [MatchRule] = MatchRule.defaults) -> [(category: DeclarationCategory, score: Int)] {
        let lowered = input.lowercased()
        let words = lowered.split(whereSeparator: { !$0.isLetter && $0 != "'" }).map(String.init)
        guard !words.isEmpty else { return [] }

        var scores: [DeclarationCategory: Int] = [:]
        for rule in rules {
            let score = rule.keywords
                .filter { matches($0, lowered: lowered, words: words) }
                .reduce(0) { $0 + $1.count }
            guard score > 0 else { continue }
            // A category can own more than one rule. The strongest wins rather
            // than the sum, so a category is never inflated by owning more
            // rules than its neighbours.
            scores[rule.category] = max(scores[rule.category] ?? 0, score)
        }

        return scores
            .map { (category: $0.key, score: $0.value) }
            .sorted {
                if $0.score != $1.score { return $0.score > $1.score }
                return $0.category.rawValue < $1.category.rawValue
            }
    }

    private static func matches(_ key: String, lowered: String, words: [String]) -> Bool {
        if key.contains(" ") {
            return lowered.contains(key)
        }
        return words.contains { $0.hasPrefix(key) }
    }
}
