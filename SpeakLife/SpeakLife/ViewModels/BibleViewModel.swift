//
//  BibleViewModel.swift
//  SpeakLife
//
//  Created by SpeakLife Team on 1/28/26.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class BibleViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var testamentSections: [TestamentSection] = []
    @Published var currentChapter: ChapterDisplayModel?
    @Published var searchResults: [SearchResultDisplayModel] = []
    @Published var readingHistory: [ReadingHistoryDisplayModel] = []
    @Published var bookmarks: [BibleBookmark] = []
    @Published var dailyVerse: RandomVerse?
    @Published var availableVersions: [BibleVersion] = []
    @Published var selectedVersion: String = "kjv" // Default to KJV (King James Version)
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var showAuthView = false
    @Published var showSearchError = false
    @Published var searchText = ""
    @Published var isSearching = false
    @Published var isAuthenticated = false
    
    // Navigation State
    @Published var selectedBook: BookDisplayModel?
    @Published var selectedChapterNumber: Int = 1
    @Published var showBookSelection = true
    @Published var showChapterGrid = false
    
    // MARK: - Dependencies
    private let interactor: BibleInteractorProtocol
    private let presenter: BiblePresenterProtocol
    private var cancellables = Set<AnyCancellable>()
    private var allBooks: [BibleBook] = []
    /// When set, the initial load opens this passage (e.g. "John 3:16") instead
    /// of resuming the last-read location. Drives the chat-answer deep link.
    private let initialReference: String?

    // MARK: - Task Management
    private var currentChapterLoadTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?
    private var initialLoadTask: Task<Void, Never>?

    // MARK: - Initialization
    init(
        interactor: BibleInteractorProtocol = BibleInteractor(),
        presenter: BiblePresenterProtocol = BiblePresenter(),
        initialReference: String? = nil
    ) {
        self.interactor = interactor
        self.presenter = presenter
        self.initialReference = initialReference

        setupBindings()
        loadInitialData()
    }
    
    deinit {
        // Cancel all running tasks to prevent memory leaks
        currentChapterLoadTask?.cancel()
        searchTask?.cancel()
        initialLoadTask?.cancel()
    }
    
    // MARK: - Setup
    private func setupBindings() {
        // Removed auto-search - now manual search only via onSubmit or explicit button tap
    }
    
    private func loadInitialData() {
        // Check authentication status
        isAuthenticated = BibleAPIService.shared.isAuthenticated
        
        initialLoadTask = Task {
            
            // Load data sequentially to avoid complexity for now
            await loadBooks()
            await loadDailyVerse()
            await loadVersions()
            
            await MainActor.run {
                loadBookmarks()
                loadHistory()
            }
            
            // A deep-linked reference takes precedence over resuming the
            // last-read location, so the two never race to set currentChapter.
            if let initialReference {
                await openReference(initialReference)
            } else if let lastRead = interactor.getLastReadLocation() {
                await continueReading(book: lastRead.book, chapter: lastRead.chapter)
            }
        }
    }
    
    // MARK: - Public Methods
    func loadBooks() async {
        isLoading = true
        errorMessage = nil
        
        do {
            allBooks = try await interactor.loadBooks()
            testamentSections = presenter.formatBooksByTestament(allBooks)
            isLoading = false
        } catch {
            handleError(error)
        }
    }
    
    func loadChapter(bookAbbrev: String, chapterNumber: Int) async {
        // Cancel any existing chapter load task
        currentChapterLoadTask?.cancel()
        
        currentChapterLoadTask = Task {
            await MainActor.run { 
                isLoading = true
                errorMessage = nil 
            }
            
            do {
                let chapter = try await interactor.loadChapter(
                    bookAbbrev: bookAbbrev,
                    chapter: chapterNumber,
                    version: selectedVersion
                )
                
                let highlights = interactor.getHighlights(for: bookAbbrev, chapter: chapterNumber)
                let bookmarks = interactor.getBookmarks().filter { 
                    $0.bookAbbrev == bookAbbrev && $0.chapter == chapterNumber 
                }
                
                await MainActor.run {
                    currentChapter = presenter.formatChapterForDisplay(chapter, highlights: highlights, bookmarks: bookmarks)
                    selectedChapterNumber = chapterNumber
                    showBookSelection = false
                    showChapterGrid = false
                    isLoading = false
                    
                    // Update reading history after successfully loading a chapter
                    loadHistory()
                }
                
                // Track analytics
                AnalyticsService.shared.trackContentInteraction(
                    contentType: "bible_chapter",
                    contentId: "\(bookAbbrev)_\(chapterNumber)",
                    action: "bible",// rwrw
                    metadata: [
                        "book": bookAbbrev,
                        "chapter": chapterNumber,
                        "version": selectedVersion
                    ]
                )
            } catch {
                await MainActor.run {
                    handleError(error)
                }
            }
        }
        
        await currentChapterLoadTask?.value
    }
    
    func searchVerses(query: String) async {
        guard !query.isEmpty else { return }
        
        // Cancel any existing search task
        searchTask?.cancel()
        
        searchTask = Task {
            await MainActor.run {
                isSearching = true
                errorMessage = nil
                showSearchError = false
            }
            
            do {
                let results = try await interactor.searchVerses(query: query, version: selectedVersion)
                await MainActor.run {
                    searchResults = presenter.formatSearchResults(results, searchTerm: query)
                    isSearching = false
                }
                
                // Track analytics
                AnalyticsService.shared.trackSearch(
                    query: query,
                    resultCount: results.occurrence,
                    category: "bible_\(selectedVersion)"
                )
            } catch {
                await MainActor.run {
                    // Handle search errors locally without dismissing the search sheet
                    handleSearchError(error)
                    isSearching = false
                }
            }
        }
        
        await searchTask?.value
    }
    
    private func handleSearchError(_ error: Error) {
        
        if let apiError = error as? BibleAPIError {
            switch apiError {
            case .rateLimited:
                if !isAuthenticated {
                    errorMessage = "You've reached the free limit. Sign in through Settings → Bible Version for unlimited access."
                } else {
                    errorMessage = "Too many requests. Please wait a moment and try again."
                }
                showSearchError = true
            case .unauthorized:
                errorMessage = "Your session has expired. Please sign in through Settings for unlimited access."
                showSearchError = true
            case .networkError:
                errorMessage = "No internet connection. Please check your network and try again."
                showSearchError = true
            case .noData:
                errorMessage = "No search results found for this query."
                showSearchError = true
            case .serverError(let code):
                if code >= 500 {
                    errorMessage = "The Bible service is temporarily unavailable. Please try again later."
                } else {
                    errorMessage = "Unable to search. Please try again."
                }
                showSearchError = true
            default:
                errorMessage = apiError.errorDescription ?? "Search failed. Please try again."
                showSearchError = true
            }
        } else {
            errorMessage = "Search failed. Please try again."
            showSearchError = true
        }
        
        // Ensure we don't trigger auth view from search
    }
    
    func loadDailyVerse() async {
        // Check if we have a cached daily verse for today
        let todayString = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
        let cachedDateKey = "DailyVerseDate"
        let cachedVerseKey = "DailyVerseData"
        
        // Check if we already have today's verse
        if let cachedDate = UserDefaults.standard.string(forKey: cachedDateKey),
           cachedDate == todayString,
           let cachedVerseData = UserDefaults.standard.data(forKey: cachedVerseKey),
           let cachedVerse = try? JSONDecoder().decode(RandomVerse.self, from: cachedVerseData) {
            // Use cached verse if it's from today
            await MainActor.run {
                dailyVerse = cachedVerse
            }
            return
        }
        
        // Fetch a new verse for today
        
        do {
            let verse = try await interactor.getRandomVerse(version: selectedVersion)
            
            // Validate the verse has content
            if verse.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                // Use a fallback verse
                let fallbackVerse = RandomVerse(
                    book: BibleBookInfo(
                        abbrev: BibleBookAbbrev(pt: "jn", en: "jn"),
                        name: "John",
                        author: "John",
                        group: "Gospel",
                        version: selectedVersion
                    ),
                    chapter: 3,
                    number: 16,
                    text: "For God so loved the world, that he gave his only begotten Son, that whosoever believeth in him should not perish, but have everlasting life."
                )
                await MainActor.run {
                    dailyVerse = fallbackVerse
                }
                saveDailyVerse(fallbackVerse, date: todayString)
            } else {
                await MainActor.run {
                    dailyVerse = verse
                }
                saveDailyVerse(verse, date: todayString)
            }
        } catch {
            // Use a fallback verse on error
            let fallbackVerse = RandomVerse(
                book: BibleBookInfo(
                    abbrev: BibleBookAbbrev(pt: "phil", en: "phil"),
                    name: "Philippians",
                    author: "Paul",
                    group: "Epistle",
                    version: selectedVersion
                ),
                chapter: 4,
                number: 13,
                text: "I can do all things through Christ which strengtheneth me."
            )
            await MainActor.run {
                dailyVerse = fallbackVerse
            }
            saveDailyVerse(fallbackVerse, date: todayString)
        }
    }
    
    private func saveDailyVerse(_ verse: RandomVerse, date: String) {
        // Save the verse and date to UserDefaults
        if let encoded = try? JSONEncoder().encode(verse) {
            UserDefaults.standard.set(encoded, forKey: "DailyVerseData")
            UserDefaults.standard.set(date, forKey: "DailyVerseDate")
        }
    }
    
    func loadVersions() async {
        
        // Clear cached versions to ensure we get fresh data without duplicates
        interactor.clearVersionsCache()
        
        do {
            let rawVersions = try await interactor.loadVersions()
            
            // Extra safety: Remove any duplicates based on version ID to prevent ForEach issues
            availableVersions = Array(Dictionary(grouping: rawVersions, by: \.version).compactMapValues(\.first).values)
            
            print("RWRW 📚 Final unique versions: \(availableVersions.map { $0.version }.joined(separator: ", "))")
        } catch {
        }
    }
    
    // MARK: - Navigation
    func selectBook(_ book: BookDisplayModel) {
        selectedBook = book
        selectedChapterNumber = 1  // Reset chapter to 1 when selecting a new book
        showChapterGrid = true
        showBookSelection = false
        
        AnalyticsService.shared.trackUserAction(
            "bible_book_selected",
            category: "bible",
            metadata: [
                "book": book.abbreviation,
                "testament": book.testament
            ]
        )
    }
    
    func selectChapter(_ chapter: Int) async {
        guard let book = selectedBook else { return }
        await loadChapter(bookAbbrev: book.abbreviation.lowercased(), chapterNumber: chapter)
    }
    
    func navigateToNextChapter() async {
        guard let nextChapter = currentChapter?.nextChapter else { return }
        await loadChapter(bookAbbrev: nextChapter.book, chapterNumber: nextChapter.chapter)
    }
    
    func navigateToPreviousChapter() async {
        guard let previousChapter = currentChapter?.previousChapter else { return }
        await loadChapter(bookAbbrev: previousChapter.book, chapterNumber: previousChapter.chapter)
    }
    
    func backToBooks() {
        showBookSelection = true
        showChapterGrid = false
        selectedBook = nil
        selectedChapterNumber = 1  // Reset chapter number when going back to books
    }
    
    func backToChapters() {
        showChapterGrid = true
        currentChapter = nil
    }
    
    // MARK: - Bookmarks
    func toggleBookmark(for verse: VerseDisplayModel) {
        guard let chapter = currentChapter else { return }
        
        if verse.isBookmarked {
            if let bookmark = bookmarks.first(where: { 
                $0.chapter == chapter.chapterNumber && $0.verseNumber == verse.number 
            }) {
                interactor.removeBookmark(bookmark)
                Event.trackBookmark("removed", metadata: [
                    "verse": verse.reference,
                    "version": selectedVersion
                ])
            }
        } else {
            let bookmark = BibleBookmark(
                bookAbbrev: selectedBook?.abbreviation.lowercased() ?? "",
                bookName: chapter.bookName,
                chapter: chapter.chapterNumber,
                verseNumber: verse.number,
                verseText: verse.text,
                version: selectedVersion
            )
            interactor.addBookmark(bookmark)
            Event.trackBookmark("added", metadata: [
                "verse": verse.reference,
                "version": selectedVersion
            ])
        }
        
        loadBookmarks()
        refreshCurrentChapter()
    }
    
    func removeBookmark(_ bookmark: BibleBookmark) {
        interactor.removeBookmark(bookmark)
        loadBookmarks()
        
        Event.trackBookmark("removed", metadata: [
            "book": bookmark.bookAbbrev,
            "chapter": bookmark.chapter,
            "verse": bookmark.verseNumber
        ])
    }
    
    func loadBookmarks() {
        bookmarks = interactor.getBookmarks()
    }
    
    // MARK: - Highlights
    func toggleHighlight(for verse: VerseDisplayModel, color: BibleHighlight.HighlightColor) {
        guard let book = selectedBook else { return }
        
        let highlight = BibleHighlight(
            id: UUID(),
            bookAbbrev: book.abbreviation.lowercased(),
            chapter: selectedChapterNumber,
            verseNumber: verse.number,
            color: color,
            dateAdded: Date()
        )
        
        interactor.addHighlight(highlight)
        refreshCurrentChapter()
        
        Event.trackHighlight("added", metadata: [
            "verse": verse.reference,
            "color": color.rawValue,
            "version": selectedVersion
        ])
    }
    
    func removeHighlight(for verse: VerseDisplayModel) {
        guard let book = selectedBook else { return }
        
        let highlights = interactor.getHighlights(for: book.abbreviation.lowercased(), chapter: selectedChapterNumber)
        if let highlight = highlights.first(where: { $0.verseNumber == verse.number }) {
            interactor.removeHighlight(highlight)
            refreshCurrentChapter()
            
            Event.trackHighlight("removed", metadata: [
                "verse": verse.reference,
                "version": selectedVersion
            ])
        }
    }
    
    // MARK: - Reading History
    func loadHistory() {
        let history = interactor.getReadingHistory()
        readingHistory = presenter.formatReadingHistory(history, books: allBooks)
    }
    
    func continueReading(book: String, chapter: Int) async {
        if let bookModel = allBooks.first(where: { $0.abbrev.en == book }) {
            let displayModel = presenter.formatBookForDisplay(bookModel)
            selectedBook = displayModel
            await loadChapter(bookAbbrev: book, chapterNumber: chapter)
        }
    }

    // MARK: - Deep Linking
    /// Opens the reader at a scripture reference like "John 3:16" or "1 John 4:8".
    /// The verse number only locates the chapter; the reader shows the full chapter.
    /// Called from the initial load (books already present); the empty-guard keeps
    /// it safe if invoked on its own. A reference that can't be resolved is a no-op,
    /// leaving the normal book list visible.
    func openReference(_ reference: String) async {
        guard let parsed = Self.parseReference(reference) else { return }
        if allBooks.isEmpty { await loadBooks() }
        guard let book = Self.matchBook(named: parsed.book, in: allBooks) else { return }

        let chapter = min(max(parsed.chapter, 1), max(book.chapters, 1))
        selectedBook = presenter.formatBookForDisplay(book)
        await loadChapter(bookAbbrev: book.abbrev.en.lowercased(), chapterNumber: chapter)

        AnalyticsService.shared.trackUserAction(
            "bible_reference_opened",
            category: "bible_chat",
            metadata: ["reference": reference, "book": book.abbrev.en, "chapter": chapter]
        )
    }

    /// Parses "Book Chapter:Verse" ("1 John 4:8", "Psalm 23:1", "John 3:16-17")
    /// into the book name and chapter. The chapter:verse token is always the final
    /// whitespace-separated component, so the book name (which may contain spaces
    /// or a leading number) is everything before it.
    static func parseReference(_ reference: String) -> (book: String, chapter: Int)? {
        let trimmed = reference.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: " ").map(String.init)
        guard parts.count >= 2, let last = parts.last else { return nil }

        let bookName = parts.dropLast().joined(separator: " ")
        guard !bookName.isEmpty else { return nil }

        // last is "3:16", "3:16-17", or just "3"; the chapter is before the colon.
        guard let chapterToken = last.split(separator: ":", maxSplits: 1).first,
              let chapter = Int(chapterToken) else { return nil }
        return (bookName, chapter)
    }

    /// Resolves a reference's book name to a loaded BibleBook, tolerant of case,
    /// punctuation, singular/plural ("Psalm" vs "Psalms"), and naming variants
    /// ("Song of Solomon" vs "Song of Songs"). Both the reference name and each
    /// book name are canonicalized through the same alias table, so the match is
    /// direction-independent. Exact match wins first, so close names (Jude vs
    /// Judges) are never confused.
    private static func matchBook(named name: String, in books: [BibleBook]) -> BibleBook? {
        // Variant -> canonical token, applied to BOTH sides so either spelling resolves.
        let aliases: [String: String] = [
            "psalm": "psalms",
            "song of solomon": "song of songs",
            "canticles": "song of songs",
            "revelations": "revelation"
        ]
        func canon(_ s: String) -> String {
            let n = s.lowercased()
                .replacingOccurrences(of: ".", with: "")
                .trimmingCharacters(in: .whitespaces)
            return aliases[n] ?? n
        }
        let target = canon(name)

        if let exact = books.first(where: { canon($0.name) == target }) {
            return exact
        }
        // No exact match: tolerate trailing-plural differences in authored text.
        return books.first(where: {
            let n = canon($0.name)
            return n == target + "s" || target == n + "s"
        })
    }
    
    // MARK: - Version Management
    func changeVersion(_ version: String) async {
        await MainActor.run {
            selectedVersion = version
        }
        UserDefaults.standard.set(version, forKey: "SelectedBibleVersion")
        
        // Clear current chapter to force UI update
        await MainActor.run {
            currentChapter = nil
        }
        
        // Reload current chapter if viewing one
        if let book = selectedBook {
            await loadChapter(bookAbbrev: book.abbreviation.lowercased(), chapterNumber: selectedChapterNumber)
        }
        
        // Reload daily verse
        await loadDailyVerse()
        
        AnalyticsService.shared.trackUserAction(
            "bible_version_changed",
            category: "bible_settings",
            metadata: [
                "version": version
            ]
        )
    }
    
    // MARK: - Sharing
    func shareVerse(_ verse: VerseDisplayModel) {
        let shareText = "\(verse.text)\n\n— \(verse.reference) (\(selectedVersion.uppercased()))"
        
        let activityController = UIActivityViewController(
            activityItems: [shareText],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityController, animated: true)
        }
        
        AnalyticsService.shared.trackShare(
            contentType: "bible_verse",
            contentId: verse.reference,
            shareMethod: "share_sheet",
            metadata: [
                "verse": verse.reference,
                "version": selectedVersion
            ]
        )
    }
    
    // MARK: - Cache Management
    func clearCache() {
        interactor.clearCache()
    }
    
    func getCacheSizeFormatted() async -> String {
        let bytes = await interactor.getCacheSize()
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: bytes)
    }
    
    // MARK: - Private Helpers
    private func refreshCurrentChapter() {
        guard let book = selectedBook else { return }
        
        // Cancel any existing task and use the managed loadChapter method
        Task {
            await loadChapter(bookAbbrev: book.abbreviation.lowercased(), chapterNumber: selectedChapterNumber)
        }
    }
    
    private func handleError(_ error: Error) {
        isLoading = false
        
        if let apiError = error as? BibleAPIError {
            switch apiError {
            case .rateLimited:
                // Show authentication view for rate limited users
                if !isAuthenticated {
                    errorMessage = "You've reached the free limit of 20 requests per hour. Sign in for unlimited access to the Bible."
                    showAuthView = true
                } else {
                    errorMessage = "Too many requests. Please wait a moment and try again."
                    showError = true
                }
            case .unauthorized:
                // Token might be invalid, prompt to re-authenticate
                errorMessage = "Your session has expired. Please sign in again to continue."
                isAuthenticated = false
                BibleAPIService.shared.clearAuthToken()
                showAuthView = true
            case .networkError:
                errorMessage = "No internet connection. Please check your network and try again."
                showError = true
            case .noData:
                errorMessage = "No content available. Please try again later."
                showError = true
            case .decodingError:
                errorMessage = "Unable to process the Bible content. Please try again."
                showError = true
            case .serverError(let code):
                if code >= 500 {
                    errorMessage = "The Bible service is temporarily unavailable. Please try again later."
                } else {
                    errorMessage = "Unable to load content. Please try again."
                }
                showError = true
            default:
                errorMessage = apiError.errorDescription ?? "Something went wrong. Please try again."
                showError = true
            }
        } else {
            errorMessage = "An unexpected error occurred. Please try again."
            showError = true
        }
    }
    
    // MARK: - Authentication
    func handleAuthenticationSuccess() {
        isAuthenticated = true
        showAuthView = false
        // Reload data after authentication
        Task {
            await loadBooks()
            await loadDailyVerse()
            
            // Retry any pending operations
            if let book = selectedBook {
                await loadChapter(bookAbbrev: book.abbreviation.lowercased(), chapterNumber: selectedChapterNumber)
            }
        }
    }
    
    func signOut() {
        BibleAPIService.shared.clearAuthToken()
        isAuthenticated = false
        UserDefaults.standard.removeObject(forKey: "BibleUserEmail")
    }
}
