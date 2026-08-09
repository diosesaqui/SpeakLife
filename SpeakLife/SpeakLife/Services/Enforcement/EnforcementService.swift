//
//  EnforcementService.swift
//  SpeakLife
//
//  Owns the Enforcement catalog and the user's position in a campaign.
//
//  Two rules here carry the whole feature and should not be "tidied" away:
//
//  1. Eligibility reads `totalDaysCompleted`, never `currentStreak`. The streak
//     zeroes on a break; the tenure counter does not. Gating on the streak would
//     hide Enforcements from a 200-day user on the exact morning their streak died —
//     the moment this feature exists to serve.
//  2. Premium is checked in `startEnforcement` only, never in `advanceIfNeeded`. A user
//     whose subscription lapses mid-campaign finishes the campaign.
//

import Foundation
import FirebaseRemoteConfig

// MARK: - Advancement result

enum EnforcementAdvanceResult: Equatable {
    case notActive
    case alreadyAdvancedToday
    case advanced(toDay: Int)
    /// - Parameter elapsedDays: calendar days from start to finish. Seven means
    ///   they never missed; a larger number is a campaign they came back to,
    ///   which is the behavior this feature is really trying to produce.
    case completed(enforcementId: String, elapsedDays: Int)
}

// MARK: - Service

final class EnforcementService: ObservableObject {

    /// Shared instance so `NotificationManager` (itself a singleton) can read the
    /// active day without threading a dependency through every call site.
    static let shared = EnforcementService()

    /// Total days completed required before an Enforcement is offered. Seven, so the
    /// curated foundation week lands first.
    static let eligibilityThreshold = 7

    /// SwiftUI mirror of `progressSnapshot`, written on the main thread only.
    /// Views bind to this; anything off the main thread must read
    /// `progressSnapshot` instead.
    @Published private(set) var progress = EnforcementProgress()

    /// Authoritative state, guarded by `lock`.
    ///
    /// `NotificationManager` schedules from a background queue (BGAppRefreshTask,
    /// the notification operation) while `completeTask` advances on main. Without
    /// the lock those two touch the same `Set<Int>` and `[String]` concurrently —
    /// copy-on-write means a reader can land on a buffer the writer is releasing,
    /// which is a crash, not merely a stale read.
    private var guardedProgress = EnforcementProgress()
    private let lock = NSLock()

    /// Thread-safe read of the authoritative state. Safe from any thread.
    var progressSnapshot: EnforcementProgress {
        lock.lock(); defer { lock.unlock() }
        return guardedProgress
    }

    /// Mutates under the lock, then republishes to SwiftUI on main.
    private func mutateProgress(_ body: (inout EnforcementProgress) -> Void) {
        lock.lock()
        body(&guardedProgress)
        let snapshot = guardedProgress
        lock.unlock()
        persist(snapshot)
        if Thread.isMainThread {
            progress = snapshot
        } else {
            DispatchQueue.main.async { [weak self] in self?.progress = snapshot }
        }
    }

    /// Set when a campaign finishes so the Today tab can present the celebration.
    /// The view clears it once presented, which also clears the persisted id.
    ///
    /// Persisted, not just in-memory: the burst can be completed from a surface
    /// that isn't the Today tab, and if the app is killed before Today next
    /// appears an in-memory-only flag would silently swallow the one celebration
    /// the user earned — along with the next-campaign offer that follows it,
    /// which is the whole re-entry hook.
    /// Stored whole rather than by id: `finish()` clears `assembledEnforcement`,
    /// so a completed curated campaign cannot be looked up again afterwards —
    /// its id was never in the catalog and its content is now gone. Persisting
    /// the campaign itself is the only way the celebration survives a kill.
    @Published var justCompleted: Enforcement? {
        didSet {
            guard justCompleted?.id != oldValue?.id else { return }
            if let enforcement = justCompleted {
                defaults.set(enforcement.id, forKey: pendingCelebrationKey)
                if let data = try? JSONEncoder().encode(enforcement) {
                    defaults.set(data, forKey: pendingCelebrationBlobKey)
                }
            } else {
                defaults.removeObject(forKey: pendingCelebrationKey)
                defaults.removeObject(forKey: pendingCelebrationBlobKey)
            }
        }
    }

    private(set) var catalog: [Enforcement] = []

    private let defaults: UserDefaults
    private let calendar: Calendar
    private let progressKey = "enforcementProgress"
    private let pendingCelebrationKey = "enforcementPendingCelebration"
    private let pendingCelebrationBlobKey = "enforcementPendingCelebrationBlob"
    private let assemblySeedKey = "enforcementAssemblySeed"

