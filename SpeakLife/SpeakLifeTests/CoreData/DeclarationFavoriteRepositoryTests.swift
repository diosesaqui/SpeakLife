//
//  DeclarationFavoriteRepositoryTests.swift
//  SpeakLifeTests
//
//  Unit tests for DeclarationFavoriteRepository
//

import XCTest
import CoreData
import Combine
@testable import SpeakLife

final class DeclarationFavoriteRepositoryTests: XCTestCase {
    
    var repository: DeclarationFavoriteRepository!
    var persistenceController: PersistenceController!
    var context: NSManagedObjectContext!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        persistenceController = PersistenceController(inMemory: true)
        context = persistenceController.container.viewContext
        repository = DeclarationFavoriteRepository(context: context)
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables = nil
        repository = nil
        context = nil
        persistenceController = nil
        super.tearDown()
    }
    
    // MARK: - Create Tests
    
    func testCreateDeclarationFavorite() async throws {
        // Given
        let entry = DeclarationFavoriteEntry(context: context)
        entry.declarationId = "decl-1"
        entry.text = "I am blessed"
        entry.category = "faith"
        entry.contentType = "affirmation"
        entry.book = "Psalms"
        entry.bibleVerseText = "Psalm 23:1"
        
        // When
        try await repository.create(entry)
        
        // Then
        XCTAssertNotNil(entry.id)
        XCTAssertNotNil(entry.createdAt)
        XCTAssertNotNil(entry.lastModified)
        
        let fetched = try await repository.findByDeclarationId("decl-1")
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.text, "I am blessed")
    }
    
    func testCreateFromDeclaration() async throws {
        // Given
        let declaration = Declaration(
            text: "God is faithful",
            book: "Hebrews",
            bibleVerseText: "Hebrews 10:23",
            category: .faith,
            categories: [],
            isFavorite: true,
            contentType: .affirmation,
            lastEdit: Date()
        )
        
        // When
        let entry = try await repository.createFromDeclaration(declaration)
        
        // Then
        XCTAssertEqual(entry.declarationId, declaration.id)
        XCTAssertEqual(entry.text, "God is faithful")
        XCTAssertEqual(entry.category, "faith")
        XCTAssertEqual(entry.book, "Hebrews")
        XCTAssertEqual(entry.bibleVerseText, "Hebrews 10:23")
        XCTAssertEqual(entry.contentType, "affirmation")
    }
    
    // MARK: - Update Tests
    
    func testUpdateDeclarationFavorite() async throws {
        // Given
        let entry = DeclarationFavoriteEntry(context: context)
        entry.declarationId = "update-test"
        entry.text = "Original text"
        entry.category = "faith"
        try await repository.create(entry)
        
        let originalModified = entry.lastModified
        
        // When
        entry.text = "Updated text"
        try await repository.update(entry)
        
        // Then
        XCTAssertEqual(entry.text, "Updated text")
        XCTAssertNotEqual(entry.lastModified, originalModified)
    }
    
    // MARK: - Delete Tests
    
    func testDeleteDeclarationFavorite() async throws {
        // Given
        let entry = DeclarationFavoriteEntry(context: context)
        entry.declarationId = "delete-test"
        entry.text = "To delete"
        try await repository.create(entry)
        
        // Verify it exists
        var fetched = try await repository.findByDeclarationId("delete-test")
        XCTAssertNotNil(fetched)
        
        // When
        try await repository.delete(entry)
        
        // Then
        fetched = try await repository.findByDeclarationId("delete-test")
        XCTAssertNil(fetched)
    }
    
    func testDeleteByDeclarationId() async throws {
        // Given
        let entry = DeclarationFavoriteEntry(context: context)
        entry.declarationId = "delete-by-id"
        entry.text = "Delete by ID"
        try await repository.create(entry)
        
        // When
        try await repository.deleteByDeclarationId("delete-by-id")
        
        // Then
        let fetched = try await repository.findByDeclarationId("delete-by-id")
        XCTAssertNil(fetched)
    }
    
    // MARK: - Fetch Tests
    
    func testFetchAll() async throws {
        // Given
        for i in 1...5 {
            let entry = DeclarationFavoriteEntry(context: context)
            entry.declarationId = "fetch-\(i)"
            entry.text = "Declaration \(i)"
            entry.category = i % 2 == 0 ? "faith" : "prayer"
            try await repository.create(entry)
        }
        
        // When
        let results = try await repository.fetch(predicate: nil)
        
        // Then
        XCTAssertEqual(results.count, 5)
    }
    
    func testFetchWithPredicate() async throws {
        // Given
        for i in 1...4 {
            let entry = DeclarationFavoriteEntry(context: context)
            entry.declarationId = "pred-\(i)"
            entry.category = i <= 2 ? "faith" : "prayer"
            entry.text = "Text \(i)"
            try await repository.create(entry)
        }
        
        // When
        let predicate = NSPredicate(format: "category == %@", "faith")
        let results = try await repository.fetch(predicate: predicate)
        
        // Then
        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results.allSatisfy { $0.category == "faith" })
    }
    
    func testFetchByCategory() async throws {
        // Given
        let categories = ["faith", "prayer", "faith", "worship", "faith"]
        for (i, category) in categories.enumerated() {
            let entry = DeclarationFavoriteEntry(context: context)
            entry.declarationId = "cat-\(i)"
            entry.category = category
            entry.text = "Category \(category)"
            try await repository.create(entry)
        }
        
        // When
        let faithResults = try await repository.fetchByCategory("faith")
        
        // Then
        XCTAssertEqual(faithResults.count, 3)
        XCTAssertTrue(faithResults.allSatisfy { $0.category == "faith" })
    }
    
    func testFindByDeclarationId() async throws {
        // Given
        let entry = DeclarationFavoriteEntry(context: context)
        entry.declarationId = "unique-id-123"
        entry.text = "Unique declaration"
        entry.category = "faith"
        try await repository.create(entry)
        
        // When
        let found = try await repository.findByDeclarationId("unique-id-123")
        
        // Then
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.text, "Unique declaration")
    }
    
    // MARK: - Observe Tests
    
    func testObserveAll() async throws {
        // Given
        let expectation = XCTestExpectation(description: "Observe changes")
        var receivedUpdates = 0
        
        repository.observeAll()
            .sink { entries in
                receivedUpdates += 1
                if receivedUpdates == 2 { // Initial + after create
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When
        let entry = DeclarationFavoriteEntry(context: context)
        entry.declarationId = "observe-test"
        entry.text = "Observe this"
        try await repository.create(entry)
        
        // Then
        await fulfillment(of: [expectation], timeout: 2.0)
        XCTAssertGreaterThanOrEqual(receivedUpdates, 2)
    }
    
    // MARK: - Conversion Tests
    
    func testToDeclaration() {
        // Given
        let entry = DeclarationFavoriteEntry(context: context)
        entry.id = UUID()
        entry.declarationId = "convert-test"
        entry.text = "I am loved by God"
        entry.category = "identity"
        entry.contentType = "affirmation"
        entry.book = "Romans"
        entry.bibleVerseText = "Romans 8:38-39"
        entry.createdAt = Date()
        entry.lastModified = Date()
        
        // When
        let declaration = repository.toDeclaration(entry)
        
        // Then
        XCTAssertEqual(declaration.id, "convert-test")
        XCTAssertEqual(declaration.text, "I am loved by God")
        XCTAssertEqual(declaration.category, .identity)
        XCTAssertEqual(declaration.contentType, .affirmation)
        XCTAssertEqual(declaration.book, "Romans")
        XCTAssertEqual(declaration.bibleVerseText, "Romans 8:38-39")
       // XCTAssertTrue(declaration.isFavorite)
    }
    
    func testToDeclarationWithUnknownCategory() {
        // Given
        let entry = DeclarationFavoriteEntry(context: context)
        entry.declarationId = "unknown-cat"
        entry.text = "Test text"
        entry.category = "unknown_category_xyz"
        entry.contentType = "journal"
        
        // When
        let declaration = repository.toDeclaration(entry)
        
        // Then
        XCTAssertEqual(declaration.category, .myOwn) // Should default to myOwn
        XCTAssertEqual(declaration.contentType, .journal)
    }
    
    func testToDeclarationWithUnknownContentType() {
        // Given
        let entry = DeclarationFavoriteEntry(context: context)
        entry.declarationId = "unknown-type"
        entry.text = "Test text"
        entry.category = "faith"
        entry.contentType = "unknown_type"
        
        // When
        let declaration = repository.toDeclaration(entry)
        
        // Then
        XCTAssertEqual(declaration.contentType, .affirmation) // Should default to affirmation
    }
    
    // MARK: - Edge Cases
    
    func testHandleNilOptionalFields() async throws {
        // Given
        let entry = DeclarationFavoriteEntry(context: context)
        entry.declarationId = "nil-fields"
        entry.text = "Basic text"
        entry.category = "faith"
        // Leave book and bibleVerseText nil
        
        // When
        try await repository.create(entry)
        let declaration = repository.toDeclaration(entry)
        
        // Then
        XCTAssertNil(declaration.book)
        XCTAssertNil(declaration.bibleVerseText)
    }
    
    /// Where the one-row-per-declaration guarantee actually lives.
    ///
    /// This used to call `create` twice and expect Core Data to collapse the
    /// rows. `DeclarationFavoriteEntry` has no uniqueness constraint and cannot
    /// have one: a store carrying a constraint will not load under CloudKit
    /// mirroring, which this model uses throughout. `create` is the raw write
    /// and duplicates by design.
    ///
    /// `createFromDeclaration` is the path the app takes, and it is where the
    /// dedup is.
    func testFavoritingTheSameDeclarationTwiceReturnsTheSameRow() async throws {
        let declaration = Declaration(
            text: "I am rooted and unshakeable in Christ.",
            book: "Colossians 2:7",
            category: .faith
        )

        let first = try await repository.createFromDeclaration(declaration)
        let second = try await repository.createFromDeclaration(declaration)

        XCTAssertEqual(first.objectID, second.objectID, "a second row was created")

        let results = try await repository.fetch(
            predicate: NSPredicate(format: "declarationId == %@", declaration.id)
        )
        XCTAssertEqual(results.count, 1)
    }
    
    // MARK: - Batch Operations

    /// Both of these were `measure { Task { … } }`, which measures the cost of
    /// spawning a task and nothing else: the block returns before the first
    /// `await` resumes. The ten detached tasks `measure` left behind then woke
    /// after `tearDown` had nil'd the properties they captured. Awaiting the
    /// work is what the tests were actually for.
    func testBatchWritesAllLand() async throws {
        for i in 1...50 {
            let entry = DeclarationFavoriteEntry(context: context)
            entry.declarationId = "batch-\(i)"
            entry.text = "Batch \(i)"
            entry.category = i % 3 == 0 ? "faith" : i % 3 == 1 ? "prayer" : "worship"
            try await repository.create(entry)
        }

        let results = try await repository.fetch(predicate: nil)
        XCTAssertEqual(results.count, 50)
    }

    func testFetchByCategoryNarrowsToThatCategory() async throws {
        for i in 1...100 {
            let entry = DeclarationFavoriteEntry(context: context)
            entry.declarationId = "cat-\(i)"
            entry.text = "Text \(i)"
            entry.category = i % 5 == 0 ? "faith" : "other"
            try await repository.create(entry)
        }

        let results = try await repository.fetchByCategory("faith")
        XCTAssertEqual(results.count, 20) // every fifth of 100
        XCTAssertTrue(results.allSatisfy { $0.category == "faith" })
    }
}
