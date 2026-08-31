//
//  BurstCompletionModel.swift
//  SpeakLifeServices
//
//  Model for tracking daily burst completions and spiritual strength
//

import Foundation
import Combine
import SpeakLifeCore
import SpeakLifePersistence

// MARK: - Burst Completion Data Model

public struct BurstCompletion: Codable {
    public let date: Date
    public let completedAt: Date
    public let declarationCount: Int
    public let timeSpent: TimeInterval // in seconds
    public var spiritualStrengthScore: Int // 1-100 scale

    public init(date: Date, completedAt: Date, declarationCount: Int, timeSpent: TimeInterval, spiritualStrengthScore: Int) {
        self.date = date
        self.completedAt = completedAt
        self.declarationCount = declarationCount
        self.timeSpent = timeSpent
        self.spiritualStrengthScore = spiritualStrengthScore
    }
}

// MARK: - Spiritual Strength Calculator

public struct SpiritualStrengthMetrics {
    public let consistency: Double // 0-1 based on streak
    public let frequency: Double // 0-1 based on completions per week
    public let dedication: Double // 0-1 based on time spent
    public let growth: Double // 0-1 based on improvement trend

    public init(consistency: Double, frequency: Double, dedication: Double, growth: Double) {
        self.consistency = consistency
        self.frequency = frequency
        self.dedication = dedication
        self.growth = growth
    }

    public var overallScore: Int {
        let weighted = (consistency * 0.35) + (frequency * 0.25) + (dedication * 0.2) + (growth * 0.2)
        return Int(weighted * 100)
    }
}

// MARK: - Burst Completion Tracker

public final class BurstCompletionTracker: ObservableObject {
    public static let shared = BurstCompletionTracker()

    @Published public var completions: [BurstCompletion] = []
    @Published public var weeklyData: [DailyStrengthData] = []
    @Published public var monthlyTrend: [MonthlyStrengthData] = []
    @Published public var currentStrengthScore: Int = 0
    @Published public var strengthLevel: StrengthLevel = .warrior

    private let userDefaultsKey = "burstCompletions"
    private let calendar = Calendar.current

    public enum StrengthLevel: String, CaseIterable {
        case warrior = "Warrior"
        case champion = "Champion"
        case conqueror = "Conqueror"
        case victorious = "Victorious"
        case unstoppable = "Unstoppable"

        public var minimumScore: Int {
            switch self {
            case .warrior: return 0
            case .champion: return 20
            case .conqueror: return 40
            case .victorious: return 60
            case .unstoppable: return 80
            }
        }

        public var icon: String {
            switch self {
            case .warrior: return "shield.fill"
            case .champion: return "medal.fill"
            case .conqueror: return "crown.fill"
            case .victorious: return "star.circle.fill"
            case .unstoppable: return "bolt.circle.fill"
            }
        }
    }

    public struct DailyStrengthData: Identifiable {
        public let id = UUID()
        public let date: Date
        public let score: Int
        public let completed: Bool
        public let dayLabel: String

        public init(date: Date, score: Int, completed: Bool, dayLabel: String) {
            self.date = date
            self.score = score
            self.completed = completed
            self.dayLabel = dayLabel
        }
    }

    public struct MonthlyStrengthData: Identifiable {
        public let id = UUID()
        public let month: String
        public let averageScore: Int
        public let completionRate: Double
        public let totalCompletions: Int

        public init(month: String, averageScore: Int, completionRate: Double, totalCompletions: Int) {
            self.month = month
            self.averageScore = averageScore
            self.completionRate = completionRate
            self.totalCompletions = totalCompletions
        }
    }

    public init() {
        loadCompletions()
        cleanupDuplicatesOneTime() // One-time cleanup of true duplicates (same timestamp)
        calculateCurrentStrength()
        generateWeeklyData()
        generateMonthlyTrend()

        // iCloud sync: push the full local history up once (the flag is only
        // set when the write definitely persisted, so a failed push retries
        // next launch), then merge in completions earned on the user's other
        // devices whenever CloudKit delivers them. Both directions are
        // unions — days are only ever added, never removed, so no device can
        // lose streak history.
        if !UserDefaults.standard.bool(forKey: Self.historyPushedFlagKey) {
            pushCompletionsToSync(fullHistory: true)
        }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSyncDataChanged),
            name: ProgressSyncStore.dataDidChange,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Public Methods

