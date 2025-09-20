//
//  SyncConflictResolverTests.swift
//  SpeakLifeTests
//
//  Unit tests for SyncConflictResolver
//

import XCTest
import CoreData
@testable import SpeakLife

final class SyncConflictResolverTests: XCTestCase {
    
    var syncResolver: SyncConflictResolver!
    var persistenceController: PersistenceController!
    var testContext: NSManagedObjectContext!
    
    override func setUp() {
        super.setUp()
        persistenceController = PersistenceController(inMemory: true)
        testContext = persistenceController.container.viewContext
        syncResolver = SyncConflictResolver(context: testContext)
    }
    
    override func tearDown() {
        syncResolver = nil
        testContext = nil
        persistenceController = nil
        super.tearDown()
    }
    
    // MARK: - Setup Tests
    func testSetupConflictResolution() {
        // When
        syncResolver.setupConflictResolution()
        
        // Then
        XCTAssertTrue(testContext.mergePolicy is CustomMergePolicy)
    }
    
    // MARK: - Merge Policy Tests
    func testCustomMergePolicyInitialization() {
        // Given
        let customMergePolicy = CustomMergePolicy()
        
        // When
        testContext.mergePolicy = customMergePolicy
        
        // Then
        XCTAssertTrue(testContext.mergePolicy is CustomMergePolicy)
    }
    
    // MARK: - Remote Change Notification Tests
    func testHandlePersistentStoreRemoteChangeNotification() {
        // Given
        let expectation = XCTestExpectation(description: "Remote change handled")
        
        // Create a journal entry to test context refresh
        let journalEntry = JournalEntry(context: testContext)
        journalEntry.id = UUID()
        journalEntry.text = "Test entry"
        journalEntry.category = "faith"
        journalEntry.createdAt = Date()
        journalEntry.lastModified = Date()
        
        try? testContext.save()
        
        // Setup conflict resolver
        syncResolver.setupConflictResolution()
        
        // When
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NotificationCenter.default.post(
                name: .NSPersistentStoreRemoteChange,
                object: self.testContext.persistentStoreCoordinator?.persistentStores.first
            )
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                expectation.fulfill()
            }
        }
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        // Test passes if no crash occurs during notification handling
    }
    
    // MARK: - Error Handling Tests
    func testCoreDataErrorTypes() {
        // Given
        let conflictResolutionError = CoreDataError.conflictResolutionFailed
        let syncFailedError = CoreDataError.syncFailed
        
        // Then
        XCTAssertEqual(conflictResolutionError.errorDescription, "Failed to resolve sync conflicts")
        XCTAssertEqual(syncFailedError.errorDescription, "iCloud sync failed")
    }
    
    // MARK: - Integration Tests
    func testSyncResolverWithRealContext() {
        // Given
        let realPersistenceController = PersistenceController(inMemory: true)
        let realContext = realPersistenceController.container.viewContext
        let realSyncResolver = SyncConflictResolver(context: realContext)
        
        // When
        realSyncResolver.setupConflictResolution()
        
        // Create test data
        let journalEntry = JournalEntry(context: realContext)
        journalEntry.id = UUID()
        journalEntry.text = "Integration test entry"
        journalEntry.category = "faith"
        journalEntry.createdAt = Date()
        journalEntry.lastModified = Date()
        
        // Then
        XCTAssertNoThrow(try realContext.save())
        
        let fetchRequest = JournalEntry.fetchRequest()
        let entries = try? realContext.fetch(fetchRequest)
        XCTAssertEqual(entries?.count, 1)
        XCTAssertEqual(entries?.first?.text, "Integration test entry")
    }
    
    // MARK: - Memory Management Tests
    func testSyncResolverDeallocation() {
        // Given
        weak var weakSyncResolver: SyncConflictResolver?
        
        autoreleasepool {
            let tempPersistenceController = PersistenceController(inMemory: true)
            let tempContext = tempPersistenceController.container.viewContext
            let tempSyncResolver = SyncConflictResolver(context: tempContext)
            weakSyncResolver = tempSyncResolver
            
            tempSyncResolver.setupConflictResolution()
        }
        
        // When
        // Objects should be deallocated after autoreleasepool
        
        // Then
        XCTAssertNil(weakSyncResolver, "SyncConflictResolver should be deallocated")
    }
}