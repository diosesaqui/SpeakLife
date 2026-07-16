//
//  ProgressSyncStore.swift
//  SpeakLife
//
//  iCloud sync engine for user progress, built on the existing
//  NSPersistentCloudKitContainer stack (private database).
//
//  Progress is stored as an append-only event log (ProgressEventEntry):
//  one row per (kind, key). Devices only ever ADD rows, so CloudKit merges
//  multi-device histories as a union and nothing is ever lost — derived
//  values (streaks, totals) are recomputed locally from the merged rows.
//
//  Lifetime counters use one row per (counter, device); the displayed total
//  is this device's contribution plus the sum of every other device's row,
//  so increments made on two devices at once are both kept.
//
//  CloudKit cannot enforce unique constraints, so two devices can insert the
//  same (kind, key) before syncing. A deterministic dedup pass runs after
//  every remote import: every device keeps the same survivor row (earliest
//  createdAt, id as tie-break) and deletes the rest, and the deletes sync.
//

import Foundation
import CoreData
import UIKit

final class ProgressSyncStore {

    static let shared = ProgressSyncStore()

    // MARK: - Event kinds

    enum Kind {
        static let dayCompletion = "dayCompletion"   // key = "yyyy-MM-dd" local day stamp
        static let listenedAudio = "listenedAudio"   // key = audio id
        static let counter = "counter"               // key = "<counterKey>|<deviceId>"
    }

    /// Posted on the main queue after remote CloudKit changes have been
    /// merged and deduped. userInfo["kinds"] is a Set<String> of event kinds
    /// present in the store so observers can refresh what they care about.
    static let dataDidChange = Notification.Name("ProgressSyncStoreDataDidChange")

    // MARK: - Device identity

    private static let deviceIdKey = "sl_syncDeviceId"

    static var deviceId: String {
        if let existing = UserDefaults.standard.string(forKey: deviceIdKey) {
            return existing
        }
        let fresh = UUID().uuidString
        UserDefaults.standard.set(fresh, forKey: deviceIdKey)
        return fresh
    }

    // MARK: - Lifetime counters synced across devices

    /// UserDefaults counter keys mirrored as per-device contribution rows.
    static let syncedCounterKeys = [
        "totalAffirmationsSpoken",
        "totalVersesRead",
        "totalSocialShares",
        "totalFavoritesAdded"
    ]

    // MARK: - Private state

    private let container: NSPersistentCloudKitContainer
    private lazy var context: NSManagedObjectContext = {
        let ctx = container.newBackgroundContext()
        ctx.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        ctx.automaticallyMergesChangesFromParent = true
        return ctx
    }()

    private var remoteChangeWorkItem: DispatchWorkItem?
    private var started = false

    private init(container: NSPersistentCloudKitContainer = PersistenceController.shared.container) {
        self.container = container
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Lifecycle

    /// Call once at app launch. Safe to call multiple times.
    func start() {
        guard !started else { return }
        started = true

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRemoteChange),
            name: .NSPersistentStoreRemoteChange,
            object: container.persistentStoreCoordinator
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )

        // Initial pass shortly after launch, once the persistent stores have
        // had a moment to load (store loading is asynchronous).
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.syncCounters()
            self?.notifyDataChanged()
        }
    }

    @objc private func handleDidBecomeActive() {
        syncCounters()
    }

    @objc private func handleRemoteChange(_ notification: Notification) {
        // Remote-change notifications arrive in bursts during an import —
        // debounce so we dedup/notify once per burst, keeping sync smooth.
        remoteChangeWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.dedupDuplicateEvents()
            self.syncCounters()
            self.notifyDataChanged()
        }
        remoteChangeWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
    }

    // MARK: - Recording events

    /// Insert an event if no row with (kind, key) exists yet. If a row exists
    /// and `payload` is non-nil and different, the payload is refreshed.
    func recordEvent(kind: String, key: String, payload: Data? = nil) {
        recordEvents(kind: kind, items: [(key: key, payload: payload)])
    }

    /// Batch upsert. Existing (kind, key) rows are left in place (payload
    /// refreshed when it changed); missing rows are inserted. Never deletes.
    func recordEvents(kind: String, items: [(key: String, payload: Data?)]) {
        guard !items.isEmpty else { return }
        let device = Self.deviceId
        context.perform { [weak self] in
            guard let self = self else { return }
            do {
                let request = ProgressEventEntry.fetchRequest()
                request.predicate = NSPredicate(format: "kind == %@", kind)
                let existing = try self.context.fetch(request)
                var byKey: [String: ProgressEventEntry] = [:]
                for row in existing { byKey[row.key] = row }

                var changed = false
                for item in items {
                    if let row = byKey[item.key] {
                        if let payload = item.payload, row.payload != payload {
                            row.payload = payload
                            row.lastModified = Date()
                            changed = true
                        }
                    } else {
                        let row = ProgressEventEntry(context: self.context)
                        row.id = UUID()
                        row.kind = kind
                        row.key = item.key
                        row.payload = item.payload
                        row.deviceId = device
                        row.createdAt = Date()
                        row.lastModified = Date()
                        byKey[item.key] = row
                        changed = true
                    }
                }

                if changed {
                    try self.context.save()
                    self.requestExport()
                }
            } catch {
                print("ProgressSyncStore: recordEvents(\(kind)) failed - \(error.localizedDescription)")
            }
        }
    }

    /// Remove the event row for (kind, key) — e.g. the user manually
    /// un-marked an audio as played. The delete syncs to other devices.
    func deleteEvent(kind: String, key: String) {
        context.perform { [weak self] in
            guard let self = self else { return }
            do {
                let request = ProgressEventEntry.fetchRequest()
                request.predicate = NSPredicate(format: "kind == %@ AND key == %@", kind, key)
                let rows = try self.context.fetch(request)
                guard !rows.isEmpty else { return }
                rows.forEach(self.context.delete)
                try self.context.save()
                self.requestExport()
            } catch {
                print("ProgressSyncStore: deleteEvent(\(kind), \(key)) failed - \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Reading events

    struct Event {
        let key: String
        let payload: Data?
        let createdAt: Date
    }

    /// Synchronously fetch all events of a kind (deduped by key, keeping the
    /// earliest row). Safe to call from any thread.
    func events(ofKind kind: String) -> [Event] {
        var result: [Event] = []
        context.performAndWait {
            do {
                let request = ProgressEventEntry.fetchRequest()
                request.predicate = NSPredicate(format: "kind == %@", kind)
                request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
                let rows = try context.fetch(request)
                var seen = Set<String>()
                for row in rows {
                    guard !seen.contains(row.key) else { continue }
                    seen.insert(row.key)
                    result.append(Event(key: row.key,
                                        payload: row.payload,
                                        createdAt: row.createdAt ?? Date(timeIntervalSince1970: 0)))
                }
            } catch {
                print("ProgressSyncStore: events(ofKind: \(kind)) failed - \(error.localizedDescription)")
            }
        }
        return result
    }

    // MARK: - Lifetime counter sync

    /// Reconciles the whitelisted UserDefaults counters with per-device rows.
    ///
    /// For each counter: this device's contribution is the local displayed
    /// value minus the other-device sum applied at the last reconcile, so
    /// local increments keep working untouched (views keep incrementing the
    /// plain UserDefaults key). The displayed value never decreases.
    func syncCounters() {
        let device = Self.deviceId
        context.perform { [weak self] in
            guard let self = self else { return }
            do {
                let request = ProgressEventEntry.fetchRequest()
                request.predicate = NSPredicate(format: "kind == %@", Kind.counter)
                let rows = try self.context.fetch(request)

                var changed = false
                let defaults = UserDefaults.standard

                for counterKey in Self.syncedCounterKeys {
                    let display = defaults.integer(forKey: counterKey)
                    let othersAppliedKey = "sl_counterOthersSum_\(counterKey)"
                    let lastOthersSum = defaults.integer(forKey: othersAppliedKey)
                    let ownContribution = max(0, display - lastOthersSum)

                    let ownRowKey = "\(counterKey)|\(device)"
                    var othersSum = 0
                    var ownRow: ProgressEventEntry?
                    var seenOtherDevices = Set<String>()
                    for row in rows where row.key.hasPrefix("\(counterKey)|") {
                        if row.key == ownRowKey {
                            // Duplicated own rows are unified by the dedup pass;
                            // any one of them is fine to update here.
                            if ownRow == nil { ownRow = row }
                        } else if !seenOtherDevices.contains(row.key) {
                            seenOtherDevices.insert(row.key)
                            othersSum += Self.counterValue(from: row.payload)
                        }
                    }

                    // Push this device's contribution (create or refresh row).
                    let payload = Self.counterPayload(ownContribution)
                    if let row = ownRow {
                        if Self.counterValue(from: row.payload) != ownContribution {
                            row.payload = payload
                            row.lastModified = Date()
                            changed = true
                        }
                    } else if ownContribution > 0 {
                        let row = ProgressEventEntry(context: self.context)
                        row.id = UUID()
                        row.kind = Kind.counter
                        row.key = ownRowKey
                        row.payload = payload
                        row.deviceId = device
                        row.createdAt = Date()
                        row.lastModified = Date()
                        changed = true
                    }

                    // Apply the merged total locally — never below what the
                    // user already sees on this device.
                    let mergedDisplay = max(display, ownContribution + othersSum)
                    DispatchQueue.main.async {
                        if defaults.integer(forKey: counterKey) < mergedDisplay {
                            defaults.set(mergedDisplay, forKey: counterKey)
                        }
                        if defaults.integer(forKey: othersAppliedKey) != othersSum {
                            defaults.set(othersSum, forKey: othersAppliedKey)
                        }
                    }
                }

                if changed {
                    try self.context.save()
                    self.requestExport()
                }
            } catch {
                print("ProgressSyncStore: syncCounters failed - \(error.localizedDescription)")
            }
        }
    }

    private static func counterPayload(_ value: Int) -> Data? {
        try? JSONSerialization.data(withJSONObject: ["v": value])
    }

    private static func counterValue(from payload: Data?) -> Int {
        guard let payload = payload,
              let object = try? JSONSerialization.jsonObject(with: payload) as? [String: Any],
              let value = object["v"] as? Int else { return 0 }
        return value
    }

    // MARK: - Dedup (CloudKit cannot enforce uniqueness)

    /// Collapses duplicate (kind, key) rows created concurrently on multiple
    /// devices. Deterministic on every device: the survivor is the row with
    /// the earliest createdAt (id string as tie-break) and it inherits the
    /// most recently modified payload, so no data is lost.
    private func dedupDuplicateEvents() {
        context.perform { [weak self] in
            guard let self = self else { return }
            do {
                let request = ProgressEventEntry.fetchRequest()
                let rows = try self.context.fetch(request)
                var groups: [String: [ProgressEventEntry]] = [:]
                for row in rows {
                    groups["\(row.kind)|\(row.key)", default: []].append(row)
                }

                var changed = false
                for (_, group) in groups where group.count > 1 {
                    let sorted = group.sorted { a, b in
                        let aDate = a.createdAt ?? Date(timeIntervalSince1970: 0)
                        let bDate = b.createdAt ?? Date(timeIntervalSince1970: 0)
                        if aDate != bDate { return aDate < bDate }
                        return (a.id?.uuidString ?? "") < (b.id?.uuidString ?? "")
                    }
                    let survivor = sorted[0]
                    let newestPayloadRow = group.max { a, b in
                        (a.lastModified ?? .distantPast) < (b.lastModified ?? .distantPast)
                    }
                    if let newest = newestPayloadRow,
                       newest !== survivor,
                       let payload = newest.payload,
                       survivor.payload != payload {
                        survivor.payload = payload
                        survivor.lastModified = newest.lastModified
                    }
                    sorted.dropFirst().forEach(self.context.delete)
                    changed = true
                }

                if changed {
                    try self.context.save()
                    self.requestExport()
                }
            } catch {
                print("ProgressSyncStore: dedup failed - \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Helpers

    private func notifyDataChanged() {
        context.perform { [weak self] in
            guard let self = self else { return }
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: "ProgressEventEntry")
            request.propertiesToFetch = ["kind"]
            request.returnsDistinctResults = true
            request.resultType = .dictionaryResultType
            let kinds: Set<String>
            if let dictionaries = (try? self.context.fetch(request)) as? [[String: Any]] {
                kinds = Set(dictionaries.compactMap { $0["kind"] as? String })
            } else {
                kinds = []
            }
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: Self.dataDidChange,
                    object: nil,
                    userInfo: ["kinds": kinds]
                )
            }
        }
    }

    /// Nudge NSPersistentCloudKitContainer to export promptly so changes made
    /// here show up on other devices fast.
    private func requestExport() {
        DispatchQueue.main.async {
            PersistenceController.shared.save()
        }
    }
}
