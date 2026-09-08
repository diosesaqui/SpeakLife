//
//  MagnifyService.swift
//  SpeakLifeServices
//
//  Owns the facet bank, today's rep, and the count of times the user has
//  magnified the Lord.
//
//  This is the rotation engine from `TakeItCaptiveService` carried across
//  essentially intact — day-pinning, the 60-day cooldown, least-recently-used
//  scoring, the intensity ladder, the free slice, engagement weighting. Every
//  one of those was argued out and paid for once, several of them by a shipped
//  bug, and inverting the feature changed none of the reasons. What changed is
//  what is being served and what it is called.
//
//  Four rules here are load-bearing:
//
//  1. **Nothing in this file can decrease.** The count only ever goes up, and
//     there is no method that clears it. A "reset" would turn a grace feature
//     into a law feature overnight.
//  2. **The day's facet is PINNED once served.** Rotation reads live signals
//     (engagement weighting, completion count), so re-deriving on every read
//     could hand someone a different facet mid-flow — they would behold one name
//     of God and be asked to speak the line belonging to another.
//  3. **Premium is checked when serving, never when finishing.** A subscription
//     that lapses between opening the rep and speaking the line does not cost
//     the user the rep.
//  4. **Storm mode is never metered, never pinned, and never gated.** Someone
//     who reaches for it at 2am gets a name of God and a line to say, free or
//     paid, first rep or four-hundredth. It does not consume the day's pin, so a
//     storm at midnight does not spend the facet the morning rep would have had.
//
//  ## Continuity across the rename
//
//  Storage keys split deliberately, on one question: would the user NOTICE?
//
//  - Kept, because they would: the count itself (`TimesMagnified.counterKey`),
//    today's completion stamp, the completion count that drives the ladder, and
//    the first-opened day that drives tenure. A four-hundred-rep user keeps
//    their number, keeps today's tick, and does not get demoted to the gentlest
//    facets in the bank on upgrade day.
//  - Migrated once: engagement weights, mapped through
//    `MagnifyDomain.fromLegacyRawValue`. This is the signal for where a person's
//    fight actually is, and it is expensive to re-earn.
//  - Started fresh, because the ids changed and a stale value would point at
//    nothing: served history and the day's pin.
//

import Foundation
import SpeakLifeCore
import SpeakLifePersistence

// MARK: - Service

public final class MagnifyService: ObservableObject {

    /// Shared instance so the App Intent (which has no view hierarchy to inherit
    /// from) and the Today tab read the same state.
    public static let shared = MagnifyService()

    /// A facet is not served again until this many days have passed. At one rep
    /// a day against a 135-entry bank, this is comfortably satisfiable.
    public static let repeatCooldownDays = 60

    /// Reps completed before intensity 3 is unlocked.
    public static let intensityThreeUnlocksAfter = 14

    /// Days of intensity-1-only at the start.
    public static let gentleOpeningDays = 7

    /// Free tier sees a fixed slice of the bank, in bank order, so the same
    /// three-per-domain set is the same on every install.
    public static let freeEntriesPerDomain = 3

    /// Written-route entries a free user gets per calendar month, on EXTRA reps
    /// only. The day's own rep is never metered — see `MagnifyFlowView`.
    public static let freeWrittenEntriesPerMonth = 3

    // MARK: Published

    /// Today's rep. Nil until `entry(isPremium:domain:)` serves one.
    @Published public private(set) var todaysEntry: MagnifyEntry?
    /// Cumulative count. Mirrored from the synced counter so views can bind.
    @Published public private(set) var timesMagnified: Int = 0
    /// SwiftUI mirror of `isCompletedToday`, for views that want to observe it.
    ///
    /// **Never read this to decide anything.** It is a cached boolean, and the
    /// day it was cached on is not stored alongside it — so at midnight it still
    /// says `true` for yesterday. Every decision reads `isCompletedToday`, which
    /// re-derives from the stored day stamp. The bug this note exists for: the
    /// checklist rebuild at rollover pre-ticked the new day's row.
    @Published public private(set) var completedToday: Bool = false

    /// Stamped by `MagnifyTheLordIntent` when the app is already running.
    /// `HomeView` switches to the Today tab on it and `ModernDailyChecklistView`
    /// presents the flow; both clear it.
    @Published public var launchRequestedAt: Date?

    public private(set) var bank: [MagnifyEntry] = []
    public private(set) var whyLines: [String] = []

