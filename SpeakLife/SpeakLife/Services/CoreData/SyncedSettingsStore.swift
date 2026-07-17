//
//  SyncedSettingsStore.swift
//  SpeakLife
//
//  Mirrors a whitelist of UserDefaults keys across the user's devices via
//  the existing Core Data + CloudKit stack (SyncedSetting entity, private
//  iCloud database).
//
//  Call sites keep reading and writing UserDefaults/@AppStorage exactly as
//  they do today — this store watches UserDefaults for changes to the
//  whitelisted keys and reconciles them with CloudKit in the background.
//  Applying a remote value writes UserDefaults, which @AppStorage picks up
//  automatically, so remote changes flow into live UI with no view changes.
//
//  Conflict handling is chosen per key so nothing is ever lost:
//  - lastWriterWins: plain preferences (name, theme, reminder times, ...)
//  - maxInt / boolOr: monotonic progress scalars and one-way flags
//  - custom mergers: progress-bearing blobs (streak stats, badges, read
//    devotionals, Bible annotations) merge as unions, never overwrite
//
//  Data-safety mechanics:
//  - A three-way merge base (the value at last reconcile) is kept per key so
//    the store knows WHICH side actually changed instead of guessing.
//  - A fresh install does not push its local defaults until the first
//    CloudKit import has settled, so a brand-new device can never overwrite
//    the user's real settings with blank defaults.
//  - Duplicate rows (CloudKit cannot enforce uniqueness) are merged, not
//    just discarded, before the loser row is deleted.
//  - Blob values are compared semantically (decoded), never by raw bytes —
//    two devices encoding the same logical value differently must not
//    ping-pong pushes forever.
//  - Applying a remote value re-checks, on the main queue, that the local
//    value hasn't changed since the reconcile pass read it; a user edit in
//    that window wins and is pushed on the next pass.
//
//  Threading: all coordination state is main-queue-confined (UserDefaults
//  and Core Data notifications arrive on arbitrary threads and hop to main
//  first). Core Data work runs on one serial background context.
//

import Foundation
import CoreData
import UIKit

final class SyncedSettingsStore {

    static let shared = SyncedSettingsStore()

    /// Posted on the main queue after remote values have been applied to
    /// UserDefaults. userInfo["keys"] is the Set<String> of applied keys.
    static let settingsDidChange = Notification.Name("SyncedSettingsStoreDidChange")

    // MARK: - Merge strategies

    private enum MergeStrategy {
        /// Newer side wins. Ties (both changed since last reconcile) keep the
        /// local value on an established device and prefer the synced value
        /// on a fresh install, so a new phone restores the user's settings.
        case lastWriterWins
        /// Progress counters that only move forward.
        case maxInt
        /// One-way flags (once true anywhere, true everywhere).
        case boolOr
        /// Lossless union for progress-bearing blobs.
        case custom((Any, Any) -> Any)
    }

    private struct SyncedKey {
        let key: String
        let strategy: MergeStrategy
        /// Semantic comparison for values whose encodings are nondeterministic
        /// (JSON blobs, order-insensitive collections). nil = plist equality.
        var equivalence: ((Any, Any) -> Bool)? = nil
    }

    // MARK: - The whitelist

