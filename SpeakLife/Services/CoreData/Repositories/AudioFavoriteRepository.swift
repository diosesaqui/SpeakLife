//
//  AudioFavoriteRepository.swift
//  SpeakLife
//
//  Audio Favorite Repository Implementation with CloudKit Sync
//

import Foundation
import CoreData
import Combine

protocol AudioFavoriteRepositoryProtocol: Repository where Entity == AudioFavoriteEntry {
    func findByAudioId(_ audioId: String) async throws -> AudioFavoriteEntry?
    func fetchByTag(_ tag: String) async throws -> [AudioFavoriteEntry]
    func deleteByAudioId(_ audioId: String) async throws
    func createFromAudioDeclaration(_ audio: AudioDeclaration) async throws -> AudioFavoriteEntry
    func toAudioDeclaration(_ entry: AudioFavoriteEntry) -> AudioDeclaration
}

final class AudioFavoriteRepository: AudioFavoriteRepositoryProtocol {
    
    private let context: NSManagedObjectContext
    private let notificationCenter: NotificationCenter
    
    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext,
         notificationCenter: NotificationCenter = .default) {
        self.context = context
        self.notificationCenter = notificationCenter
    }
    
    // MARK: - Create
    func create(_ entity: AudioFavoriteEntry) async throws {
        try await context.perform {
            // Always set a UUID if not present
            if entity.id == nil {
                entity.id = UUID()
            }
            if entity.createdAt == nil {
                entity.createdAt = Date()
            }
            entity.lastModified = Date()
            
            print("📱 Creating AudioFavoriteEntry: \(entity.audioId) - \(entity.title)")
            
            try self.context.save()
            
            print("✅ AudioFavoriteEntry saved to Core Data: \(entity.audioId)")
        }
        
        // Trigger immediate sync for faster perceived performance
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            print("🔄 Requesting CloudKit sync for audio favorite")
            PersistenceController.shared.requestImmediateSync()
        }
    }
    
    // MARK: - Update
    func update(_ entity: AudioFavoriteEntry) async throws {
        try await context.perform {
            entity.lastModified = Date()
            try self.context.save()
        }
    }
    
    // MARK: - Delete
    func delete(_ entity: AudioFavoriteEntry) async throws {
        try await context.perform {
            self.context.delete(entity)
            try self.context.save()
        }
    }
    
    // MARK: - Fetch
    func fetch(predicate: NSPredicate? = nil) async throws -> [AudioFavoriteEntry] {
        try await fetchWithLimit(predicate: predicate, limit: nil)
    }
    
    // MARK: - Fetch with Limit (performance optimization)
    func fetchWithLimit(predicate: NSPredicate? = nil, limit: Int? = nil) async throws -> [AudioFavoriteEntry] {
        try await context.perform {
            let request = AudioFavoriteEntry.fetchRequest()
            request.predicate = predicate
            request.sortDescriptors = [NSSortDescriptor(keyPath: \AudioFavoriteEntry.createdAt, ascending: false)]
            
            // Add batch fetching for better performance
            request.fetchBatchSize = 20
            
            // Add limit if specified
            if let limit = limit {
                request.fetchLimit = limit
            }
            
            // Return properties only for better memory usage
            request.returnsObjectsAsFaults = false
            
            let results = try self.context.fetch(request)
            return results
        }
    }
    
    // MARK: - Fetch by ID
    func fetchById(_ id: UUID) async throws -> AudioFavoriteEntry? {
        let predicate = NSPredicate(format: "id == %@", id as CVarArg)
        let results = try await fetch(predicate: predicate)
        return results.first
    }
    
    // MARK: - Find by Audio ID
    func findByAudioId(_ audioId: String) async throws -> AudioFavoriteEntry? {
        let predicate = NSPredicate(format: "audioId == %@", audioId)
        let results = try await fetch(predicate: predicate)
        return results.first
    }
    
    // MARK: - Fetch by Tag
    func fetchByTag(_ tag: String) async throws -> [AudioFavoriteEntry] {
        let predicate = NSPredicate(format: "tag == %@", tag)
        return try await fetch(predicate: predicate)
    }
    
    // MARK: - Delete by Audio ID
    func deleteByAudioId(_ audioId: String) async throws {
        if let entry = try await findByAudioId(audioId) {
            try await delete(entry)
        }
    }
    
    // MARK: - Observe All
    func observeAll() -> AnyPublisher<[AudioFavoriteEntry], Never> {
        let request = AudioFavoriteEntry.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \AudioFavoriteEntry.createdAt, ascending: false)]
        
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
    
    /// Create AudioFavoriteEntry from AudioDeclaration (with duplicate check)
    func createFromAudioDeclaration(_ audio: AudioDeclaration) async throws -> AudioFavoriteEntry {
        // Check if already exists to prevent duplicates
        if let existing = try await findByAudioId(audio.id) {
            return existing
        }
        
        let entity = AudioFavoriteEntry(context: context)
        entity.audioId = audio.id
        entity.title = audio.title
        entity.subtitle = audio.subtitle
        entity.duration = audio.duration
        entity.imageUrl = audio.imageUrl
        entity.isPremium = audio.isPremium
        entity.tag = audio.tag
        entity.season = Int32(audio.season ?? 0)
        entity.episode = Int32(audio.episode ?? 0)
        
        try await create(entity)
        return entity
    }
    
    /// Convert AudioFavoriteEntry to AudioDeclaration
    func toAudioDeclaration(_ entry: AudioFavoriteEntry) -> AudioDeclaration {
        return AudioDeclaration(
            id: entry.audioId,
            title: entry.title,
            subtitle: entry.subtitle,
            duration: entry.duration,
            imageUrl: entry.imageUrl,
            isPremium: entry.isPremium,
            tag: entry.tag,
            season: entry.season > 0 ? Int(entry.season) : nil,
            episode: entry.episode > 0 ? Int(entry.episode) : nil,
            isFavorite: true,
            favoriteId: entry.id?.uuidString,
            dateFavorited: entry.createdAt
        )
    }
}