    private let defaults: UserDefaults
    private let calendar: Calendar
    private let featureFlags: FeatureFlagProviding
    /// Pushes the counter out to the user's other devices. Injected so a unit
    /// test can bank a rep without standing up CloudKit — the counter math lives
    /// in `ProgressSyncStore` and is tested there.
    private let syncCounters: () -> Void

    // Persistence keys. See the continuity note in the file header for why some
    // of these still say "guard".
    private let servedKey = "magnifyServedEntries"          // [entryId: ISO day]
    private let pinnedKey = "magnifyPinnedEntry"            // "yyyy-MM-dd|entryId"
    private let recentDomainsKey = "magnifyRecentDomains"   // [String], newest last
    private let engagementKey = "magnifyDomainEngagement"   // [String: Int]
    private let engagementMigratedKey = "magnifyEngagementMigrated"
    private let legacyEngagementKey = "guardCategoryEngagement"
    private let logKey = "magnifyLog"
    private let seenWhyKey = "magnifySeenWhy"
    /// Kept from the drill this replaces — a returning user must not lose these.
    private let completionCountKey = "guardCompletionCount"
    private let lastCompletedDayKey = "guardLastCompletedDay"
    private let firstOpenedDayKey = "guardFirstOpenedDay"
    private let writtenMonthKey = "guardEscapeHatchMonth"   // "yyyy-MM"
    private let writtenCountKey = "guardEscapeHatchCount"

    public init(defaults: UserDefaults = .standard,
                calendar: Calendar = .current,
                bank: [MagnifyEntry]? = nil,
                whyLines: [String]? = nil,
                syncCounters: @escaping () -> Void = { ProgressSyncStore.shared.syncCounters() },
                featureFlags: FeatureFlagProviding = DefaultFeatureFlags.shared) {
        self.defaults = defaults
        self.calendar = calendar
        self.syncCounters = syncCounters
        self.featureFlags = featureFlags
        // Annotated, and only loaded when something is actually missing: a test
        // that supplies both must never touch Bundle.main.
        let loaded: MagnifyBank?
        if bank == nil || whyLines == nil {
            loaded = Self.loadBankFromBundle(defaults: defaults)
        } else {
            loaded = nil
        }
        self.bank = bank ?? loaded?.entries ?? []
        self.whyLines = whyLines ?? loaded?.whyLines ?? []
        self.timesMagnified = TimesMagnified.total(defaults: defaults)
        self.completedToday = Self.isToday(defaults.object(forKey: lastCompletedDayKey) as? String,
                                           calendar: calendar)
        migrateLegacyEngagement()
    }

    // MARK: - Bank loading

    /// Filename lives in `UserDefaults` so a future `magnify_v2.json` can ship
    /// via Remote Config without a code change — same play as
    /// `enforcementsFileName` and `thoughtsFileName`.
    private static func loadBankFromBundle(defaults: UserDefaults) -> MagnifyBank? {
        let fileName = defaults.string(forKey: "magnifyFileName") ?? "magnify.json"
        let resource = fileName.replacingOccurrences(of: ".json", with: "")
        guard let url = Bundle.main.url(forResource: resource, withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("⚠️ MagnifyService: \(fileName) not found in bundle")
            return nil
        }
        do {
            return try JSONDecoder().decode(MagnifyBank.self, from: data)
        } catch {
            print("⚠️ MagnifyService: failed to decode \(fileName): \(error)")
            return nil
        }
    }

    // MARK: - Migration

    /// Carries engagement weights across the rename, exactly once.
    ///
    /// Engagement is what makes the rotation converge on where a person's fight
    /// actually is, and it is earned one rep at a time over months. Dropping it
    /// would have quietly reset every long-tenured user to an unweighted
    /// rotation on upgrade day, and nothing on screen would have explained why
    /// the app suddenly felt generic.
    private func migrateLegacyEngagement() {
        guard !defaults.bool(forKey: engagementMigratedKey) else { return }
        defaults.set(true, forKey: engagementMigratedKey)

        guard let legacy = defaults.dictionary(forKey: legacyEngagementKey) as? [String: Int],
              !legacy.isEmpty else { return }

        var migrated = engagement()
        for (rawValue, count) in legacy {
            guard let domain = MagnifyDomain.fromLegacyRawValue(rawValue) else { continue }
            migrated[domain.rawValue, default: 0] += count
        }
        defaults.set(migrated, forKey: engagementKey)
    }