    /// Block-based observers deregister by token, not by `self`.
    private var syncedSettingsObserver: NSObjectProtocol?

    init(defaults: UserDefaults = .standard,
         calendar: Calendar = .current,
         catalog: [Enforcement]? = nil) {
        self.defaults = defaults
        self.calendar = calendar
        if let catalog {
            self.catalog = catalog
        } else {
            self.catalog = Self.loadCatalogFromBundle(defaults: defaults)
        }
        let loaded = Self.loadProgress(defaults: defaults, key: progressKey)
        self.guardedProgress = loaded
        self.progress = loaded
        // Re-arm a celebration that was earned but never shown. Property
        // observers don't fire for assignments inside an initializer, so this
        // won't loop back through didSet.
        if let data = defaults.data(forKey: pendingCelebrationBlobKey),
           let stored = try? JSONDecoder().decode(Enforcement.self, from: data) {
            self.justCompleted = stored
        } else if let pendingId = defaults.string(forKey: pendingCelebrationKey) {
            // Installs that banked a celebration before the blob existed.
            self.justCompleted = self.catalog.first { $0.id == pendingId }
        }

        // Progress is read once, here — so a campaign arriving from the user's
        // other device would otherwise sit in UserDefaults unnoticed until the
        // next launch, and this device would go on offering to start a week
        // that is already running. Delivered on main: the block writes
        // @Published state and the recommendation cache.
        syncedSettingsObserver = NotificationCenter.default.addObserver(
            forName: SyncedSettingsStore.settingsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleSyncedSettingsChange(notification)
        }
    }

    deinit {
        if let syncedSettingsObserver {
            NotificationCenter.default.removeObserver(syncedSettingsObserver)
        }
    }

    // MARK: - iCloud sync

    private func handleSyncedSettingsChange(_ notification: Notification) {
        guard let keys = notification.userInfo?["keys"] as? Set<String> else { return }

        // The recommendation is picked from the onboarding category choices,
        // which sync too. A restored device caches its answer before those
        // arrive, so without this it recommends from an empty pick list until
        // the next launch.
        if keys.contains("userSelectedCategories") {
            cachedRecommendedId = nil
        }

        guard keys.contains(progressKey) else { return }
        adoptSyncedProgress()
    }

    /// Picks up the campaign `SyncedSettingsStore` merged into UserDefaults on
    /// another device's behalf.
    ///
    /// Deliberately not routed through `mutateProgress`. That path persists
    /// unconditionally, and writing the blob straight back would re-encode it —
    /// a `Set<Int>` has no stable JSON order — which the store reads as a fresh
    /// local edit and pushes out again, so the two devices would echo at each
    /// other. The store already wrote the authoritative bytes; the common case
    /// here is to catch up to them and write nothing.
    private func adoptSyncedProgress() {
        let synced = Self.loadProgress(defaults: defaults, key: progressKey)

        lock.lock()
        let current = guardedProgress
        // The in-memory copy can legitimately be ahead: the burst may have
        // banked a day in the window between the store's reconcile read and
        // this notification. Merge by the same rules the store used rather than
        // overwriting, so that day is not thrown away.
        let merged = SyncedSettingsStore.mergedEnforcementProgress(current, synced)
        let changed = merged != current
        if changed { guardedProgress = merged }
        lock.unlock()

        // Persist only when the local side still holds something the store's
        // write does not — that really is a local change and has to go out.
        // Everything else is already on disk exactly as the store left it.
        if merged != synced {
            persist(merged)
        }

        // Outside the lock: @Published observers read back into the service.
        guard changed else { return }
        progress = merged
    }

    // MARK: - Catalog

    /// Filename lives in `UserDefaults` so a future `enforcements_v2.json` can ship via
    /// Remote Config without a code change — same play as `declarationsFileName`
    /// in `LocalAPIClient`.
    private static func loadCatalogFromBundle(defaults: UserDefaults) -> [Enforcement] {
        let fileName = defaults.string(forKey: "enforcementsFileName") ?? "enforcements.json"
        let resource = fileName.replacingOccurrences(of: ".json", with: "")
        guard let url = Bundle.main.url(forResource: resource, withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("⚠️ EnforcementService: \(fileName) not found in bundle")
            return []
        }
        do {
            return try JSONDecoder().decode(EnforcementCatalog.self, from: data).enforcements
        } catch {
            print("⚠️ EnforcementService: failed to decode \(fileName): \(error)")
            return []
        }
    }

    func enforcement(id: String) -> Enforcement? {
        catalog.first { $0.id == id }
    }

