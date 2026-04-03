//
//  AffirmationRepositoryTests.swift
//  SpeakLifeTests
//
//  Unit tests for AffirmationRepository
//

import XCTest
import CoreData
import Combine
@testable import SpeakLife

final class AffirmationRepositoryTests: XCTestCase {
    
    var repository: AffirmationRepository!
    var testContext: NSManagedObjectContext!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        
        // Create in-memory Core Data stack for testing
        let persistenceController = PersistenceController(inMemory: true)
        testContext = persistenceController.container.viewContext
        repository = AffirmationRepository(context: testContext)
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables = nil
        repository = nil
        testContext = nil
        super.tearDown()
    }
    
    // MARK: - Create Tests
    func testCreateAffirmationEntry() async throws {
        // Given
        let affirmationEntry = AffirmationEntry(context: testContext)
        affirmationEntry.text = "I am blessed and highly favored"
        affirmationEntry.category = "faith"
        
        // When
        try await repository.create(affirmationEntry)
        
        // Then
        XCTAssertNotNil(affirmationEntry.id)
        XCTAssertNotNil(affirmationEntry.createdAt)
        XCTAssertNotNil(affirmationEntry.lastModified)
        XCTAssertEqual(affirmationEntry.text, "I am blessed and highly favored")
        XCTAssertEqual(affirmationEntry.category, "faith")
    }
    
    // MARK: - Update Tests
    func testUpdateAffirmationEntry() async throws {
        // Given
        let affirmationEntry = AffirmationEntry(context: testContext)
        affirmationEntry.text = "Original affirmation"
        affirmationEntry.category = "faith"
        try await repository.create(affirmationEntry)
        
        let originalModifiedDate = affirmationEntry.lastModified
        
        // Wait a moment to ensure timestamp difference
        try await Task.sleep(nanoseconds: 1_000_000)
        
        // When
        affirmationEntry.text = "Updated affirmation"
        try await repository.update(affirmationEntry)
        
        // Then
        XCTAssertEqual(affirmationEntry.text, "Updated affirmation")
        XCTAssertNotEqual(affirmationEntry.lastModified, originalModifiedDate)
        XCTAssertTrue(affirmationEntry.lastModified! > originalModifiedDate!)
    }
    
    // MARK: - Delete Tests
    func testDeleteAffirmationEntry() async throws {
        // Given
        let affirmationEntry = AffirmationEntry(context: testContext)
        affirmationEntry.text = "Affirmation to delete"
        affirmationEntry.category = "faith"
        try await repository.create(affirmationEntry)
        
        let entryId = affirmationEntry.id!
        
        // When
        try await repository.delete(affirmationEntry)
        
        // Then
        let deletedEntry = try await repository.fetchById(entryId)
        XCTAssertNil(deletedEntry)
    }
    
    // MARK: - Fetch Tests
    func testFetchAllAffirmationEntries() async throws {
        // Given
        let entry1 = AffirmationEntry(context: testContext)
        entry1.text = "I am loved"
        entry1.category = "love"
        try await repository.create(entry1)
        
        let entry2 = AffirmationEntry(context: testContext)
        entry2.text = "I am strong"
        entry2.category = "strength"
        try await repository.create(entry2)
        
        // When
        let entries = try await repository.fetch()
        
        // Then
        XCTAssertEqual(entries.count, 2)
        XCTAssertTrue(entries.contains { $0.text == "I am loved" })
        XCTAssertTrue(entries.contains { $0.text == "I am strong" })
    }
    
    func testFetchAffirmationEntryById() async throws {
        // Given
        let affirmationEntry = AffirmationEntry(context: testContext)
        affirmationEntry.text = "Test affirmation"
        affirmationEntry.category = "faith"
        try await repository.create(affirmationEntry)
        
        let entryId = affirmationEntry.id!
        
        // When
        let fetchedEntry = try await repository.fetchById(entryId)
        
        // Then
        XCTAssertNotNil(fetchedEntry)
        XCTAssertEqual(fetchedEntry?.text, "Test affirmation")
        XCTAssertEqual(fetchedEntry?.id, entryId)
    }
    
    // MARK: - Category Tests
    func testFetchByCategory() async throws {
        // Given
        let faithEntry = AffirmationEntry(context: testContext)
        faithEntry.text = "Faith affirmation"
        faithEntry.category = "faith"
        try await repository.create(faithEntry)
        
        let loveEntry = AffirmationEntry(context: testContext)
        loveEntry.text = "Love affirmation"
        loveEntry.category = "love"
        try await repository.create(loveEntry)
        
        // When
        let faithEntries = try await repository.fetchByCategory("faith")
        
        // Then
        XCTAssertEqual(faithEntries.count, 1)
        XCTAssertEqual(faithEntries.first?.text, "Faith affirmation")
        XCTAssertEqual(faithEntries.first?.category, "faith")
    }
    
    // MARK: - Favorites Tests
    func testToggleFavorite() async throws {
        // Given
        let affirmationEntry = AffirmationEntry(context: testContext)
        affirmationEntry.text = "Favorite affirmation"
        affirmationEntry.category = "faith"
        affirmationEntry.isFavorite = false
        try await repository.create(affirmationEntry)
        
        // When
        try await repository.toggleFavorite(affirmationEntry)
        
        // Then
        XCTAssertTrue(affirmationEntry.isFavorite)
        
        // When - toggle again
        try await repository.toggleFavorite(affirmationEntry)
        
        // Then
        XCTAssertFalse(affirmationEntry.isFavorite)
    }
    
    func testFetchFavorites() async throws {
        // Given
        let favoriteEntry = AffirmationEntry(context: testContext)
        favoriteEntry.text = "Favorite affirmation"
        favoriteEntry.category = "faith"
        favoriteEntry.isFavorite = true
        try await repository.create(favoriteEntry)
        
        let regularEntry = AffirmationEntry(context: testContext)
        regularEntry.text = "Regular affirmation"
        regularEntry.category = "faith"
        regularEntry.isFavorite = false
        try await repository.create(regularEntry)
        
        // When
        let favorites = try await repository.fetchFavorites()
        
        // Then
        XCTAssertEqual(favorites.count, 1)
        XCTAssertEqual(favorites.first?.text, "Favorite affirmation")
        XCTAssertTrue(favorites.first?.isFavorite ?? false)
    }
    
    // MARK: - Search Tests
    func testSearchAffirmationEntries() async throws {
        // Given
        let entry1 = AffirmationEntry(context: testContext)
        entry1.text = "I am blessed with faith"
        entry1.category = "faith"
        try await repository.create(entry1)
        
        let entry2 = AffirmationEntry(context: testContext)
        entry2.text = "I am filled with love"
        entry2.category = "love"
        try await repository.create(entry2)
        
        // When
        let searchResults = try await repository.search(text: "blessed")
        
        // Then
        XCTAssertEqual(searchResults.count, 1)
        XCTAssertEqual(searchResults.first?.text, "I am blessed with faith")
    }
    
    // MARK: - Observer Tests
    func testObserveAllAffirmationEntries() async throws {
        // Given
        let expectation = XCTestExpectation(description: "Observe affirmation entries")
        var observedEntries: [AffirmationEntry] = []
        
        repository.observeAll()
            .sink { entries in
                observedEntries = entries
                if entries.count > 0 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When
        let affirmationEntry = AffirmationEntry(context: testContext)
        affirmationEntry.text = "Observed affirmation"
        affirmationEntry.category = "faith"
        try await repository.create(affirmationEntry)
        
        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(observedEntries.count, 1)
        XCTAssertEqual(observedEntries.first?.text, "Observed affirmation")
    }
}