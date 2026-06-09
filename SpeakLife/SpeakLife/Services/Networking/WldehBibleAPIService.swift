//
//  WldehBibleAPIService.swift
//  SpeakLife
//
//  Created by SpeakLife Team
//

import Foundation

// MARK: - Wldeh Bible API Models

struct WldehBibleVersion: Codable {
    let id: String
    let version: String
    let description: String?
    let scope: String?
    let language: WldehLanguage
    let country: WldehCountry?
    let numeralSystem: String?
    let script: String?
    let archivist: String?
    let copyright: String?
    let localVersionName: String?
    let localVersionAbbreviation: String?
}

struct WldehLanguage: Codable {
    let name: String
    let code: String
    let level: String?
}

struct WldehCountry: Codable {
    let name: String
    let code: String
}

// For chapter endpoint - verses in array
struct WldehChapterVerse: Codable {
    let book: String
    let chapter: String
    let verse: String
    let text: String
}

struct WldehChapterResponse: Codable {
    let data: [WldehChapterVerse]
}

// For single verse endpoint
struct WldehSingleVerse: Codable {
    let verse: String
    let text: String
}

// MARK: - Book Name Mappings
struct BibleBookMapping {
    static let bookNames: [String: (full: String, order: Int, testament: BibleBook.Testament)] = [
        // Old Testament
        "genesis": ("Genesis", 1, .old),
        "exodus": ("Exodus", 2, .old),
        "leviticus": ("Leviticus", 3, .old),
        "numbers": ("Numbers", 4, .old),
        "deuteronomy": ("Deuteronomy", 5, .old),
        "joshua": ("Joshua", 6, .old),
        "judges": ("Judges", 7, .old),
        "ruth": ("Ruth", 8, .old),
        "1samuel": ("1 Samuel", 9, .old),
        "2samuel": ("2 Samuel", 10, .old),
        "1kings": ("1 Kings", 11, .old),
        "2kings": ("2 Kings", 12, .old),
        "1chronicles": ("1 Chronicles", 13, .old),
        "2chronicles": ("2 Chronicles", 14, .old),
        "ezra": ("Ezra", 15, .old),
        "nehemiah": ("Nehemiah", 16, .old),
        "esther": ("Esther", 17, .old),
        "job": ("Job", 18, .old),
        "psalms": ("Psalms", 19, .old),
        "proverbs": ("Proverbs", 20, .old),
        "ecclesiastes": ("Ecclesiastes", 21, .old),
        "songofsongs": ("Song of Songs", 22, .old),
        "isaiah": ("Isaiah", 23, .old),
        "jeremiah": ("Jeremiah", 24, .old),
        "lamentations": ("Lamentations", 25, .old),
        "ezekiel": ("Ezekiel", 26, .old),
        "daniel": ("Daniel", 27, .old),
        "hosea": ("Hosea", 28, .old),
        "joel": ("Joel", 29, .old),
        "amos": ("Amos", 30, .old),
        "obadiah": ("Obadiah", 31, .old),
        "jonah": ("Jonah", 32, .old),
        "micah": ("Micah", 33, .old),
        "nahum": ("Nahum", 34, .old),
        "habakkuk": ("Habakkuk", 35, .old),
        "zephaniah": ("Zephaniah", 36, .old),
        "haggai": ("Haggai", 37, .old),
        "zechariah": ("Zechariah", 38, .old),
        "malachi": ("Malachi", 39, .old),
        // New Testament
        "matthew": ("Matthew", 40, .new),
        "mark": ("Mark", 41, .new),
        "luke": ("Luke", 42, .new),
        "john": ("John", 43, .new),
        "acts": ("Acts", 44, .new),
        "romans": ("Romans", 45, .new),
        "1corinthians": ("1 Corinthians", 46, .new),
        "2corinthians": ("2 Corinthians", 47, .new),
        "galatians": ("Galatians", 48, .new),
        "ephesians": ("Ephesians", 49, .new),
        "philippians": ("Philippians", 50, .new),
        "colossians": ("Colossians", 51, .new),
        "1thessalonians": ("1 Thessalonians", 52, .new),
        "2thessalonians": ("2 Thessalonians", 53, .new),
        "1timothy": ("1 Timothy", 54, .new),
        "2timothy": ("2 Timothy", 55, .new),
        "titus": ("Titus", 56, .new),
        "philemon": ("Philemon", 57, .new),
        "hebrews": ("Hebrews", 58, .new),
        "james": ("James", 59, .new),
        "1peter": ("1 Peter", 60, .new),
        "2peter": ("2 Peter", 61, .new),
        "1john": ("1 John", 62, .new),
        "2john": ("2 John", 63, .new),
        "3john": ("3 John", 64, .new),
        "jude": ("Jude", 65, .new),
        "revelation": ("Revelation", 66, .new)
    ]
    
