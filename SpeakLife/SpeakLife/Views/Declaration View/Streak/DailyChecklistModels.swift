//
//  DailyChecklistModels.swift
//  SpeakLife
//
//  Progressive daily checklist models for enhanced streak feature
//  

import Foundation
import SwiftUI

// MARK: - Task Categories & Types
enum TaskCategory: String, CaseIterable, Codable {
    case foundation = "foundation"     // Core spiritual practices
    case growth = "growth"            // Personal development
    case impact = "impact"            // Community engagement
    case mastery = "mastery"          // Advanced practices
    
    var displayName: String {
        switch self {
        case .foundation: return "Foundation"
        case .growth: return "Growth"
        case .impact: return "Impact"
        case .mastery: return "Mastery"
        }
    }
    
    var color: Color {
        switch self {
        case .foundation: return .blue
        case .growth: return .green
        case .impact: return .orange
        case .mastery: return .purple
        }
    }
    
    var emoji: String {
        switch self {
        case .foundation: return "🌱"
        case .growth: return "🌿"
        case .impact: return "🌟"
        case .mastery: return "👑"
        }
    }
}

enum TaskType: String, CaseIterable, Codable {
    case speak = "speak"
    case listen = "listen"
    case read = "read"
    case share = "share"
    case reflect = "reflect"
    case memorize = "memorize"
    case worship = "worship"
    case serve = "serve"
    case study = "study"
    case teach = "teach"
}

enum DifficultyLevel: Int, CaseIterable, Codable {
    case beginner = 1
    case intermediate = 2
    case advanced = 3
    case expert = 4
    
    var displayName: String {
        switch self {
        case .beginner: return "Beginner"
        case .intermediate: return "Intermediate"
        case .advanced: return "Advanced"
        case .expert: return "Expert"
        }
    }
}

// MARK: - Task Navigation Destination
enum TaskNavigationDestination: String, Codable {
    case none
    case audioTab
    case devotional
    case burst
    case bibleChat
    case journal
    case personalDeclaration
}

// MARK: - Enhanced Daily Task Model
struct DailyTask: Identifiable, Codable {
    let id: String
    var title: String
    var description: String
    let icon: String
    let category: TaskCategory
    let type: TaskType
    let difficulty: DifficultyLevel
    let minimumStreakDay: Int
    var estimatedMinutes: Int
    var isCompleted: Bool = false
    var completedAt: Date?
    var isNewlyUnlocked: Bool = false
    var navigationDestination: TaskNavigationDestination = .none
    /// Foundation week (days 1-7): the exact catalog episode this task points
    /// at (`AudioDeclaration.id`). The checklist deep-links straight to it.
    /// nil after the foundation week — the task opens the open audio tab.
    var recommendedAudioId: String? = nil

    /// Set on the tasks an active campaign rebuilt from the user's own words.
    ///
    /// Optional, not `Bool = false`, on purpose: `DailyTask` uses synthesized
    /// Codable, which does NOT fall back to a property's default value when a
    /// key is absent. A new non-optional key would throw `keyNotFound` on every
    /// checklist persisted before this shipped, and the user would lose today's
    /// progress. An Optional decodes to nil. Read it through
    /// `isCampaignRefreshed`, never directly.
    var campaignRefreshed: Bool? = nil

    var isCampaignRefreshed: Bool { campaignRefreshed == true }

    init(id: String, title: String, description: String, icon: String,
         category: TaskCategory, type: TaskType, difficulty: DifficultyLevel = .beginner,
         minimumStreakDay: Int = 1, estimatedMinutes: Int = 5,
         isCompleted: Bool = false, completedAt: Date? = nil,
         navigationDestination: TaskNavigationDestination = .none,
         recommendedAudioId: String? = nil) {
        self.id = id
        self.title = title
        self.description = description
        self.icon = icon
        self.category = category
        self.type = type
        self.difficulty = difficulty
        self.minimumStreakDay = minimumStreakDay
        self.estimatedMinutes = estimatedMinutes
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.navigationDestination = navigationDestination
        self.recommendedAudioId = recommendedAudioId
    }
}

// MARK: - Daily Checklist Model
struct DailyChecklist: Codable {
    let date: Date
    var tasks: [DailyTask]
    var completedAt: Date?
    var currentPhase: ProgressionPhase
    var newTasksUnlocked: [String] = []
    
    /// True when ALL tasks are done (used for full-checklist celebration UI only).
    var isCompleted: Bool {
        tasks.allSatisfy { $0.isCompleted }
    }

    /// True when the Daily Burst is done — this is the only requirement to earn a streak day.
    /// Devotional, audio, gratitude etc. are bonus tasks and don't gate the streak.
    var isStreakEarned: Bool {
        tasks.first(where: { $0.id == "complete_daily_burst" })?.isCompleted ?? false
    }
    
    var completionProgress: Double {
        let completedCount = tasks.filter { $0.isCompleted }.count
        return Double(completedCount) / Double(tasks.count)
    }
    
    var completedTasksCount: Int {
        tasks.filter { $0.isCompleted }.count
    }
    
    var estimatedTotalMinutes: Int {
        tasks.reduce(0) { $0 + $1.estimatedMinutes }
    }
}

// MARK: - Progression System
enum ProgressionPhase: String, CaseIterable, Codable {
    case foundation = "foundation"     // Days 1-7
    case growth = "growth"            // Days 8-30
    case impact = "impact"            // Days 31-100
    case mastery = "mastery"          // Days 100+
    
    var displayName: String {
        switch self {
        case .foundation: return "Building Foundation"
        case .growth: return "Growing Deeper"
        case .impact: return "Making Impact"
        case .mastery: return "Spiritual Mastery"
        }
    }
    
    var description: String {
        switch self {
        case .foundation: return "Establishing core spiritual habits"
        case .growth: return "Expanding your spiritual practices"
        case .impact: return "Reaching out and serving others"
        case .mastery: return "Advanced spiritual disciplines"
        }
    }
    
    var minStreakDay: Int {
        switch self {
        case .foundation: return 1
        case .growth: return 8
        case .impact: return 31
        case .mastery: return 100
        }
    }
    
    var maxStreakDay: Int {
        switch self {
        case .foundation: return 7
        case .growth: return 30
        case .impact: return 99
        case .mastery: return Int.max
        }
    }
    
    var color: Color {
        switch self {
        case .foundation: return .blue
        case .growth: return .green
        case .impact: return .orange
        case .mastery: return .purple
        }
    }
    
    var emoji: String {
        switch self {
        case .foundation: return "🌱"
        case .growth: return "🌿"
        case .impact: return "🌟"
        case .mastery: return "👑"
        }
    }
    
    static func getPhase(for streakDay: Int) -> ProgressionPhase {
        if streakDay >= 100 { return .mastery }
        if streakDay >= 31 { return .impact }
        if streakDay >= 8 { return .growth }
        return .foundation
    }
}

// MARK: - Merged Completion History

/// The MERGED, cross-device record of which local days the user actually
/// completed their burst.
///
/// Why this exists: `StreakStats.currentStreak` is only ever as fresh as the
/// last time THIS phone synced. A second device that has been in a drawer
/// carries a counter and a `lastCompletedDate` from a week ago, and any
/// decision made from those sees a gap the user never had. The day-completion
/// log (`ProgressSyncStore.Kind.dayCompletion`, mirrored into
/// `BurstCompletionTracker.completions`) is append-only and union-merged
/// across devices, so it is the one record every device eventually agrees on.
///
/// Deliberately a plain value type over start-of-day dates: the freeze
/// decision stays a pure function of (history, today) and can be unit-tested
/// without CoreData, CloudKit, or a singleton.
struct StreakHistory: Equatable {

