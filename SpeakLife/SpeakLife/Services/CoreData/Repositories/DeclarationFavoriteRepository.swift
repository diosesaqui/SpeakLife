//
//  DeclarationFavoriteRepository.swift
//  SpeakLife
//
//  Declaration Favorite Repository Implementation with CloudKit Sync
//

import Foundation
import CoreData
import Combine

protocol DeclarationFavoriteRepositoryProtocol: Repository where Entity == DeclarationFavoriteEntry {
    func findByDeclarationId(_ declarationId: String) async throws -> DeclarationFavoriteEntry?
    func fetchByCategory(_ category: String) async throws -> [DeclarationFavoriteEntry]
    func fetchByContentType(_ contentType: String) async throws -> [DeclarationFavoriteEntry]
    func deleteByDeclarationId(_ declarationId: String) async throws
    func createFromDeclaration(_ declaration: Declaration) async throws -> DeclarationFavoriteEntry
    func toDeclaration(_ entry: DeclarationFavoriteEntry) -> Declaration
}

final class DeclarationFavoriteRepository: DeclarationFavoriteRepositoryProtocol {
    
    private let context: NSManagedObjectContext
    private let notificationCenter: NotificationCenter
    private let syncRequester: ImmediateSyncRequesting

    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext,
         notificationCenter: NotificationCenter = .default,
         syncRequester: ImmediateSyncRequesting = PersistenceController.defaultSyncRequester) {
        self.context = context
        self.notificationCenter = notificationCenter
        self.syncRequester = syncRequester
    }
    
    // MARK: - Create
    func create(_ entity: DeclarationFavoriteEntry) async throws {
        try await context.perform {
            // Always set a UUID if not present
            if entity.id == nil {
                entity.id = UUID()
            }
            if entity.createdAt == nil {
                entity.createdAt = Date()
            }
            entity.lastModified = Date()
            
            print("📱 Creating DeclarationFavoriteEntry: \(entity.declarationId ?? "unknown") - \(entity.text ?? "")")
            
            try self.context.save()
            
            print("✅ DeclarationFavoriteEntry saved to Core Data: \(entity.declarationId ?? "unknown")")
        }
        
        // Trigger immediate sync for faster perceived performance
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            print("🔄 Requesting CloudKit sync for declaration favorite")
            self.syncRequester.requestImmediateSync()
        }
    }
    
    // MARK: - Update
    func update(_ entity: DeclarationFavoriteEntry) async throws {
        try await context.perform {
            entity.lastModified = Date()
            try self.context.save()
        }
    }
    
    // MARK: - Delete
    func delete(_ entity: DeclarationFavoriteEntry) async throws {
        try await context.perform {
            self.context.delete(entity)
            try self.context.save()
        }
    }
    
    // MARK: - Fetch
    func fetch(predicate: NSPredicate? = nil) async throws -> [DeclarationFavoriteEntry] {
        try await context.perform {
            let request = DeclarationFavoriteEntry.fetchRequest()
            request.predicate = predicate
            request.sortDescriptors = [
                NSSortDescriptor(keyPath: \DeclarationFavoriteEntry.createdAt, ascending: false),
                // Total order, same reason as AudioFavoriteRepository.
                NSSortDescriptor(keyPath: \DeclarationFavoriteEntry.declarationId, ascending: true)
            ]
            let results = try self.context.fetch(request)
            return results
        }
    }
    
    // MARK: - Fetch by ID
    func fetchById(_ id: UUID) async throws -> DeclarationFavoriteEntry? {
        let predicate = NSPredicate(format: "id == %@", id as CVarArg)
        let results = try await fetch(predicate: predicate)
        return results.first
    }
    
    // MARK: - Find by Declaration ID
    func findByDeclarationId(_ declarationId: String) async throws -> DeclarationFavoriteEntry? {
        let predicate = NSPredicate(format: "declarationId == %@", declarationId)
        let results = try await fetch(predicate: predicate)
        return results.first
    }
    
    // MARK: - Fetch by Category
    func fetchByCategory(_ category: String) async throws -> [DeclarationFavoriteEntry] {
        let predicate = NSPredicate(format: "category == %@", category)
        return try await fetch(predicate: predicate)
    }
    
    // MARK: - Fetch by Content Type
    func fetchByContentType(_ contentType: String) async throws -> [DeclarationFavoriteEntry] {
        let predicate = NSPredicate(format: "contentType == %@", contentType)
        return try await fetch(predicate: predicate)
    }
    
    // MARK: - Delete by Declaration ID
    func deleteByDeclarationId(_ declarationId: String) async throws {
        if let entry = try await findByDeclarationId(declarationId) {
            try await delete(entry)
        }
    }
    
    // MARK: - Observe All
    func observeAll() -> AnyPublisher<[DeclarationFavoriteEntry], Never> {
        let request = DeclarationFavoriteEntry.fetchRequest()
        request.sortDescriptors = [
                NSSortDescriptor(keyPath: \DeclarationFavoriteEntry.createdAt, ascending: false),
                // Total order, same reason as AudioFavoriteRepository.
                NSSortDescriptor(keyPath: \DeclarationFavoriteEntry.declarationId, ascending: true)
            ]
        
        let initialResults = (try? context.fetch(request)) ?? []
        
        return notificationCenter.publisher(for: .NSManagedObjectContextObjectsDidChange, object: context)
            .compactMap { _ in
                try? self.context.fetch(request)
            }
            .prepend(initialResults)
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    // MARK: - Helper Methods
    
    /// Create DeclarationFavoriteEntry from Declaration (with duplicate check)
    func createFromDeclaration(_ declaration: Declaration) async throws -> DeclarationFavoriteEntry {
        // Check if already exists to prevent duplicates
        if let existing = try await findByDeclarationId(declaration.id) {
            return existing
        }
        
        let entity = DeclarationFavoriteEntry(context: context)
        entity.declarationId = declaration.id
        entity.text = declaration.text
        entity.category = declaration.category.rawValue
        entity.contentType = declaration.contentType.rawValue
        entity.book = declaration.book
        entity.bibleVerseText = declaration.bibleVerseText
        
        try await create(entity)
        return entity
    }
    
    /// Convert DeclarationFavoriteEntry to Declaration
    func toDeclaration(_ entry: DeclarationFavoriteEntry) -> Declaration {
        return Declaration(
            text: entry.text ?? "",
            book: entry.book,
            bibleVerseText: entry.bibleVerseText,
            category: DeclarationCategory(rawValue: entry.category ?? "faith") ?? .faith,
            categories: [],
            isFavorite: true,
            contentType: ContentType(rawValue: entry.contentType ?? "affirmation") ?? .affirmation,
            lastEdit: entry.lastModified
        )
    }
}