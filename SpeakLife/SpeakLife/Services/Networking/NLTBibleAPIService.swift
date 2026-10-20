//
//  NLTBibleAPIService.swift
//  SpeakLife
//
//  New Living Translation via Tyndale's NLT API (https://api.nlt.to).
//

import Foundation

/// The NLT is copyrighted, so unlike the public-domain translations it needs an
/// API key and an attribution notice. The key arrives through Remote Config
/// (`nlt_api_key`) so it is never compiled into the binary and can be rotated
/// without a release. Until it is set, NLT stays out of the version picker.
enum NLTConfig {
    static var apiKey: String = ""

    static let versionId = "nlt"

    static var isAvailable: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static func isNLT(_ version: String) -> Bool {
        version.lowercased() == versionId
    }

    /// Tyndale's standard notice for NLT text shown in an app.
    static let copyrightNotice = "Scripture quotations are taken from the Holy Bible, New Living Translation, copyright © 1996, 2004, 2015 by Tyndale House Foundation. Used by permission of Tyndale House Publishers, Carol Stream, Illinois 60188. All rights reserved."
}

final class NLTBibleAPIService {
    static let shared = NLTBibleAPIService()

    private let passagesURL = "https://api.nlt.to/api/passages"
    private let session: URLSession

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForRequest = 12
            configuration.timeoutIntervalForResource = 30
            // Offline caching is off until Tyndale confirms what the licence
            // allows, so keep URLSession from writing responses to disk too.
            configuration.urlCache = nil
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
            self.session = URLSession(configuration: configuration)
        }
    }

    func fetchChapter(abbrev: String, chapter: Int) async throws -> BibleChapter {
        let key = NLTConfig.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw BibleAPIError.unauthorized }

        let bookKey = BibleBookMapping.abbreviationToApiName[abbrev.lowercased()] ?? abbrev.lowercased()
        guard let bookInfo = BibleBookMapping.bookNames[bookKey] else { throw BibleAPIError.noData }

        var components = URLComponents(string: passagesURL)
        components?.queryItems = [
            URLQueryItem(name: "ref", value: "\(bookInfo.full) \(chapter)"),
            URLQueryItem(name: "version", value: "NLT"),
            URLQueryItem(name: "key", value: key)
        ]
        guard let url = components?.url else { throw BibleAPIError.invalidURL }

        let data: Data
        do {
            let (body, response) = try await session.data(from: url)
            if let httpResponse = response as? HTTPURLResponse {
                switch httpResponse.statusCode {
                case 200...299: break
                case 401, 403: throw BibleAPIError.unauthorized
                case 429: throw BibleAPIError.rateLimited
                default: throw BibleAPIError.serverError(httpResponse.statusCode)
                }
            }
            data = body
        } catch let error as BibleAPIError {
            throw error
        } catch is CancellationError {
            throw CancellationError()
        } catch let urlError as URLError where urlError.code == .cancelled {
            throw CancellationError()
        } catch {
            throw BibleAPIError.networkError(error)
        }

        guard let html = String(data: data, encoding: .utf8) else { throw BibleAPIError.noData }
        let verses = Self.parseVerses(html: html)

        // A blank chapter reads as the app being broken; fail so the reader
        // shows its error and retry instead.
        guard !verses.isEmpty else { throw BibleAPIError.noData }

        return BibleChapter(
            book: BibleBookInfo(
                abbrev: BibleBookAbbrev(pt: abbrev, en: abbrev),
                name: bookInfo.full,
                author: "",
                group: "",
                version: NLTConfig.versionId
            ),
            chapter: ChapterInfo(number: chapter, verses: verses.count),
            verses: verses
        )
    }

    // MARK: - HTML parsing

    /// The passages endpoint returns styled HTML, one `<verse_export vn="N">`
    /// block per verse, with verse numbers, footnotes, section headings and
    /// chapter labels mixed into the text. Its markup is not always well formed,
    /// so this splits on the verse tags rather than relying on closing tags.
    static func parseVerses(html: String) -> [BibleVerse] {
        var versesByNumber: [Int: String] = [:]

        for segment in html.components(separatedBy: "<verse_export").dropFirst() {
            guard let tagEnd = segment.firstIndex(of: ">") else { continue }
            let attributes = String(segment[..<tagEnd])
            guard let number = firstMatch(#"\bvn="(\d+)""#, in: attributes).flatMap({ Int($0) }) else { continue }

            var body = String(segment[segment.index(after: tagEnd)...])
            if let close = body.range(of: "</verse_export>") {
                body = String(body[..<close.lowerBound])
            }

            let text = cleanVerseText(body)
            guard !text.isEmpty else { continue }
            // A verse split across paragraphs can arrive as two blocks.
            if let existing = versesByNumber[number] {
                versesByNumber[number] = existing + " " + text
            } else {
                versesByNumber[number] = text
            }
        }

        return versesByNumber
            .map { BibleVerse(number: $0.key, text: $0.value) }
            .sorted { $0.number < $1.number }
    }

    private static func cleanVerseText(_ html: String) -> String {
        // Footnotes can hold nested spans (e.g. small-caps LORD), so a regex
        // would stop at the first inner </span> and leak footnote text.
        var text = removingSpans(withClass: "tn", from: html)
        let removals = [
            #"(?s)<a class="a-tn">.*?</a>"#,
            // Verse number and chapter labels.
            #"(?s)<span class="vn">.*?</span>"#,
            #"(?s)<span class="cw_ch">.*?</span>"#,
            #"(?s)<span class="cw">.*?</span>"#,
            // Section headings. Ended by the next tag rather than a closing tag,
            // since the API sometimes closes these with a bare <p>.
            #"(?s)<h\d[^>]*>.*?</h\d>"#,
            #"<p class="(?:subhead|chapter-number)[^"]*"[^>]*>[^<]*"#,
            // Everything else is presentation.
            #"<[^>]+>"#
        ]
        for pattern in removals {
            text = text.replacingOccurrences(of: pattern, with: " ", options: [.regularExpression, .caseInsensitive])
        }

        text = decodeEntities(text)
        text = text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        // Removing tags leaves a gap before punctuation that followed them.
        text = text.replacingOccurrences(of: #" +([,.;:!?’”)])"#, with: "$1", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Removes every `<span class="…">` with the given class, including any
    /// spans nested inside it.
    private static func removingSpans(withClass className: String, from html: String) -> String {
        let opener = "<span class=\"\(className)\">"
        var result = ""
        var rest = Substring(html)

        while let start = rest.range(of: opener) {
            result += rest[..<start.lowerBound]
            var cursor = start.upperBound
            var depth = 1
            while depth > 0 {
                let nextOpen = rest.range(of: "<span", range: cursor..<rest.endIndex)
                guard let nextClose = rest.range(of: "</span>", range: cursor..<rest.endIndex) else {
                    cursor = rest.endIndex
                    break
                }
                if let nextOpen, nextOpen.lowerBound < nextClose.lowerBound {
                    depth += 1
                    cursor = nextOpen.upperBound
                } else {
                    depth -= 1
                    cursor = nextClose.upperBound
                }
            }
            result += " "
            rest = rest[cursor...]
        }
        result += rest
        return result
    }

    private static let namedEntities: [String: String] = [
        "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": " ",
        "ldquo": "“", "rdquo": "”", "lsquo": "‘", "rsquo": "’",
        "mdash": "—", "ndash": "–", "hellip": "…", "thinsp": " ", "emsp": " ", "ensp": " "
    ]

    private static func decodeEntities(_ text: String) -> String {
        guard text.contains("&"),
              let regex = try? NSRegularExpression(pattern: "&(#x?[0-9a-fA-F]+|[a-zA-Z]+);") else { return text }

        var result = ""
        var cursor = text.startIndex
        for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let whole = Range(match.range, in: text),
                  let nameRange = Range(match.range(at: 1), in: text) else { continue }
            result += text[cursor..<whole.lowerBound]
            let name = String(text[nameRange])

            var replacement: String?
            if name.hasPrefix("#") {
                let isHex = name.dropFirst().first.map { $0 == "x" || $0 == "X" } ?? false
                let digits = name.dropFirst(isHex ? 2 : 1)
                if let code = UInt32(digits, radix: isHex ? 16 : 10), let scalar = Unicode.Scalar(code) {
                    replacement = String(Character(scalar))
                }
            } else {
                replacement = namedEntities[name.lowercased()]
            }
            result += replacement ?? String(text[whole])
            cursor = whole.upperBound
        }
        result += text[cursor...]
        return result
    }

    private static func firstMatch(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[range])
    }
}
