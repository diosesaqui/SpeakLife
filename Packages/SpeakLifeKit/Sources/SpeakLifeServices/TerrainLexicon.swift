//
//  TerrainLexicon.swift
//  SpeakLife
//
//  Sorts a typed thought into one of Guarding's nine terrains, on device.
//
//  This exists because Guarding was borrowing `MatchRule.defaults` — a table
//  built to sort prayer needs into 42 `DeclarationCategory` values — and then
//  mapping the answer down to nine. Three things were wrong with that:
//
//  1. **It answered a harder question than the one being asked.** Nine coarse
//     buckets is a far easier problem than 42, and keywords are genuinely good
//     at it. Borrowing the harder table threw that advantage away.
//  2. **First rule won, not best rule.** `matchAll(...).first` returns whichever
//     matching rule sits highest in the file. "afraid of Covid coming back" hit
//     `fear` on the single token "afraid" and never considered that the sentence
//     is about a body.
//  3. **Its vocabulary was the wrong vocabulary.** "covid" appears nowhere in
//     the 42-rule table, so "Covid is coming back" matched NOTHING, fell to the
//     low-confidence branch, and returned a general identity declaration for a
//     thought about illness.
//
//  So this scores every terrain and takes the highest, rather than taking the
//  first thing that fires.
//
//  **Matching is prefix-per-word, not substring.** A bare `contains` makes "ill"
//  match "still" and "will", which is how a keyword table quietly rots. A
//  single-word key matches when some word in the sentence STARTS with it, which
//  still gives stemming for free ("heal" catches healing/healed, "anxiet"
//  catches anxiety/anxious) without the false positives. Multi-word keys are
//  matched as plain substrings, because that is what they are.
//
//  **Score is keyword length.** Longer, more specific keys outweigh short
//  generic ones, so "test results" beats a stray "not" without needing a
//  hand-tuned weight per entry.
//

import Foundation
import SpeakLifeCore

enum TerrainLexicon {

