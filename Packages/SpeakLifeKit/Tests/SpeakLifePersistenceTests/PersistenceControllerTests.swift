//
//  PersistenceControllerTests.swift
//  SpeakLifeTests
//
//  Unit tests for PersistenceController
//

import XCTest
import CoreData
@testable import SpeakLifePersistence

final class PersistenceControllerTests: XCTestCase {
    
    var persistenceController: PersistenceController!
    
    override func setUp() {
        super.setUp()
        persistenceController = PersistenceController(inMemory: true)
    }
    
    override func tearDown() {
        persistenceController = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    func testPersistenceControllerInitialization() {
        // Then
        XCTAssertNotNil(persistenceController.container)
        XCTAssertNotNil(persistenceController.container.viewContext)
        XCTAssertTrue(persistenceController.container.viewContext.automaticallyMergesChangesFromParent)
    }
    
    func testInMemoryStore() {
        // Given
        let context = persistenceController.container.viewContext
        
        // When
        let journalEntry = JournalEntry(context: context)
        journalEntry.id = UUID()
        journalEntry.text = "Test entry"
        journalEntry.category = "faith"
        journalEntry.createdAt = Date()
        journalEntry.lastModified = Date()
        
        // Then
        XCTAssertNoThrow(try context.save())
        
        let fetchRequest = JournalEntry.fetchRequest()
        let entries = try? context.fetch(fetchRequest)
        XCTAssertEqual(entries?.count, 1)
        XCTAssertEqual(entries?.first?.text, "Test entry")
    }
    
    // MARK: - Save Context Tests
    func testSaveContext() {
        // Given
        let context = persistenceController.container.viewContext
        let journalEntry = JournalEntry(context: context)
        journalEntry.id = UUID()
        journalEntry.text = "Save test entry"
        journalEntry.category = "faith"
        journalEntry.createdAt = Date()
        journalEntry.lastModified = Date()
        
        // When
        XCTAssertNoThrow(persistenceController.save())
        
        // Then
        XCTAssertFalse(context.hasChanges)
    }
    
    func testSaveContextWithNoChanges() {
        // Given
        let context = persistenceController.container.viewContext
        XCTAssertFalse(context.hasChanges)
        
        // When & Then
        XCTAssertNoThrow(persistenceController.save())
    }
    
    // MARK: - Batch Delete Tests
    func testBatchDeleteJournalEntries() throws {
        // Given
        let context = persistenceController.container.viewContext
        
        for i in 1...5 {
            let journalEntry = JournalEntry(context: context)
            journalEntry.id = UUID()
            journalEntry.text = "Entry \(i)"
            journalEntry.category = "faith"
            journalEntry.createdAt = Date()
            journalEntry.lastModified = Date()
        }
        
        try context.save()
        
        let fetchRequest = JournalEntry.fetchRequest()
        let initialEntries = try context.fetch(fetchRequest)
        XCTAssertEqual(initialEntries.count, 5)
        
        // When
        try persistenceController.deleteAll(JournalEntry.self)
        
        // Then
        let remainingEntries = try context.fetch(fetchRequest)
        XCTAssertEqual(remainingEntries.count, 0)
    }
    
    func testBatchDeleteAffirmationEntries() throws {
        // Given
        let context = persistenceController.container.viewContext
        
        for i in 1...3 {
            let affirmationEntry = AffirmationEntry(context: context)
            affirmationEntry.id = UUID()
            affirmationEntry.text = "Affirmation \(i)"
            affirmationEntry.category = "faith"
            affirmationEntry.createdAt = Date()
            affirmationEntry.lastModified = Date()
        }
        
        try context.save()
        
        let fetchRequest = AffirmationEntry.fetchRequest()
        let initialEntries = try context.fetch(fetchRequest)
        XCTAssertEqual(initialEntries.count, 3)
        
        // When
        try persistenceController.deleteAll(AffirmationEntry.self)
        
        // Then
        let remainingEntries = try context.fetch(fetchRequest)
        XCTAssertEqual(remainingEntries.count, 0)
    }
    
    // MARK: - Preview Tests
    func testPreviewPersistenceController() {
        // Given
        let previewController = PersistenceController.preview
        let context = previewController.container.viewContext
        
        // When
        let journalFetchRequest = JournalEntry.fetchRequest()
        let affirmationFetchRequest = AffirmationEntry.fetchRequest()
        
        let journalEntries = try? context.fetch(journalFetchRequest)
        let affirmationEntries = try? context.fetch(affirmationFetchRequest)
        
        // Then
        XCTAssertNotNil(journalEntries)
        XCTAssertNotNil(affirmationEntries)
        XCTAssertTrue((journalEntries?.count ?? 0) > 0)
        XCTAssertTrue((affirmationEntries?.count ?? 0) > 0)
    }

    // MARK: - Throwaway store

    /// A committed row must still be there after the context stops holding it.
    ///
    /// This is the shape of a bug that reddened CI for weeks, in a different
    /// persistence test every run: rows written and awaited came back short.
    ///
    ///   AffirmationRepositoryTests.testSearchAffirmationEntries — 0 of 1
    ///   DeclarationFavoriteRepositoryTests.testFetchByCategory  — 2 of 3
    ///
    /// The store was a SQLite file at `/dev/null`, so every committed page was
    /// thrown away and the rows lived only in that connection's page cache.
    /// Enough of them forces the cache to spill, and what spilled to /dev/null
    /// read back as end-of-file. `reset()` drops the in-memory copies so the
    /// count has to come from the store itself.
    func testCommittedRowsSurviveTheCacheBeingDropped() throws {
        let context = persistenceController.container.viewContext
        let padding = String(repeating: "spill ", count: 200)

        for i in 0..<2_000 {
            let journalEntry = JournalEntry(context: context)
            journalEntry.id = UUID()
            journalEntry.text = "\(padding)\(i)"
            journalEntry.category = "faith"
            journalEntry.createdAt = Date()
            journalEntry.lastModified = Date()
        }

        try context.save()
        context.reset()

        XCTAssertEqual(try context.count(for: JournalEntry.fetchRequest()), 2_000,
                       "Rows were committed and then lost by the store, not by the test.")
    }

    /// Two throwaway stacks are two stores. They shared one path when both
    /// pointed at `/dev/null`, so one test's rows could turn up in another's.
    func testTwoThrowawayStacksDoNotShareAStore() throws {
        let other = PersistenceController(inMemory: true)

        let context = persistenceController.container.viewContext
        let journalEntry = JournalEntry(context: context)
        journalEntry.id = UUID()
        journalEntry.text = "Belongs to the first stack only"
        journalEntry.category = "faith"
        journalEntry.createdAt = Date()
        journalEntry.lastModified = Date()
        try context.save()

        XCTAssertNotEqual(persistenceController.container.persistentStoreDescriptions.first?.url,
                          other.container.persistentStoreDescriptions.first?.url)
        XCTAssertEqual(try other.container.viewContext.count(for: JournalEntry.fetchRequest()), 0)
    }
}