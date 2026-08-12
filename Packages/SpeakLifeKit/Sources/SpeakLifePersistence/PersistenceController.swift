//
//  PersistenceController.swift
//  SpeakLife
//
//  Core Data Stack with iCloud Sync Configuration
//

import CoreData
import CloudKit
import Foundation
import SpeakLifeCore

public final class PersistenceController {

    public static let shared = PersistenceController()

    // Track import attempts for retry logic
    private var importAttempts = 0
    private let maxImportAttempts = 5
    private let importRetryDelays = [5.0, 10.0, 15.0, 30.0, 60.0] // Progressive delays

    deinit {
        // Clean up notification observers
        NotificationCenter.default.removeObserver(self)
    }

    public static var preview: PersistenceController = {
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
    
    public let container: NSPersistentCloudKitContainer

    /// Whether CloudKit should be left alone entirely.
    ///
    /// Tests must not reach CloudKit, for two reasons and the second is the
    /// serious one.
    ///
    /// It is slow. `SpeakLifeApp` holds `PersistenceController.shared`, so every
    /// test run stands up mirroring and pushes a schema, then retries against an
    /// account no simulator has for the life of the process.
    ///
    /// And it is not hermetic. Run locally by a developer who is signed in, the
    /// suite mirrors its rows into `iCloud.com.franchiz.speaklife` — the same
    /// private database the shipping app uses. Test fixtures do not belong in a
    /// real user's iCloud, and a test whose result depends on what is already up
    /// there is not a test.
    ///
    /// Local persistence is untouched: the SQLite store, history tracking and
    /// migration behave exactly as they do in the app. Only the CloudKit traffic
    /// is left off.
    static var isRunningTests: Bool {
        // Duplicated from `AppEnvironment.isRunningTests` (in the app target)
        // so this file compiles inside a Foundation-only SwiftPM target.
        // Kept identical byte-for-byte: the environment probe is checked
        // before the class probe on purpose — see the note on AppEnvironment
        // for why the order matters at launch.
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || NSClassFromString("XCTestCase") != nil
    }

    /// Loaded from the bundle exactly once, and shared by every container.
    ///
    /// `NSPersistentCloudKitContainer(name:)` reads the model off disk on every
    /// construction and hands back a *different* `NSManagedObjectModel` each
    /// time. The app builds one container, so in production this is invisible.
    /// The test suite builds a fresh `PersistenceController` in almost every
    /// `setUp`, and from the second one on, the same `NSManagedObject`
    /// subclasses are registered against several identical-but-distinct models.
    /// Core Data then cannot tell which entity a subclass refers to:
    ///
    ///   +[JournalEntry entity] Failed to find a unique match for an
    ///   NSEntityDescription to a managed object subclass
    ///
    /// It logs that and carries on with an arbitrary choice, which is how a
    /// suite ends up failing in scattered, unrelated-looking ways and
    /// occasionally taking the process down.
    ///
    /// One model instance for the whole process removes the ambiguity at its
    /// source, and costs nothing in the app.
    static let managedObjectModel: NSManagedObjectModel = {
        // `Bundle.module` resolves to the SwiftPM-generated resource bundle
        // for `SpeakLifePersistence`, which is where the .xcdatamodeld ships.
        // (Previously `Bundle(for: PersistenceController.self)` because the
        // model lived alongside the app target; SwiftPM compiles the model
        // with `momc` at build time.)
        guard let url = Bundle.module
                .url(forResource: "SpeakLife", withExtension: "momd"),
              let model = NSManagedObjectModel(contentsOf: url) else {
            fatalError("SpeakLife.momd is missing from the bundle")
        }
        return model
    }()

    public init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "SpeakLife",
                                                  managedObjectModel: Self.managedObjectModel)
        
        // Detect which CloudKit environment we're in
        #if DEBUG
        print("🔵 CloudKit Environment: DEVELOPMENT")
        #else
        print("🟢 CloudKit Environment: PRODUCTION")
        #endif
        
