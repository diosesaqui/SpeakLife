//
//  FavoritesMigrationService.swift
//  SpeakLife
//
//  Service to migrate existing favorites to new Core Data + CloudKit system
//

import Foundation
import FirebaseAnalytics

final class FavoritesMigrationService {
    
    private let audioFavoriteRepository: any AudioFavoriteRepositoryProtocol
    private let declarationFavoriteRepository: any DeclarationFavoriteRepositoryProtocol
    
    init(audioFavoriteRepository: any AudioFavoriteRepositoryProtocol = AudioFavoriteRepository(),
         declarationFavoriteRepository: any DeclarationFavoriteRepositoryProtocol = DeclarationFavoriteRepository()) {
        self.audioFavoriteRepository = audioFavoriteRepository
        self.declarationFavoriteRepository = declarationFavoriteRepository
    }
    
    /// Migrate all legacy favorites to Core Data + CloudKit
    func migrateLegacyFavorites() async throws {
        print("🔄 Starting favorites migration to Core Data + CloudKit...")
        
        var migrationResults = MigrationResults()
        
        // Migrate audio favorites
        try await migrateAudioFavorites(&migrationResults)
        
        // Migrate declaration favorites (if any legacy files exist)
        try await migrateDeclarationFavorites(&migrationResults)
        
        // Log migration results
        logMigrationResults(migrationResults)
        
        print("✅ Favorites migration completed successfully")
    }
    
    // MARK: - Audio Favorites Migration
    
    private func migrateAudioFavorites(_ results: inout MigrationResults) async throws {
        let fileManager = FileManager.default
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let legacyURL = documentsPath.appendingPathComponent("audioFavorites.txt")
        
        guard fileManager.fileExists(atPath: legacyURL.path) else {
            print("ℹ️ No legacy audio favorites file found")
            return
        }
        
        do {
            let data = try Data(contentsOf: legacyURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let legacyFavorites = try decoder.decode([AudioDeclaration].self, from: data)
            
            print("📦 Found \(legacyFavorites.count) legacy audio favorites to migrate")
            
            for legacyFavorite in legacyFavorites {
                do {
                    // Check if already exists
                    if try await audioFavoriteRepository.findByAudioId(legacyFavorite.id) == nil {
                        _ = try await audioFavoriteRepository.createFromAudioDeclaration(legacyFavorite)
                        results.audioFavoritesMigrated += 1
                    } else {
                        results.audioFavoritesSkipped += 1
                    }
                } catch {
                    print("⚠️ Failed to migrate audio favorite \(legacyFavorite.id): \(error)")
                    results.audioFavoritesFailed += 1
                }
            }
            
            // Only remove legacy file if ALL items migrated successfully
            if results.audioFavoritesFailed == 0 {
                try fileManager.removeItem(at: legacyURL)
                print("🗑️ Legacy audio favorites file removed")
            } else {
                print("⚠️ Keeping legacy file due to \(results.audioFavoritesFailed) failed migrations")
                // Create a backup file to prevent data loss
                let backupURL = legacyURL.appendingPathExtension("backup")
                try? fileManager.copyItem(at: legacyURL, to: backupURL)
            }
            
        } catch {
            print("❌ Failed to read legacy audio favorites: \(error)")
            throw MigrationError.audioFavoritesMigrationFailed(error)
        }
    }
    
    // MARK: - Declaration Favorites Migration
    
    private func migrateDeclarationFavorites(_ results: inout MigrationResults) async throws {
        // Check if there are any legacy declaration favorites stored in UserDefaults or files
        // This is for any favorites that might be stored outside of Core Data
        
        // For now, we'll focus on ensuring existing Core Data favorites are properly synced
        // Future enhancement: migrate any other legacy favorite storage systems
        
        print("ℹ️ Declaration favorites migration - checking for legacy storage...")
        
        // Placeholder for future legacy declaration favorites migration
        // If you have any other legacy storage systems, add migration logic here
        
        results.declarationFavoritesMigrated = 0
        results.declarationFavoritesSkipped = 0
        results.declarationFavoritesFailed = 0
    }
    
    // MARK: - Migration Results
    
    private func logMigrationResults(_ results: MigrationResults) {
        let totalMigrated = results.audioFavoritesMigrated + results.declarationFavoritesMigrated
        let totalSkipped = results.audioFavoritesSkipped + results.declarationFavoritesSkipped
        let totalFailed = results.audioFavoritesFailed + results.declarationFavoritesFailed
        
        print("""
        📊 Migration Results:
        ✅ Migrated: \(totalMigrated) items
        ⏭️ Skipped: \(totalSkipped) items (already exist)
        ❌ Failed: \(totalFailed) items
        
        Audio Favorites: \(results.audioFavoritesMigrated) migrated, \(results.audioFavoritesSkipped) skipped, \(results.audioFavoritesFailed) failed
        Declaration Favorites: \(results.declarationFavoritesMigrated) migrated, \(results.declarationFavoritesSkipped) skipped, \(results.declarationFavoritesFailed) failed
        """)
        
        // Track migration analytics
        Analytics.logEvent("favorites_migration_completed", parameters: [
            "total_migrated": totalMigrated,
            "total_skipped": totalSkipped,
            "total_failed": totalFailed,
            "audio_favorites_migrated": results.audioFavoritesMigrated,
            "declaration_favorites_migrated": results.declarationFavoritesMigrated
        ])
    }
}

// MARK: - Supporting Types

struct MigrationResults {
    var audioFavoritesMigrated = 0
    var audioFavoritesSkipped = 0
    var audioFavoritesFailed = 0
    
    var declarationFavoritesMigrated = 0
    var declarationFavoritesSkipped = 0
    var declarationFavoritesFailed = 0
}

enum MigrationError: Error {
    case audioFavoritesMigrationFailed(Error)
    case declarationFavoritesMigrationFailed(Error)
    
    var localizedDescription: String {
        switch self {
        case .audioFavoritesMigrationFailed(let error):
            return "Audio favorites migration failed: \(error.localizedDescription)"
        case .declarationFavoritesMigrationFailed(let error):
            return "Declaration favorites migration failed: \(error.localizedDescription)"
        }
    }
}