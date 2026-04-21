//
//  HelloAOBibleAPIService.swift
//  SpeakLife
//
//  Created by SpeakLife Team on 1/29/26.
//

import Foundation

// Import the existing Bible models
// Note: These models are defined in the main app's Bible/BibleModels.swift

// MARK: - HelloAO API Models

// Translation models
struct HelloAOTranslation: Codable {
    let id: String
    let name: String
    let shortName: String?
    let language: String
    let languageName: String
    let languageEnglishName: String
    let textDirection: String
    let numberOfBooks: Int
    let totalNumberOfChapters: Int
    let totalNumberOfVerses: Int
    let website: String?
    let licenseUrl: String?
}

// Book models (from /books.json endpoint)
struct HelloAOBook: Codable {
    let id: String
    let translationId: String
    let name: String
    let commonName: String
    let title: String
    let order: Int
    let numberOfChapters: Int
    let firstChapterNumber: Int
    let lastChapterNumber: Int
    let totalNumberOfVerses: Int
    let firstChapterApiLink: String
    let lastChapterApiLink: String
}

// Chapter response models (from /book/chapter.json endpoint)
struct HelloAOChapter: Codable {
    let translation: HelloAOChapterTranslationInfo
    let book: HelloAOChapterBookInfo
    let chapter: HelloAOChapterInfo
    let thisChapterLink: String
    let thisChapterAudioLinks: HelloAOAudioLinks?
    let nextChapterApiLink: String?
    let nextChapterAudioLinks: HelloAOAudioLinks?
    let previousChapterApiLink: String?
    let previousChapterAudioLinks: HelloAOAudioLinks?
    let numberOfVerses: Int
}

// Simplified models for chapter response
struct HelloAOChapterTranslationInfo: Codable {
    let id: String
    let name: String
    let website: String
    let language: String
    let textDirection: String
    let numberOfBooks: Int
    let totalNumberOfChapters: Int
    let totalNumberOfVerses: Int
}

struct HelloAOChapterBookInfo: Codable {
    let id: String
    let translationId: String
    let name: String
    let order: Int
    let numberOfChapters: Int
    let totalNumberOfVerses: Int
}

struct HelloAOChapterInfo: Codable {
    let number: Int
    let content: [HelloAOContent]
    let footnotes: [HelloAOFootnote]?
}

// Content models - simplified based on actual API
struct HelloAOContent: Codable {
    let type: String // "heading", "verse", "line_break"
    let number: Int? // Only present for verses
    let content: [HelloAOContentItem]? // Array of strings or objects
    
    enum CodingKeys: String, CodingKey {
        case type, number, content
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        number = try container.decodeIfPresent(Int.self, forKey: .number)
        
        // Content can be missing for line_break
        if type == "line_break" {
            content = nil
        } else {
            content = try container.decodeIfPresent([HelloAOContentItem].self, forKey: .content)
        }
    }
}

// Content item can be either string or footnote reference
enum HelloAOContentItem: Codable {
    case text(String)
    case footnoteRef(HelloAOFootnoteRef)
    case unknown // Handle unexpected content gracefully
    
    init(from decoder: Decoder) throws {
        // Try decoding as string first (most common case)
        if let string = try? decoder.singleValueContainer().decode(String.self) {
            self = .text(string)
            return
        }
        
        // Try decoding as footnote reference
        if let footnoteRef = try? decoder.singleValueContainer().decode(HelloAOFootnoteRef.self) {
            self = .footnoteRef(footnoteRef)
            return
        }
        
        // For any other type, just log and continue as unknown
        let codingPath = decoder.codingPath.map { $0.stringValue }.joined(separator: " -> ")
        self = .unknown
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let string):
            try container.encode(string)
        case .footnoteRef(let ref):
            try container.encode(ref)
        case .unknown:
            try container.encode("") // Encode as empty string
        }
    }
}

struct HelloAOFootnoteRef: Codable {
    let noteId: Int
}

struct HelloAOFootnote: Codable {
    let noteId: Int
    let caller: String
    let text: String
    let reference: HelloAOFootnoteReference
}

struct HelloAOFootnoteReference: Codable {
    let chapter: Int
    let verse: Int
}

// Audio links - simplified
struct HelloAOAudioLinks: Codable {
    let gilbert: String?
    let hays: String?
    let souer: String?
    
