//
//  BibleInteractor.swift
//  SpeakLife
//
//  Created by SpeakLife Team on 1/28/26.
//

import Foundation
import Combine

protocol BibleInteractorProtocol {
    func loadBooks() async throws -> [BibleBook]
    func loadChapter(bookAbbrev: String, chapter: Int, version: String) async throws -> BibleChapter
    func searchVerses(query: String, version: String) async throws -> BibleSearchResponse
    func getRandomVerse(version: String) async throws -> RandomVerse
    func loadVersions() async throws -> [BibleVersion]
    
    // Bookmark operations
    func addBookmark(_ bookmark: BibleBookmark)
    func removeBookmark(_ bookmark: BibleBookmark)
    func getBookmarks() -> [BibleBookmark]
    func isBookmarked(bookAbbrev: String, chapter: Int, verse: Int) -> Bool
    
    // Highlight operations
    func addHighlight(_ highlight: BibleHighlight)
    func removeHighlight(_ highlight: BibleHighlight)
    func getHighlights(for bookAbbrev: String, chapter: Int) -> [BibleHighlight]
    
    // Reading history
    func saveReadingHistory(bookAbbrev: String, chapter: Int)
    func getReadingHistory() -> [(book: String, chapter: Int, date: Date)]
    func getLastReadLocation() -> (book: String, chapter: Int)?
    
    // Cache management
    func clearCache()
    func getCacheSize() -> Int64
}

final class BibleInteractor: BibleInteractorProtocol {
    private let apiService: BibleAPIServiceProtocol
    private let cacheManager: BibleCacheManager
    private let userDefaults = UserDefaults.standard
    
    // Keys for UserDefaults
    private let bookmarksKey = "BibleBookmarks"
    private let highlightsKey = "BibleHighlights"
    private let readingHistoryKey = "BibleReadingHistory"
    private let lastReadKey = "BibleLastRead"
    
    init(apiService: BibleAPIServiceProtocol = BibleAPIService.shared) {
        self.apiService = apiService
        self.cacheManager = BibleCacheManager()
    }
    
    // MARK: - API Operations
    func loadBooks() async throws -> [BibleBook] {
        // Check cache first
        if let cachedBooks = cacheManager.getCachedBooks() {
            return cachedBooks
        }
        
        // Try to fetch from API
        do {
            let books = try await apiService.fetchBooks()
            
            // Cache the result
            cacheManager.cacheBooks(books)
            
            return books
        } catch {
            print("RWRW ⚠️ API failed, using fallback books: \(error)")
            // If API fails, return fallback books
            let fallbackBooks = getFallbackBooks()
            // Cache the fallback books so they're available offline
            cacheManager.cacheBooks(fallbackBooks)
            return fallbackBooks
        }
    }
    
