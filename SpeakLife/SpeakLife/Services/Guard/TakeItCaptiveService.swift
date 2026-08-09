//
//  TakeItCaptiveService.swift
//  SpeakLife
//
//  Owns the thought bank, today's rep, and the ground the user has taken.
//
//  Three rules here are load-bearing:
//
//  1. **Nothing in this file can decrease.** Ground taken only ever goes up, and
//     there is no method that clears it. A "reset" would turn a grace feature
//     into a law feature overnight.
//  2. **The day's thought is PINNED once served.** Rotation reads live signals
//     (engagement weighting, completion count), so re-deriving on every read
//     could hand someone a different thought mid-flow — they would swipe away
//     one lie and be asked to speak the counter to another.
//  3. **Premium is checked when serving, never when finishing.** A subscription
//     that lapses between opening the drill and speaking the line does not cost
//     the user the rep.
//

import Foundation
import FirebaseRemoteConfig

// MARK: - Service

final class TakeItCaptiveService: ObservableObject {

    /// Shared instance so the App Intent (which has no view hierarchy to inherit
    /// from) and the Today tab read the same state.
    static let shared = TakeItCaptiveService()

    /// A thought is not served again until this many days have passed. At one
    /// rep a day against a 120-entry bank, this is comfortably satisfiable.
    static let repeatCooldownDays = 60

    /// Reps completed before intensity 3 is unlocked. Never open a new user with
    /// the heaviest thought in the bank.
    static let intensityThreeUnlocksAfter = 14

    /// Days of intensity-1-only at the start.
    static let gentleOpeningDays = 7

    /// Free tier sees a fixed slice of the bank, in bank order, so the same
    /// three-per-category set is the same on every install.
    static let freeThoughtsPerCategory = 3

    /// Escape-hatch entries a free user gets per calendar month.
    static let freeEscapeHatchesPerMonth = 3

    // MARK: Published

    /// Today's rep. Nil until `thought(isPremium:)` serves one.
    @Published private(set) var todaysThought: IncomingThought?
    /// Cumulative ground. Mirrored from the synced counter so views can bind.
    @Published private(set) var groundTaken: Int = 0
    /// True once today's rep is finished. Drives the checklist row's tick.
    @Published private(set) var completedToday: Bool = false

    private(set) var bank: [IncomingThought] = []

    private let defaults: UserDefaults
    private let calendar: Calendar
    /// Pushes the ground counter out to the user's other devices. Injected so a
    /// unit test can bank ground without standing up CloudKit — the counter
    /// math itself lives in `ProgressSyncStore` and is tested there.
    private let syncCounters: () -> Void

    // Persistence keys.
    private let servedKey = "guardServedThoughts"        // [thoughtId: ISO day]
    private let pinnedKey = "guardPinnedThought"         // "yyyy-MM-dd|thoughtId"
    private let recentCategoriesKey = "guardRecentCategories" // [String], newest last
    private let engagementKey = "guardCategoryEngagement"     // [String: Int]
    private let completionCountKey = "guardCompletionCount"
    private let lastCompletedDayKey = "guardLastCompletedDay"
    private let firstOpenedDayKey = "guardFirstOpenedDay"
    private let escapeHatchMonthKey = "guardEscapeHatchMonth"  // "yyyy-MM"
    private let escapeHatchCountKey = "guardEscapeHatchCount"
    private let logKey = "guardCapturedLog"

    init(defaults: UserDefaults = .standard,
         calendar: Calendar = .current,
         bank: [IncomingThought]? = nil,
         syncCounters: @escaping () -> Void = { ProgressSyncStore.shared.syncCounters() }) {
        self.defaults = defaults
        self.calendar = calendar
        self.syncCounters = syncCounters
        self.bank = bank ?? Self.loadBankFromBundle(defaults: defaults)
        self.groundTaken = GroundTaken.total(defaults: defaults)
        self.completedToday = Self.isToday(defaults.object(forKey: lastCompletedDayKey) as? String,
                                           calendar: calendar)
    }

    // MARK: - Bank loading

    /// Filename lives in `UserDefaults` so a future `thoughts_v2.json` can ship
    /// via Remote Config without a code change — same play as `enforcementsFileName`.
    private static func loadBankFromBundle(defaults: UserDefaults) -> [IncomingThought] {
        let fileName = defaults.string(forKey: "thoughtsFileName") ?? "thoughts.json"
        let resource = fileName.replacingOccurrences(of: ".json", with: "")
        guard let url = Bundle.main.url(forResource: resource, withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("⚠️ TakeItCaptiveService: \(fileName) not found in bundle")
            return []
        }
        do {
            return try JSONDecoder().decode(ThoughtBank.self, from: data).thoughts
        } catch {
            print("⚠️ TakeItCaptiveService: failed to decode \(fileName): \(error)")
            return []
        }
    }