    /// Memoized. `calculateCurrentStreak` walks back day by day doing a linear
    /// scan of `completions` for each one, so a long streak over a long history
    /// is O(streak × history) — and this is now read from the Today tab's body,
    /// which SwiftUI re-evaluates constantly. Recomputing it there would put
    /// hundreds of thousands of date comparisons on the home screen's render
    /// path.
    ///
    /// The cache is keyed on the calendar day and on `completions.count`, so it
    /// invalidates on a rollover and on any append or sync merge — the only two
    /// ways the answer can change.
    public var currentStreak: Int {
        let today = calendar.startOfDay(for: Date())
        if let cached = cachedStreak, cached.day == today, cached.completionCount == completions.count {
            return cached.value
        }
        let value = calculateCurrentStreak()
        cachedStreak = (day: today, completionCount: completions.count, value: value)
        return value
    }

    private var cachedStreak: (day: Date, completionCount: Int, value: Int)?

    public func recordBurstCompletion(declarationCount: Int, timeSpent: TimeInterval) {
        let today = calendar.startOfDay(for: Date())
        let isFirstCompletionToday = !completions.contains(where: { calendar.startOfDay(for: $0.date) == today })

        let metrics = calculateMetricsInternal()
        let strengthScore = metrics.overallScore

        let completion = BurstCompletion(
            date: today,
            completedAt: Date(),
            declarationCount: declarationCount,
            timeSpent: timeSpent,
            spiritualStrengthScore: strengthScore
        )

        #if DEBUG
        let completionType = isFirstCompletionToday ? "First completion" : "Additional completion"
        print("✅ BurstCompletionTracker: Recording \(completionType) for \(today) with score \(strengthScore)")
        #endif

        completions.append(completion)
        saveCompletions()
        updateStrengthLevel(score: strengthScore)
        generateWeeklyData()
        generateMonthlyTrend()

        // Send notification for milestone achievements only on first completion of the day
        if isFirstCompletionToday {
            checkAndCelebrateMilestones()
        }
    }

    public func getTodaysCompletion() -> BurstCompletion? {
        let today = calendar.startOfDay(for: Date())
        return completions.first { calendar.startOfDay(for: $0.date) == today }
    }

    public func hasTodaysCompletion() -> Bool {
        return getTodaysCompletion() != nil
    }

    /// How many bursts have been spoken today.
    ///
    /// The streak only ever asked whether the day was touched at all, which was
    /// the right question when the burst was a once-a-day event. Now that the
    /// user is invited in several times a day, the count is what the completion
    /// screen shows them and what tells them there is another one waiting.
    public var todaysCompletionCount: Int {
        let today = calendar.startOfDay(for: Date())
        return completions.filter { calendar.startOfDay(for: $0.date) == today }.count
    }