    // MARK: - Serving today's facet

    /// Today's rep, pinned for the calendar day.
    ///
    /// - Parameter isPremium: free users draw from a fixed slice of the bank.
    ///   Checked here and nowhere downstream, so a lapse mid-rep costs nothing.
    /// - Parameter domain: the domain the user tapped, or nil to let the
    ///   rotation choose. A tapped domain is honoured over the weighting — they
    ///   just told us where they need Him lifted, which beats any inference.
    public func entry(isPremium: Bool, domain: MagnifyDomain? = nil) -> MagnifyEntry? {
        guard !bank.isEmpty else { return nil }
        let today = Self.dayStamp(Date(), calendar: calendar)

        // Pinned already? Hand back the same one — see rule 2 in the header.
        // A domain tap overrides the pin: it is new information from the user,
        // arriving after the pin was set, and honouring the stale pin would mean
        // ignoring the one thing they explicitly told us.
        if domain == nil, let pinned = defaults.string(forKey: pinnedKey) {
            let parts = pinned.split(separator: "|", maxSplits: 1).map(String.init)
            if parts.count == 2, parts[0] == today,
               let match = bank.first(where: { $0.id == parts[1] }) {
                if todaysEntry?.id != match.id { todaysEntry = match }
                return match
            }
        }

        if defaults.string(forKey: firstOpenedDayKey) == nil {
            defaults.set(today, forKey: firstOpenedDayKey)
        }

        guard let pick = select(isPremium: isPremium, domain: domain) else { return nil }
        defaults.set("\(today)|\(pick.id)", forKey: pinnedKey)
        recordServed(pick, on: today)
        todaysEntry = pick
        return pick
    }

    /// Storm mode: a facet, right now, no questions and no bookkeeping.
    ///
    /// Deliberately does NOT pin, does NOT consult premium, and does NOT consume
    /// the day's rotation. Someone reaching for this is not shopping — they need
    /// a name of God in their mouth in under thirty seconds. Metering that, or
    /// spending the morning's facet on it, would both be answers to a question
    /// nobody in a storm is asking.
    ///
    /// Draws from the whole bank at the user's current ceiling, least recently
    /// served first, so repeated use inside one hard week still rotates.
    public func stormEntry() -> MagnifyEntry? {
        guard !bank.isEmpty else { return nil }
        let ceiling = intensityCeiling()
        let served = servedDays()
        var pool = bank.filter { $0.intensity <= ceiling }
        if pool.isEmpty { pool = bank }
        return pool.min { lhs, rhs in
            let lhsScore: Int = score(lhs, weights: engagement(), served: served)
            let rhsScore: Int = score(rhs, weights: engagement(), served: served)
            if lhsScore == rhsScore { return lhs.id < rhs.id }
            return lhsScore > rhsScore
        }
    }

    /// The rotation. Filters hard, then weights, then falls back rather than ever
    /// returning nil on a non-empty bank — a rep with no facet is a dead end the
    /// user cannot fix.
    private func select(isPremium: Bool, domain: MagnifyDomain?) -> MagnifyEntry? {
        var pool = isPremium ? bank : freeSlice()
        if let domain {
            let inDomain = pool.filter { $0.domain == domain }
            // A free user who taps a domain still gets that domain — their slice
            // holds three of each, which is exactly why the slice is built per
            // domain rather than as a flat prefix.
            if !inDomain.isEmpty { pool = inDomain }
        }
        guard !pool.isEmpty else { return nil }

        let ceiling = intensityCeiling()
        let served = servedDays()
        let cutoff = calendar.date(byAdding: .day, value: -Self.repeatCooldownDays, to: Date())

        // Never more than 2 consecutive days from one domain — unless they asked
        // for it, in which case it is not a rut, it is a request.
        let recent = recentDomains()
        let blockedDomain: MagnifyDomain? = {
            guard domain == nil, recent.count >= 2, let last = recent.last,
                  recent[recent.count - 2] == last else { return nil }
            return last
        }()

        var candidates = pool.filter { entry in
            guard entry.intensity <= ceiling else { return false }
            guard entry.domain != blockedDomain else { return false }
            guard let servedDay = served[entry.id],
                  let servedDate = Self.date(from: servedDay, calendar: calendar),
                  let cutoff else { return true }
            return servedDate < cutoff
        }

        // Relax in the order that costs the user least: the cooldown first (a
        // repeat is mildly stale), then the consecutive-domain rule, then the
        // intensity ceiling LAST — that one exists to protect new users and is
        // the only filter whose removal could actually land badly.
        if candidates.isEmpty {
            candidates = pool.filter { $0.intensity <= ceiling && $0.domain != blockedDomain }
        }
        if candidates.isEmpty {
            candidates = pool.filter { $0.intensity <= ceiling }
        }
        if candidates.isEmpty {
            candidates = pool
        }

        // Weight toward the domain the user actually engages. Engagement is
        // earned by domain taps and completed reps, so this converges on where
        // the fight really is rather than on where we guessed it was.
        //
        // Premium only — personalized rotation is a paid line. A free user still
        // gets a real rotation (cooldown, no-repeat-domain, intensity ladder),
        // just an unweighted one, so the free tier is never a broken tier.
        //
        // `min(by:)` with a "higher score sorts first" comparator, so this picks
        // the HIGHEST score. Ties break on id so the choice is deterministic —
        // two devices on the same day land on the same facet. Annotated rather
        // than inferred: a bare `[:]` on one arm of a ternary makes the compiler
        // solve the literal's type through the branch.
        let weights: [String: Int] = isPremium ? engagement() : [:]
        return candidates.min { lhs, rhs in
            let lhsScore: Int = score(lhs, weights: weights, served: served)
            let rhsScore: Int = score(rhs, weights: weights, served: served)
            if lhsScore == rhsScore { return lhs.id < rhs.id }
            return lhsScore > rhsScore
        }
    }