    // MARK: - Serving today's thought

    /// Today's rep, pinned for the calendar day.
    ///
    /// - Parameter isPremium: free users draw from a fixed slice of the bank.
    ///   Checked here and nowhere downstream, so a lapse mid-drill costs nothing.
    func thought(isPremium: Bool) -> IncomingThought? {
        guard !bank.isEmpty else { return nil }
        let today = Self.dayStamp(Date(), calendar: calendar)

        // Pinned already? Hand back the same one — see rule 2 in the header.
        if let pinned = defaults.string(forKey: pinnedKey) {
            let parts = pinned.split(separator: "|", maxSplits: 1).map(String.init)
            if parts.count == 2, parts[0] == today,
               let match = bank.first(where: { $0.id == parts[1] }) {
                if todaysThought?.id != match.id { todaysThought = match }
                return match
            }
        }

        if defaults.string(forKey: firstOpenedDayKey) == nil {
            defaults.set(today, forKey: firstOpenedDayKey)
        }

        guard let pick = selectThought(isPremium: isPremium) else { return nil }
        defaults.set("\(today)|\(pick.id)", forKey: pinnedKey)
        recordServed(pick, on: today)
        todaysThought = pick
        return pick
    }

    /// The rotation. Filters hard, then weights, then falls back rather than
    /// ever returning nil on a non-empty bank — a drill with no thought is a
    /// dead end the user cannot fix.
    private func selectThought(isPremium: Bool) -> IncomingThought? {
        let pool = isPremium ? bank : freeSlice()
        guard !pool.isEmpty else { return nil }

        let ceiling = intensityCeiling()
        let served = servedDays()
        let cutoff = calendar.date(byAdding: .day, value: -Self.repeatCooldownDays, to: Date())

        // Never more than 2 consecutive days from one category.
        let recent = recentCategories()
        let blockedCategory: ThoughtCategory? = {
            guard recent.count >= 2, let last = recent.last, recent[recent.count - 2] == last else {
                return nil
            }
            return last
        }()

        var candidates = pool.filter { thought in
            guard thought.intensity <= ceiling else { return false }
            guard thought.category != blockedCategory else { return false }
            guard let servedDay = served[thought.id],
                  let servedDate = Self.date(from: servedDay, calendar: calendar),
                  let cutoff else { return true }
            return servedDate < cutoff
        }

        // Relax in the order that costs the user least: the cooldown first (a
        // repeat is mildly stale), then the consecutive-category rule, then the
        // intensity ceiling LAST — that one exists to protect new users and is
        // the only filter whose removal could actually land badly.
        if candidates.isEmpty {
            candidates = pool.filter { $0.intensity <= ceiling && $0.category != blockedCategory }
        }
        if candidates.isEmpty {
            candidates = pool.filter { $0.intensity <= ceiling }
        }
        if candidates.isEmpty {
            candidates = pool
        }

        // Weight toward the terrain the user actually engages. Engagement is
        // earned by escape-hatch entries and completed reps, so this converges
        // on where the fight really is rather than on where we guessed it was.
        //
        // Premium only — personalized rotation is a paid line. A free user still
        // gets a real rotation (cooldown, no-repeat-category, intensity ladder),
        // just an unweighted one, so the free tier is never a broken tier.
        //
        // `min(by:)` with a "higher score sorts first" comparator, so this picks
        // the HIGHEST score. Ties break on id so the choice is deterministic —
        // two devices on the same day land on the same thought.
        let weights = isPremium ? engagement() : [:]
        return candidates.min { lhs, rhs in
            let lhsScore = score(lhs, weights: weights, served: served)
            let rhsScore = score(rhs, weights: weights, served: served)
            if lhsScore == rhsScore { return lhs.id < rhs.id }
            return lhsScore > rhsScore
        }
    }

    /// Higher is better. Engagement lifts a category; having been served
    /// recently pushes it down.
    private func score(_ thought: IncomingThought,
                       weights: [String: Int],
                       served: [String: String]) -> Int {
        var value = (weights[thought.category.rawValue] ?? 0) * 10
        if served[thought.id] != nil { value -= 100 }
        return value
    }