    static let abbreviationToApiName: [String: String] = [
        // Old Testament
        "gn": "genesis", "gen": "genesis",
        "ex": "exodus", "exo": "exodus",
        "lv": "leviticus", "lev": "leviticus",
        "nm": "numbers", "num": "numbers",
        "dt": "deuteronomy", "deu": "deuteronomy",
        "js": "joshua", "jos": "joshua",
        "jg": "judges", "jdg": "judges",
        "rt": "ruth", "rut": "ruth",
        "1sm": "1samuel", "1sa": "1samuel",
        "2sm": "2samuel", "2sa": "2samuel",
        "1rs": "1kings", "1ki": "1kings",
        "2rs": "2kings", "2ki": "2kings",
        "1cr": "1chronicles", "1ch": "1chronicles",
        "2cr": "2chronicles", "2ch": "2chronicles",
        "ed": "ezra", "ezr": "ezra",
        "ne": "nehemiah", "neh": "nehemiah",
        "et": "esther", "est": "esther",
        "jb": "job", "job": "job",
        "sl": "psalms", "psa": "psalms", "ps": "psalms",
        "pv": "proverbs", "pro": "proverbs",
        "ec": "ecclesiastes", "ecc": "ecclesiastes",
        "ct": "songofsongs", "sng": "songofsongs", "sos": "songofsongs",
        "is": "isaiah", "isa": "isaiah",
        "jr": "jeremiah", "jer": "jeremiah",
        "lm": "lamentations", "lam": "lamentations",
        "ez": "ezekiel", "ezk": "ezekiel",
        "dn": "daniel", "dan": "daniel",
        "os": "hosea", "hos": "hosea",
        "jl": "joel", "jol": "joel", "joe": "joel",
        "am": "amos", "amo": "amos",
        "ob": "obadiah", "oba": "obadiah",
        "jon": "jonah",
        "mq": "micah", "mic": "micah",
        "na": "nahum", "nam": "nahum", "nah": "nahum",
        "hc": "habakkuk", "hab": "habakkuk",
        "sf": "zephaniah", "zep": "zephaniah",
        "ag": "haggai", "hag": "haggai",
        "zc": "zechariah", "zec": "zechariah",
        "ml": "malachi", "mal": "malachi",
        // New Testament
        "mt": "matthew", "mat": "matthew",
        "mc": "mark", "mrk": "mark", "mk": "mark",
        "lc": "luke", "luk": "luke", "lk": "luke",
        "jo": "john", "jhn": "john", "jn": "john",
        "at": "acts", "act": "acts",
        "rm": "romans", "rom": "romans",
        "1co": "1corinthians", "1cor": "1corinthians",
        "2co": "2corinthians", "2cor": "2corinthians",
        "gl": "galatians", "gal": "galatians",
        "ef": "ephesians", "eph": "ephesians",
        "fp": "philippians", "php": "philippians", "phil": "philippians",
        "cl": "colossians", "col": "colossians",
        "1ts": "1thessalonians", "1th": "1thessalonians",
        "2ts": "2thessalonians", "2th": "2thessalonians",
        "1tm": "1timothy", "1ti": "1timothy",
        "2tm": "2timothy", "2ti": "2timothy",
        "tt": "titus", "tit": "titus",
        "fm": "philemon", "phm": "philemon",
        "hb": "hebrews", "heb": "hebrews",
        "tg": "james", "jas": "james",
        "1pe": "1peter", "1pet": "1peter",
        "2pe": "2peter", "2pet": "2peter",
        "1jo": "1john", "1jn": "1john",
        "2jo": "2john", "2jn": "2john",
        "3jo": "3john", "3jn": "3john",
        "jd": "jude", "jud": "jude",
        "ap": "revelation", "rev": "revelation"
    ]
    
