//
//  SpeakOverLink.swift
//  SpeakLife
//
//  "Speak it over someone": one person sends a declaration to someone they
//  love, and the link opens SpeakLife straight onto it.
//
//  Building and reading the link live here and nowhere else, so the rules
//  about what a gift may contain are written once. Everything in a gift came
//  from a stranger's URL, so it is treated as plain text and nothing more: no
//  markup, no lookups, no actions. It is cleaned the same way on the way out
//  and on the way in, because a link can be hand-edited in between.
//
//  The link is a `ReferralLink` (root path on speaklife.app.link), so an
//  install that comes from it is credited to `speak_over`, and the gift rides
//  in Branch link data for the fresh-install case.
//

import Foundation

/// A declaration someone sent. Plain text only.
struct SpeakOverGift: Codable, Equatable {
    let text: String
    let book: String?
    /// The sender's first name, if they gave one.
    let from: String?
    /// The recipient's first name, if the sender gave one.
    let to: String?

    /// Declarations with `book == "Jesus"` are in Jesus' own voice (CLAUDE.md,
    /// rule 1), so the screen labels them instead of showing a reference.
    var isJesusVoice: Bool {
        book?.caseInsensitiveCompare("Jesus") == .orderedSame
    }
}

enum SpeakOverLink {

    /// Query keys. Short, because the whole gift rides in the URL.
    enum Key {
        static let text = "so_t"
        static let book = "so_b"
        static let from = "so_from"
        static let to = "so_to"
    }

    /// The longest declaration in the set is about 210 characters.
    static let maxTextLength = 280
    static let maxNameLength = 30
    static let maxBookLength = 40

    // MARK: - Build

    /// The link a gift is sent as.
    ///
    /// Text is capped rather than refused here: the sender picked a real
    /// declaration, and a link that opens the app is still better than none.
    /// If the text cleans down to nothing, the gift keys are left off and the
    /// link simply opens SpeakLife.
    static func url(text: String, book: String?, from: String?, to: String?,
                    campaign: String?) -> URL {
        var extra: [URLQueryItem] = []
        if let text = clean(text, limit: maxTextLength) {
            extra.append(URLQueryItem(name: Key.text, value: text))
            if let book = clean(book, limit: maxBookLength) {
                extra.append(URLQueryItem(name: Key.book, value: book))
            }
            if let from = clean(from, limit: maxNameLength) {
                extra.append(URLQueryItem(name: Key.from, value: from))
            }
            if let to = clean(to, limit: maxNameLength) {
                extra.append(URLQueryItem(name: Key.to, value: to))
            }
        }
        return ReferralLink.url(.speakOver, campaign: campaign, extra: extra)
    }

    // MARK: - Parse

    /// The gift in a URL, or nil when this is not a gift link.
    ///
    /// Reads query items only, so the universal link, a `speaklife://` open
    /// and any future host all parse the same way. Never reads the path, which
    /// is what keeps it apart from `StandLink`.
    static func parse(_ url: URL) -> SpeakOverGift? {
        guard let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else {
            return nil
        }
        var values: [String: String] = [:]
        // First occurrence wins, so a key appended to the end cannot override.
        for item in items where values[item.name] == nil {
            if let value = item.value { values[item.name] = value }
        }
        return gift(from: values)
    }

    /// The gift in a Branch session, for the fresh-install path.
    ///
    /// Branch hands a long link's query parameters back as top-level link
    /// data. `~referring_link` is the fallback for a session that carries the
    /// link but not the keys.
    static func parse(branchParams params: [String: Any]) -> SpeakOverGift? {
        var values: [String: String] = [:]
        for key in [Key.text, Key.book, Key.from, Key.to] {
            if let value = params[key] as? String { values[key] = value }
        }
        if values[Key.text] != nil {
            return gift(from: values)
        }
        if let link = params["~referring_link"] as? String, let url = URL(string: link) {
            return parse(url)
        }
        return nil
    }

