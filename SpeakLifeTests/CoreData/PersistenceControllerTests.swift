//
//  PersistenceControllerTests.swift
//  SpeakLifeTests
//
//  Unit tests for PersistenceController
//

import XCTest
import CoreData
@testable import SpeakLife

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
}