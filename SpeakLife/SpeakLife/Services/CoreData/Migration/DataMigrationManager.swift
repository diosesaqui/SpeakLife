//
//  DataMigrationManager.swift
//  SpeakLife
//
//  Data Migration Manager for Legacy Data to Core Data
//

import Foundation
import CoreData
import FirebaseAnalytics

final class DataMigrationManager {
    
    private let persistenceController: PersistenceController
    private let legacyAPIService: APIService
    
    init(persistenceController: PersistenceController = .shared,
         legacyAPIService: APIService = LocalAPIClient()) {
        self.persistenceController = persistenceController
        self.legacyAPIService = legacyAPIService
    }
    
    // MARK: - Migration
    func migrateLegacyData() async throws {
        let context = persistenceController.container.viewContext
        
        // Check if migration has already been performed
        let migrationKey = "HasMigratedToCoreData"
        if UserDefaults.standard.bool(forKey: migrationKey) {
            // Track that user already migrated
            Analytics.logEvent("core_data_migration_skipped", parameters: [
                "reason": "already_migrated"
            ])
            return
        }
        
        // Track migration start
        let migrationStartTime = Date()
        Analytics.logEvent("core_data_migration_started", parameters: [:])
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            legacyAPIService.declarations { [weak self] declarations, error, _ in
                guard let self = self else {
                    continuation.resume(throwing: DataMigrationError.migrationFailed)
                    return
                }
                
                if let error = error {
                    // Track API error
                    Analytics.logEvent("core_data_migration_failed", parameters: [
                        "error_type": "api_error",
                        "error_description": error.localizedDescription
                    ])
                    continuation.resume(throwing: error)
                    return
                }
                
                Task {
                    do {
                        let migrationResult = try await self.migrateLegacyDeclarations(declarations, context: context)
                        
                        // Calculate migration duration
                        let migrationDuration = Date().timeIntervalSince(migrationStartTime)
                        
                        // Only set migration flag if we actually migrated some data
                        if migrationResult.totalEntries > 0 {
                            UserDefaults.standard.set(true, forKey: migrationKey)
                            
                            // Clean up legacy data only after successful migration
                            self.cleanUpLegacyData()
                        } else {
                            print("⚠️ No data to migrate - keeping migration flag false")
                        }
                        
                        // Track successful migration
                        Analytics.logEvent("core_data_migration_success", parameters: [
                            "total_entries": migrationResult.totalEntries,
                            "journal_entries": migrationResult.journalEntries,
                            "affirmation_entries": migrationResult.affirmationEntries,
                            "migration_duration_seconds": Int(migrationDuration),
                            "had_legacy_data": migrationResult.totalEntries > 0
                        ])
                        
                        continuation.resume()
                    } catch {
                        // Track migration failure
                        Analytics.logEvent("core_data_migration_failed", parameters: [
                            "error_type": "core_data_error",
                            "error_description": error.localizedDescription,
                            "migration_duration_seconds": Int(Date().timeIntervalSince(migrationStartTime))
                        ])
                        
                        // Don't set migration flag if failed - will retry next time
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    private func migrateLegacyDeclarations(_ declarations: [Declaration], context: NSManagedObjectContext) async throws -> MigrationResult {
        var journalCount = 0
        var affirmationCount = 0
        try await context.perform {
            for declaration in declarations where declaration.category == .myOwn {
                if declaration.contentType == .journal {
                    let journalEntry = JournalEntry(context: context)
                    journalEntry.id = UUID()
                    journalEntry.text = declaration.text
                    journalEntry.book = declaration.book
                    journalEntry.bibleVerseText = declaration.bibleVerseText
                    journalEntry.category = declaration.category.rawValue
                    journalEntry.isFavorite = declaration.isFavorite ?? false
                    journalEntry.createdAt = declaration.lastEdit ?? Date()
                    journalEntry.lastModified = declaration.lastEdit ?? Date()
                    journalCount += 1
                } else if declaration.contentType == .affirmation {
                    let affirmationEntry = AffirmationEntry(context: context)
                    affirmationEntry.id = UUID()
                    affirmationEntry.text = declaration.text
                    affirmationEntry.book = declaration.book
                    affirmationEntry.bibleVerseText = declaration.bibleVerseText
                    affirmationEntry.category = declaration.category.rawValue
                    affirmationEntry.isFavorite = declaration.isFavorite ?? false
                    affirmationEntry.createdAt = declaration.lastEdit ?? Date()
                    affirmationEntry.lastModified = declaration.lastEdit ?? Date()
                    affirmationCount += 1
                }
            }
            
            try context.save()
        }
        
        return MigrationResult(
            journalEntries: journalCount,
            affirmationEntries: affirmationCount,
            totalEntries: journalCount + affirmationCount
        )
    }
    
    // MARK: - Clean Up Legacy Data
    func cleanUpLegacyData() {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            Analytics.logEvent("legacy_cleanup_failed", parameters: [
                "error": "documents_directory_not_found"
            ])
            return
        }
        
        let declarationsURL = documentsDirectory.appendingPathComponent("declarations.json")
        
        do {
            if FileManager.default.fileExists(atPath: declarationsURL.path) {
                try FileManager.default.removeItem(at: declarationsURL)
                Analytics.logEvent("legacy_cleanup_success", parameters: [
                    "file_removed": "declarations.json"
                ])
            } else {
                Analytics.logEvent("legacy_cleanup_skipped", parameters: [
                    "reason": "file_not_found"
                ])
            }
        } catch {
            Analytics.logEvent("legacy_cleanup_failed", parameters: [
                "error": error.localizedDescription
            ])
        }
    }
}

// MARK: - Migration Result
struct MigrationResult {
    let journalEntries: Int
    let affirmationEntries: Int
    let totalEntries: Int
}

// MARK: - Error Types
enum DataMigrationError: Error, LocalizedError {
    case migrationFailed
    case contextNotAvailable
    
    var errorDescription: String? {
        switch self {
        case .migrationFailed:
            return "Data migration failed"
        case .contextNotAvailable:
            return "Core Data context not available"
        }
    }
}