    /// The free tier's fixed set: the first N of each category, in bank order.
    /// Deterministic on purpose — every free install sees the same 24, which is
    /// what makes the paid bank ("the full 120, rotating") a real difference
    /// rather than a number on a table.
    func freeSlice() -> [IncomingThought] {
        var perCategory: [ThoughtCategory: Int] = [:]
        return bank.filter { thought in
            let count = perCategory[thought.category, default: 0]
            guard count < Self.freeThoughtsPerCategory else { return false }
            perCategory[thought.category] = count + 1
            return true
        }
    }

    /// 1 for the first week, 2 until the user has 14 reps behind them, then 3.
    func intensityCeiling() -> Int {
        let completions = defaults.integer(forKey: completionCountKey)
        if completions >= Self.intensityThreeUnlocksAfter { return 3 }
        guard let firstDay = defaults.string(forKey: firstOpenedDayKey),
              let firstDate = Self.date(from: firstDay, calendar: calendar) else { return 1 }
        let days = calendar.dateComponents([.day], from: firstDate, to: Date()).day ?? 0
        return days < Self.gentleOpeningDays ? 1 : 2
    }

    // MARK: - Completing a rep

    /// Banks the rep. Idempotent within a calendar day for the daily drill, so a
    /// double-tap cannot inflate the count; escape-hatch and interrupt reps are
    /// each their own ground and always count.
    ///
    /// - Returns: the new cumulative total.
    @discardableResult
    func takeGround(category: ThoughtCategory,
                    thoughtId: String,
                    source: CapturedThought.Source,
                    spoken: Bool) -> Int {
        let today = Self.dayStamp(Date(), calendar: calendar)
        if source == .daily, defaults.string(forKey: lastCompletedDayKey) == today {
            return groundTaken
        }

        let total = GroundTaken.take(defaults: defaults)
        groundTaken = total

        if source == .daily {
            defaults.set(today, forKey: lastCompletedDayKey)
            completedToday = true
            pushRecentCategory(category)
        }
        defaults.set(defaults.integer(forKey: completionCountKey) + 1, forKey: completionCountKey)
        bumpEngagement(category)
        appendLog(CapturedThought(id: UUID(), date: Date(), source: source,
                                  category: category, thoughtId: thoughtId, spoken: spoken))

        // Mirror into the synced rows immediately rather than waiting for the
        // next launch, so a second device sees the ground on its next open.
        syncCounters()
        return total
    }

    /// Refreshes the published mirror from the synced counter. Called when the
    /// Today tab appears, since another device's ground arrives via CloudKit
    /// while this view is off screen.
    func refreshGround() {
        let total = GroundTaken.total(defaults: defaults)
        if total != groundTaken { groundTaken = total }
        completedToday = Self.isToday(defaults.string(forKey: lastCompletedDayKey), calendar: calendar)
    }

    // MARK: - Kill switch

    /// Mirrors `SubscriptionStore.guardEnabled` for callers that have no
    /// SubscriptionStore to read — the checklist generator and the App Intent.
    /// Same Remote Config key, one source of truth.
    var isEnabled: Bool {
        RemoteConfig.remoteConfig()["guardEnabled"].boolValue
    }

    /// `completedToday`, or nil when the pillar is dark — the kill switch is
    /// off, or the bank failed to load and there is nothing to drill with.
    /// `TaskLibrary` reads this: nil leaves the checklist row out entirely
    /// rather than offering a task that cannot be finished.
    ///
    /// Tests exercise `completedToday` directly to stay clear of Remote Config.
    var enabledCompletedToday: Bool? {
        guard isEnabled, !bank.isEmpty else { return nil }
        return completedToday
    }

    // MARK: - Escape hatch quota

    /// How many escape-hatch entries the user has left this month. `nil` means
    /// unlimited (premium).
    func escapeHatchesRemaining(isPremium: Bool) -> Int? {
        guard !isPremium else { return nil }
        return max(0, Self.freeEscapeHatchesPerMonth - escapeHatchesUsedThisMonth())
    }

    func canUseEscapeHatch(isPremium: Bool) -> Bool {
        guard let remaining = escapeHatchesRemaining(isPremium: isPremium) else { return true }
        return remaining > 0
    }