    // Chapter counts for each book
    static let chapterCounts: [String: Int] = [
        "genesis": 50, "exodus": 40, "leviticus": 27, "numbers": 36, "deuteronomy": 34,
        "joshua": 24, "judges": 21, "ruth": 4, "1samuel": 31, "2samuel": 24,
        "1kings": 22, "2kings": 25, "1chronicles": 29, "2chronicles": 36, "ezra": 10,
        "nehemiah": 13, "esther": 10, "job": 42, "psalms": 150, "proverbs": 31,
        "ecclesiastes": 12, "songofsongs": 8, "isaiah": 66, "jeremiah": 52, "lamentations": 5,
        "ezekiel": 48, "daniel": 12, "hosea": 14, "joel": 3, "amos": 9,
        "obadiah": 1, "jonah": 4, "micah": 7, "nahum": 3, "habakkuk": 3,
        "zephaniah": 3, "haggai": 2, "zechariah": 14, "malachi": 4,
        "matthew": 28, "mark": 16, "luke": 24, "john": 21, "acts": 28,
        "romans": 16, "1corinthians": 16, "2corinthians": 13, "galatians": 6, "ephesians": 6,
        "philippians": 4, "colossians": 4, "1thessalonians": 5, "2thessalonians": 3, "1timothy": 6,
        "2timothy": 4, "titus": 3, "philemon": 1, "hebrews": 13, "james": 5,
        "1peter": 5, "2peter": 3, "1john": 5, "2john": 1, "3john": 1,
        "jude": 1, "revelation": 22
    ]
}

// MARK: - Wldeh Bible API Service
final class WldehBibleAPIService: BibleAPIServiceProtocol {
    static let shared = WldehBibleAPIService()
    
    private let baseURL = "https://cdn.jsdelivr.net/gh/wldeh/bible-api"
    private let session: URLSession
    private let defaultVersion = "en-kjv" // Default to KJV
    
    // Cache for versions and books since they don't change
    private var cachedVersions: [BibleVersion]?
    private var cachedWldehVersions: [WldehBibleVersion]?
    private var cachedBooks: [BibleBook]?
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    // MARK: - BibleAPIServiceProtocol Implementation
    
    func fetchBooks() async throws -> [BibleBook] {
        
        // Return cached books if available
        if let cachedBooks = cachedBooks {
            return cachedBooks
        }
        
        // Generate books from static mapping
        var books: [BibleBook] = []
        for (apiName, info) in BibleBookMapping.bookNames {
            let abbrevKey = BibleBookMapping.abbreviationToApiName.first(where: { $0.value == apiName })?.key ?? apiName
            let book = BibleBook(
                abbrev: BibleBookAbbrev(
                    pt: abbrevKey,
                    en: abbrevKey
                ),
                author: "", // Not provided by this API
                chapters: BibleBookMapping.chapterCounts[apiName] ?? 1,
                group: determineBookGroup(info.full, testament: info.testament),
                name: info.full,
                testament: info.testament
            )
            books.append(book)
        }
        
        // Sort by order
        books.sort { book1, book2 in
            let order1 = BibleBookMapping.bookNames.values.first(where: { $0.full == book1.name })?.order ?? 0
            let order2 = BibleBookMapping.bookNames.values.first(where: { $0.full == book2.name })?.order ?? 0
            return order1 < order2
        }
        
        cachedBooks = books
        return books
    }
    
    func fetchBook(abbrev: String) async throws -> BibleBook {
        let books = try await fetchBooks()
        guard let book = books.first(where: { $0.abbrev.en == abbrev || $0.abbrev.pt == abbrev }) else {
            throw BibleAPIError.noData
        }
        return book
    }
    
