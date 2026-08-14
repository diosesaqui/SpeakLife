//
//  MessageBodyFormatter.swift
//  SpeakLifeCore
//
//  Turns a broadcast message body into readable paragraphs.
//
//  Why this exists:
//    Messages are composed in paragraphs, but the text arrives at the app as a
//    single run. Some of that is escaping (a body pasted into a Shortcut or a
//    shell-built curl payload reaches FCM with a literal `\n` two-character
//    sequence rather than a newline); some of it is the sender's input field
//    flattening returns into spaces before the push is ever built. Either way
//    the reader used to paint one 200-word wall of text.
//
//    So the formatting is recovered on the reading side rather than trusted
//    from the wire. That also fixes every message already sitting in the
//    `speakLifeMessages` Firestore wall, which no sender-side change could.
//
//    The rules, in order:
//      1. Unescape and normalize every newline spelling into a real "\n".
//      2. Honor the author's breaks — any line break is a paragraph break.
//      3. Only when a block is still long enough to read as a wall, split it
//         at sentence boundaries into paragraphs of roughly `targetWords`.
//      4. A scripture quote closing with its citation always ends a paragraph,
//         and is flagged so the UI can set it apart from the prose around it.
//
//  Pure Foundation and free of UI, so it is exercised under `swift test`.
//

import Foundation

public enum MessageBodyFormatter {

    /// One rendered paragraph.
    public struct Block: Identifiable, Equatable, Sendable {

        public enum Kind: Sendable {
            /// Ordinary paragraph copy.
            case prose
            /// A quoted verse closing with its reference, e.g.
            /// `"This is the day the Lord has made." (Ps 118:24)`.
            case scripture
        }

        /// Position in the message. Stable for `ForEach` because the blocks are
        /// derived from immutable text and never reordered.
        public let id: Int
        public let text: String
        public let kind: Kind

        public init(id: Int, text: String, kind: Kind) {
            self.id = id
            self.text = text
            self.kind = kind
        }
    }

    // MARK: - Tuning

    /// A block longer than this (in words) is re-paragraphed. Set above
    /// `targetWords` so a body that is already a comfortable paragraph is left
    /// exactly as the author wrote it.
    private static let splitThresholdWords = 55

    /// Soft target for an auto-built paragraph. The paragraph closes on the
    /// first sentence that carries it past this, so paragraphs land around
    /// three to five lines on a phone.
    private static let targetWords = 34

    /// A trailing paragraph shorter than this is folded back into the one
    /// before it, so a stray fragment never dangles alone. Deliberately small:
    /// a short closing line ("Make it count.") is a good paragraph, not an
    /// orphan.
    private static let orphanWords = 4

    // MARK: - API

    /// Paragraphs for `raw`, each tagged with how it should be rendered.
    public static func blocks(from raw: String) -> [Block] {
        paragraphs(from: raw).enumerated().map { index, text in
            Block(id: index, text: text, kind: isScriptureQuote(text) ? .scripture : .prose)
        }
    }

    /// Paragraphs for `raw`, as plain strings. Empty when there is nothing to
    /// show, so callers can skip rendering entirely.
    public static func paragraphs(from raw: String) -> [String] {
        let normalized = normalizingNewlines(raw)

        let authored = normalized
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        return authored.flatMap { block -> [String] in
            // A list item is a paragraph by construction — never regrouped, and
            // never split apart on the period of "1. Pray".
            guard !isListItem(block), wordCount(block) > splitThresholdWords else {
                return [block]
            }
            return reparagraph(block)
        }
    }

    /// Single-line rendering for previews (the Inbox card, a banner), where
    /// paragraph breaks would spend the few available lines on whitespace.
    public static func preview(_ raw: String) -> String {
        paragraphs(from: raw).joined(separator: " ")
    }

    // MARK: - Normalization