    private static let whitelist: [SyncedKey] = [
        // Streak stats blob: recency-aware merge (see StreakStats.merging).
        SyncedKey(key: "streakStats",
                  strategy: .custom(mergeStreakStats),
                  equivalence: streakStatsEquivalent),

        // Progress-bearing blobs — union merges, nothing ever dropped.
        SyncedKey(key: "UnlockedBadges",
                  strategy: .custom(mergeJSONArrayData(idField: "title")),
                  equivalence: jsonArrayDataEquivalent(idField: "title")),
        SyncedKey(key: "BibleBookmarks",
                  strategy: .custom(mergeJSONArrayData(idField: "id")),
                  equivalence: jsonArrayDataEquivalent(idField: "id")),
        SyncedKey(key: "BibleHighlights",
                  strategy: .custom(mergeJSONArrayData(idField: "id")),
                  equivalence: jsonArrayDataEquivalent(idField: "id")),
        SyncedKey(key: "devotionalDictionary",
                  strategy: .custom(mergeDevotionalDictionary),
                  equivalence: devotionalDictionaryEquivalent),
        SyncedKey(key: "completedQuizTitlesRaw",
                  strategy: .custom(mergeJSONStringArrayString),
                  equivalence: jsonStringArraySetEquivalent),
        SyncedKey(key: "warriorRoomUserReactions",
                  strategy: .custom(mergeStringDictionary)),
        SyncedKey(key: "warriorRoomUserAgreements",
                  strategy: .custom(mergeStringArray),
                  equivalence: stringArraySetEquivalent),

        // Monotonic progress scalars.
        SyncedKey(key: "abbasLoveLetterIndex", strategy: .maxInt),
        SyncedKey(key: "personalDeclaration_completedDayCount", strategy: .maxInt),

        // One-way flags.
        SyncedKey(key: "onboarded", strategy: .boolOr),
        SyncedKey(key: "hasCompletedEnhancedOnboarding", strategy: .boolOr),
        SyncedKey(key: "hasPersonalDeclaration", strategy: .boolOr),

        // Identity & personalization.
        SyncedKey(key: "userName", strategy: .lastWriterWins),
        SyncedKey(key: "surveyGoalWord", strategy: .lastWriterWins),
        SyncedKey(key: "firstSelection", strategy: .lastWriterWins),
        SyncedKey(key: "onboarding_segment", strategy: .lastWriterWins),
        SyncedKey(key: "onboarding_quiz_version", strategy: .lastWriterWins),
        SyncedKey(key: "onboarding_completed_at", strategy: .lastWriterWins),
        SyncedKey(key: "selectedDeclarationStyles", strategy: .lastWriterWins),
        SyncedKey(key: "userSelectedCategories", strategy: .lastWriterWins),
        SyncedKey(key: "lastCategorySelected", strategy: .lastWriterWins),
        SyncedKey(key: "userTopCategories", strategy: .lastWriterWins),
        SyncedKey(key: "foundationAudioDayAssignments", strategy: .lastWriterWins),

        // Personal declaration.
        SyncedKey(key: "personal_declaration_v1", strategy: .lastWriterWins),
        SyncedKey(key: "personalDeclaration_lastSpokenDate", strategy: .lastWriterWins),

        // Appearance & experience preferences.
        SyncedKey(key: "theme", strategy: .lastWriterWins),
        SyncedKey(key: "fontString", strategy: .lastWriterWins),
        SyncedKey(key: "backgroundMusicEnabled", strategy: .lastWriterWins),
        SyncedKey(key: "useAnimatedText", strategy: .lastWriterWins),
        SyncedKey(key: "animationSpeed", strategy: .lastWriterWins),
        SyncedKey(key: "autoStartAnimation", strategy: .lastWriterWins),
        SyncedKey(key: "highlightPowerWords", strategy: .lastWriterWins),
        SyncedKey(key: "showAnimationProgress", strategy: .lastWriterWins),
        SyncedKey(key: "hapticsEnabled", strategy: .lastWriterWins),
        SyncedKey(key: "audioDelightsEnabled", strategy: .lastWriterWins),
        SyncedKey(key: "warriorRoomIsSister", strategy: .lastWriterWins),

        // Bible reading.
        SyncedKey(key: "SelectedBibleVersion", strategy: .lastWriterWins),
        SyncedKey(key: "BibleLastRead", strategy: .lastWriterWins),
        SyncedKey(key: "BibleReaderFontSize", strategy: .lastWriterWins),
        SyncedKey(key: "BibleReaderFont", strategy: .lastWriterWins),
        SyncedKey(key: "BibleLineSpacing", strategy: .lastWriterWins),
        SyncedKey(key: "BibleShowVerseNumbers", strategy: .lastWriterWins),

        // Reminder preferences (times/counts — never the OS permission,
        // which is inherently per-device).
        SyncedKey(key: "notificationCount", strategy: .lastWriterWins),
        SyncedKey(key: "startTimeNotification", strategy: .lastWriterWins),
        SyncedKey(key: "endTimeNotification", strategy: .lastWriterWins),
        SyncedKey(key: "startTimeIndex", strategy: .lastWriterWins),
        SyncedKey(key: "endTimeIndex", strategy: .lastWriterWins),
        SyncedKey(key: "selectedNotificationCategories", strategy: .lastWriterWins),
        SyncedKey(key: "personalDeclarationTimeIndex", strategy: .lastWriterWins),
        SyncedKey(key: "morningReminderEnabled", strategy: .lastWriterWins),
        SyncedKey(key: "morningReminderHour", strategy: .lastWriterWins),
        SyncedKey(key: "morningReminderMinute", strategy: .lastWriterWins),
        SyncedKey(key: "eveningCheckInEnabled", strategy: .lastWriterWins),
        SyncedKey(key: "eveningCheckInHour", strategy: .lastWriterWins),
        SyncedKey(key: "eveningCheckInMinute", strategy: .lastWriterWins),
        SyncedKey(key: "checklistNotificationsEnabled", strategy: .lastWriterWins),
        SyncedKey(key: "dailyDeclarationRemindersEnabled", strategy: .lastWriterWins)
    ]