    func fetchChapter(version: String, abbrev: String, chapter: Int) async throws -> BibleChapter {
        // Convert abbreviation to API book name
        let bookName = BibleBookMapping.abbreviationToApiName[abbrev.lowercased()] ?? abbrev.lowercased()
        
        // Map version to Wldeh format (e.g., "kjv" -> "en-kjv")
        let wldehVersion = mapToWldehVersion(version)
        
        let url = "\(baseURL)/bibles/\(wldehVersion)/books/\(bookName)/chapters/\(chapter).json"
        
        let response: WldehChapterResponse = try await performRequest(url: url)
        
        // Convert to app's BibleChapter model
        return convertToBibleChapter(response, abbrev: abbrev, version: version, chapter: chapter)
    }
    
    func fetchVersions() async throws -> [BibleVersion] {
        
        // Return cached versions if available
        if let cachedVersions = cachedVersions {
            return cachedVersions
        }
        
        // Only return the three allowed versions
        let allowedVersions = [
            BibleVersion(
                version: "asv",
                verses: 31102 // Standard Bible verse count
            ),
            BibleVersion(
                version: "kjv", 
                verses: 31102 // Standard Bible verse count
            ),
            BibleVersion(
                version: "web",
                verses: 31102 // Standard Bible verse count
            )
        ]
        
        cachedVersions = allowedVersions
        return allowedVersions
    }
    
    func searchVerses(version: String, query: String) async throws -> BibleSearchResponse {
        
        // For client-side search, we would need to:
        // 1. Cache chapters as they're loaded
        // 2. Search through cached content
        // 3. Or load all books/chapters (expensive)
        
        // For now, return empty response
        return BibleSearchResponse(
            occurrence: 0,
            version: version,
            verses: []
        )
    }
    
    func fetchRandomVerse(version: String) async throws -> RandomVerse {
        
        // Use day of year as seed for consistent daily verse
        let calendar = Calendar.current
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: Date()) ?? 1
        
        // Use a curated list of popular books to avoid empty chapters
        let popularBooks = ["genesis", "psalms", "proverbs", "matthew", "john", "romans", "1corinthians", "ephesians", "philippians", "james"]
        
        // Use day of year to select book deterministically (same for all users on same day)
        let bookIndex = (dayOfYear - 1) % popularBooks.count
        let selectedBook = popularBooks[bookIndex]
        
        // Use safer chapter ranges for known books
        let safeChapterRanges: [String: Int] = [
            "genesis": min(10, BibleBookMapping.chapterCounts["genesis"] ?? 1),
            "psalms": 23,  // Popular psalms
            "proverbs": min(10, BibleBookMapping.chapterCounts["proverbs"] ?? 1),
            "matthew": min(10, BibleBookMapping.chapterCounts["matthew"] ?? 1),
            "john": min(10, BibleBookMapping.chapterCounts["john"] ?? 1),
            "romans": min(8, BibleBookMapping.chapterCounts["romans"] ?? 1),
            "1corinthians": min(13, BibleBookMapping.chapterCounts["1corinthians"] ?? 1),
            "ephesians": min(6, BibleBookMapping.chapterCounts["ephesians"] ?? 1),
            "philippians": min(4, BibleBookMapping.chapterCounts["philippians"] ?? 1),
            "james": min(5, BibleBookMapping.chapterCounts["james"] ?? 1)
        ]
        
        let maxChapter = safeChapterRanges[selectedBook] ?? 1
        
        // Use day of year to select chapter deterministically
        let chapterIndex = ((dayOfYear - 1) / popularBooks.count) % maxChapter
        let selectedChapter = chapterIndex + 1
        
        
        // Fetch the chapter
        let abbrev = BibleBookMapping.abbreviationToApiName.first(where: { $0.value == selectedBook })?.key ?? selectedBook
        let chapter = try await fetchChapter(version: version, abbrev: abbrev, chapter: selectedChapter)
        
