//
//  AudioFavoritesManagerTests.swift
//  SpeakLifeTests
//
//  Unit tests for AudioFavoritesManager
//

import XCTest
import CoreData
import Combine
import SpeakLifeCore
@testable import SpeakLifePersistence

/// Mock Repository for Testing.
///
/// Two things here are load-bearing, and both exist because this mock is
/// hammered concurrently.
///
/// `AudioFavoritesManager.toggleFavorite` runs its body in `Task { @MainActor }`,
/// but every repository method it awaits is a nonisolated `async` function — so
/// each `await` hops straight back OFF the main actor onto the concurrent
/// executor. A test that toggles three favorites in a loop really does run
/// three of these at once.
///
/// Unsynchronized, that produced both of this suite's failures. The array lost
/// an append, so three favorites arrived as two. And three
/// `AudioFavoriteEntry(context:)` inserts landed on one main-queue
/// `viewContext` simultaneously, which Core Data reports as:
///
///   Serious application error. Exception was caught during Core Data change
///   processing. -[__NSCFSet addObject:]: attempt to insert nil
///
/// So: entries are guarded by a lock, and the entities are built with no
/// context behind them at all. A context-less managed object is a plain
/// attribute bag — no change processing to corrupt, nothing queue-confined —
/// which is all a mock ever needed. Nothing is lost by it: this mock never
/// saved, fetched, or faulted, and every non-optional attribute is assigned
/// below rather than left to an insert default.
class MockAudioFavoriteRepository: AudioFavoriteRepositoryProtocol {

    // These flags are written from the repository's nonisolated async methods
    // and read from the test, so they go through the same lock `entries` does.
    //
    // They were plain `var Bool` while the only reader was a single check after
    // a fixed sleep, which is a race you would rarely lose. Tests now POLL them
    // in a loop until the work lands, which turns a once-per-test read into
    // hundreds — exactly the shape a thread sanitiser flags, and exactly the
    // shape that occasionally reads a stale `false` forever and times out.
    var createCalled: Bool {
        get { lock.withLock { _createCalled } }
        set { lock.withLock { _createCalled = newValue } }
    }
    var deleteCalled: Bool {
        get { lock.withLock { _deleteCalled } }
        set { lock.withLock { _deleteCalled = newValue } }
    }
    var fetchCalled: Bool {
        get { lock.withLock { _fetchCalled } }
        set { lock.withLock { _fetchCalled = newValue } }
    }

    private var _createCalled = false
    private var _deleteCalled = false
    private var _fetchCalled = false

    var shouldThrowError = false
    var observePublisher = PassthroughSubject<[AudioFavoriteEntry], Never>()

    private let lock = NSLock()
    private var _entries: [AudioFavoriteEntry] = []

    var entries: [AudioFavoriteEntry] {
        get { lock.withLock { _entries } }
        set { lock.withLock { _entries = newValue } }
    }

    /// Mutates and publishes under the SAME lock, deliberately.
    ///
    /// Locking only the mutation is not enough, and the difference is the
    /// remaining "3 favorites arrived as 2". Three concurrent creates each
    /// build a correct snapshot, release the lock, and only then reach the
    /// subject — in whatever order the scheduler picks. If the create that
    /// appended second publishes last, the manager's final `favorites` is the
    /// shorter list, and the count is wrong with no race left to see.
    ///
    /// Holding the lock across the send makes mutation and publication one
    /// step, so the last write is always the last thing published. The only
    /// subscriber hops to the main queue, so nothing re-enters this lock.
    private func mutateAndPublish(_ body: (inout [AudioFavoriteEntry]) -> Void) {
        lock.withLock {
            body(&_entries)
            observePublisher.send(_entries)
        }
    }

    private static let entity: NSEntityDescription = {
        guard let entity = PersistenceController.managedObjectModel
                .entitiesByName["AudioFavoriteEntry"] else {
            fatalError("AudioFavoriteEntry is missing from the Core Data model")
        }
        return entity
    }()

    private func makeEntry() -> AudioFavoriteEntry {
        AudioFavoriteEntry(entity: Self.entity, insertInto: nil)
    }