    // MARK: - Bookkeeping keys

    private static let baseKey = "sl_syncedSettingsBase"           // [String: Data] value at last reconcile
    private static let stampsKey = "sl_syncedSettingsStamps"       // [String: Double] remote lastModified at last reconcile
    private static let initializedKey = "sl_settingsSyncInitialized"

    // MARK: - Private state

    private let container: NSPersistentCloudKitContainer
    private let context: NSManagedObjectContext

    // Main-queue-confined coordination state.
    private var localChangeWorkItem: DispatchWorkItem?
    private var remoteChangeWorkItem: DispatchWorkItem?
    private var reconcileInFlight = false
    private var reconcileQueued: Trigger?
    private var lastLocalDigest: [String: Data]?
    private var importSettled: Bool
    private var started = false
    /// Captured once: a fresh install prefers the synced (restored) value
    /// when both sides differ and no merge base exists yet.
    private let isFreshInstall: Bool

    private enum Trigger {
        case local      // a UserDefaults write (may be a no-op echo)
        case remote     // CloudKit delivered changes
        case lifecycle  // launch / didBecomeActive
    }

    private init(container: NSPersistentCloudKitContainer = PersistenceController.shared.container) {
        self.container = container
        let ctx = container.newBackgroundContext()
        ctx.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        ctx.automaticallyMergesChangesFromParent = true
        self.context = ctx

        let defaults = UserDefaults.standard
        if defaults.object(forKey: Self.initializedKey) == nil {
            // Established devices have local history (a streak blob or the
            // onboarding flag); a truly fresh install has neither.
            let hasHistory = defaults.bool(forKey: "hasLaunchedBefore")
                || defaults.object(forKey: "streakStats") != nil
                || defaults.bool(forKey: "onboarded")
            self.isFreshInstall = !hasHistory
        } else {
            self.isFreshInstall = false
        }
        // Established devices may push immediately — their local values ARE
        // the user's data. A fresh install must wait for the first import.
        self.importSettled = !isFreshInstall
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
            selector: #selector(handleLocalDefaultsChange),
            name: UserDefaults.didChangeNotification,
            object: UserDefaults.standard
        )

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

