//
//  SyncConflictResolverTests.swift
//  SpeakLifeTests
//
//  Unit tests for SyncConflictResolver
//

import XCTest
import CoreData
@testable import SpeakLifePersistence

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
    /// The remote-change handler must survive a notification without crashing.
    ///
    /// This used to post the notification from inside `asyncAfter(0.1)`, fulfil
    /// an expectation from a second `asyncAfter(0.1)` nested in the first, and
    /// wait 1.0s for the pair. None of that delay was needed — nothing here is
    /// waiting for the notification to be *scheduled* — and on a loaded runner
    /// the two nested main-queue hops drifted past the budget and failed the
    /// test. It went red on main for that reason and nothing else.
    ///
    /// Posting is synchronous, so the handler has already run by the time
    /// `post` returns. The drain afterwards is only for any follow-up work the
    /// handler hands back to the main queue.
    func testHandlePersistentStoreRemoteChangeNotification() {
        // Given: a saved entry, so the context has something to refresh
        let journalEntry = JournalEntry(context: testContext)
        journalEntry.id = UUID()
        journalEntry.text = "Test entry"
        journalEntry.category = "faith"
        journalEntry.createdAt = Date()
        journalEntry.lastModified = Date()

        try? testContext.save()

        syncResolver.setupConflictResolution()

        // When
        NotificationCenter.default.post(
            name: .NSPersistentStoreRemoteChange,
            object: testContext.persistentStoreCoordinator?.persistentStores.first
        )
        drainMainQueue(for: 0.2)

        // Then: no crash, and the context is still usable afterwards.
        // The original test asserted nothing at all; this at least proves the
        // store survived the handler.
        XCTAssertNoThrow(try testContext.fetch(JournalEntry.fetchRequest()))
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