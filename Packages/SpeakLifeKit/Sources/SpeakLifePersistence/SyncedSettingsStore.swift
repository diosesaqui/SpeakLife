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
import SpeakLifeCore

public final class SyncedSettingsStore {

    public static let shared = SyncedSettingsStore()

    /// Posted on the main queue after remote values have been applied to
    /// UserDefaults. userInfo["keys"] is the Set<String> of applied keys.
    public static let settingsDidChange = Notification.Name("SyncedSettingsStoreDidChange")

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

        // NOTE: "dailyChecklist" is deliberately NOT synced here. The blob is
        // owned by EnhancedStreakViewModel (day rollover, per-device task
        // personalization); syncing it created a second owner and a
        // day-winner rule that fought the VM. Task completions cross devices
        // as ProgressSyncStore "taskCompletion" events instead — union by
        // construction, and deleting the event propagates an un-check.

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

        // The seven-day Enforcement campaign. Without this the campaign was
        // device-local: the user's second device had no idea a week was
        // running and offered to start a fresh one on top of it. Note this is
        // a campaign-aware merge, not a field-by-field union — blending two
        // different weeks' day sets would hand the user a campaign they never
        // started (see mergedEnforcementProgress).
        SyncedKey(key: "enforcementProgress",
                  strategy: .custom(mergeEnforcementProgress),
                  equivalence: enforcementProgressEquivalent),

        // Monotonic progress scalars.
        SyncedKey(key: "abbasLoveLetterIndex", strategy: .maxInt),
        SyncedKey(key: "personalDeclaration_completedDayCount", strategy: .maxInt),
        // Inbox read pointer — the broadcast sequence number the user has read
        // up to — so the unread badge clears on every device once it is read
        // on one. maxInt is exactly the right rule for a read pointer: the
        // furthest-read device wins, so a device that has been offline can
        // never push a stale pointer and resurrect messages already read.
        //
        // String literal mirrors `InboxUnreadTracker.readSeqKey` in the app
        // (SpeakLifeMessagesView.swift). Inlined so this file does not
        // reach back into the app; the two must not drift.
        SyncedKey(key: "inboxReadSeq", strategy: .maxInt),

        // One-way flags.
        SyncedKey(key: "onboarded", strategy: .boolOr),
        SyncedKey(key: "hasCompletedEnhancedOnboarding", strategy: .boolOr),
        SyncedKey(key: "hasPersonalDeclaration", strategy: .boolOr),
        // "Your streak freeze was used" — raised where the freeze is spent and
        // consumed-and-cleared by EnhancedStreakViewModel.appDidBecomeActive
        // (via showFreezeUsedBannerIfNeeded). Synced so the banner reaches
        // whichever device the user next opens rather than only the one that
        // happened to spend the freeze, which may be a phone in a drawer.
        // boolOr never carries the clear back, so the still-true remote row
        // returns on the next reconcile; the view model bounds the banner by
        // freeze identity rather than by this flag alone.
        SyncedKey(key: "streakFreezeWasUsed", strategy: .boolOr),

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

        // Personal declaration. The v2 list is progress-bearing — each record
        // carries its own "Day N" and spoken-today counters — so it merges as a
        // union by id rather than letting one device's list overwrite another's.
        // The v1 single-record key stays whitelisted so devices still on the old
        // build keep syncing; upgraded devices migrate v1 once and ignore it after.
        // String literals mirror `PersonalDeclarationRepository.storageKey` /
        // `legacyStorageKey` in the app (Services/PersonalDeclaration/
        // PersonalDeclarationRepository.swift). Inlined so this file does not
        // reach back into the app; the three must not drift.
        SyncedKey(key: "personal_declarations_v2",
                  strategy: .custom(mergePersonalDeclarations),
                  equivalence: personalDeclarationsEquivalent),
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
        // Travels with the topics above: once curated on one device, the feed's
        // category chooser must stop mirroring its pick into them everywhere.
        SyncedKey(key: "notificationTopicsCustomized", strategy: .lastWriterWins),
        SyncedKey(key: "personalDeclarationTimeIndex", strategy: .lastWriterWins),
        SyncedKey(key: "morningReminderEnabled", strategy: .lastWriterWins),
        SyncedKey(key: "morningReminderHour", strategy: .lastWriterWins),
        SyncedKey(key: "morningReminderMinute", strategy: .lastWriterWins),
        SyncedKey(key: "eveningCheckInEnabled", strategy: .lastWriterWins),
        SyncedKey(key: "eveningCheckInHour", strategy: .lastWriterWins),
        SyncedKey(key: "eveningCheckInMinute", strategy: .lastWriterWins),
        SyncedKey(key: "checklistNotificationsEnabled", strategy: .lastWriterWins),
        SyncedKey(key: "dailyDeclarationRemindersEnabled", strategy: .lastWriterWins),
        // How many Daily Burst invitations a day. Travels with the toggle above:
        // someone who turned the rhythm down to one a day on their phone should
        // not be nudged three times on their iPad.
        SyncedKey(key: "burstRemindersPerDay", strategy: .lastWriterWins)
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