    // MARK: - Fallback Data
    private func getFallbackBooks() -> [BibleBook] {
        return [
            // Old Testament
            BibleBook(
                abbrev: BibleBookAbbrev(pt: "gn", en: "gen"),
                author: "Moses",
                chapters: 50,
                group: "Pentateuch",
                name: "Genesis",
                testament: .old
            ),
            BibleBook(
                abbrev: BibleBookAbbrev(pt: "ex", en: "exo"),
                author: "Moses", 
                chapters: 40,
                group: "Pentateuch",
                name: "Exodus",
                testament: .old
            ),
            BibleBook(
                abbrev: BibleBookAbbrev(pt: "lv", en: "lev"),
                author: "Moses",
                chapters: 27,
                group: "Pentateuch",
                name: "Leviticus",
                testament: .old
            ),
            BibleBook(
                abbrev: BibleBookAbbrev(pt: "nm", en: "num"),
                author: "Moses",
                chapters: 36,
                group: "Pentateuch",
                name: "Numbers",
                testament: .old
            ),
            BibleBook(
                abbrev: BibleBookAbbrev(pt: "dt", en: "deu"),
                author: "Moses",
                chapters: 34,
                group: "Pentateuch",
                name: "Deuteronomy",
                testament: .old
            ),
            BibleBook(
                abbrev: BibleBookAbbrev(pt: "js", en: "jos"),
                author: "Joshua",
                chapters: 24,
                group: "Historical",
                name: "Joshua",
                testament: .old
            ),
            BibleBook(
                abbrev: BibleBookAbbrev(pt: "jz", en: "jdg"),
                author: "Samuel",
                chapters: 21,
                group: "Historical",
                name: "Judges",
                testament: .old
            ),
            BibleBook(
                abbrev: BibleBookAbbrev(pt: "rt", en: "rut"),
                author: "Samuel",
                chapters: 4,
                group: "Historical",
                name: "Ruth",
                testament: .old
            ),
            BibleBook(
                abbrev: BibleBookAbbrev(pt: "1sm", en: "1sa"),
                author: "Samuel",
                chapters: 31,
                group: "Historical",
                name: "1 Samuel",
                testament: .old
            ),
            BibleBook(
                abbrev: BibleBookAbbrev(pt: "2sm", en: "2sa"),
                author: "Samuel",
                chapters: 24,
                group: "Historical",
                name: "2 Samuel",
                testament: .old
            ),
            BibleBook(
                abbrev: BibleBookAbbrev(pt: "1rs", en: "1ki"),
                author: "Jeremiah",
                chapters: 22,
                group: "Historical",
                name: "1 Kings",
                testament: .old
            ),
            BibleBook(
                abbrev: BibleBookAbbrev(pt: "2rs", en: "2ki"),
                author: "Jeremiah",
                chapters: 25,
                group: "Historical",
                name: "2 Kings",
                testament: .old
            ),
            BibleBook(
                abbrev: BibleBookAbbrev(pt: "1cr", en: "1ch"),
                author: "Ezra",
                chapters: 29,
                group: "Historical",
                name: "1 Chronicles",
                testament: .old
            ),
            BibleBook(
                abbrev: BibleBookAbbrev(pt: "2cr", en: "2ch"),
                author: "Ezra",
                chapters: 36,
                group: "Historical",
                name: "2 Chronicles",
                testament: .old
            ),
            BibleBook(
                abbrev: BibleBookAbbrev(pt: "ed", en: "ezr"),
                author: "Ezra",
                chapters: 10,
                group: "Historical",
                name: "Ezra",
                testament: .old
            ),
            BibleBook(
                abbrev: BibleBookAbbrev(pt: "ne", en: "neh"),
                author: "Nehemiah",
                chapters: 13,
                group: "Historical",
                name: "Nehemiah",
                testament: .old
            ),
            BibleBook(
                abbrev: BibleBookAbbrev(pt: "et", en: "est"),
                author: "Mordecai",
                chapters: 10,
                group: "Historical",
                name: "Esther",
                testament: .old
            ),
            BibleBook(
                abbrev: BibleBookAbbrev(pt: "job", en: "job"),
                author: "Job",
                chapters: 42,
                group: "Wisdom",
                name: "Job",
                testament: .old
            ),
            BibleBook(
                abbrev: BibleBookAbbrev(pt: "sl", en: "psa"),
                author: "David",
                chapters: 150,
                group: "Wisdom",
                name: "Psalms",
                testament: .old
            ),
            BibleBook(
                abbrev: BibleBookAbbrev(pt: "pv", en: "pro"),
                author: "Solomon",
                chapters: 31,
                group: "Wisdom",
                name: "Proverbs",
                testament: .old
            ),
            BibleBook(
                abbrev: BibleBookAbbrev(pt: "ec", en: "ecc"),
                author: "Solomon",
                chapters: 12,
                group: "Wisdom",
                name: "Ecclesiastes",
                testament: .old
            ),
            BibleBook(
                abbrev: BibleBookAbbrev(pt: "ct", en: "sng"),
                author: "Solomon",
                chapters: 8,
                group: "Wisdom",
                name: "Song of Songs",
                testament: .old
            ),
            BibleBook(
                abbrev: BibleBookAbbrev(pt: "is", en: "isa"),
                author: "Isaiah",
                chapters: 66,
                group: "Major Prophets",
                name: "Isaiah",
                testament: .old
            ),
            BibleBook(
                abbrev: BibleBookAbbrev(pt: "jr", en: "jer"),
                author: "Jeremiah",
                chapters: 52,
                group: "Major Prophets",
                name: "Jeremiah",
                testament: .old
            ),
            BibleBook(
                abbrev: BibleBookAbbrev(pt: "lm", en: "lam"),
                author: "Jeremiah",
                chapters: 5,
                group: "Major Prophets",
                name: "Lamentations",
                testament: .old
            ),
            BibleBook(
                abbrev: BibleBookAbbrev(pt: "ez", en: "ezk"),
                author: "Ezekiel",
                chapters: 48,
                group: "Major Prophets",
                name: "Ezekiel",
                testament: .old
            ),
            BibleBook(
                abbrev: BibleBookAbbrev(pt: "dn", en: "dan"),
                author: "Daniel",
                chapters: 12,
                group: "Major Prophets",
                name: "Daniel",
                testament: .old
            ),
            BibleBook(
                abbrev: BibleBookAbbrev(pt: "os", en: "hos"),
                author: "Hosea",
                chapters: 14,
                group: "Minor Prophets",
                name: "Hosea",
                testament: .old
            ),
            BibleBook(
                abbrev: BibleBookAbbrev(pt: "jl", en: "joe"),
                author: "Joel",
                chapters: 3,
                group: "Minor Prophets",
                name: "Joel",
                testament: .old
            ),
            BibleBook(
                abbrev: BibleBookAbbrev(pt: "am", en: "amo"),
                author: "Amos",
                chapters: 9,
                group: "Minor Prophets",
                name: "Amos",
                testament: .old
            ),
            BibleBook(
                abbrev: BibleBookAbbrev(pt: "ob", en: "oba"),
                author: "Obadiah",
                chapters: 1,
                group: "Minor Prophets",
                name: "Obadiah",
                testament: .old
            ),
            BibleBook(
                abbrev: BibleBookAbbrev(pt: "jn", en: "jon"),
                author: "Jonah",
                chapters: 4,
                group: "Minor Prophets",
                name: "Jonah",
                testament: .old
            ),
            BibleBook(
                abbrev: BibleBookAbbrev(pt: "mq", en: "mic"),
                author: "Micah",
                chapters: 7,
                group: "Minor Prophets",
                name: "Micah",
                testament: .old
            ),
            BibleBook(
                abbrev: BibleBookAbbrev(pt: "na", en: "nam"),
                author: "Nahum",
                chapters: 3,
                group: "Minor Prophets",
                name: "Nahum",
                testament: .old
            ),
            BibleBook(
                abbrev: BibleBookAbbrev(pt: "hc", en: "hab"),
                author: "Habakkuk",
                chapters: 3,
                group: "Minor Prophets",
                name: "Habakkuk",
                testament: .old
            ),
            BibleBook(
                abbrev: BibleBookAbbrev(pt: "sf", en: "zep"),
                author: "Zephaniah",
                chapters: 3,
                group: "Minor Prophets",
                name: "Zephaniah",
                testament: .old
            ),
            BibleBook(
                abbrev: BibleBookAbbrev(pt: "ag", en: "hag"),
                author: "Haggai",
                chapters: 2,
                group: "Minor Prophets",
                name: "Haggai",
                testament: .old
            ),
            BibleBook(
                abbrev: BibleBookAbbrev(pt: "zc", en: "zec"),
                author: "Zechariah",
                chapters: 14,
                group: "Minor Prophets",
                name: "Zechariah",
                testament: .old
            ),
            BibleBook(
                abbrev: BibleBookAbbrev(pt: "ml", en: "mal"),
                author: "Malachi",
                chapters: 4,
                group: "Minor Prophets",
                name: "Malachi",
                testament: .old
            ),
            
            // New Testament
            BibleBook(
                abbrev: BibleBookAbbrev(pt: "mt", en: "mat"),
                author: "Matthew",
                chapters: 28,
                group: "Gospels",
                name: "Matthew",
                testament: .new
            ),
            BibleBook(
                abbrev: BibleBookAbbrev(pt: "mc", en: "mrk"),
                author: "Mark",
                chapters: 16,
                group: "Gospels",
                name: "Mark",
                testament: .new
            ),
            BibleBook(
                abbrev: BibleBookAbbrev(pt: "lc", en: "luk"),
                author: "Luke",
                chapters: 24,
                group: "Gospels",
                name: "Luke",
                testament: .new
            ),
            BibleBook(
                abbrev: BibleBookAbbrev(pt: "jo", en: "jhn"),
                author: "John",
                chapters: 21,
                group: "Gospels",
                name: "John",
                testament: .new
            ),
            BibleBook(
                abbrev: BibleBookAbbrev(pt: "at", en: "act"),
                author: "Luke",
                chapters: 28,
                group: "History",
                name: "Acts",
                testament: .new
            ),
            BibleBook(
                abbrev: BibleBookAbbrev(pt: "rm", en: "rom"),
                author: "Paul",
                chapters: 16,
                group: "Pauline Epistles",
                name: "Romans",
                testament: .new
            ),
            BibleBook(
                abbrev: BibleBookAbbrev(pt: "1co", en: "1co"),
                author: "Paul",
                chapters: 16,
                group: "Pauline Epistles",
                name: "1 Corinthians",
                testament: .new
            ),
            BibleBook(
                abbrev: BibleBookAbbrev(pt: "2co", en: "2co"),
                author: "Paul",
                chapters: 13,
                group: "Pauline Epistles",
                name: "2 Corinthians",
                testament: .new
            ),
            BibleBook(
                abbrev: BibleBookAbbrev(pt: "gl", en: "gal"),
                author: "Paul",
                chapters: 6,
                group: "Pauline Epistles",
                name: "Galatians",
                testament: .new
            ),
            BibleBook(
                abbrev: BibleBookAbbrev(pt: "ef", en: "eph"),
                author: "Paul",
                chapters: 6,
                group: "Pauline Epistles",
                name: "Ephesians",
                testament: .new
            ),
            BibleBook(
                abbrev: BibleBookAbbrev(pt: "fp", en: "php"),
                author: "Paul",
                chapters: 4,
                group: "Pauline Epistles",
                name: "Philippians",
                testament: .new
            ),
            BibleBook(
                abbrev: BibleBookAbbrev(pt: "cl", en: "col"),
                author: "Paul",
                chapters: 4,
                group: "Pauline Epistles",
                name: "Colossians",
                testament: .new
            ),
            BibleBook(
                abbrev: BibleBookAbbrev(pt: "1ts", en: "1th"),
                author: "Paul",
                chapters: 5,
                group: "Pauline Epistles",
                name: "1 Thessalonians",
                testament: .new
            ),
            BibleBook(
                abbrev: BibleBookAbbrev(pt: "2ts", en: "2th"),
                author: "Paul",
                chapters: 3,
                group: "Pauline Epistles",
                name: "2 Thessalonians",
                testament: .new
            ),
            BibleBook(
                abbrev: BibleBookAbbrev(pt: "1tm", en: "1ti"),
                author: "Paul",
                chapters: 6,
                group: "Pastoral Epistles",
                name: "1 Timothy",
                testament: .new
            ),
            BibleBook(
                abbrev: BibleBookAbbrev(pt: "2tm", en: "2ti"),
                author: "Paul",
                chapters: 4,
                group: "Pastoral Epistles",
                name: "2 Timothy",
                testament: .new
            ),
            BibleBook(
                abbrev: BibleBookAbbrev(pt: "tt", en: "tit"),
                author: "Paul",
                chapters: 3,
                group: "Pastoral Epistles",
                name: "Titus",
                testament: .new
            ),
            BibleBook(
                abbrev: BibleBookAbbrev(pt: "fm", en: "phm"),
                author: "Paul",
                chapters: 1,
                group: "Pastoral Epistles",
                name: "Philemon",
                testament: .new
            ),
            BibleBook(
                abbrev: BibleBookAbbrev(pt: "hb", en: "heb"),
                author: "Paul",
                chapters: 13,
                group: "General Epistles",
                name: "Hebrews",
                testament: .new
            ),
            BibleBook(
                abbrev: BibleBookAbbrev(pt: "tg", en: "jas"),
                author: "James",
                chapters: 5,
                group: "General Epistles",
                name: "James",
                testament: .new
            ),
            BibleBook(
                abbrev: BibleBookAbbrev(pt: "1pe", en: "1pe"),
                author: "Peter",
                chapters: 5,
                group: "General Epistles",
                name: "1 Peter",
                testament: .new
            ),
            BibleBook(
                abbrev: BibleBookAbbrev(pt: "2pe", en: "2pe"),
                author: "Peter",
                chapters: 3,
                group: "General Epistles",
                name: "2 Peter",
                testament: .new
            ),
            BibleBook(
                abbrev: BibleBookAbbrev(pt: "1jo", en: "1jn"),
                author: "John",
                chapters: 5,
                group: "General Epistles",
                name: "1 John",
                testament: .new
            ),
            BibleBook(
                abbrev: BibleBookAbbrev(pt: "2jo", en: "2jn"),
                author: "John",
                chapters: 1,
                group: "General Epistles",
                name: "2 John",
                testament: .new
            ),
            BibleBook(
                abbrev: BibleBookAbbrev(pt: "3jo", en: "3jn"),
                author: "John",
                chapters: 1,
                group: "General Epistles",
                name: "3 John",
                testament: .new
            ),
            BibleBook(
                abbrev: BibleBookAbbrev(pt: "jd", en: "jud"),
                author: "Jude",
                chapters: 1,
                group: "General Epistles",
                name: "Jude",
                testament: .new
            ),
            BibleBook(
                abbrev: BibleBookAbbrev(pt: "ap", en: "rev"),
                author: "John",
                chapters: 22,
                group: "Prophecy",
                name: "Revelation",
                testament: .new
            )
        ]
    }
    