    /// Text that is empty, or longer than any link this app builds, is refused
    /// outright: that link was not made here. Names and the reference are only
    /// trimmed, because a long name is harmless.
    private static func gift(from values: [String: String]) -> SpeakOverGift? {
        guard let text = clean(values[Key.text], limit: nil),
              text.count <= maxTextLength,
              text.unicodeScalars.count <= maxTextLength * maxScalarsPerCharacter else { return nil }
        return SpeakOverGift(
            text: text,
            book: clean(values[Key.book], limit: maxBookLength),
            from: clean(values[Key.from], limit: maxNameLength),
            to: clean(values[Key.to], limit: maxNameLength)
        )
    }

    // MARK: - Verse

    /// The verse for a received line, when it is one of the app's own
    /// declarations, word for word. The link carries no verse (it would double
    /// its length), and a line someone typed has none to show, so anything
    /// that does not match exactly gets the reference alone. Local data only.
    static func verse(for gift: SpeakOverGift, in pool: [Declaration]) -> String? {
        let match = pool.first { declaration in
            declaration.category != .myOwn
                && declaration.text == gift.text
                && (gift.book == nil || declaration.book == gift.book)
        }
        guard let verse = match?.bibleVerseText?
            .trimmingCharacters(in: .whitespacesAndNewlines), !verse.isEmpty else { return nil }
        return verse
    }

    // MARK: - Cleaning

    /// Combining marks kept on one character. Real scripts (accents,
    /// Devanagari vowel signs, an emoji's variation selector) need one to
    /// three; stacks of dozens ("Zalgo" text) exist only to spill out of the
    /// layout.
    static let maxMarksPerCharacter = 3
    /// The caps above count characters, and one character can hold many
    /// scalars. This bounds the raw size too.
    static let maxScalarsPerCharacter = 3

    /// Zero-width non-joiner and joiner. Format characters, but load bearing:
    /// emoji sequences and Persian and Indic names are spelled with them.
    private static let keptFormatScalars: Set<UInt32> = [0x200C, 0x200D]

    /// Plain, single-line text, or nil when nothing is left.
    ///
    /// Control characters (newlines, tabs, bells) become spaces. Other
    /// invisible format characters (zero-width spaces, right-to-left
    /// overrides) are dropped, because they can make a line read differently
    /// from what it says. Combining marks are capped per character. Runs of
    /// whitespace collapse to one space.
    static func clean(_ raw: String?, limit: Int?) -> String? {
        guard let raw else { return nil }
        var scalars = String.UnicodeScalarView()
        var marksInARow = 0
        for scalar in raw.unicodeScalars {
            switch scalar.properties.generalCategory {
            case .control:
                marksInARow = 0
                scalars.append(Unicode.Scalar(UInt8(32)))
            case .format:
                if keptFormatScalars.contains(scalar.value) {
                    scalars.append(scalar)
                }
            case .nonspacingMark, .enclosingMark, .spacingMark:
                marksInARow += 1
                if marksInARow <= maxMarksPerCharacter {
                    scalars.append(scalar)
                }
            default:
                marksInARow = 0
                scalars.append(scalar)
            }
        }
        var text = String(scalars)
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
        if let limit {
            if text.count > limit {
                text = String(text.prefix(limit))
            }
            while text.unicodeScalars.count > limit * maxScalarsPerCharacter, !text.isEmpty {
                text.removeLast()
            }
            text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return text.isEmpty ? nil : text
    }
}

// MARK: - Copy

/// The words on both ends, kept together so they stay consistent and can be
/// tested. The sender is standing with the recipient: nothing here claims the
/// recipient will change.
enum SpeakOverCopy {

    static let sendTitle = "Send this to someone you're standing with"

    static func headline(from sender: String?) -> String {
        guard let sender, !sender.isEmpty else { return "Someone is standing with you" }
        return "\(sender) is standing with you"
    }

    /// Under the headline. Uses the recipient's name when the sender gave it.
    static func subline(to recipient: String?) -> String {
        guard let recipient, !recipient.isEmpty else { return "Speak this out loud today." }
        return "\(recipient), speak this out loud today."
    }

    /// The words that travel with the card in the share sheet.
    ///
    /// `ReferralShareText` adds the link for messaging apps only, so these
    /// must read as a finished thought on their own: a full stop, not a colon
    /// pointing at a link that may not be there.
    static func shareText(to recipient: String?) -> String {
        let line = "I'm standing with you on this one. Speak it out loud today."
        if let recipient, !recipient.isEmpty {
            return "\(recipient), \(line)"
        }
        return line
    }
}
