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

// MARK: - Service

final class TakeItCaptiveService: ObservableObject {

    /// Shared instance so the App Intent (which has no view hierarchy to inherit
    /// from) and the Today tab read the same state.
    static let shared = TakeItCaptiveService()

    /// A thought is not served again until this many days have passed. At one
    /// rep a day against a 135-entry bank, this is comfortably satisfiable.
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
    /// SwiftUI mirror of `isCompletedToday`, for views that want to observe it.
    ///
    /// **Never read this to decide anything.** It is a cached boolean, and the
    /// day it was cached on is not stored alongside it — so at midnight it still
    /// says `true` for yesterday. Every decision reads `isCompletedToday`, which
    /// re-derives from the stored day stamp. The bug this note exists for: the
    /// checklist rebuild at rollover pre-ticked the new day's Guard row.
    @Published private(set) var completedToday: Bool = false

    /// Stamped by `TakeThoughtCaptiveIntent` when the app is already running.
    /// `HomeView` switches to the Today tab on it and `ModernDailyChecklistView`
    /// presents the drill; both clear it. See the note in
    /// `TakeThoughtCaptiveIntent.swift` for why the persisted stamp is not
    /// enough on its own.
    @Published var launchRequestedAt: Date?

    private(set) var bank: [IncomingThought] = []