    /// The words that put a thought in each terrain.
    ///
    /// Written for how people actually type at 2am, not for how a theologian
    /// would name the category. Overlap between terrains is expected and fine —
    /// scoring resolves it, which is the whole reason this is scored.
    static let keywords: [ThoughtCategory: [String]] = [

        .fear: [
            "afraid", "scared", "fear", "terrif", "panic", "anxiet", "anxious",
            "worry", "worried", "dread", "nervous", "frighten", "spiral",
            "what if", "worst case", "something bad", "going to happen",
            "can't stop thinking", "racing thoughts", "on edge", "freaking out",
            "overwhelm", "catastroph", "danger", "unsafe", "threat"
        ],

        .sickness: [
            "sick", "ill", "illness", "disease", "cancer", "tumor", "covid",
            "flu", "virus", "infection", "diagnos", "symptom", "chronic",
            "pain", "hurting", "hospital", "doctor", "surgery", "medicat",
            "medicine", "chemo", "test results", "scan", "biopsy",
            // "relapse" deliberately does NOT live here. It reads as medical,
            // but the word people actually type it in is addiction, and the
            // sickness terrain answers with declarations about a body being
            // whole. `ThoughtCategory.from` already carries the warning for the
            // purity version of this mistake: routing addiction there "would
            // send someone fighting a bottle to declarations about their eyes".
            // Sending them to declarations about their lungs is the same error.
            // Medical recurrence is covered by the phrases below.
            "remission", "not getting better", "my body", "my health",
            "won't heal", "never heal", "dying", "terminal", "condition",
            "coming back", "flare up", "immune", "blood pressure", "diabet"
        ],

        .lack: [
            "money", "broke", "bills", "rent", "afford", "debt", "owe",
            "paycheck", "income", "poverty", "poor", "provide", "provision",
            "can't pay", "not enough money", "behind on", "eviction",
            "lost my job", "laid off", "unemploy", "savings", "bankrupt",
            "financ", "cost", "expensive", "make ends meet"
        ],

        .rejection: [
            "nobody wants", "no one wants", "unwanted", "left out", "left me",
            "unloved", "no one cares", "nobody cares", "ignored", "invisible",
            "don't belong", "doesn't want me", "rejected", "rejection",
            "unlikable", "too much for", "not wanted", "pushed away",
            "everyone leaves", "always leave", "abandoned me", "betrayed",
            "cheated", "dumped", "broke up"
        ],

        .condemnation: [
            "guilt", "guilty", "shame", "ashamed", "dirty", "unforgiv",
            "too far gone", "messed up", "screwed up", "ruined", "disappoint",
            "punish", "unworthy", "not worthy", "deserve", "my past",
            "what i did", "can't forgive", "condemn", "judged", "bad person",
            "hypocrite", "keep sinning", "keep falling",
            // Addiction belongs here, not with sickness and not with purity.
            // `ThoughtCategory.from` maps `.addiction` onto grace on purpose:
            // it carries alcohol, drugs and every other compulsion, and what is
            // underneath all of them is shame. Grace and freedom are the right
            // medicine; a declaration about a healthy body is not.
            "relapse", "addict", "alcohol", "drinking", "drunk", "drugs",
            "sober", "sobriety", "using again", "clean time", "compulsion",
            "can't stop drinking", "withdrawal", "one more drink"
        ],

        .inadequacy: [
            "not good enough", "not enough", "worthless", "useless", "failure",
            "failing", "loser", "stupid", "dumb", "imposter", "fraud",
            "can't do it", "not smart", "not capable", "incompeten",
            "everyone else is better", "behind everyone", "waste", "pathetic",
            "amount to", "never be", "not cut out", "inadequate", "weak"
        ],

        .abandonment: [
            "god left", "god doesn't", "god isn't", "god won't", "forsaken",
            "forgotten me", "doesn't hear", "not listening", "silence",
            "stopped listening", "won't listen", "doesn't listen", "listening",
            "stopped hearing", "quit on me", "turned away",
            "far from god", "abandoned", "alone", "lonely", "isolated",
            "no one understands", "empty", "numb", "hopeless", "no hope",
            "gave up on me", "unanswered", "where is god", "does god care"
        ],

        // Doubt and guidance, NOT vocation. The bank's confusion pool answers
        // "You made the whole thing up", "You do not know what you are doing",
        // "God is not going to tell you what to do" — faith and hearing God.
        // It has nothing at intensity 1 about a life's direction, and the one
        // entry that does ("I move when God says move") sits at intensity 3,
        // which a new user cannot reach.
        //
        // So the vocational words are deliberately absent: purpose, calling,
        // direction, wandering, aimless, stuck. They fall through to the
        // 42-rule matcher, which maps `.destiny` onto `.inadequacy` — the
        // identity terrain — and that is both the designed behaviour and a
        // better answer than a declaration about faith being real.
        //
        // "lost" is absent for a different reason: it is the same word in "I
        // feel lost" and "I lost my mom", and sending a grieving person a
        // declaration about direction is the worst miss in this file.
        .confusion: [
            "don't know what", "no idea what", "confused", "confusing",
            "which way", "what am i supposed", "can't decide", "second guess",
            "doubt", "makes no sense", "why is this happening",
            "don't understand", "can't hear god", "god isn't speaking",
            "no answer", "silent about"
        ],

        .lust: [
            "lust", "porn", "pornograph", "temptation", "tempted", "impure",
            "sexual", "craving", "urges", "can't stop looking", "keep looking",
            "looking at", "acting out",
            "fantas", "unfaithful", "my eyes", "purity", "relapsed again"
        ]
    ]

    /// The terrain a thought belongs to, and how strongly.
    ///
    /// - Returns: nil when nothing matched at all, so the caller can tell "this
    ///   is about the body" apart from "we have no idea" and pick an honest
    ///   fallback rather than pretending to a match.
    static func terrain(for text: String) -> (category: ThoughtCategory, score: Int)? {
        let lowered = text.lowercased()
        let words = lowered.split(whereSeparator: { !$0.isLetter && $0 != "'" }).map(String.init)
        guard !words.isEmpty else { return nil }

        var best: ThoughtCategory?
        var bestScore = 0

        // Sorted so the walk is deterministic. Dictionary order is not stable
        // between runs, and a tie must not resolve differently on two devices
        // handed the same sentence.
        for category in ThoughtCategory.allCases.sorted(by: { $0.rawValue < $1.rawValue }) {
            guard let keys = keywords[category] else { continue }
            var score = 0
            for key in keys where matches(key, lowered: lowered, words: words) {
                // Length is the weight: specific phrases outrank stray tokens.
                score += key.count
            }
            if score > bestScore {
                bestScore = score
                best = category
            }
        }

        guard let best, bestScore > 0 else { return nil }
        return (best, bestScore)
    }

    /// Multi-word keys are substrings. Single words must START a word in the
    /// sentence, which gives stemming without letting "ill" match "still".
    private static func matches(_ key: String, lowered: String, words: [String]) -> Bool {
        if key.contains(" ") {
            return lowered.contains(key)
        }
        return words.contains { $0.hasPrefix(key) }
    }
}