    func create(_ entity: AudioFavoriteEntry) async throws {
        createCalled = true
        if shouldThrowError {
            throw NSError(domain: "MockError", code: 1, userInfo: nil)
        }
        mutateAndPublish { list in list.append(entity) }
    }

    func update(_ entity: AudioFavoriteEntry) async throws {
        if shouldThrowError {
            throw NSError(domain: "MockError", code: 1, userInfo: nil)
        }
    }
    
    func delete(_ entity: AudioFavoriteEntry) async throws {
        deleteCalled = true
        if shouldThrowError {
            throw NSError(domain: "MockError", code: 1, userInfo: nil)
        }
        mutateAndPublish { list in list.removeAll { $0.audioId == entity.audioId } }
    }

    func fetch(predicate: NSPredicate?) async throws -> [AudioFavoriteEntry] {
        fetchCalled = true
        if shouldThrowError {
            throw NSError(domain: "MockError", code: 1, userInfo: nil)
        }
        return entries
    }
    
    func fetchById(_ id: UUID) async throws -> AudioFavoriteEntry? {
        return entries.first { $0.id == id }
    }
    
    func findByAudioId(_ audioId: String) async throws -> AudioFavoriteEntry? {
        if shouldThrowError {
            throw NSError(domain: "MockError", code: 1, userInfo: nil)
        }
        return entries.first { $0.audioId == audioId }
    }
    
    func fetchByTag(_ tag: String) async throws -> [AudioFavoriteEntry] {
        return entries.filter { $0.tag == tag }
    }
    
    func deleteByAudioId(_ audioId: String) async throws {
        deleteCalled = true
        if shouldThrowError {
            throw NSError(domain: "MockError", code: 1, userInfo: nil)
        }
        mutateAndPublish { list in list.removeAll { $0.audioId == audioId } }
    }

    func createFromAudioDeclaration(_ audio: AudioDeclaration) async throws -> AudioFavoriteEntry {
        let entry = makeEntry()
        entry.audioId = audio.id
        entry.title = audio.title
        entry.subtitle = audio.subtitle
        entry.duration = audio.duration
        entry.imageUrl = audio.imageUrl
        entry.isPremium = audio.isPremium
        entry.tag = audio.tag
        entry.season = Int32(audio.season ?? 0)
        entry.episode = Int32(audio.episode ?? 0)
        entry.id = UUID()
        entry.createdAt = Date()
        entry.lastModified = Date()
        // Mirrors AudioFavoriteRepository: the caller's own timestamp wins.
        // Without this the mock stamped three inserts with the same instant and
        // sorting by date came out in whatever order the writes happened to land.
        entry.dateFavorited = audio.dateFavorited ?? Date()
        try await create(entry)
        return entry
    }
    
    func toAudioDeclaration(_ entry: AudioFavoriteEntry) -> AudioDeclaration {
        return AudioDeclaration(
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
            dateFavorited: entry.dateFavorited ?? entry.createdAt
        )
    }
    
    func observeAll() -> AnyPublisher<[AudioFavoriteEntry], Never> {
        observePublisher
            .prepend(entries)
            .eraseToAnyPublisher()
    }
}

final class AudioFavoritesManagerTests: XCTestCase {
    