    /// One entry per completed local day, normalized to start-of-day.
    let completedDays: Set<Date>

    init(completedDays: Set<Date> = []) {
        self.completedDays = completedDays
    }

    /// Normalizes raw completion timestamps to local start-of-day. Duplicate
    /// completions on one day collapse to a single entry, which is exactly
    /// what a "did the user complete that day" record should be.
    init(dates: [Date], calendar: Calendar = .current) {
        self.completedDays = Set(dates.map { calendar.startOfDay(for: $0) })
    }

    var isEmpty: Bool { completedDays.isEmpty }

    /// The most recent day the user completed on ANY device.
    var lastCompletedDay: Date? { completedDays.max() }

    /// How many consecutive completed days end ON `day` (0 when `day` itself
    /// was never completed). This is the real, cross-device length of the run
    /// the user is standing on — the number a freeze would be protecting.
    func consecutiveDays(endingOn day: Date, calendar: Calendar = .current) -> Int {
        var cursor = calendar.startOfDay(for: day)
        var count = 0
        // Same one-year ceiling BurstCompletionTracker walks. A streak longer
        // than that is not worth an unbounded loop over a synced data set.
        while count < 365, completedDays.contains(cursor) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }
}

// MARK: - Streak Statistics
struct StreakStats: Codable, Equatable {
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var totalDaysCompleted: Int = 0
    var lastCompletedDate: Date?
    // Fix 4: Streak freeze — new users start with one; earn more at milestones
    var streakFreezeAvailable: Bool = true
    var streakFreezeUsedDate: Date?
    /// The last REALLY completed day a currently-spent freeze is standing in
    /// for — i.e. the day the gap opened after. Non-nil means `lastCompletedDate`
    /// is a bridge (a placeholder written by the freeze), not a day the user
    /// actually completed; a real completion clears it (see `updateStreak`).
    ///
    /// It carries two jobs that nothing else could do:
    /// 1. Identity. A freeze is named by the gap it covers, so two devices
    ///    that both notice the same lapse write identical state — one spend,
    ///    however many devices see it — and neither pays twice for one gap.
    /// 2. Provenance. `merging` needs to know that a `lastCompletedDate` is a
    ///    bridge, so a stale phone's placeholder can never out-vote the phone
    ///    that actually completed that day.
    var streakFreezeCoveredDay: Date?
    // Milestones (streak day numbers) that have already triggered a full
    // celebration. Persisted so that breaking a streak and rebuilding past an
    // already-celebrated milestone does NOT re-fire its celebration. Defaults
    // empty; absent in older saved data and decodes cleanly.
    var celebratedMilestones: Set<Int> = []

