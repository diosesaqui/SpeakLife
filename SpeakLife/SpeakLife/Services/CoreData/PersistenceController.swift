//
//  PersistenceController.swift
//  SpeakLife
//
//  Core Data Stack with iCloud Sync Configuration
//

import CoreData
import CloudKit
import UIKit

final class PersistenceController {
    
    static let shared = PersistenceController()
    
    // Track import attempts for retry logic
    private var importAttempts = 0
    private let maxImportAttempts = 5
    private let importRetryDelays = [5.0, 10.0, 15.0, 30.0, 60.0] // Progressive delays
    
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let viewContext = controller.container.viewContext
        
        // Add sample data for previews
        for i in 0..<5 {
            let journalEntry = JournalEntry(context: viewContext)
            journalEntry.id = UUID()
            journalEntry.text = "Sample journal entry \(i)"
            journalEntry.category = "faith"
            journalEntry.createdAt = Date()
            journalEntry.lastModified = Date()
            journalEntry.isFavorite = false
            
            let affirmationEntry = AffirmationEntry(context: viewContext)
            affirmationEntry.id = UUID()
            affirmationEntry.text = "Sample affirmation \(i)"
            affirmationEntry.category = "faith"
            affirmationEntry.createdAt = Date()
            affirmationEntry.lastModified = Date()
            affirmationEntry.isFavorite = false
        }
        
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        
        return controller
    }()
    
    let container: NSPersistentCloudKitContainer
    
    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "SpeakLife")
        
        if inMemory {
            container.persistentStoreDescriptions.forEach { storeDescription in
                storeDescription.url = URL(fileURLWithPath: "/dev/null")
            }
        } else {
            // Create a store description if none exists
            if container.persistentStoreDescriptions.isEmpty {
                let description = NSPersistentStoreDescription()
                description.type = NSSQLiteStoreType
                description.shouldInferMappingModelAutomatically = true
                description.shouldMigrateStoreAutomatically = true
                container.persistentStoreDescriptions = [description]
            }
            
            guard let description = container.persistentStoreDescriptions.first else {
                fatalError("Failed to retrieve a persistent store description.")
            }
            
            // Configure for CloudKit sync with performance optimizations
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            
            // Performance optimization: Enable WAL mode for better concurrent access
            description.setOption(["journal_mode": "WAL"] as NSDictionary, forKey: NSSQLitePragmasOption)
            
            // Set CloudKit container options with optimizations
            let options = NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.com.franchiz.speaklife")
            options.databaseScope = .private
            
            // IMPORTANT: Check if we're in production (TestFlight/App Store) or development
            #if DEBUG
            print("RWRW: Using CloudKit DEVELOPMENT environment")
            #else
            print("RWRW: Using CloudKit PRODUCTION environment")
            #endif
            
            description.cloudKitContainerOptions = options
        }
        
        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                print("RWRW: Persistent store load FAILED - \(error.localizedDescription)")
                #if DEBUG
                fatalError("Unresolved error \(error), \(error.userInfo)")
                #else
                // In production, log error but don't crash the app
                print("Core Data error: \(error), \(error.userInfo)")
                #endif
            } else {
                print("RWRW: Persistent store loaded successfully")
                print("RWRW: Store URL: \(storeDescription.url?.path ?? "No URL")")
                print("RWRW: CloudKit enabled: \(storeDescription.cloudKitContainerOptions != nil)")
                
                // CRITICAL: For production builds, we need to ensure schema is initialized
                #if !DEBUG
                self.initializeCloudKitSchema()
                #endif
                
                // Check CloudKit account status
                self.checkCloudKitAccountStatus()
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        
        // Configure merge policy for conflict resolution
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        // Performance optimizations for faster sync
        container.viewContext.undoManager = nil // Disable undo for better performance
        
        // Setup CloudKit sync event notifications
        setupCloudKitSyncLogging()
        
        // Setup background sync optimization
        setupBackgroundSyncOptimization()
        
        // Force initial CloudKit import check on fresh install with longer delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            self.checkForInitialCloudKitImport()
        }
    }
    
    // MARK: - Save Context
    func save() {
        let context = container.viewContext
        
        guard context.hasChanges else { return }
        
        do {
            try context.save()
            print("RWRW: Context saved successfully - changes committed to CloudKit sync")
        } catch {
            let nsError = error as NSError
            print("RWRW: Context save failed - \(nsError.localizedDescription)")
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }
    
    // MARK: - CloudKit Sync Logging
    private func setupCloudKitSyncLogging() {
        NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: container.persistentStoreCoordinator,
            queue: .main
        ) { notification in
            print("RWRW: CloudKit remote change notification received - \(notification.userInfo ?? [:])")
        }
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NSPersistentCloudKitContainerEventChangedNotification"),
            object: container,
            queue: .main
        ) { notification in
            if let event = notification.userInfo?["event"] as? NSPersistentCloudKitContainer.Event {
                self.logCloudKitEvent(event)
            }
        }
    }
    
    private func logCloudKitEvent(_ event: NSPersistentCloudKitContainer.Event) {
        let eventType = switch event.type {
        case .setup: "Setup"
        case .import: "Import"
        case .export: "Export"
        @unknown default: "Unknown"
        }
        
        print("RWRW: CloudKit \(eventType) - Started: \(event.startDate), Ended: \(event.endDate?.description ?? "In Progress")")
        
        if let error = event.error {
            print("RWRW: CloudKit \(eventType) Error - \(error.localizedDescription)")
        } else if event.endDate != nil {
            print("RWRW: CloudKit \(eventType) Success")
        }
    }
    
    private func checkCloudKitAccountStatus() {
        let container = CKContainer(identifier: "iCloud.com.franchiz.speaklife")
        
        container.accountStatus { status, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("RWRW: CloudKit account status check FAILED - \(error.localizedDescription)")
                } else {
                    let statusString = switch status {
                    case .available: "Available"
                    case .noAccount: "No Account"
                    case .restricted: "Restricted"
                    case .couldNotDetermine: "Could Not Determine"
                    case .temporarilyUnavailable: "Temporarily Unavailable"
                    @unknown default: "Unknown"
                    }
                    print("RWRW: CloudKit account status: \(statusString)")
                    
                    if status != .available {
                        print("RWRW: ⚠️ CloudKit not available - data will not sync")
                    }
                }
            }
        }
    }
    
    // MARK: - Background Sync Optimization
    private func setupBackgroundSyncOptimization() {
        // Trigger sync when app becomes active
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("RWRW: App became active - requesting CloudKit sync")
            self?.requestSyncIfNeeded()
        }
        
        // Trigger sync when app enters background
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("RWRW: App entering background - ensuring sync completion")
            self?.requestSyncIfNeeded()
        }
    }
    
    private func requestSyncIfNeeded() {
        // Force a sync by triggering export if there are pending changes
        let context = container.viewContext
        if context.hasChanges {
            do {
                try context.save()
                print("RWRW: Proactive sync triggered")
            } catch {
                print("RWRW: Proactive sync failed - \(error.localizedDescription)")
            }
        }
        
        // Also request import of remote changes
        container.viewContext.refreshAllObjects()
    }
    
    // MARK: - Initial CloudKit Import Check
    private func checkForInitialCloudKitImport() {
        print("RWRW: Checking for initial CloudKit import (attempt \(importAttempts + 1)/\(maxImportAttempts))...")
        
        // First check CloudKit account status
        let cloudKitContainer = CKContainer(identifier: "iCloud.com.franchiz.speaklife")
        cloudKitContainer.accountStatus { [weak self] status, error in
            guard let self = self else { return }
            
            if status != .available {
                let statusString = switch status {
                case .noAccount: "No iCloud account"
                case .restricted: "iCloud restricted"
                case .couldNotDetermine: "Could not determine"
                case .temporarilyUnavailable: "Temporarily unavailable"
                @unknown default: "Unknown status"
                }
                
                print("RWRW: CloudKit not available, status: \(status)")
                NotificationCenter.default.post(name: NSNotification.Name("CloudKitImportFailed"), 
                                              object: nil, 
                                              userInfo: ["reason": statusString])
                return
            }
            
            let context = self.container.viewContext
            context.perform {
                // Check if we have any local data
                let journalRequest = JournalEntry.fetchRequest()
                let affirmationRequest = AffirmationEntry.fetchRequest()
                
                do {
                    let journalCount = try context.count(for: journalRequest)
                    let affirmationCount = try context.count(for: affirmationRequest)
                    
                    print("RWRW: Local data count - Journals: \(journalCount), Affirmations: \(affirmationCount)")
                    
                    if journalCount == 0 && affirmationCount == 0 {
                        print("RWRW: No local data found - forcing CloudKit import...")
                        
                        self.importAttempts += 1
                        
                        // Notify UI that import is starting
                        DispatchQueue.main.async {
                            NotificationCenter.default.post(name: NSNotification.Name("CloudKitImportStarted"), object: nil)
                        }
                        
                        // Force CloudKit to import by refreshing context
                        DispatchQueue.main.async {
                            self.container.viewContext.refreshAllObjects()
                            
                            // Also try to trigger import by fetching from CloudKit
                            self.forceCloudKitImport()
                        }
                    } else {
                        print("RWRW: Local data exists - no import needed")
                        self.importAttempts = 0 // Reset attempts on success
                        
                        // Notify UI of successful data presence
                        DispatchQueue.main.async {
                            NotificationCenter.default.post(name: NSNotification.Name("CloudKitImportCompleted"), object: nil)
                        }
                    }
                } catch {
                    print("RWRW: Error checking local data count - \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func forceCloudKitImport() {
        print("RWRW: Forcing CloudKit import...")
        
        // Strategy 1: Refresh all objects in main context
        container.viewContext.refreshAllObjects()
        
        // Strategy 2: Reset and reload the context
        container.viewContext.reset()
        
        // Strategy 3: Create a new background context with fresh fetch
        let backgroundContext = container.newBackgroundContext()
        backgroundContext.automaticallyMergesChangesFromParent = true
        backgroundContext.perform {
            // Set up fetch requests with no cache
            let journalRequest = JournalEntry.fetchRequest()
            journalRequest.includesPendingChanges = true
            journalRequest.returnsObjectsAsFaults = false
            journalRequest.shouldRefreshRefetchedObjects = true
            
            let affirmationRequest = AffirmationEntry.fetchRequest()
            affirmationRequest.includesPendingChanges = true
            affirmationRequest.returnsObjectsAsFaults = false
            affirmationRequest.shouldRefreshRefetchedObjects = true
            
            do {
                // Force a fresh fetch
                let journals = try backgroundContext.fetch(journalRequest)
                let affirmations = try backgroundContext.fetch(affirmationRequest)
                
                print("RWRW: Background fetch results - Journals: \(journals.count), Affirmations: \(affirmations.count)")
                
                // If we found data in background context, ensure it's in main context
                if journals.count > 0 || affirmations.count > 0 {
                    DispatchQueue.main.async {
                        self.container.viewContext.refreshAllObjects()
                    }
                }
                
                // Save context to ensure changes propagate
                if backgroundContext.hasChanges {
                    try backgroundContext.save()
                }
                
                // Strategy 4: Force CloudKit to re-evaluate by creating a dummy query
                self.performDummyCloudKitQuery()
                
                // Wait a bit then check main context
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                    self.recheckAfterImport()
                }
                
            } catch {
                print("RWRW: Error during forced import - \(error.localizedDescription)")
            }
        }
    }
    
    private func performDummyCloudKitQuery() {
        // This forces CloudKit to sync by performing a direct query
        let container = CKContainer(identifier: "iCloud.com.franchiz.speaklife")
        let privateDatabase = container.privateCloudDatabase
        
        // Query for recent records to trigger sync
        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: "CD_JournalEntry", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "CD_createdAt", ascending: false)]
        
        let operation = CKQueryOperation(query: query)
        operation.resultsLimit = 1
        
        operation.recordFetchedBlock = { record in
            print("RWRW: Found CloudKit record: \(record.recordID)")
        }
        
        operation.queryCompletionBlock = { cursor, error in
            if let error = error {
                print("RWRW: CloudKit query error: \(error.localizedDescription)")
            } else {
                print("RWRW: CloudKit query completed")
            }
        }
        
        privateDatabase.add(operation)
    }
    
    private func recheckAfterImport() {
        print("RWRW: Rechecking data after forced import...")
        
        let context = container.viewContext
        context.perform {
            let journalRequest = JournalEntry.fetchRequest()
            let affirmationRequest = AffirmationEntry.fetchRequest()
            
            do {
                let journalCount = try context.count(for: journalRequest)
                let affirmationCount = try context.count(for: affirmationRequest)
                
                print("RWRW: Data count after import attempt - Journals: \(journalCount), Affirmations: \(affirmationCount)")
                
                if journalCount > 0 || affirmationCount > 0 {
                    print("RWRW: ✅ CloudKit import successful!")
                    
                    // Notify UI to refresh
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: NSNotification.Name("CloudKitImportCompleted"), object: nil)
                    }
                } else {
                    print("RWRW: ⚠️ No data imported - attempt \(self.importAttempts)/\(self.maxImportAttempts)")
                    
                    // Retry with progressive delays
                    if self.importAttempts < self.maxImportAttempts {
                        let delay = self.importRetryDelays[min(self.importAttempts - 1, self.importRetryDelays.count - 1)]
                        print("RWRW: Retrying import in \(delay) seconds...")
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                            self.checkForInitialCloudKitImport()
                        }
                    } else {
                        print("RWRW: Max import attempts reached. User may need to check iCloud settings.")
                        
                        // Notify UI of import failure
                        DispatchQueue.main.async {
                            NotificationCenter.default.post(name: NSNotification.Name("CloudKitImportFailed"), 
                                                          object: nil,
                                                          userInfo: ["reason": "Max attempts reached"])
                        }
                    }
                }
            } catch {
                print("RWRW: Error rechecking data - \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Manual Sync Request
    func requestImmediateSync() {
        print("RWRW: Manual sync requested")
        
        // Save any pending changes
        if container.viewContext.hasChanges {
            try? container.viewContext.save()
        }
        
        // Reset import attempts to try again
        importAttempts = 0
        
        // Trigger a fresh import check
        checkForInitialCloudKitImport()
    }
    
    // MARK: - CloudKit Schema Initialization
    private func initializeCloudKitSchema() {
        print("RWRW: Initializing CloudKit schema for production")
        
        // This forces Core Data to initialize the CloudKit schema
        // by performing a simple operation
        do {
            let backgroundContext = container.newBackgroundContext()
            backgroundContext.perform {
                // Try to count existing records - this ensures schema exists
                let journalRequest = JournalEntry.fetchRequest()
                journalRequest.fetchLimit = 1
                
                let affirmationRequest = AffirmationEntry.fetchRequest()
                affirmationRequest.fetchLimit = 1
                
                do {
                    _ = try backgroundContext.count(for: journalRequest)
                    _ = try backgroundContext.count(for: affirmationRequest)
                    print("RWRW: CloudKit schema check completed")
                } catch {
                    print("RWRW: CloudKit schema initialization error: \(error)")
                }
            }
        } catch {
            print("RWRW: Failed to initialize CloudKit schema: \(error)")
        }
    }
    
    // MARK: - Batch Delete
    func deleteAll<T: NSManagedObject>(_ type: T.Type) throws {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: String(describing: type))
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        deleteRequest.resultType = .resultTypeObjectIDs
        
        let result = try container.viewContext.execute(deleteRequest) as? NSBatchDeleteResult
        let changes: [AnyHashable: Any] = [NSDeletedObjectsKey: result?.result as? [NSManagedObjectID] ?? []]
        NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [container.viewContext])
    }
}