    /// Spends one. Premium spends nothing, so the counter never has to be
    /// unwound if a subscription lapses.
    func recordEscapeHatchUse(isPremium: Bool) {
        guard !isPremium else { return }
        let month = Self.monthStamp(Date(), calendar: calendar)
        if defaults.string(forKey: escapeHatchMonthKey) != month {
            defaults.set(month, forKey: escapeHatchMonthKey)
            defaults.set(0, forKey: escapeHatchCountKey)
        }
        defaults.set(escapeHatchesUsedThisMonth() + 1, forKey: escapeHatchCountKey)
    }

    private func escapeHatchesUsedThisMonth() -> Int {
        let month = Self.monthStamp(Date(), calendar: calendar)
        guard defaults.string(forKey: escapeHatchMonthKey) == month else { return 0 }
        return defaults.integer(forKey: escapeHatchCountKey)
    }

    // MARK: - Terrain (Phase 3 groundwork, read-only today)

    /// The terrain the user has taken the most ground in. Never surfaced as a
    /// diagnosis — the only sentence it is allowed to produce is "You've been
    /// taking a lot of ground in <terrain>".
    func strongestTerrain() -> ThoughtCategory? {
        engagement()
            .compactMap { key, value in
                ThoughtCategory(rawValue: key).map { ($0, value) }
            }
            // Dictionary order is not stable between runs, so ties break on the
            // raw value — otherwise the same data could name a different
            // terrain on each launch.
            .max { lhs, rhs in
                lhs.1 == rhs.1 ? lhs.0.rawValue > rhs.0.rawValue : lhs.1 < rhs.1
            }?.0
    }

    /// The log, newest first. Local-only and capped — this is a record of ground
    /// taken, not a diary, and nothing downstream needs the full history.
    func recentCaptures(limit: Int = 100) -> [CapturedThought] {
        Array(loadLog().suffix(limit).reversed())
    }

    // MARK: - Persistence helpers

    private func servedDays() -> [String: String] {
        defaults.dictionary(forKey: servedKey) as? [String: String] ?? [:]
    }

    private func recordServed(_ thought: IncomingThought, on day: String) {
        var served = servedDays()
        served[thought.id] = day
        defaults.set(served, forKey: servedKey)
    }

    private func recentCategories() -> [ThoughtCategory] {
        (defaults.stringArray(forKey: recentCategoriesKey) ?? []).compactMap(ThoughtCategory.init)
    }

    private func pushRecentCategory(_ category: ThoughtCategory) {
        var recent = defaults.stringArray(forKey: recentCategoriesKey) ?? []
        recent.append(category.rawValue)
        if recent.count > 5 { recent.removeFirst(recent.count - 5) }
        defaults.set(recent, forKey: recentCategoriesKey)
    }

    private func engagement() -> [String: Int] {
        defaults.dictionary(forKey: engagementKey) as? [String: Int] ?? [:]
    }

    private func bumpEngagement(_ category: ThoughtCategory) {
        var weights = engagement()
        weights[category.rawValue, default: 0] += 1
        defaults.set(weights, forKey: engagementKey)
    }

    private func loadLog() -> [CapturedThought] {
        guard let data = defaults.data(forKey: logKey),
              let decoded = try? JSONDecoder().decode([CapturedThought].self, from: data) else { return [] }
        return decoded
    }

    private func appendLog(_ entry: CapturedThought) {
        var log = loadLog()
        log.append(entry)
        if log.count > 500 { log.removeFirst(log.count - 500) }
        if let data = try? JSONEncoder().encode(log) {
            defaults.set(data, forKey: logKey)
        }
    }

    // MARK: - Day stamps

    /// Built per call rather than cached in a static.
    ///
    /// A shared `DateFormatter` would have to have its `timeZone` mutated on
    /// every use (the calendar is injected so tests can pin it), and a mutable
    /// static touched from more than one place is a data race waiting for the
    /// first background caller. Construction is cheap next to the work these
    /// stamps guard.
    private static func formatter(_ format: String, calendar: Calendar) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = format
        formatter.timeZone = calendar.timeZone
        return formatter
    }

    static func dayStamp(_ date: Date, calendar: Calendar) -> String {
        formatter("yyyy-MM-dd", calendar: calendar).string(from: date)
    }

    static func monthStamp(_ date: Date, calendar: Calendar) -> String {
        formatter("yyyy-MM", calendar: calendar).string(from: date)
    }

    static func date(from stamp: String, calendar: Calendar) -> Date? {
        formatter("yyyy-MM-dd", calendar: calendar).date(from: stamp)
    }

    private static func isToday(_ stamp: String?, calendar: Calendar) -> Bool {
        guard let stamp else { return false }
        return stamp == dayStamp(Date(), calendar: calendar)
    }
}
