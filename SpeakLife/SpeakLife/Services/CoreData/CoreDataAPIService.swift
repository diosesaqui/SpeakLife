//
//  CoreDataAPIService.swift
//  SpeakLife
//
//  Core Data implementation of APIService protocol for seamless migration
//

import Foundation
import CoreData
import Combine
import FirebaseAnalytics

final class CoreDataAPIService: APIService {

    // Delegate version state to the underlying legacy service. CoreDataAPIService
    // forwards all declaration fetches through legacyAPIService (LocalAPIClient),
    // which is where the @AppStorage-backed remote/local version actually lives.
    // Without these forwarders, DeclarationViewModel.setRemoteDeclarationVersion
    // would write to an in-memory placeholder while loadFromBackEnd read a
    // completely different storage — making version bumps a no-op.
    var remoteVersion: Int {
        get { legacyAPIService.remoteVersion }
        set { legacyAPIService.remoteVersion = newValue }
    }
    var localVersion: Int {
        get { legacyAPIService.localVersion }
        set { legacyAPIService.localVersion = newValue }
    }

    private let journalRepository: any JournalRepositoryProtocol
    private let affirmationRepository: any AffirmationRepositoryProtocol
    // 'var' (not 'let') so the protocol-typed property's setter is reachable
    // through the computed remoteVersion/localVersion forwarders above.
    // APIService isn't AnyObject-constrained, so Swift can't guarantee the
    // conformer is a class without a mutable binding here.
    private var legacyAPIService: APIService
    private let migrationManager: DataMigrationManager
    
    init(journalRepository: any JournalRepositoryProtocol = JournalRepository(),
         affirmationRepository: any AffirmationRepositoryProtocol = AffirmationRepository(),
         legacyAPIService: APIService = LocalAPIClient.shared,
         migrationManager: DataMigrationManager = DataMigrationManager()) {
        self.journalRepository = journalRepository
        self.affirmationRepository = affirmationRepository
        self.legacyAPIService = legacyAPIService
        self.migrationManager = migrationManager
        
        // Setup sync conflict resolution
        let syncResolver = SyncConflictResolver()
        syncResolver.setupConflictResolution()
        
        // Perform migration in background with low priority to avoid blocking UI
        Task(priority: .background) {
            // Add small delay to let UI initialize first
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            
            do {
                try await migrationManager.migrateLegacyData()
                // Track that Core Data service was initialized successfully
                AnalyticsService.shared.track("core_data_service_initialized", parameters: [:])
            } catch {
                AnalyticsService.shared.track("core_data_service_init_failed", parameters: [
                    "error": error.localizedDescription
                ])
                print("Migration failed: \(error)")
            }
        }
    }
    
    // MARK: - APIService Implementation
    func declarations(completion: @escaping ([Declaration], APIError?, Bool) -> Void) {
        Task {
            do {
                // Get both journal and affirmation entries
                let journalEntries = try await journalRepository.fetch(predicate: nil)
                let affirmationEntries = try await affirmationRepository.fetch(predicate: nil)
                
                // Convert to Declaration objects
                var declarations: [Declaration] = []
                
                for entry in journalEntries {
                    // Every JournalEntry is a personal journal, so surface it as
                    // .myOwn regardless of the stored category. Older entries
                    // created from the Today checklist were tagged with the user's
                    // onboarding category; mapping to .myOwn here recovers them in
                    // Profile > Create Your Own, which filters on category == .myOwn.
                    let declaration = Declaration(
                        text: entry.text ?? "",
                        book: entry.book,
                        bibleVerseText: entry.bibleVerseText,
                        category: .myOwn,
                        categories: [],
                        isFavorite: entry.isFavorite,
                        contentType: .journal,
                        lastEdit: entry.lastModified
                    )
                    declarations.append(declaration)
                }
                
                for entry in affirmationEntries {
                    let declaration = Declaration(
                        text: entry.text ?? "",
                        book: entry.book,
                        bibleVerseText: entry.bibleVerseText,
                        category: DeclarationCategory(rawValue: entry.category ?? "faith") ?? .faith,
                        categories: [],
                        isFavorite: entry.isFavorite,
                        contentType: .affirmation,
                        lastEdit: entry.lastModified
                    )
                    declarations.append(declaration)
                }
                
                
                // Also get non-own declarations from legacy service
                legacyAPIService.declarations { legacyDeclarations, error, synced in
                    let nonOwnDeclarations = legacyDeclarations.filter { $0.category != .myOwn }
                    let allDeclarations = declarations + nonOwnDeclarations
                    
                    
                    DispatchQueue.main.async {
                        completion(allDeclarations, error, synced)
                    }
                }
                
            } catch {
                DispatchQueue.main.async {
                    completion([], APIError.noData, false)
                }
            }
        }
    }
    
    func save(declarations: [Declaration], completion: @escaping (Bool) -> Void) {
        // WARNING: This method receives ALL declarations but should NOT delete and recreate everything
        // The legacy implementation may have done that, but with CloudKit we need to be smarter
        
        // For now, just save to legacy service for non-myOwn declarations
        // Individual create/update/delete methods should be used for myOwn content
        let nonOwnDeclarations = declarations.filter { $0.category != .myOwn }
        legacyAPIService.save(declarations: nonOwnDeclarations, completion: completion)
    }
    