        // Filter out empty verses
        let nonEmptyVerses = chapter.verses.filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        
        // Select verse deterministically based on day of year
        let verseIndex = dayOfYear % max(nonEmptyVerses.count, 1)
        guard let selectedVerse = nonEmptyVerses.indices.contains(verseIndex) ? nonEmptyVerses[verseIndex] : nonEmptyVerses.first else {
            // Fallback to John 3:16
            return RandomVerse(
                book: BibleBookInfo(
                    abbrev: BibleBookAbbrev(pt: "jn", en: "jn"),
                    name: "John",
                    author: "John",
                    group: "Gospel",
                    version: version
                ),
                chapter: 3,
                number: 16,
                text: "For God so loved the world, that he gave his only begotten Son, that whosoever believeth in him should not perish, but have everlasting life."
            )
        }
        
        
        return RandomVerse(
            book: chapter.book,
            chapter: selectedChapter,
            number: selectedVerse.number,
            text: selectedVerse.text
        )
    }
    
    func createUser(email: String, name: String, password: String, notifications: Bool) async throws -> BibleUserToken {
        // This API doesn't support user authentication
        throw BibleAPIError.serverError(501) // Not Implemented
    }
    
    func loginUser(email: String, password: String) async throws -> BibleUserToken {
        // This API doesn't support user authentication
        throw BibleAPIError.serverError(501) // Not Implemented
    }
    
    // MARK: - Private Methods
    
    private func performRequest<T: Decodable>(url urlString: String) async throws -> T {
        guard let url = URL(string: urlString) else {
            throw BibleAPIError.invalidURL
        }
        
        do {
            let (data, response) = try await session.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse {
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    throw BibleAPIError.serverError(httpResponse.statusCode)
                }
            }
            
            do {
                let decoder = JSONDecoder()
                let result = try decoder.decode(T.self, from: data)
                return result
            } catch {
                if let responseString = String(data: data, encoding: .utf8) {
                }
                throw BibleAPIError.decodingError(error)
            }
        } catch let error as BibleAPIError {
            throw error
        } catch is CancellationError {
            // The Task driving this request was cancelled (e.g. the user tapped
            // a new chapter before the previous load finished). This is not a
            // connectivity failure, so surface it as cancellation so callers can
            // ignore it instead of showing a false "No internet" alert.
            throw CancellationError()
        } catch let urlError as URLError where urlError.code == .cancelled {
            throw CancellationError()
        } catch {
            throw BibleAPIError.networkError(error)
        }
    }

    private func mapToWldehVersion(_ version: String) -> String {
        // Map common version abbreviations to Wldeh format
        let versionLower = version.lowercased()
        
        // Check if it already has the language prefix
        if versionLower.hasPrefix("en-") {
            return versionLower
        }
        
        // Common English versions
        switch versionLower {
        case "kjv": return "en-kjv"
        case "asv": return "en-asv"
        case "bbe": return "en-bbe"
        case "darby": return "en-darby"
        case "douay": return "en-douay"
        case "erv": return "en-erv"
        case "gnv": return "en-gnv"
        case "kjv1900": return "en-kjv1900"
        case "web": return "en-web"
        case "ylt": return "en-ylt"
        default: return "en-\(versionLower)"
        }
    }
    
    private func convertToBibleChapter(_ response: WldehChapterResponse, abbrev: String, version: String, chapter: Int) -> BibleChapter {
        // Get book info from mapping
        let bookName = BibleBookMapping.abbreviationToApiName[abbrev.lowercased()] ?? abbrev.lowercased()
        let bookInfo = BibleBookMapping.bookNames[bookName] ?? ("Unknown", 1, .old)
        
        // Convert verses - remove duplicates and sort by verse number
        var uniqueVerses: [Int: BibleVerse] = [:]
        for wldehVerse in response.data {
            if let verseNum = Int(wldehVerse.verse) {
                let cleanedText = cleanVerseText(wldehVerse.text)
                uniqueVerses[verseNum] = BibleVerse(
                    number: verseNum,
                    text: cleanedText
                )
            }
        }
        
        let verses = uniqueVerses.values.sorted { $0.number < $1.number }
        
        return BibleChapter(
            book: BibleBookInfo(
                abbrev: BibleBookAbbrev(pt: abbrev, en: abbrev),
                name: bookInfo.full,
                author: "",
                group: determineBookGroup(bookInfo.full, testament: bookInfo.testament),
                version: version
            ),
            chapter: ChapterInfo(
                number: chapter,
                verses: verses.count
            ),
            verses: verses
        )
    }
    
    private func determineBookGroup(_ bookName: String, testament: BibleBook.Testament) -> String {
        if testament == .old {
            if ["Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy"].contains(bookName) {
                return "Pentateuch"
            } else if ["Joshua", "Judges", "Ruth", "1 Samuel", "2 Samuel", "1 Kings", "2 Kings", "1 Chronicles", "2 Chronicles", "Ezra", "Nehemiah", "Esther"].contains(bookName) {
                return "Historical"
            } else if ["Job", "Psalms", "Proverbs", "Ecclesiastes", "Song of Songs"].contains(bookName) {
                return "Poetic"
            } else {
                return "Prophetic"
            }
        } else {
            if ["Matthew", "Mark", "Luke", "John"].contains(bookName) {
                return "Gospel"
            } else if bookName == "Acts" {
                return "Historical"
            } else if bookName == "Revelation" {
                return "Prophetic"
            } else {
                return "Epistle"
            }
        }
    }
    
    // MARK: - Additional Helper Methods
    
    private func cleanVerseText(_ text: String) -> String {
        var cleanedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove paragraph markers
        cleanedText = cleanedText.replacingOccurrences(of: "¶", with: "")
        
        // First, let's identify and preserve the main text by finding where annotations start
        // Annotations often start with a verse reference like "1.1" or contain "Heb." or "Gr."
        
        // Split by potential annotation markers but preserve the main text
        if let hebrewRange = cleanedText.range(of: "Heb.", options: .caseInsensitive) {
            // Keep only text before Hebrew annotations
            cleanedText = String(cleanedText[..<hebrewRange.lowerBound])
        }
        
        if let greekRange = cleanedText.range(of: "Gr.", options: .caseInsensitive) {
            // Keep only text before Greek annotations
            cleanedText = String(cleanedText[..<greekRange.lowerBound])
        }
        
        // Remove verse cross-references (like "1.15" that appear after the main text)
        // Look for pattern: period followed by number.number
        cleanedText = cleanedText.replacingOccurrences(
            of: #"\.(\d+\.\d+.*?)$"#,
            with: ".",
            options: .regularExpression
        )
        
        // Remove any non-ASCII characters (Hebrew/Greek text)
        cleanedText = cleanedText.replacingOccurrences(
            of: #"[^\x00-\x7F]+"#,
            with: "",
            options: .regularExpression
        )
        
        // Remove corrupted patterns
        cleanedText = cleanedText.replacingOccurrences(of: "Aa h", with: "")
        
        // Fix spacing issues - ensure periods are followed by space
        cleanedText = cleanedText.replacingOccurrences(
            of: #"\.(?=[A-Z])"#,
            with: ". ",
            options: .regularExpression
        )
        
        // Fix colons and semicolons spacing
        cleanedText = cleanedText.replacingOccurrences(
            of: #"[:;](?=[A-Z])"#,
            with: ": ",
            options: .regularExpression
        )
        
        // Clean up multiple spaces
        cleanedText = cleanedText.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        
        // Final trim
        cleanedText = cleanedText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return cleanedText
    }
    
    func fetchVerse(version: String, book: String, chapter: Int, verse: Int) async throws -> BibleVerse? {
        let wldehVersion = mapToWldehVersion(version)
        let bookName = BibleBookMapping.abbreviationToApiName[book.lowercased()] ?? book.lowercased()
        
        let url = "\(baseURL)/bibles/\(wldehVersion)/books/\(bookName)/chapters/\(chapter)/verses/\(verse).json"
        
        let singleVerse: WldehSingleVerse = try await performRequest(url: url)
        
        return BibleVerse(
            number: Int(singleVerse.verse) ?? verse,
            text: cleanVerseText(singleVerse.text)
        )
    }
}