//
//  JournalRepositoryTests.swift
//  SpeakLifeTests
//
//  Unit tests for JournalRepository
//

import XCTest
import CoreData
import Combine
@testable import SpeakLife

final class JournalRepositoryTests: XCTestCase {
    
    var repository: JournalRepository!
    var testContext: NSManagedObjectContext!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        
        // Create in-memory Core Data stack for testing
        let persistenceController = PersistenceController(inMemory: true)
        testContext = persistenceController.container.viewContext
        repository = JournalRepository(context: testContext)
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables = nil
        repository = nil
        testContext = nil
        super.tearDown()
    }
    
    // MARK: - Create Tests
    func testCreateJournalEntry() async throws {
        // Given
        let journalEntry = JournalEntry(context: testContext)
        journalEntry.text = "Test journal entry"
        journalEntry.category = "faith"
        
        // When
        try await repository.create(journalEntry)
        
        // Then
        XCTAssertNotNil(journalEntry.id)
        XCTAssertNotNil(journalEntry.createdAt)
        XCTAssertNotNil(journalEntry.lastModified)
        XCTAssertEqual(journalEntry.text, "Test journal entry")
        XCTAssertEqual(journalEntry.category, "faith")
    }
    
    // MARK: - Update Tests
    func testUpdateJournalEntry() async throws {
        // Given
        let journalEntry = JournalEntry(context: testContext)
        journalEntry.text = "Original text"
        journalEntry.category = "faith"
        try await repository.create(journalEntry)
        
        let originalModifiedDate = journalEntry.lastModified
        
        // Wait a moment to ensure timestamp difference
        try await Task.sleep(nanoseconds: 1_000_000)
        
        // When
        journalEntry.text = "Updated text"
        try await repository.update(journalEntry)
        
        // Then
        XCTAssertEqual(journalEntry.text, "Updated text")
        XCTAssertNotEqual(journalEntry.lastModified, originalModifiedDate)
        XCTAssertTrue(journalEntry.lastModified! > originalModifiedDate!)
    }
    
    // MARK: - Delete Tests
    func testDeleteJournalEntry() async throws {
        // Given
        let journalEntry = JournalEntry(context: testContext)
        journalEntry.text = "Entry to delete"
        journalEntry.category = "faith"
        try await repository.create(journalEntry)
        
        let entryId = journalEntry.id!
        
        // When
        try await repository.delete(journalEntry)
        
        // Then
        let deletedEntry = try await repository.fetchById(entryId)
        XCTAssertNil(deletedEntry)
    }
    
    // MARK: - Fetch Tests
    func testFetchAllJournalEntries() async throws {
        // Given
        let entry1 = JournalEntry(context: testContext)
        entry1.text = "Entry 1"
        entry1.category = "faith"
        try await repository.create(entry1)
        
        let entry2 = JournalEntry(context: testContext)
        entry2.text = "Entry 2"
        entry2.category = "hope"
        try await repository.create(entry2)
        
        // When
        let entries = try await repository.fetch()
        
        // Then
        XCTAssertEqual(entries.count, 2)
        XCTAssertTrue(entries.contains { $0.text == "Entry 1" })
        XCTAssertTrue(entries.contains { $0.text == "Entry 2" })
    }
    
    func testFetchJournalEntryById() async throws {
        // Given
        let journalEntry = JournalEntry(context: testContext)
        journalEntry.text = "Test entry"
        journalEntry.category = "faith"
        try await repository.create(journalEntry)
        
        let entryId = journalEntry.id!
        
        // When
        let fetchedEntry = try await repository.fetchById(entryId)
        
        // Then
        XCTAssertNotNil(fetchedEntry)
        XCTAssertEqual(fetchedEntry?.text, "Test entry")
        XCTAssertEqual(fetchedEntry?.id, entryId)
    }
    
    // MARK: - Favorites Tests
    func testToggleFavorite() async throws {
        // Given
        let journalEntry = JournalEntry(context: testContext)
        journalEntry.text = "Test favorite"
        journalEntry.category = "faith"
        journalEntry.isFavorite = false
        try await repository.create(journalEntry)
        
        // When
        try await repository.toggleFavorite(journalEntry)
        
        // Then
        XCTAssertTrue(journalEntry.isFavorite)
        
        // When - toggle again
        try await repository.toggleFavorite(journalEntry)
        
        // Then
        XCTAssertFalse(journalEntry.isFavorite)
    }
    
    func testFetchFavorites() async throws {
        // Given
        let entry1 = JournalEntry(context: testContext)
        entry1.text = "Favorite entry"
        entry1.category = "faith"
        entry1.isFavorite = true
        try await repository.create(entry1)
        
        let entry2 = JournalEntry(context: testContext)
        entry2.text = "Regular entry"
        entry2.category = "faith"
        entry2.isFavorite = false
        try await repository.create(entry2)
        
        // When
        let favorites = try await repository.fetchFavorites()
        
        // Then
        XCTAssertEqual(favorites.count, 1)
        XCTAssertEqual(favorites.first?.text, "Favorite entry")
        XCTAssertTrue(favorites.first?.isFavorite ?? false)
    }
    
    // MARK: - Search Tests
    func testSearchJournalEntries() async throws {
        // Given
        let entry1 = JournalEntry(context: testContext)
        entry1.text = "This is about faith and hope"
        entry1.category = "faith"
        try await repository.create(entry1)
        
        let entry2 = JournalEntry(context: testContext)
        entry2.text = "This is about love and peace"
        entry2.category = "love"
        try await repository.create(entry2)
        
        // When
        let searchResults = try await repository.search(text: "faith")
        
        // Then
        XCTAssertEqual(searchResults.count, 1)
        XCTAssertEqual(searchResults.first?.text, "This is about faith and hope")
    }
    
    // MARK: - Observer Tests
    func testObserveAllJournalEntries() async throws {
        // Given
        let expectation = XCTestExpectation(description: "Observe journal entries")
        var observedEntries: [JournalEntry] = []
        
        repository.observeAll()
            .sink { entries in
                observedEntries = entries
                if entries.count > 0 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When
        let journalEntry = JournalEntry(context: testContext)
        journalEntry.text = "Observed entry"
        journalEntry.category = "faith"
        try await repository.create(journalEntry)
        
        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(observedEntries.count, 1)
        XCTAssertEqual(observedEntries.first?.text, "Observed entry")
    }
}