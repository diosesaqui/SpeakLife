//
//  UnifiedFavoritesManager.swift
//  SpeakLife
//
//  Unified favorites management for all content types with Core Data + CloudKit sync
//

import Foundation
import SwiftUI
import Combine

enum UnifiedFavoritesError: LocalizedError {
    case loadFailed(Error)
    case saveFailed(Error)
    case toggleFailed(Error)
    case migrationFailed(Error)
    case syncFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .loadFailed(let error):
            return "Failed to load favorites: \(error.localizedDescription)"
        case .saveFailed(let error):
            return "Failed to save favorite: \(error.localizedDescription)"
        case .toggleFailed(let error):
            return "Failed to toggle favorite: \(error.localizedDescription)"
        case .migrationFailed(let error):
            return "Migration failed: \(error.localizedDescription)"
        case .syncFailed(let error):
            return "Sync failed: \(error.localizedDescription)"
        }
    }
}

final class UnifiedFavoritesManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var declarationFavorites: [Declaration] = []
    @Published var audioFavorites: [AudioDeclaration] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Repositories
    private let affirmationRepository: any AffirmationRepositoryProtocol
    private let journalRepository: any JournalRepositoryProtocol
    private let declarationFavoriteRepository: any DeclarationFavoriteRepositoryProtocol
    private let audioFavoriteRepository: any AudioFavoriteRepositoryProtocol
    
    private var cancellables = Set<AnyCancellable>()
    private var updateDebouncer: AnyCancellable?
    private let updateQueue = DispatchQueue(label: "com.speaklife.favoritesupdate", qos: .background)
    
    init(affirmationRepository: any AffirmationRepositoryProtocol = AffirmationRepository(),
         journalRepository: any JournalRepositoryProtocol = JournalRepository(),
         declarationFavoriteRepository: any DeclarationFavoriteRepositoryProtocol = DeclarationFavoriteRepository(),
         audioFavoriteRepository: any AudioFavoriteRepositoryProtocol = AudioFavoriteRepository()) {
        
        self.affirmationRepository = affirmationRepository
        self.journalRepository = journalRepository
        self.declarationFavoriteRepository = declarationFavoriteRepository
        self.audioFavoriteRepository = audioFavoriteRepository
        
        setupObservers()
        loadAllFavorites()
    }
    
    // MARK: - Setup
    
    private func setupObservers() {
        // Create a publisher that combines all declaration changes with debouncing
        let declarationUpdates = Publishers.Merge3(
            affirmationRepository.observeAll().map { _ in () },
            journalRepository.observeAll().map { _ in () },
            declarationFavoriteRepository.observeAll().map { _ in () }
        )
        .debounce(for: .milliseconds(300), scheduler: updateQueue)
        .sink { [weak self] _ in
            self?.updateDeclarationFavorites()
        }
        declarationUpdates.store(in: &cancellables)
        
        // Observe audio favorites with debouncing
        audioFavoriteRepository.observeAll()
            .debounce(for: .milliseconds(300), scheduler: updateQueue)
            .sink { [weak self] entries in
                self?.updateAudioFavorites(entries)
            }
            .store(in: &cancellables)
    }
    
    private func loadAllFavorites() {
        isLoading = true
        Task {
            await updateDeclarationFavoritesAsync()
            await updateAudioFavoritesAsync()
            
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Declaration Favorites
    
    private func updateDeclarationFavorites() {
        Task {
            await updateDeclarationFavoritesAsync()
        }
    }
    
    @MainActor
    private func updateDeclarationFavoritesAsync() async {
        do {
            var allFavorites: [Declaration] = []
            
            // Get Core Data favorites (affirmations and journals)
            let favoriteAffirmations = try await affirmationRepository.fetchFavorites()
            let favoriteJournals = try await journalRepository.fetchFavorites()
            
            // Convert to Declaration objects
            for entry in favoriteAffirmations {
                let declaration = Declaration(
                    text: entry.text ?? "",
                    book: entry.book,
                    bibleVerseText: entry.bibleVerseText,
                    category: DeclarationCategory(rawValue: entry.category ?? "myOwn") ?? .myOwn,
                    categories: [],
                    isFavorite: true,
                    contentType: .affirmation,
                    lastEdit: entry.lastModified
                )
                allFavorites.append(declaration)
            }
            
            for entry in favoriteJournals {
                let declaration = Declaration(
                    text: entry.text ?? "",
                    book: entry.book,
                    bibleVerseText: entry.bibleVerseText,
                    category: DeclarationCategory(rawValue: entry.category ?? "myOwn") ?? .myOwn,
                    categories: [],
                    isFavorite: true,
                    contentType: .journal,
                    lastEdit: entry.lastModified
                )
                allFavorites.append(declaration)
            }
            
            // Get standalone declaration favorites (legacy non-myOwn favorites)
            let standaloneFavorites = try await declarationFavoriteRepository.fetch(predicate: nil)
            for entry in standaloneFavorites {
                let declaration = declarationFavoriteRepository.toDeclaration(entry)
                allFavorites.append(declaration)
            }
            
            // Sort by most recently added
            allFavorites.sort { ($0.lastEdit ?? Date.distantPast) > ($1.lastEdit ?? Date.distantPast) }
            
            self.declarationFavorites = allFavorites
            
        } catch {
            self.errorMessage = "Failed to load declaration favorites: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Audio Favorites
    
    private func updateAudioFavorites(_ entries: [AudioFavoriteEntry]) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.audioFavorites = entries.map { entry in
                self.audioFavoriteRepository.toAudioDeclaration(entry)
            }.sorted { ($0.dateFavorited ?? Date.distantPast) > ($1.dateFavorited ?? Date.distantPast) }
        }
    }
    
    private func updateAudioFavoritesAsync() async {
        do {
            let entries = try await audioFavoriteRepository.fetch(predicate: nil)
            await MainActor.run {
                self.updateAudioFavorites(entries)
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load audio favorites: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Public Methods - Declaration Favorites
    
    /// Check if a declaration is favorited
    func isDeclarationFavorite(_ declaration: Declaration) -> Bool {
        return declarationFavorites.contains { $0.id == declaration.id }
    }
    
    /// Toggle declaration favorite status with retry logic
    func toggleDeclarationFavorite(_ declaration: Declaration, retryCount: Int = 3) {
        Task { @MainActor in
            var lastError: Error?
            
            for attempt in 1...retryCount {
                do {
                    if declaration.category == .myOwn {
                        // Handle myOwn declarations through existing Core Data entities
                        if declaration.contentType == .affirmation {
                            if let entry = try await findAffirmationByText(declaration.text) {
                                try await affirmationRepository.toggleFavorite(entry)
                            }
                        } else if declaration.contentType == .journal {
                            if let entry = try await findJournalByText(declaration.text) {
                                try await journalRepository.toggleFavorite(entry)
                            }
                        }
                    } else {
                        // Handle non-myOwn declarations through standalone favorites
                        if let existing = try await declarationFavoriteRepository.findByDeclarationId(declaration.id) {
                            // Remove favorite
                            try await declarationFavoriteRepository.delete(existing)
                        } else {
                            // Add favorite
                            _ = try await declarationFavoriteRepository.createFromDeclaration(declaration)
                        }
                    }
                    
                    // Success - clear error and return
                    self.errorMessage = nil
                    return
                    
                } catch {
                    lastError = error
                    
                    // If not the last attempt, wait and retry with exponential backoff
                    if attempt < retryCount {
                        let delay = UInt64(attempt * 500_000_000) // Exponential backoff
                        try? await Task.sleep(nanoseconds: delay)
                    }
                }
            }
            
            // All retries failed
            if let error = lastError {
                self.errorMessage = UnifiedFavoritesError.toggleFailed(error).localizedDescription
                print("❌ Toggle declaration favorite failed after \(retryCount) attempts: \(error)")
            }
        }
    }
    
    /// Remove declaration favorite
    func removeDeclarationFavorite(_ declaration: Declaration) {
        toggleDeclarationFavorite(declaration) // Same logic - toggle will remove if favorited
    }
    
    // MARK: - Public Methods - Audio Favorites
    
    /// Check if audio is favorited
    func isAudioFavorite(_ audio: AudioDeclaration) -> Bool {
        return audioFavorites.contains { $0.id == audio.id }
    }
    
    /// Toggle audio favorite status with retry logic
    func toggleAudioFavorite(_ audio: AudioDeclaration, retryCount: Int = 3) {
        Task { @MainActor in
            var lastError: Error?
            
            for attempt in 1...retryCount {
                do {
                    if let existing = try await audioFavoriteRepository.findByAudioId(audio.id) {
                        // Remove favorite
                        try await audioFavoriteRepository.delete(existing)
                    } else {
                        // Add favorite
                        _ = try await audioFavoriteRepository.createFromAudioDeclaration(audio)
                    }
                    
                    // Success - clear error and return
                    self.errorMessage = nil
                    return
                    
                } catch {
                    lastError = error
                    
                    // If not the last attempt, wait and retry with exponential backoff
                    if attempt < retryCount {
                        let delay = UInt64(attempt * 500_000_000) // Exponential backoff
                        try? await Task.sleep(nanoseconds: delay)
                    }
                }
            }
            
            // All retries failed
            if let error = lastError {
                self.errorMessage = UnifiedFavoritesError.toggleFailed(error).localizedDescription
                print("❌ Toggle audio favorite failed after \(retryCount) attempts: \(error)")
            }
        }
    }
    
    /// Remove audio favorite
    func removeAudioFavorite(_ audio: AudioDeclaration) {
        toggleAudioFavorite(audio) // Same logic - toggle will remove if favorited
    }
    
    // MARK: - Helper Methods
    
    private func findAffirmationByText(_ text: String) async throws -> AffirmationEntry? {
        let predicate = NSPredicate(format: "text == %@", text)
        let results = try await affirmationRepository.fetch(predicate: predicate)
        return results.first
    }
    
    private func findJournalByText(_ text: String) async throws -> JournalEntry? {
        let predicate = NSPredicate(format: "text == %@", text)
        let results = try await journalRepository.fetch(predicate: predicate)
        return results.first
    }
    
    // MARK: - Utility Methods
    
    /// Get all favorites count
    var totalFavoritesCount: Int {
        return declarationFavorites.count + audioFavorites.count
    }
    
    /// Get favorites by content type
    func getDeclarationFavorites(byContentType contentType: ContentType) -> [Declaration] {
        return declarationFavorites.filter { $0.contentType == contentType }
    }
    
    /// Get audio favorites by tag
    func getAudioFavorites(byTag tag: String) -> [AudioDeclaration] {
        return audioFavorites.filter { $0.tag == tag }
    }
    
    /// Refresh all favorites
    func refreshAllFavorites() {
        loadAllFavorites()
    }
}