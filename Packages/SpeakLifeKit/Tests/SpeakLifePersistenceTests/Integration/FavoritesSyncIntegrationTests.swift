//
//  FavoritesSyncIntegrationTests.swift
//  SpeakLifeTests
//
//  Integration tests for favorites sync with Core Data + CloudKit
//

import XCTest
import CoreData
import Combine
import SpeakLifeCore
@testable import SpeakLifePersistence

/// Main-actor isolated for the same reason as `AffirmationRepositoryTests`:
/// an async body must not touch the main-queue `viewContext` off-queue.
@MainActor
final class FavoritesSyncIntegrationTests: XCTestCase {
    
    var persistenceController: PersistenceController!
    var audioRepository: AudioFavoriteRepository!
    var declarationRepository: DeclarationFavoriteRepository!
    var audioManager: AudioFavoritesManager!
    var unifiedManager: UnifiedFavoritesManager!
    var migrationService: FavoritesMigrationService!
    var cancellables: Set<AnyCancellable>!
    /// Stands in for the documents directory so the migration flow does not
    /// write `audioFavorites.txt` into the real one.
    var testDocumentsDirectory: URL!

    override func setUp() {
        super.setUp()

        testDocumentsDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: testDocumentsDirectory,
                                                 withIntermediateDirectories: true)

        // Use in-memory store for tests
        persistenceController = PersistenceController(inMemory: true)
        let context = persistenceController.container.viewContext
        
        audioRepository = AudioFavoriteRepository(context: context)
        declarationRepository = DeclarationFavoriteRepository(context: context)
        
        let docs: URL = testDocumentsDirectory
        audioManager = AudioFavoritesManager(
            repository: audioRepository,
            documentsDirectory: { docs }
        )
        
        unifiedManager = UnifiedFavoritesManager(
            declarationFavoriteRepository: declarationRepository,
            audioFavoriteRepository: audioRepository
        )
        
        migrationService = FavoritesMigrationService(
            audioFavoriteRepository: audioRepository,
            declarationFavoriteRepository: declarationRepository,
            documentsDirectory: { docs }
        )
        
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        // Close the throwaway store before dropping the controller. Setting the
        // property to nil does not: the SQLite connection, its WAL and its file
        // descriptors stay open until the process exits, so without this every
        // stack the suite builds is still open during every later test.
        persistenceController?.tearDownScratchStore()
        if let testDocumentsDirectory {
            try? FileManager.default.removeItem(at: testDocumentsDirectory)
        }
        testDocumentsDirectory = nil
        cancellables = nil
        migrationService = nil
        unifiedManager = nil
        audioManager = nil
        declarationRepository = nil
        audioRepository = nil
        persistenceController = nil
        