    func loadChapter(bookAbbrev: String, chapter: Int, version: String = "nlt") async throws -> BibleChapter {
        // Check cache first
        if let cachedChapter = cacheManager.getCachedChapter(bookAbbrev: bookAbbrev, chapter: chapter, version: version) {
            // Save to reading history
            saveReadingHistory(bookAbbrev: bookAbbrev, chapter: chapter)
            return cachedChapter
        }
        
        // Fetch from API
        let chapterData = try await apiService.fetchChapter(version: version, abbrev: bookAbbrev, chapter: chapter)
        
        // Cache the result
        cacheManager.cacheChapter(chapterData, bookAbbrev: bookAbbrev, chapter: chapter, version: version)
        
        // Save to reading history
        saveReadingHistory(bookAbbrev: bookAbbrev, chapter: chapter)
        
        return chapterData
    }
    
    func searchVerses(query: String, version: String = "nlt") async throws -> BibleSearchResponse {
        // Search is not cached due to dynamic nature
        return try await apiService.searchVerses(version: version, query: query)
    }
    
    func getRandomVerse(version: String = "nlt") async throws -> RandomVerse {
        // Random verses are not cached
        return try await apiService.fetchRandomVerse(version: version)
    }
    
    func loadVersions() async throws -> [BibleVersion] {
        // Check cache first
        if let cachedVersions = cacheManager.getCachedVersions() {
            return cachedVersions
        }
        
        // Try to fetch from API
        do {
            let versions = try await apiService.fetchVersions()
            
            // Cache the result
            cacheManager.cacheVersions(versions)
            
            return versions
        } catch {
            print("RWRW ⚠️ API failed for versions, using fallback versions: \(error)")
            // If API fails, return fallback versions
            let fallbackVersions = getFallbackVersions()
            // Cache the fallback versions so they're available offline
            cacheManager.cacheVersions(fallbackVersions)
            return fallbackVersions
        }
    }
    