    mutating func updateStreak(for date: Date) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: date)

        // A real completion after the lapse retires the freeze's placeholder:
        // from here on lastCompletedDate is backed by a day the user actually
        // completed, so it must stop reading as a bridge in merging().
        if let coveredDay = streakFreezeCoveredDay, today > coveredDay {
            streakFreezeCoveredDay = nil
        }

        if let lastDate = lastCompletedDate {
            let lastDateStart = calendar.startOfDay(for: lastDate)
            let daysDifference = calendar.dateComponents([.day], from: lastDateStart, to: today).day ?? 0
            
            if daysDifference == 1 {
                // Consecutive day - increment streak
                currentStreak += 1
            } else if daysDifference > 1 {
                // Streak broken - reset to 1
                currentStreak = 1
            } else if daysDifference == 0 {
                // Same day - already counted, don't update
                return
            }
            // daysDifference < 0 means completion is before last date - ignore
        } else {
            // First completion
            currentStreak = 1
        }
        
        longestStreak = max(longestStreak, currentStreak)
        totalDaysCompleted += 1
        lastCompletedDate = today
    }
    
    /// The streak count this side can actually still claim TODAY.
    ///
    /// A streak whose lastCompletedDate is before yesterday is dead — unless
    /// it is still freeze-rescuable (freeze available and streak >= 3, so a
    /// legitimate freeze save is never pre-empted). Merging with the RAW
    /// currentStreak instead would let a stale synced blob resurrect a broken
    /// streak after the local validity check reset it (the "zombie streak":
    /// badge shows an old count with no completions to back it, then drops on
    /// the next real completion).
    ///
    /// The rescuable clause is deliberately a SUPERSET of what
    /// checkStreakValidity will actually rescue — that rule also reads the
    /// merged completion history, which a pure merge of two blobs cannot see.
    /// Erring wide only ever delays a reset by one merge; erring narrow would
    /// zero out a streak a freeze was about to save, which is the one mistake
    /// this feature must never make.
    private var liveCurrentStreak: Int {
        guard let last = lastCompletedDate else { return 0 }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else {
            return currentStreak
        }
        if calendar.startOfDay(for: last) >= yesterday { return currentStreak }
        if streakFreezeAvailable && currentStreak >= 3 { return currentStreak }
        return 0
    }

    /// Merges streak stats from another device (iCloud sync). Used by both
    /// SyncedSettingsStore's blob merger and EnhancedStreakViewModel's live
    /// heal so the two can never drift apart.
    ///
    /// Rules: truly monotonic fields (longest streak, total days, celebrated
    /// milestones) merge as max/union. The LIVE fields (currentStreak and
    /// the freeze state) are NOT monotonic — a streak legitimately resets —
    /// so they follow the side whose lastCompletedDate is most recent, and
    /// every count is first normalized to what it can still claim today
    /// (liveCurrentStreak), so a stale blob can never resurrect a broken
    /// streak. On the same last-completed day, a date written by a freeze
    /// (streakFreezeCoveredDay != nil) is a placeholder and loses to a side
    /// that actually completed that day. Both devices compute the same
    /// result, so merges converge.
    func merging(_ other: StreakStats) -> StreakStats {
        var merged = self
        merged.longestStreak = max(longestStreak, other.longestStreak)
        merged.totalDaysCompleted = max(totalDaysCompleted, other.totalDaysCompleted)
        merged.celebratedMilestones = celebratedMilestones.union(other.celebratedMilestones)

        let mineLive = liveCurrentStreak
        let theirsLive = other.liveCurrentStreak
        // A side whose lastCompletedDate was written by a freeze is holding a
        // placeholder, not a day the user completed. See streakFreezeCoveredDay.
        let mineBridged = streakFreezeCoveredDay != nil
        let theirsBridged = other.streakFreezeCoveredDay != nil

        switch (lastCompletedDate, other.lastCompletedDate) {
        case (let mine?, let theirs?):
            if theirs > mine {
                merged.currentStreak = theirsLive
                merged.streakFreezeAvailable = other.streakFreezeAvailable
                merged.streakFreezeUsedDate = other.streakFreezeUsedDate
                merged.streakFreezeCoveredDay = other.streakFreezeCoveredDay
            } else if theirs == mine {
                if mineBridged != theirsBridged {
                    // The two sides agree on the day but disagree on what it
                    // MEANS: one completed it, the other only bridged to it
                    // with a freeze. The real completion wins.
                    //
                    // This is the multi-device bug this rule exists for: a
                    // phone that has been in a drawer can spend a freeze off
                    // its own stale counter before iCloud catches it up, and
                    // the bridge lands its lastCompletedDate on the same day
                    // as the phone the user actually uses. Under a plain
                    // max() the drawer phone's resurrected count won and the
                    // active phone's streak jumped with no explanation.
                    // Both devices pick the same side here, so it converges.
                    merged.currentStreak = theirsBridged ? mineLive : theirsLive
                    // The winner completed that day for real, so there is no
                    // bridge left outstanding.
                    merged.streakFreezeCoveredDay = nil
                } else {
                    // Neither (or both) bridged: the higher live count is the
                    // real one (a fresh install starts at 0/1).
                    merged.currentStreak = max(mineLive, theirsLive)
                    merged.streakFreezeCoveredDay = Self.laterDay(streakFreezeCoveredDay,
                                                                  other.streakFreezeCoveredDay)
                }
                // A freeze spent anywhere is spent (symmetric, so devices
                // converge).
                merged.streakFreezeAvailable = streakFreezeAvailable && other.streakFreezeAvailable
                merged.streakFreezeUsedDate = Self.laterDay(streakFreezeUsedDate, other.streakFreezeUsedDate)
            } else {
                merged.currentStreak = mineLive
            }
            merged.lastCompletedDate = max(mine, theirs)
        case (nil, let theirs?):
            merged.currentStreak = theirsLive
            merged.lastCompletedDate = theirs
            merged.streakFreezeAvailable = other.streakFreezeAvailable
            merged.streakFreezeUsedDate = other.streakFreezeUsedDate
            merged.streakFreezeCoveredDay = other.streakFreezeCoveredDay
        case (_?, nil):
            merged.currentStreak = mineLive
        default:
            break
        }
        return merged
    }

    private static func laterDay(_ mine: Date?, _ theirs: Date?) -> Date? {
        switch (mine, theirs) {
        case (let mine?, let theirs?): return max(mine, theirs)
        case (let mine?, nil): return mine
        case (nil, let theirs?): return theirs
        default: return nil
        }
    }

    // MARK: - Validity / freeze decision

    /// What a validity check decided. Returned rather than acted on so the
    /// struct stays pure: writing the "tell them about the freeze" flag and
    /// scheduling the streak-break push are the caller's job (see
    /// EnhancedStreakViewModel.checkStreakValidity). A pure struct is what
    /// lets the whole decision be unit-tested without UserDefaults or firing
    /// real notifications at whoever runs the suite.
    enum ValidityOutcome: Equatable {
        case unchanged
        /// A freeze was spent to bridge the lapse that opened after
        /// `coveredDay` — the last day actually completed before it.
        case freezeSpent(coveredDay: Date)
        case streakBroken(previousStreak: Int)
    }

    /// Decides whether the streak survives the gap since the last completed
    /// day, and if not, whether a freeze rescues it.
    ///
    /// - Parameter history: the MERGED, cross-device record of completed days.
    ///   The decision is made from this rather than from this device's own
    ///   `currentStreak` / `lastCompletedDate`, because those are only as
    ///   fresh as the last time THIS phone synced. Deciding locally meant the
    ///   answer depended on which device opened first: a stale phone saw a
    ///   week-long gap the user never had and spent a freeze to "rescue" a
    ///   count that had long since moved on, while a phone whose counter had
    ///   dropped below 3 could never rescue a run the user genuinely had.
    ///   Two things follow from the merged history and nothing else: how big
    ///   the gap really is, and how long the run before it really was.
    ///
    ///   Pass nil only when no history is available; the check then falls back
    ///   to this device's own record and behaves exactly as it did before.
    @discardableResult
    mutating func checkStreakValidity(history: StreakHistory? = nil) -> ValidityOutcome {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // The last day the user completed ANYWHERE. Taking the later of this
        // device's record and the merged history is what makes every device
        // measure the same gap, whichever one opens first and however stale
        // it is — a device can be behind the truth, never ahead of it.
        let localDay = lastCompletedDate.map { calendar.startOfDay(for: $0) }
        guard let anchorDay = [localDay, history?.lastCompletedDay].compactMap({ $0 }).max() else {
            currentStreak = 0
            return .unchanged
        }

        let daysDifference = calendar.dateComponents([.day], from: anchorDay, to: today).day ?? 0
        guard daysDifference > 1 else { return .unchanged }

        // The run the freeze would be protecting. Read from the merged
        // history, and never below this device's own counter: histories can be
        // thinner than the counter for users whose completions predate the
        // day-completion log, and a freeze must never become HARDER to earn
        // than it is today.
        let historyStreak = history?.consecutiveDays(endingOn: anchorDay) ?? 0
        let protectedStreak = max(currentStreak, historyStreak)
        // A freeze is named by the gap it covers, so a gap already paid for
        // can never be charged twice — milestones hand out fresh freezes, and
        // without this a re-award could be spent on the same lapse again.
        let gapAlreadyCovered = streakFreezeCoveredDay == anchorDay

        if streakFreezeAvailable, protectedStreak >= 3, !gapAlreadyCovered {
            // Spend the freeze. Every field written here is a function of
            // (merged history, today), so two devices deciding for the same
            // lapse produce identical state — one spend, not two.
            streakFreezeAvailable = false
            streakFreezeUsedDate = Date()
            streakFreezeCoveredDay = anchorDay
            // Rescue the run the merged history can actually back, not
            // whatever this device's counter happened to say.
            currentStreak = protectedStreak
            // Bridge the gap so the next completion counts as consecutive.
            // Without this, updateStreak's daysDifference > 1 branch would
            // reset the very streak the freeze just spent itself
            // protecting (and snap the foundation week back to day 1).
            lastCompletedDate = calendar.date(byAdding: .day, value: -1, to: today)
            return .freezeSpent(coveredDay: anchorDay)
        }

        let previousStreak = currentStreak
        currentStreak = 0
        return previousStreak > 0 ? .streakBroken(previousStreak: previousStreak) : .unchanged
    }
}

// MARK: - Completion Celebration Data
struct CompletionCelebration {
    let streakNumber: Int
    let isNewRecord: Bool
    let motivationalMessage: String
    let shareImage: UIImage?
    
    static func generateMessage(for streak: Int, isRecord: Bool) -> String {
        if isRecord {
            return "🏆 NEW RECORD! \(streak) days of speaking LIFE! You're unstoppable!"
        }
        
        switch streak {
        case 1:
            return "🔥 Day 1 Complete! You've started something POWERFUL!"
        case 7:
            return "🔥 ONE WEEK STRONG! Your persistence is moving mountains!"
        case 30:
            return "🔥 30 DAYS! You're transformed by the renewing of your mind!"
        case 100:
            return "🔥 100 DAYS! You're a WARRIOR of faith and declaration!"
        default:
            return "🔥 \(streak) DAYS! Keep speaking life—heaven is listening!"
        }
    }
}

// MARK: - Foundation Week Audio Plan (Days 1-7)

/// One recommendable audio in the foundation week (day-independent).
struct FoundationAudio: Equatable {
    /// `AudioDeclaration.id` — the Firebase Storage filename the audio catalog
    /// keys on (e.g. "psalm9_11.mp3"). Must match the remote catalog exactly.
    let audioId: String
    /// Exact catalog title, shown verbatim on the task card.
    let title: String
    let durationMinutes: Int
}

/// The curated listening sequence for the foundation week. Instead of sending
/// new users into the open catalog, days 1-7 each name one specific audio.
///
/// The week is personalized from the user's onboarding signals: day 1 is
/// always the Psalm 91 anchor (free, universal), then the personal
/// declaration's category (strongest stated intent), then each onboarding-
/// selected category, each mapped to the episode that hits its exact domain.
/// Remaining days top up from the curated default week. After day 7 the
/// listen task returns to the generic personalized-category behavior.
enum FoundationAudioPlan {

