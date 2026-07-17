//
//  ProgressSyncEntities.swift
//  SpeakLife
//
//  NSManagedObject subclasses for the iCloud progress-sync entities.
//
//  ProgressEventEntry is an append-only event log: one row per (kind, key).
//  CloudKit merges row sets from multiple devices as a union, so derived
//  numbers (streaks, totals) are recomputed locally from the merged rows and
//  no device can lose another device's progress.
//
//  SyncedSetting is a generic key/value record used to mirror whitelisted
//  UserDefaults preferences across devices (last-writer-wins, with custom
//  lossless mergers for progress-bearing blobs).
//

import Foundation
import CoreData

// MARK: - ProgressEventEntry

@objc(ProgressEventEntry)
public class ProgressEventEntry: NSManagedObject {

}

extension ProgressEventEntry {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ProgressEventEntry> {
        return NSFetchRequest<ProgressEventEntry>(entityName: "ProgressEventEntry")
    }

    @NSManaged public var id: UUID?
    /// Event family, e.g. "dayCompletion", "listenedAudio", "counter".
    @NSManaged public var kind: String
    /// Natural key within the kind (day stamp, audio id, counter id, ...).
    /// CloudKit cannot enforce uniqueness — the app dedups on (kind, key).
    @NSManaged public var key: String
    /// Optional JSON payload with event details.
    @NSManaged public var payload: Data?
    @NSManaged public var deviceId: String
    @NSManaged public var createdAt: Date?
    @NSManaged public var lastModified: Date?
}

extension ProgressEventEntry: Identifiable {

}

// MARK: - SyncedSetting

@objc(SyncedSetting)
public class SyncedSetting: NSManagedObject {

}

extension SyncedSetting {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<SyncedSetting> {
        return NSFetchRequest<SyncedSetting>(entityName: "SyncedSetting")
    }

    @NSManaged public var id: UUID?
    /// The mirrored UserDefaults key.
    @NSManaged public var key: String
    /// Property-list encoded value (wrapped in a single-entry dictionary).
    @NSManaged public var value: Data?
    @NSManaged public var deviceId: String
    @NSManaged public var lastModified: Date?
}

extension SyncedSetting: Identifiable {

}