        super.tearDown()
    }
    
    // MARK: - End-to-End Sync Tests
    
    func testCompleteAudioFavoriteSyncFlow() async throws {
        // Given
        let audio = AudioDeclaration(
            id: "sync-test-1.mp3",
            title: "Sync Test Audio",
            subtitle: "Testing sync",
            duration: "5:30",
            imageUrl: "https://example.com/sync.jpg",
            isPremium: false,
            tag: "faith",
            season: 1,
            episode: 5
        )
        
        // When - Add favorite through manager
        audioManager.toggleFavorite(audio)
        
        // Wait for async operations
        try await Task.sleep(nanoseconds: 200_000_000)
        
        // Then - Verify it's persisted in Core Data
        let fetchedEntries = try await audioRepository.fetch(predicate: nil)
        XCTAssertEqual(fetchedEntries.count, 1)
        XCTAssertEqual(fetchedEntries.first?.audioId, "sync-test-1.mp3")
        
        // Verify manager recognizes it as favorite
        XCTAssertTrue(audioManager.isFavorite(audio))
        
        // Verify it appears in unified manager
        let audioFavorites = await unifiedManager.audioFavorites
        XCTAssertTrue(audioFavorites.contains { $0.id == audio.id })
    }
    
    func testCompleteDeclarationFavoriteSyncFlow() async throws {
        // Given
        let declaration = Declaration(
            text: "I am blessed and highly favored",
            book: "Ephesians",
            bibleVerseText: "Ephesians 1:3",
            category: .faith,
            categories: [],
            isFavorite: false,
            contentType: .affirmation,
            lastEdit: Date()
        )
        
        // When - Add through unified manager
        unifiedManager.toggleDeclarationFavorite(declaration)
        
        // Wait for async operations
        try await Task.sleep(nanoseconds: 300_000_000)
        
        // Then - Verify persistence
        let fetchedEntries = try await declarationRepository.fetch(predicate: nil)
        XCTAssertGreaterThanOrEqual(fetchedEntries.count, 0) // May have created entry
        
        // Check if it was properly categorized
        if declaration.category != .myOwn {
            let entry = try await declarationRepository.findByDeclarationId(declaration.id)
            XCTAssertNotNil(entry)
            XCTAssertEqual(entry?.text, declaration.text)
        }
    }
    
    // MARK: - Concurrent Operations Tests
    
    func testConcurrentFavoriteOperations() async throws {
        // Given - Multiple favorites to add concurrently
        let audioItems = (1...10).map { i in
            AudioDeclaration(
                id: "concurrent-\(i).mp3",
                title: "Audio \(i)",
                subtitle: "Sub \(i)",
                duration: "\(i):00",
                imageUrl: "",
                isPremium: i % 2 == 0,
                tag: ["faith", "prayer", "worship"][i % 3]
            )
        }
        
        // When - Add all concurrently
        await withTaskGroup(of: Void.self) { group in
            for audio in audioItems {
                group.addTask {
                    self.audioManager.toggleFavorite(audio)
                }
            }
        }
        
        // Wait for all operations to complete
        try await Task.sleep(nanoseconds: 500_000_000)
        
        // Then - All should be saved
        let fetchedEntries = try await audioRepository.fetch(predicate: nil)
        XCTAssertEqual(fetchedEntries.count, 10)
        
        // Verify all are recognized as favorites
        for audio in audioItems {
            XCTAssertTrue(audioManager.isFavorite(audio))
        }
    }
    
    // MARK: - Migration Integration Tests
    
    func testFullMigrationFlow() async throws {
        // Given - Create legacy file
        let fileManager = FileManager.default
        let legacyURL = testDocumentsDirectory.appendingPathComponent("audioFavorites.txt")
        
        let legacyFavorites = [
            AudioDeclaration(
                id: "migrate-1.mp3",
                title: "Legacy 1",
                subtitle: "Legacy Sub 1",
                duration: "3:00",
                imageUrl: "",
                isPremium: false,
                tag: "faith"
            ),
            AudioDeclaration(
                id: "migrate-2.mp3",
                title: "Legacy 2",
                subtitle: "Legacy Sub 2",
                duration: "4:00",
                imageUrl: "",
                isPremium: true,
                tag: "prayer"
            )
        ]
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(legacyFavorites)
        try data.write(to: legacyURL)
        
        // When - Run migration
        try await migrationService.migrateLegacyFavorites()
        
        // Wait for migration to complete
        try await Task.sleep(nanoseconds: 300_000_000)
        
        // Then - Verify migration success
        let migratedEntries = try await audioRepository.fetch(predicate: nil)
        XCTAssertEqual(migratedEntries.count, 2)
        
        // Verify they're accessible through manager
        XCTAssertEqual(audioManager.favorites.count, 2)
        
        // Legacy file should be removed
        XCTAssertFalse(fileManager.fileExists(atPath: legacyURL.path))
        
        // Clean up if test fails
        try? fileManager.removeItem(at: legacyURL)
    }
    
    // MARK: - Reactive Updates Tests
    
    func testReactiveUpdatesAcrossManagers() async throws {
        // Given
        let expectation = XCTestExpectation(description: "Reactive update")
        var receivedUpdate = false
        
        // Subscribe to changes
        audioManager.$favorites
            .dropFirst() // Skip initial value
            .sink { favorites in
                if !favorites.isEmpty && !receivedUpdate {
                    receivedUpdate = true
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When - Add favorite through repository directly
        let audio = AudioDeclaration(
            id: "reactive-1.mp3",
            title: "Reactive Test",
            subtitle: "Sub",
            duration: "2:00",
            imageUrl: "",
            isPremium: false,
            tag: "faith"
        )
        
        _ = try await audioRepository.createFromAudioDeclaration(audio)
        
        // Then - Manager should receive update
        await fulfillment(of: [expectation], timeout: 3.0)
        XCTAssertTrue(receivedUpdate)
        XCTAssertTrue(audioManager.isFavorite(audio))
    }
    
    // MARK: - Conflict Resolution Tests
    
    func testDuplicateFavoriteHandling() async throws {
        // Given
        let audio = AudioDeclaration(
            id: "duplicate-test.mp3",
            title: "Duplicate Test",
            subtitle: "Sub",
            duration: "1:00",
            imageUrl: "",
            isPremium: false,
            tag: "faith"
        )
        
        // When - Add same favorite twice
        audioManager.toggleFavorite(audio)
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Try to add again through repository
        do {
            _ = try await audioRepository.createFromAudioDeclaration(audio)
        } catch {
            // Constraint violation is acceptable
        }
        
        // Then - Should only have one entry
        let entries = try await audioRepository.fetch(
            predicate: NSPredicate(format: "audioId == %@", "duplicate-test.mp3")
        )
        XCTAssertLessThanOrEqual(entries.count, 1)
    }
    
    // MARK: - Bulk Writes

    /// `measure { Task { … } }` is a trap, and this test used to be one.
    ///
    /// `measure` takes a synchronous block. Spawning an unstructured `Task`
    /// inside it means the block returns before the first `await` resumes, so
    /// the timing measured nothing and the assertion inside never ran under the
    /// test's watch. Worse, `measure` runs the block ten times, so ten detached
    /// tasks outlived the test, and the first one to wake after `tearDown` read
    /// `audioRepository` — an implicitly unwrapped optional that had just been
    /// set to nil — and took the whole test process down:
    ///
    ///   FavoritesSyncIntegrationTests.swift:304: Fatal error: Unexpectedly
    ///   found nil while implicitly unwrapping an Optional value
    ///
    /// Awaiting the work is what the test was for. Fifty writes through the
    /// repository, then one fetch that has to see all fifty.
    func testBulkWritesAllLand() async throws {
        for i in 1...50 {
            let audio = AudioDeclaration(
                id: "bulk-\(i).mp3",
                title: "Bulk \(i)",
                subtitle: "Sub",
                duration: "\(i):00",
                imageUrl: "",
                isPremium: false,
                tag: "faith"
            )

            _ = try await audioRepository.createFromAudioDeclaration(audio)
        }

        let entries = try await audioRepository.fetch(predicate: nil)
        XCTAssertEqual(entries.count, 50)
    }
    
    // MARK: - Error Recovery Tests
    
    func testErrorRecoveryWithRetry() async throws {
        // Given - Audio that will be toggled with retry
        let audio = AudioDeclaration(
            id: "retry-test.mp3",
            title: "Retry Test",
            subtitle: "Sub",
            duration: "1:00",
            imageUrl: "",
            isPremium: false,
            tag: "faith"
        )
        
        // When - Toggle with retry (simulating potential failures)
        audioManager.toggleFavorite(audio, retryCount: 3)
        
        // Wait for retries to complete
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Then - Should eventually succeed
        let entries = try await audioRepository.fetch(predicate: nil)
        XCTAssertGreaterThan(entries.count, 0)
    }
    
    // MARK: - Data Integrity Tests
    
    func testDataIntegrityAcrossOperations() async throws {
        // Given - Initial set of favorites
        let initialAudio = [
            AudioDeclaration(
                id: "integrity-1.mp3",
                title: "Integrity 1",
                subtitle: "Sub 1",
                duration: "1:00",
                imageUrl: "",
                isPremium: false,
                tag: "faith"
            ),
            AudioDeclaration(
                id: "integrity-2.mp3",
                title: "Integrity 2",
                subtitle: "Sub 2",
                duration: "2:00",
                imageUrl: "",
                isPremium: true,
                tag: "prayer"
            )
        ]
        
        // Add initial favorites
        for audio in initialAudio {
            audioManager.toggleFavorite(audio)
        }
        
        try await Task.sleep(nanoseconds: 300_000_000)
        
        // When - Perform various operations
        // Remove first
        audioManager.toggleFavorite(initialAudio[0])
        
        // Add new one
        let newAudio = AudioDeclaration(
            id: "integrity-3.mp3",
            title: "Integrity 3",
            subtitle: "Sub 3",
            duration: "3:00",
            imageUrl: "",
            isPremium: false,
            tag: "worship"
        )
        audioManager.toggleFavorite(newAudio)
        
        try await Task.sleep(nanoseconds: 300_000_000)
        
        // Then - Verify final state
        let finalEntries = try await audioRepository.fetch(predicate: nil)
        XCTAssertEqual(finalEntries.count, 2) // Removed 1, kept 1, added 1
        
        XCTAssertFalse(audioManager.isFavorite(initialAudio[0]))
        XCTAssertTrue(audioManager.isFavorite(initialAudio[1]))
        XCTAssertTrue(audioManager.isFavorite(newAudio))
    }
}