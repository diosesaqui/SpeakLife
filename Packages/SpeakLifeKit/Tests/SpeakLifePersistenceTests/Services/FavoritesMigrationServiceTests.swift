//
//  FavoritesMigrationServiceTests.swift
//  SpeakLifeTests
//
//  Unit tests for FavoritesMigrationService
//

import XCTest
import CoreData
import SpeakLifeCore
@testable import SpeakLifePersistence

// Mock Repository with failure simulation support
class MockAudioFavoriteRepositoryWithFailure: MockAudioFavoriteRepository {
    var shouldFailOnIds: [String] = []
    
    override func createFromAudioDeclaration(_ audio: AudioDeclaration) async throws -> AudioFavoriteEntry {
        if shouldFailOnIds.contains(audio.id) {
            throw NSError(domain: "MigrationTest", code: 1, userInfo: [NSLocalizedDescriptionKey: "Simulated failure"])
        }
        return try await super.createFromAudioDeclaration(audio)
    }
}

final class FavoritesMigrationServiceTests: XCTestCase {
    
    var migrationService: FavoritesMigrationService!
    var mockAudioRepo: MockAudioFavoriteRepositoryWithFailure!
    var mockDeclarationRepo: MockDeclarationFavoriteRepository!
    var testDirectory: URL!
    var fileManager: FileManager!
    
    override func setUp() {
        super.setUp()
        
        fileManager = FileManager.default
        
        // Create a temporary test directory
        let tempDir = fileManager.temporaryDirectory
        testDirectory = tempDir.appendingPathComponent(UUID().uuidString)
        try? fileManager.createDirectory(at: testDirectory, withIntermediateDirectories: true)
        
        mockAudioRepo = MockAudioFavoriteRepositoryWithFailure()
        mockDeclarationRepo = MockDeclarationFavoriteRepository()
        
        migrationService = FavoritesMigrationService(
            audioFavoriteRepository: mockAudioRepo,
            declarationFavoriteRepository: mockDeclarationRepo
        )
    }
    
    override func tearDown() {
        // Clean up test directory
        try? fileManager.removeItem(at: testDirectory)
        
        migrationService = nil
        mockAudioRepo = nil
        mockDeclarationRepo = nil
        testDirectory = nil
        fileManager = nil
        
        super.tearDown()
    }
    
    // MARK: - Audio Favorites Migration Tests
    
    func testMigrateAudioFavoritesSuccess() async throws {
        // Given - Create legacy audio favorites file
        let legacyFavorites = [
            AudioDeclaration(
                id: "legacy-1",
                title: "Legacy Audio 1",
                subtitle: "Sub 1",
                duration: "5:00",
                imageUrl: "https://example.com/1.jpg",
                isPremium: false,
                tag: "faith"
            ),
            AudioDeclaration(
                id: "legacy-2",
                title: "Legacy Audio 2",
                subtitle: "Sub 2",
                duration: "3:00",
                imageUrl: "https://example.com/2.jpg",
                isPremium: true,
                tag: "prayer"
            )
        ]
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(legacyFavorites)
        
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let legacyURL = documentsPath.appendingPathComponent("audioFavorites.txt")
        
        try data.write(to: legacyURL)
        
        // When
        try await migrationService.migrateLegacyFavorites()
        
        // Then
        XCTAssertEqual(mockAudioRepo.entries.count, 2)
        XCTAssertEqual(mockAudioRepo.entries.first?.audioId, "legacy-1")
        XCTAssertEqual(mockAudioRepo.entries.last?.audioId, "legacy-2")
        
        // Legacy file should be removed after successful migration
        XCTAssertFalse(fileManager.fileExists(atPath: legacyURL.path))
    }
    
    func testMigrateAudioFavoritesPartialFailure() async throws {
        // Given - Create legacy file with some items that will fail
        let legacyFavorites = [
            AudioDeclaration(
                id: "success-1",
                title: "Success",
                subtitle: "Sub",
                duration: "2:00",
                imageUrl: "",
                isPremium: false,
                tag: "faith"
            ),
            AudioDeclaration(
                id: "fail-1",
                title: "Fail",
                subtitle: "Sub",
                duration: "1:00",
                imageUrl: "",
                isPremium: false,
                tag: "prayer"
            )
        ]
        
        // Configure mock to fail on second item
        mockAudioRepo.shouldFailOnIds = ["fail-1"]
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(legacyFavorites)
        
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let legacyURL = documentsPath.appendingPathComponent("audioFavorites.txt")
        
        try data.write(to: legacyURL)
        
        // When
        try await migrationService.migrateLegacyFavorites()
        
        // Then
        XCTAssertEqual(mockAudioRepo.entries.count, 1) // Only successful item
        
        // Legacy file should NOT be removed due to failures
        XCTAssertTrue(fileManager.fileExists(atPath: legacyURL.path))
        
        // Backup should be created
        let backupURL = legacyURL.appendingPathExtension("backup")
        XCTAssertTrue(fileManager.fileExists(atPath: backupURL.path))
        
        // Clean up
        try? fileManager.removeItem(at: legacyURL)
        try? fileManager.removeItem(at: backupURL)
    }
    
