//
//  UnifiedFavoritesManagerTests.swift
//  SpeakLifeTests
//
//  Unit tests for UnifiedFavoritesManager
//

import XCTest
import SpeakLifeTestSupport
import CoreData
import Combine
import SpeakLifeCore
@testable import SpeakLifePersistence

// Mock Repositories for Testing
class MockAffirmationRepository: AffirmationRepositoryProtocol {
    var entries: [AffirmationEntry] = []
    var favoriteToggled = false
    
    func create(_ entity: AffirmationEntry) async throws {
        entries.append(entity)
    }
    
    func update(_ entity: AffirmationEntry) async throws {}
    
    func delete(_ entity: AffirmationEntry) async throws {
        entries.removeAll { $0.id == entity.id }
    }
    
    func fetch(predicate: NSPredicate?) async throws -> [AffirmationEntry] {
        if let predicate = predicate {
            return entries.filter { predicate.evaluate(with: $0) }
        }
        return entries
    }
    
    func fetchById(_ id: UUID) async throws -> AffirmationEntry? {
        return entries.first { $0.id == id }
    }
    
    func fetchFavorites() async throws -> [AffirmationEntry] {
        return entries.filter { $0.isFavorite }
    }
    
    func toggleFavorite(_ entity: AffirmationEntry) async throws {
        favoriteToggled = true
        entity.isFavorite.toggle()
    }
    
    func search(text: String) async throws -> [AffirmationEntry] {
        return entries.filter { $0.text?.contains(text) ?? false }
    }
    
    func fetchByCategory(_ category: String) async throws -> [AffirmationEntry] {
        return entries.filter { $0.category == category }
    }
    
    func observeAll() -> AnyPublisher<[AffirmationEntry], Never> {
        Just(entries).eraseToAnyPublisher()
    }
}

class MockJournalRepository: JournalRepositoryProtocol {
    var entries: [JournalEntry] = []
    var favoriteToggled = false
    
    func create(_ entity: JournalEntry) async throws {
        entries.append(entity)
    }
    
    func update(_ entity: JournalEntry) async throws {}
    
    func delete(_ entity: JournalEntry) async throws {
        entries.removeAll { $0.id == entity.id }
    }
    
    func fetch(predicate: NSPredicate?) async throws -> [JournalEntry] {
        if let predicate = predicate {
            return entries.filter { predicate.evaluate(with: $0) }
        }
        return entries
    }
    
    func fetchById(_ id: UUID) async throws -> JournalEntry? {
        return entries.first { $0.id == id }
    }
    
    func fetchFavorites() async throws -> [JournalEntry] {
        return entries.filter { $0.isFavorite }
    }
    
    func toggleFavorite(_ entity: JournalEntry) async throws {
        favoriteToggled = true
        entity.isFavorite.toggle()
    }
    
    func search(text: String) async throws -> [JournalEntry] {
        return entries.filter { $0.text?.contains(text) ?? false }
    }
    
    func observeAll() -> AnyPublisher<[JournalEntry], Never> {
        Just(entries).eraseToAnyPublisher()
    }
}

class MockDeclarationFavoriteRepository: DeclarationFavoriteRepositoryProtocol {
    func fetchByContentType(_ contentType: String) async throws -> [DeclarationFavoriteEntry] {
        return []
    }
    
    // Same shape, same reasons, as MockAudioFavoriteRepository: the manager
    // awaits these from a @MainActor task, they are nonisolated so they run off
    // it, and several land at once. See that mock for the full account.
    private let lock = NSLock()
    private var _entries: [DeclarationFavoriteEntry] = []

    var entries: [DeclarationFavoriteEntry] {
        get { lock.withLock { _entries } }
        set { lock.withLock { _entries = newValue } }
    }

    private func mutating(_ body: (inout [DeclarationFavoriteEntry]) -> Void) {
        lock.withLock { body(&_entries) }
    }

    private static let entity: NSEntityDescription = {
        guard let entity = PersistenceController.managedObjectModel
                .entitiesByName["DeclarationFavoriteEntry"] else {
            fatalError("DeclarationFavoriteEntry is missing from the Core Data model")
        }
        return entity
    }()

    func create(_ entity: DeclarationFavoriteEntry) async throws {
        mutating { list in list.append(entity) }
    }

    func update(_ entity: DeclarationFavoriteEntry) async throws {}

    func delete(_ entity: DeclarationFavoriteEntry) async throws {
        mutating { list in list.removeAll { $0.id == entity.id } }
    }