        if inMemory {
            container.persistentStoreDescriptions.forEach { storeDescription in
                storeDescription.url = URL(fileURLWithPath: "/dev/null")

                // Not redundant. `NSPersistentCloudKitContainer` fills the
                // default description's `cloudKitContainerOptions` in from the
                // app's iCloud entitlement before this code runs, so an
                // in-memory store that never asked for CloudKit gets mirroring
                // anyway. The suite's own log said so:
                //
                //   Observing store: <NSSQLCore> (URL: file:///dev/null)
                //   CloudKit enabled: true
                //
                // A store pointed at /dev/null has nothing to mirror, and the
                // setup request it enqueues is pure latency in every test.
                storeDescription.cloudKitContainerOptions = nil
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
            if Self.isRunningTests {
                // Clearing, not just declining to set: the container seeds this
                // from the iCloud entitlement on its own, so leaving it alone
                // leaves mirroring on.
                description.cloudKitContainerOptions = nil
                print("🧪 Running under XCTest — CloudKit mirroring disabled")
            } else {
                let options = NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.com.franchiz.speaklife")
                options.databaseScope = .private

                description.cloudKitContainerOptions = options
            }
        }
        
        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                print("Persistent store load FAILED - \(error.localizedDescription)")
                #if DEBUG
                fatalError("Unresolved error \(error), \(error.userInfo)")
                #else
                // In production, log error but don't crash the app
                print("Core Data error: \(error), \(error.userInfo)")
                #endif
            } else {
                print("Persistent store loaded successfully")
                print("Store URL: \(storeDescription.url?.path ?? "No URL")")
                print("CloudKit enabled: \(storeDescription.cloudKitContainerOptions != nil)")

                // Initialize CloudKit schema for all builds to ensure proper sync
                self.initializeCloudKitSchema()

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

        // Background sync optimization observers used to be registered here.
        // They were moved to `start(lifecycle:)` because the notification
        // names come from UIKit and must be injected by the app target so
        // this file stays UIKit-free.

        // Check CloudKit import in background to avoid blocking UI
        Task(priority: .background) {
            try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
            await MainActor.run {
                self.checkForInitialCloudKitImport()
            }
        }
    }
    