    // Custom decoding to handle any narrator names
    private struct DynamicCodingKeys: CodingKey {
        var stringValue: String
        init?(stringValue: String) {
            self.stringValue = stringValue
        }
        var intValue: Int? { return nil }
        init?(intValue: Int) { return nil }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)
        
        gilbert = try container.decodeIfPresent(String.self, forKey: DynamicCodingKeys(stringValue: "gilbert")!)
        hays = try container.decodeIfPresent(String.self, forKey: DynamicCodingKeys(stringValue: "hays")!)
        souer = try container.decodeIfPresent(String.self, forKey: DynamicCodingKeys(stringValue: "souer")!)
    }
}

// MARK: - Commentary Models
struct HelloAOCommentary: Codable {
    let id: String
    let name: String
    let language: String
    let languageName: String
    let languageEnglishName: String
}

struct HelloAODataset: Codable {
    let id: String
    let name: String
    let language: String
}

// MARK: - HelloAO API Service
final class HelloAOBibleAPIService {
    static let shared = HelloAOBibleAPIService()
    
    private let baseURL = "https://bible.helloao.org/api"
    private let session: URLSession
    private let defaultTranslation = "BSB" // Berean Standard Bible as default
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    // MARK: - Translation Endpoints
    
    /// Fetch all available Bible translations
    func fetchAvailableTranslations() async throws -> [HelloAOTranslation] {
        let url = "\(baseURL)/available_translations.json"
        return try await performRequest(url: url)
    }
    
    /// Fetch all books in a specific translation
    func fetchBooks(translation: String = "BSB") async throws -> [HelloAOBook] {
        let url = "\(baseURL)/\(translation)/books.json"
        return try await performRequest(url: url)
    }
    
    /// Fetch a specific chapter from a translation
    func fetchChapter(translation: String = "BSB", book: String, chapter: Int) async throws -> HelloAOChapter {
        let url = "\(baseURL)/\(translation)/\(book)/\(chapter).json"
        return try await performRequest(url: url)
    }
    
    // MARK: - Commentary Endpoints
    
    /// Fetch all available commentaries
    func fetchAvailableCommentaries() async throws -> [HelloAOCommentary] {
        let url = "\(baseURL)/available_commentaries.json"
        return try await performRequest(url: url)
    }
    
    /// Fetch books in a specific commentary
    func fetchCommentaryBooks(commentary: String) async throws -> [HelloAOBook] {
        let url = "\(baseURL)/c/\(commentary)/books.json"
        return try await performRequest(url: url)
    }
    
    /// Fetch a chapter from a commentary
    func fetchCommentaryChapter(commentary: String, book: String, chapter: Int) async throws -> HelloAOChapter {
        let url = "\(baseURL)/c/\(commentary)/\(book)/\(chapter).json"
        return try await performRequest(url: url)
    }
    
    // MARK: - Dataset Endpoints
    
    /// Fetch all available datasets
    func fetchAvailableDatasets() async throws -> [HelloAODataset] {
        let url = "\(baseURL)/available_datasets.json"
        return try await performRequest(url: url)
    }
    
    /// Fetch books in a specific dataset
    func fetchDatasetBooks(dataset: String) async throws -> [HelloAOBook] {
        let url = "\(baseURL)/d/\(dataset)/books.json"
        return try await performRequest(url: url)
    }
    
    /// Fetch a chapter from a dataset
    func fetchDatasetChapter(dataset: String, book: String, chapter: Int) async throws -> HelloAOChapter {
        let url = "\(baseURL)/d/\(dataset)/\(book)/\(chapter).json"
        return try await performRequest(url: url)
    }
    
    // MARK: - Additional Helper Methods
    
    /// Get a specific verse from a chapter
    func fetchVerse(translation: String = "BSB", book: String, chapter: Int, verse: Int) async throws -> BibleVerse? {
        let chapterData = try await fetchChapter(translation: translation, book: book, chapter: chapter)
        
        // Find the specific verse
        for content in chapterData.chapter.content {
            if content.type == "verse" && content.number == verse {
                let verseText = extractVerseText(from: content)
                return BibleVerse(number: verse, text: verseText)
            }
        }
        
        return nil
    }
    