    /// Higher is better. Engagement lifts a domain; recency pushes down.
    ///
    /// Recency is measured in DAYS, not as a boolean "has been served".
    ///
    /// That distinction is the whole function, and it is here because the drill
    /// this replaces shipped without it. The free pool holds 27 entries against a
    /// 60-day cooldown, so from about day 28 every candidate has been served and
    /// the cooldown filter relaxes away. With a flat penalty every candidate then
    /// scored identically, the id tie-break fired, and the same entry was served
    /// every single day from then on — a free user's rep quietly froze. Scoring
    /// by how long ago turns the exhausted case into a proper least-recently-used
    /// rotation instead.
    ///
    /// Every step is explicitly `Int` and on its own line. Nested generic
    /// `min`/`max` over integer literals mixed with arithmetic is one of the
    /// shapes that costs the type checker real time, and the file this was ported
    /// from failed an archive over exactly that class of expression.
    private func score(_ entry: MagnifyEntry,
                       weights: [String: Int],
                       served: [String: String]) -> Int {
        let domainWeight: Int = weights[entry.domain.rawValue] ?? 0
        let engagementBonus: Int = domainWeight * 10

        guard let servedDay = served[entry.id],
              let servedDate = Self.date(from: servedDay, calendar: calendar) else {
            // Never served always wins, whatever the weighting says. A facet they
            // have not beheld beats one they have.
            return engagementBonus + Self.neverServedBonus
        }

        let daysAgo: Int = calendar.dateComponents([.day], from: servedDate, to: Date()).day ?? 0
        let recencyCeiling: Int = Self.neverServedBonus - 1
        var recencyBonus: Int = daysAgo
        if recencyBonus < 0 { recencyBonus = 0 }
        if recencyBonus > recencyCeiling { recencyBonus = recencyCeiling }
        return engagementBonus + recencyBonus
    }

    /// Big enough that no engagement weighting can lift a recently-served entry
    /// over an unseen one, and that a served entry can never reach it.
    private static let neverServedBonus = 10_000

    /// The free tier's fixed set: the first N of each domain, in bank order.
    /// Deterministic on purpose — every free install sees the same 27, which is
    /// what makes the paid bank ("all 135, rotating") a real difference rather
    /// than a number on a table.
    public func freeSlice() -> [MagnifyEntry] {
        var perDomain: [MagnifyDomain: Int] = [:]
        var slice: [MagnifyEntry] = []
        for entry in bank {
            let count: Int = perDomain[entry.domain] ?? 0
            guard count < Self.freeEntriesPerDomain else { continue }
            perDomain[entry.domain] = count + 1
            slice.append(entry)
        }
        return slice
    }