    public func getCompletionsForWeek() -> [BurstCompletion] {
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date())!
        return completions.filter { $0.date >= weekAgo }
    }

    public func getCompletionsForMonth() -> [BurstCompletion] {
        let monthAgo = calendar.date(byAdding: .month, value: -1, to: Date())!
        return completions.filter { $0.date >= monthAgo }
    }

    public func getUniqueDaysCount() -> Int {
        let uniqueDays = Set(completions.map { calendar.startOfDay(for: $0.date) })
        return uniqueDays.count
    }

    // MARK: - Public Methods for Graph

    public func calculateMetrics() -> SpiritualStrengthMetrics {
        calculateMetricsInternal()
    }

    // MARK: - Private Methods

    private func cleanupDuplicatesOneTime() {
        // Only remove completions that have identical timestamps (true duplicates)
        // Allow multiple completions per day with different timestamps
        var uniqueCompletions: [BurstCompletion] = []
        var seenTimestamps: Set<Date> = []

        for completion in completions {
            if !seenTimestamps.contains(completion.completedAt) {
                seenTimestamps.insert(completion.completedAt)
                uniqueCompletions.append(completion)
            } else {
                #if DEBUG
                print("🧹 BurstCompletionTracker: Removing true duplicate with timestamp \(completion.completedAt)")
                #endif
            }
        }

        // Update completions only if we found true duplicates
        if uniqueCompletions.count < completions.count {
            completions = uniqueCompletions.sorted(by: { $0.date < $1.date })
            saveCompletions()
        }
    }

    private func calculateMetricsInternal() -> SpiritualStrengthMetrics {
        let weekCompletions = getCompletionsForWeek()
        let monthCompletions = getCompletionsForMonth()

        // Consistency: based on consecutive days
        let consistency = calculateConsistencyScore()

        // Frequency: completions in last 7 days
        let frequency = Double(weekCompletions.count) / 7.0

        // Dedication: average time spent
        let avgTimeSpent = weekCompletions.isEmpty ? 0 :
            weekCompletions.map(\.timeSpent).reduce(0, +) / Double(weekCompletions.count)
        let dedication = min(avgTimeSpent / 180.0, 1.0) // 3 minutes = perfect score

        // Growth: improvement trend
        let growth = calculateGrowthTrend(monthCompletions)

        return SpiritualStrengthMetrics(
            consistency: consistency,
            frequency: frequency,
            dedication: dedication,
            growth: growth
        )
    }

    private func calculateCurrentStreak() -> Int {
        var consecutiveDays = 0
        var currentDate = calendar.startOfDay(for: Date())

        // A streak is alive until today actually ends: if today's burst isn't
        // done yet, count back from yesterday instead of reporting 0. Starting
        // strictly at today made this 0 every morning, which silently defeated
        // the streakStats heals in EnhancedStreakViewModel and left the badge
        // stuck below the real completed-day history.
        if !completions.contains(where: { calendar.startOfDay(for: $0.date) == currentDate }) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: currentDate) else { return 0 }
            currentDate = yesterday
        }

        // Check consecutive days starting from today going backwards
        for _ in 0..<365 {  // Check up to a year back
            // Count day as complete if there's at least one completion that day
            if completions.contains(where: { calendar.startOfDay(for: $0.date) == currentDate }) {
                consecutiveDays += 1
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate)!
            } else {
                break
            }
        }

        return consecutiveDays
    }

    private func calculateConsistencyScore() -> Double {
        let streak = calculateCurrentStreak()
        return min(Double(streak) / 7.0, 1.0) // 7 days = perfect consistency
    }

    private func calculateGrowthTrend(_ monthCompletions: [BurstCompletion]) -> Double {
        guard monthCompletions.count > 7 else { return 0.5 } // neutral if not enough data

        let sorted = monthCompletions.sorted { $0.date < $1.date }
        let firstWeek = Array(sorted.prefix(7))
        let lastWeek = Array(sorted.suffix(7))

        let firstWeekAvg = firstWeek.map { Double($0.spiritualStrengthScore) }.reduce(0, +) / Double(firstWeek.count)
        let lastWeekAvg = lastWeek.map { Double($0.spiritualStrengthScore) }.reduce(0, +) / Double(lastWeek.count)

        let improvement = (lastWeekAvg - firstWeekAvg) / 100.0
        return min(max(0.5 + improvement, 0), 1) // 0.5 is neutral, cap at 0-1
    }

    private func calculateCurrentStrength() {
        let metrics = calculateMetricsInternal()
        currentStrengthScore = metrics.overallScore
        updateStrengthLevel(score: currentStrengthScore)
    }

    private func updateStrengthLevel(score: Int) {
        for level in StrengthLevel.allCases.reversed() {
            if score >= level.minimumScore {
                strengthLevel = level
                break
            }
        }
    }

    private func generateWeeklyData() {
        weeklyData = []
        let today = calendar.startOfDay(for: Date())

        for dayOffset in (0..<7).reversed() {
            if let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) {
                let dayCompletions = completions.filter { calendar.startOfDay(for: $0.date) == date }
                let dayFormatter = DateFormatter()
                dayFormatter.dateFormat = "E"

                // Sum all completion scores for the day (allows multiple completions)
                let totalScore = dayCompletions.map { $0.spiritualStrengthScore }.reduce(0, +)

                weeklyData.append(DailyStrengthData(
                    date: date,
                    score: totalScore,
                    completed: !dayCompletions.isEmpty,
                    dayLabel: dayFormatter.string(from: date)
                ))
            }
        }
    }

    private func generateMonthlyTrend() {
        monthlyTrend = []
        let today = Date()

        for monthOffset in (0..<3).reversed() {
            if let monthStart = calendar.date(byAdding: .month, value: -monthOffset, to: today) {
                let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart)!
                let monthCompletions = completions.filter {
                    $0.date >= monthStart && $0.date < monthEnd
                }

                if !monthCompletions.isEmpty {
                    let avgScore = monthCompletions.map { $0.spiritualStrengthScore }.reduce(0, +) / monthCompletions.count
                    let daysInMonth = calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 30
                    let completionRate = Double(monthCompletions.count) / Double(daysInMonth)

                    let monthFormatter = DateFormatter()
                    monthFormatter.dateFormat = "MMM"

                    monthlyTrend.append(MonthlyStrengthData(
                        month: monthFormatter.string(from: monthStart),
                        averageScore: avgScore,
                        completionRate: completionRate,
                        totalCompletions: monthCompletions.count
                    ))
                }
            }
        }
    }

    private func checkAndCelebrateMilestones() {
        let uniqueDays = getUniqueDaysCount()

        // Check for milestone achievements based on unique days
        let milestones = [7, 21, 30, 50, 100]
        if milestones.contains(uniqueDays) {
            // This would trigger a celebration animation or notification
            NotificationCenter.default.post(
                name: Notification.Name("BurstMilestoneAchieved"),
                object: nil,
                userInfo: ["count": uniqueDays]
            )
        }
    }

    // MARK: - Persistence

    private func saveCompletions() {
        if let encoded = try? JSONEncoder().encode(completions) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
        // Only today's completion can be new here — the full history was
        // pushed once at init. Re-encoding the whole history on every save
        // would waste CPU and CloudKit traffic for rows that never change.
        pushCompletionsToSync(fullHistory: false)
    }

    private func loadCompletions() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode([BurstCompletion].self, from: data) {
            completions = decoded
        }
    }

    // MARK: - iCloud Sync (union merge, never lossy)

    /// Posted after remote burst completions have been merged into the local
    /// history, so streak consumers can heal their derived stats.
    public static let historyMergedNotification = Notification.Name("BurstCompletionHistoryMerged")

    /// Set only after the full local history has definitely persisted to the
    /// sync store, so a failed push retries on the next launch.
    private static let historyPushedFlagKey = "sl_burstHistoryPushedToSync_v1"
    /// completedAt timestamps of completions that arrived FROM other devices.
    /// Those must never be re-pushed: re-stamping them with this device's
    /// timezone could mint a new event key for a day another device already
    /// recorded, duplicating rows forever.
    private static let remoteMergedTimestampsKey = "sl_remoteMergedBurstTimestamps"

    private static let dayStampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar.current
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    public static func dayStamp(for date: Date) -> String {
        dayStampFormatter.string(from: date)
    }

    private var remoteMergedTimestamps: Set<TimeInterval> {
        get {
            let array = UserDefaults.standard.array(forKey: Self.remoteMergedTimestampsKey) as? [TimeInterval] ?? []
            return Set(array)
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: Self.remoteMergedTimestampsKey)
        }
    }

    /// Upserts one dayCompletion event per unique local day this device
    /// earned itself. Existing rows are left untouched (idempotent).
    /// `fullHistory: false` pushes only today's completion — the common
    /// per-save case, avoiding a full-history re-encode every save.
    private func pushCompletionsToSync(fullHistory: Bool) {
        let mergedFromRemote = remoteMergedTimestamps
        let today = calendar.startOfDay(for: Date())
        let candidates = completions.filter { completion in
            guard !mergedFromRemote.contains(completion.completedAt.timeIntervalSince1970) else { return false }
            return fullHistory || calendar.startOfDay(for: completion.date) == today
        }
        guard !candidates.isEmpty else {
            if fullHistory {
                // Nothing to migrate — an empty history is trivially pushed.
                UserDefaults.standard.set(true, forKey: Self.historyPushedFlagKey)
            }
            return
        }

        var firstPerDay: [String: BurstCompletion] = [:]
        for completion in candidates {
            let stamp = Self.dayStamp(for: completion.date)
            if let existing = firstPerDay[stamp] {
                if completion.completedAt < existing.completedAt {
                    firstPerDay[stamp] = completion
                }
            } else {
                firstPerDay[stamp] = completion
            }
        }
        let items = firstPerDay.map { stamp, completion in
            (key: stamp, payload: try? JSONEncoder().encode(completion))
        }
        ProgressSyncStore.shared.recordEvents(kind: ProgressSyncStore.Kind.dayCompletion, items: items) { success in
            if fullHistory && success {
                UserDefaults.standard.set(true, forKey: Self.historyPushedFlagKey)
            }
        }
    }

    @objc private func handleSyncDataChanged(_ notification: Notification) {
        if let kinds = notification.userInfo?["kinds"] as? Set<String>,
           !kinds.contains(ProgressSyncStore.Kind.dayCompletion) {
            return
        }
        // Asynchronous fetch — never block the main thread behind the sync
        // context's import/dedup work. The completion runs on main, where
        // the @Published completions array must be mutated anyway.
        ProgressSyncStore.shared.events(ofKind: ProgressSyncStore.Kind.dayCompletion) { [weak self] events in
            self?.mergeRemoteDayCompletions(events)
        }
    }

    /// Adds any day completed on another device that this device has never
    /// seen. Purely additive: local history is never rewritten or removed.
    /// Runs on the main queue.
    private func mergeRemoteDayCompletions(_ events: [ProgressSyncStore.Event]) {
        guard !events.isEmpty else { return }

        // Dedup on BOTH axes: exact completion identity (completedAt is an
        // instant, identical across devices for the same completion) and the
        // LOCAL calendar day. The event key was stamped in the writing
        // device's timezone, so comparing keys alone would re-append the
        // same completion forever when the timezones differ.
        let localTimestamps = Set(completions.map { $0.completedAt.timeIntervalSince1970 })
        let localDays = Set(completions.map { calendar.startOfDay(for: $0.date) })
        var merged: [BurstCompletion] = []
        var mergedDays = Set<Date>()
        var mergedTimestampLedger = remoteMergedTimestamps

        for event in events {
            var candidate: BurstCompletion?
            if let payload = event.payload,
               let completion = try? JSONDecoder().decode(BurstCompletion.self, from: payload) {
                candidate = completion
            } else if let day = Self.dayStampFormatter.date(from: event.key) {
                // Payload missing or unreadable — still count the day so the
                // streak survives, with neutral details.
                candidate = BurstCompletion(
                    date: calendar.startOfDay(for: day),
                    completedAt: event.createdAt,
                    declarationCount: 0,
                    timeSpent: 0,
                    spiritualStrengthScore: 50
                )
            }
            guard let completion = candidate else { continue }

            let timestamp = completion.completedAt.timeIntervalSince1970
            let localDay = calendar.startOfDay(for: completion.date)
            guard !localTimestamps.contains(timestamp),
                  !localDays.contains(localDay),
                  !mergedDays.contains(localDay) else { continue }

            merged.append(completion)
            mergedDays.insert(localDay)
            mergedTimestampLedger.insert(timestamp)
        }

        guard !merged.isEmpty else { return }

        #if DEBUG
        print("☁️ BurstCompletionTracker: merged \(merged.count) day(s) from other devices")
        #endif

        remoteMergedTimestamps = mergedTimestampLedger
        completions = (completions + merged).sorted { $0.date < $1.date }
        if let encoded = try? JSONEncoder().encode(completions) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }

        calculateCurrentStrength()
        generateWeeklyData()
        generateMonthlyTrend()

        NotificationCenter.default.post(name: Self.historyMergedNotification, object: nil)
    }
}
