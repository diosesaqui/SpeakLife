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
    @Published var selectedVersion: String = "bsb" // Default to BSB (Berean Standard Bible)
    
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
    
    // MARK: - Task Management
    private var currentChapterLoadTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?
    private var initialLoadTask: Task<Void, Never>?
    
    // MARK: - Initialization
    init(
        interactor: BibleInteractorProtocol = BibleInteractor(),
        presenter: BiblePresenterProtocol = BiblePresenter()
    ) {
        self.interactor = interactor
        self.presenter = presenter
        
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
        print("RWRW 🚀 BibleViewModel.loadInitialData() starting")
        // Check authentication status
        isAuthenticated = BibleAPIService.shared.isAuthenticated
        
        initialLoadTask = Task {
            print("RWRW 📖 Starting to load Bible data...")
            
            // Load data sequentially to avoid complexity for now
            await loadBooks()
            await loadDailyVerse()
            await loadVersions()
            
            await MainActor.run {
                loadBookmarks()
                loadHistory()
                print("RWRW ✅ Bible data loading completed")
            }
            
            // Check for last read location
            if let lastRead = interactor.getLastReadLocation() {
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
        print("🔍 Search Error: \(error)")
        
        if let apiError = error as? BibleAPIError {
            switch apiError {
            case .rateLimited:
                if !isAuthenticated {
                    errorMessage = "You've reached the free limit. Sign in through Settings → Bible Version for unlimited access."
                } else {
                    errorMessage = "Too many requests. Please wait a moment and try again."
                }
                showSearchError = true
                print("🔍 Rate limited error - showSearchError = true, showAuthView = \(showAuthView)")
            case .unauthorized:
                errorMessage = "Your session has expired. Please sign in through Settings for unlimited access."
                showSearchError = true
                print("🔍 Unauthorized error - showSearchError = true, showAuthView = \(showAuthView)")
            case .networkError:
                errorMessage = "No internet connection. Please check your network and try again."
                showSearchError = true
                print("🔍 Network error - showSearchError = true")
            case .noData:
                errorMessage = "No search results found for this query."
                showSearchError = true
                print("🔍 No data error - showSearchError = true")
            case .serverError(let code):
                if code >= 500 {
                    errorMessage = "The Bible service is temporarily unavailable. Please try again later."
                } else {
                    errorMessage = "Unable to search. Please try again."
                }
                showSearchError = true
                print("🔍 Server error (\(code)) - showSearchError = true")
            default:
                errorMessage = apiError.errorDescription ?? "Search failed. Please try again."
                showSearchError = true
                print("🔍 Default API error - showSearchError = true")
            }
        } else {
            errorMessage = "Search failed. Please try again."
            showSearchError = true
            print("🔍 Generic error - showSearchError = true")
        }
        
        // Ensure we don't trigger auth view from search
        print("🔍 Final state: showSearchError = \(showSearchError), showAuthView = \(showAuthView)")
    }
    
    func loadDailyVerse() async {
        do {
            dailyVerse = try await interactor.getRandomVerse(version: selectedVersion)
        } catch {
            print("Failed to load daily verse: \(error)")
        }
    }
    
    func loadVersions() async {
        print("RWRW 🔍 BibleViewModel.loadVersions() called")
        
        // Clear cached versions to ensure we get fresh data without duplicates
        interactor.clearVersionsCache()
        
        do {
            let rawVersions = try await interactor.loadVersions()
            
            // Extra safety: Remove any duplicates based on version ID to prevent ForEach issues
            availableVersions = Array(Dictionary(grouping: rawVersions, by: \.version).compactMapValues(\.first).values)
            
            print("RWRW ✅ BibleViewModel loaded \(rawVersions.count) raw versions, deduplicated to \(availableVersions.count) unique versions")
            print("RWRW 📚 Final unique versions: \(availableVersions.map { $0.version }.joined(separator: ", "))")
        } catch {
            print("RWRW ❌ Failed to load versions: \(error)")
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
    
    // MARK: - Version Management
    func changeVersion(_ version: String) async {
        selectedVersion = version
        UserDefaults.standard.set(version, forKey: "SelectedBibleVersion")
        
        // Reload current chapter if viewing one
        if let book = selectedBook, let chapter = currentChapter {
            await loadChapter(bookAbbrev: book.abbreviation.lowercased(), chapterNumber: chapter.chapterNumber)
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