    /// 1 for the first week, 2 until the user has 14 reps behind them, then 3.
    public func intensityCeiling() -> Int {
        let completions = defaults.integer(forKey: completionCountKey)
        if completions >= Self.intensityThreeUnlocksAfter { return 3 }
        guard let firstDay = defaults.string(forKey: firstOpenedDayKey),
              let firstDate = Self.date(from: firstDay, calendar: calendar) else { return 1 }
        let days = calendar.dateComponents([.day], from: firstDate, to: Date()).day ?? 0
        return days < Self.gentleOpeningDays ? 1 : 2
    }

    // MARK: - The teaching layer

    /// Today's "why" line, rotating through the bank's pool by day.
    ///
    /// Keyed off the day rather than served at random so the line is stable for
    /// the whole day — someone who opens the rep twice should not be told two
    /// different reasons — and so the pool is walked evenly instead of clustering.
    public func whyLine(for date: Date = Date()) -> String? {
        guard !whyLines.isEmpty else { return nil }
        let day = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
        return whyLines[day % whyLines.count]
    }

    /// Whether the first-run explanation has been shown. One-way: it is set the
    /// first time the flow opens and never cleared, because a person who has
    /// been magnifying for a month does not need to be taught it again.
    public var hasSeenWhy: Bool {
        defaults.bool(forKey: seenWhyKey)
    }

    public func markWhySeen() {
        defaults.set(true, forKey: seenWhyKey)
    }

    // MARK: - Completing a rep

    /// Banks the rep.
    ///
    /// - Parameter source: where this rep came from — the day's rotation, the
    ///   written route, storm mode, or an extra. Recorded in the log.
    /// - Parameter completesDailyRep: whether this rep was the day's.
    ///
    /// These two are deliberately separate. Someone who opens the daily rep and
    /// takes the written route has still done today's rep, and the checklist row
    /// they launched from has to tick — but the log should record honestly that
    /// they named it themselves. Fusing the two left that row unchecked after a
    /// completed rep in the feature this replaces.
    ///
    /// Idempotent within a calendar day when `completesDailyRep` is true, so a
    /// double-tap cannot inflate the count. Extra reps beyond the day's are each
    /// their own and always count.
    ///
    /// - Returns: the new cumulative total.
    @discardableResult
    public func magnify(domain: MagnifyDomain,
                        entryId: String,
                        source: MagnifiedMoment.Source,
                        spoken: Bool,
                        completesDailyRep: Bool) -> Int {
        let today = Self.dayStamp(Date(), calendar: calendar)
        if completesDailyRep, defaults.string(forKey: lastCompletedDayKey) == today {
            return timesMagnified
        }

        let total = TimesMagnified.add(defaults: defaults)
        timesMagnified = total

        if completesDailyRep {
            defaults.set(today, forKey: lastCompletedDayKey)
            completedToday = true
            pushRecentDomain(domain)
            // Only day-reps advance the intensity ladder. Counting every rep let
            // fourteen extra reps on day one unlock intensity 3 on day two, which
            // is exactly the gentle opening the ladder exists to protect.
            defaults.set(defaults.integer(forKey: completionCountKey) + 1,
                         forKey: completionCountKey)
        }
        bumpEngagement(domain)
        appendLog(MagnifiedMoment(id: UUID(), date: Date(), source: source,
                                  domain: domain, entryId: entryId, spoken: spoken))

        // Mirror into the synced rows immediately rather than waiting for the
        // next launch, so a second device sees the count on its next open.
        syncCounters()
        return total
    }

    /// Refreshes the published mirror from the synced counter. Called when the
    /// Today tab appears, since another device's reps arrive via CloudKit while
    /// this view is off screen.
    public func refreshCount() {
        let total = TimesMagnified.total(defaults: defaults)
        if total != timesMagnified { timesMagnified = total }
        let done = isCompletedToday
        if done != completedToday { completedToday = done }
    }

    // MARK: - Kill switch

    /// **Deliberately still `guardEnabled`.** The key already exists in the
    /// Remote Config console with a value set against it, and renaming it in code
    /// would ship the pillar dark (or lit) for everyone until someone remembered
    /// to add the new key on the other side. One source of truth, and the truth
    /// is whatever the console already says. `SubscriptionStore.guardEnabled`
    /// mirrors this for callers that have a store to read.
    public var isEnabled: Bool {
        featureFlags.bool("guardEnabled", default: false)
    }

    /// Whether today's rep is done, re-derived from the stored day stamp on every
    /// read rather than cached. The authoritative answer — see the note on
    /// `completedToday`.
    public var isCompletedToday: Bool {
        Self.isToday(defaults.string(forKey: lastCompletedDayKey), calendar: calendar)
    }

