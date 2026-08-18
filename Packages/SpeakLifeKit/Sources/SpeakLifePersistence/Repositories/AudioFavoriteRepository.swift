//
//  AudioFavoriteRepository.swift
//  SpeakLife
//
//  Audio Favorite Repository Implementation with CloudKit Sync
//

import Foundation
import CoreData
import Combine
import SpeakLifeCore

public protocol AudioFavoriteRepositoryProtocol: Repository where Entity == AudioFavoriteEntry {
    func findByAudioId(_ audioId: String) async throws -> AudioFavoriteEntry?
    func fetchByTag(_ tag: String) async throws -> [AudioFavoriteEntry]
    func deleteByAudioId(_ audioId: String) async throws
    func createFromAudioDeclaration(_ audio: AudioDeclaration) async throws -> AudioFavoriteEntry
    func toAudioDeclaration(_ entry: AudioFavoriteEntry) -> AudioDeclaration
}

public final class AudioFavoriteRepository: AudioFavoriteRepositoryProtocol {

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
    public func create(_ entity: AudioFavoriteEntry) async throws {
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
            self.syncRequester.requestImmediateSync()
        }
    }
    
    // MARK: - Update
    public func update(_ entity: AudioFavoriteEntry) async throws {
        try await context.perform {
            entity.lastModified = Date()
            try self.context.save()
        }
    }
    
    // MARK: - Delete
    public func delete(_ entity: AudioFavoriteEntry) async throws {
        try await context.perform {
            self.context.delete(entity)
            try self.context.save()
        }
    }
    
    // MARK: - Fetch
    public func fetch(predicate: NSPredicate? = nil) async throws -> [AudioFavoriteEntry] {
        try await fetchWithLimit(predicate: predicate, limit: nil)
    }

    // MARK: - Fetch with Limit (performance optimization)
    public func fetchWithLimit(predicate: NSPredicate? = nil, limit: Int? = nil) async throws -> [AudioFavoriteEntry] {
        try await context.perform {
            let request = AudioFavoriteEntry.fetchRequest()
            request.predicate = predicate
            request.sortDescriptors = [
                NSSortDescriptor(keyPath: \AudioFavoriteEntry.createdAt, ascending: false),
                // Tiebreak, so the order is total rather than merely mostly
                // decided. `createdAt` is not unique — a migration importing a
                // legacy file writes its rows in one tight loop — and an
                // ambiguous order makes the results of any one fetch a
                // coin toss.
                NSSortDescriptor(keyPath: \AudioFavoriteEntry.audioId, ascending: true)
            ]

            // No `fetchBatchSize`. It used to be 20, "for better performance",
            // set alongside `returnsObjectsAsFaults = false` on the same
            // request — and those two ask for opposite things. Batching says
            // hand back faults and page them in twenty at a time; the other
            // says materialize every row now. Together they were losing rows:
            //
            //   AudioFavoriteRepositoryTests.testFetchByTag — 1 of 2
            //   AudioFavoriteRepositoryTests.testFindByAudioId — nil of 1
            //
            // Both save every row and await it before reading, so there is no
            // race in the tests. A tiebreak sort was added first, on the theory
            // that ties at a page boundary were what got paged over; it did not
            // hold, and the fetches kept coming back short. Batching buys
            // nothing here anyway — this is one person's favorites, hundreds of
            // rows at the outside, and the caller wants them all materialized.

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
    public func fetchById(_ id: UUID) async throws -> AudioFavoriteEntry? {
        let predicate = NSPredicate(format: "id == %@", id as CVarArg)
        let results = try await fetch(predicate: predicate)
        return results.first
    }
    
    // MARK: - Find by Audio ID
    public func findByAudioId(_ audioId: String) async throws -> AudioFavoriteEntry? {
        let predicate = NSPredicate(format: "audioId == %@", audioId)
        let results = try await fetch(predicate: predicate)
        return results.first
    }
    
    // MARK: - Fetch by Tag
    public func fetchByTag(_ tag: String) async throws -> [AudioFavoriteEntry] {
        let predicate = NSPredicate(format: "tag == %@", tag)
        return try await fetch(predicate: predicate)
    }
    
    // MARK: - Delete by Audio ID
    public func deleteByAudioId(_ audioId: String) async throws {
        if let entry = try await findByAudioId(audioId) {
            try await delete(entry)
        }
    }
    
    // MARK: - Observe All
    public func observeAll() -> AnyPublisher<[AudioFavoriteEntry], Never> {
        let request = AudioFavoriteEntry.fetchRequest()
        request.sortDescriptors = [
                NSSortDescriptor(keyPath: \AudioFavoriteEntry.createdAt, ascending: false),
                // Tiebreak, so the order is total rather than merely mostly
                // decided. `createdAt` is not unique — a migration importing a
                // legacy file writes its rows in one tight loop — and an
                // ambiguous order makes each emission a different arrangement
                // of the same rows, which the UI reads as movement.
                NSSortDescriptor(keyPath: \AudioFavoriteEntry.audioId, ascending: true)
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
    
    /// Create AudioFavoriteEntry from AudioDeclaration (with duplicate check)
    ///
    /// The insert and every attribute write happen inside `context.perform`,
    /// and that is the whole point of the closure.
    ///
    /// `context` is the container's `viewContext`, which is confined to the
    /// main queue. This method is `async` and nonisolated, so its body runs on
    /// the cooperative pool — including when `AudioFavoritesManager` calls it
    /// from a `Task { @MainActor }`, because awaiting a nonisolated async
    /// function hops straight back off the main actor. Inserting into the
    /// context from there is an unsynchronized mutation, and Core Data punishes
    /// it in two ways, both of which this project saw:
    ///
    ///   · quietly, by losing a write — a test that saved 100 favorites fetched
    ///     back 99, on roughly three runs in five;
    ///   · loudly, by corrupting change processing —
    ///     "-[__NSCFSet addObject:]: attempt to insert nil".
    ///
    /// `create` below was already doing this correctly; only the construction
    /// above it was outside the queue.
    public func createFromAudioDeclaration(_ audio: AudioDeclaration) async throws -> AudioFavoriteEntry {
        // Check if already exists to prevent duplicates
        if let existing = try await findByAudioId(audio.id) {
            return existing
        }

        let entity = await context.perform {
            let entity = AudioFavoriteEntry(context: self.context)
            entity.audioId = audio.id
            entity.title = audio.title
            entity.subtitle = audio.subtitle
            entity.duration = audio.duration
            entity.imageUrl = audio.imageUrl
            entity.isPremium = audio.isPremium
            entity.tag = audio.tag
            entity.season = Int32(audio.season ?? 0)
            entity.episode = Int32(audio.episode ?? 0)
            return entity
        }

        try await create(entity)
        return entity
    }
    
    /// Convert AudioFavoriteEntry to AudioDeclaration
    public func toAudioDeclaration(_ entry: AudioFavoriteEntry) -> AudioDeclaration {
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