    // MARK: - Fallback Versions Data
    private func getFallbackVersions() -> [BibleVersion] {
        return [
            BibleVersion(
                version: "nlt",
                verses: 31102,
            ),
            BibleVersion(
                version: "niv",
                verses: 31102,
            ),
            BibleVersion(
                version: "esv",
                verses: 31102,
            ),
            BibleVersion(
                version: "kjv",
                verses: 31102,
            ),
            BibleVersion(
                version: "nasb",
                verses: 31102,
            ),
            BibleVersion(
                version: "nkjv",
                verses: 31102,
            ),
            BibleVersion(
                version: "csb",
                verses: 31102,
            ),
            BibleVersion(
                version: "msg",
                verses: 31102,
            )
        ]
    }
    
    // MARK: - Bookmark Operations
    func addBookmark(_ bookmark: BibleBookmark) {
        var bookmarks = getBookmarks()
        
        // Check if bookmark already exists
        if !bookmarks.contains(where: { 
            $0.bookAbbrev == bookmark.bookAbbrev && 
            $0.chapter == bookmark.chapter && 
            $0.verseNumber == bookmark.verseNumber 
        }) {
            bookmarks.append(bookmark)
            saveBookmarks(bookmarks)
        }
    }
    
    func removeBookmark(_ bookmark: BibleBookmark) {
        var bookmarks = getBookmarks()
        bookmarks.removeAll { $0.id == bookmark.id }
        saveBookmarks(bookmarks)
    }
    
