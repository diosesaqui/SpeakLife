//
//  BurstVariety.swift
//  SpeakLife
//
//  Keeps a burst from saying the same thing twice.
//
//  The burst used to dedupe by exact text only. That let two lines on the same
//  verse land in one session: a campaign anchor ("I am submitted to God, so I
//  resist the devil. Enemy, you flee.") and the warfare declaration on James
//  4:7 ("Devil, I submit to God and resist you, so flee."). Different strings,
//  same line, and the speaker hears it twice in seven.
//
//  A line is too close to one already chosen when it stands on the same verse
//  (overlapping reference, or the same scripture quoted, which is how a
//  Jesus-voice line is matched since its reference is just "Jesus"), or when
//  its wording is nearly the same.
//

import Foundation

public enum BurstVariety {

    /// Picks up to `limit` lines from `candidates`, in order, preferring ones
    /// that say something new.
    ///
    /// The first pass skips anything too close to a line already in the burst
    /// (`alongside`), to a line it has already picked, or to anything in
    /// `avoiding`. The second pass only skips exact repeats, so a thin pool
    /// still fills the burst: a near-repeat is better than a missing slat. The
    /// lines the second pass adds go last, which keeps a repeat as far from its
    /// twin as the burst allows.
    ///
    /// - Parameters:
    ///   - alongside: lines already in the burst.
    ///   - avoiding: lines that are not in the burst but whose verses it should
    ///     still steer clear of, like the week's other campaign anchors.
    ///   - blockedTexts: exact texts never to pick, on either pass.
    public static func pick(
        _ candidates: [BurstDeclaration],
        limit: Int,
        alongside: [BurstDeclaration] = [],
        avoiding: [BurstDeclaration] = [],
        blockedTexts: Set<String> = []
    ) -> [BurstDeclaration] {
        guard limit > 0 else { return [] }

        var usedTexts = blockedTexts.union(alongside.map(\.text))
        var context = (alongside + avoiding).map(Fingerprint.init)
        var picked: [BurstDeclaration] = []

        for candidate in candidates where picked.count < limit {
            guard !usedTexts.contains(candidate.text) else { continue }
            let fingerprint = Fingerprint(candidate)
            guard !context.contains(where: { $0.isTooClose(to: fingerprint) }) else { continue }
            picked.append(candidate)
            usedTexts.insert(candidate.text)
            context.append(fingerprint)
        }

        for candidate in candidates where picked.count < limit {
            guard !usedTexts.contains(candidate.text) else { continue }
            picked.append(candidate)
            usedTexts.insert(candidate.text)
        }

        return picked
    }

    /// Whether two lines say the same thing closely enough that one burst
    /// should not carry both.
    public static func isTooClose(_ a: BurstDeclaration, _ b: BurstDeclaration) -> Bool {
        Fingerprint(a).isTooClose(to: Fingerprint(b))
    }

    // MARK: - Fingerprint

    struct Fingerprint {
        let text: String
        let reference: ScriptureReference?
        let scriptureWords: Set<String>
        let textWords: Set<String>

        init(_ line: BurstDeclaration) {
            text = line.text
            reference = ScriptureReference(line.verse)
            scriptureWords = BurstVariety.contentWords(line.scripture ?? "")
            textWords = BurstVariety.contentWords(line.text)
        }

        func isTooClose(to other: Fingerprint) -> Bool {
            if text == other.text { return true }
            if let a = reference, let b = other.reference, a.overlaps(b) { return true }
            // Catches a Jesus-voice line ("Jesus" is its whole reference) and a
            // parallel gospel passage of the same saying.
            if BurstVariety.jaccard(scriptureWords, other.scriptureWords, minimumWords: 4) >= 0.6 {
                return true
            }
            return BurstVariety.nearlySameWording(textWords, other.textWords)
        }
    }

    // MARK: - Words

    /// Small words that every line shares and that say nothing about which
    /// truth a line declares.
    private static let stopWords: Set<String> = [
        "i", "am", "my", "me", "mine", "the", "and", "a", "an", "of", "to", "is",
        "in", "his", "he", "him", "so", "you", "your", "yours", "it", "its",
        "that", "for", "with", "be", "are", "by", "on", "this", "all", "from",
        "was", "not", "who", "will", "has", "have", "they", "them", "their",
        "our", "we", "us", "do", "does", "as", "at", "or", "but", "every",
        "god", "god's", "lord", "jesus", "christ", "unto", "thee", "thou", "thy", "ye",
    ]

    static func contentWords(_ text: String) -> Set<String> {
        let lowered = text.lowercased().replacingOccurrences(of: "\u{2019}", with: "'")
        var words = Set<String>()
        var current = ""
        for character in lowered {
            if character.isLetter || character == "'" {
                current.append(character)
            } else if !current.isEmpty {
                words.insert(current)
                current = ""
            }
        }
        if !current.isEmpty { words.insert(current) }
        return words.subtracting(stopWords)
    }

    static func jaccard(_ a: Set<String>, _ b: Set<String>, minimumWords: Int = 1) -> Double {
        guard a.count >= minimumWords, b.count >= minimumWords else { return 0 }
        return Double(a.intersection(b).count) / Double(a.union(b).count)
    }

    /// Nearly every content word of the shorter line is in the longer one, and
    /// the two share at least half their words overall. Both halves matter: the
    /// first alone would flag "I am free" inside any longer line about freedom.
    static func nearlySameWording(_ a: Set<String>, _ b: Set<String>) -> Bool {
        guard a.count >= 3, b.count >= 3 else { return false }
        let shared = Double(a.intersection(b).count)
        let containment = shared / Double(min(a.count, b.count))
        return containment >= 0.8 && jaccard(a, b) >= 0.5
    }
}

// MARK: - Scripture Reference

/// "Luke 10:18-19", "Psalm 139:14", "Ruth 2:20b" parsed far enough to tell
/// whether two references share a verse.
///
/// Returns nil for anything it cannot read, including the "Jesus" reference
/// of a Jesus-voice line. Those are matched on the scripture they quote.
struct ScriptureReference: Equatable {
    let book: String
    let chapter: Int
    let verses: ClosedRange<Int>

    init?(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let colon = trimmed.firstIndex(of: ":") else { return nil }

        // "1 Corinthians 13" -> book "1 corinthians", chapter 13.
        let head = trimmed[..<colon]
        guard let space = head.lastIndex(of: " ") else { return nil }
        guard let chapter = Int(head[head.index(after: space)...]) else { return nil }
        let bookName = head[..<space]
            .lowercased()
            .split(separator: " ")
            .joined(separator: " ")
        guard !bookName.isEmpty else { return nil }

        // "18-19", "20b", "4 (NKJV)" -> the verse numbers, letters dropped.
        let tail = trimmed[trimmed.index(after: colon)...]
        let numbers = tail
            .split(whereSeparator: { $0 == "-" || $0 == "\u{2013}" || $0 == "\u{2014}" || $0 == "," || $0 == " " })
            .compactMap { Int($0.prefix(while: \.isNumber)) }
        guard let first = numbers.first else { return nil }
        let last = numbers.count > 1 ? max(numbers[1], first) : first

        book = bookName == "psalms" ? "psalm" : bookName
        self.chapter = chapter
        verses = first...last
    }

    func overlaps(_ other: ScriptureReference) -> Bool {
        book == other.book && chapter == other.chapter && verses.overlaps(other.verses)
    }
}