    /// Reads the guarded snapshot, so this is safe to call from the notification
    /// scheduler as well as from a view body.
    ///
    /// An assembled campaign travels inside progress, so it resolves without the
    /// declaration pool — which the scheduler does not have on its queue.
    var activeEnforcement: Enforcement? {
        resolve(progressSnapshot)
    }

    /// The day the user is working on right now, or nil when nothing is running.
    var activeDay: EnforcementDay? {
        // One snapshot for both reads — taking two could straddle a mutation and
        // pair a campaign with a day number from the next one.
        let snapshot = progressSnapshot
        guard let enforcement = resolve(snapshot) else { return nil }
        return enforcement.day(snapshot.currentDay)
    }

    private func resolve(_ snapshot: EnforcementProgress) -> Enforcement? {
        guard snapshot.isActive else { return nil }
        if let assembled = snapshot.assembledEnforcement { return assembled }
        guard let id = snapshot.activeEnforcementId else { return nil }
        return enforcement(id: id)
    }

    /// Mirrors `SubscriptionStore.enforcementEnabled` for callers that have no
    /// SubscriptionStore to read — the checklist generator and
    /// `NotificationManager`. Same Remote Config key, one source of truth.
    var isEnabled: Bool {
        RemoteConfig.remoteConfig()["enforcementEnabled"].boolValue
    }

    /// `activeDay`, or nil when the kill switch is off. Non-UI surfaces use this
    /// so flipping `enforcementEnabled` takes them dark without a second check. Tests
    /// exercise `activeDay` directly to stay clear of Remote Config.
    var enabledActiveDay: EnforcementDay? {
        isEnabled ? activeDay : nil
    }

    // MARK: - Eligibility

    /// - Parameter totalDaysCompleted: `StreakStats.totalDaysCompleted` — the
    ///   monotonic tenure counter, not `currentStreak`.
    func isEligible(totalDaysCompleted: Int) -> Bool {
        totalDaysCompleted >= Self.eligibilityThreshold
    }

    /// The Enforcement to lead with, matched to the user's strongest stated intent.
    /// Falls back to the first in the catalog so the picker is never empty.
    ///
    /// Resolved once per launch and cached. `UserSelectedCategories.all()` runs a
    /// `JSONDecoder` over `UserDefaults`, and this is read from `EnforcementCard.body`
    /// — i.e. on every layout pass of a card inside a ScrollView — so an uncached
    /// call would decode JSON during scrolling. The categories it reads are set
    /// at onboarding and change at most a handful of times per install; the cost
    /// of that staleness is a highlight ring on the wrong chip until relaunch.
    func recommendedEnforcement() -> Enforcement? {
        if let cachedRecommendedId {
            return cachedRecommendedId.flatMap { enforcement(id: $0) }
        }
        var resolved: Enforcement?
        for pick in UserSelectedCategories.all() {
            if let match = catalog.first(where: { $0.theme.caseInsensitiveCompare(pick) == .orderedSame }) {
                resolved = match
                break
            }
        }
        let result = resolved ?? catalog.first
        cachedRecommendedId = .some(result?.id)
        return result
    }

    /// Double optional: outer nil means "not resolved yet", inner nil means
    /// "resolved to nothing" (empty catalog), so an empty catalog isn't retried
    /// on every layout pass.
    private var cachedRecommendedId: String??

    // MARK: - Mutations

    /// Starts one of the hand-authored campaigns. Premium-gated — the only gate.
    @discardableResult
    func startEnforcement(id: String, isPremium: Bool) -> Bool {
        guard isPremium, enforcement(id: id) != nil else { return false }
        begin(id: id, assembled: nil)
        return true
    }

    /// Starts a campaign built for what the user actually said they're facing.
    ///
    /// An authored campaign wins when its category is the top match — those have
    /// a deliberate day-to-day arc that a draw from the pool cannot reproduce.
    /// Everything else assembles from the reviewed declarations, which is what
    /// takes coverage from four categories to twenty-nine.
    ///
    /// - Parameter pool: `declarationsv10.json`, passed in by the caller because
    ///   it loads asynchronously and this service must stay usable from the
    ///   notification scheduler, which has no access to it.
    /// - Returns: the campaign that started, or nil if nothing could be built.
    @discardableResult
    func startMatched(primary: DeclarationCategory,
                      secondaries: [DeclarationCategory] = [],
                      pool: [Declaration],
                      isPremium: Bool) -> Enforcement? {
        guard isPremium else { return nil }

        // Authored campaigns take precedence for their own category.
        if let authored = catalog.first(where: { $0.theme.caseInsensitiveCompare(primary.rawValue) == .orderedSame }) {
            begin(id: authored.id, assembled: nil)
            return authored
        }

        guard let assembled = EnforcementAssembler.assemble(
            primary: primary, secondaries: secondaries,
            pool: pool, seed: assemblySeed
        ) else { return nil }

        begin(id: assembled.id, assembled: assembled)
        return assembled
    }