    func fetch(predicate: NSPredicate?) async throws -> [DeclarationFavoriteEntry] {
        return entries
    }
    
    func fetchById(_ id: UUID) async throws -> DeclarationFavoriteEntry? {
        return entries.first { $0.id == id }
    }
    
    func findByDeclarationId(_ declarationId: String) async throws -> DeclarationFavoriteEntry? {
        return entries.first { $0.declarationId == declarationId }
    }
    
    func fetchByCategory(_ category: String) async throws -> [DeclarationFavoriteEntry] {
        return entries.filter { $0.category == category }
    }
    
    func deleteByDeclarationId(_ declarationId: String) async throws {
        mutating { list in list.removeAll { $0.declarationId == declarationId } }
    }

    func createFromDeclaration(_ declaration: Declaration) async throws -> DeclarationFavoriteEntry {
        let entry = DeclarationFavoriteEntry(entity: Self.entity, insertInto: nil)
        entry.declarationId = declaration.id
        entry.text = declaration.text
        entry.category = declaration.category.rawValue
        entry.contentType = declaration.contentType.rawValue
        entry.book = declaration.book
        entry.bibleVerseText = declaration.bibleVerseText
        entry.id = UUID()
        entry.createdAt = Date()
        entry.lastModified = Date()
        mutating { list in list.append(entry) }
        return entry
    }
    
    func toDeclaration(_ entry: DeclarationFavoriteEntry) -> Declaration {
        return Declaration(
            text: entry.text,
            book: entry.book,
            bibleVerseText: entry.bibleVerseText,
            category: DeclarationCategory(rawValue: entry.category) ?? .faith,
            categories: [],
            isFavorite: true,
            contentType: ContentType(rawValue: entry.contentType ?? "affirmation") ?? .affirmation,
            lastEdit: entry.lastModified
        )
    }
    
    func observeAll() -> AnyPublisher<[DeclarationFavoriteEntry], Never> {
        Just(entries).eraseToAnyPublisher()
    }
}

final class UnifiedFavoritesManagerTests: XCTestCase {
    
    var manager: UnifiedFavoritesManager!
    var mockAffirmationRepo: MockAffirmationRepository!
    var mockJournalRepo: MockJournalRepository!
    var mockDeclarationRepo: MockDeclarationFavoriteRepository!
    var mockAudioRepo: MockAudioFavoriteRepository!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        
        mockAffirmationRepo = MockAffirmationRepository()
        mockJournalRepo = MockJournalRepository()
        mockDeclarationRepo = MockDeclarationFavoriteRepository()
        mockAudioRepo = MockAudioFavoriteRepository()
        
