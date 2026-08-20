//
//  DataMigrationManagerTests.swift
//  SpeakLifeTests
//
//  Unit tests for DataMigrationManager
//

import XCTest
import CoreData
import SpeakLifeCore
@testable import SpeakLifePersistence

/// Main-actor isolated for the same reason as `AffirmationRepositoryTests`:
/// an async body must not touch the main-queue `viewContext` off-queue.
@MainActor
final class DataMigrationManagerTests: XCTestCase {
    
    var migrationManager: DataMigrationManager!
    var persistenceController: PersistenceController!
    var mockAPIService: MockAPIService!
    /// Stands in for the documents directory. Before this existed the cleanup
    /// tests wrote and deleted `declarations.json` in the real documents
    /// directory of whatever machine ran them.
    var testDocumentsDirectory: URL!

    override func setUp() {
        super.setUp()
        persistenceController = PersistenceController(inMemory: true)
        mockAPIService = MockAPIService()

        testDocumentsDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: testDocumentsDirectory,
                                                 withIntermediateDirectories: true)
        let docs: URL = testDocumentsDirectory
        migrationManager = DataMigrationManager(
            persistenceController: persistenceController,
            legacyAPIService: mockAPIService,
            documentsDirectory: { docs }
        )
        
        // Reset migration flag for each test
        UserDefaults.standard.removeObject(forKey: "HasMigratedToCoreData")
    }
    
    override func tearDown() {
        // Close the throwaway store before dropping the controller. Setting the
        // property to nil does not: the SQLite connection, its WAL and its file
        // descriptors stay open until the process exits, so without this every
        // stack the suite builds is still open during every later test.
        persistenceController?.tearDownScratchStore()
        UserDefaults.standard.removeObject(forKey: "HasMigratedToCoreData")
        if let testDocumentsDirectory {
            try? FileManager.default.removeItem(at: testDocumentsDirectory)
        }
        testDocumentsDirectory = nil
        migrationManager = nil
        mockAPIService = nil
        persistenceController = nil
        super.tearDown()
    }
    
    // MARK: - Migration Tests
    func testMigrateLegacyDataSuccess() async throws {
        // Given
        let journalDeclaration = Declaration(
            text: "Test journal entry",
            book: nil,
            bibleVerseText: nil,
            category: .myOwn,
            categories: [],
            isFavorite: false,
            contentType: .journal,
            lastEdit: Date()
        )
        
        let affirmationDeclaration = Declaration(
            text: "Test affirmation",
            book: nil,
            bibleVerseText: nil,
            category: .myOwn,
            categories: [],
            isFavorite: true,
            contentType: .affirmation,
            lastEdit: Date()
        )
        
        mockAPIService.mockDeclarations = [journalDeclaration, affirmationDeclaration]
        
        // When
        try await migrationManager.migrateLegacyData()
        
        // Then
        let context = persistenceController.container.viewContext
        
        let journalFetchRequest = JournalEntry.fetchRequest()
        let journalEntries = try context.fetch(journalFetchRequest)
        XCTAssertEqual(journalEntries.count, 1)
        XCTAssertEqual(journalEntries.first?.text, "Test journal entry")
        XCTAssertEqual(journalEntries.first?.category, "myOwn")
        XCTAssertFalse(journalEntries.first?.isFavorite ?? true)
        
        let affirmationFetchRequest = AffirmationEntry.fetchRequest()
        let affirmationEntries = try context.fetch(affirmationFetchRequest)
        XCTAssertEqual(affirmationEntries.count, 1)
        XCTAssertEqual(affirmationEntries.first?.text, "Test affirmation")
        XCTAssertEqual(affirmationEntries.first?.category, "myOwn")
        XCTAssertTrue(affirmationEntries.first?.isFavorite ?? false)
        
        // Migration flag should be set
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "HasMigratedToCoreData"))
    }
    
    func testMigrateLegacyDataSkipsIfAlreadyMigrated() async throws {
        // Given
        UserDefaults.standard.set(true, forKey: "HasMigratedToCoreData")
        mockAPIService.mockDeclarations = [
            Declaration(
                text: "Should not be migrated",
                category: .myOwn,
                contentType: .journal
            )
        ]
        
        // When
        try await migrationManager.migrateLegacyData()
        
        // Then
        let context = persistenceController.container.viewContext
        let journalFetchRequest = JournalEntry.fetchRequest()
        let journalEntries = try context.fetch(journalFetchRequest)
        XCTAssertEqual(journalEntries.count, 0)
        
        // API service should not have been called
        XCTAssertFalse(mockAPIService.declarationsCalled)
    }
    
    func testMigrateLegacyDataWithAPIError() async {
        // Given
        mockAPIService.shouldReturnError = true
        
        // When & Then
        do {
            try await migrationManager.migrateLegacyData()
            XCTFail("Should have thrown an error")
        } catch {
            XCTAssertTrue(error is APIError)
        }
        
        // Migration flag should not be set
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "HasMigratedToCoreData"))
    }
    
    func testMigrateLegacyDataFiltersNonOwnDeclarations() async throws {
        // Given
        let ownDeclaration = Declaration(
            text: "My own declaration",
            category: .myOwn,
            contentType: .journal
        )
        
        let systemDeclaration = Declaration(
            text: "System declaration",
            category: .faith,
            contentType: .journal
        )
        
        mockAPIService.mockDeclarations = [ownDeclaration, systemDeclaration]
        
        // When
        try await migrationManager.migrateLegacyData()
        
        // Then
        let context = persistenceController.container.viewContext
        let journalFetchRequest = JournalEntry.fetchRequest()
        let journalEntries = try context.fetch(journalFetchRequest)
        
        // Only the .myOwn declaration should be migrated
        XCTAssertEqual(journalEntries.count, 1)
        XCTAssertEqual(journalEntries.first?.text, "My own declaration")
    }
    
    // MARK: - Cleanup Tests
    func testCleanUpLegacyData() {
        // Given
        let declarationsURL = testDocumentsDirectory.appendingPathComponent("declarations.json")
        
        // Create a test file
        let testData = "test data".data(using: .utf8)!
        XCTAssertNoThrow(try testData.write(to: declarationsURL))
        XCTAssertTrue(FileManager.default.fileExists(atPath: declarationsURL.path))
        
        // When
        migrationManager.cleanUpLegacyData()
        
        // Then
        XCTAssertFalse(FileManager.default.fileExists(atPath: declarationsURL.path))
    }
    
    func testCleanUpLegacyDataWithNonExistentFile() {
        // Given
        let declarationsURL = testDocumentsDirectory.appendingPathComponent("declarations.json")
        
        // Ensure file doesn't exist
        try? FileManager.default.removeItem(at: declarationsURL)
        XCTAssertFalse(FileManager.default.fileExists(atPath: declarationsURL.path))
        
        // When & Then - should not crash
        XCTAssertNoThrow(migrationManager.cleanUpLegacyData())
    }
}

// MARK: - Mock API Service
class MockAPIService: APIService {
    var localVersion: Int = 0
    
    var remoteVersion: Int = 1
    var mockDeclarations: [Declaration] = []
    var shouldReturnError = false
    var declarationsCalled = false
    
    func declarations(completion: @escaping ([Declaration], APIError?, Bool) -> Void) {
        declarationsCalled = true
        
        if shouldReturnError {
            completion([], APIError.noData, false)
        } else {
            completion(mockDeclarations, nil, false)
        }
    }
    
    func save(declarations: [Declaration], completion: @escaping (Bool) -> Void) {
        completion(true)
    }
    
    func declarationCategories(completion: @escaping (Set<DeclarationCategory>, APIError?) -> Void) {
        completion(Set([.faith, .myOwn]), nil)
    }
    
    func save(selectedCategories: Set<DeclarationCategory>, completion: @escaping (Bool) -> Void) {
        completion(true)
    }
    
    func audio(version: Int, completion: @escaping (WelcomeAudio?, [AudioDeclaration]?) -> Void) {
        completion(nil, nil)
    }
}