        // The fresh-install push gate opens when the first CloudKit import
        // settles (PersistenceController posts these) — or after a generous
        // timeout so a device with no network ever still starts syncing.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleImportSettled),
            name: NSNotification.Name("CloudKitImportCompleted"),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleImportSettled),
            name: NSNotification.Name("CloudKitImportFailed"),
            object: nil
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + 120.0) { [weak self] in
            self?.settleImport()
        }

        // First pass shortly after launch (store loading is asynchronous).
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.scheduleReconcile(.lifecycle)
        }
    }

    @objc private func handleDidBecomeActive() {
        DispatchQueue.main.async { [weak self] in
            self?.scheduleReconcile(.lifecycle)
        }
    }

    @objc private func handleImportSettled() {
        DispatchQueue.main.async { [weak self] in
            self?.settleImport()
        }
    }

    private func settleImport() {
        guard !importSettled else { return }
        importSettled = true
        scheduleReconcile(.lifecycle)
    }

    @objc private func handleLocalDefaultsChange() {
        // Delivered synchronously on whatever thread wrote the default —
        // hop to main before touching any coordination state.
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.localChangeWorkItem?.cancel()
            let work = DispatchWorkItem { [weak self] in self?.scheduleReconcile(.local) }
            self.localChangeWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: work)
        }
    }

    @objc private func handleRemoteChange(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.remoteChangeWorkItem?.cancel()
            let work = DispatchWorkItem { [weak self] in self?.scheduleReconcile(.remote) }
            self.remoteChangeWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
        }
    }

    /// Public entry — safe to call from any thread.
    func reconcile() {
        DispatchQueue.main.async { [weak self] in
            self?.scheduleReconcile(.lifecycle)
        }
    }

    // MARK: - Reconcile scheduling (main queue)

    private func scheduleReconcile(_ trigger: Trigger) {
        // Local-change echoes are by far the most common trigger (every
        // UserDefaults write in the app fires the notification). Skip the
        // whole pass when no whitelisted value actually changed.
        if trigger == .local, let last = lastLocalDigest, Self.computeLocalDigest() == last {
            return
        }
        if reconcileInFlight {
            // Coalesce: remember the strongest queued trigger and run once
            // the current pass finishes.
            if reconcileQueued == nil || trigger != .local {
                reconcileQueued = trigger
            }
            return
        }
        reconcileInFlight = true
        performReconcile()
    }

    private func finishReconcile() {
        reconcileInFlight = false
        if let queued = reconcileQueued {
            reconcileQueued = nil
            scheduleReconcile(queued)
        }
    }

    // MARK: - Reconcile

    private func performReconcile() {
        let freshInstall = isFreshInstall
        let mayPushLocalOnly = importSettled
        let device = ProgressSyncStore.deviceId

        context.perform { [weak self] in
            guard let self = self else { return }
            do {
                let defaults = UserDefaults.standard
                var base = (defaults.dictionary(forKey: Self.baseKey) as? [String: Data]) ?? [:]
                var stamps = (defaults.dictionary(forKey: Self.stampsKey) as? [String: Double]) ?? [:]

                let request = SyncedSetting.fetchRequest()
                let allRows = try self.context.fetch(request)
                var rowsByKey: [String: SyncedSetting] = [:]
                var rowsChanged = false

                // Dedup rows per key (CloudKit cannot enforce uniqueness).
                // Deterministic survivor: newest lastModified, id tie-break.
                // The survivor absorbs a MERGE of every duplicate's value
                // first, so a concurrent push from another device can never
                // destroy data by merely being older.
                var grouped: [String: [SyncedSetting]] = [:]
                for row in allRows { grouped[row.key, default: []].append(row) }
                for (key, group) in grouped {
                    let sorted = group.sorted { a, b in
                        let aDate = a.lastModified ?? .distantPast
                        let bDate = b.lastModified ?? .distantPast
                        if aDate != bDate { return aDate > bDate }
                        return (a.id?.uuidString ?? "") > (b.id?.uuidString ?? "")
                    }
                    let survivor = sorted[0]
                    if sorted.count > 1 {
                        if let entry = Self.whitelistByKey[key] {
                            var accumulated = survivor.value.flatMap(Self.decodeValue)
                            for loser in sorted.dropFirst() {
                                guard let loserValue = loser.value.flatMap(Self.decodeValue) else { continue }
                                if let current = accumulated {
                                    accumulated = Self.mergeValues(entry.strategy, current, loserValue)
                                } else {
                                    accumulated = loserValue
                                }
                            }
                            if let merged = accumulated,
                               let encoded = Self.encodeValue(merged),
                               survivor.value != encoded,
                               !(Self.equivalent(entry, survivor.value.flatMap(Self.decodeValue), merged)) {
                                survivor.value = encoded
                                survivor.lastModified = Date()
                            }
                        }
                        sorted.dropFirst().forEach(self.context.delete)
                        rowsChanged = true
                    }
                    rowsByKey[key] = survivor
                }

                // (key, the local value the decision was based on, winner)
                var applied: [(key: String, expectedLocal: Any?, winner: Any)] = []

                for entry in Self.whitelist {
                    let key = entry.key
                    let localValue = defaults.object(forKey: key)
                    let row = rowsByKey[key]
                    let remoteValue = row?.value.flatMap(Self.decodeValue)

                    func push(_ value: Any) {
                        guard let encoded = Self.encodeValue(value) else { return }
                        let target: SyncedSetting
                        if let row = row {
                            target = row
                        } else {
                            target = SyncedSetting(context: self.context)
                            target.id = UUID()
                            target.key = key
                            rowsByKey[key] = target
                        }
                        guard target.value != encoded else { return }
                        target.value = encoded
                        target.deviceId = device
                        target.lastModified = Date()
                        rowsChanged = true
                    }

                    func bookkeep(finalValue: Any?) {
                        base[key] = finalValue.flatMap(Self.encodeValue)
                        if let stampDate = rowsByKey[key]?.lastModified {
                            stamps[key] = stampDate.timeIntervalSince1970
                        }
                    }

                    switch (localValue, remoteValue) {
                    case (nil, nil):
                        continue

                    case (let local?, nil):
                        // Local-only value. A fresh install must NOT push
                        // until the first import settles — its local values
                        // are just defaults, and pushing them would beat the
                        // user's real rows in the newest-wins dedup. Leave
                        // the key un-bookkept so a later pass retries.
                        if mayPushLocalOnly {
                            push(local)
                            bookkeep(finalValue: local)
                        }

                    case (nil, let remote?):
                        // Remote-only value — restore it locally.
                        applied.append((key: key, expectedLocal: nil, winner: remote))

                        bookkeep(finalValue: remote)

                    case (let local?, let remote?):
                        if Self.equivalent(entry, local, remote) {
                            bookkeep(finalValue: local)
                            continue
                        }

                        let baseValue = base[key].flatMap(Self.decodeValue)
                        let localChanged = baseValue.map { !Self.equivalent(entry, local, $0) } ?? true
                        let remoteStamp = row?.lastModified?.timeIntervalSince1970 ?? 0
                        let remoteChanged = remoteStamp > (stamps[key] ?? 0) + 0.0005

                        let winner: Any
                        switch entry.strategy {
                        case .maxInt:
                            winner = max(Self.intValue(local), Self.intValue(remote))
                        case .boolOr:
                            winner = Self.boolValue(local) || Self.boolValue(remote)
                        case .custom(let merge):
                            winner = merge(local, remote)
                        case .lastWriterWins:
                            if remoteChanged && !localChanged {
                                winner = remote
                            } else if localChanged && !remoteChanged {
                                winner = local
                            } else {
                                // Both changed (or no base yet): a fresh
                                // install restores the synced value; an
                                // established device keeps what the user
                                // sees on screen.
                                winner = freshInstall ? remote : local
                            }
                        }

                        if !Self.equivalent(entry, winner, local) {
                            applied.append((key: key, expectedLocal: local, winner: winner))
                        }
                        if !Self.equivalent(entry, winner, remote) {
                            push(winner)
                        }
                        bookkeep(finalValue: winner)
                    }
                }

                if rowsChanged {
                    try self.context.save()
                }

                // Apply + bookkeeping commit happens on main so the local
                // read-check and write are atomic w.r.t. UI writes.
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    let defaults = UserDefaults.standard
                    var actuallyApplied = Set<String>()

                    for item in applied {
                        // If the user changed this key after the reconcile
                        // pass read it, their change wins: skip the apply and
                        // forget the bookkeeping so the next pass sees the
                        // key as locally-changed and pushes it.
                        let current = defaults.object(forKey: item.key)
                        if Self.valuesEqual(current, item.expectedLocal) {
                            defaults.set(item.winner, forKey: item.key)
                            actuallyApplied.insert(item.key)
                        } else {
                            base.removeValue(forKey: item.key)
                            stamps.removeValue(forKey: item.key)
                        }
                    }

                    if (defaults.dictionary(forKey: Self.baseKey) as? [String: Data]) ?? [:] != base {
                        defaults.set(base, forKey: Self.baseKey)
                    }
                    let existingStamps = (defaults.dictionary(forKey: Self.stampsKey) as? [String: Double]) ?? [:]
                    if existingStamps != stamps {
                        defaults.set(stamps, forKey: Self.stampsKey)
                    }
                    if defaults.object(forKey: Self.initializedKey) == nil {
                        defaults.set(true, forKey: Self.initializedKey)
                    }

                    // Snapshot the post-reconcile local state so echo
                    // notifications from our own writes short-circuit.
                    self.lastLocalDigest = Self.computeLocalDigest()

                    if !actuallyApplied.isEmpty {
                        NotificationCenter.default.post(
                            name: Self.settingsDidChange,
                            object: nil,
                            userInfo: ["keys": actuallyApplied]
                        )
                    }
                    self.finishReconcile()
                }
            } catch {
                print("SyncedSettingsStore: reconcile failed - \(error.localizedDescription)")
                DispatchQueue.main.async { [weak self] in
                    self?.finishReconcile()
                }
            }
        }
    }

    // MARK: - Whitelist helpers

    private static let whitelistByKey: [String: SyncedKey] = {
        var map: [String: SyncedKey] = [:]
        for entry in whitelist { map[entry.key] = entry }
        return map
    }()

    private static func mergeValues(_ strategy: MergeStrategy, _ a: Any, _ b: Any) -> Any {
        switch strategy {
        case .maxInt: return max(intValue(a), intValue(b))
        case .boolOr: return boolValue(a) || boolValue(b)
        case .custom(let merge): return merge(a, b)
        case .lastWriterWins: return a
        }
    }

    private static func equivalent(_ entry: SyncedKey, _ a: Any?, _ b: Any?) -> Bool {
        switch (a, b) {
        case (nil, nil): return true
        case (let a?, let b?):
            if let equivalence = entry.equivalence { return equivalence(a, b) }
            return valuesEqual(a, b)
        default: return false
        }
    }

    /// Current encodings of every whitelisted local value — cheap change
    /// detector for the UserDefaults.didChangeNotification firehose.
    private static func computeLocalDigest() -> [String: Data] {
        let defaults = UserDefaults.standard
        var digest: [String: Data] = [:]
        for entry in whitelist {
            if let value = defaults.object(forKey: entry.key),
               let encoded = encodeValue(value) {
                digest[entry.key] = encoded
            }
        }
        return digest
    }

    // MARK: - Value encoding (property-list wrap)

    private static func encodeValue(_ value: Any) -> Data? {
        try? PropertyListSerialization.data(
            fromPropertyList: ["v": value],
            format: .binary,
            options: 0
        )
    }

    private static func decodeValue(_ data: Data) -> Any? {
        guard let object = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dictionary = object as? [String: Any] else { return nil }
        return dictionary["v"]
    }

    private static func valuesEqual(_ a: Any?, _ b: Any?) -> Bool {
        switch (a, b) {
        case (nil, nil): return true
        case (let a?, let b?): return (a as AnyObject).isEqual(b as AnyObject)
        default: return false
        }
    }

    private static func intValue(_ value: Any) -> Int {
        (value as? Int) ?? (value as? NSNumber)?.intValue ?? 0
    }

    private static func boolValue(_ value: Any) -> Bool {
        (value as? Bool) ?? (value as? NSNumber)?.boolValue ?? false
    }

    // MARK: - Custom mergers (all lossless unions)

    /// Streak stats: recency-aware merge — see StreakStats.merging(_:).
    /// If one side is empty or unreadable, the readable side wins; never
    /// let a blank blob overwrite real progress.
    private static func mergeStreakStats(_ local: Any, _ remote: Any) -> Any {
        let decodedLocal = (local as? Data).flatMap { try? JSONDecoder().decode(StreakStats.self, from: $0) }
        let decodedRemote = (remote as? Data).flatMap { try? JSONDecoder().decode(StreakStats.self, from: $0) }
        guard let localStats = decodedLocal else { return decodedRemote != nil ? remote : local }
        guard let remoteStats = decodedRemote else { return local }

        let merged = localStats.merging(remoteStats)
        if merged == localStats { return local }
        if merged == remoteStats { return remote }
        return (try? JSONEncoder().encode(merged)) ?? local
    }

    private static func streakStatsEquivalent(_ a: Any, _ b: Any) -> Bool {
        let decodedA = (a as? Data).flatMap { try? JSONDecoder().decode(StreakStats.self, from: $0) }
        let decodedB = (b as? Data).flatMap { try? JSONDecoder().decode(StreakStats.self, from: $0) }
        if let decodedA = decodedA, let decodedB = decodedB { return decodedA == decodedB }
        return valuesEqual(a, b)
    }

    /// Union of two JSON-encoded arrays of objects (Data blobs), keyed by a
    /// field. Local order is preserved; remote-only items are appended.
    private static func mergeJSONArrayData(idField: String) -> (Any, Any) -> Any {
        return { local, remote in
            let decodedLocal = (local as? Data).flatMap { (try? JSONSerialization.jsonObject(with: $0)) as? [[String: Any]] }
            let decodedRemote = (remote as? Data).flatMap { (try? JSONSerialization.jsonObject(with: $0)) as? [[String: Any]] }
            guard let localArray = decodedLocal else { return decodedRemote != nil ? remote : local }
            guard let remoteArray = decodedRemote else { return local }
            let localIds = Set(localArray.map { Self.jsonIdentity($0, idField: idField) })
            let merged = localArray + remoteArray.filter { !localIds.contains(Self.jsonIdentity($0, idField: idField)) }
            guard merged.count != localArray.count else { return local }
            return (try? JSONSerialization.data(withJSONObject: merged)) ?? local
        }
    }

    /// Identity-set comparison for JSON array blobs — byte layouts differ
    /// across devices for the same logical set, so never compare raw Data.
    private static func jsonArrayDataEquivalent(idField: String) -> (Any, Any) -> Bool {
        return { a, b in
            let decodedA = (a as? Data).flatMap { (try? JSONSerialization.jsonObject(with: $0)) as? [[String: Any]] }
            let decodedB = (b as? Data).flatMap { (try? JSONSerialization.jsonObject(with: $0)) as? [[String: Any]] }
            guard let arrayA = decodedA, let arrayB = decodedB else { return valuesEqual(a, b) }
            return Set(arrayA.map { Self.jsonIdentity($0, idField: idField) })
                == Set(arrayB.map { Self.jsonIdentity($0, idField: idField) })
        }
    }

    private static func jsonIdentity(_ item: [String: Any], idField: String) -> String {
        if let string = item[idField] as? String { return string }
        if let value = item[idField] { return String(describing: value) }
        return String(describing: item)
    }

    /// Union of the read-devotionals dictionary ([DateComponents: Bool] as
    /// JSON Data) — a devotional read anywhere is read everywhere.
    private static func mergeDevotionalDictionary(_ local: Any, _ remote: Any) -> Any {
        let decodedLocal = (local as? Data).flatMap { try? JSONDecoder().decode([DateComponents: Bool].self, from: $0) }
        let decodedRemote = (remote as? Data).flatMap { try? JSONDecoder().decode([DateComponents: Bool].self, from: $0) }
        guard var localDictionary = decodedLocal else { return decodedRemote != nil ? remote : local }
        guard let remoteDictionary = decodedRemote else { return local }
        var changed = false
        for (components, read) in remoteDictionary where localDictionary[components] != true {
            localDictionary[components] = read
            changed = true
        }
        guard changed else { return local }
        return (try? JSONEncoder().encode(localDictionary)) ?? local
    }

    private static func devotionalDictionaryEquivalent(_ a: Any, _ b: Any) -> Bool {
        let decodedA = (a as? Data).flatMap { try? JSONDecoder().decode([DateComponents: Bool].self, from: $0) }
        let decodedB = (b as? Data).flatMap { try? JSONDecoder().decode([DateComponents: Bool].self, from: $0) }
        if let decodedA = decodedA, let decodedB = decodedB { return decodedA == decodedB }
        return valuesEqual(a, b)
    }

    /// Union of a JSON string-array stored AS a String (quiz titles).
    private static func mergeJSONStringArrayString(_ local: Any, _ remote: Any) -> Any {
        let decodedLocal = (local as? String).flatMap { try? JSONDecoder().decode([String].self, from: Data($0.utf8)) }
        let decodedRemote = (remote as? String).flatMap { try? JSONDecoder().decode([String].self, from: Data($0.utf8)) }
        guard let localArray = decodedLocal else { return decodedRemote != nil ? remote : local }
        guard let remoteArray = decodedRemote else { return local }
        let localSet = Set(localArray)
        let merged = localArray + remoteArray.filter { !localSet.contains($0) }
        guard merged.count != localArray.count else { return local }
        guard let data = try? JSONEncoder().encode(merged) else { return local }
        return String(data: data, encoding: .utf8) ?? (local as? String ?? "")
    }

    private static func jsonStringArraySetEquivalent(_ a: Any, _ b: Any) -> Bool {
        let decodedA = (a as? String).flatMap { try? JSONDecoder().decode([String].self, from: Data($0.utf8)) }
        let decodedB = (b as? String).flatMap { try? JSONDecoder().decode([String].self, from: Data($0.utf8)) }
        if let decodedA = decodedA, let decodedB = decodedB { return Set(decodedA) == Set(decodedB) }
        return valuesEqual(a, b)
    }

    /// Union of [String: String] dictionaries; local wins on key conflicts.
    private static func mergeStringDictionary(_ local: Any, _ remote: Any) -> Any {
        guard let localDictionary = local as? [String: String],
              let remoteDictionary = remote as? [String: String] else {
            return local
        }
        return remoteDictionary.merging(localDictionary) { _, localValue in localValue }
    }

    /// Union of [String] arrays preserving local order.
    private static func mergeStringArray(_ local: Any, _ remote: Any) -> Any {
        guard let localArray = local as? [String],
              let remoteArray = remote as? [String] else {
            return local
        }
        let localSet = Set(localArray)
        return localArray + remoteArray.filter { !localSet.contains($0) }
    }

    /// Order-insensitive comparison for plain string arrays.
    private static func stringArraySetEquivalent(_ a: Any, _ b: Any) -> Bool {
        guard let arrayA = a as? [String], let arrayB = b as? [String] else { return valuesEqual(a, b) }
        return Set(arrayA) == Set(arrayB)
    }
}