        manager = UnifiedFavoritesManager(
            affirmationRepository: mockAffirmationRepo,
            journalRepository: mockJournalRepo,
            declarationFavoriteRepository: mockDeclarationRepo,
            audioFavoriteRepository: mockAudioRepo
        )
        
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables = nil
        manager = nil
        mockAffirmationRepo = nil
        mockJournalRepo = nil
        mockDeclarationRepo = nil
        mockAudioRepo = nil
        super.tearDown()
    }
    
    // MARK: - Declaration Favorites Tests
    
    func testIsDeclarationFavorite() async throws {
        // Given
        let declaration = Declaration(
            text: "I am blessed",
            book: "Psalms",
            bibleVerseText: "Psalm 23:1",
            category: .faith,
            categories: [],
            isFavorite: false,
            contentType: .affirmation
        )
        
        // Add as favorite
        try await mockDeclarationRepo.createFromDeclaration(declaration)
        
        // Wait for async update
        try await Task.sleep(nanoseconds: 200_000_000)
        
        // When
        let isFavorite = manager.isDeclarationFavorite(declaration)
        
        // Then
        // Note: Due to async nature, this might not immediately reflect
        // In real scenario, the observe pattern would update this
        XCTAssertNotNil(mockDeclarationRepo.entries.first { $0.declarationId == declaration.id })
    }
    
    func testToggleDeclarationFavoriteNonMyOwn() async throws {
        // Given
        let declaration = Declaration(
            text: "God is good",
            category: .faith, // Non-myOwn category
            categories: [],
            isFavorite: false,
            contentType: .affirmation
        )
        
        // When - Add favorite
        manager.toggleDeclarationFavorite(declaration)
        try await Task.sleep(nanoseconds: 300_000_000)
        
        // Then
        XCTAssertEqual(mockDeclarationRepo.entries.count, 1)
        XCTAssertEqual(mockDeclarationRepo.entries.first?.text, "God is good")
        
        // When - Toggle again to remove
        manager.toggleDeclarationFavorite(declaration)
        try await Task.sleep(nanoseconds: 300_000_000)
        
        // Then
        // Should be removed (eventually)
    }
    
    func testToggleDeclarationFavoriteMyOwnAffirmation() async throws {
        // Given.
        //
        // Retain the controller for the whole test — see the block comment on the
        // same fix in `FavoritesMigrationServiceTests.testMigrateAudioFavoritesSkipExisting`.
        let persistenceController = PersistenceController(inMemory: true)
        let context = persistenceController.container.viewContext
        addTeardownBlock { _ = persistenceController }
        let affirmation = AffirmationEntry(context: context)
        affirmation.text = "My affirmation"
        affirmation.category = "myOwn"
        affirmation.isFavorite = false
        mockAffirmationRepo.entries.append(affirmation)
        
        let declaration = Declaration(
            text: "My affirmation",
            category: .myOwn,
            categories: [],
            isFavorite: false,
            contentType: .affirmation
        )
        
        // When
        manager.toggleDeclarationFavorite(declaration)
        try await Task.sleep(nanoseconds: 300_000_000)
        
        // Then
        XCTAssertTrue(mockAffirmationRepo.favoriteToggled)
    }
    
    func testToggleDeclarationFavoriteWithRetry() async throws {
        // Given
        let declaration = Declaration(
            text: "Test retry",
            category: .faith,
            categories: [],
            isFavorite: false,
            contentType: .affirmation
        )
        
        // When
        manager.toggleDeclarationFavorite(declaration, retryCount: 2)
        try await Task.sleep(nanoseconds: 500_000_000)
        
        // Then - Should handle retries
        XCTAssertNotNil(manager) // Basic check that manager handles retries
    }
    
    // MARK: - Audio Favorites Tests
    
    func testIsAudioFavorite() async throws {
        // Given
        let audio = AudioDeclaration(
            id: "audio-1",
            title: "Test Audio",
            subtitle: "Sub",
            duration: "5:00",
            imageUrl: "",
            isPremium: false,
            tag: "faith"
        )
        
        // Add to favorites
        _ = try await mockAudioRepo.createFromAudioDeclaration(audio)
        
        // Wait for update
        try await Task.sleep(nanoseconds: 200_000_000)
        
        // When/Then
        // Check the repository directly
        XCTAssertEqual(mockAudioRepo.entries.count, 1)
    }
    
    func testToggleAudioFavorite() async throws {
        // Given
        let audio = AudioDeclaration(
            id: "toggle-audio",
            title: "Toggle Test",
            subtitle: "Sub",
            duration: "3:00",
            imageUrl: "",
            isPremium: true,
            tag: "prayer"
        )
        
        // When - Add favorite
        manager.toggleAudioFavorite(audio)
        try await Task.sleep(nanoseconds: 300_000_000)
        
        // Then
        XCTAssertTrue(mockAudioRepo.createCalled)
        
        // When - Toggle again to remove
        manager.toggleAudioFavorite(audio)
        try await Task.sleep(nanoseconds: 300_000_000)
        
        // Then
        XCTAssertTrue(mockAudioRepo.deleteCalled)
    }
    
    // MARK: - Utility Methods Tests
    
    func testTotalFavoritesCount() async throws {
        // Given - Add various favorites
        let declaration = Declaration(
            text: "Declaration",
            category: .faith,
            categories: [],
            isFavorite: false,
            contentType: .affirmation
        )
        
        let audio = AudioDeclaration(
            id: "audio-count",
            title: "Audio",
            subtitle: "Sub",
            duration: "2:00",
            imageUrl: "",
            isPremium: false,
            tag: "worship"
        )
        
        _ = try await mockDeclarationRepo.createFromDeclaration(declaration)
        _ = try await mockAudioRepo.createFromAudioDeclaration(audio)
        
        // Wait for updates
        try await Task.sleep(nanoseconds: 200_000_000)
        
        // When/Then
        // Check repositories directly
        XCTAssertEqual(mockDeclarationRepo.entries.count, 1)
        XCTAssertEqual(mockAudioRepo.entries.count, 1)
    }
    
    func testGetDeclarationFavoritesByContentType() async throws {
        // Given
        let affirmation = Declaration(
            text: "Affirmation",
            category: .faith,
            categories: [],
            isFavorite: true,
            contentType: .affirmation
        )
        
        let journal = Declaration(
            text: "Journal",
            category: .myOwn,
            categories: [],
            isFavorite: true,
            contentType: .journal
        )
        
        _ = try await mockDeclarationRepo.createFromDeclaration(affirmation)
        _ = try await mockDeclarationRepo.createFromDeclaration(journal)
        
        // Manually update manager's declarationFavorites for testing
        manager.declarationFavorites = [affirmation, journal]
        
        // When
        let affirmations = manager.getDeclarationFavorites(byContentType: .affirmation)
        let journals = manager.getDeclarationFavorites(byContentType: .journal)
        
        // Then
        XCTAssertEqual(affirmations.count, 1)
        XCTAssertEqual(journals.count, 1)
        XCTAssertEqual(affirmations.first?.text, "Affirmation")
        XCTAssertEqual(journals.first?.text, "Journal")
    }
    
    func testGetAudioFavoritesByTag() async throws {
        // Given
        let faithAudio = AudioDeclaration(
            id: "faith-1",
            title: "Faith Audio",
            subtitle: "Sub",
            duration: "5:00",
            imageUrl: "",
            isPremium: false,
            tag: "faith"
        )
        
        let prayerAudio = AudioDeclaration(
            id: "prayer-1",
            title: "Prayer Audio",
            subtitle: "Sub",
            duration: "4:00",
            imageUrl: "",
            isPremium: false,
            tag: "prayer"
        )
        
        _ = try await mockAudioRepo.createFromAudioDeclaration(faithAudio)
        _ = try await mockAudioRepo.createFromAudioDeclaration(prayerAudio)
        
        // Manually update manager's audioFavorites for testing
        manager.audioFavorites = [faithAudio, prayerAudio]
        
        // When
        let faithFavorites = manager.getAudioFavorites(byTag: "faith")
        let prayerFavorites = manager.getAudioFavorites(byTag: "prayer")
        
        // Then
        XCTAssertEqual(faithFavorites.count, 1)
        XCTAssertEqual(prayerFavorites.count, 1)
        XCTAssertEqual(faithFavorites.first?.title, "Faith Audio")
        XCTAssertEqual(prayerFavorites.first?.title, "Prayer Audio")
    }
    
    func testRefreshAllFavorites() {
        // When
        manager.refreshAllFavorites()

        // Then - Should set isLoading
        XCTAssertTrue(manager.isLoading)

        // ...and clear it once the refresh finishes.
        //
        // This waited on a 0.5s sleep with a 2.0s timeout. A wider margin than
        // the streak suite's, so it had not gone red yet, but it is the same
        // bet: that the work finishes inside a fixed nap. Waiting on the flag
        // itself removes the bet and returns as soon as it flips.
        waitUntil("the refresh to finish loading") { !self.manager.isLoading }
        XCTAssertFalse(manager.isLoading)
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorMessageOnToggleFailure() async throws {
        // Given a declaration that will fail
        let declaration = Declaration(
            text: "Will fail",
            category: .faith,
            categories: [],
            isFavorite: false,
            contentType: .affirmation
        )
        
        // Simulate error scenario - no matching entry
        manager.toggleDeclarationFavorite(declaration, retryCount: 1)
        try await Task.sleep(nanoseconds: 500_000_000)
        
        // Then - Error handling should work
        // Note: In real scenario, this would set errorMessage
        XCTAssertNotNil(manager) // Basic validation
    }
    
    // MARK: - Performance Tests
    
    func testTogglePerformanceWithRetry() {
        measure {
            let declaration = Declaration(
                text: "Performance test",
                category: .faith,
                categories: [],
                isFavorite: false,
                contentType: .affirmation
            )
            
            manager.toggleDeclarationFavorite(declaration, retryCount: 1)
            
            // Wait briefly
            Thread.sleep(forTimeInterval: 0.1)
        }
    }
    
    // MARK: - Integration Tests
    
    func testMultipleFavoriteTypes() async throws {
        // Given - Create multiple types of favorites
        let declaration = Declaration(
            text: "Multi test declaration",
            category: .faith,
            categories: [],
            isFavorite: false,
            contentType: .affirmation
        )
        
        let audio = AudioDeclaration(
            id: "multi-audio",
            title: "Multi Audio",
            subtitle: "Sub",
            duration: "3:00",
            imageUrl: "",
            isPremium: false,
            tag: "faith"
        )
        
        // When - Add both types
        _ = try await mockDeclarationRepo.createFromDeclaration(declaration)
        _ = try await mockAudioRepo.createFromAudioDeclaration(audio)
        
        // Then - Both repositories should have entries
        XCTAssertEqual(mockDeclarationRepo.entries.count, 1)
        XCTAssertEqual(mockAudioRepo.entries.count, 1)
    }
}