    /// Starts a campaign Claude curated from the user's own words.
    ///
    /// The declarations still come from the reviewed pool — the model returned
    /// indexes, not text — so this is the same content with a better ordering
    /// and a better fit to what they described.
    @discardableResult
    func startCurated(_ curated: [Declaration],
                      primary: DeclarationCategory,
                      isPremium: Bool) -> Enforcement? {
        guard isPremium,
              let enforcement = EnforcementAssembler.assemble(curated: curated, primary: primary)
        else { return nil }
        begin(id: enforcement.id, assembled: enforcement)
        return enforcement
    }

    /// The reviewed declarations to put in front of the curator.
    func curationCandidates(primary: DeclarationCategory,
                            secondaries: [DeclarationCategory],
                            pool: [Declaration]) -> [Declaration] {
        EnforcementAssembler.candidates(for: [primary] + secondaries,
                                        in: pool, seed: assemblySeed)
    }

    /// Stable per install, so a campaign draws the same lines every launch while
    /// two users facing the same thing don't get identical weeks.
    private var assemblySeed: String {
        if let existing = defaults.string(forKey: assemblySeedKey) { return existing }
        let seed = UUID().uuidString
        defaults.set(seed, forKey: assemblySeedKey)
        return seed
    }

    private func begin(id: String, assembled: Enforcement?) {
        mutateProgress { p in
            let history = p.completedEnforcementIds
            p = EnforcementProgress()
            p.activeEnforcementId = id
            p.assembledEnforcement = assembled
            p.startedOn = Date()
            p.completedEnforcementIds = history
        }
    }

    /// Marks today's Enforcement day complete. Called when the daily burst completes.
    ///
    /// Idempotent within a calendar day, and deliberately **not** premium-gated
    /// so a lapsed subscriber still finishes the campaign they started.
    @discardableResult
    func advanceIfNeeded(now: Date = Date()) -> EnforcementAdvanceResult {
        var result: EnforcementAdvanceResult = .notActive
        var finished: Enforcement?

        // The whole read-decide-write runs inside one lock hold, so two callers
        // racing (burst on main, anything else off it) can't both see the same
        // day as un-advanced and burn two days for one burst.
        mutateProgress { p in
            // `resolve`, not `enforcement(id:)`. An assembled or curated campaign
            // lives in `p.assembledEnforcement` and its id ("curated_warfare") is
            // not in the catalog, so a catalog-only lookup returned nil and this
            // reported `.notActive` for it — no day was ever banked, and every
            // campaign built from the user's own words sat on day 1 forever.
            guard p.isActive, let enforcement = self.resolve(p) else {
                result = .notActive
                return
            }
            guard !p.hasAdvancedToday(calendar: self.calendar, now: now) else {
                result = .alreadyAdvancedToday
                return
            }

            p.completedDayNumbers.insert(p.currentDay)
            p.lastAdvancedOn = now

            if p.isComplete {
                // Read before finish() clears it.
                let elapsed = p.startedOn.map {
                    (self.calendar.dateComponents([.day], from: $0, to: now).day ?? 0) + 1
                } ?? Enforcement.length
                p.finish()
                finished = enforcement
                result = .completed(enforcementId: enforcement.id,
                                    elapsedDays: max(elapsed, Enforcement.length))
            } else {
                result = .advanced(toDay: p.currentDay)
            }
        }

        // Outside the lock: `justCompleted` is a @Published the UI observes, and
        // publishing while holding the lock invites a deadlock via an observer
        // that reads back into the service.
        if let finished {
            if Thread.isMainThread {
                justCompleted = finished
            } else {
                DispatchQueue.main.async { [weak self] in self?.justCompleted = finished }
            }
        }
        return result
    }

    /// Drops the active campaign without banking it as completed.
    func abandon() {
        mutateProgress { p in
            p.activeEnforcementId = nil
            p.startedOn = nil
            p.completedDayNumbers = []
            p.lastAdvancedOn = nil
        }
    }

    // MARK: - Persistence

    private static func loadProgress(defaults: UserDefaults, key: String) -> EnforcementProgress {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(EnforcementProgress.self, from: data) else {
            return EnforcementProgress()
        }
        return decoded
    }

    /// Writes the exact snapshot that was just committed under the lock, rather
    /// than re-reading state that another thread may have moved on from.
    private func persist(_ snapshot: EnforcementProgress) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: progressKey)
    }
}