    /// `isCompletedToday`, or nil when the pillar is dark — the kill switch is
    /// off, or the bank failed to load and there is nothing to serve.
    /// `TaskLibrary` reads this: nil leaves the checklist row out entirely rather
    /// than offering a task that cannot be finished.
    public var enabledCompletedToday: Bool? {
        guard isEnabled, !bank.isEmpty else { return nil }
        return isCompletedToday
    }

    // MARK: - Written-route quota

    /// How many written entries the user has left this month. `nil` means
    /// unlimited (premium, or the day's own rep, which is never metered).
    public func writtenEntriesRemaining(isPremium: Bool) -> Int? {
        guard !isPremium else { return nil }
        let used: Int = writtenEntriesUsedThisMonth()
        let remaining: Int = Self.freeWrittenEntriesPerMonth - used
        return remaining > 0 ? remaining : 0
    }

    public func canUseWrittenRoute(isPremium: Bool) -> Bool {
        guard let remaining = writtenEntriesRemaining(isPremium: isPremium) else { return true }
        return remaining > 0
    }

    /// Spends one. Premium spends nothing, so the counter never has to be unwound
    /// if a subscription lapses.
    public func recordWrittenEntryUse(isPremium: Bool) {
        guard !isPremium else { return }
        let month = Self.monthStamp(Date(), calendar: calendar)
        if defaults.string(forKey: writtenMonthKey) != month {
            defaults.set(month, forKey: writtenMonthKey)
            defaults.set(0, forKey: writtenCountKey)
        }
        defaults.set(writtenEntriesUsedThisMonth() + 1, forKey: writtenCountKey)
    }

    private func writtenEntriesUsedThisMonth() -> Int {
        let month = Self.monthStamp(Date(), calendar: calendar)
        guard defaults.string(forKey: writtenMonthKey) == month else { return 0 }
        return defaults.integer(forKey: writtenCountKey)
    }

    // MARK: - Ground covered (read-only)

    /// The domain the user has magnified God over the most. Never surfaced as a
    /// diagnosis — the only sentence it is allowed to produce is "You've been
    /// lifting Him high over <domain>".
    ///
    /// Written as a plain loop rather than `compactMap` + `max(by:)`. The chained
    /// version inferred a tuple type through two generic higher-order functions
    /// and compared across both members inside a ternary, and the Swift type
    /// checker could not solve it in reasonable time — it failed an Xcode Cloud
    /// archive outright.
    public func strongestDomain() -> MagnifyDomain? {
        var best: MagnifyDomain?
        var bestCount: Int = 0

        for (key, count) in engagement() {
            guard let domain = MagnifyDomain(rawValue: key) else { continue }
            guard let currentBest = best else {
                best = domain
                bestCount = count
                continue
            }
            if count > bestCount {
                best = domain
                bestCount = count
            } else if count == bestCount, domain.rawValue < currentBest.rawValue {
                // Dictionary order is not stable between runs, so ties break on
                // the raw value — otherwise the same data could name a different
                // domain on each launch.
                best = domain
            }
        }
        return best
    }

    /// The log, newest first. Local-only and capped — this is a record of reps,
    /// not a diary, and nothing downstream needs the full history.
    public func recentMoments(limit: Int = 100) -> [MagnifiedMoment] {
        let log: [MagnifiedMoment] = loadLog()
        let tail: [MagnifiedMoment] = Array(log.suffix(limit))
        return tail.reversed()
    }

    // MARK: - Persistence helpers

    private func servedDays() -> [String: String] {
        defaults.dictionary(forKey: servedKey) as? [String: String] ?? [:]
    }

    private func recordServed(_ entry: MagnifyEntry, on day: String) {
        var served = servedDays()
        served[entry.id] = day
        defaults.set(served, forKey: servedKey)
    }

    private func recentDomains() -> [MagnifyDomain] {
        // `compactMap(MagnifyDomain.init)` would make the compiler resolve an
        // unapplied initializer reference against every init the type has,
        // including the synthesized Decodable one. Spelled out, there is nothing
        // to resolve.
        let raw: [String] = defaults.stringArray(forKey: recentDomainsKey) ?? []
        return raw.compactMap { MagnifyDomain(rawValue: $0) }
    }

