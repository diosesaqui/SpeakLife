//
//  BatchFetchCoordinator.swift
//  SpeakLife
//
//  Coordinates batch fetching to optimize Core Data performance
//

import Foundation
import CoreData

final class BatchFetchCoordinator {
    
    static let shared = BatchFetchCoordinator()
    
    private let context: NSManagedObjectContext
    
    private init() {
        // Create a private context for batch operations
        self.context = PersistenceController.shared.container.newBackgroundContext()
        self.context.automaticallyMergesChangesFromParent = true
    }
    
    // MARK: - Batch Fetch All Favorites
    func fetchAllFavoritesOptimized() async -> (declarations: [Declaration], audio: [AudioDeclaration]) {
        await withCheckedContinuation { continuation in
            // All fetching and object access must happen on the context's own
            // queue; the context merges CloudKit changes concurrently and
            // touching its objects from another thread crashes.
            context.perform { [context] in
                var declarations: [Declaration] = []
                var audioDeclarations: [AudioDeclaration] = []

                do {
                    // Fully materialize results; no lazy batch faulting so
                    // nothing touches the context after the fetch returns
                    let declarationRequest = DeclarationFavoriteEntry.fetchRequest()
                    declarationRequest.returnsObjectsAsFaults = false
                    declarationRequest.relationshipKeyPathsForPrefetching = []

                    let audioRequest = AudioFavoriteEntry.fetchRequest()
                    audioRequest.returnsObjectsAsFaults = false
                    
                    // Fetch declaration favorites
                    let declarationEntries = try context.fetch(declarationRequest)
                    declarations = declarationEntries.compactMap { entry in
                        // Skip empty entries
                        guard !entry.text.isEmpty && !entry.declarationId.isEmpty && !entry.category.isEmpty else { return nil }
                        
                        let declarationCategory = DeclarationCategory(rawValue: entry.category) ?? .faith
                        return Declaration(
                            text: entry.text,
                            book: entry.book,
                            bibleVerseText: entry.bibleVerseText,
                            category: declarationCategory,
                            categories: [declarationCategory],
                            isFavorite: true,
                            contentType: ContentType(rawValue: entry.contentType ?? "affirmation") ?? .affirmation,
                            lastEdit: entry.createdAt
                        )
                    }
                    
                    // Fetch audio favorites
                    let audioEntries = try context.fetch(audioRequest)
                    for entry in audioEntries {
                        // Skip empty entries
                        guard !entry.audioId.isEmpty && !entry.title.isEmpty else { continue }
                        
                        let audioDeclaration = AudioDeclaration(
                            id: entry.audioId,
                            title: entry.title,
                            subtitle: entry.subtitle,
                            duration: entry.duration,
                            imageUrl: entry.imageUrl,
                            isPremium: entry.isPremium,
                            tag: entry.tag,
                            season: Int(entry.season),
                            episode: Int(entry.episode),
                            isFavorite: true,
                            favoriteId: entry.id?.uuidString,
                            dateFavorited: entry.dateFavorited
                        )
                        audioDeclarations.append(audioDeclaration)
                    }
                    
                } catch {
                    print("Batch fetch error: \(error)")
                }
                
                continuation.resume(returning: (declarations, audioDeclarations))
            }
        }
    }
    
    // MARK: - Batch Fetch MyOwn Content
    func fetchMyOwnContentOptimized() async -> [Declaration] {
        await withCheckedContinuation { continuation in
            context.perform { [context] in
                var declarations: [Declaration] = []

                do {
                    // Fetch journal entries
                    let journalRequest = JournalEntry.fetchRequest()
                    journalRequest.returnsObjectsAsFaults = false
                    journalRequest.predicate = NSPredicate(format: "category == %@", "myOwn")

                    // Fetch affirmation entries
                    let affirmationRequest = AffirmationEntry.fetchRequest()
                    affirmationRequest.returnsObjectsAsFaults = false
                    affirmationRequest.predicate = NSPredicate(format: "category == %@", "myOwn")
                    
                    // Process journals
                    let journalEntries = try context.fetch(journalRequest)
                    for entry in journalEntries {
                        declarations.append(Declaration(
                            text: entry.text ?? "",
                            book: entry.book,
                            bibleVerseText: entry.bibleVerseText,
                            category: .myOwn,
                            categories: [.myOwn],
                            isFavorite: entry.isFavorite,
                            contentType: .journal,
                            lastEdit: entry.lastModified
                        ))
                    }
                    
                    // Process affirmations
                    let affirmationEntries = try context.fetch(affirmationRequest)
                    for entry in affirmationEntries {
                        declarations.append(Declaration(
                            text: entry.text ?? "",
                            book: entry.book,
                            bibleVerseText: entry.bibleVerseText,
                            category: .myOwn,
                            categories: [.myOwn],
                            isFavorite: entry.isFavorite,
                            contentType: .affirmation,
                            lastEdit: entry.lastModified
                        ))
                    }
                    
                } catch {
                    print("MyOwn content fetch error: \(error)")
                }
                
                continuation.resume(returning: declarations)
            }
        }
    }
}