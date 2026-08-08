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
    @Published var justCompleted: Enforcement? {
        didSet {
            guard justCompleted?.id != oldValue?.id else { return }
            if let id = justCompleted?.id {
                defaults.set(id, forKey: pendingCelebrationKey)
            } else {
                defaults.removeObject(forKey: pendingCelebrationKey)
            }
        }
    }

    private(set) var catalog: [Enforcement] = []

    private let defaults: UserDefaults
    private let calendar: Calendar
    private let progressKey = "enforcementProgress"
    private let pendingCelebrationKey = "enforcementPendingCelebration"

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
        if let pendingId = defaults.string(forKey: pendingCelebrationKey) {
            self.justCompleted = self.catalog.first { $0.id == pendingId }
        }
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
    var activeEnforcement: Enforcement? {
        let snapshot = progressSnapshot
        guard snapshot.isActive, let id = snapshot.activeEnforcementId else { return nil }
        return enforcement(id: id)
    }

    /// The day the user is working on right now, or nil when no Enforcement is running.
    var activeDay: EnforcementDay? {
        // One snapshot for both reads — taking two could straddle a mutation and
        // pair a campaign with a day number from the next one.
        let snapshot = progressSnapshot
        guard snapshot.isActive, let id = snapshot.activeEnforcementId,
              let enforcement = enforcement(id: id) else { return nil }
        return enforcement.day(snapshot.currentDay)
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

    /// Starts a campaign. Premium-gated — this is the only gate.
    @discardableResult
    func startEnforcement(id: String, isPremium: Bool) -> Bool {
        guard isPremium, enforcement(id: id) != nil else { return false }
        mutateProgress { p in
            let history = p.completedEnforcementIds
            p = EnforcementProgress()
            p.activeEnforcementId = id
            p.startedOn = Date()
            p.completedEnforcementIds = history
        }
        return true
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
            guard p.isActive, let id = p.activeEnforcementId,
                  let enforcement = self.enforcement(id: id) else {
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
