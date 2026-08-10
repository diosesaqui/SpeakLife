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
//  Threading model: all mutable coordination state (debounce work items,
//  in-flight flags) is confined to the MAIN queue — notification handlers
//  hop there first, because Core Data and UserDefaults notifications arrive
//  on arbitrary posting threads. Core Data work runs on one serial
//  background context created eagerly in init.
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
        static let taskCompletion = "taskCompletion" // key = "<dayStamp>|<taskId>" (bonus checklist tasks)

        static let all: Set<String> = [dayCompletion, listenedAudio, counter, taskCompletion]
    }

    /// Posted on the main queue after remote CloudKit changes have been
    /// merged and deduped. userInfo["kinds"] is always Kind.all — the store
    /// cannot cheaply know which kinds changed (a deletion can empty a kind
    /// entirely), so observers must refresh and decide for themselves.
    static let dataDidChange = Notification.Name("ProgressSyncStoreDataDidChange")

    // MARK: - Device identity

    private static let deviceIdKey = "sl_syncDeviceId"
    private static let deviceIdVendorKey = "sl_syncDeviceIdVendor"

    /// Stable per-device identifier for per-device counter rows.
    ///
    /// UserDefaults is restored onto new phones by iCloud/device-to-device
    /// migration, which would make two live devices share one id and fight
    /// over the same counter row. identifierForVendor is NOT carried over by
    /// restore, so we pin the stored id to it and mint a fresh id when the
    /// vendor id changes (the old row simply becomes another device's
    /// contribution — nothing is lost).
    static var deviceId: String {
        let defaults = UserDefaults.standard
        let currentVendor = UIDevice.current.identifierForVendor?.uuidString

        if let existing = defaults.string(forKey: deviceIdKey) {
            let storedVendor = defaults.string(forKey: deviceIdVendorKey)
            if storedVendor == currentVendor || currentVendor == nil {
                return existing
            }
        }

        let fresh = UUID().uuidString
        defaults.set(fresh, forKey: deviceIdKey)
        if let currentVendor = currentVendor {
            defaults.set(currentVendor, forKey: deviceIdVendorKey)
        }
        return fresh
    }

    // MARK: - Lifetime counters synced across devices

    /// UserDefaults counter keys mirrored as per-device contribution rows.
    static let syncedCounterKeys = [
        "totalAffirmationsSpoken",
        "totalVersesRead",
        "totalSocialShares",
        "totalFavoritesAdded",
        // Guarding: ground taken. Belongs here rather than in its own store
        // precisely because this machinery is append-only and monotonic by
        // construction — there is no code path that can lower it, which is the
        // one guarantee that feature makes about its only number.
        GroundTaken.counterKey
    ]

    // MARK: - Private state

    private let container: NSPersistentCloudKitContainer
    private let context: NSManagedObjectContext

    // Main-queue-confined coordination state.
    private var remoteChangeWorkItem: DispatchWorkItem?
    private var counterSyncInFlight = false
    private var started = false

    private init(container: NSPersistentCloudKitContainer = PersistenceController.shared.container) {
        self.container = container
        let ctx = container.newBackgroundContext()
        ctx.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        ctx.automaticallyMergesChangesFromParent = true
        self.context = ctx
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
            self?.pruneStaleTaskCompletions()
            self?.syncCounters()
            self?.notifyDataChanged()
        }
    }

    @objc private func handleDidBecomeActive() {
        syncCounters()
    }

    @objc private func handleRemoteChange(_ notification: Notification) {
        // NSPersistentStoreRemoteChange arrives on Core Data's posting
        // thread, in bursts during an import. Hop to main so the debounce
        // state has a single home, and coalesce the burst into one pass.
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.remoteChangeWorkItem?.cancel()
            let work = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                self.dedupDuplicateEvents { [weak self] in
                    self?.syncCounters()
                    self?.notifyDataChanged()
                }
            }
            self.remoteChangeWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
        }
    }

    // MARK: - Recording events

    /// Insert an event if no row with (kind, key) exists yet. If a row exists
    /// and `payload` is non-nil and different, the payload is refreshed.
    /// `completion` is called on the main queue with whether the write
    /// definitely persisted — callers gating one-time migrations MUST only
    /// mark them done on success.
    func recordEvent(kind: String, key: String, payload: Data? = nil, completion: ((Bool) -> Void)? = nil) {
        recordEvents(kind: kind, items: [(key: key, payload: payload)], completion: completion)
    }

    /// Batch upsert. Existing (kind, key) rows are left in place (payload
    /// refreshed when it changed); missing rows are inserted. Never deletes.
    func recordEvents(kind: String, items: [(key: String, payload: Data?)], completion: ((Bool) -> Void)? = nil) {
        guard !items.isEmpty else {
            DispatchQueue.main.async { completion?(true) }
            return
        }
        let device = Self.deviceId
        context.perform { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion?(false) }
                return
            }
            var succeeded = false
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
                }
                succeeded = true
            } catch {
                print("ProgressSyncStore: recordEvents(\(kind)) failed - \(error.localizedDescription)")
            }
            let result = succeeded
            DispatchQueue.main.async { completion?(result) }
        }
    }

    /// Remove the event row for (kind, key) — e.g. the user manually
    /// un-marked an audio as played. The delete syncs to other devices.
    func deleteEvent(kind: String, key: String, completion: ((Bool) -> Void)? = nil) {
        context.perform { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion?(false) }
                return
            }
            var succeeded = false
            do {
                let request = ProgressEventEntry.fetchRequest()
                request.predicate = NSPredicate(format: "kind == %@ AND key == %@", kind, key)
                let rows = try self.context.fetch(request)
                if !rows.isEmpty {
                    rows.forEach(self.context.delete)
                    try self.context.save()
                }
                succeeded = true
            } catch {
                print("ProgressSyncStore: deleteEvent(\(kind), \(key)) failed - \(error.localizedDescription)")
            }
            let result = succeeded
            DispatchQueue.main.async { completion?(result) }
        }
    }

    // MARK: - Reading events

    struct Event {
        let key: String
        let payload: Data?
        let createdAt: Date
    }

    /// Asynchronously fetch all events of a kind (deduped by key, keeping the
    /// earliest row). `completion` runs on the main queue. Asynchronous by
    /// design: a synchronous performAndWait here would block the caller
    /// behind whatever import/dedup work the sync context is doing.
    func events(ofKind kind: String, completion: @escaping ([Event]) -> Void) {
        context.perform { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion([]) }
                return
            }
            var result: [Event] = []
            do {
                let request = ProgressEventEntry.fetchRequest()
                request.predicate = NSPredicate(format: "kind == %@", kind)
                request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
                let rows = try self.context.fetch(request)
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
            let events = result
            DispatchQueue.main.async { completion(events) }
        }
    }

    // MARK: - Lifetime counter sync

    /// Reconciles the whitelisted UserDefaults counters with per-device rows.
    ///
    /// The math is a strict three-phase pipeline so the UserDefaults
    /// read-modify-write happens atomically on the main queue (where the UI
    /// increments the counters) and can never swallow an increment:
    ///   1. background: snapshot the per-device rows into plain values
    ///   2. main: read + compute + write the defaults in one synchronous step
    ///   3. background: push this device's contribution rows
    /// Bookkeeping is monotonic — the displayed total and the applied
    /// other-device sum never decrease, so temporarily missing rows (store
    /// still loading, import incomplete) can't corrupt the contribution math.
    func syncCounters() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, !self.counterSyncInFlight else { return }
            self.counterSyncInFlight = true

            let device = Self.deviceId
            // Phase 1 (background): snapshot rows as plain values.
            self.context.perform { [weak self] in
                guard let self = self else { return }
                var othersSumByCounter: [String: Int] = [:]
                var ownValueByCounter: [String: Int] = [:]
                do {
                    let request = ProgressEventEntry.fetchRequest()
                    request.predicate = NSPredicate(format: "kind == %@", Kind.counter)
                    let rows = try self.context.fetch(request)
                    for counterKey in Self.syncedCounterKeys {
                        let prefix = "\(counterKey)|"
                        let ownRowKey = "\(counterKey)|\(device)"
                        var othersSum = 0
                        var seenKeys = Set<String>()
                        for row in rows where row.key.hasPrefix(prefix) {
                            guard !seenKeys.contains(row.key) else { continue }
                            seenKeys.insert(row.key)
                            let value = Self.counterValue(from: row.payload)
                            if row.key == ownRowKey {
                                ownValueByCounter[counterKey] = value
                            } else {
                                othersSum += value
                            }
                        }
                        othersSumByCounter[counterKey] = othersSum
                    }
                } catch {
                    print("ProgressSyncStore: counter snapshot failed - \(error.localizedDescription)")
                    DispatchQueue.main.async { self.counterSyncInFlight = false }
                    return
                }

                // Phase 2 (main): atomic read-compute-write of the defaults.
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    let defaults = UserDefaults.standard
                    var desiredOwnValues: [String: Int] = [:]

                    for counterKey in Self.syncedCounterKeys {
                        let othersAppliedKey = "sl_counterOthersSum_\(counterKey)"
                        let display = defaults.integer(forKey: counterKey)
                        let appliedBefore = defaults.integer(forKey: othersAppliedKey)
                        // Monotonic: never trust a SMALLER other-device sum —
                        // rows can be temporarily invisible mid-import, and
                        // lowering the baseline would reclassify other
                        // devices' work as our own (permanent double count).
                        let othersSum = max(othersSumByCounter[counterKey] ?? 0, appliedBefore)

                        let ownContribution = max(0, display - othersSum)
                        let mergedDisplay = max(display, ownContribution + othersSum)

                        if mergedDisplay > display {
                            defaults.set(mergedDisplay, forKey: counterKey)
                        }
                        if othersSum > appliedBefore {
                            defaults.set(othersSum, forKey: othersAppliedKey)
                        }
                        desiredOwnValues[counterKey] = ownContribution
                    }

                    // Phase 3 (background): push contribution rows (monotonic).
                    self.context.perform { [weak self] in
                        guard let self = self else { return }
                        defer { DispatchQueue.main.async { self.counterSyncInFlight = false } }
                        do {
                            let request = ProgressEventEntry.fetchRequest()
                            request.predicate = NSPredicate(format: "kind == %@", Kind.counter)
                            let rows = try self.context.fetch(request)
                            var changed = false

                            for counterKey in Self.syncedCounterKeys {
                                let desired = desiredOwnValues[counterKey] ?? 0
                                guard desired > 0 else { continue }
                                let ownRowKey = "\(counterKey)|\(device)"
                                let ownRows = rows.filter { $0.key == ownRowKey }

                                if let row = ownRows.first {
                                    // Counters only grow — never lower the row.
                                    if desired > Self.counterValue(from: row.payload) {
                                        row.payload = Self.counterPayload(desired)
                                        row.lastModified = Date()
                                        changed = true
                                    }
                                } else {
                                    let row = ProgressEventEntry(context: self.context)
                                    row.id = UUID()
                                    row.kind = Kind.counter
                                    row.key = ownRowKey
                                    row.payload = Self.counterPayload(desired)
                                    row.deviceId = device
                                    row.createdAt = Date()
                                    row.lastModified = Date()
                                    changed = true
                                }
                            }

                            if changed {
                                try self.context.save()
                            }
                        } catch {
                            print("ProgressSyncStore: counter push failed - \(error.localizedDescription)")
                        }
                    }
                }
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

    // MARK: - Pruning

    /// taskCompletion rows only matter for the current day (the checklist
    /// regenerates daily); dayCompletion rows are the permanent streak
    /// history and are NEVER pruned. Rows older than this are deleted so the
    /// table doesn't grow forever (~4 rows/day), and the deletes sync.
    private static let taskCompletionRetentionDays = 30

    private func pruneStaleTaskCompletions() {
        guard let cutoffDate = Calendar.current.date(
            byAdding: .day,
            value: -Self.taskCompletionRetentionDays,
            to: Date()
        ) else { return }
        // Keys are "yyyy-MM-dd|taskId", so a lexicographic compare against
        // the cutoff day stamp selects exactly the older days ("…-20|x" <
        // "…-21", while same-day keys sort above the bare stamp and survive).
        let cutoffStamp = BurstCompletionTracker.dayStamp(for: cutoffDate)
        context.perform { [weak self] in
            guard let self = self else { return }
            do {
                let request = ProgressEventEntry.fetchRequest()
                request.predicate = NSPredicate(format: "kind == %@ AND key < %@",
                                                Kind.taskCompletion, cutoffStamp)
                let stale = try self.context.fetch(request)
                guard !stale.isEmpty else { return }
                stale.forEach(self.context.delete)
                try self.context.save()
                #if DEBUG
                print("ProgressSyncStore: pruned \(stale.count) stale taskCompletion row(s)")
                #endif
            } catch {
                print("ProgressSyncStore: prune failed - \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Dedup (CloudKit cannot enforce uniqueness)

    /// Collapses duplicate (kind, key) rows created concurrently on multiple
    /// devices. Deterministic on every device: the survivor is the row with
    /// the earliest createdAt (id string as tie-break). The survivor inherits
    /// the "best" payload so no data is lost: for counter rows that's the
    /// LARGEST value (counters only grow); for everything else the most
    /// recently modified payload.
    private func dedupDuplicateEvents(completion: @escaping () -> Void) {
        context.perform { [weak self] in
            defer { DispatchQueue.main.async { completion() } }
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

                    if survivor.kind == Kind.counter {
                        let maxValue = group.map { Self.counterValue(from: $0.payload) }.max() ?? 0
                        if Self.counterValue(from: survivor.payload) < maxValue {
                            survivor.payload = Self.counterPayload(maxValue)
                            survivor.lastModified = Date()
                        }
                    } else if let newest = group.max(by: { (a, b) in
                        (a.lastModified ?? .distantPast) < (b.lastModified ?? .distantPast)
                    }), newest !== survivor,
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
                }
            } catch {
                print("ProgressSyncStore: dedup failed - \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Helpers

    private func notifyDataChanged() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: Self.dataDidChange,
                object: nil,
                userInfo: ["kinds": Kind.all]
            )
        }
    }
}
