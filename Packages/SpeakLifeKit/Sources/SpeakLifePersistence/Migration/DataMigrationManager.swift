//
//  DataMigrationManager.swift
//  SpeakLife
//
//  Data Migration Manager for Legacy Data to Core Data
//

import Foundation
import CoreData
import SpeakLifeCore

public final class DataMigrationManager {

    /// Injected by the app at startup with a `LocalAPIClient`-producing closure,
    /// so this file does not have to name a class that lives in the app target.
    /// Left nil in the package's own build; the test suite passes its
    /// `MockAPIService` explicitly through the `legacyAPIService:` initializer
    /// parameter and never reads this.
    public static var defaultLegacyAPIServiceFactory: (() -> APIService)?

    private let persistenceController: PersistenceController
    private let legacyAPIService: APIService
    private let favoritesMigrationService: FavoritesMigrationService

    public init(persistenceController: PersistenceController = .shared,
                legacyAPIService: APIService? = nil,
                favoritesMigrationService: FavoritesMigrationService = FavoritesMigrationService()) {
        self.persistenceController = persistenceController
        // Prefer the explicit arg (used by tests). Fall back to the app-installed
        // factory. If neither is set (e.g. running under `swift test` without the
        // factory), use `NoOpLegacyAPIService` — `migrateLegacyData` will short-
        // circuit on the empty declaration list and no-op cleanly.
        self.legacyAPIService = legacyAPIService
            ?? Self.defaultLegacyAPIServiceFactory?()
            ?? NoOpLegacyAPIService()
        self.favoritesMigrationService = favoritesMigrationService
    }

    // MARK: - Migration
    public func migrateLegacyData() async throws {
        let context = persistenceController.container.viewContext
        
        // Check if migration has already been performed
        let migrationKey = "HasMigratedToCoreData"
        if UserDefaults.standard.bool(forKey: migrationKey) {
            // Track that user already migrated
            CoreAnalytics.track("core_data_migration_skipped", parameters: [
                "reason": "already_migrated"
            ])
            return
        }
        
        // Track migration start
        let migrationStartTime = Date()
        CoreAnalytics.track("core_data_migration_started", parameters: [:])
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            legacyAPIService.declarations { [weak self] declarations, error, _ in
                guard let self = self else {
                    continuation.resume(throwing: DataMigrationError.migrationFailed)
                    return
                }
                
                if let error = error {
                    // Track API error
                    CoreAnalytics.track("core_data_migration_failed", parameters: [
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
                        
                        // Migrate favorites after declarations
                        try await self.favoritesMigrationService.migrateLegacyFavorites()
                        
                        // Only set migration flag if we actually migrated some data
                        if migrationResult.totalEntries > 0 {
                            UserDefaults.standard.set(true, forKey: migrationKey)
                            
                            // Clean up legacy data only after successful migration
                            self.cleanUpLegacyData()
                        } else {
                            // Warning: 
                            print("⚠️ No data to migrate - keeping migration flag false")
                        }
                        
                        // Track successful migration
                        CoreAnalytics.track("core_data_migration_success", parameters: [
                            "total_entries": migrationResult.totalEntries,
                            "journal_entries": migrationResult.journalEntries,
                            "affirmation_entries": migrationResult.affirmationEntries,
                            "migration_duration_seconds": Int(migrationDuration),
                            "had_legacy_data": migrationResult.totalEntries > 0
                        ])
                        
                        continuation.resume()
                    } catch {
                        // Track migration failure
                        CoreAnalytics.track("core_data_migration_failed", parameters: [
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
    public func cleanUpLegacyData() {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            CoreAnalytics.track("legacy_cleanup_failed", parameters: [
                "error": "documents_directory_not_found"
            ])
            return
        }
        
        let declarationsURL = documentsDirectory.appendingPathComponent("declarations.json")
        
        do {
            if FileManager.default.fileExists(atPath: declarationsURL.path) {
                try FileManager.default.removeItem(at: declarationsURL)
                CoreAnalytics.track("legacy_cleanup_success", parameters: [
                    "file_removed": "declarations.json"
                ])
            } else {
                CoreAnalytics.track("legacy_cleanup_skipped", parameters: [
                    "reason": "file_not_found"
                ])
            }
        } catch {
            CoreAnalytics.track("legacy_cleanup_failed", parameters: [
                "error": error.localizedDescription
            ])
        }
    }
}

// MARK: - Migration Result
public struct MigrationResult {
    public let journalEntries: Int
    public let affirmationEntries: Int
    public let totalEntries: Int

    public init(journalEntries: Int, affirmationEntries: Int, totalEntries: Int) {
        self.journalEntries = journalEntries
        self.affirmationEntries = affirmationEntries
        self.totalEntries = totalEntries
    }
}

// MARK: - Error Types
public enum DataMigrationError: Error, LocalizedError {
    case migrationFailed
    case contextNotAvailable

    public var errorDescription: String? {
        switch self {
        case .migrationFailed:
            return "Data migration failed"
        case .contextNotAvailable:
            return "Core Data context not available"
        }
    }
}

// MARK: - No-op fallback service
//
// Used when neither the app-installed factory nor an explicit `legacyAPIService:`
// arg is available (package's own `swift build`, or a test that forgot to inject).
// `declarations` hands back an empty list, which makes `migrateLegacyData` a no-op.
// Never used by the shipping app or by the migration tests.
private final class NoOpLegacyAPIService: APIService {
    var remoteVersion: Int = 0
    var localVersion: Int = 0

    func declarations(completion: @escaping ([Declaration], APIError?, Bool) -> Void) {
        completion([], nil, false)
    }
    func save(declarations: [Declaration], completion: @escaping (Bool) -> Void) {
        completion(true)
    }
    func declarationCategories(completion: @escaping (Set<DeclarationCategory>, APIError?) -> Void) {
        completion([], nil)
    }
    func save(selectedCategories: Set<DeclarationCategory>, completion: @escaping (Bool) -> Void) {
        completion(true)
    }
    func audio(version: Int, completion: @escaping (WelcomeAudio?, [AudioDeclaration]?) -> Void) {
        completion(nil, nil)
    }
}