    func testMigrateAudioFavoritesNoLegacyFile() async throws {
        // Given - No legacy file exists
        
        // When
        try await migrationService.migrateLegacyFavorites()
        
        // Then - Should complete without error
        XCTAssertEqual(mockAudioRepo.entries.count, 0)
    }
    
    func testMigrateAudioFavoritesSkipExisting() async throws {
        // Given - Add existing entry.
        //
        // Retain the controller for the whole test — pulling `.container.viewContext`
        // off a temporary would let the stack deallocate before the fetch runs, and
        // Core Data punished that upstream: a fetch returned a faulted object whose
        // context had already gone away, taking the process with it.
        let persistenceController = PersistenceController(inMemory: true)
        let context = persistenceController.container.viewContext
        addTeardownBlock { _ = persistenceController }
        let existing = AudioFavoriteEntry(context: context)
        existing.audioId = "existing-1"
        existing.title = "Existing"
        mockAudioRepo.entries.append(existing)
        
        // Create legacy file with duplicate
        let legacyFavorites = [
            AudioDeclaration(
                id: "existing-1", // Same ID
                title: "Legacy Duplicate",
                subtitle: "Sub",
                duration: "1:00",
                imageUrl: "",
                isPremium: false,
                tag: "faith"
            ),
            AudioDeclaration(
                id: "new-1",
                title: "New Item",
                subtitle: "Sub",
                duration: "2:00",
                imageUrl: "",
                isPremium: false,
                tag: "prayer"
            )
        ]
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(legacyFavorites)
        
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let legacyURL = documentsPath.appendingPathComponent("audioFavorites.txt")
        
        try data.write(to: legacyURL)
        
        // When
        try await migrationService.migrateLegacyFavorites()
        
        // Then
        XCTAssertEqual(mockAudioRepo.entries.count, 2) // 1 existing + 1 new
        XCTAssertTrue(mockAudioRepo.entries.contains { $0.audioId == "new-1" })
        
        // Clean up
        try? fileManager.removeItem(at: legacyURL)
    }
    
    func testMigrateCorruptedLegacyFile() async throws {
        // Given - Create corrupted legacy file
        let corruptedData = "This is not valid JSON".data(using: .utf8)!
        
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let legacyURL = documentsPath.appendingPathComponent("audioFavorites.txt")
        
        try corruptedData.write(to: legacyURL)
        
        // When/Then - Should handle error gracefully
        do {
            try await migrationService.migrateLegacyFavorites()
            // Should handle error internally, not throw
        } catch {
            // Error is acceptable
            XCTAssertTrue(error is MigrationError)
        }
        
        // Legacy file should remain
        XCTAssertTrue(fileManager.fileExists(atPath: legacyURL.path))
        
        // Clean up
        try? fileManager.removeItem(at: legacyURL)
    }
    
    // MARK: - Migration Results Tests
    
    func testMigrationResultsTracking() async throws {
        // Given - Create legacy file with multiple items
        let legacyFavorites = (1...5).map { i in
            AudioDeclaration(
                id: "item-\(i)",
                title: "Item \(i)",
                subtitle: "Sub",
                duration: "\(i):00",
                imageUrl: "",
                isPremium: false,
                tag: "faith"
            )
        }
        
        // Configure mock to track results
        mockAudioRepo.shouldFailOnIds = ["item-3", "item-5"]
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(legacyFavorites)
        
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let legacyURL = documentsPath.appendingPathComponent("audioFavorites.txt")
        
        try data.write(to: legacyURL)
        
        // When
        try await migrationService.migrateLegacyFavorites()
        
        // Then
        // 3 successful (items 1, 2, 4)
        // 2 failed (items 3, 5)
        XCTAssertEqual(mockAudioRepo.entries.count, 3)
        
        // Legacy file should remain due to failures
        XCTAssertTrue(fileManager.fileExists(atPath: legacyURL.path))
        
        // Clean up
        try? fileManager.removeItem(at: legacyURL)
        let backupURL = legacyURL.appendingPathExtension("backup")
        try? fileManager.removeItem(at: backupURL)
    }
    
    // MARK: - Large Migrations

    /// Was `measure { Task { … } }`. The block returned before the migration's
    /// first `await` resumed, so it timed task creation and asserted nothing,
    /// and the ten detached tasks it left running outlived `tearDown`.
    func testLargeLegacyFileMigratesInFull() async throws {
        // Given - Create large legacy dataset
        let legacyFavorites = (1...100).map { i in
            AudioDeclaration(
                id: "legacy-\(i).mp3",
                title: "Legacy Item \(i)",
                subtitle: "Sub \(i)",
                duration: "\(i % 60):00",
                imageUrl: "https://example.com/\(i).jpg",
                isPremium: i % 2 == 0,
                tag: ["faith", "prayer", "worship"][i % 3]
            )
        }
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(legacyFavorites)
        
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let legacyURL = documentsPath.appendingPathComponent("audioFavorites.txt")
        
        try data.write(to: legacyURL)
        
        // When
        try await migrationService.migrateLegacyFavorites()

        // Then - every row crossed, and the legacy file is gone
        XCTAssertEqual(mockAudioRepo.entries.count, 100)
        XCTAssertFalse(fileManager.fileExists(atPath: legacyURL.path))

        // Clean up
        try? fileManager.removeItem(at: legacyURL)
    }
}

