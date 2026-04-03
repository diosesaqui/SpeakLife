//
//  AudioFavoriteRepositoryTests.swift
//  SpeakLifeTests
//
//  Unit tests for AudioFavoriteRepository
//

import XCTest
import CoreData
import Combine
@testable import SpeakLife

final class AudioFavoriteRepositoryTests: XCTestCase {
    
    var repository: AudioFavoriteRepository!
    var persistenceController: PersistenceController!
    var context: NSManagedObjectContext!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        persistenceController = PersistenceController(inMemory: true)
        context = persistenceController.container.viewContext
        repository = AudioFavoriteRepository(context: context)
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
    
    func testCreateAudioFavorite() async throws {
        // Given
        let entry = AudioFavoriteEntry(context: context)
        entry.audioId = "test-audio-1"
        entry.title = "Test Audio"
        entry.subtitle = "Test Subtitle"
        entry.duration = "10:30"
        entry.imageUrl = "https://example.com/image.jpg"
        entry.isPremium = false
        entry.tag = "faith"
        
        // When
        try await repository.create(entry)
        
        // Then
        XCTAssertNotNil(entry.id)
        XCTAssertNotNil(entry.createdAt)
        XCTAssertNotNil(entry.lastModified)
        
        let fetched = try await repository.findByAudioId("test-audio-1")
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.title, "Test Audio")
    }
    
    func testCreateFromAudioDeclaration() async throws {
        // Given
        let audio = AudioDeclaration(
            id: "audio-123",
            title: "Declaration Title",
            subtitle: "Subtitle",
            duration: "5:45",
            imageUrl: "https://example.com/img.jpg",
            isPremium: true,
            tag: "prayer",
            season: 2,
            episode: 5
        )
        
        // When
        let entry = try await repository.createFromAudioDeclaration(audio)
        
        // Then
        XCTAssertEqual(entry.audioId, "audio-123")
        XCTAssertEqual(entry.title, "Declaration Title")
        XCTAssertEqual(entry.subtitle, "Subtitle")
        XCTAssertEqual(entry.isPremium, true)
        XCTAssertEqual(entry.season, 2)
        XCTAssertEqual(entry.episode, 5)
    }
    
    // MARK: - Update Tests
    
    func testUpdateAudioFavorite() async throws {
        // Given
        let entry = AudioFavoriteEntry(context: context)
        entry.audioId = "update-test"
        entry.title = "Original Title"
        try await repository.create(entry)
        
        let originalModified = entry.lastModified
        
        // When
        entry.title = "Updated Title"
        try await repository.update(entry)
        
        // Then
        XCTAssertEqual(entry.title, "Updated Title")
        XCTAssertNotEqual(entry.lastModified, originalModified)
    }
    
    // MARK: - Delete Tests
    
    func testDeleteAudioFavorite() async throws {
        // Given
        let entry = AudioFavoriteEntry(context: context)
        entry.audioId = "delete-test"
        entry.title = "To Delete"
        try await repository.create(entry)
        
        // Verify it exists
        var fetched = try await repository.findByAudioId("delete-test")
        XCTAssertNotNil(fetched)
        
        // When
        try await repository.delete(entry)
        
        // Then
        fetched = try await repository.findByAudioId("delete-test")
        XCTAssertNil(fetched)
    }
    
    func testDeleteByAudioId() async throws {
        // Given
        let entry = AudioFavoriteEntry(context: context)
        entry.audioId = "delete-by-id-test"
        entry.title = "Delete By ID"
        try await repository.create(entry)
        
        // When
        try await repository.deleteByAudioId("delete-by-id-test")
        
        // Then
        let fetched = try await repository.findByAudioId("delete-by-id-test")
        XCTAssertNil(fetched)
    }
    
    func testDeleteByAudioIdNonExistent() async throws {
        // When & Then - Should not throw
        try await repository.deleteByAudioId("non-existent-id")
    }
    
    // MARK: - Fetch Tests
    
    func testFetchAll() async throws {
        // Given
        for i in 1...3 {
            let entry = AudioFavoriteEntry(context: context)
            entry.audioId = "fetch-\(i)"
            entry.title = "Title \(i)"
            try await repository.create(entry)
        }
        
        // When
        let results = try await repository.fetch(predicate: nil)
        
        // Then
        XCTAssertEqual(results.count, 3)
    }
    
    func testFetchWithPredicate() async throws {
        // Given
        let entry1 = AudioFavoriteEntry(context: context)
        entry1.audioId = "audio-1"
        entry1.tag = "faith"
        try await repository.create(entry1)
        
        let entry2 = AudioFavoriteEntry(context: context)
        entry2.audioId = "audio-2"
        entry2.tag = "prayer"
        try await repository.create(entry2)
        
        // When
        let predicate = NSPredicate(format: "tag == %@", "faith")
        let results = try await repository.fetch(predicate: predicate)
        
        // Then
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.tag, "faith")
    }
    
    func testFetchById() async throws {
        // Given
        let entry = AudioFavoriteEntry(context: context)
        let id = UUID()
        entry.id = id
        entry.audioId = "fetch-by-id"
        try await repository.create(entry)
        
        // When
        let fetched = try await repository.fetchById(id)
        
        // Then
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.audioId, "fetch-by-id")
    }
    
    func testFindByAudioId() async throws {
        // Given
        let entry = AudioFavoriteEntry(context: context)
        entry.audioId = "unique-audio-id"
        entry.title = "Unique Title"
        try await repository.create(entry)
        
        // When
        let found = try await repository.findByAudioId("unique-audio-id")
        
        // Then
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.title, "Unique Title")
    }
    
    func testFetchByTag() async throws {
        // Given
        for tag in ["faith", "prayer", "faith", "worship"] {
            let entry = AudioFavoriteEntry(context: context)
            entry.audioId = UUID().uuidString
            entry.tag = tag
            try await repository.create(entry)
        }
        
        // When
        let faithResults = try await repository.fetchByTag("faith")
        
        // Then
        XCTAssertEqual(faithResults.count, 2)
        XCTAssertTrue(faithResults.allSatisfy { $0.tag == "faith" })
    }
    
    func testFetchWithLimit() async throws {
        // Given
        for i in 1...10 {
            let entry = AudioFavoriteEntry(context: context)
            entry.audioId = "limit-\(i)"
            entry.title = "Title \(i)"
            try await repository.create(entry)
        }
        
        // When
        let results = try await repository.fetchWithLimit(predicate: nil, limit: 5)
        
        // Then
        XCTAssertEqual(results.count, 5)
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
        let entry = AudioFavoriteEntry(context: context)
        entry.audioId = "observe-test"
        try await repository.create(entry)
        
        // Then
        await fulfillment(of: [expectation], timeout: 2.0)
        XCTAssertGreaterThanOrEqual(receivedUpdates, 2)
    }
    
    // MARK: - Conversion Tests
    
    func testToAudioDeclaration() async throws {
        // Given
        let entry = AudioFavoriteEntry(context: context)
        entry.id = UUID()
        entry.audioId = "convert-test"
        entry.title = "Convert Title"
        entry.subtitle = "Convert Subtitle"
        entry.duration = "3:21"
        entry.imageUrl = "https://example.com/convert.jpg"
        entry.isPremium = true
        entry.tag = "faith"
        entry.season = 1
        entry.episode = 10
        entry.createdAt = Date()
        
        // When
        let audioDeclaration = repository.toAudioDeclaration(entry)
        
        // Then
        XCTAssertEqual(audioDeclaration.id, "convert-test")
        XCTAssertEqual(audioDeclaration.title, "Convert Title")
        XCTAssertEqual(audioDeclaration.subtitle, "Convert Subtitle")
        XCTAssertEqual(audioDeclaration.duration, "3:21")
        XCTAssertEqual(audioDeclaration.isPremium, true)
        XCTAssertEqual(audioDeclaration.season, 1)
        XCTAssertEqual(audioDeclaration.episode, 10)
        XCTAssertTrue(audioDeclaration.isFavorite)
        XCTAssertNotNil(audioDeclaration.favoriteId)
        XCTAssertNotNil(audioDeclaration.dateFavorited)
    }
    
    // MARK: - Edge Cases
    
    func testHandleNilOptionalFields() async throws {
        // Given
        let entry = AudioFavoriteEntry(context: context)
        entry.audioId = "nil-fields-test"
        entry.title = "Title Only"
        // Leave optional fields nil
        
        // When
        try await repository.create(entry)
        let audioDeclaration = repository.toAudioDeclaration(entry)
        
        // Then
        XCTAssertNil(audioDeclaration.season)
        XCTAssertNil(audioDeclaration.episode)
    }
    
    func testUniqueConstraintOnAudioId() async throws {
        // Given
        let entry1 = AudioFavoriteEntry(context: context)
        entry1.audioId = "duplicate-id"
        entry1.title = "First"
        try await repository.create(entry1)
        
        // When - Create another with same audioId
        let entry2 = AudioFavoriteEntry(context: context)
        entry2.audioId = "duplicate-id"
        entry2.title = "Second"
        
        // Then - Should handle constraint violation
        // Note: Core Data unique constraints may merge or reject depending on configuration
        do {
            try await repository.create(entry2)
            // If it succeeds, verify only one exists
            let results = try await repository.fetch(predicate: NSPredicate(format: "audioId == %@", "duplicate-id"))
            XCTAssertLessThanOrEqual(results.count, 1)
        } catch {
            // Constraint violation is acceptable
            XCTAssertNotNil(error)
        }
    }
    
    // MARK: - Performance Tests
    
    func testBatchFetchPerformance() async throws {
        // Given - Create many entries
        for i in 1...100 {
            let entry = AudioFavoriteEntry(context: context)
            entry.audioId = "perf-\(i)"
            entry.title = "Performance Test \(i)"
            try await repository.create(entry)
        }
        
        // When & Then
        measure {
            Task {
                let results = try? await repository.fetch(predicate: nil)
                XCTAssertEqual(results?.count, 100)
            }
        }
    }
}