    // MARK: Recommendable episodes
    // All verified against the audio catalog ("declarations" filter unless
    // noted) so the deep-link always resolves.

    static let psalm91 = FoundationAudio(audioId: "psalm9_11.mp3",
        title: "Psalm 91: A Shield of Protection", durationMinutes: 2)
    static let longLife = FoundationAudio(audioId: "longlife_v2.mp3",
        title: "Renewed Youth and Long Life Declaration", durationMinutes: 3)
    static let healing = FoundationAudio(audioId: "healed_v2.mp3",
        title: "Healing Declarations", durationMinutes: 5)
    static let peace = FoundationAudio(audioId: "peace_v2.mp3",
        title: "Peace Beyond Understanding", durationMinutes: 3)
    static let identityInChrist = FoundationAudio(audioId: "identity_v2.mp3",
        title: "Identity in Christ", durationMinutes: 4)
    static let victory = FoundationAudio(audioId: "victorious_v2.mp3",
        title: "Living Victoriously in Christ", durationMinutes: 3)
    static let gratitude = FoundationAudio(audioId: "gratitude_v2.mp3",
        title: "A Heart of Gratitude", durationMinutes: 3)
    static let warfare = FoundationAudio(audioId: "warfare_v2.mp3",
        title: "Victory in Spiritual Warfare", durationMinutes: 3)
    static let abundance = FoundationAudio(audioId: "prosperity_v2.mp3",
        title: "Abundance Declarations", durationMinutes: 4)
    static let protection = FoundationAudio(audioId: "godsprotection_v2.mp3",
        title: "Protection Promises", durationMinutes: 4)
    static let brokenhearted = FoundationAudio(audioId: "heartbreak_v2.mp3",
        title: "Healing for the Brokenhearted", durationMinutes: 3)
    static let children = FoundationAudio(audioId: "children_v2.mp3",
        title: "Blessing Our Children", durationMinutes: 3)
    static let miracles = FoundationAudio(audioId: "miracles_v2.mp3",
        title: "Breakthrough and Miracles", durationMinutes: 3)
    static let relationships = FoundationAudio(audioId: "restoration_v2.mp3",
        title: "Restoring Relationships", durationMinutes: 3)
    static let spiritualGrowth = FoundationAudio(audioId: "spiritualGrowth_v2.mp3",
        title: "A Declaration for Spiritual Growth", durationMinutes: 4)
    // "meditation" filter
    static let godsLove = FoundationAudio(audioId: "loveMeditations.mp3",
        title: "The Heart of God's Love", durationMinutes: 8)

    /// Fallback sequence when onboarding gave no (or few) signals — the arc:
    /// protection, long life, healing, peace, identity, victory, gratitude.
    static let defaultWeek: [FoundationAudio] = [
        psalm91, longLife, healing, peace, identityInChrist, victory, gratitude,
    ]

    /// Lowercased `DeclarationCategory` rawValue → the episode that speaks to
    /// that category's exact domain. Covers every category offered in the
    /// onboarding pickers plus the common personal-declaration matches;
    /// unmapped categories simply fall through to the default week.
    static let categoryAudio: [String: FoundationAudio] = [
        // Peace over the mind
        "anxiety": peace, "fear": peace, "rest": peace,
        "mentalhealth": peace, "anger": peace,
        // Healing and the body
        "health": healing, "wellness": healing,
        // Who they are in Christ
        "identity": identityInChrist, "confidence": identityInChrist,
        // Faith and victory
        "faith": victory,
        // Growth and direction
        "wisdom": spiritualGrowth, "grace": spiritualGrowth, "destiny": spiritualGrowth,
        "spiritualgrowth": spiritualGrowth, "obedience": spiritualGrowth, "newseason": spiritualGrowth,
        // Provision
        "wealth": abundance, "work": abundance, "business": abundance,
        "debt": abundance, "favor": abundance, "housing": abundance,
        // Breakthrough when it looks impossible
        "hope": miracles, "miracles": miracles, "hardtimes": miracles,
        // Joy and thanksgiving
        "joy": gratitude, "gratitude": gratitude, "praise": gratitude,
        // Relationships and family
        "marriage": relationships, "relationship": relationships, "friendship": relationships,
        "parenting": children, "singleparent": children, "fertility": children,
        // God's love
        "love": godsLove, "godsheart": godsLove,
        // The wounded heart
        "innerhealing": brokenhearted, "grief": brokenhearted,
        "divorce": brokenhearted, "forgiveness": brokenhearted,
        // Warfare and deliverance
        "warfare": warfare, "addiction": warfare,
        // Protection
        "godsprotection": protection,
    ]

    // MARK: Week building

    /// Builds the personalized 7-day sequence. Pure — pass the stored signals
    /// in. Day 1 is always Psalm 91; the personal declaration's category leads
    /// day 2 (it's the one thing they said they're believing God for), then
    /// the selected categories, then the default week fills the rest. Never
    /// recommends the same episode twice in the week.
    static func personalizedWeek(personalDeclarationCategory: String?,
                                 selectedCategories: [String]) -> [FoundationAudio] {
        var week: [FoundationAudio] = [psalm91]
        func append(_ audio: FoundationAudio) {
            guard week.count < 7, !week.contains(audio) else { return }
            week.append(audio)
        }

        if let raw = personalDeclarationCategory,
           let match = categoryAudio[raw.lowercased()] {
            append(match)
        }
        // Selections are persisted from a Set, so stored order is arbitrary
        // and can differ between launches. Sort so the same picks always
        // yield the same week — otherwise a reshuffle between days could
        // repeat one episode and skip another.
        for category in selectedCategories.map({ $0.lowercased() }).sorted() {
            if let match = categoryAudio[category] { append(match) }
        }
        for audio in defaultWeek { append(audio) }
        return week
    }

    /// Today's recommendation, built from the stored onboarding signals:
    /// the active personal declaration's category and the categories chosen
    /// during onboarding (the same store the checklist personalizes from).
    ///
    /// Each day's pick is PINNED once made (persisted day → audioId). The
    /// signals are live and can change mid-week (new personal declaration via
    /// the breakthrough flow, edited categories); positional indexing into a
    /// rebuilt week would then repeat an already-heard episode and silently
    /// skip the newly relevant one. Instead, a day keeps the episode it was
    /// first given, and an unpinned day takes the highest-priority episode
    /// not yet served — so a new signal's episode plays on the NEXT day
    /// rather than landing in an already-past slot.
    static func recommendation(forDay day: Int) -> FoundationAudio? {
        guard (1...7).contains(day) else { return nil }

        var assignments = loadDayAssignments()
        if let pinnedId = assignments[day], let pinned = episode(forId: pinnedId) {
            return pinned
        }

        let week = personalizedWeek(
            personalDeclarationCategory: PersonalDeclarationRepository.activeCategoryRaw(),
            selectedCategories: UserSelectedCategories.all()
        )
        // First unpinned day past day 1 with no history (fresh pinning store,
        // e.g. an app update landing mid-week): backfill earlier days
        // positionally so today doesn't re-pick an episode those days already
        // recommended under the old positional scheme.
        if assignments.isEmpty && day > 1 {
            for (index, audio) in week.prefix(day - 1).enumerated() {
                assignments[index + 1] = audio.audioId
            }
        }
        let served = Set(assignments.filter { $0.key != day }.values)
        // week holds 7 distinct episodes and at most 6 other days are pinned,
        // so a pick always exists.
        guard let pick = week.first(where: { !served.contains($0.audioId) }) else { return nil }
        assignments[day] = pick.audioId
        saveDayAssignments(assignments)
        return pick
    }

