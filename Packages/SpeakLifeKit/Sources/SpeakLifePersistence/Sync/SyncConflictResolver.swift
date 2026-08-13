//
//  SyncConflictResolver.swift
//  SpeakLife
//
//  Sync Conflict Resolution Strategy for iCloud
//

import Foundation
import CoreData
import CloudKit

public final class SyncConflictResolver {

    private let context: NSManagedObjectContext

    public init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
    }

    // MARK: - Conflict Resolution
    public func setupConflictResolution() {
        context.mergePolicy = CustomMergePolicy()
        
        // Listen for CloudKit sync notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePersistentStoreRemoteChange),
            name: .NSPersistentStoreRemoteChange,
            object: nil
        )
    }
    
    @objc private func handlePersistentStoreRemoteChange(_ notification: Notification) {
        Task { @MainActor in
            context.performAndWait {
                context.refreshAllObjects()
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Custom Merge Policy
public final class CustomMergePolicy: NSMergePolicy {

    public init() {
        super.init(merge: .mergeByPropertyObjectTrumpMergePolicyType)
    }
    
    public override func resolve(constraintConflicts list: [NSConstraintConflict]) throws {
        for conflict in list {
            try resolveConstraintConflict(conflict)
        }
    }

    public override func resolve(optimisticLockingConflicts list: [NSMergeConflict]) throws {
        for conflict in list {
            try resolveOptimisticLockingConflict(conflict)
        }
    }
    
    private func resolveConstraintConflict(_ conflict: NSConstraintConflict) throws {
        // For constraint conflicts, keep the most recently modified object
        let conflictingObjects = Array(conflict.conflictingObjects)
        guard let mostRecentObject = conflictingObjects.max(by: { obj1, obj2 in
            let date1 = getLastModifiedDate(from: obj1)
            let date2 = getLastModifiedDate(from: obj2)
            return date1 < date2
        }) else {
            throw CoreDataError.conflictResolutionFailed
        }
        
        for object in conflictingObjects {
            if object != mostRecentObject {
                if let context = object.managedObjectContext {
                    context.delete(object)
                }
            }
        }
    }
    
    private func resolveOptimisticLockingConflict(_ conflict: NSMergeConflict) throws {
        // For optimistic locking conflicts, merge changes intelligently
        let sourceObject = conflict.sourceObject
        
        let objectSnapshot = conflict.objectSnapshot ?? [:]
        let cachedSnapshot = conflict.cachedSnapshot ?? [:]
        
        // Compare last modified dates
        let sourceDate = getLastModifiedDate(from: sourceObject)
        let snapshotDate = objectSnapshot["lastModified"] as? Date ?? Date.distantPast
        
        if sourceDate > snapshotDate {
            // Local changes are newer, keep them
            for (key, value) in cachedSnapshot {
                if key != "lastModified" && sourceObject.value(forKey: key) == nil {
                    sourceObject.setValue(value, forKey: key)
                }
            }
        } else {
            // Remote changes are newer, merge them
            for (key, value) in objectSnapshot {
                if key != "lastModified" {
                    sourceObject.setValue(value, forKey: key)
                }
            }
        }
        
        // Always update lastModified to current time
        sourceObject.setValue(Date(), forKey: "lastModified")
    }
    
    private func getLastModifiedDate(from object: NSManagedObject) -> Date {
        return object.value(forKey: "lastModified") as? Date ?? Date.distantPast
    }
}

// MARK: - Error Types
public enum CoreDataError: Error, LocalizedError {
    case conflictResolutionFailed
    case syncFailed
    
    public var errorDescription: String? {
        switch self {
        case .conflictResolutionFailed:
            return "Failed to resolve sync conflicts"
        case .syncFailed:
            return "iCloud sync failed"
        }
    }
}