    func getBookmarks() -> [BibleBookmark] {
        guard let data = userDefaults.data(forKey: bookmarksKey),
              let bookmarks = try? JSONDecoder().decode([BibleBookmark].self, from: data) else {
            return []
        }
        return bookmarks.sorted { $0.dateAdded > $1.dateAdded }
    }
    
    func isBookmarked(bookAbbrev: String, chapter: Int, verse: Int) -> Bool {
        let bookmarks = getBookmarks()
        return bookmarks.contains { 
            $0.bookAbbrev == bookAbbrev && 
            $0.chapter == chapter && 
            $0.verseNumber == verse 
        }
    }
    
    private func saveBookmarks(_ bookmarks: [BibleBookmark]) {
        if let data = try? JSONEncoder().encode(bookmarks) {
            userDefaults.set(data, forKey: bookmarksKey)
        }
    }
    
    // MARK: - Highlight Operations
    func addHighlight(_ highlight: BibleHighlight) {
        var highlights = getAllHighlights()
        
        // Remove existing highlight for same verse if exists
        highlights.removeAll { 
            $0.bookAbbrev == highlight.bookAbbrev && 
            $0.chapter == highlight.chapter && 
            $0.verseNumber == highlight.verseNumber 
        }
        
        highlights.append(highlight)
        saveHighlights(highlights)
    }
    