    // MARK: Persisted day assignments

    private static let dayAssignmentsKey = "foundationAudioDayAssignments"

    private static func loadDayAssignments(defaults: UserDefaults = .standard) -> [Int: String] {
        guard let data = defaults.data(forKey: dayAssignmentsKey),
              let decoded = try? JSONDecoder().decode([Int: String].self, from: data) else { return [:] }
        return decoded
    }

    private static func saveDayAssignments(_ assignments: [Int: String], defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(assignments) {
            defaults.set(data, forKey: dayAssignmentsKey)
        }
    }

    private static func episode(forId id: String) -> FoundationAudio? {
        if let match = defaultWeek.first(where: { $0.audioId == id }) { return match }
        return categoryAudio.values.first(where: { $0.audioId == id })
    }
}

// MARK: - User Selected Categories (shared reader)

/// Single reader for the onboarding category picks that DeclarationViewModel
/// persists ("userSelectedCategories", with the legacy "selectedCategory"
/// fallback). The checklist personalization and the foundation audio plan all
/// read through here so the key and encoding live in one place.
enum UserSelectedCategories {
    static func all(defaults: UserDefaults = .standard) -> [String] {
        if let data = defaults.data(forKey: "userSelectedCategories"),
           let categories = try? JSONDecoder().decode([String].self, from: data) {
            return categories
        }
        if let single = defaults.string(forKey: "selectedCategory") { return [single] }
        return []
    }

    /// The user's top picks, in stored order (the checklist personalizes
    /// titles from the first two).
    static func top(_ count: Int = 2, defaults: UserDefaults = .standard) -> [String] {
        Array(all(defaults: defaults).prefix(count))
    }
}

// MARK: - Progressive Task Library
struct TaskLibrary {
    
    // MARK: - Foundation Phase Tasks (Days 1-7)
    static let foundationTasks: [DailyTask] = [
        DailyTask(
            id: "complete_daily_burst",
            title: "Speak Your Daily Burst",
            description: "Seven declarations out loud. This is how you release your faith.",
            icon: "bolt.circle.fill",
            category: .foundation,
            type: .speak,
            difficulty: .beginner,
            minimumStreakDay: 1,
            estimatedMinutes: 3,
            navigationDestination: .burst
        ),
        DailyTask(
            id: "read_devotional",
            title: "Read Daily Devotional",
            description: "Spend time in God's Word and truth",
            icon: "book.fill",
            category: .foundation,
            type: .read,
            difficulty: .beginner,
            minimumStreakDay: 1,
            estimatedMinutes: 5,
            navigationDestination: .devotional
        ),
        DailyTask(
            id: "listen_audio",
            title: "Listen to Audio Affirmation",
            description: "Faith comes by hearing God's Word",
            icon: "headphones",
            category: .foundation,
            type: .listen,
            difficulty: .beginner,
            minimumStreakDay: 1,
            estimatedMinutes: 4,
            navigationDestination: .audioTab
        ),
        DailyTask(
            id: "gratitude_moment",
            title: "Express Gratitude",
            description: "Thank God for one specific blessing today",
            icon: "heart.fill",
            category: .foundation,
            type: .reflect,
            difficulty: .beginner,
            minimumStreakDay: 2,
            estimatedMinutes: 2,
            navigationDestination: .journal
        )
    ]
    
    // MARK: - Personalized Task Generation
    /// Personalizes a task based on user's top selected categories
    /// - Parameters:
    ///   - task: The base task to personalize
    ///   - userCategories: Array of user's selected category strings
    /// - Returns: Personalized task with category-specific titles and descriptions
    static func personalizeTask(_ task: DailyTask, for userCategories: [String]) -> DailyTask {
        let topCategories = Array(userCategories.prefix(2))
        
        guard !topCategories.isEmpty else {
            return task
        }
        
        var personalizedTask = task
        
        switch task.id {
        case "listen_audio":
            if let primaryCategory = topCategories.first {
                personalizedTask.title = "Listen to \(formatCategoryName(primaryCategory)) Audio"
                personalizedTask.description = "Listen to an audio affirmation from your \(formatCategoryName(primaryCategory)) category"
            }
            
        case "read_devotional":
            if topCategories.count >= 2 {
                let cat1 = formatCategoryName(topCategories[0])
                let cat2 = formatCategoryName(topCategories[1])
                personalizedTask.title = "Read \(cat1) or \(cat2) Devotional"
                personalizedTask.description = "Spend time in God's Word focusing on \(cat1) or \(cat2)"
            } else if let primaryCategory = topCategories.first {
                personalizedTask.title = "Read \(formatCategoryName(primaryCategory)) Devotional"
                personalizedTask.description = "Spend time in God's Word focusing on \(formatCategoryName(primaryCategory))"
            }
            
        case "complete_daily_burst":
            // Keep the "this is how you release your faith" signal in the
            // personalized copy too — it's the whole point of the task, and
            // naming the category shouldn't cost the user the reason.
            if let primaryCategory = topCategories.first {
                personalizedTask.description = "Seven \(formatCategoryName(primaryCategory)) declarations out loud. This is how you release your faith."
            }
            
        case "journal_insight":
            if let primaryCategory = topCategories.first {
                personalizedTask.description = "Write about how God is working in your \(formatCategoryName(primaryCategory)) journey"
            }

        case "gratitude_moment":
            if let primaryCategory = topCategories.first {
                personalizedTask.title = "Reflect on \(formatCategoryName(primaryCategory))"
                personalizedTask.description = "Write one honest line about where you need God in your \(formatCategoryName(primaryCategory)) right now"
            }

        case "ask_the_bible":
            if let primaryCategory = topCategories.first {
                personalizedTask.title = "Ask the Bible about \(formatCategoryName(primaryCategory))"
                personalizedTask.description = "Bring a \(formatCategoryName(primaryCategory)) question to Scripture and let the Word answer"
            }
            
        case "memorize_verse":
            if topCategories.count >= 2 {
                let cat1 = formatCategoryName(topCategories[0])
                let cat2 = formatCategoryName(topCategories[1])
                personalizedTask.title = "Memorize \(cat1) or \(cat2) Verse"
                personalizedTask.description = "Learn a verse about \(cat1) or \(cat2)"
            } else if let primaryCategory = topCategories.first {
                personalizedTask.title = "Memorize \(formatCategoryName(primaryCategory)) Verse"
                personalizedTask.description = "Learn a verse about \(formatCategoryName(primaryCategory))"
            }
            
        case "share_affirmation":
            if let primaryCategory = topCategories.first {
                personalizedTask.description = "Share a \(formatCategoryName(primaryCategory)) truth with someone today"
            }
            
        default:
            break
        }
        
        return personalizedTask
    }
    
    private static func formatCategoryName(_ category: String) -> String {
        // Convert category string to readable format
        let formatted = category
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "gods", with: "God's")
            .capitalized
        