    // `internal` (not `private`) for the same reason `ProgressSyncStore.init`
    // is — kept off the public surface so the app keeps going through `.shared`,
    // but reachable from an in-target test if one is ever added.
    init(container: NSPersistentCloudKitContainer = PersistenceController.shared.container) {
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
    ///
    /// - Parameter lifecycle: the app's foreground/background notification
    ///   names (`UIApplication.did{BecomeActive,EnterBackground}Notification`
    ///   on iOS). Injected by the app target so this file stays UIKit-free.
    ///   Only `didBecomeActive` is observed here; the parameter takes the
    ///   pair for symmetry with the other CoreData stores.
    public func start(lifecycle: LifecycleNames) {
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
            name: lifecycle.didBecomeActive,
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
    public func reconcile() {
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
        let device = ProgressSyncStore.shared.deviceId

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
            // Byte-equal is always semantically equal — skip the decode cost
            // (blob equivalences JSON-decode both sides, and identical bytes
            // are the common case for a single-device user).
            if valuesEqual(a, b) { return true }
            if let equivalence = entry.equivalence { return equivalence(a, b) }
            return false
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

    /// Union of the personal declarations list. Every record the user has
    /// created on any device is kept; where both sides know a declaration, the
    /// one that has been prayed further wins each counter. Losing a "Day 40" to
    /// a phone that has been in a drawer would gut the whole point of the feature.
    private static func mergePersonalDeclarations(_ local: Any, _ remote: Any) -> Any {
        let decodedLocal = (local as? Data).flatMap { try? JSONDecoder().decode([PersonalDeclaration].self, from: $0) }
        let decodedRemote = (remote as? Data).flatMap { try? JSONDecoder().decode([PersonalDeclaration].self, from: $0) }
        guard let localList = decodedLocal else { return decodedRemote != nil ? remote : local }
        guard let remoteList = decodedRemote else { return local }

        var merged = localList
        for remoteDeclaration in remoteList {
            if let index = merged.firstIndex(where: { $0.id == remoteDeclaration.id }) {
                merged[index] = mergeDeclaration(merged[index], remoteDeclaration)
            } else {
                merged.append(remoteDeclaration)
            }
        }
        // Oldest first keeps the list — and therefore the staggered reminder
        // times — stable across devices.
        merged.sort { $0.startDate < $1.startDate }
        guard merged != localList else { return local }
        return (try? JSONEncoder().encode(merged)) ?? local
    }

    private static func mergeDeclaration(_ a: PersonalDeclaration,
                                         _ b: PersonalDeclaration) -> PersonalDeclaration {
        var merged = a
        merged.completedDayCount = max(a.completedDayCount, b.completedDayCount)
        // Whichever device spoke it most recently owns today's repeat count.
        if b.lastSpokenDate > a.lastSpokenDate {
            merged.lastSpokenDate = b.lastSpokenDate
            merged.dailySpeakCount = b.dailySpeakCount
        } else if a.lastSpokenDate == b.lastSpokenDate {
            merged.dailySpeakCount = max(a.dailySpeakCount, b.dailySpeakCount)
        }
        // A breakthrough is one-way: once received anywhere, received everywhere.
        if merged.receivedDate == nil { merged.receivedDate = b.receivedDate }
        if (merged.testimony ?? "").isEmpty { merged.testimony = b.testimony }
        // So is putting one down. Without this the union would hand a removed
        // declaration back on the next reconcile, reminder and all.
        if merged.deletedDate == nil { merged.deletedDate = b.deletedDate }
        return merged
    }

    private static func personalDeclarationsEquivalent(_ a: Any, _ b: Any) -> Bool {
        let decodedA = (a as? Data).flatMap { try? JSONDecoder().decode([PersonalDeclaration].self, from: $0) }
        let decodedB = (b as? Data).flatMap { try? JSONDecoder().decode([PersonalDeclaration].self, from: $0) }
        guard let listA = decodedA, let listB = decodedB else { return valuesEqual(a, b) }
        return listA.sorted { $0.startDate < $1.startDate } == listB.sorted { $0.startDate < $1.startDate }
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

    // MARK: - Enforcement campaign merge

    /// Plist-value shim around `mergedEnforcementProgress`. Hands back one of
    /// the original blobs whenever the merge is semantically a no-op, so an
    /// unstable re-encoding never looks like a change worth pushing.
    private static func mergeEnforcementProgress(_ local: Any, _ remote: Any) -> Any {
        let decodedLocal = (local as? Data).flatMap { try? JSONDecoder().decode(EnforcementProgress.self, from: $0) }
        let decodedRemote = (remote as? Data).flatMap { try? JSONDecoder().decode(EnforcementProgress.self, from: $0) }
        guard let localProgress = decodedLocal else { return decodedRemote != nil ? remote : local }
        guard let remoteProgress = decodedRemote else { return local }

        let merged = mergedEnforcementProgress(localProgress, remoteProgress)
        if merged == localProgress { return local }
        if merged == remoteProgress { return remote }
        return (try? JSONEncoder().encode(merged)) ?? local
    }

    /// Merges two devices' Enforcement campaigns.
    ///
    /// Both devices run this independently over the same pair of values, so it
    /// MUST be commutative and deterministic: every choice below breaks ties on
    /// the data itself (dates, then ids, then a content fingerprint) and never
    /// on which side happens to be "local". A local-wins rule would leave the
    /// two devices holding different campaigns forever, each pushing its own
    /// answer back at the other.
    ///
    /// Internal rather than private so the rules can be pinned by tests; the
    /// shipping call site is `mergeEnforcementProgress` above.
    public static func mergedEnforcementProgress(_ a: EnforcementProgress,
                                                 _ b: EnforcementProgress) -> EnforcementProgress {
        var merged = EnforcementProgress()
        merged.completedEnforcementIds = mergedEnforcementHistory(a.completedEnforcementIds,
                                                                  b.completedEnforcementIds)

        if let idA = a.activeEnforcementId, let idB = b.activeEnforcementId {
            if idA == idB {
                // The same week on both sides: a day banked anywhere is banked.
                merged.activeEnforcementId = idA
                merged.assembledEnforcement = preferredEnforcement(a.assembledEnforcement,
                                                                   b.assembledEnforcement)
                // Earliest start wins: `elapsedDays` is measured from it, and
                // the campaign began when the user first began it.
                merged.startedOn = earlierDate(a.startedOn, b.startedOn)
                merged.completedDayNumbers = a.completedDayNumbers.union(b.completedDayNumbers)
                merged.lastAdvancedOn = laterDate(a.lastAdvancedOn, b.lastAdvancedOn)
            } else {
                // Two different weeks. Unioning their day sets would produce a
                // campaign the user never started — day five of one week paired
                // with the anchors of another — so the newer start takes the
                // whole campaign and the older one is dropped.
                let (winner, loser) = newerCampaign(a, b)
                copyCampaign(from: winner, into: &merged)
                // A dropped week is banked only if it was genuinely finished;
                // otherwise it was abandoned and was never earned.
                if loser.isComplete, let loserId = loser.activeEnforcementId,
                   !merged.completedEnforcementIds.contains(loserId) {
                    merged.completedEnforcementIds.append(loserId)
                }
            }
        } else if a.activeEnforcementId != nil {
            adoptSoleCampaign(holder: a, other: b, into: &merged)
        } else if b.activeEnforcementId != nil {
            adoptSoleCampaign(holder: b, other: a, into: &merged)
        }

        // A campaign with all seven days banked is finished, not running.
        // `finish()` does this the instant day seven lands, so this only catches
        // a state that crossed devices mid-flight; leaving it would strand a
        // campaign that `advanceIfNeeded` no longer touches.
        if merged.activeEnforcementId != nil, merged.isComplete {
            merged.finish()
        }
        return merged
    }

    /// Takes the campaign from the only side that has one.
    private static func adoptSoleCampaign(holder: EnforcementProgress,
                                          other: EnforcementProgress,
                                          into merged: inout EnforcementProgress) {
        guard let id = holder.activeEnforcementId else { return }
        // The other side already banked this campaign as complete and this side
        // never did — it finished the week while this device was away. Handing
        // the campaign back would re-open a week the user already celebrated,
        // every time the two devices meet. A deliberate restart of a
        // previously-completed campaign is told apart by the holder carrying
        // that id in its OWN history (`begin` preserves history), which this
        // case does not.
        if other.completedEnforcementIds.contains(id),
           !holder.completedEnforcementIds.contains(id) {
            return
        }
        copyCampaign(from: holder, into: &merged)
    }

    /// Moves a whole campaign across, `assembledEnforcement` included.
    ///
    /// The blob has to travel with its own campaign: a curated id like
    /// "curated_warfare" is not in `enforcements.json`, so a campaign that
    /// arrives without it cannot be resolved at all and the user's week
    /// silently disappears on the receiving device.
    private static func copyCampaign(from source: EnforcementProgress,
                                     into merged: inout EnforcementProgress) {
        merged.activeEnforcementId = source.activeEnforcementId
        merged.assembledEnforcement = source.assembledEnforcement
        merged.startedOn = source.startedOn
        merged.completedDayNumbers = source.completedDayNumbers
        merged.lastAdvancedOn = source.lastAdvancedOn
    }

    /// Which of two different campaigns is the live one. A missing `startedOn`
    /// loses to any real date, and an exact tie breaks on the id so both
    /// devices pick the same winner instead of each keeping its own.
    private static func newerCampaign(_ a: EnforcementProgress,
                                      _ b: EnforcementProgress)
        -> (winner: EnforcementProgress, loser: EnforcementProgress) {
        let startA = a.startedOn ?? .distantPast
        let startB = b.startedOn ?? .distantPast
        if startA != startB { return startA > startB ? (a, b) : (b, a) }
        let idA = a.activeEnforcementId ?? ""
        let idB = b.activeEnforcementId ?? ""
        return idA >= idB ? (a, b) : (b, a)
    }

    /// Order-preserving union of the completed-campaign history: the side that
    /// knows more campaigns leads and the other's unknown ids are appended.
    /// Leading with "local" would leave the two devices holding the same
    /// history in different orders forever, each pushing its own ordering back.
    private static func mergedEnforcementHistory(_ a: [String], _ b: [String]) -> [String] {
        let ordered: ([String], [String])
        if a.count != b.count {
            ordered = a.count > b.count ? (a, b) : (b, a)
        } else if a.joined(separator: "\u{1}") <= b.joined(separator: "\u{1}") {
            ordered = (a, b)
        } else {
            ordered = (b, a)
        }
        var result = ordered.0
        var seen = Set(result)
        for id in ordered.1 where !seen.contains(id) {
            seen.insert(id)
            result.append(id)
        }
        return result
    }

    /// One campaign id, two different campaigns — possible because a curated
    /// campaign's id is only "curated_" + theme, so two devices that each
    /// curated a week collide under one id. Picking by content fingerprint
    /// keeps both devices on the same seven lines; picking "whichever is local"
    /// would leave them speaking different day-three anchors all week.
    private static func preferredEnforcement(_ a: Enforcement?, _ b: Enforcement?) -> Enforcement? {
        guard let a = a else { return b }
        guard let b = b else { return a }
        if a == b { return a }
        return enforcementFingerprint(a) <= enforcementFingerprint(b) ? a : b
    }

    /// Deliberately `title` and not `displayTitle`. This is a deterministic
    /// tiebreak over the bytes two devices actually stored, so it must reflect
    /// what is on disk, not what the UI renders. Swapping in the re-derived
    /// title would make the fingerprint depend on app version, and two devices
    /// on different builds would stop agreeing on the same campaign.
    ///
    /// `theme.rawValue` for the same reason: it is the value on disk. The theme
    /// is a `DeclarationCategory` in memory now, but its display name is not
    /// what was stored, and feeding one in here would change the fingerprint on
    /// upgrade and break agreement with a device still on the old build.
    ///
    /// Internal rather than private so the exact bytes can be pinned by tests,
    /// same as `mergedEnforcementProgress` above. There is no way to notice this
    /// drifting from a running app — two devices simply, quietly, disagree — so
    /// the only place it can be caught is a test that asserts the literal string.
    public static func enforcementFingerprint(_ enforcement: Enforcement) -> String {
        ([enforcement.id, enforcement.title, enforcement.theme.rawValue]
            + enforcement.days.map { "\($0.dayNumber)\u{1}\($0.anchorText)\u{1}\($0.audioId)" })
            .joined(separator: "\u{1}")
    }

    private static func earlierDate(_ a: Date?, _ b: Date?) -> Date? {
        guard let a = a else { return b }
        guard let b = b else { return a }
        return min(a, b)
    }

    private static func laterDate(_ a: Date?, _ b: Date?) -> Date? {
        guard let a = a else { return b }
        guard let b = b else { return a }
        return max(a, b)
    }

    /// `completedDayNumbers` is a `Set<Int>`, and JSON gives a Set no stable
    /// order, so two devices holding the identical campaign encode different
    /// bytes. Comparing raw Data here would make every reconcile look like a
    /// change and the two devices would push at each other forever.
    private static func enforcementProgressEquivalent(_ a: Any, _ b: Any) -> Bool {
        let decodedA = (a as? Data).flatMap { try? JSONDecoder().decode(EnforcementProgress.self, from: $0) }
        let decodedB = (b as? Data).flatMap { try? JSONDecoder().decode(EnforcementProgress.self, from: $0) }
        if let decodedA = decodedA, let decodedB = decodedB { return decodedA == decodedB }
        return valuesEqual(a, b)
    }
}
