//
//  EnhancedStreakViewModel.swift
//  SpeakLifeServices
//
//  Enhanced streak view model with daily checklist functionality.
//
//  Foundation + Combine only (`ObservableObject` and `@Published` come
//  from Combine, not SwiftUI). The 1800-line UIKit share-image renderer
//  that used to live at the bottom of this file moved to the app-side
//  `StreakShareCardRenderer`; the view model calls through
//  `shareImageRenderer` — a closure the app installs at startup with
//  `EnhancedStreakViewModel.shareImageRenderer = { StreakShareCardRenderer.render($0) }`.
//

import Foundation
import Combine
import SpeakLifeCore
import SpeakLifePersistence

public final class EnhancedStreakViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published public var todayChecklist: DailyChecklist
    @Published public var streakStats: StreakStats
    @Published public var showCompletionCelebration = false
    @Published public var celebrationData: CompletionCelebration?
    @Published public var showFireAnimation = false
    @Published public var badgeManager: BadgeManager
    @Published public var showBadgeUnlock = false
    @Published public var showFirstTaskConfetti = false
    // Fix 4: Show banner when streak freeze was auto-applied
    @Published public var showFreezeUsedMessage = false

    // MARK: - Private Properties
    private let userDefaults = UserDefaults.standard
    private let checklistKey = "dailyChecklist"
    private let streakStatsKey = "streakStats"
    private let hasAutoCompletedFirstTaskKey = "hasAutoCompletedFirstTask"

    /// "A freeze was spent — tell the user." SYNCED across devices (see the
    /// SyncedSettingsStore whitelist), so the phone that did not apply the
    /// freeze still explains why the number moved.
    private static let freezeUsedFlagKey = "streakFreezeWasUsed"
    /// Local-only on purpose, and never whitelisted for sync: which freeze
    /// THIS device has already shown the banner for. The flag above syncs
    /// one-way (a bool that is only ever raised), so clearing it locally is
    /// not enough — the still-true remote row gets pushed straight back and
    /// the banner would re-fire on every launch of the device that spent the
    /// freeze. Keyed on the freeze's identity so each device announces each
    /// freeze exactly once.
    private static let freezeBannerShownKey = "streakFreezeBannerShownFor"

    /// Streak days that earn a full-screen celebration. Every other completed
    /// day gets only a haptic + the auto-collapsing completed banner.
    public static let celebrationMilestones: Set<Int> = [1, 3, 7, 14, 30, 50, 100, 200, 365]

    /// Where streak decisions send their push side effects. Production always
    /// uses the real service; tests swap in a double, because the ordering of
    /// these calls against the iCloud heal is the thing worth pinning down and
    /// UNUserNotificationCenter offers no way to observe it.
    public static var notifications: StreakNotifying = NoOpStreakNotifier.shared

    /// Foundation-typed hook the app installs at startup with the UIKit
    /// share-card renderer. Nil in the package (and in tests), which means
    /// `celebrationData.shareImage` comes back nil — the share sheet already
    /// handles that path. Public so `EnhancedStreakView` can install a
    /// per-instance renderer if the app ever needs one.
    public typealias ShareImageRenderer = (StreakShareRenderArgs) -> Any?
    public static var shareImageRenderer: ShareImageRenderer?

    /// Notification names that used to reference `UIApplication` directly.
    /// Injected as `Notification.Name` values so this file does not import
    /// UIKit. The app installs the real names at startup via
    /// `EnhancedStreakViewModel.LifecycleNames.install(...)`; the defaults
    /// use empty names (which never fire), safe for `swift test`.
    public struct LifecycleNames {
        public static var didBecomeActive: Notification.Name = Notification.Name("__speaklife_never_fires_didBecomeActive__")
        public static var calendarDayChanged: Notification.Name = .NSCalendarDayChanged

        public static func install(didBecomeActive: Notification.Name) {
            Self.didBecomeActive = didBecomeActive
        }
    }

    // MARK: - User Preferences
    /// Retrieves user's top 2 selected categories from UserDefaults
    /// - Returns: Array of category strings (max 2) for task personalization
    private func getUserTopCategories() -> [String] {
        UserSelectedCategories.top()
    }

    /// The streak day the user is working on TODAY: the day already earned
    /// today, or the next day when today is still unearned. Task generation is
    /// keyed to `currentStreak`, which only advances after the burst — so a
    /// user opening the app on the morning of day 2 would otherwise still see
    /// day 1's foundation audio. This gives the audio plan a day that rolls
    /// over with the calendar. A broken streak resets it to 1, restarting the
    /// foundation week from the top.
    public var workingStreakDay: Int {
        if let last = streakStats.lastCompletedDate,
           Calendar.current.isDateInToday(last) {
            return max(1, streakStats.currentStreak)
        }
        return streakStats.currentStreak + 1
    }

    // MARK: - Initialization
    public init() {
        self.todayChecklist = Self.createTodayChecklist()
        self.streakStats = StreakStats()
        self.badgeManager = BadgeManager()

        loadData()  // This now handles checkStreakValidity internally when needed

        // Heal the badge against the authoritative per-day burst history right
        // at launch. Without this, an undercounted streakStats (day earned on
        // another device, or a burst recorded without its checklist task) only
        // healed when an iCloud sync event happened to fire.
        reconcileWithSyncedProgress()

        // A freeze may have been spent inside loadData() above (first launch
        // of a new day), or on the user's other device before this one opened.
        // Announce it now rather than waiting for a background/foreground
        // round trip that may never come this session.
        //
        // The hop off init is the one place it is needed: this view model is
        // built inside a SwiftUI view's initializer, and publishing from there
        // would be a change made during a view update. Everywhere else the
        // banner is raised synchronously on main.
        DispatchQueue.main.async { [weak self] in self?.showFreezeUsedBannerIfNeeded() }

        checkForNewBadges()

        // Refresh tasks with user categories after loading
        refreshTasksWithUserCategories()

        // Schedule evening notification for today with current progress
        scheduleEveningCheckIn()

        // Listen for app becoming active to check for new day
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: LifecycleNames.didBecomeActive,
            object: nil
        )

        // Also roll over when the calendar day changes while the app is open and
        // in the foreground across midnight — didBecomeActive doesn't fire then.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: LifecycleNames.calendarDayChanged,
            object: nil
        )

        // iCloud sync: heal streak stats when progress earned on the user's
        // other devices arrives (burst history union, merged settings blob).
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSyncedProgressChanged),
            name: BurstCompletionTracker.historyMergedNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSyncedProgressChanged),
            name: SyncedSettingsStore.settingsDidChange,
            object: nil
        )
        // Bonus-task completions cross devices as taskCompletion events.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleProgressEventsChanged),
            name: ProgressSyncStore.dataDidChange,
            object: nil
        )
    }

    // MARK: - iCloud Sync Healing

    @objc private func handleSyncedProgressChanged(_ notification: Notification) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.handleSyncedProgressChanged(notification) }
            return
        }
        // A freeze spent on the user's other device reaches this one as this
        // flag — announce it, so the number never moves without explanation.
        var announceFreeze = false
        if notification.name == SyncedSettingsStore.settingsDidChange,
           let keys = notification.userInfo?["keys"] as? Set<String> {
            announceFreeze = keys.contains(Self.freezeUsedFlagKey)

            // A declaration spoken, added, or closed out on another device
            // arrives as this key. The checklist row is derived from that list,
            // so it has to be rebuilt or the row keeps yesterday's answer:
            // "1 of 2 spoken" on a phone where the second was already spoken.
            // Nothing else carries this state, which is exactly why it syncs
            // correctly — there is only one copy of the truth.
            if keys.contains(PersonalDeclarationStorageKey.value) {
                refreshTasksForCampaignChange()
            }

            // Otherwise only react when the streak blob itself was applied.
            guard keys.contains(streakStatsKey) else {
                if announceFreeze { showFreezeUsedBannerIfNeeded() }
                return
            }
        }
        reconcileWithSyncedProgress()
        // ORDER MATTERS: the banner is bounded by the freeze's IDENTITY, and
        // that identity (streakFreezeCoveredDay) lives in the synced blob that
        // reconcileWithSyncedProgress folds in just above. Announcing first
        // would read this device's stale in-memory stats — on the receiving
        // device, which never spent the freeze, both freeze dates are still
        // nil there, so the identity would fall through to today's date and
        // stamp the wrong one. The flag syncs one-way (boolOr), so a remote
        // row still holding true comes back later, by which point the real
        // covered day HAS landed, the stamp no longer matches, and the banner
        // fires a second time — the exact double-fire the identity exists to
        // prevent. (It cuts the other way too: a genuinely new freeze spent
        // later the same day would be swallowed by that stale "today" stamp.)
        if announceFreeze { showFreezeUsedBannerIfNeeded() }
    }

    /// Merges progress synced from the user's other devices into the live
    /// streak state. Historical fields (longest streak, totals, milestones)
    /// only ever move UP; the live currentStreak follows the most recent
    /// completion (StreakStats.merging), so a broken streak is never
    /// resurrected by a stale device's old blob.
    private func reconcileWithSyncedProgress() {
        var changed = false
        let streakBefore = streakStats.currentStreak

        // 1. Fold in the synced streakStats blob (SyncedSettingsStore already
        //    union-merged it with the other devices' copies) using the same
        //    merge rules the store uses, so the two can never disagree.
        if let data = userDefaults.data(forKey: streakStatsKey),
           let synced = try? JSONDecoder().decode(StreakStats.self, from: data) {
            let merged = streakStats.merging(synced)
            if merged != streakStats {
                streakStats = merged
                changed = true
            }
        }

        // 2. Heal from the merged burst history — the authoritative record.
        //    (Safe to only raise here: the tracker derives its streak by
        //    walking actual completion days back from today, so a broken
        //    streak computes low and never inflates.)
        let tracker = BurstCompletionTracker.shared
        let burstStreak = tracker.currentStreak
        if burstStreak > streakStats.currentStreak {
            streakStats.currentStreak = burstStreak
            streakStats.longestStreak = max(streakStats.longestStreak, burstStreak)
            changed = true
        }
        let uniqueDays = tracker.getUniqueDaysCount()
        if uniqueDays > streakStats.totalDaysCompleted {
            streakStats.totalDaysCompleted = uniqueDays
            changed = true
        }
        if let latestDay = tracker.completions.map(\.date).max() {
            let day = Calendar.current.startOfDay(for: latestDay)
            if streakStats.lastCompletedDate.map({ day > $0 }) ?? true {
                streakStats.lastCompletedDate = day
                changed = true
            }
            // A real completed day past the one a freeze bridged over retires
            // that bridge: lastCompletedDate is backed by an actual day again,
            // so it must stop being treated as a placeholder in merging().
            if let coveredDay = streakStats.streakFreezeCoveredDay, day > coveredDay {
                streakStats.streakFreezeCoveredDay = nil
                changed = true
            }
        }

        // 3. If today's burst was completed on another device, reflect it in
        //    today's checklist — without re-firing celebrations or analytics
        //    (the device that earned the day already did). Only touch the
        //    checklist when it actually belongs to today: around midnight
        //    this can run before the new-day rollover regenerates it, and
        //    stamping yesterday's checklist would corrupt it.
        if Calendar.current.isDateInToday(todayChecklist.date),
           tracker.hasTodaysCompletion(),
           let index = todayChecklist.tasks.firstIndex(where: { $0.id == "complete_daily_burst" }),
           !todayChecklist.tasks[index].isCompleted {
            let wasChecklistComplete = todayChecklist.isCompleted
            let completedAt = tracker.getTodaysCompletion()?.completedAt ?? Date()
            todayChecklist.tasks[index].isCompleted = true
            todayChecklist.tasks[index].completedAt = completedAt
            if todayChecklist.completedAt == nil && todayChecklist.isStreakEarned {
                todayChecklist.completedAt = completedAt
            }
            // The day is done — clear the now-wrong "streak at risk" push and
            // refresh the evening check-in with the real progress (the local
            // completion path does both; the synced path must too).
            Self.notifications.cancelStreakAtRiskNotification()
            scheduleEveningCheckIn()
            if !wasChecklistComplete && todayChecklist.isCompleted {
                checklistCompletionSyncedRemotely = true
            }
            changed = true
        }

        if changed {
            saveData()
            // A healed streak day changes which tasks (and which foundation
            // audio) today should show — regenerate, preserving completions.
            if streakStats.currentStreak != streakBefore {
                refreshTasksWithUserCategories()
            }
        }

        // Deliberately outside the `changed` guard and run on every reconcile:
        // this is the exact moment a break decided moments ago in loadData() —
        // off history iCloud had not delivered yet — gets overturned. If the
        // break was real, the count is still 0 here (the tracker walks actual
        // completion days back from today, so it cannot inflate one) and the
        // push correctly stands.
        revokeStreakBreakNotificationIfStreakAlive()
    }

    // MARK: - Synced Task Completions (bonus tasks, via event log)

    /// True while the most recent full-checklist completion came from another
    /// device. The checklist view consumes this to skip the full-screen
    /// celebration — the device that earned it already celebrated.
    private var checklistCompletionSyncedRemotely = false

    public func consumeRemoteCompletionFlag() -> Bool {
        let wasRemote = checklistCompletionSyncedRemotely
        checklistCompletionSyncedRemotely = false
        return wasRemote
    }

    @objc private func handleProgressEventsChanged(_ notification: Notification) {
        if let kinds = notification.userInfo?["kinds"] as? Set<String>,
           !kinds.contains(ProgressSyncStore.Kind.taskCompletion) {
            return
        }
        // Asynchronous fetch; the completion runs on main, where the
        // @Published checklist must be mutated anyway.
        ProgressSyncStore.shared.events(ofKind: ProgressSyncStore.Kind.taskCompletion) { [weak self] events in
            self?.applySyncedTaskCompletions(events)
        }
    }

    /// Overlays bonus-task completions earned on other devices (taskCompletion
    /// events, one row per day+task, union-merged by CloudKit) onto today's
    /// checklist. Additive only, matched by id, and deliberately EXCLUDES the
    /// burst task: the streak day is only ever credited through the
    /// authoritative BurstCompletionTracker channel (step 3 above), so a
    /// checklist row can never mark a day earned ahead of the streak record.
    /// Runs on the main queue.
    private func applySyncedTaskCompletions(_ events: [ProgressSyncStore.Event]) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.applySyncedTaskCompletions(events) }
            return
        }
        guard Calendar.current.isDateInToday(todayChecklist.date) else { return }

        let todayPrefix = BurstCompletionTracker.dayStamp(for: Date()) + "|"
        let wasChecklistComplete = todayChecklist.isCompleted
        var changed = false

        for event in events where event.key.hasPrefix(todayPrefix) {
            let taskId = String(event.key.dropFirst(todayPrefix.count))
            guard taskId != "complete_daily_burst",
                  let index = todayChecklist.tasks.firstIndex(where: { $0.id == taskId }),
                  !todayChecklist.tasks[index].isCompleted else { continue }
            todayChecklist.tasks[index].isCompleted = true
            todayChecklist.tasks[index].completedAt = Self.taskCompletionDate(from: event.payload) ?? event.createdAt
            changed = true
        }

        guard changed else { return }
        if !wasChecklistComplete && todayChecklist.isCompleted {
            checklistCompletionSyncedRemotely = true
        }
        saveData()
        // Progress changed — refresh the evening check-in so it doesn't nag
        // about tasks already finished on another device.
        scheduleEveningCheckIn()
        checkForNewBadges()
    }

    private static func taskCompletionKey(taskId: String) -> String {
        "\(BurstCompletionTracker.dayStamp(for: Date()))|\(taskId)"
    }

    private static func taskCompletionPayload(completedAt: Date) -> Data? {
        try? JSONSerialization.data(withJSONObject: ["completedAt": completedAt.timeIntervalSince1970])
    }

    private static func taskCompletionDate(from payload: Data?) -> Date? {
        guard let payload = payload,
              let object = try? JSONSerialization.jsonObject(with: payload) as? [String: Any],
              let epoch = object["completedAt"] as? Double else { return nil }
        return Date(timeIntervalSince1970: epoch)
    }

    // MARK: - Task Personalization
    /// Refreshes daily tasks with user category personalization while preserving completion status
    public func refreshTasksWithUserCategories() {
        let userCategories = getUserTopCategories()
        guard !userCategories.isEmpty else { return }

        // Re-personalize all current tasks based on streak level
        let currentStreak = streakStats.currentStreak > 0 ? streakStats.currentStreak : 1
        let freshTasks = TaskLibrary.getCoreTasksForStreak(currentStreak, userCategories: userCategories,
                                                           foundationAudioDay: workingStreakDay,
                                                           enforcementDay: EnforcementService.shared.enabledActiveDay,
                                                           personalDeclarations: PersonalDeclarationProgressBridge.todayProgress(),
                                                           guardCompletedToday: TakeItCaptiveService.shared.enabledCompletedToday,
                                                           totalDaysCompleted: totalDaysCompleted)

        // Preserve completion status from existing tasks
        let existingCompletions = Dictionary(uniqueKeysWithValues: todayChecklist.tasks.map {
            ($0.id, ($0.isCompleted, $0.completedAt))
        })

        todayChecklist.tasks = freshTasks.map { task in
            var updatedTask = task
            // The declaration and Guarding rows are derived — from how many
            // declarations are spoken today, and from whether today's rep is
            // done — so neither may inherit a stale value. Carrying one forward
            // would show the declaration row done after a rebuild that saw a new
            // declaration added, or the Guard row done on a day whose rep has
            // not been taken yet.
            if task.id != TaskLibrary.personalDeclarationTaskId,
               task.id != TaskLibrary.guardTaskId,
               let (wasCompleted, completedAt) = existingCompletions[task.id] {
                updatedTask.isCompleted = wasCompleted
                updatedTask.completedAt = completedAt
            }
            return updatedTask
        }

        saveData()
    }

    /// Rebuilds today's tasks after a campaign starts, switches, or is abandoned.
    ///
    /// `todayChecklist` is only regenerated on day rollover, streak change, and
    /// re-personalization — none of which a campaign start triggers. Without
    /// this, someone who starts a campaign today keeps the tasks that were built
    /// with `enforcementDay: nil`: no CampaignBadge, the Burst's generic
    /// description, and a listen row still deep-linked to the foundation-week
    /// episode instead of the campaign's audio — while the card above it says
    /// all of that is in their daily tasks.
    ///
    /// Deliberately not `refreshTasksWithUserCategories`, which returns early
    /// when the user has no chosen categories and so cannot be relied on here.
    public func refreshTasksForCampaignChange() {
        let currentStreak = streakStats.currentStreak > 0 ? streakStats.currentStreak : 1
        let freshTasks = TaskLibrary.getCoreTasksForStreak(currentStreak,
                                                           userCategories: getUserTopCategories(),
                                                           foundationAudioDay: workingStreakDay,
                                                           enforcementDay: EnforcementService.shared.enabledActiveDay,
                                                           personalDeclarations: PersonalDeclarationProgressBridge.todayProgress(),
                                                           guardCompletedToday: TakeItCaptiveService.shared.enabledCompletedToday,
                                                           totalDaysCompleted: totalDaysCompleted)

        // Completions must survive: starting a campaign after speaking today's
        // Burst must not un-check it and hand back a streak day already banked.
        let existingCompletions = Dictionary(uniqueKeysWithValues: todayChecklist.tasks.map {
            ($0.id, ($0.isCompleted, $0.completedAt))
        })

        todayChecklist.tasks = freshTasks.map { task in
            var updatedTask = task
            // The declaration and Guarding rows are derived — from how many
            // declarations are spoken today, and from whether today's rep is
            // done — so neither may inherit a stale value. Carrying one forward
            // would show the declaration row done after a rebuild that saw a new
            // declaration added, or the Guard row done on a day whose rep has
            // not been taken yet.
            if task.id != TaskLibrary.personalDeclarationTaskId,
               task.id != TaskLibrary.guardTaskId,
               let (wasCompleted, completedAt) = existingCompletions[task.id] {
                updatedTask.isCompleted = wasCompleted
                updatedTask.completedAt = completedAt
            }
            return updatedTask
        }

        saveData()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Public Methods
    public func autoCompleteFirstTaskIfDemoCompleted(hasCompletedDemo: Bool) {
        // Check if we've already auto-completed once globally
        let hasAlreadyAutoCompleted = userDefaults.bool(forKey: hasAutoCompletedFirstTaskKey)
        guard !hasAlreadyAutoCompleted else { return }

        // Only auto-complete if demo was completed and no tasks have been completed yet
        // The Burst by id, not whatever happens to be first. The demo IS the
        // Burst, and the first row is no longer it — the declaration sits ahead
        // of it now. Worse, `completeTask` refuses the declaration id by design,
        // so targeting position would silently no-op while still setting the
        // has-auto-completed flag, and the user would never get the credit.
        guard hasCompletedDemo,
              todayChecklist.completedTasksCount == 0,
              let firstTask = todayChecklist.tasks.first(where: { $0.id == "complete_daily_burst" }),
              !firstTask.isCompleted else { return }

        // Mark that we've auto-completed so it won't happen again
        userDefaults.set(true, forKey: hasAutoCompletedFirstTaskKey)

        // Auto-complete the first task with animation delay for UX
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.completeTaskWithCelebration(taskId: firstTask.id)
        }
    }

    private func completeTaskWithCelebration(taskId: String) {
        // Complete the task with immediate celebration
        completeTask(taskId: taskId)

        // Show confetti animation immediately for first task completion
        self.showFirstTaskConfetti = true

        // Hide confetti after 2.5 seconds with smooth fade
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            self?.showFirstTaskConfetti = false
        }
    }

    public func completeTask(taskId: String) {
        // The declaration row is earned by speaking, not by ticking. Its state
        // comes from `lastSpokenDate` on each record, so a manual completion
        // here would be overwritten by the next rebuild anyway — and worse, it
        // would record a task-completion event, creating a second source of
        // truth that could disagree with the declarations across devices.
        guard taskId != TaskLibrary.personalDeclarationTaskId else { return }
        // Same rule, same reason: the Guarding row is earned by rejecting the
        // thought and SPEAKING the counter out loud. Ticking it by hand would
        // record ground the user never took, and the next rebuild — which
        // re-derives it from TakeItCaptiveService — would undo the tick anyway.
        // The row's tap opens the drill instead (see
        // ModernDailyChecklistView.handleTaskNavigation).
        guard taskId != TaskLibrary.guardTaskId else { return }
        guard let taskIndex = todayChecklist.tasks.firstIndex(where: { $0.id == taskId }),
              !todayChecklist.tasks[taskIndex].isCompleted else { return }

        let task = todayChecklist.tasks[taskIndex]

        // Routed through CoreAnalytics so the daily-habit loop is visible in
        // PostHog (retention/funnels), not Firebase alone. The Firebase sink
        // still receives it via FirebaseAnalyticsProvider.
        CoreAnalytics.track("checklist_task_completed", parameters: [
            "task_id": taskId,
            "task_category": task.category.rawValue,
            "task_type": task.type.rawValue,
            "task_difficulty": task.difficulty.rawValue,
            "streak_day": streakStats.currentStreak,
            "current_phase": todayChecklist.currentPhase.rawValue,
            "estimated_minutes": task.estimatedMinutes,
            "is_newly_unlocked": task.isNewlyUnlocked,
            "is_burst": taskId == "complete_daily_burst",
            // Foundation week: which curated audio this listen task pointed at
            "recommended_audio_id": task.recommendedAudioId ?? "none"
        ])

        todayChecklist.tasks[taskIndex].isCompleted = true
        todayChecklist.tasks[taskIndex].completedAt = Date()

        // Mirror bonus-task completions to iCloud so the user's other devices
        // show them too. The burst is excluded: its day is carried by the
        // authoritative BurstCompletionTracker dayCompletion event.
        if taskId != "complete_daily_burst" {
            ProgressSyncStore.shared.recordEvent(
                kind: ProgressSyncStore.Kind.taskCompletion,
                key: Self.taskCompletionKey(taskId: taskId),
                payload: Self.taskCompletionPayload(completedAt: Date())
            )
        }

        // Premium celebration feedback
        StreakFeedback.onTaskCompleted()
        StreakFeedback.playGentleSuccess()

        // Streak is earned as soon as the Daily Burst is completed.
        // All other tasks (devotional, audio, gratitude, etc.) are bonus — they
        // show progress in the checklist UI but don't gate the streak.
        if todayChecklist.isStreakEarned && todayChecklist.completedAt == nil {
            completeDay()
        }

        // The burst also advances an active Enforcement, so the user has one action to
        // do, not two. Idempotent per calendar day, and deliberately not
        // premium-gated so a lapsed subscriber still finishes their campaign.
        if taskId == "complete_daily_burst", EnforcementService.shared.isEnabled {
            let enforcementId = EnforcementService.shared.progress.activeEnforcementId
            switch EnforcementService.shared.advanceIfNeeded() {
            case .advanced(let day):
                CoreAnalytics.track("enforcement_day_completed", parameters: [
                    "enforcement_id": enforcementId ?? "unknown",
                    "day": day - 1
                ])
            case .completed(let id, let elapsedDays):
                CoreAnalytics.track("enforcement_day_completed", parameters: [
                    "enforcement_id": id, "day": Enforcement.length
                ])
                // elapsed_days > 7 means they dropped off and came back, which is
                // the behavior worth measuring — not just clean 7-day runs.
                CoreAnalytics.track("enforcement_completed", parameters: [
                    "enforcement_id": id, "elapsed_days": elapsedDays
                ])
            case .notActive, .alreadyAdvancedToday:
                break
            }
        }

        saveData()
        checkForNewBadges()

        // Update evening notification based on current progress
        scheduleEveningCheckIn()
    }

    public func uncompleteTask(taskId: String) {
        // Same reason as `completeTask`: derived state, not user-settable.
        guard taskId != TaskLibrary.personalDeclarationTaskId else { return }
        // And ground taken is never given back — there is no code path in this
        // feature that lowers the count, so there must not be one that unticks
        // the row it came from.
        guard taskId != TaskLibrary.guardTaskId else { return }
        guard let taskIndex = todayChecklist.tasks.firstIndex(where: { $0.id == taskId }),
              todayChecklist.tasks[taskIndex].isCompleted else { return }

        todayChecklist.tasks[taskIndex].isCompleted = false
        todayChecklist.tasks[taskIndex].completedAt = nil

        // If day was completed but now a task is unchecked, mark day as incomplete
        if todayChecklist.completedAt != nil {
            todayChecklist.completedAt = nil
        }

        // Deleting the synced event propagates the un-check (and stops this
        // device's own row from resurrecting it).
        if taskId != "complete_daily_burst" {
            ProgressSyncStore.shared.deleteEvent(
                kind: ProgressSyncStore.Kind.taskCompletion,
                key: Self.taskCompletionKey(taskId: taskId)
            )
        }

        saveData()
    }

    public func resetDay() {
        // Clear today's synced completion events so the reset sticks instead
        // of being re-overlaid from iCloud.
        for task in todayChecklist.tasks where task.isCompleted && task.id != "complete_daily_burst" {
            ProgressSyncStore.shared.deleteEvent(
                kind: ProgressSyncStore.Kind.taskCompletion,
                key: Self.taskCompletionKey(taskId: task.id)
            )
        }
        let currentStreak = max(1, streakStats.currentStreak)
        todayChecklist = createProgressiveChecklist(for: currentStreak)
        saveData()
    }

    // MARK: - Progressive Task System
    public func updateTasksForNewStreak() {
        let currentStreak = streakStats.currentStreak
        let previousStreak = currentStreak - 1

        // Check if we've entered a new phase
        let currentPhase = ProgressionPhase.getPhase(for: currentStreak)
        let previousPhase = ProgressionPhase.getPhase(for: previousStreak)

        // Analytics for phase progression
        if currentPhase != previousPhase {
            CoreAnalytics.track("phase_progression", parameters: [
                "previous_phase": previousPhase.rawValue,
                "new_phase": currentPhase.rawValue,
                "streak_day": currentStreak
            ])
        }

        // Get newly unlocked tasks
        let newTasks = TaskLibrary.getNewlyUnlockedTasks(currentStreak: currentStreak, previousStreak: previousStreak)

        if !newTasks.isEmpty {
            todayChecklist.newTasksUnlocked = newTasks.map { $0.id }

            // Analytics for new task unlocks
            for newTask in newTasks {
                CoreAnalytics.track("task_unlocked", parameters: [
                    "task_id": newTask.id,
                    "task_category": newTask.category.rawValue,
                    "task_type": newTask.type.rawValue,
                    "task_difficulty": newTask.difficulty.rawValue,
                    "unlock_streak_day": currentStreak,
                    "current_phase": currentPhase.rawValue
                ])
            }

            // Mark new tasks as newly unlocked for UI celebration
            for newTask in newTasks {
                if let index = todayChecklist.tasks.firstIndex(where: { $0.id == newTask.id }) {
                    todayChecklist.tasks[index].isNewlyUnlocked = true
                }
            }
        }

        // Fix 4: Award a new streak freeze at milestone days
        let freezeMilestones = [7, 14, 30, 60, 100]
        if freezeMilestones.contains(streakStats.currentStreak) {
            streakStats.streakFreezeAvailable = true
        }

        // Update current phase
        todayChecklist.currentPhase = currentPhase

        // Generate new task list for today based on current streak and user preferences
        let userCategories = getUserTopCategories()
        let updatedTasks = TaskLibrary.getCoreTasksForStreak(currentStreak, userCategories: userCategories,
                                                             foundationAudioDay: workingStreakDay,
                                                           enforcementDay: EnforcementService.shared.enabledActiveDay,
                                                           personalDeclarations: PersonalDeclarationProgressBridge.todayProgress(),
                                                           guardCompletedToday: TakeItCaptiveService.shared.enabledCompletedToday,
                                                           totalDaysCompleted: totalDaysCompleted)

        // Preserve completion status for existing tasks
        let existingCompletions = Dictionary(uniqueKeysWithValues: todayChecklist.tasks.map { ($0.id, $0.isCompleted) })

        todayChecklist.tasks = updatedTasks.map { task in
            var updatedTask = task
            // Derived, so never inherited. See the note on the other rebuild.
            if task.id != TaskLibrary.personalDeclarationTaskId,
               task.id != TaskLibrary.guardTaskId,
               let wasCompleted = existingCompletions[task.id] {
                updatedTask.isCompleted = wasCompleted
                if wasCompleted {
                    updatedTask.completedAt = Date()
                }
            }
            return updatedTask
        }

        saveData()
    }

    private func createProgressiveChecklist(for streakDay: Int) -> DailyChecklist {
        let today = Calendar.current.startOfDay(for: Date())
        let phase = ProgressionPhase.getPhase(for: streakDay)
        let userCategories = getUserTopCategories()
        let tasks = TaskLibrary.getCoreTasksForStreak(streakDay, userCategories: userCategories,
                                                      foundationAudioDay: workingStreakDay,
                                                           enforcementDay: EnforcementService.shared.enabledActiveDay,
                                                           personalDeclarations: PersonalDeclarationProgressBridge.todayProgress(),
                                                           guardCompletedToday: TakeItCaptiveService.shared.enabledCompletedToday,
                                                           totalDaysCompleted: totalDaysCompleted)

        return DailyChecklist(
            date: today,
            tasks: tasks,
            currentPhase: phase
        )
    }

    public func getUpcomingUnlocks(for streakDay: Int) -> [DailyTask] {
        let nextFewDays = (streakDay + 1)...(streakDay + 10)
        var upcomingTasks: [DailyTask] = []

        for day in nextFewDays {
            let newTasks = TaskLibrary.getNewlyUnlockedTasks(currentStreak: day, previousStreak: day - 1)
            upcomingTasks.append(contentsOf: newTasks)
            if upcomingTasks.count >= 3 { break } // Limit to next 3 unlocks
        }

        return upcomingTasks
    }

    // MARK: - Private Methods
    /// The streak number ANY user-facing surface should show.
    ///
    /// There are two streak sources and they routinely disagree:
    ///
    /// - `streakStats.currentStreak` is a maintained counter, healed from sync
    ///   and from `checkStreakValidity`.
    /// - `BurstCompletionTracker.currentStreak` is derived by walking the
    ///   merged day-completion log, which only contains days recorded through
    ///   `recordBurstCompletion` — so it undercounts anyone whose history
    ///   predates the tracker.
    ///
    /// `completeDay()` already reconciles them with a max before writing the
    /// streak and before firing `streak_day_completed`, so the reconciled value
    /// is the real one. Anything that reads a raw source instead ends up
    /// disagreeing with the badge — which is exactly what shipped: the badge
    /// said 10 while the burst celebration's "Day Streak" card said 3.
    ///
    /// Read this. Do not read either source directly for display.
    public var displayStreak: Int {
        max(streakStats.currentStreak, BurstCompletionTracker.shared.currentStreak)
    }

    private func completeDay() {
        let today = Date()
        todayChecklist.completedAt = today

        // Capture longestStreak BEFORE updateStreak modifies it (fixes isNewRecord always being false)
        let longestStreakBefore = streakStats.longestStreak
        streakStats.updateStreak(for: today)

        // BurstCompletionTracker is the authoritative source of truth (calculates from actual history).
        // streakStats can fall out of sync if checkStreakValidity() resets it incorrectly.
        // Use whichever value is higher to ensure we never show a lower streak than reality.
        // This sync must run BEFORE updateTasksForNewStreak below: tasks (including
        // the foundation week's "Day N of 7" audio) are generated from
        // streakStats.currentStreak and are not regenerated afterwards, so a
        // late rescue would leave a day-1 checklist next to a rescued streak.
        let burstStreak = BurstCompletionTracker.shared.currentStreak
        let currentStreakNumber = max(streakStats.currentStreak, burstStreak)

        // Sync streakStats if it fell behind
        if currentStreakNumber > streakStats.currentStreak {
            streakStats.currentStreak = currentStreakNumber
            streakStats.longestStreak = max(streakStats.longestStreak, currentStreakNumber)
        }

        // Update tasks for new streak milestone
        updateTasksForNewStreak()

        let isNewRecord = currentStreakNumber > longestStreakBefore

        // THE core retention event — fires the moment a streak day is earned.
        // Previously untracked, which is why D1/D7 streak retention was invisible
        // in PostHog. Everything in the retention funnel hangs off this.
        CoreAnalytics.track("streak_day_completed", parameters: [
            "streak_day": currentStreakNumber,
            "is_new_record": isNewRecord,
            "longest_streak": streakStats.longestStreak,
            "total_days_completed": streakStats.totalDaysCompleted,
            "tasks_completed": todayChecklist.completedTasksCount,
            "total_tasks": todayChecklist.tasks.count,
            "phase": todayChecklist.currentPhase.rawValue
        ])

        // Premium celebration for daily goal completion
        StreakFeedback.onDayCompleted()
        StreakFeedback.playForStreakMilestone(currentStreakNumber)

        if isNewRecord {
            StreakFeedback.onNewRecord()
        }

        // Decide whether this day earns a full-screen celebration.
        // Meaningful = a not-yet-celebrated milestone day. Ordinary days get only
        // the haptic above (including the distinct new-record haptic) plus the
        // auto-collapsing completed banner, so celebrations stay rare and never
        // re-fire after a streak is rebuilt.
        //
        // Note: we deliberately do NOT trigger on "new personal record." Because
        // updateStreak() pins longestStreak to currentStreak on every completion,
        // a user extending their all-time-best streak sets a new record EVERY
        // day — so a record-based trigger would fire daily and defeat the goal.
        let isMilestoneDay = Self.celebrationMilestones.contains(currentStreakNumber)
        let isNewMilestone = isMilestoneDay && !streakStats.celebratedMilestones.contains(currentStreakNumber)

        if isNewMilestone {
            streakStats.celebratedMilestones.insert(currentStreakNumber)
        }

        if isNewMilestone {
            // Create celebration data (share image is expensive — only build it
            // when we're actually going to show the celebration)
            let motivational = getMotivationalMessage()
            celebrationData = CompletionCelebration(
                streakNumber: currentStreakNumber,
                isNewRecord: isNewRecord,
                motivationalMessage: CompletionCelebration.generateMessage(
                    for: currentStreakNumber,
                    isRecord: isNewRecord
                ),
                shareImage: Self.shareImageRenderer?(
                    StreakShareRenderArgs(
                        currentStreak: currentStreakNumber,
                        milestone: getMilestone(for: currentStreakNumber),
                        motivationalMessage: motivational
                    )
                )
            )

            // Show fire animation first, then celebration, then badges
            showFireAnimation = true

            // [weak self]: this timer must not be what keeps the view model
            // alive. A strong capture here outlives the screen that owns it by
            // two seconds and then publishes into it, which in the suite means
            // a torn-down view model waking up mid-way through the NEXT test
            // and writing its streak into the shared UserDefaults.
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                self?.showFireAnimation = false
                self?.showCompletionCelebration = true
            }
        }

        saveData()

        // Fix 2: Cancel streak-at-risk notification since day is complete
        Self.notifications.cancelStreakAtRiskNotification()

        // The comeback the break push asks for has already happened — today is
        // earned. Left standing, it fires tomorrow morning telling a user with
        // a live streak to restart.
        revokeStreakBreakNotificationIfStreakAlive()

        // Celebrate streak milestones (3/7/30/100) with a next-morning push —
        // only on a genuinely new milestone, so rebuilding past one after a break
        // never re-fires the push.
        if isNewMilestone {
            Self.notifications.scheduleStreakMilestoneIfNeeded(
                currentStreak: currentStreakNumber,
                previousStreak: currentStreakNumber - 1
            )
        }

        // Check for badges AFTER completing the day to ensure proper timing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.checkForNewBadges()
        }
    }

    /// UIKit-free public entry so the app can render a share image for a
    /// button tap even outside of the milestone celebration path. Wraps
    /// `Self.shareImageRenderer` with the same StreakShareRenderArgs the
    /// milestone path builds.
    public func generateShareImage() -> Any? {
        Self.shareImageRenderer?(
            StreakShareRenderArgs(
                currentStreak: streakStats.currentStreak,
                milestone: getMilestone(for: streakStats.currentStreak),
                motivationalMessage: getMotivationalMessage()
            )
        )
    }

    /// The merged, cross-device record of the days the user actually completed.
    ///
    /// BurstCompletionTracker's history is the local mirror of every device's
    /// ProgressSyncStore `dayCompletion` rows (union-merged by CloudKit, never
    /// pruned), so this is the same set on every device once sync has
    /// delivered — which is exactly what makes the freeze decision below
    /// independent of which phone happens to open first.
    private static func mergedStreakHistory() -> StreakHistory {
        StreakHistory(dates: BurstCompletionTracker.shared.completions.map(\.date))
    }

    private func checkStreakValidity() {
        // The struct decides; the side effects live here, so the decision
        // itself stays a pure, testable function of (merged history, today).
        switch streakStats.checkStreakValidity(history: Self.mergedStreakHistory()) {
        case .freezeSpent:
            // Raised, not shown, here: the banner is drawn once per freeze per
            // device by showFreezeUsedBannerIfNeeded(), which also reaches the
            // user's OTHER device when this flag syncs.
            userDefaults.set(true, forKey: Self.freezeUsedFlagKey)
            // The freeze carried the run through the gap, so a break notice
            // still pending from an earlier, thinner read of the history is
            // now describing something that didn't happen.
            revokeStreakBreakNotificationIfStreakAlive()
        case .streakBroken(let previousStreak):
            // Notify user that their streak was broken (Fix 1)
            Self.notifications.scheduleStreakBreakNotification(previousStreak: previousStreak)
        case .unchanged:
            revokeStreakBreakNotificationIfStreakAlive()
        }
        saveData()
    }

    /// Revokes a pending or delivered "your streak broke" push once the streak
    /// is back on its feet.
    ///
    /// The break decision is made from whatever completion history THIS device
    /// has synced so far, and the push it schedules doesn't fire until the next
    /// morning at 9am. The first launch of a new day is both when the decision
    /// is most likely to be wrong — iCloud hasn't delivered the days earned on
    /// the user's other device yet — and when the scheduling happens. Seconds
    /// later `reconcileWithSyncedProgress()` folds the real history in and the
    /// count comes back, but nothing used to withdraw the push: it fired the
    /// next morning announcing a broken streak, with a stale count, to a user
    /// whose badge had been alive the whole time and who had completed twice
    /// since.
    ///
    /// A live streak is the one fact that makes the notice false, whichever way
    /// it got that way — freeze, sync heal, or the user simply coming back — so
    /// that is the single condition this checks.
    private func revokeStreakBreakNotificationIfStreakAlive() {
        guard streakStats.currentStreak > 0 else { return }
        Self.notifications.cancelStreakBreakNotification()
    }

    /// Shows the "streak freeze used" banner at most once per freeze, per
    /// device — on the phone that applied it AND on the phone that only
    /// received the result, and never twice on either.
    ///
    /// Clearing the synced flag is necessary but NOT sufficient: it syncs as a
    /// one-way boolean, so a remote row still holding true is pushed back here
    /// on the next reconcile and the banner would fire again every launch. The
    /// freeze's identity — the day it covers, which is the same value on every
    /// device for the same lapse — is what actually bounds it.
    private func showFreezeUsedBannerIfNeeded() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.showFreezeUsedBannerIfNeeded() }
            return
        }
        guard userDefaults.bool(forKey: Self.freezeUsedFlagKey) else { return }

        // Covered day first (identical across devices for one freeze), then
        // the used-date (merged as the later of the two sides, so also
        // stable), then today — a last-resort bound of one banner per day
        // rather than one per launch.
        let identity = BurstCompletionTracker.dayStamp(
            for: streakStats.streakFreezeCoveredDay ?? streakStats.streakFreezeUsedDate ?? Date()
        )
        userDefaults.set(false, forKey: Self.freezeUsedFlagKey)
        guard userDefaults.string(forKey: Self.freezeBannerShownKey) != identity else { return }
        userDefaults.set(identity, forKey: Self.freezeBannerShownKey)
        showFreezeUsedMessage = true
    }

    @objc private func appDidBecomeActive() {
        // May arrive off-main (e.g. NSCalendarDayChanged); this mutates
        // @Published state, so always run on the main thread.
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.appDidBecomeActive() }
            return
        }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let checklistDate = calendar.startOfDay(for: todayChecklist.date)

        if today != checklistDate {
            // New day, create fresh checklist with progressive tasks
            checkStreakValidity()
            let currentStreak = max(1, streakStats.currentStreak)
            todayChecklist = createProgressiveChecklist(for: currentStreak)
            saveData()
            // The same order launch uses (loadData, then reconcile). The
            // validity check above sees only what THIS device has synced, so a
            // rollover landing while the app sits in the background can break a
            // streak the user never missed — and until now nothing here
            // overturned it before the next cold launch. Reconciling folds the
            // authoritative burst history in: it withdraws the break push,
            // regenerates the day's tasks from the real streak day (preserving
            // completions), and credits a burst already done on the user's
            // other device.
            reconcileWithSyncedProgress()
            checkForNewBadges()

            // Schedule evening notification for the new day with current progress
            scheduleEveningCheckIn()
        }

        // Fix 4: Show banner if a streak freeze was used — either while the
        // app was away, or by the rollover immediately above. Deliberately
        // AFTER the rollover: the device that applies the freeze should
        // explain itself in the same session, not next launch.
        showFreezeUsedBannerIfNeeded()
    }

    private static func createTodayChecklist() -> DailyChecklist {
        let today = Calendar.current.startOfDay(for: Date())
        // Start with day 1 for new users
        let initialTasks = TaskLibrary.getCoreTasksForStreak(1)
        return DailyChecklist(
            date: today,
            tasks: initialTasks,
            currentPhase: .foundation
        )
    }

    // MARK: - Data Persistence
    private func saveData() {
        // Save checklist
        if let checklistData = try? JSONEncoder().encode(todayChecklist) {
            userDefaults.set(checklistData, forKey: checklistKey)
        }

        // Save streak stats
        if let statsData = try? JSONEncoder().encode(streakStats) {
            userDefaults.set(statsData, forKey: streakStatsKey)
        }

        // Also save current streak as simple integer for notifications to use
        userDefaults.set(streakStats.currentStreak, forKey: "currentStreak")
    }

    #if DEBUG
    // MARK: - Debug Helpers (compiled out of release)

    /// Simulates completing today AS the given streak day, running the real
    /// `completeDay()` path so celebration gating behaves exactly as in production.
    /// Use to land on day 7, 30, etc. without grinding real days.
    public func debugCompleteAs(streakDay day: Int) {
        let calendar = Calendar.current
        if day <= 1 {
            streakStats.currentStreak = 0
            streakStats.lastCompletedDate = nil
        } else {
            streakStats.currentStreak = day - 1
            streakStats.longestStreak = max(streakStats.longestStreak, day - 1)
            streakStats.lastCompletedDate = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: Date()))
        }
        todayChecklist.completedAt = nil
        completeDay()
    }

    /// Simulates breaking the streak (as if several days were missed).
    public func debugBreakStreak() {
        streakStats.currentStreak = 0
        streakStats.lastCompletedDate = Calendar.current.date(byAdding: .day, value: -5, to: Date())
        todayChecklist.completedAt = nil
        saveData()
    }

    /// Forgets all celebrated milestones — re-arms every celebration for testing.
    public func debugClearCelebratedMilestones() {
        streakStats.celebratedMilestones = []
        saveData()
    }
    #endif

    private func loadData() {
        // Load streak stats first (needed for creating new checklist)
        if let statsData = userDefaults.data(forKey: streakStatsKey),
           let stats = try? JSONDecoder().decode(StreakStats.self, from: statsData) {
            streakStats = stats

            // Migration: existing users have no celebrated-milestone history.
            // Seed every milestone they've already reached (<= longest streak)
            // so we never re-celebrate something they've clearly seen before.
            if streakStats.celebratedMilestones.isEmpty && streakStats.longestStreak > 0 {
                streakStats.celebratedMilestones = Self.celebrationMilestones.filter { $0 <= streakStats.longestStreak }
                if let migrated = try? JSONEncoder().encode(streakStats) {
                    userDefaults.set(migrated, forKey: streakStatsKey)
                }
            }
        }

        // Load checklist
        if let checklistData = userDefaults.data(forKey: checklistKey),
           let checklist = try? JSONDecoder().decode(DailyChecklist.self, from: checklistData) {

            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let checklistDate = calendar.startOfDay(for: checklist.date)

            if today == checklistDate {
                // Same day - use saved checklist with completion status
                todayChecklist = checklist
            } else {
                // Different day - create fresh checklist for new day
                checkStreakValidity()
                let currentStreak = max(1, streakStats.currentStreak)
                todayChecklist = createProgressiveChecklist(for: currentStreak)
                saveData()
            }
        } else {
            // No saved checklist - create fresh one based on current streak
            let currentStreak = max(1, streakStats.currentStreak)
            todayChecklist = createProgressiveChecklist(for: currentStreak)
            saveData()
        }
    }

    private func getMilestone(for streak: Int) -> String {
        switch streak {
        case 7...13: return "Faith Builder"
        case 14...29: return "Word Warrior"
        case 30...49: return "Faith Overcomer"
        case 50...99: return "Kingdom Heir"
        case 100...199: return "Covenant Keeper"
        case 200...364: return "Spiritual Giant"
        case 365...: return "Destiny Carrier"
        default: return ""
        }
    }

    private func getMotivationalMessage() -> String {
        let messages = [
            "Every word you speak has the power to transform your reality!",
            "You are rewriting your story with words of LIFE!",
            "Your consistency is building an unstoppable future!",
            "Speaking life daily - this is how legends are made!",
            "Your words are creating the life you were meant to live!"
        ]

        // Use streak number to pick consistent message
        let index = streakStats.currentStreak % messages.count
        return messages[index]
    }

    // MARK: - Badge System Integration

    private func checkForNewBadges() {
        // Fix 3: Use real tracked values from UserDefaults instead of hardcoded zeros
        let affirmationsSpoken = userDefaults.integer(forKey: "totalAffirmationsSpoken")
        let versesRead = userDefaults.integer(forKey: "totalVersesRead")
        let socialShares = userDefaults.integer(forKey: "totalSocialShares")
        let favoritesAdded = userDefaults.integer(forKey: "totalFavoritesAdded")
        let userStats = UserStats(
            affirmationsSpoken: affirmationsSpoken,
            versesRead: versesRead,
            socialShares: socialShares,
            favoritesAdded: favoritesAdded,
            categoriesCompleted: Set<String>()
        )

        let previousBadgeCount = badgeManager.unlockedBadgeCount
        badgeManager.checkForNewBadges(streakStats: streakStats, userStats: userStats,
                                       completedEnforcementIds: EnforcementService.shared.progress.completedEnforcementIds)

        // Only show badge unlock if a NEW badge was unlocked this check
        if let _ = badgeManager.recentlyUnlocked,
           badgeManager.unlockedBadgeCount > previousBadgeCount {


            // Show badge unlock after main celebrations if they're showing, otherwise immediately
            let delay: Double = (showFireAnimation || showCompletionCelebration) ? 6.0 : 1.0

            // [weak self] for the same reason as the celebration timers: these
            // nest to eight seconds, and a strong capture makes the view model
            // — and every NotificationCenter observer it registered in init —
            // outlive the screen that owns it by that long.
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self, self.badgeManager.recentlyUnlocked != nil else { return }
                if !self.showFireAnimation && !self.showCompletionCelebration {
                    self.showBadgeUnlock = true
                } else {
                    // Wait a bit more if celebrations are still showing.
                    // Guard against re-firing after the popup was already shown and dismissed
                    // (e.g. via the burst view's own 1.5 s trigger).
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                        guard let self, self.badgeManager.recentlyUnlocked != nil else { return }
                        self.showBadgeUnlock = true
                    }
                }
            }
        }
    }

    public func dismissBadgeUnlock() {
        showBadgeUnlock = false
        badgeManager.clearRecentlyUnlocked()
    }

    // MARK: - Notification Scheduling

    /// Foundation-typed sweep of the three legacy notification identifiers
    /// `scheduleEveningCheckIn()` used to inline. Installed by the app at
    /// startup (`AppDelegate.installStreakLegacyNotificationCleanup(...)`)
    /// with `UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers:)`.
    /// Nil in tests, so `EnhancedStreakViewModel.init` can build without
    /// touching `UNUserNotificationCenter.current()` — which traps under
    /// `swift test` because the executable has no bundle identifier.
    public static var cancelLegacyDailyNotifications: (_ identifiers: [String]) -> Void = { _ in }

    public func scheduleEveningCheckIn() {
        // Cancel all old daily system notifications (no longer sent daily)
        Self.cancelLegacyDailyNotifications(["FallbackEveningNotification",
                                             "streak_crushed_it",
                                             "PersonalizedEveningNotification"])

        // Streak is safe once the burst is done — cancel at-risk immediately.
        // Only send at-risk when user has an active streak AND hasn't done their burst yet.
        let burstDone = todayChecklist.isStreakEarned

        if !burstDone && streakStats.currentStreak >= 1 {
            Self.notifications.scheduleStreakAtRiskNotification(
                currentStreak: streakStats.currentStreak
            )
        } else {
            Self.notifications.cancelStreakAtRiskNotification()
        }
    }

}

// MARK: - Legacy Compatibility
extension EnhancedStreakViewModel {
    // Bridge to existing StreakViewModel interface
    public var currentStreak: Int { streakStats.currentStreak }
    public var longestStreak: Int { streakStats.longestStreak }
    public var totalDaysCompleted: Int { streakStats.totalDaysCompleted }
    public var hasCurrentStreak: Bool { streakStats.currentStreak > 0 }

    public var titleText: String {
        let streak = streakStats.currentStreak
        return streak == 1 ? "\(streak) day" : "\(streak) days"
    }

    public var subTitleText: String {
        let longest = streakStats.longestStreak
        return longest == 1 ? "\(longest) day" : "\(longest) days"
    }

    public var subTitleDetailText: String {
        let total = streakStats.totalDaysCompleted
        return total == 1 ? "\(total) day" : "\(total) days"
    }
}