        // Handle special cases
        switch category.lowercased() {
        case "health": return "Health"
        case "wealth": return "Wealth"
        case "faith": return "Faith"
        case "love": return "Love"
        case "wisdom": return "Wisdom"
        case "destiny": return "Destiny"
        case "warfare": return "Spiritual Warfare"
        case "anxiety": return "Peace & Anxiety"
        case "marriage": return "Marriage"
        case "parenting": return "Parenting"
        case "work": return "Work & Career"
        case "identity": return "Identity"
        case "hope": return "Hope"
        case "joy": return "Joy"
        case "grace": return "Grace"
        case "rest": return "Rest"
        case "miracles": return "Miracles"
        case "favor": return "God's Favor"
        case "healing", "innerhealing": return "Healing"
        case "protection", "godsprotection": return "God's Protection"
        default: return formatted
        }
    }
    
    // MARK: - Growth Phase Tasks (Days 8-30)
    static let growthTasks: [DailyTask] = [
        DailyTask(
            id: "journal_insight",
            title: "Journal One Insight",
            description: "Write down one thing God showed you today",
            icon: "pencil.and.scribble",
            category: .growth,
            type: .reflect,
            difficulty: .intermediate,
            minimumStreakDay: 8,
            estimatedMinutes: 5,
            navigationDestination: .journal
        ),
        DailyTask(
            id: "memorize_verse",
            title: "Memorize Scripture",
            description: "Learn or review a Bible verse",
            icon: "brain.head.profile",
            category: .growth,
            type: .memorize,
            difficulty: .intermediate,
            minimumStreakDay: 10,
            estimatedMinutes: 8
        ),
        DailyTask(
            id: "worship_song",
            title: "Worship Through Music",
            description: "Listen to or sing a worship song",
            icon: "music.note",
            category: .growth,
            type: .worship,
            difficulty: .beginner,
            minimumStreakDay: 12,
            estimatedMinutes: 6
        ),
        DailyTask(
            id: "study_deeper",
            title: "Deeper Bible Study",
            description: "Study a passage using cross-references",
            icon: "magnifyingglass",
            category: .growth,
            type: .study,
            difficulty: .intermediate,
            minimumStreakDay: 15,
            estimatedMinutes: 12
        ),
        DailyTask(
            id: "prayer_walk",
            title: "Prayer Walk",
            description: "Pray while walking, connecting body and spirit",
            icon: "figure.walk",
            category: .growth,
            type: .worship,
            difficulty: .intermediate,
            minimumStreakDay: 20,
            estimatedMinutes: 10
        )
    ]
    
    // MARK: - Impact Phase Tasks (Days 31-100)
    static let impactTasks: [DailyTask] = [
        DailyTask(
            id: "share_affirmation",
            title: "Share an Affirmation",
            description: "Share God's truth with someone today",
            icon: "square.and.arrow.up.fill",
            category: .impact,
            type: .share,
            difficulty: .intermediate,
            minimumStreakDay: 31,
            estimatedMinutes: 5
        ),
        DailyTask(
            id: "encourage_someone",
            title: "Encourage Someone",
            description: "Send an encouraging message to someone",
            icon: "message.fill",
            category: .impact,
            type: .serve,
            difficulty: .intermediate,
            minimumStreakDay: 35,
            estimatedMinutes: 7
        ),
        DailyTask(
            id: "pray_for_others",
            title: "Pray for Others",
            description: "Intercede for family, friends, or community",
            icon: "hands.and.sparkles.fill",
            category: .impact,
            type: .worship,
            difficulty: .intermediate,
            minimumStreakDay: 40,
            estimatedMinutes: 8
        ),
        DailyTask(
            id: "serve_someone",
            title: "Act of Service",
            description: "Do something kind for someone without expecting return",
            icon: "hands.clap.fill",
            category: .impact,
            type: .serve,
            difficulty: .advanced,
            minimumStreakDay: 50,
            estimatedMinutes: 15
        ),
        DailyTask(
            id: "testimony_share",
            title: "Share Your Testimony",
            description: "Tell someone how God has worked in your life",
            icon: "megaphone.fill",
            category: .impact,
            type: .share,
            difficulty: .advanced,
            minimumStreakDay: 60,
            estimatedMinutes: 10
        )
    ]
    
    // MARK: - Mastery Phase Tasks (Days 100+)
    static let masteryTasks: [DailyTask] = [
        DailyTask(
            id: "mentor_someone",
            title: "Mentor Someone",
            description: "Guide someone younger in faith",
            icon: "person.2.fill",
            category: .mastery,
            type: .teach,
            difficulty: .expert,
            minimumStreakDay: 100,
            estimatedMinutes: 20
        ),
        DailyTask(
            id: "fast_and_pray",
            title: "Fast and Pray",
            description: "Skip a meal and spend time in prayer",
            icon: "leaf.fill",
            category: .mastery,
            type: .worship,
            difficulty: .expert,
            minimumStreakDay: 120,
            estimatedMinutes: 30
        ),
        DailyTask(
            id: "teach_truth",
            title: "Teach God's Truth",
            description: "Teach or explain biblical truth to others",
            icon: "person.crop.circle.fill.badge.plus",
            category: .mastery,
            type: .teach,
            difficulty: .expert,
            minimumStreakDay: 150,
            estimatedMinutes: 25
        ),
        DailyTask(
            id: "create_content",
            title: "Create Spiritual Content",
            description: "Write, record, or create content that encourages others",
            icon: "video.fill",
            category: .mastery,
            type: .share,
            difficulty: .expert,
            minimumStreakDay: 200,
            estimatedMinutes: 30
        )
    ]
    
    // MARK: - All Tasks Combined
    static let allTasks: [DailyTask] = foundationTasks + growthTasks + impactTasks + masteryTasks
    
    // MARK: - Task Selection Logic
    static func getAvailableTasks(for streakDay: Int) -> [DailyTask] {
        return allTasks.filter { $0.minimumStreakDay <= streakDay }
    }
    
    /// Ensures the Daily Burst task is always first so it's the hero "NEXT UP" card.
    /// Burst is the only task that earns the streak — it must never be buried.
    private static func burstFirst(_ tasks: [DailyTask]) -> [DailyTask] {
        guard let burstIndex = tasks.firstIndex(where: { $0.id == "complete_daily_burst" }),
              burstIndex != 0 else { return tasks }
        var reordered = tasks
        let burst = reordered.remove(at: burstIndex)
        reordered.insert(burst, at: 0)
        return reordered
    }

    /// The foundation habits that never graduate. Past the foundation week the
    /// phase mixes narrow down to make room for growth/impact/mastery work, but
    /// speaking (burst) and hearing (audio) are lifelong daily habits, not
    /// first-week exercises — they stay on the checklist forever.
    /// Order follows `foundationTasks`, not the id list.
    private static func keepers(_ ids: [String]) -> [DailyTask] {
        foundationTasks.filter { ids.contains($0.id) }
    }

    /// - Parameter foundationAudioDay: The day (1-7) whose curated audio the
    ///   listen task should point at. Defaults to `streakDay`; the view model
    ///   passes the working day so the recommendation advances each calendar
    ///   day instead of waiting for the burst to bump the streak.
    /// - Parameter enforcementDay: the active Enforcement's day, when one is running. Takes
    ///   precedence over `foundationAudioDay` for the listen task.
    /// - Parameter personalDeclarations: how many the user carries and how many
    ///   are spoken today. nil leaves the row out entirely, which is right for
    ///   anyone who has not started one — a task nobody can finish is worse than
    ///   no task.
    static func getCoreTasksForStreak(_ streakDay: Int, userCategories: [String] = [],
                                      foundationAudioDay: Int? = nil,
                                      enforcementDay: EnforcementDay? = nil,
                                      personalDeclarations: PersonalDeclaration.Progress? = nil) -> [DailyTask] {
        let audioDay = foundationAudioDay ?? streakDay
        // Check if AI features are enabled for enhanced task generation
        if isAIEnabled() {
            let aiTasks = getAIEnhancedTasks(streakDay: streakDay, userCategories: userCategories)
            let planned = applyAudioPlan(to: aiTasks, day: audioDay, enforcementDay: enforcementDay)
            let owned = markCampaignOwned(planned, enforcementDay: enforcementDay)
            return withPersonalDeclaration(burstFirst(owned), progress: personalDeclarations)
        }

        // Standard task generation
        let phase = ProgressionPhase.getPhase(for: streakDay)
        let availableTasks = getAvailableTasks(for: streakDay)
        
        var tasks: [DailyTask]
        
        switch phase {
        case .foundation:
            // Light on day 1 (burst + devotional + audio) to protect the streak,
            // then progressively reveal gratitude, Ask the Bible, etc. as the
            // habit takes hold. Gated by each task's minimumStreakDay.
            tasks = Array(foundationTasks.filter { $0.minimumStreakDay <= streakDay }.prefix(5))
            
        case .growth:
            // Mix foundation and growth tasks
            let foundation = keepers(["complete_daily_burst", "read_devotional", "listen_audio"])
            let growth = availableTasks.filter { $0.category == .growth }
            tasks = foundation + Array(growth.prefix(1))

        case .impact:
            // Mix foundation, growth, and impact tasks
            let foundation = keepers(["complete_daily_burst", "listen_audio"])
            let growth = Array(growthTasks.filter { $0.minimumStreakDay <= streakDay }.prefix(1))
            let impact = availableTasks.filter { $0.category == .impact }
            tasks = foundation + growth + Array(impact.prefix(1))

        case .mastery:
            // Advanced combination with all categories
            let foundation = keepers(["complete_daily_burst", "listen_audio"])
            let impact = Array(impactTasks.filter { $0.minimumStreakDay <= streakDay }.prefix(1))
            let mastery = availableTasks.filter { $0.category == .mastery }

            tasks = foundation + impact + Array(mastery.prefix(1))
        }
        
        // Personalize tasks based on user categories
        if !userCategories.isEmpty {
            tasks = tasks.map { personalizeTask($0, for: userCategories) }
        }

        // The audio plan runs AFTER personalization so the curated day-by-day
        // pick (days 1-7), the open-ended prompt (day 8+), and an active Enforcement's
        // day all win over the generic category title.
        tasks = applyAudioPlan(to: tasks, day: audioDay, enforcementDay: enforcementDay)
        tasks = markCampaignOwned(tasks, enforcementDay: enforcementDay)

        // burstFirst first, THEN the declaration, so the declaration ends up at
        // the front and the Burst directly behind it. Reversing these lets
        // burstFirst hoist the Burst back over the declaration.
        return withPersonalDeclaration(burstFirst(tasks), progress: personalDeclarations)
    }

    /// Adds the declaration row, or replaces it if a caller already had one.
    ///
    /// Always rebuilt from `progress` rather than kept, because its completion
    /// and subtitle are both derived: carrying an old copy forward would show
    /// "2 of 3 spoken" after the third was spoken on another device.
    private static func withPersonalDeclaration(_ tasks: [DailyTask],
                                                progress: PersonalDeclaration.Progress?) -> [DailyTask] {
        var result = tasks.filter { $0.id != personalDeclarationTaskId }
        guard let progress else { return result }
        // Front of the list, ahead of the Burst.
        //
        // The Burst has other ways in and gets finished by them: an active
        // campaign completes it from its own CTA, and the quick-action grid
        // links straight to it. The declaration has no second entry point, and
        // it is the only row made of the user's own words.
        //
        // Runs AFTER `burstFirst`, not before, or that call would move the Burst
        // back over the top of it.
        result.insert(personalDeclarationTask(progress), at: 0)
        return result
    }

    /// Ids of the tasks an active campaign rebuilds. Both are genuinely
    /// different content while one is running: the listen task points at the
    /// campaign's day audio, and the Burst speaks the campaign's seven
    /// declarations instead of the general feed.
    static let campaignOwnedTaskIds: Set<String> = ["complete_daily_burst", "listen_audio"]

    static let personalDeclarationTaskId = "speak_personal_declaration"

    /// The one thing the user is believing God for, as a task.
    ///
    /// It was a card floating below the list, which meant its position was a
    /// judgment call that got re-litigated every time the screen changed, and it
    /// sank under COMPLETED as the day filled in. As a task it inherits the
    /// ordering the list already does correctly: unfinished rises, finished
    /// sinks. Nobody has to decide where it goes again.
    ///
    /// **Completion is derived, never toggled.** It is done when every active
    /// declaration has been spoken today and not before, so the row cannot be
    /// ticked without actually speaking. `EnhancedStreakViewModel.completeTask`
    /// refuses this id for that reason, and the rebuild paths re-derive it
    /// instead of carrying the old value forward.
    ///
    /// **It never earns the streak.** `DailyChecklist.isStreakEarned` reads the
    /// Burst alone, so adding this changes the day's "N of M" and nothing else.
    ///
    /// **It syncs without syncing anything.** Completion comes from
    /// `lastSpokenDate` on each record, and that list already merges across
    /// devices as a union by id. Recording a separate task-completion event
    /// would create a second source of truth that could disagree with the
    /// declarations themselves.
    private static func personalDeclarationTask(_ progress: PersonalDeclaration.Progress) -> DailyTask {
        var task = DailyTask(
            id: personalDeclarationTaskId,
            title: "Speak What You're Believing For",
            description: "",
            icon: "hands.sparkles.fill",
            category: .foundation,
            type: .speak,
            difficulty: .beginner,
            minimumStreakDay: 1,
            estimatedMinutes: 2,
            navigationDestination: .personalDeclaration
        )
        task.isCompleted = progress.allSpoken
        task.description = Self.personalDeclarationSubtitle(progress)
        return task
    }

    /// Says where they actually are, and shows their own words when it can.
    ///
    /// Carrying several, the count wins: "not spoken yet" is a lie when two of
    /// three are done, and one declaration's text would misrepresent the row.
    /// Carrying one, the text wins — that daily reminder is the whole reason the
    /// old feed tile existed, and it should not be lost to a generic subtitle.
    static func personalDeclarationSubtitle(_ progress: PersonalDeclaration.Progress) -> String {
        if progress.total > 1 {
            return progress.allSpoken
                ? "All \(progress.total) spoken today"
                : "\(progress.spokenToday) of \(progress.total) spoken today"
        }
        if progress.allSpoken { return "Spoken today" }
        let text = progress.headline.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? "Speak it out loud over your life" : text
    }

    /// Stamps those two so the checklist can say where they came from.
    ///
    /// Without this the campaign's work is invisible: someone types a sentence,
    /// two tasks quietly change underneath them, and nothing connects the two.
    /// The stamp is what lets the row carry a badge instead of the campaign card
    /// carrying a second copy of the same button.
    private static func markCampaignOwned(_ tasks: [DailyTask],
                                          enforcementDay: EnforcementDay?) -> [DailyTask] {
        guard let enforcementDay else { return tasks }
        return tasks.map { task in
            guard campaignOwnedTaskIds.contains(task.id) else { return task }
            var owned = task
            owned.campaignRefreshed = true
            // The Burst's stock line ("Seven declarations out loud…") is true of
            // every day forever. On a campaign it's seven specific declarations
            // and the day number is the reason to open it.
            if task.id == "complete_daily_burst" {
                owned.description = "Day \(enforcementDay.dayNumber) of \(Enforcement.length), built from what you're standing on."
            }
            return owned
        }
    }

    /// Days 1-7: points the listen task at that day's exact recommended audio
    /// (title, duration, and deep-link id) so the first week builds on a
    /// curated sequence.
    ///
    /// Day 8+: the curated week is over, so the task goes open-ended — no
    /// assigned episode, no deep link, just an invitation to play whatever
    /// builds their faith today. The listen task itself never goes away; faith
    /// keeps coming by hearing long after the foundation week ends.
    ///
    /// - Parameter enforcementDay: When an Enforcement is running it owns the listen task —
    ///   its curated day beats both the foundation week's pick and the day-8+
    ///   open prompt, because the Enforcement is the arc the user actually signed up
    ///   for. Nil restores the pre-Enforcement behavior exactly.
    private static func applyAudioPlan(to tasks: [DailyTask], day: Int,
                                       enforcementDay: EnforcementDay? = nil) -> [DailyTask] {
        if let enforcementDay {
            return tasks.map { task in
                guard task.id == "listen_audio" else { return task }
                var audioTask = task
                audioTask.title = enforcementDay.audioTitle
                audioTask.description = "Day \(enforcementDay.dayNumber) of \(Enforcement.length)"
                audioTask.estimatedMinutes = enforcementDay.audioMinutes
                audioTask.recommendedAudioId = enforcementDay.audioId
                return audioTask
            }
        }

        let audio = FoundationAudioPlan.recommendation(forDay: day)
        return tasks.map { task in
            guard task.id == "listen_audio" else { return task }
            var audioTask = task
            if let audio {
                audioTask.title = audio.title
                audioTask.description = "Day \(day) of 7: today's recommended audio for your foundation"
                audioTask.estimatedMinutes = audio.durationMinutes
                audioTask.recommendedAudioId = audio.audioId
            } else {
                audioTask.title = "Listen to Grow Your Faith"
                audioTask.description = "Play a favorite, or anything that builds your faith today"
                audioTask.recommendedAudioId = nil
            }
            return audioTask
        }
    }
    
    static func getNewlyUnlockedTasks(currentStreak: Int, previousStreak: Int) -> [DailyTask] {
        let currentAvailable = getAvailableTasks(for: currentStreak)
        let previousAvailable = getAvailableTasks(for: previousStreak)
        
        return currentAvailable.filter { task in
            !previousAvailable.contains { $0.id == task.id }
        }
    }
    
    // MARK: - AI Enhanced Task Generation
    
    private static func isAIEnabled() -> Bool {
        // Check if AI features are enabled via UserDefaults
        // This is set by SubscriptionStore when AI features are enabled
        return UserDefaults.standard.bool(forKey: "enableAIFeatures")
    }
    
    private static func getAIEnhancedTasks(streakDay: Int, userCategories: [String]) -> [DailyTask] {
        // AI-powered task selection based on user behavior and spiritual journey
        let phase = ProgressionPhase.getPhase(for: streakDay)
        let availableTasks = getAvailableTasks(for: streakDay)
        
        // Get user behavior data for personalization
        let userBehavior = getUserBehaviorData()
        
        var tasks: [DailyTask] = []
        
        // Core task selection with AI personalization
        switch phase {
        case .foundation:
            tasks = selectFoundationTasksWithAI(availableTasks: availableTasks, userBehavior: userBehavior, streakDay: streakDay)
        case .growth:
            tasks = selectGrowthTasksWithAI(availableTasks: availableTasks, userBehavior: userBehavior, streakDay: streakDay)
        case .impact:
            tasks = selectImpactTasksWithAI(availableTasks: availableTasks, userBehavior: userBehavior, streakDay: streakDay)
        case .mastery:
            tasks = selectMasteryTasksWithAI(availableTasks: availableTasks, userBehavior: userBehavior, streakDay: streakDay)
        }
        
        // Apply AI-driven personalization based on user categories and behavior
        tasks = personalizeTasksForUser(tasks: tasks, userCategories: userCategories, userBehavior: userBehavior)
        
        return tasks
    }
    
    private static func getUserBehaviorData() -> [String: Any] {
        // Get user behavior data from EnhancedAnalyticsService
        let userProfile = EnhancedAnalyticsService.shared.userBehaviorProfile
        
        return [
            "topCategories": Array(userProfile.topCategories.keys),
            "strugglingAreas": userProfile.strugglingAreas,
            "spiritualMaturity": userProfile.spiritualMaturityLevel.rawValue,
            "preferredTaskTypes": [], // Could be derived from user behavior patterns
            "completionPatterns": userProfile.completionRates,
            "weeklyPattern": userProfile.weeklyPattern,
            "currentLifeSeason": userProfile.currentLifeSeason
        ]
    }
    
    private static func selectFoundationTasksWithAI(availableTasks: [DailyTask], userBehavior: [String: Any], streakDay: Int) -> [DailyTask] {
        // AI-enhanced foundation task selection
        let foundationTasks = availableTasks.filter { $0.category == .foundation }
        
        // Prioritize based on user's spiritual maturity and completion patterns
        let prioritizedTasks = foundationTasks.sorted { task1, task2 in
            // AI scoring logic would go here
            return task1.minimumStreakDay <= task2.minimumStreakDay
        }
        
        return Array(prioritizedTasks.prefix(5))
    }
    
    private static func selectGrowthTasksWithAI(availableTasks: [DailyTask], userBehavior: [String: Any], streakDay: Int) -> [DailyTask] {
        // AI-enhanced growth task selection
        let baseGrowthTasks = availableTasks.filter { $0.category == .growth }

        // AI determines optimal mix based on user progress
        var tasks = keepers(["complete_daily_burst", "read_devotional", "listen_audio"])
        tasks.append(contentsOf: Array(baseGrowthTasks.prefix(1)))

        return tasks
    }

    private static func selectImpactTasksWithAI(availableTasks: [DailyTask], userBehavior: [String: Any], streakDay: Int) -> [DailyTask] {
        // AI-enhanced impact task selection
        let impactTasks = availableTasks.filter { $0.category == .impact }
        let growthTasks = availableTasks.filter { $0.category == .growth }

        // AI balances challenge and foundation
        var tasks = keepers(["complete_daily_burst", "listen_audio"])
        tasks.append(contentsOf: Array(growthTasks.prefix(1)))
        tasks.append(contentsOf: Array(impactTasks.prefix(1)))

        return tasks
    }

    private static func selectMasteryTasksWithAI(availableTasks: [DailyTask], userBehavior: [String: Any], streakDay: Int) -> [DailyTask] {
        // AI-enhanced mastery task selection
        let masteryTasks = availableTasks.filter { $0.category == .mastery }
        let impactTasks = availableTasks.filter { $0.category == .impact }

        // AI creates advanced spiritual practice combinations. Burst and audio
        // ride along — a 100-day streak still needs the task that earns it.
        var tasks = keepers(["complete_daily_burst", "listen_audio"])
        tasks.append(contentsOf: Array(impactTasks.prefix(1)))
        tasks.append(contentsOf: Array(masteryTasks.prefix(1)))

        return tasks
    }
    
    private static func personalizeTasksForUser(tasks: [DailyTask], userCategories: [String], userBehavior: [String: Any]) -> [DailyTask] {
        // Apply the same onboarding-category personalization the standard path
        // uses, so titles/descriptions reflect the user's selections regardless
        // of whether AI task selection is enabled.
        guard !userCategories.isEmpty else { return tasks }
        return tasks.map { personalizeTask($0, for: userCategories) }
    }
}