    /// Collapses every way a line break reaches us into "\n".
    ///
    /// The escaped forms are the ones that matter: a body that has been through
    /// a JSON string one time too many arrives carrying the characters
    /// backslash + n, which would otherwise print literally in the reader.
    static func normalizingNewlines(_ raw: String) -> String {
        var text = raw
        // Escaped first, longest first, so "\r\n" is not left as a stray "\r".
        for escaped in ["\\r\\n", "\\n", "\\r"] {
            text = text.replacingOccurrences(of: escaped, with: "\n")
        }
        text = text.replacingOccurrences(of: "\\t", with: " ")
        text = text.replacingOccurrences(of: "\r\n", with: "\n")
        for separator in ["\r", "\u{2028}", "\u{2029}", "\u{0085}"] {
            text = text.replacingOccurrences(of: separator, with: "\n")
        }
        // Non-breaking spaces survive copy/paste and defeat word splitting.
        text = text.replacingOccurrences(of: "\u{00A0}", with: " ")
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Re-paragraphing

    /// Splits one long block into paragraphs at sentence boundaries.
    private static func reparagraph(_ block: String) -> [String] {
        let sentences = self.sentences(in: block)
        guard sentences.count > 1 else { return [block] }

        var paragraphs: [String] = []
        var current: [String] = []
        var currentWords = 0

        func flush() {
            guard !current.isEmpty else { return }
            paragraphs.append(current.joined(separator: " "))
            current.removeAll()
            currentWords = 0
        }

        for sentence in sentences {
            current.append(sentence)
            currentWords += wordCount(sentence)
            // A verse that closes with its reference gets its own paragraph:
            // it is the anchor of the message and reads as a pull quote.
            if endsWithCitation(sentence) || currentWords >= targetWords {
                flush()
            }
        }
        flush()

        // Fold a dangling fragment back rather than leave it stranded.
        if paragraphs.count > 1,
           let last = paragraphs.last,
           wordCount(last) < orphanWords {
            paragraphs.removeLast()
            paragraphs[paragraphs.count - 1] += " " + last
        }

        return paragraphs
    }

    /// Splits `text` into sentences.
    ///
    /// Hand-rolled rather than delegating to `NSLinguisticTagger`/`NLTokenizer`:
    /// this needs one behavior neither offers, which is keeping a trailing
    /// scripture citation attached to the sentence it belongs to, so
    /// `…be glad in it." (Ps 118:24) Not tomorrow.` breaks after the reference
    /// and not before it.
    static func sentences(in text: String) -> [String] {
        let characters = Array(text)
        var sentences: [String] = []
        var start = 0
        var index = 0

        while index < characters.count {
            guard isTerminator(characters[index]) else {
                index += 1
                continue
            }

            // Absorb the run of terminators ("...", "?!") and any closing
            // punctuation that belongs to this sentence.
            var end = index
            while end + 1 < characters.count, isTerminator(characters[end + 1]) { end += 1 }
            while end + 1 < characters.count, isClosingPunctuation(characters[end + 1]) { end += 1 }

            // A citation trailing the close of a quote belongs to this
            // sentence, not the next one.
            if let citationEnd = citationRange(in: characters, startingAfter: end) {
                end = citationEnd
            }

            let next = nextSignificantIndex(in: characters, after: end)
            // A boundary needs whitespace after the terminator ("6.30" is not
            // two sentences), a character the next sentence could open with,
            // and a period that is not part of an abbreviation. End of text is
            // always a boundary.
            let isBoundary: Bool
            if let next {
                isBoundary = next > end + 1
                    && startsSentence(characters[next])
                    && !isAbbreviation(characters, endingAt: index)
            } else {
                isBoundary = true
            }

            if isBoundary {
                let sentence = String(characters[start...end]).trimmingCharacters(in: .whitespaces)
                if !sentence.isEmpty { sentences.append(sentence) }
                start = (next ?? characters.count)
                index = start
            } else {
                index = end + 1
            }
        }

        if start < characters.count {
            let tail = String(characters[start...]).trimmingCharacters(in: .whitespaces)
            if !tail.isEmpty { sentences.append(tail) }
        }

        return sentences
    }

    // MARK: - Character classification

    private static func isTerminator(_ character: Character) -> Bool {
        character == "." || character == "!" || character == "?" || character == "…"
    }

    private static func isClosingPunctuation(_ character: Character) -> Bool {
        "\"'\u{201D}\u{2019})]»".contains(character)
    }

    /// True when the character could open a new sentence: a capital, a digit, an
    /// opening quote, or anything non-Latin (an emoji opener like "☀️ Take it").
    private static func startsSentence(_ character: Character) -> Bool {
        if character.isUppercase || character.isNumber { return true }
        if "\"'\u{201C}\u{2018}(«—".contains(character) { return true }
        return !character.isLetter && !character.isPunctuation && !character.isWhitespace
    }

    /// Index of the next non-whitespace character after `index`, or nil at the end.
    private static func nextSignificantIndex(in characters: [Character], after index: Int) -> Int? {
        var cursor = index + 1
        while cursor < characters.count, characters[cursor].isWhitespace { cursor += 1 }
        return cursor < characters.count ? cursor : nil
    }

    /// Abbreviations that end in a period and keep the sentence running.
    ///
    /// Book abbreviations are absent on purpose: scripture is cited as "Ps 118:24",
    /// with no period, so the sentence-ending "…in Rom." case does not arise.
    private static let abbreviations: Set<String> = [
        "mr", "mrs", "ms", "dr", "st", "sr", "jr", "prof", "rev",
        "vs", "etc", "eg", "ie", "approx", "fig", "cf", "al",
    ]

    /// True when the word ending at `periodIndex` is an abbreviation (or a
    /// single-letter initial), so its period is not a sentence end.
    private static func isAbbreviation(_ characters: [Character], endingAt periodIndex: Int) -> Bool {
        guard characters[periodIndex] == "." else { return false }

        var start = periodIndex - 1
        var word = ""
        while start >= 0, characters[start].isLetter || characters[start] == "." {
            if characters[start].isLetter { word.append(characters[start]) }
            start -= 1
        }
        guard !word.isEmpty else { return false }
        let token = String(word.reversed()).lowercased()

        // "J. Smith", and "e.g." style dotted forms, which lost their dots above.
        if token.count == 1 { return true }
        return abbreviations.contains(token)
    }

    // MARK: - Scripture citations

    /// Matches a bare reference: `(Ps 118:24)`, `(1 Cor 2:16)`, `(Lam 3:22-23)`,
    /// `(John 10:10, NIV)`.
    private static let citationPattern = "\\(\\s*[1-3]?\\s*[A-Za-z]{2,14}\\.?\\s*\\d{1,3}:\\d{1,3}(\\s*[-–]\\s*\\d{1,3})?(\\s*,[^()]{0,12})?\\s*\\)"

    private static let citationRegex: NSRegularExpression? = {
        try? NSRegularExpression(pattern: citationPattern)
    }()

    private static let trailingCitationRegex: NSRegularExpression? = {
        try? NSRegularExpression(pattern: citationPattern + "\\s*$")
    }()

    /// End index of a citation that starts just after `index` (skipping spaces),
    /// or nil when the next thing is not a reference.
    private static func citationRange(in characters: [Character], startingAfter index: Int) -> Int? {
        var cursor = index + 1
        while cursor < characters.count, characters[cursor] == " " { cursor += 1 }
        guard cursor < characters.count, characters[cursor] == "(" else { return nil }

        // Bound the candidate: a reference is short, and never spans a newline.
        let limit = min(characters.count, cursor + 40)
        guard let close = (cursor..<limit).first(where: { characters[$0] == ")" }) else { return nil }

        let candidate = String(characters[cursor...close])
        guard matchesCitation(candidate) else { return nil }
        return close
    }

    private static func matchesCitation(_ text: String) -> Bool {
        guard let regex = citationRegex else { return false }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range) else { return false }
        // Anchored: the candidate IS a reference, not prose that contains one.
        return match.range == range
    }

    static func endsWithCitation(_ text: String) -> Bool {
        guard let regex = trailingCitationRegex else { return false }
        let range = NSRange(text.startIndex..., in: text)
        return regex.firstMatch(in: text, range: range) != nil
    }

    /// A paragraph that opens with a quotation mark and closes with its
    /// reference — the shape the UI sets apart as a pull quote.
    static func isScriptureQuote(_ text: String) -> Bool {
        guard let first = text.first, "\"\u{201C}«".contains(first) else { return false }
        return endsWithCitation(text)
    }

    // MARK: - Helpers

    private static func isListItem(_ text: String) -> Bool {
        guard let first = text.first else { return false }
        if "-•*–—".contains(first) { return true }
        // "1." / "2)" / "10." openers.
        guard first.isNumber else { return false }
        let rest = text.drop(while: { $0.isNumber })
        guard let marker = rest.first else { return false }
        return marker == "." || marker == ")"
    }

    private static func wordCount(_ text: String) -> Int {
        text.split(whereSeparator: { $0.isWhitespace }).count
    }
}
