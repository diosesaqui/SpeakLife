//
//  AudioFavoritesManager.swift
//  SpeakLife
//
//  Audio favorites management service following existing favorites pattern
//

import Foundation
import SwiftUI

final class AudioFavoritesManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var favorites: [AudioDeclaration] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private let fileManager = FileManager.default
    private let favoritesFileName = "audioFavorites.txt"
    private var favoritesURL: URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath.appendingPathComponent(favoritesFileName)
    }
    
    // MARK: - Initialization
    init() {
        loadFavorites()
    }
    
    // MARK: - Public Methods
    
    /// Toggle favorite status for an audio declaration
    func toggleFavorite(_ audio: AudioDeclaration) {
        var updatedAudio = audio
        
        if isFavorite(audio) {
            // Remove from favorites
            updatedAudio.isFavorite = false
            updatedAudio.favoriteId = nil
            updatedAudio.dateFavorited = nil
            removeFavoriteFromList(audio)
        } else {
            // Add to favorites
            updatedAudio.isFavorite = true
            updatedAudio.favoriteId = UUID().uuidString
            updatedAudio.dateFavorited = Date()
            addFavoriteToList(updatedAudio)
        }
        
        saveFavorites()
        
        // Track analytics
        AudioAnalytics.shared.trackFavoriteToggle(
            audio: updatedAudio,
            isFavorited: updatedAudio.isFavorite
        )
    }
    
    /// Check if an audio is favorited
    func isFavorite(_ audio: AudioDeclaration) -> Bool {
        return favorites.contains { $0.id == audio.id }
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
        if let index = favorites.firstIndex(where: { $0.id == id }) {
            var audio = favorites[index]
            audio.isFavorite = false
            audio.favoriteId = nil
            audio.dateFavorited = nil
            
            favorites.remove(at: index)
            saveFavorites()
            
            AudioAnalytics.shared.trackFavoriteRemoved(audio: audio)
        }
    }
    
    /// Remove multiple favorites
    func removeFavorites(at indexSet: IndexSet) {
        let audioToRemove = indexSet.map { favorites[$0] }
        
        for audio in audioToRemove {
            removeFavorite(withId: audio.id)
        }
    }
    
    /// Clear all favorites
    func clearAllFavorites() {
        let favoriteCount = favorites.count
        favorites.removeAll()
        saveFavorites()
        
        AudioAnalytics.shared.trackFavoritesCleared(count: favoriteCount)
    }
    
    /// Get favorites count
    var favoritesCount: Int {
        return favorites.count
    }
    
    // MARK: - Private Methods
    
    private func addFavoriteToList(_ audio: AudioDeclaration) {
        // Remove if it already exists to avoid duplicates
        favorites.removeAll { $0.id == audio.id }
        // Add to beginning (most recent first)
        favorites.insert(audio, at: 0)
    }
    
    private func removeFavoriteFromList(_ audio: AudioDeclaration) {
        favorites.removeAll { $0.id == audio.id }
    }
    
    private func loadFavorites() {
        isLoading = true
        errorMessage = nil
        
        do {
            if fileManager.fileExists(atPath: favoritesURL.path) {
                let data = try Data(contentsOf: favoritesURL)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                favorites = try decoder.decode([AudioDeclaration].self, from: data)
            } else {
                favorites = []
            }
        } catch {
            print("❌ Error loading audio favorites: \(error)")
            errorMessage = "Failed to load favorites"
            favorites = []
        }
        
        isLoading = false
    }
    
    private func saveFavorites() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            
            let data = try encoder.encode(favorites)
            try data.write(to: favoritesURL)
            
            print("✅ Audio favorites saved successfully (\(favorites.count) items)")
        } catch {
            print("❌ Error saving audio favorites: \(error)")
            errorMessage = "Failed to save favorites"
        }
    }
    
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
    func importFavorites(from data: Data, mergeWithExisting: Bool = true) -> Bool {
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let importedFavorites = try decoder.decode([AudioDeclaration].self, from: data)
            
            if mergeWithExisting {
                // Merge with existing favorites, avoiding duplicates
                for importedFavorite in importedFavorites {
                    if !favorites.contains(where: { $0.id == importedFavorite.id }) {
                        favorites.append(importedFavorite)
                    }
                }
            } else {
                // Replace existing favorites
                favorites = importedFavorites
            }
            
            saveFavorites()
            return true
        } catch {
            print("❌ Error importing favorites: \(error)")
            errorMessage = "Failed to import favorites"
            return false
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