    private func pushRecentDomain(_ domain: MagnifyDomain) {
        var recent = defaults.stringArray(forKey: recentDomainsKey) ?? []
        recent.append(domain.rawValue)
        if recent.count > 5 { recent.removeFirst(recent.count - 5) }
        defaults.set(recent, forKey: recentDomainsKey)
    }

    private func engagement() -> [String: Int] {
        defaults.dictionary(forKey: engagementKey) as? [String: Int] ?? [:]
    }

    private func bumpEngagement(_ domain: MagnifyDomain) {
        var weights = engagement()
        weights[domain.rawValue, default: 0] += 1
        defaults.set(weights, forKey: engagementKey)
    }

    private func loadLog() -> [MagnifiedMoment] {
        guard let data = defaults.data(forKey: logKey),
              let decoded = try? JSONDecoder().decode([MagnifiedMoment].self, from: data) else { return [] }
        return decoded
    }

    private func appendLog(_ entry: MagnifiedMoment) {
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
    /// A shared `DateFormatter` would have to have its `timeZone` mutated on every
    /// use (the calendar is injected so tests can pin it), and a mutable static
    /// touched from more than one place is a data race waiting for the first
    /// background caller. Construction is cheap next to the work these stamps
    /// guard.
    private static func formatter(_ format: String, calendar: Calendar) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = format
        formatter.timeZone = calendar.timeZone
        return formatter
    }

    public static func dayStamp(_ date: Date, calendar: Calendar) -> String {
        formatter("yyyy-MM-dd", calendar: calendar).string(from: date)
    }

    public static func monthStamp(_ date: Date, calendar: Calendar) -> String {
        formatter("yyyy-MM", calendar: calendar).string(from: date)
    }

    public static func date(from stamp: String, calendar: Calendar) -> Date? {
        formatter("yyyy-MM-dd", calendar: calendar).date(from: stamp)
    }

    private static func isToday(_ stamp: String?, calendar: Calendar) -> Bool {
        guard let stamp else { return false }
        return stamp == dayStamp(Date(), calendar: calendar)
    }
}

// MARK: - Pending launch

extension MagnifyService {

    /// Set by the App Intent, read by the Today tab.
    ///
    /// TWO mechanisms, because the intent has two very different arrival cases
    /// and neither one covers the other:
    ///
    /// - **Cold launch.** `perform()` runs before any view exists, so an
    ///   in-memory flag would be set and never observed — the user would watch
    ///   the app open to the home screen having just asked Siri to magnify the
    ///   Lord. The persisted stamp survives that gap and is consumed on first
    ///   appear.
    /// - **Warm app, wrong tab.** `onAppear` does not fire for a tab that is
    ///   already on screen or already built, so the persisted stamp alone left
    ///   the intent doing nothing at all. The published `launchRequestedAt`
    ///   drives a tab switch and the presentation.
    ///
    /// The persisted stamp is consumed exactly once, so the two cannot both fire
    /// and double-present.
    private static let pendingLaunchKey = "guardPendingIntentLaunch"

    /// Set alongside the stamp when the intent was the storm shortcut, so the
    /// flow opens straight into a facet rather than into the domain picker.
    private static let pendingStormKey = "magnifyPendingStorm"

    public static func requestPendingLaunch(storm: Bool = false, defaults: UserDefaults = .standard) {
        defaults.set(Date().timeIntervalSince1970, forKey: pendingLaunchKey)
        defaults.set(storm, forKey: pendingStormKey)
    }

    /// Returns true once per request, then clears it.
    ///
    /// Stale requests are dropped: a flag written more than a couple of minutes
    /// ago belongs to a launch that already happened (or one the user abandoned
    /// at the lock screen), and firing the flow off it would ambush someone who
    /// opened the app for something else entirely.
    public static func consumePendingLaunch(defaults: UserDefaults = .standard,
                                            now: Date = Date()) -> Bool {
        let stamp = defaults.double(forKey: pendingLaunchKey)
        guard stamp > 0 else { return false }
        defaults.removeObject(forKey: pendingLaunchKey)
        return now.timeIntervalSince1970 - stamp < 120
    }

    /// Whether the consumed launch was the storm shortcut. Read AFTER
    /// `consumePendingLaunch` returns true; cleared on read so a later ordinary
    /// launch cannot inherit it.
    public static func consumePendingStorm(defaults: UserDefaults = .standard) -> Bool {
        let storm = defaults.bool(forKey: pendingStormKey)
        defaults.removeObject(forKey: pendingStormKey)
        return storm
    }
}