    /// Get a range of verses from a chapter
    func fetchVerseRange(translation: String = "BSB", book: String, chapter: Int, startVerse: Int, endVerse: Int) async throws -> [BibleVerse] {
        let chapterData = try await fetchChapter(translation: translation, book: book, chapter: chapter)
        var verses: [BibleVerse] = []
        
        for content in chapterData.chapter.content {
            if content.type == "verse",
               let verseNumber = content.number,
               verseNumber >= startVerse && verseNumber <= endVerse {
                let verseText = extractVerseText(from: content)
                verses.append(BibleVerse(number: verseNumber, text: verseText))
            }
        }
        
        return verses
    }
    
    // MARK: - Search (Not directly supported, will need to implement client-side)
    func searchVerses(translation: String = "BSB", query: String) async throws -> BibleSearchResponse {
        // This API doesn't have a search endpoint, so we'd need to implement client-side search
        // For now, return empty response
        return BibleSearchResponse(
            occurrence: 0,
            version: translation.lowercased(),
            verses: []
        )
    }
    
    // MARK: - Private Methods
    private func performRequest<T: Decodable>(url urlString: String) async throws -> T {
        guard let url = URL(string: urlString) else {
            throw BibleAPIError.invalidURL
        }
        
        
        do {
            let (data, response) = try await session.data(from: url)
            
            // Check HTTP response
            if let httpResponse = response as? HTTPURLResponse {
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    throw BibleAPIError.serverError(httpResponse.statusCode)
                }
            }
            
            // Decode response
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
        } catch {
            throw BibleAPIError.networkError(error)
        }
    }
    
    // MARK: - Adapter Methods (Convert HelloAO models to existing app models)
    func adaptTranslationToBibleVersion(_ translation: HelloAOTranslation) -> BibleVersion {
        return BibleVersion(
            version: translation.id.lowercased(),
            verses: translation.totalNumberOfVerses
        )
    }
    
    func adaptBookToBibleBook(_ book: HelloAOBook) -> BibleBook {
        // Determine testament based on book order (1-39 = OT, 40-66 = NT)
        let testament: BibleBook.Testament = book.order <= 39 ? .old : .new
        
        return BibleBook(
            abbrev: BibleBookAbbrev(
                pt: book.id.lowercased(), // Use ID as Portuguese abbrev
                en: book.id.lowercased()  // Use ID as English abbrev
            ),
            author: "", // Not provided by this API
            chapters: book.numberOfChapters,
            group: determineBookGroup(book.name, testament: testament),
            name: book.name,
            testament: testament
        )
    }
    
    func adaptChapterToBibleChapter(_ helloChapter: HelloAOChapter, bookAbbrev: String) -> BibleChapter {
        // Extract verses from content
        var verses: [BibleVerse] = []
        
        for content in helloChapter.chapter.content {
            if content.type == "verse", let verseNumber = content.number {
                let verseText = extractVerseText(from: content)
                verses.append(BibleVerse(
                    number: verseNumber,
                    text: verseText
                ))
            }
        }
        
        return BibleChapter(
            book: BibleBookInfo(
                abbrev: BibleBookAbbrev(
                    pt: helloChapter.book.id.lowercased(),
                    en: helloChapter.book.id.lowercased()
                ),
                name: helloChapter.book.name,
                author: "", // Not provided
                group: determineBookGroup(helloChapter.book.name, testament: helloChapter.book.order <= 39 ? .old : .new),
                version: helloChapter.translation.id.lowercased()
            ),
            chapter: ChapterInfo(
                number: helloChapter.chapter.number,
                verses: helloChapter.numberOfVerses
            ),
            verses: verses
        )
    }
    
    private func extractVerseText(from content: HelloAOContent) -> String {
        guard let contentItems = content.content else { return "" }
        
        var textParts: [String] = []
        for item in contentItems {
            switch item {
            case .text(let text):
                textParts.append(text)
            case .footnoteRef(_):
                // Skip footnote references for now, or add a marker
                break
            case .unknown:
                // Skip unknown content types
                break
            }
        }
        
        return textParts.joined(separator: " ")
    }
    
    private func determineBookGroup(_ bookName: String, testament: BibleBook.Testament) -> String {
        // Simplified group determination based on book name
        if testament == .old {
            if ["Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy"].contains(bookName) {
                return "Pentateuch"
            } else if ["Joshua", "Judges", "Ruth", "1 Samuel", "2 Samuel", "1 Kings", "2 Kings", "1 Chronicles", "2 Chronicles", "Ezra", "Nehemiah", "Esther"].contains(bookName) {
                return "Historical"
            } else if ["Job", "Psalms", "Proverbs", "Ecclesiastes", "Song of Solomon"].contains(bookName) {
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
}