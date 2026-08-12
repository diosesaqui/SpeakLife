//
//  JournalRepository.swift
//  SpeakLife
//
//  Journal Repository Implementation
//

import Foundation
import CoreData
import Combine

public protocol JournalRepositoryProtocol: Repository where Entity == JournalEntry {
    func fetchFavorites() async throws -> [JournalEntry]
    func toggleFavorite(_ entry: JournalEntry) async throws
    func search(text: String) async throws -> [JournalEntry]
}

public final class JournalRepository: JournalRepositoryProtocol {

    private let context: NSManagedObjectContext
    private let notificationCenter: NotificationCenter
    private let syncRequester: ImmediateSyncRequesting

    public init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext,
                notificationCenter: NotificationCenter = .default,
                syncRequester: ImmediateSyncRequesting = PersistenceController.defaultSyncRequester) {
        self.context = context
        self.notificationCenter = notificationCenter
        self.syncRequester = syncRequester
    }

    // MARK: - Create
    public func create(_ entity: JournalEntry) async throws {
        try await context.perform {
            // Always set a UUID if not present
            if entity.id == nil {
                entity.id = UUID()
            }
            if entity.createdAt == nil {
                entity.createdAt = Date()
            }
            entity.lastModified = Date()
            
            // Capture values before saving
            let entityId = entity.id?.uuidString ?? "nil"
            let entityText = entity.text?.prefix(50) ?? "nil"
            
            try self.context.save()
        }
        
        // Trigger immediate sync for faster perceived performance
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.syncRequester.requestImmediateSync()
        }
    }
    
    // MARK: - Update
    public func update(_ entity: JournalEntry) async throws {
        try await context.perform {
            entity.lastModified = Date()
            try self.context.save()
        }
    }
    
    // MARK: - Delete
    public func delete(_ entity: JournalEntry) async throws {
        try await context.perform {
            self.context.delete(entity)
            try self.context.save()
        }
    }
    
    // MARK: - Fetch
    public func fetch(predicate: NSPredicate? = nil) async throws -> [JournalEntry] {
        try await context.perform {
            let request = JournalEntry.fetchRequest()
            request.predicate = predicate
            request.sortDescriptors = [NSSortDescriptor(keyPath: \JournalEntry.lastModified, ascending: false)]
            let results = try self.context.fetch(request)
            return results
        }
    }
    
    // MARK: - Fetch by ID
    public func fetchById(_ id: UUID) async throws -> JournalEntry? {
        let predicate = NSPredicate(format: "id == %@", id as CVarArg)
        let results = try await fetch(predicate: predicate)
        return results.first
    }
    
    // MARK: - Observe All
    public func observeAll() -> AnyPublisher<[JournalEntry], Never> {
        let request = JournalEntry.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \JournalEntry.lastModified, ascending: false)]
        
        let initialResults = (try? context.fetch(request)) ?? []
        
        return notificationCenter.publisher(for: .NSManagedObjectContextObjectsDidChange, object: context)
            .compactMap { _ in
                try? self.context.fetch(request)
            }
            .prepend(initialResults)
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    // MARK: - Fetch Favorites
    public func fetchFavorites() async throws -> [JournalEntry] {
        let predicate = NSPredicate(format: "isFavorite == %@", NSNumber(value: true))
        return try await fetch(predicate: predicate)
    }
    
    // MARK: - Toggle Favorite
    public func toggleFavorite(_ entry: JournalEntry) async throws {
        try await context.perform {
            entry.isFavorite.toggle()
            entry.lastModified = Date()
            try self.context.save()
        }
    }
    
    // MARK: - Search
    public func search(text: String) async throws -> [JournalEntry] {
        let predicate = NSPredicate(format: "text CONTAINS[cd] %@", text)
        return try await fetch(predicate: predicate)
    }
    
}