    private let defaults: UserDefaults
    private let calendar: Calendar
    private let featureFlags: FeatureFlagProviding
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
         syncCounters: @escaping () -> Void = { ProgressSyncStore.shared.syncCounters() },
         featureFlags: FeatureFlagProviding = DefaultFeatureFlags.shared) {
        self.defaults = defaults
        self.calendar = calendar
        self.syncCounters = syncCounters
        self.featureFlags = featureFlags
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
        // Annotated rather than inferred: a bare `[:]` on one arm of a ternary
        // makes the compiler solve the literal's type through the branch.
        let weights: [String: Int] = isPremium ? engagement() : [:]
        return candidates.min { lhs, rhs in
            let lhsScore: Int = score(lhs, weights: weights, served: served)
            let rhsScore: Int = score(rhs, weights: weights, served: served)
            if lhsScore == rhsScore { return lhs.id < rhs.id }
            return lhsScore > rhsScore
        }
    }

    /// Higher is better. Engagement lifts a category; recency pushes down.
    ///
    /// Recency is measured in DAYS, not as a boolean "has been served".
    ///
    /// That distinction is the whole function. The free pool holds 24 thoughts
    /// against a 60-day cooldown, so from about day 25 every candidate has been
    /// served and the cooldown filter relaxes away. With a flat penalty every
    /// candidate then scored identically, the id tie-break fired, and the same
    /// thought was served every single day from then on — a free user's drill
    /// quietly froze. Scoring by how long ago turns the exhausted case into a
    /// proper least-recently-used rotation instead.
    ///
    /// Every step is explicitly `Int` and on its own line. Nested generic
    /// `min`/`max` over integer literals mixed with arithmetic is one of the
    /// shapes that costs the type checker real time, and this file already
    /// failed an archive over exactly that class of expression.
    private func score(_ thought: IncomingThought,
                       weights: [String: Int],
                       served: [String: String]) -> Int {
        let categoryWeight: Int = weights[thought.category.rawValue] ?? 0
        let engagementBonus: Int = categoryWeight * 10

        guard let servedDay = served[thought.id],
              let servedDate = Self.date(from: servedDay, calendar: calendar) else {
            // Never served always wins, whatever the weighting says. A thought
            // they have not seen beats one they have.
            return engagementBonus + Self.neverServedBonus
        }

        let daysAgo: Int = calendar.dateComponents([.day], from: servedDate, to: Date()).day ?? 0
        let recencyCeiling: Int = Self.neverServedBonus - 1
        var recencyBonus: Int = daysAgo
        if recencyBonus < 0 { recencyBonus = 0 }
        if recencyBonus > recencyCeiling { recencyBonus = recencyCeiling }
        return engagementBonus + recencyBonus
    }

    /// Big enough that no engagement weighting can lift a recently-served
    /// thought over an unseen one, and that a served thought can never reach it.
    private static let neverServedBonus = 10_000

    /// The free tier's fixed set: the first N of each category, in bank order.
    /// Deterministic on purpose — every free install sees the same 27, which is
    /// what makes the paid bank ("the full 135, rotating") a real difference
    /// rather than a number on a table.
    func freeSlice() -> [IncomingThought] {
        var perCategory: [ThoughtCategory: Int] = [:]
        var slice: [IncomingThought] = []
        for thought in bank {
            let count: Int = perCategory[thought.category] ?? 0
            guard count < Self.freeThoughtsPerCategory else { continue }
            perCategory[thought.category] = count + 1
            slice.append(thought)
        }
        return slice
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

    /// Banks the rep.
    ///
    /// - Parameter source: where the THOUGHT came from — the bank, the escape
    ///   hatch, or an interrupt. Recorded in the log.
    /// - Parameter completesDailyRep: whether this rep was the day's drill.
    ///
    /// These two are deliberately separate. Someone who opens the daily drill
    /// and taps "Something else is on my mind" has still done today's rep, and
    /// the checklist row they launched from has to tick — but the log should
    /// record honestly that the thought was their own, not one we served. Fusing
    /// the two left that row unchecked after a completed drill.
    ///
    /// Idempotent within a calendar day when `completesDailyRep` is true, so a
    /// double-tap cannot inflate the count. Extra reps beyond the day's drill
    /// are each their own ground and always count.
    ///
    /// - Returns: the new cumulative total.
    @discardableResult
    func takeGround(category: ThoughtCategory,
                    thoughtId: String,
                    source: CapturedThought.Source,
                    spoken: Bool,
                    completesDailyRep: Bool) -> Int {
        let today = Self.dayStamp(Date(), calendar: calendar)
        if completesDailyRep, defaults.string(forKey: lastCompletedDayKey) == today {
            return groundTaken
        }

        let total = GroundTaken.take(defaults: defaults)
        groundTaken = total

        if completesDailyRep {
            defaults.set(today, forKey: lastCompletedDayKey)
            completedToday = true
            pushRecentCategory(category)
            // Only day-reps advance the intensity ladder. Counting every rep let
            // fourteen escape-hatch entries on day one unlock intensity 3 on day
            // two, which is exactly the gentle opening the ladder exists to
            // protect. Someone reaching for the hatch that often is carrying
            // enough already.
            defaults.set(defaults.integer(forKey: completionCountKey) + 1,
                         forKey: completionCountKey)
        }
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
        let done = isCompletedToday
        if done != completedToday { completedToday = done }
    }

    // MARK: - Kill switch

    /// Mirrors `SubscriptionStore.guardEnabled` for callers that have no
    /// SubscriptionStore to read — the checklist generator and the App Intent.
    /// Same Remote Config key, one source of truth.
    var isEnabled: Bool {
        featureFlags.bool("guardEnabled", default: false)
    }

    /// Whether today's rep is done, re-derived from the stored day stamp on
    /// every read rather than cached. The authoritative answer — see the note
    /// on `completedToday`.
    var isCompletedToday: Bool {
        Self.isToday(defaults.string(forKey: lastCompletedDayKey), calendar: calendar)
    }

    /// `isCompletedToday`, or nil when the pillar is dark — the kill switch is
    /// off, or the bank failed to load and there is nothing to drill with.
    /// `TaskLibrary` reads this: nil leaves the checklist row out entirely
    /// rather than offering a task that cannot be finished.
    var enabledCompletedToday: Bool? {
        guard isEnabled, !bank.isEmpty else { return nil }
        return isCompletedToday
    }

    // MARK: - Escape hatch quota

    /// How many escape-hatch entries the user has left this month. `nil` means
    /// unlimited (premium).
    func escapeHatchesRemaining(isPremium: Bool) -> Int? {
        guard !isPremium else { return nil }
        let used: Int = escapeHatchesUsedThisMonth()
        let remaining: Int = Self.freeEscapeHatchesPerMonth - used
        return remaining > 0 ? remaining : 0
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
    ///
    /// Written as a plain loop rather than `compactMap` + `max(by:)`.
    ///
    /// The chained version inferred a tuple type through two generic
    /// higher-order functions and compared across both members inside a ternary,
    /// and the Swift type checker could not solve it in reasonable time — it
    /// failed the Xcode Cloud archive outright. A loop is also easier to read
    /// than the comparator was, so nothing is lost.
    func strongestTerrain() -> ThoughtCategory? {
        var bestCategory: ThoughtCategory?
        var bestCount: Int = 0

        for (key, count) in engagement() {
            guard let category = ThoughtCategory(rawValue: key) else { continue }
            guard let currentBest = bestCategory else {
                bestCategory = category
                bestCount = count
                continue
            }
            if count > bestCount {
                bestCategory = category
                bestCount = count
            } else if count == bestCount, category.rawValue < currentBest.rawValue {
                // Dictionary order is not stable between runs, so ties break on
                // the raw value — otherwise the same data could name a different
                // terrain on each launch.
                bestCategory = category
            }
        }
        return bestCategory
    }

    /// The log, newest first. Local-only and capped — this is a record of ground
    /// taken, not a diary, and nothing downstream needs the full history.
    func recentCaptures(limit: Int = 100) -> [CapturedThought] {
        let log: [CapturedThought] = loadLog()
        let tail: [CapturedThought] = Array(log.suffix(limit))
        return tail.reversed()
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
        // `compactMap(ThoughtCategory.init)` made the compiler resolve an
        // unapplied initializer reference against every init the type has,
        // including the synthesized Decodable one. Spelled out, there is
        // nothing to resolve.
        let raw: [String] = defaults.stringArray(forKey: recentCategoriesKey) ?? []
        return raw.compactMap { ThoughtCategory(rawValue: $0) }
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