    // MARK: - Create Single Declaration
    func createSingleDeclaration(_ declaration: Declaration) async throws {
        guard declaration.category == .myOwn else { return }
        
        let context = PersistenceController.shared.container.viewContext
        
        if declaration.contentType == .journal {
            let journalEntry = JournalEntry(context: context)
            journalEntry.text = declaration.text
            journalEntry.book = declaration.book
            journalEntry.bibleVerseText = declaration.bibleVerseText
            journalEntry.category = declaration.category.rawValue
            journalEntry.isFavorite = declaration.isFavorite ?? false
            try await journalRepository.create(journalEntry)
        } else if declaration.contentType == .affirmation {
            let affirmationEntry = AffirmationEntry(context: context)
            affirmationEntry.text = declaration.text
            affirmationEntry.book = declaration.book
            affirmationEntry.bibleVerseText = declaration.bibleVerseText
            affirmationEntry.category = declaration.category.rawValue
            affirmationEntry.isFavorite = declaration.isFavorite ?? false
            try await affirmationRepository.create(affirmationEntry)
        }
    }
    
    func declarationCategories(completion: @escaping (Set<DeclarationCategory>, APIError?) -> Void) {
        legacyAPIService.declarationCategories(completion: completion)
    }
    
    func save(selectedCategories: Set<DeclarationCategory>, completion: @escaping (Bool) -> Void) {
        legacyAPIService.save(selectedCategories: selectedCategories, completion: completion)
    }
    
    func audio(version: Int, completion: @escaping (WelcomeAudio?, [AudioDeclaration]?) -> Void) {
        legacyAPIService.audio(version: version, completion: completion)
    }
    
    // MARK: - Helper Methods
    func createJournalEntry(text: String, category: DeclarationCategory = .myOwn) async throws {
        let context = PersistenceController.shared.container.viewContext
        let journalEntry = JournalEntry(context: context)
        journalEntry.text = text
        journalEntry.category = category.rawValue
        try await journalRepository.create(journalEntry)
    }
    
    func createAffirmationEntry(text: String, category: DeclarationCategory = .myOwn) async throws {
        let context = PersistenceController.shared.container.viewContext
        let affirmationEntry = AffirmationEntry(context: context)
        affirmationEntry.text = text
        affirmationEntry.category = category.rawValue
        try await affirmationRepository.create(affirmationEntry)
    }
    
    func deleteJournalEntry(_ entry: JournalEntry) async throws {
        try await journalRepository.delete(entry)
    }
    
    func deleteAffirmationEntry(_ entry: AffirmationEntry) async throws {
        try await affirmationRepository.delete(entry)
    }
    
    // MARK: - Remove Duplicates
    func removeDuplicates() async throws {
        
        // Remove duplicate journal entries
        let allJournals = try await journalRepository.fetch(predicate: nil)
        var seenJournalTexts = Set<String>()
        var journalDuplicates = 0
        
        for entry in allJournals {
            guard let text = entry.text else { continue }
            if seenJournalTexts.contains(text) {
                // This is a duplicate
                try await journalRepository.delete(entry)
                journalDuplicates += 1
            } else {
                seenJournalTexts.insert(text)
            }
        }
        
        // Remove duplicate affirmation entries
        let allAffirmations = try await affirmationRepository.fetch(predicate: nil)
        var seenAffirmationTexts = Set<String>()
        var affirmationDuplicates = 0
        
        for entry in allAffirmations {
            guard let text = entry.text else { continue }
            if seenAffirmationTexts.contains(text) {
                // This is a duplicate
                try await affirmationRepository.delete(entry)
                affirmationDuplicates += 1
            } else {
                seenAffirmationTexts.insert(text)
            }
        }
        
    }
    
    // MARK: - Delete by UUID
    func deleteByUUID(_ uuid: UUID, contentType: ContentType) async throws {
        
        if contentType == .journal {
            if let entry = try await journalRepository.fetchById(uuid) {
                try await journalRepository.delete(entry)
            }
        } else if contentType == .affirmation {
            if let entry = try await affirmationRepository.fetchById(uuid) {
                try await affirmationRepository.delete(entry)
            }
        }
    }
    
    // MARK: - Legacy Delete Method (for compatibility)
    func deleteDeclaration(withId idString: String, contentType: ContentType) async throws {
        
        // Since Declaration IDs are text+category+contentType, we need to find by text content
        // Parse the Declaration ID to extract the text
        let categoryRaw = "myOwn"
        let contentTypeRaw = contentType.rawValue
        
        // Remove category and contentType from the end to get the text
        var searchText = idString
        if searchText.hasSuffix(categoryRaw + contentTypeRaw) {
            searchText = String(searchText.dropLast(categoryRaw.count + contentTypeRaw.count))
        }
        
        
        // For legacy compatibility, delete the first matching entry
        if contentType == .journal {
            let entries = try await journalRepository.fetch(predicate: NSPredicate(format: "text == %@", searchText))
            if let firstEntry = entries.first {
                try await journalRepository.delete(firstEntry)
            }
        } else if contentType == .affirmation {
            let entries = try await affirmationRepository.fetch(predicate: NSPredicate(format: "text == %@", searchText))
            if let firstEntry = entries.first {
                try await affirmationRepository.delete(firstEntry)
            }
        }
    }
}