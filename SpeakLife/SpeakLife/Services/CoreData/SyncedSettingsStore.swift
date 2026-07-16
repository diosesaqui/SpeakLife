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
//  A three-way merge base (the value at last reconcile) is kept per key so
//  the store can tell WHICH side actually changed instead of guessing.
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
    }

    // MARK: - The whitelist

    private static let whitelist: [SyncedKey] = [
        // Streak stats blob: max streaks, union of celebrated milestones.
        SyncedKey(key: "streakStats", strategy: .custom(mergeStreakStats)),

        // Progress-bearing blobs — union merges, nothing ever dropped.
        SyncedKey(key: "UnlockedBadges", strategy: .custom(mergeJSONArrayData(idField: "title"))),
        SyncedKey(key: "BibleBookmarks", strategy: .custom(mergeJSONArrayData(idField: "id"))),
        SyncedKey(key: "BibleHighlights", strategy: .custom(mergeJSONArrayData(idField: "id"))),
        SyncedKey(key: "devotionalDictionary", strategy: .custom(mergeDevotionalDictionary)),
        SyncedKey(key: "completedQuizTitlesRaw", strategy: .custom(mergeJSONStringArrayString)),
        SyncedKey(key: "warriorRoomUserReactions", strategy: .custom(mergeStringDictionary)),
        SyncedKey(key: "warriorRoomUserAgreements", strategy: .custom(mergeStringArray)),

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
    private lazy var context: NSManagedObjectContext = {
        let ctx = container.newBackgroundContext()
        ctx.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        ctx.automaticallyMergesChangesFromParent = true
        return ctx
    }()

    private var localChangeWorkItem: DispatchWorkItem?
    private var remoteChangeWorkItem: DispatchWorkItem?
    private var isApplyingRemoteValues = false
    private var started = false
    /// Captured once: a fresh install prefers the synced (restored) value
    /// when both sides differ and no merge base exists yet.
    private let isFreshInstall: Bool

    private init(container: NSPersistentCloudKitContainer = PersistenceController.shared.container) {
        self.container = container
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

        // First pass shortly after launch (store loading is asynchronous).
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.reconcile()
        }
    }

    @objc private func handleDidBecomeActive() {
        reconcile()
    }

    @objc private func handleLocalDefaultsChange() {
        guard !isApplyingRemoteValues else { return }
        localChangeWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.reconcile() }
        localChangeWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: work)
    }

    @objc private func handleRemoteChange(_ notification: Notification) {
        remoteChangeWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.reconcile() }
        remoteChangeWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
    }

    // MARK: - Reconcile

    /// Reconciles every whitelisted key between UserDefaults and CloudKit.
    /// Idempotent and cheap (one fetch of a few dozen rows); safe to call
    /// from any thread.
    func reconcile() {
        let device = ProgressSyncStore.deviceId
        let freshInstall = isFreshInstall
        context.perform { [weak self] in
            guard let self = self else { return }
            do {
                let defaults = UserDefaults.standard
                var base = (defaults.dictionary(forKey: Self.baseKey) as? [String: Data]) ?? [:]
                var stamps = (defaults.dictionary(forKey: Self.stampsKey) as? [String: Double]) ?? [:]
                let baseBefore = base
                let stampsBefore = stamps

                let request = SyncedSetting.fetchRequest()
                let allRows = try self.context.fetch(request)
                var rowsByKey: [String: SyncedSetting] = [:]
                var rowsChanged = false

                // Dedup rows per key deterministically (CloudKit cannot
                // enforce uniqueness): the newest lastModified survives,
                // id string as tie-break; the rest are deleted everywhere.
                var grouped: [String: [SyncedSetting]] = [:]
                for row in allRows { grouped[row.key, default: []].append(row) }
                for (key, group) in grouped {
                    let sorted = group.sorted { a, b in
                        let aDate = a.lastModified ?? .distantPast
                        let bDate = b.lastModified ?? .distantPast
                        if aDate != bDate { return aDate > bDate }
                        return (a.id?.uuidString ?? "") > (b.id?.uuidString ?? "")
                    }
                    rowsByKey[key] = sorted[0]
                    if sorted.count > 1 {
                        sorted.dropFirst().forEach(self.context.delete)
                        rowsChanged = true
                    }
                }

                var appliedValues: [String: Any] = [:]

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
                        // Local-only value (first adoption on this device,
                        // or the row was never created) — push it up.
                        push(local)
                        bookkeep(finalValue: local)

                    case (nil, let remote?):
                        // Remote-only value — restore it locally.
                        appliedValues[key] = remote
                        bookkeep(finalValue: remote)

                    case (let local?, let remote?):
                        if Self.valuesEqual(local, remote) {
                            bookkeep(finalValue: local)
                            continue
                        }

                        let baseValue = base[key].flatMap(Self.decodeValue)
                        let localChanged = baseValue.map { !Self.valuesEqual(local, $0) } ?? true
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

                        if !Self.valuesEqual(winner, local) {
                            appliedValues[key] = winner
                        }
                        if !Self.valuesEqual(winner, remote) {
                            push(winner)
                        }
                        bookkeep(finalValue: winner)
                    }
                }

                if rowsChanged {
                    try self.context.save()
                }

                let baseChanged = !(base as NSDictionary).isEqual(to: baseBefore)
                let stampsChanged = !(stamps as NSDictionary).isEqual(to: stampsBefore)

                DispatchQueue.main.async {
                    if !appliedValues.isEmpty {
                        self.isApplyingRemoteValues = true
                        for (key, value) in appliedValues {
                            UserDefaults.standard.set(value, forKey: key)
                        }
                        self.isApplyingRemoteValues = false
                    }
                    if baseChanged { UserDefaults.standard.set(base, forKey: Self.baseKey) }
                    if stampsChanged { UserDefaults.standard.set(stamps, forKey: Self.stampsKey) }
                    if UserDefaults.standard.object(forKey: Self.initializedKey) == nil {
                        UserDefaults.standard.set(true, forKey: Self.initializedKey)
                    }
                    if !appliedValues.isEmpty {
                        NotificationCenter.default.post(
                            name: Self.settingsDidChange,
                            object: nil,
                            userInfo: ["keys": Set(appliedValues.keys)]
                        )
                    }
                    if rowsChanged {
                        // Nudge CloudKit export so other devices see it fast.
                        PersistenceController.shared.save()
                    }
                }
            } catch {
                print("SyncedSettingsStore: reconcile failed - \(error.localizedDescription)")
            }
        }
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

    /// Streak stats: streak numbers merge as max, milestone celebrations as
    /// union, freeze availability conservatively (spent anywhere = spent).
    private static func mergeStreakStats(_ local: Any, _ remote: Any) -> Any {
        let decodedLocal = (local as? Data).flatMap { try? JSONDecoder().decode(StreakStats.self, from: $0) }
        let decodedRemote = (remote as? Data).flatMap { try? JSONDecoder().decode(StreakStats.self, from: $0) }
        // If one side is empty or unreadable, the readable side wins — never
        // let a blank blob overwrite real progress.
        guard var localStats = decodedLocal else { return decodedRemote != nil ? remote : local }
        guard let remoteStats = decodedRemote else { return local }

        localStats.currentStreak = max(localStats.currentStreak, remoteStats.currentStreak)
        localStats.longestStreak = max(localStats.longestStreak, remoteStats.longestStreak)
        localStats.totalDaysCompleted = max(localStats.totalDaysCompleted, remoteStats.totalDaysCompleted)
        switch (localStats.lastCompletedDate, remoteStats.lastCompletedDate) {
        case (let l?, let r?): localStats.lastCompletedDate = max(l, r)
        case (nil, let r?): localStats.lastCompletedDate = r
        default: break
        }
        localStats.streakFreezeAvailable = localStats.streakFreezeAvailable && remoteStats.streakFreezeAvailable
        switch (localStats.streakFreezeUsedDate, remoteStats.streakFreezeUsedDate) {
        case (let l?, let r?): localStats.streakFreezeUsedDate = max(l, r)
        case (nil, let r?): localStats.streakFreezeUsedDate = r
        default: break
        }
        localStats.celebratedMilestones.formUnion(remoteStats.celebratedMilestones)

        return (try? JSONEncoder().encode(localStats)) ?? local
    }

    /// Union of two JSON-encoded arrays of objects (Data blobs), keyed by a
    /// field. Local order is preserved; remote-only items are appended.
    private static func mergeJSONArrayData(idField: String) -> (Any, Any) -> Any {
        return { local, remote in
            let decodedLocal = (local as? Data).flatMap { (try? JSONSerialization.jsonObject(with: $0)) as? [[String: Any]] }
            let decodedRemote = (remote as? Data).flatMap { (try? JSONSerialization.jsonObject(with: $0)) as? [[String: Any]] }
            guard let localArray = decodedLocal else { return decodedRemote != nil ? remote : local }
            guard let remoteArray = decodedRemote else { return local }
            func identity(_ item: [String: Any]) -> String {
                if let string = item[idField] as? String { return string }
                if let value = item[idField] { return String(describing: value) }
                return String(describing: item)
            }
            let localIds = Set(localArray.map(identity))
            let merged = localArray + remoteArray.filter { !localIds.contains(identity($0)) }
            guard merged.count != localArray.count else { return local }
            return (try? JSONSerialization.data(withJSONObject: merged)) ?? local
        }
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

    /// Union of a JSON string-array stored AS a String (quiz titles).
    private static func mergeJSONStringArrayString(_ local: Any, _ remote: Any) -> Any {
        let decodedLocal = (local as? String).flatMap { try? JSONDecoder().decode([String].self, from: Data($0.utf8)) }
        let decodedRemote = (remote as? String).flatMap { try? JSONDecoder().decode([String].self, from: Data($0.utf8)) }
        guard let localArray = decodedLocal else { return decodedRemote != nil ? remote : local }
        guard let remoteArray = decodedRemote else { return local }
        let localString = (local as? String) ?? ""
        let localSet = Set(localArray)
        let merged = localArray + remoteArray.filter { !localSet.contains($0) }
        guard merged.count != localArray.count else { return local }
        guard let data = try? JSONEncoder().encode(merged) else { return local }
        return String(data: data, encoding: .utf8) ?? localString
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
}
