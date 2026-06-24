//
//  AudioFavoritesManager.swift
//  SpeakLife
//
//  Audio favorites management service with Core Data + CloudKit sync
//

import Foundation
import SwiftUI
import Combine

/// Errors that can occur in AudioFavoritesManager
enum AudioFavoritesError: LocalizedError {
    case importFailed(Error)
    case exportFailed(Error)
    case migrationFailed(Error)
    case toggleFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .importFailed(let error):
            return "Failed to import favorites: \(error.localizedDescription)"
        case .exportFailed(let error):
            return "Failed to export favorites: \(error.localizedDescription)"
        case .migrationFailed(let error):
            return "Failed to migrate favorites: \(error.localizedDescription)"
        case .toggleFailed(let error):
            return "Failed to toggle favorite: \(error.localizedDescription)"
        }
    }
}

final class AudioFavoritesManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var favorites: [AudioDeclaration] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private let repository: any AudioFavoriteRepositoryProtocol
    private var cancellables = Set<AnyCancellable>()
    private let fileManager = FileManager.default
    private let legacyFavoritesFileName = "audioFavorites.txt"

    /// One-time gate so the junk-favorites purge only does a full scan once per
    /// install. Bump the suffix if the cleanup criteria ever change.
    private let junkFavoritesCleanupKey = "audioFavorites.junkCleanup.v1"
    
    private var legacyFavoritesURL: URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath.appendingPathComponent(legacyFavoritesFileName)
    }
    
    // MARK: - Initialization
    init(repository: any AudioFavoriteRepositoryProtocol = AudioFavoriteRepository()) {
        self.repository = repository
        setupObservers()
        loadFavorites()
        migrateLegacyFavorites()
        cleanUpNonAudioFavorites()
    }
    
    private func setupObservers() {
        repository.observeAll()
            .sink { [weak self] entries in
                self?.updateFavoritesFromEntries(entries)
            }
            .store(in: &cancellables)
    }
    
    private func updateFavoritesFromEntries(_ entries: [AudioFavoriteEntry]) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // Filter to real, categorized audio so leaked schema-priming / test
            // rows that keep syncing down from CloudKit never show in (or inflate
            // the count of) the user's Favorites, even before the purge runs.
            self.favorites = entries
                .map { self.repository.toAudioDeclaration($0) }
                .filter { self.isRealAudioFavorite($0) }
        }
    }
    
    // MARK: - Public Methods
    
    /// Toggle favorite status for an audio declaration with retry logic
    func toggleFavorite(_ audio: AudioDeclaration, retryCount: Int = 3) {
        Task { @MainActor in
            var lastError: Error?
            
            for attempt in 1...retryCount {
                do {
                    if isFavorite(audio) {
                        // Remove from favorites
                        try await repository.deleteByAudioId(audio.id)
                        
                        // Track analytics
                        AudioAnalytics.shared.trackFavoriteToggle(
                            audio: audio,
                            isFavorited: false
                        )
                    } else {
                        // Add to favorites
                        _ = try await repository.createFromAudioDeclaration(audio)
                        
                        // Track favorite saved for paywall triggers
                        PaywallTriggerManager.shared.trackFavoriteSaved()
                        
                        // Track analytics
                        AudioAnalytics.shared.trackFavoriteToggle(
                            audio: audio,
                            isFavorited: true
                        )
                    }
                    
                    // Success - clear error and break
                    self.errorMessage = nil
                    return
                    
                } catch {
                    lastError = error
                    
                    // If not the last attempt, wait and retry
                    if attempt < retryCount {
                        let delay = UInt64(attempt * 500_000_000) // Exponential backoff
                        try? await Task.sleep(nanoseconds: delay)
                    }
                }
            }
            
            // All retries failed
            if let error = lastError {
                self.errorMessage = "Failed to toggle favorite after \(retryCount) attempts: \(error.localizedDescription)"
                print("❌ Toggle favorite failed for \(audio.id): \(error)")
            }
        }
    }
    
    /// Check if an audio is favorited
    func isFavorite(_ audio: AudioDeclaration) -> Bool {
        return favorites.contains { $0.id == audio.id }
    }
    
    /// Async version for Core Data queries
    func isFavoriteAsync(_ audio: AudioDeclaration) async -> Bool {
        do {
            let entry = try await repository.findByAudioId(audio.id)
            return entry != nil
        } catch {
            return false
        }
    }
    
    /// Get favorites sorted by date added (most recent first)
    func getFavoritesSortedByDate() -> [AudioDeclaration] {
        return favorites.sorted { 
            ($0.dateFavorited ?? Date.distantPast) > ($1.dateFavorited ?? Date.distantPast)
        }
    }
    
    /// Get favorites sorted alphabetically
    func getFavoritesSortedAlphabetically() -> [AudioDeclaration] {
        return favorites.sorted { $0.title < $1.title }
    }
    
    /// Get favorites by tag/category
    func getFavorites(byTag tag: String) -> [AudioDeclaration] {
        return favorites.filter { $0.tag == tag }
    }
    
    /// Remove favorite by ID
    func removeFavorite(withId id: String) {
        Task {
            do {
                try await repository.deleteByAudioId(id)
                
                if let audio = favorites.first(where: { $0.id == id }) {
                    AudioAnalytics.shared.trackFavoriteRemoved(audio: audio)
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to remove favorite: \(error.localizedDescription)"
                }
            }
        }
    }
    
    /// Remove multiple favorites
    func removeFavorites(at indexSet: IndexSet) {
        let audioToRemove = indexSet.map { favorites[$0] }
        
        Task {
            for audio in audioToRemove {
                do {
                    try await repository.deleteByAudioId(audio.id)
                    AudioAnalytics.shared.trackFavoriteRemoved(audio: audio)
                } catch {
                    await MainActor.run {
                        self.errorMessage = "Failed to remove favorites: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
    
    /// Clear all favorites
    func clearAllFavorites() {
        Task {
            do {
                let favoriteCount = favorites.count
                let allEntries = try await repository.fetch(predicate: nil)
                
                for entry in allEntries {
                    try await repository.delete(entry)
                }
                
                AudioAnalytics.shared.trackFavoritesCleared(count: favoriteCount)
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to clear favorites: \(error.localizedDescription)"
                }
            }
        }
    }
    
    /// Get favorites count
    var favoritesCount: Int {
        return favorites.count
    }
    
    // MARK: - Private Methods

    /// A real favorite is backed by a playable audio file (its `audioId` is the
    /// `.mp3` storage filename) AND carries a category tag. Every catalogued
    /// audio satisfies both, so this only ever rejects leaked schema-priming /
    /// test rows (e.g. "Schema initialization", "CloudKit Audio") that have no
    /// real file and no category.
    private func isRealAudioFavorite(_ audio: AudioDeclaration) -> Bool {
        let hasCategory = !(audio.tag ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return audio.isPlayableAudio && hasCategory
    }

    /// Permanently removes favorites that aren't real, categorized audio from
    /// Core Data. Because favorites sync via NSPersistentCloudKitContainer, the
    /// deletes propagate up to the user's iCloud too, so the junk stops syncing
    /// back down to their other devices. Gated by a local flag so the full scan
    /// runs once; the display filter keeps any late-arriving junk hidden in the
    /// meantime.
    func cleanUpNonAudioFavorites() {
        guard !UserDefaults.standard.bool(forKey: junkFavoritesCleanupKey) else { return }
        Task {
            do {
                let entries = try await self.repository.fetch(predicate: nil)
                var removed = 0
                for entry in entries {
                    let audio = self.repository.toAudioDeclaration(entry)
                    if !self.isRealAudioFavorite(audio) {
                        try await self.repository.delete(entry)
                        removed += 1
                    }
                }
                UserDefaults.standard.set(true, forKey: self.junkFavoritesCleanupKey)
                if removed > 0 {
                    print("🧹 Removed \(removed) junk audio favorite(s) that weren't real audio")
                }
            } catch {
                print("❌ Junk favorites cleanup failed: \(error.localizedDescription)")
            }
        }
    }

    /// Migrate legacy file-based favorites to Core Data
    private func migrateLegacyFavorites() {
        // Check if legacy file exists
        guard fileManager.fileExists(atPath: legacyFavoritesURL.path) else { return }
        
        Task {
            do {
                let data = try Data(contentsOf: legacyFavoritesURL)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let legacyFavorites = try decoder.decode([AudioDeclaration].self, from: data)
                
                print("📦 Migrating \(legacyFavorites.count) legacy audio favorites to Core Data")
                
                // Import each legacy favorite
                var migrationFailures = 0
                for legacyFavorite in legacyFavorites {
                    do {
                        // Check if it already exists
                        if try await repository.findByAudioId(legacyFavorite.id) == nil {
                            _ = try await repository.createFromAudioDeclaration(legacyFavorite)
                        }
                    } catch {
                        print("⚠️ Failed to migrate favorite \(legacyFavorite.id): \(error)")
                        migrationFailures += 1
                    }
                }
                
                // Only remove legacy file if ALL items migrated successfully
                if migrationFailures == 0 {
                    try fileManager.removeItem(at: legacyFavoritesURL)
                    print("✅ Legacy audio favorites migration completed")
                } else {
                    print("⚠️ Keeping legacy file due to \(migrationFailures) failed migrations")
                }
                
            } catch {
                print("❌ Failed to migrate legacy audio favorites: \(error)")
            }
        }
    }
    
    private func loadFavorites() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let entries = try await repository.fetch(predicate: nil)
                await MainActor.run {
                    self.updateFavoritesFromEntries(entries)
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    print("❌ Error loading audio favorites: \(error)")
                    self.errorMessage = "Failed to load favorites"
                    self.favorites = []
                    self.isLoading = false
                }
            }
        }
    }
    
    // Note: saveFavorites() is no longer needed as Core Data handles persistence automatically
    
    // MARK: - Import/Export Functionality
    
    /// Export favorites as JSON data for sharing or backup
    func exportFavorites() -> Data? {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            return try encoder.encode(favorites)
        } catch {
            print("❌ Error exporting favorites: \(error)")
            return nil
        }
    }
    
    /// Import favorites from JSON data
    @discardableResult
    func importFavorites(from data: Data, mergeWithExisting: Bool = true) async throws -> Bool {
        do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let importedFavorites = try decoder.decode([AudioDeclaration].self, from: data)
                
                if !mergeWithExisting {
                    // Clear existing favorites first
                    let existingEntries = try await repository.fetch(predicate: nil)
                    for entry in existingEntries {
                        try await repository.delete(entry)
                    }
                }
                
                // Import favorites
                for importedFavorite in importedFavorites {
                    if mergeWithExisting {
                        // Check if it already exists
                        if try await repository.findByAudioId(importedFavorite.id) == nil {
                            _ = try await repository.createFromAudioDeclaration(importedFavorite)
                        }
                    } else {
                        _ = try await repository.createFromAudioDeclaration(importedFavorite)
                    }
                }
                
                await MainActor.run {
                    print("✅ Successfully imported \(importedFavorites.count) favorites")
                }
                return true
            } catch {
                await MainActor.run {
                    print("❌ Error importing favorites: \(error)")
                    self.errorMessage = "Failed to import favorites: \(error.localizedDescription)"
                }
                throw AudioFavoritesError.importFailed(error)
            }
    }
}

// MARK: - Analytics Extension
extension AudioFavoritesManager {
    
    /// Get favorites statistics for analytics
    func getFavoritesStats() -> (totalCount: Int, byCategory: [String: Int], averagePerWeek: Double) {
        let totalCount = favorites.count
        
        // Group by category
        let byCategory = Dictionary(grouping: favorites) { $0.tag ?? "Unknown" }
            .mapValues { $0.count }
        
        // Calculate average per week (if we have dates)
        let datesWithFavorites = favorites.compactMap { $0.dateFavorited }
        let averagePerWeek: Double
        
        if let oldestDate = datesWithFavorites.min(),
           let newestDate = datesWithFavorites.max() {
            let timeInterval = newestDate.timeIntervalSince(oldestDate)
            let weeks = max(timeInterval / (7 * 24 * 60 * 60), 1) // At least 1 week
            averagePerWeek = Double(totalCount) / weeks
        } else {
            averagePerWeek = 0
        }
        
        return (totalCount, byCategory, averagePerWeek)
    }
}