    func removeHighlight(_ highlight: BibleHighlight) {
        var highlights = getAllHighlights()
        highlights.removeAll { $0.id == highlight.id }
        saveHighlights(highlights)
    }
    
    func getHighlights(for bookAbbrev: String, chapter: Int) -> [BibleHighlight] {
        let highlights = getAllHighlights()
        return highlights.filter { 
            $0.bookAbbrev == bookAbbrev && 
            $0.chapter == chapter 
        }
    }
    
    private func getAllHighlights() -> [BibleHighlight] {
        guard let data = userDefaults.data(forKey: highlightsKey),
              let highlights = try? JSONDecoder().decode([BibleHighlight].self, from: data) else {
            return []
        }
        return highlights
    }
    
    private func saveHighlights(_ highlights: [BibleHighlight]) {
        if let data = try? JSONEncoder().encode(highlights) {
            userDefaults.set(data, forKey: highlightsKey)
        }
    }
    
    // MARK: - Reading History
    func saveReadingHistory(bookAbbrev: String, chapter: Int) {
        var history = getReadingHistoryData()
        
        // Remove duplicate entries for same book/chapter
        history.removeAll { $0.book == bookAbbrev && $0.chapter == chapter }
        
        // Add new entry
        history.insert(ReadingHistoryEntry(book: bookAbbrev, chapter: chapter, date: Date()), at: 0)
        
        // Keep only last 50 entries
        if history.count > 50 {
            history = Array(history.prefix(50))
        }
        
        // Save to UserDefaults
        if let data = try? JSONEncoder().encode(history) {
            userDefaults.set(data, forKey: readingHistoryKey)
        }
        
        // Update last read location
        saveLastReadLocation(book: bookAbbrev, chapter: chapter)
    }
    
    func getReadingHistory() -> [(book: String, chapter: Int, date: Date)] {
        let history = getReadingHistoryData()
        return history.map { ($0.book, $0.chapter, $0.date) }
    }
    
    func getLastReadLocation() -> (book: String, chapter: Int)? {
        guard let data = userDefaults.data(forKey: lastReadKey),
              let lastRead = try? JSONDecoder().decode(LastReadLocation.self, from: data) else {
            return nil
        }
        return (lastRead.book, lastRead.chapter)
    }
    
    private func saveLastReadLocation(book: String, chapter: Int) {
        let lastRead = LastReadLocation(book: book, chapter: chapter)
        if let data = try? JSONEncoder().encode(lastRead) {
            userDefaults.set(data, forKey: lastReadKey)
        }
    }
    
    private func getReadingHistoryData() -> [ReadingHistoryEntry] {
        guard let data = userDefaults.data(forKey: readingHistoryKey),
              let history = try? JSONDecoder().decode([ReadingHistoryEntry].self, from: data) else {
            return []
        }
        return history
    }
    
    // MARK: - Cache Management
    func clearCache() {
        cacheManager.clearAllCache()
    }
    
    func getCacheSize() -> Int64 {
        return cacheManager.getCacheSize()
    }
}

// MARK: - Supporting Types
private struct ReadingHistoryEntry: Codable {
    let book: String
    let chapter: Int
    let date: Date
}

private struct LastReadLocation: Codable {
    let book: String
    let chapter: Int
}