    // MARK: - Save Context
    public func save() {
        let context = container.viewContext
        
        guard context.hasChanges else { return }
        
        do {
            try context.save()
            print("Context saved successfully - changes committed to CloudKit sync")
        } catch {
            let nsError = error as NSError
            print("Context save failed - \(nsError.localizedDescription)")
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
            print("CloudKit remote change notification received - \(notification.userInfo ?? [:])")
        }
        
        // More detailed CloudKit event logging
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCloudKitEvent(_:)),
            name: NSNotification.Name("NSPersistentCloudKitContainer.eventChangedNotification"),
            object: nil
        )
    }
    
    @objc private func handleCloudKitEvent(_ notification: Notification) {
        guard let event = notification.userInfo?["event"] as? NSPersistentCloudKitContainer.Event else { return }
        logCloudKitEvent(event)
    }
    
    private func logCloudKitEvent(_ event: NSPersistentCloudKitContainer.Event) {
        let eventType = switch event.type {
        case .setup: "Setup"
        case .import: "Import"
        case .export: "Export"
        @unknown default: "Unknown"
        }
        
        print("CloudKit \(eventType) - Started: \(event.startDate), Ended: \(event.endDate?.description ?? "In Progress")")
        
        if let error = event.error {
            print("CloudKit \(eventType) Error - \(error.localizedDescription)")
        } else if event.endDate != nil {
            print("CloudKit \(eventType) Success")
        }
    }
    
    private func checkCloudKitAccountStatus() {
        guard !Self.isRunningTests else { return }
        let container = CKContainer(identifier: "iCloud.com.franchiz.speaklife")
        
        container.accountStatus { status, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("CloudKit account status check FAILED - \(error.localizedDescription)")
                } else {
                    let statusString = switch status {
                    case .available: "Available"
                    case .noAccount: "No Account"
                    case .restricted: "Restricted"
                    case .couldNotDetermine: "Could Not Determine"
                    case .temporarilyUnavailable: "Temporarily Unavailable"
                    @unknown default: "Unknown"
                    }
                    print("CloudKit account status: \(statusString)")
                    
                    if status != .available {
                        // Warning: 
                        print("⚠️ CloudKit not available - data will not sync")
                    }
                }
            }
        }
    }
    
    // MARK: - Background Sync Optimization

    /// Called once by the app after `PersistenceController.shared` has been
    /// touched. Registering here (rather than in `init`) lets the app inject
    /// the UIKit lifecycle names so this file does not need to import UIKit.
    ///
    /// Safe to call multiple times — subsequent calls simply add duplicate
    /// observers, which is harmless (both call the same idempotent
    /// `requestSyncIfNeeded`) but still worth avoiding, so the app should
    /// call it exactly once from `didFinishLaunchingWithOptions`.
    public func start(lifecycle: LifecycleNames) {
        // Trigger sync when app becomes active
        NotificationCenter.default.addObserver(
            forName: lifecycle.didBecomeActive,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("App became active - requesting CloudKit sync")
            self?.requestSyncIfNeeded()
        }

        // Trigger sync when app enters background
        NotificationCenter.default.addObserver(
            forName: lifecycle.didEnterBackground,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("App entering background - ensuring sync completion")
            self?.requestSyncIfNeeded()
        }
    }
    
    private func requestSyncIfNeeded() {
        // Force a sync by triggering export if there are pending changes
        let context = container.viewContext
        if context.hasChanges {
            do {
                try context.save()
                print("Proactive sync triggered")
            } catch {
                print("Proactive sync failed - \(error.localizedDescription)")
            }
        }
        
        // Also request import of remote changes
        container.viewContext.refreshAllObjects()
    }
    
    // MARK: - Initial CloudKit Import Check
    private func checkForInitialCloudKitImport() {
        guard !Self.isRunningTests else { return }
        print("Checking for initial CloudKit import (attempt \(importAttempts + 1)/\(maxImportAttempts))...")
        
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
                
                print("CloudKit not available, status: \(status)")
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
                let audioFavoriteRequest = AudioFavoriteEntry.fetchRequest()
                let declarationFavoriteRequest = DeclarationFavoriteEntry.fetchRequest()
                
                do {
                    let journalCount = try context.count(for: journalRequest)
                    let affirmationCount = try context.count(for: affirmationRequest)
                    let audioFavoriteCount = try context.count(for: audioFavoriteRequest)
                    let declarationFavoriteCount = try context.count(for: declarationFavoriteRequest)
                    
                    print("Local data count - Journals: \(journalCount), Affirmations: \(affirmationCount)")
                    print("Favorite data count - Audio: \(audioFavoriteCount), Declarations: \(declarationFavoriteCount)")
                    
                    if journalCount == 0 && affirmationCount == 0 && audioFavoriteCount == 0 && declarationFavoriteCount == 0 {
                        print("No local data found - forcing CloudKit import...")
                        
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
                        print("Local data exists - no import needed")
                        self.importAttempts = 0 // Reset attempts on success
                        
                        // Notify UI of successful data presence
                        DispatchQueue.main.async {
                            NotificationCenter.default.post(name: NSNotification.Name("CloudKitImportCompleted"), object: nil)
                        }
                    }
                } catch {
                    print("Error checking local data count - \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func forceCloudKitImport() {
        print("Forcing CloudKit import...")
        
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
                
                print("Background fetch results - Journals: \(journals.count), Affirmations: \(affirmations.count)")
                
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
                print("Error during forced import - \(error.localizedDescription)")
            }
        }
    }
    
    private func performDummyCloudKitQuery() {
        guard !Self.isRunningTests else { return }
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
            print("Found CloudKit record: \(record.recordID)")
        }
        
        operation.queryCompletionBlock = { cursor, error in
            if let error = error {
                print("CloudKit query error: \(error.localizedDescription)")
            } else {
                print("CloudKit query completed")
            }
        }
        
        privateDatabase.add(operation)
    }
    
    private func recheckAfterImport() {
        print("Rechecking data after forced import...")
        
        let context = container.viewContext
        context.perform {
            let journalRequest = JournalEntry.fetchRequest()
            let affirmationRequest = AffirmationEntry.fetchRequest()
            
            do {
                let journalCount = try context.count(for: journalRequest)
                let affirmationCount = try context.count(for: affirmationRequest)
                
                print("Data count after import attempt - Journals: \(journalCount), Affirmations: \(affirmationCount)")
                
                if journalCount > 0 || affirmationCount > 0 {
                    print("✅ CloudKit import successful!")
                    
                    // Notify UI to refresh
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: NSNotification.Name("CloudKitImportCompleted"), object: nil)
                    }
                } else {
                    // Warning: 
                    print("⚠️ No data imported - attempt \(self.importAttempts)/\(self.maxImportAttempts)")
                    
                    // Retry with progressive delays
                    if self.importAttempts < self.maxImportAttempts {
                        let delay = self.importRetryDelays[min(self.importAttempts - 1, self.importRetryDelays.count - 1)]
                        print("Retrying import in \(delay) seconds...")
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                            self.checkForInitialCloudKitImport()
                        }
                    } else {
                        print("Max import attempts reached. User may need to check iCloud settings.")
                        
                        // Notify UI of import failure
                        DispatchQueue.main.async {
                            NotificationCenter.default.post(name: NSNotification.Name("CloudKitImportFailed"), 
                                                          object: nil,
                                                          userInfo: ["reason": "Max attempts reached"])
                        }
                    }
                }
            } catch {
                print("Error rechecking data - \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Manual Sync Request

    /// The requester a repository uses when nobody injected one.
    ///
    /// Repositories are handed the context they should write to, and then used
    /// to reach past it to `PersistenceController.shared` to nudge sync. That
    /// one line undid the injection: a test writing to its own in-memory store
    /// still *built the app's real SQLite stack* on the first save, started
    /// CloudKit mirroring on it, and left it running for the rest of the
    /// process. Reading `shared` is what constructs it, so a guard inside
    /// `requestImmediateSync()` would already be too late.
    ///
    /// Under XCTest this hands back a requester that does nothing and never
    /// touches `shared`.
    public static var defaultSyncRequester: ImmediateSyncRequesting {
        isRunningTests ? NoOpSyncRequester() : shared
    }

    public func requestImmediateSync() {
        print("Manual sync requested")
        
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
        guard !Self.isRunningTests else { return }
        #if DEBUG
        // Push the full model schema (incl. ProgressEventEntry/SyncedSetting)
        // to the CloudKit DEVELOPMENT environment so the record types exist
        // before any real data is written. Release builds use the Production
        // environment, where the schema must be promoted via CloudKit
        // Console — this call is dev-only by design.
        DispatchQueue.global(qos: .utility).async { [container] in
            do {
                try container.initializeCloudKitSchema(options: [])
                print("CloudKit development schema initialized")
            } catch {
                print("CloudKit schema initialization failed (non-fatal): \(error.localizedDescription)")
            }
        }
        #endif

        // Simple schema check - just verify entities can be queried
        let backgroundContext = container.newBackgroundContext()
        backgroundContext.perform {
            do {
                // Perform a simple count to ensure entities are recognized
                _ = try backgroundContext.count(for: JournalEntry.fetchRequest())
                _ = try backgroundContext.count(for: AffirmationEntry.fetchRequest())
                _ = try backgroundContext.count(for: DeclarationFavoriteEntry.fetchRequest())
                _ = try backgroundContext.count(for: AudioFavoriteEntry.fetchRequest())
                _ = try backgroundContext.count(for: ProgressEventEntry.fetchRequest())
                _ = try backgroundContext.count(for: SyncedSetting.fetchRequest())

                print("CloudKit schema check completed")
            } catch {
                print("CloudKit schema initialization check failed: \(error)")
                // Non-fatal - schema will be created when first entity is saved
            }
        }
    }
    
    // MARK: - Batch Delete
    public func deleteAll<T: NSManagedObject>(_ type: T.Type) throws {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: String(describing: type))
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        deleteRequest.resultType = .resultTypeObjectIDs
        
        let result = try container.viewContext.execute(deleteRequest) as? NSBatchDeleteResult
        let changes: [AnyHashable: Any] = [NSDeletedObjectsKey: result?.result as? [NSManagedObjectID] ?? []]
        NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [container.viewContext])
    }
}

// MARK: - Immediate Sync

/// Asks the persistent stack to push whatever is pending up to CloudKit now.
///
/// Exists so a repository can nudge sync without naming
/// `PersistenceController.shared`. A repository is given the context it writes
/// to; the thing it pushes through should arrive the same way.
public protocol ImmediateSyncRequesting {
    func requestImmediateSync()
}

extension PersistenceController: ImmediateSyncRequesting {}

/// Does nothing, which is exactly right for a store with no CloudKit behind it.
public struct NoOpSyncRequester: ImmediateSyncRequesting {
    public init() {}
    public func requestImmediateSync() {}
}