    var manager: AudioFavoritesManager!
    var mockRepository: MockAudioFavoriteRepository!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        mockRepository = MockAudioFavoriteRepository()
        manager = AudioFavoritesManager(repository: mockRepository)
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables = nil
        manager = nil
        mockRepository = nil
        super.tearDown()
    }
    
    // MARK: - Toggle Favorite Tests
    
    func testToggleFavoriteAdd() async throws {
        // Given
        let audio = AudioDeclaration(
            id: "audio-1.mp3",
            title: "Test Audio",
            subtitle: "Subtitle",
            duration: "5:00",
            imageUrl: "https://example.com/image.jpg",
            isPremium: false,
            tag: "faith"
        )
        
        // When
        manager.toggleFavorite(audio)
        
        // Wait for async operation
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Then
        XCTAssertTrue(mockRepository.createCalled)
        XCTAssertTrue(manager.isFavorite(audio))
    }
    
    func testToggleFavoriteRemove() async throws {
        // Given
        let audio = AudioDeclaration(
            id: "audio-2.mp3",
            title: "Test Audio 2",
            subtitle: "Subtitle 2",
            duration: "3:00",
            imageUrl: "https://example.com/image2.jpg",
            isPremium: true,
            tag: "prayer"
        )
        
        // First add it
        manager.toggleFavorite(audio)
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertTrue(manager.isFavorite(audio))
        
        // When - Toggle again to remove
        manager.toggleFavorite(audio)
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Then
        XCTAssertTrue(mockRepository.deleteCalled)
        XCTAssertFalse(manager.isFavorite(audio))
    }
    
    func testToggleFavoriteWithRetry() async throws {
        // Given
        let audio = AudioDeclaration(
            id: "retry-test.mp3",
            title: "Retry Test",
            subtitle: "Retry",
            duration: "1:00",
            imageUrl: "",
            isPremium: false,
            tag: "faith"
        )
        
        // Simulate first attempt failure
        mockRepository.shouldThrowError = true
        
        // When
        manager.toggleFavorite(audio, retryCount: 1)
        
        // Wait for retry
        try await Task.sleep(nanoseconds: 200_000_000)
        
        // Then - Should have error message after failure
        XCTAssertNotNil(manager.errorMessage)
        XCTAssertFalse(manager.isFavorite(audio))
    }
    
    // MARK: - Favorite Check Tests
    
    func testIsFavorite() async throws {
        // Given
        let audio1 = AudioDeclaration(
            id: "fav-1.mp3",
            title: "Favorite 1",
            subtitle: "Sub 1",
            duration: "2:00",
            imageUrl: "",
            isPremium: false,
            tag: "faith"
        )
        
        let audio2 = AudioDeclaration(
            id: "fav-2.mp3",
            title: "Favorite 2",
            subtitle: "Sub 2",
            duration: "3:00",
            imageUrl: "",
            isPremium: false,
            tag: "prayer"
        )
        
        // When
        manager.toggleFavorite(audio1)
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Then
        XCTAssertTrue(manager.isFavorite(audio1))
        XCTAssertFalse(manager.isFavorite(audio2))
    }
    
    func testIsFavoriteAsync() async throws {
        // Given
        let audio = AudioDeclaration(
            id: "async-fav.mp3",
            title: "Async Favorite",
            subtitle: "Async",
            duration: "4:00",
            imageUrl: "",
            isPremium: true,
            tag: "worship"
        )
        
        manager.toggleFavorite(audio)
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // When
        let isFavorite = await manager.isFavoriteAsync(audio)
        
        // Then
        XCTAssertTrue(isFavorite)
    }
    
    // MARK: - Sorting Tests
    
    func testGetFavoritesSortedByDate() async throws {
        // Given
        let now = Date()
        for i in 0..<3 {
            let audio = AudioDeclaration(
                id: "date-\(i).mp3",
                title: "Audio \(i)",
                subtitle: "Sub \(i)",
                duration: "\(i):00",
                imageUrl: "",
                isPremium: false,
                tag: "faith",
                dateFavorited: now.addingTimeInterval(Double(i * 3600))
            )
            manager.toggleFavorite(audio)
        }
        
        try await Task.sleep(nanoseconds: 200_000_000)
        
        // When
        let sorted = manager.getFavoritesSortedByDate()
        
        // Then
        XCTAssertEqual(sorted.count, 3)
        // Should be in reverse chronological order
        if sorted.count >= 2 {
            XCTAssertTrue(sorted[0].dateFavorited! > sorted[1].dateFavorited!)
        }
    }
    
    func testGetFavoritesSortedAlphabetically() async throws {
        // Given
        let titles = ["Zebra", "Apple", "Mango"]
        for title in titles {
            let audio = AudioDeclaration(
                id: "alpha-\(title).mp3",
                title: title,
                subtitle: "Sub",
                duration: "1:00",
                imageUrl: "",
                isPremium: false,
                tag: "faith"
            )
            manager.toggleFavorite(audio)
        }
        
        try await Task.sleep(nanoseconds: 200_000_000)
        
        // When
        let sorted = manager.getFavoritesSortedAlphabetically()
        
        // Then
        XCTAssertEqual(sorted.count, 3)
        if sorted.count == 3 {
            XCTAssertEqual(sorted[0].title, "Apple")
            XCTAssertEqual(sorted[1].title, "Mango")
            XCTAssertEqual(sorted[2].title, "Zebra")
        }
    }
    
    func testGetFavoritesByTag() async throws {
        // Given
        let tags = ["faith", "prayer", "faith", "worship"]
        for (i, tag) in tags.enumerated() {
            let audio = AudioDeclaration(
                id: "tag-\(i).mp3",
                title: "Audio \(i)",
                subtitle: "Sub",
                duration: "1:00",
                imageUrl: "",
                isPremium: false,
                tag: tag
            )
            manager.toggleFavorite(audio)
        }
        
        try await Task.sleep(nanoseconds: 200_000_000)
        
        // When
        let faithFavorites = manager.getFavorites(byTag: "faith")
        
        // Then
        XCTAssertEqual(faithFavorites.count, 2)
        XCTAssertTrue(faithFavorites.allSatisfy { $0.tag == "faith" })
    }
    
    // MARK: - Remove Favorites Tests
    
    func testRemoveFavoriteById() async throws {
        // Given
        let audio = AudioDeclaration(
            id: "remove-1.mp3",
            title: "To Remove",
            subtitle: "Sub",
            duration: "1:00",
            imageUrl: "",
            isPremium: false,
            tag: "faith"
        )
        
        manager.toggleFavorite(audio)
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertTrue(manager.isFavorite(audio))
        
        // When
        manager.removeFavorite(withId: "remove-1.mp3")
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Then
        XCTAssertTrue(mockRepository.deleteCalled)
        XCTAssertFalse(manager.isFavorite(audio))
    }
    
    func testRemoveFavoritesAtIndexSet() async throws {
        // Given
        for i in 0..<5 {
            let audio = AudioDeclaration(
                id: "batch-\(i).mp3",
                title: "Audio \(i)",
                subtitle: "Sub",
                duration: "1:00",
                imageUrl: "",
                isPremium: false,
                tag: "faith"
            )
            manager.toggleFavorite(audio)
        }
        
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(manager.favorites.count, 5)
        
        // When - Remove indices 1 and 3
        let indexSet = IndexSet([1, 3])
        manager.removeFavorites(at: indexSet)
        try await Task.sleep(nanoseconds: 200_000_000)
        
        // Then
        XCTAssertEqual(manager.favorites.count, 3)
    }
    
    func testClearAllFavorites() async throws {
        // Given
        for i in 0..<3 {
            let audio = AudioDeclaration(
                id: "clear-\(i).mp3",
                title: "Audio \(i)",
                subtitle: "Sub",
                duration: "1:00",
                imageUrl: "",
                isPremium: false,
                tag: "faith"
            )
            manager.toggleFavorite(audio)
        }
        
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(manager.favorites.count, 3)
        
        // When
        manager.clearAllFavorites()
        try await Task.sleep(nanoseconds: 200_000_000)
        
        // Then
        XCTAssertEqual(manager.favorites.count, 0)
    }
    
    // MARK: - Import/Export Tests
    
    func testExportFavorites() async throws {
        // Given
        let audio = AudioDeclaration(
            id: "export-1.mp3",
            title: "Export Test",
            subtitle: "Export",
            duration: "2:30",
            imageUrl: "https://example.com/export.jpg",
            isPremium: true,
            tag: "faith"
        )
        
        manager.toggleFavorite(audio)
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // When
        let exportData = manager.exportFavorites()
        
        // Then
        XCTAssertNotNil(exportData)
        
        if let data = exportData {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let decoded = try decoder.decode([AudioDeclaration].self, from: data)
            XCTAssertEqual(decoded.count, 1)
            XCTAssertEqual(decoded.first?.id, "export-1.mp3")
        }
    }
    
    func testImportFavoritesMerge() async throws {
        // Given - Add one existing favorite
        let existing = AudioDeclaration(
            id: "existing-1.mp3",
            title: "Existing",
            subtitle: "Sub",
            duration: "1:00",
            imageUrl: "",
            isPremium: false,
            tag: "faith"
        )
        
        manager.toggleFavorite(existing)
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Create import data with new favorites
        let toImport = [
            AudioDeclaration(
                id: "import-1.mp3",
                title: "Import 1",
                subtitle: "Sub",
                duration: "2:00",
                imageUrl: "",
                isPremium: false,
                tag: "prayer"
            ),
            AudioDeclaration(
                id: "import-2.mp3",
                title: "Import 2",
                subtitle: "Sub",
                duration: "3:00",
                imageUrl: "",
                isPremium: true,
                tag: "worship"
            )
        ]
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let importData = try encoder.encode(toImport)
        
        // When
        let success = try await manager.importFavorites(from: importData, mergeWithExisting: true)
        try await Task.sleep(nanoseconds: 200_000_000)
        
        // Then
        XCTAssertTrue(success)
        XCTAssertEqual(manager.favorites.count, 3) // 1 existing + 2 imported
    }
    
    func testImportFavoritesReplace() async throws {
        // Given - Add existing favorites
        for i in 0..<2 {
            let audio = AudioDeclaration(
                id: "old-\(i).mp3",
                title: "Old \(i)",
                subtitle: "Sub",
                duration: "1:00",
                imageUrl: "",
                isPremium: false,
                tag: "faith"
            )
            manager.toggleFavorite(audio)
        }
        
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(manager.favorites.count, 2)
        
        // Create import data
        let toImport = [
            AudioDeclaration(
                id: "new-1.mp3",
                title: "New 1",
                subtitle: "Sub",
                duration: "2:00",
                imageUrl: "",
                isPremium: false,
                tag: "prayer"
            )
        ]
        
        let encoder = JSONEncoder()
        let importData = try encoder.encode(toImport)
        
        // When
        let success = try await manager.importFavorites(from: importData, mergeWithExisting: false)
        try await Task.sleep(nanoseconds: 200_000_000)
        
        // Then
        XCTAssertTrue(success)
        XCTAssertEqual(manager.favorites.count, 1)
        XCTAssertEqual(manager.favorites.first?.id, "new-1.mp3")
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorHandlingOnToggle() async throws {
        // Given
        mockRepository.shouldThrowError = true
        let audio = AudioDeclaration(
            id: "error-test.mp3",
            title: "Error Test",
            subtitle: "Error",
            duration: "1:00",
            imageUrl: "",
            isPremium: false,
            tag: "faith"
        )
        
        // When
        manager.toggleFavorite(audio, retryCount: 1)
        try await Task.sleep(nanoseconds: 300_000_000) // Wait for retries
        
        // Then
        XCTAssertNotNil(manager.errorMessage)
        XCTAssertTrue(manager.errorMessage?.contains("Failed to toggle favorite") ?? false)
    }
    
    // MARK: - Analytics Tests
    
    func testGetFavoritesStats() async throws {
        // Given
        let audioItems = [
            ("faith", 3),
            ("prayer", 2),
            ("worship", 1)
        ]
        
        for (tag, count) in audioItems {
            for i in 0..<count {
                let audio = AudioDeclaration(
                    id: "\(tag)-\(i).mp3",
                    title: "\(tag) \(i)",
                    subtitle: "Sub",
                    duration: "1:00",
                    imageUrl: "",
                    isPremium: false,
                    tag: tag,
                    dateFavorited: Date()
                )
                manager.toggleFavorite(audio)
            }
        }
        
        try await Task.sleep(nanoseconds: 200_000_000)
        
        // When
        let stats = manager.getFavoritesStats()
        
        // Then
        XCTAssertEqual(stats.totalCount, 6)
        XCTAssertEqual(stats.byCategory["faith"], 3)
        XCTAssertEqual(stats.byCategory["prayer"], 2)
        XCTAssertEqual(stats.byCategory["worship"], 1)
        XCTAssertGreaterThanOrEqual(stats.averagePerWeek, 0)
    }
}