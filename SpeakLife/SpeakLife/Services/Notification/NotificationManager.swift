//
//  NotificationManager.swift
//  Dios Es Aqui
//
//  Created by Riccardo Washington on 2/20/22.
//

import UserNotifications
import Foundation

let resyncNotification = NSNotification.Name("NotificationsDone")
let notificationNavigate = NSNotification.Name("NavigateToContent")
let declarationsContentUpdated = NSNotification.Name("DeclarationsContentUpdated")

final class NotificationManager: NSObject {
    
    static let shared = NotificationManager()
    
    var lastScheduledNotificationDate: Date? {
        get {
            UserDefaults.standard.object(forKey: "lastScheduledNotificationDate") as? Date
        } set {
            guard let newValue = newValue else {
                UserDefaults.standard.removeObject(forKey: "lastScheduledNotificationDate")
                return
            }
            UserDefaults.standard.set(newValue, forKey: "lastScheduledNotificationDate")
            scheduleBatchRefresh(batchEndsAt: newValue)
        }
    }
    
    func notificationCategories() -> Set<DeclarationCategory> {
        [DeclarationCategory.destiny, .gratitude, .faith, .identity, .grace, .joy, .rest]
    }

    private override init() {}

    /// Submits a background-refresh request to the OS. Injected as a
    /// Foundation-typed closure so this file does not import `BackgroundTasks`;
    /// the app target installs the real `BGTaskScheduler.shared.submit(...)`
    /// implementation on startup (see `AppDelegate.installBackgroundTaskSubmitter`).
    /// Defaults to a no-op so unit tests exercising `scheduleBatchRefresh` do
    /// not touch the scheduler.
    var submitBackgroundTask: (_ identifier: String, _ earliestBeginDate: Date?) -> Void = { _, _ in }

    private let notificationProcessor = NotificationProcessor(service: LocalAPIClient())
    
    let notificationCenter = UNUserNotificationCenter.current()
    
    
    func registerNotifications(count: Int,
                               startTime: Int,
                               endTime: Int,
                               categories: Set<DeclarationCategory>? = nil,
                               callback: (() -> Void)? = nil) {
        let actualCount = max(5, count) // Ensure minimum of 1 notification
        
        // Log notification scheduling for verification
        
        removeNotifications()
        
        // Check if AI features are enabled for enhanced notifications
        // Note: This would need access to SubscriptionStore instance in a real implementation
        // For now, we'll add a simple check here that can be expanded later
//        if shouldUseAINotifications() {
//            registerAIEnhancedNotifications(count: count, startTime: startTime, endTime: endTime, categories: categories, callback: callback)
//            return
//        }
        
        // Use original notification system
        // Enough for every day in the batch, not just one day's worth. Asking
        // for `actualCount` left the scheduling loop with nothing to cycle
        // through, so all four days of a batch carried identical declarations.
        let poolSize = actualCount * Self.daysAhead(forCount: actualCount)
        let resolved = categories ?? notificationCategories()
        let notifications = getNotificationData(for: poolSize, categories: resolved)

        // Remember what this batch is about to send, so the NEXT rebuild does
        // not re-draw it. Once for the whole pool rather than per request.
        NotificationProcessor.rememberSent(notifications.map(\.body))

        prepareNotifications(declarations: notifications,
                             startTime: startTime,
                             endTime: endTime,
                             count: actualCount) {
            callback?()
        }
        // Schedule checklist notifications (cleans up legacy IDs from prior versions)
        scheduleChecklistNotifications()
    }
    

    /// Called when remote declaration content updates (version bump). Reschedules
    /// notifications immediately using the user's current saved preferences so
    /// pending notifications reflect the new content without waiting for the
    /// next natural resync cycle (~24 h).
    func rescheduleFromUserDefaults() {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: "notificationEnabled") else { return }

        let count     = defaults.integer(forKey: "notificationCount")
        let startTime = defaults.integer(forKey: "startTimeIndex")
        let endTime   = defaults.integer(forKey: "endTimeIndex")
        let catString = defaults.string(forKey: "selectedNotificationCategories") ?? ""
        let parsed    = Set(catString.components(separatedBy: ",").compactMap { DeclarationCategory($0) })
        // Respect the user's saved selection exactly. Only fall back to a
        // generic mix when nothing is saved at all.
        let categories: Set<DeclarationCategory> = parsed.isEmpty
            ? [.destiny, .gratitude, .faith, .identity, .grace, .joy, .rest]
            : parsed

        registerNotifications(
            count: max(count, 5),
            startTime: startTime,
            endTime: endTime,
            categories: categories
        )
    }

    func getNotificationData(for count: Int,
                                     categories: Set<DeclarationCategory>?)  ->  [NotificationProcessor.NotificationData] {
        var notificationData: [NotificationProcessor.NotificationData] = []
        
        if let categories = categories {
            notificationProcessor.getNotificationData(count: count, categories: Array(categories)) { data in
                notificationData = data
            }
        } else {
            notificationProcessor.getNotificationData(count: count, categories: nil) { data in
                notificationData = data
            }
        }
        
        return notificationData
    }
    
    
    
    /// How many days ahead one batch covers.
    ///
    /// iOS allows up to 64 pending notifications per app. We share that budget
    /// with 7 lifecycle pushes (D1-D30) + 14 daily burst weekday triggers
    /// (7 morning + 7 evening) + a few streak/lapsed slots. 40 leaves ~24 slots
    /// of headroom, keeping us under the OS cap so iOS never silently drops
    /// sends.
    ///   count=5  → 8 days (40 notifications) + ~21 system = 61 total
    ///   count=10 → 4 days (40 notifications) + ~21 system = 61 total
    ///   count=20 → 2 days (40 notifications) + ~21 system = 61 total
    ///
    /// Shared by the fetch and the scheduling loop: if those two disagree about
    /// the horizon, the loop runs off the end of the pool and starts repeating,
    /// which is the bug this whole helper exists to prevent recurring.
    static func daysAhead(forCount count: Int) -> Int {
        let maxPendingPerBatch = 40
        return max(1, min(10, maxPendingPerBatch / max(count, 1)))
    }

    private func prepareNotifications(declarations: [NotificationProcessor.NotificationData],
                                      startTime: Int,
                                      endTime: Int,
                                      count: Int,
                                      callback: (() -> Void)? = nil) {

        let hourMinute = distributeTimes(startTime: startTime, endTime: endTime, count: count)

        guard hourMinute.count > 1 else { callback?(); return }
        guard declarations.count >= count else { callback?(); return }

        let daysAhead = Self.daysAhead(forCount: count)
        let now = Date()
        let calendar = Calendar.autoupdatingCurrent

        // An active Enforcement takes over slot 0 of each day. It REPLACES a slot
        // rather than adding one: the 64-pending budget documented above has no
        // headroom, so an Enforcement must cost zero net notifications.
        let activeEnforcement = EnforcementService.shared.enabledActiveDay != nil
            ? EnforcementService.shared.activeEnforcement : nil
        let enforcementStartDay = EnforcementService.shared.progress.currentDay

        for day in 0..<daysAhead {
            for idx in 0..<count {
                // Walk forward through the pool so each day gets its own
                // declarations.
                //
                // This read `(idx + day * count) % declarations.count`, and the
                // caller hands over exactly `count` declarations — so the
                // modulus WAS `count`, `day * count` cancelled to zero, and
                // every day resolved to `idx`. The comment said it cycled for
                // variety; it did the opposite, serving the same handful over
                // and over. `registerNotifications` now fetches
                // `count * daysAhead` so there is genuinely something to walk
                // through, and the modulo is only a guard against the pool
                // coming back short.
                guard !declarations.isEmpty else { break }
                let declarationIndex = (day * count + idx) % declarations.count
                let decl = declarations[declarationIndex]

                var body = decl.body
                if decl.book.count > 1 {
                    body += " ~ " + decl.book
                }

                // Slot 0 carries the Enforcement's anchor for that day, projected
                // forward one day at a time and clamped at the final day.
                //
                // Deliberately NO "Day 4 of 7" counter in the push. The batch is
                // scheduled up to 10 days ahead and an Enforcement only advances when
                // the user actually speaks their burst, so a projected counter
                // runs ahead of the truth for exactly the person who has stopped
                // showing up — the one we're trying to win back. Telling them
                // "Day 6 of 7" when they're on day 3 reads as an app that isn't
                // paying attention. The counter stays in the app, where it is
                // always exact; the push carries the theme and the day's line.
                var enforcementTitle: String?
                var enforcementCategory: String?
                var isEnforcementPrompt = false
                if idx == 0, let enforcement = activeEnforcement {
                    let projected = min(enforcementStartDay + day, Enforcement.length)
                    if let enforcementDay = enforcement.day(projected) {
                        // Belt and braces: assembly already requires a reference,
                        // but an authored campaign or future content edit could
                        // ship one without, and " ~ " with nothing after it is a
                        // visible defect in the push.
                        body = enforcementDay.anchorBook.isEmpty
                            ? enforcementDay.anchorText
                            : enforcementDay.anchorText + " ~ " + enforcementDay.anchorBook
                        // displayTitle: this goes into the push. A campaign
                        // begun before the naming fix has the old title in its
                        // persisted blob, and a notification reading "Enforcing
                        // Warfare & Victory" lands on the lock screen.
                        enforcementTitle = enforcement.displayTitle
                        enforcementCategory = enforcement.theme.rawValue
                    }
                } else if idx == 0, let prompt = EnforcementPrompt.copy(forDayOffset: day) {
                    // No campaign running: once a week, slot 0 invites them to
                    // name what they're walking through. Same slot the anchor
                    // would occupy, so the two can never collide and the pending
                    // count is unchanged either way.
                    body = prompt.body
                    enforcementTitle = prompt.title
                    isEnforcementPrompt = true
                }

                // Calculate the exact fire date for this day + time slot
                let baseDate = calendar.date(byAdding: .day, value: day, to: now)!
                let targetDate = calendar.date(bySettingHour: hourMinute[idx].hour,
                                               minute: hourMinute[idx].minute,
                                               second: 0,
                                               of: baseDate)!

                // Skip slots that have already passed (only relevant for day 0)
                guard targetDate > now else { continue }

                let content = UNMutableNotificationContent()
                content.title = enforcementTitle ?? "SpeakLife"
                content.body = body
                content.sound = UNNotificationSound.default
                if isEnforcementPrompt {
                    // No `category` key: that one routes to the declaration feed
                    // and renders the body AS a declaration. This body is a
                    // question, not something to speak over yourself.
                    content.userInfo = ["enforcementPrompt": true]
                } else {
                    content.userInfo = ["category": enforcementCategory ?? decl.category]
                }

                let finalComponents = calendar.dateComponents(
                    [.year, .month, .day, .hour, .minute], from: targetDate)
                let trigger = UNCalendarNotificationTrigger(
                    dateMatching: finalComponents, repeats: false)

                // Stable ID per (day, slot) so re-registering replaces the prior
                // batch in place — without nuking the entire pending list (which
                // would also wipe lifecycle/streak/burst/personal-declaration
                // pushes, all of which we own elsewhere). iOS auto-replaces a
                // pending request when add() is called with the same identifier.
                let request = UNNotificationRequest(
                    identifier: Self.contentBatchID(day: day, slot: idx),
                    content: content,
                    trigger: trigger
                )
                notificationCenter.add(request) { error in
                    if let error = error {
                        print("❌ Failed to schedule notification (day \(day), slot \(idx)): \(error.localizedDescription)")
                    }
                }
            }
        }

        // Record the batch end so the app knows when this batch's last notification fires.
        let refreshDate = calendar.date(byAdding: .day, value: daysAhead - 1, to: now)
        lastScheduledNotificationDate = refreshDate

        // Also record when to start trying to reschedule. Buffer scales with batch length:
        // a 10-day batch reschedules with 4 days of slack, a 6-day batch with 2, a 3-day
        // batch with 1. Keeps short batches from triggering reschedule on every launch.
        let bufferDays = max(1, min(4, daysAhead / 2))
        nextRescheduleDate = calendar.date(byAdding: .day, value: max(0, daysAhead - 1 - bufferDays), to: now)
        callback?()
    }

    /// The earliest date at which the foreground lifecycle handler should re-register
    /// notifications. Set inside `prepareNotifications` based on the current batch length.
    /// Falls back to `.distantPast` when missing so a stale install reschedules immediately.
    var nextRescheduleDate: Date? {
        get {
            UserDefaults.standard.object(forKey: "nextRescheduleDate") as? Date
        }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue, forKey: "nextRescheduleDate")
            } else {
                UserDefaults.standard.removeObject(forKey: "nextRescheduleDate")
            }
        }
    }

    /// True when the app should reschedule the notification batch on the next foreground.
    var shouldRescheduleBatch: Bool {
        guard let threshold = nextRescheduleDate else { return true }
        return Date() >= threshold
    }
    
    /// Submits a BGAppRefreshTask to fire when the notification batch is 4 days
    /// from running out. iOS will wake the app in the background, call
    /// `updateNotificationContent`, which runs `UpdateNotificationsOperation`
    /// → `registerNotifications` → schedules a fresh 10-day batch.
    /// This means users get continuous notifications even without opening the app.
    ///
    /// The actual `BGTaskScheduler.shared.submit(...)` call is routed through
    /// `submitBackgroundTask`, installed by `AppDelegate` on startup. Keeps this
    /// file free of `import BackgroundTasks` so it builds in a Foundation-only
    /// test package.
    private func scheduleBatchRefresh(batchEndsAt endDate: Date) {
        // Aim to refresh when 4 days of notifications remain (buffer for iOS delays)
        let refreshBuffer: TimeInterval = 4 * 24 * 60 * 60
        let refreshDate = endDate.addingTimeInterval(-refreshBuffer)

        // If refresh date is already past (e.g. small batch), fire as soon as possible
        let fireDate = max(refreshDate, Date(timeIntervalSinceNow: 60))

        submitBackgroundTask("com.speaklife.updateNotificationContent", fireDate)
    }
    private func getArrayDates(from dates: [Date], startTimeIndex: Int, endTimeIndex: Int) -> [Date] {
        
        var newArrayDate: [Date] = []
        
        if endTimeIndex <= startTimeIndex {
            let startToEndOfDay = dates.suffix(from: startTimeIndex)
            let endToStart = dates.prefix(through: endTimeIndex)
            newArrayDate.append(contentsOf: startToEndOfDay)
            newArrayDate.append(contentsOf: endToStart)
            return newArrayDate
        }
        
        var tick = 0
        for date in dates {
            if tick >= startTimeIndex && tick <= endTimeIndex  {
                newArrayDate.append(date)
            }
            tick += 1
        }
        return newArrayDate
    }
    
    func getHourMinute(startTime: Int, endTime: Int, count: Int) -> [(hour: Int, minute: Int)] {
        let dates = TimeSlots.getDateTimeSlots()
        let calendar = Calendar.autoupdatingCurrent
        
        let newArrayDates = getArrayDates(from: dates, startTimeIndex: startTime, endTimeIndex: endTime)
        
        var returnTimes: [(hour: Int, minute: Int)] = []
        var tempCount = 0
        
        while tempCount < count && tempCount < newArrayDates.count {
            let hour = calendar.component(.hour, from: newArrayDates[tempCount])
            let minute = calendar.component(.minute, from: newArrayDates[tempCount])
            let newTime = (hour: hour, minute: minute)
            returnTimes.append(newTime)
            tempCount += 1
        }
        
        let stopIndex = tempCount - 1
        
        
        while tempCount < count {
            let hour = calendar.component(.hour, from: newArrayDates[stopIndex])
            let minute = calendar.component(.minute, from: newArrayDates[stopIndex])
            let newTime = (hour: hour, minute: minute)
            returnTimes.append(newTime)
            tempCount += 1
            
        }
        
        return returnTimes
    }
    
    private func createDate(hour: Int, minute: Int) -> Date? {
        // Use the current date as the base
        let currentDate = Date()
        let calendar = Calendar.autoupdatingCurrent

        // Set the specific hour and minute
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: currentDate)
    }
    
    func distributeTimes(startTime: Int, endTime: Int, count: Int) -> [(hour: Int, minute: Int)] {
        let dates = TimeSlots.getDateTimeSlots()
        let calendar = Calendar.autoupdatingCurrent
        let newArrayDates = getArrayDates(from: dates, startTimeIndex: startTime, endTimeIndex: endTime)
        let startTimeHour = calendar.component(.hour, from: newArrayDates[0])
        let startTimeMinute = calendar.component(.minute, from: newArrayDates[0])
        
        let endTimeHour = calendar.component(.hour, from: newArrayDates.last!)
        let endTimeMinute = calendar.component(.minute, from: newArrayDates.last!)
                                                 
        let startTime = createDate(hour: startTimeHour, minute: startTimeMinute)!
        let endTime = createDate(hour: endTimeHour, minute: endTimeMinute)!
        
        
        guard count > 0, startTime < endTime else {
            return [] // Return an empty array if count is zero or if start time is after end time
        }

        var result: [(hour: Int, minute: Int)] = []

        // Calculate total duration in seconds
        let totalSeconds = Int(endTime.timeIntervalSince(startTime))
        
        // Calculate interval in seconds
        let interval = totalSeconds / count

        // Generate times
        for i in 0..<count {
            if let time = Calendar.current.date(byAdding: .second, value: i * interval, to: startTime) {
                let hour = Calendar.current.component(.hour, from: time)
                let minute = Calendar.current.component(.minute, from: time)
                result.append((hour, minute))
            }
        }

        return result
    }
    
    func notificationsPending(completion: @escaping(Bool, Int?) -> Void) {
        notificationCenter.getPendingNotificationRequests { requests in
            if requests.count > 0 {
                completion(true, requests.count)
                return
            } else {
                completion(false, nil)
                return
            }
        }
    }
    
    private func removeNotifications() {
        // Remove ONLY content batch notifications. Previously this called
        // removeAllPendingNotificationRequests() which nuked lifecycle pushes
        // (D1-D30), streak at-risk/milestones, daily burst rotations, lapsed
        // pushes, and the personal declaration reminder on every reschedule —
        // breaking the entire retention system. Now we use stable IDs and
        // remove only ours.
        notificationCenter.removePendingNotificationRequests(
            withIdentifiers: Self.allPossibleContentBatchIDs
        )
    }

    /// Stable ID format for one slot in the content batch. Swapping from UUIDs
    /// to these means iOS de-duplicates on re-add (same ID replaces in place)
    /// and we can clean up only the batch instead of the entire pending list.
    fileprivate static func contentBatchID(day: Int, slot: Int) -> String {
        "content_batch_d\(day)_s\(slot)"
    }

    /// Every ID we could possibly have scheduled. Computed across the worst-case
    /// batch shape (10 days × 30 slots = 300 IDs) so a shrinking batch (e.g.
    /// count grew so daysAhead dropped) properly clears stale slots from prior
    /// runs. Cheap — iOS handles 300 string lookups easily.
    fileprivate static let allPossibleContentBatchIDs: [String] = {
        var ids: [String] = []
        for day in 0..<10 {
            for slot in 0..<30 {
                ids.append(contentBatchID(day: day, slot: slot))
            }
        }
        return ids
    }()
    
    private func verifyNotificationsScheduled() {
        notificationCenter.getPendingNotificationRequests { requests in
            print("\n📊 NOTIFICATION VERIFICATION REPORT")
            print("=====================================")
            print("Total pending: \(requests.count) notifications")
            
            if requests.count == 0 {
                // Warning: 
                print("⚠️ WARNING: No notifications were scheduled!")
            } else {
                print("✅ SUCCESS: Notifications are properly scheduled")
                
                // Check authorization status
                self.notificationCenter.getNotificationSettings { settings in
                    switch settings.authorizationStatus {
                    case .authorized:
                        print("✅ Permissions: Authorized")
                    case .provisional:
                        // Warning: 
                        print("⚠️ Permissions: Provisional (may not show all alerts)")
                    case .denied:
                        print("❌ Permissions: DENIED - User must enable in Settings")
                    case .notDetermined:
                        print("❓ Permissions: Not determined - Need to request")
                    @unknown default:
                        print("❓ Permissions: Unknown status")
                    }
                    
                    print("   Alert: \(settings.alertSetting == .enabled ? "✅" : "❌")")
                    print("   Sound: \(settings.soundSetting == .enabled ? "✅" : "❌")")
                    print("   Badge: \(settings.badgeSetting == .enabled ? "✅" : "❌")")
                }
                
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm"
                formatter.timeZone = TimeZone.autoupdatingCurrent
                
                // Show all scheduled notifications with full date info
                print("\n📅 Scheduled Notifications:")
                for (index, request) in requests.prefix(15).enumerated() {
                    if let trigger = request.trigger as? UNCalendarNotificationTrigger {
                        let components = trigger.dateComponents
                        
                        var dateStr = ""
                        if let year = components.year,
                           let month = components.month,
                           let day = components.day,
                           let hour = components.hour,
                           let minute = components.minute {
                            dateStr = "\(year)-\(String(format: "%02d", month))-\(String(format: "%02d", day)) \(String(format: "%02d:%02d", hour, minute))"
                        } else if let hour = components.hour,
                                  let minute = components.minute {
                            dateStr = "Daily at \(String(format: "%02d:%02d", hour, minute))"
                        }
                        
                        print("\n  \(index + 1). \(dateStr)")
                        print("      Body: \(request.content.body.prefix(50))...")
                        print("      Repeats: \(trigger.repeats)")
                        
                        // Check if notification date is in the past
                        if let nextTriggerDate = trigger.nextTriggerDate() {
                            let timeUntil = nextTriggerDate.timeIntervalSince(Date())
                            if timeUntil < 0 {
                                // Warning: 
                                print("      ⚠️ WARNING: Next trigger is in the PAST!")
                                print("      Was supposed to fire: \(formatter.string(from: nextTriggerDate))")
                            } else {
                                let hours = Int(timeUntil / 3600)
                                let minutes = Int((timeUntil.truncatingRemainder(dividingBy: 3600)) / 60)
                                print("      ⏰ Will fire: \(formatter.string(from: nextTriggerDate)) (in \(hours)h \(minutes)m)")
                            }
                        }
                    }
                }
                
                if requests.count > 15 {
                    print("\n  ... and \(requests.count - 15) more notifications")
                }
                
                print("\n=====================================\n")
            }
        }
    }
    
    // MARK: - Checklist Notifications

    /// Sweeps any leftover notification IDs from earlier app versions so they
    /// can't fire on users who upgraded mid-batch. Called from
    /// registerNotifications() and on .active foreground. Includes the
    /// personalized checklist morning/evening pushes, the "reminders ending"
    /// prompt, and the legacy daily streak reminder — all retired to cut
    /// daily notification volume.
    func scheduleChecklistNotifications() {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [
            "PersonalizedMorningNotification",
            "PersonalizedEveningNotification",
            "FallbackEveningNotification",
            "reschedule_prompt",
            "daily_speak_life_reminder"
        ])
    }

    // MARK: - AI Enhanced Notifications
    
    private func shouldUseAINotifications() -> Bool {
        // For now, return false until we can properly access SubscriptionStore
        // This can be updated when the notification system gets refactored
        return false
    }
    
    private func registerAIEnhancedNotifications(count: Int,
                                               startTime: Int,
                                               endTime: Int,
                                               categories: Set<DeclarationCategory>? = nil,
                                               callback: (() -> Void)? = nil) {
        Task {
            do {
                // Get AI-optimized notification times
                let optimalTimes = await RecommendationEngine.shared.getOptimalNotificationTimes()
                
                // Get AI-recommended contextual content
                let contextualDeclarations = await RecommendationEngine.shared.getContextualDeclarations()
                
                // Use AI-selected content if available, otherwise fall back to categories
                let notifications: [NotificationProcessor.NotificationData]
                if !contextualDeclarations.isEmpty {
                    // Convert AI declarations to notification data
                    notifications = contextualDeclarations.prefix(count).map { declaration in
                        NotificationProcessor.NotificationData(book: declaration.category.rawValue, body: declaration.text, category: declaration.category.rawValue)
                    }
                } else if let categories = categories {
                    notifications = getNotificationData(for: count, categories: categories)
                } else {
                    notifications = getNotificationData(for: count, categories: notificationCategories())
                }
                
                await MainActor.run {
                    // Use AI-optimized timing if available, otherwise use user preferences
                    if !optimalTimes.isEmpty {
                        self.prepareAINotifications(declarations: notifications, optimalTimes: optimalTimes, count: count) {
                            callback?()
                        }
                    } else {
                        // Fall back to regular timing
                        self.prepareNotifications(declarations: notifications, startTime: startTime, endTime: endTime, count: count) {
                            callback?()
                        }
                    }
                }
                
            } catch {
                print("❌ AI notification setup failed, falling back to standard: \(error)")
             //    Fall back to standard notification system
                await MainActor.run {
                    if let categories = categories {
                        let notifications = self.getNotificationData(for: count, categories: categories)
                        self.prepareNotifications(declarations: notifications, startTime: startTime, endTime: endTime, count: count) {
                            callback?()
                        }
                    }
                }
            }
        }
    }
    
    private func prepareAINotifications(declarations: [NotificationProcessor.NotificationData], optimalTimes: [Date], count: Int, callback: @escaping () -> Void) {
        // Convert optimal times to hour-based scheduling similar to existing system
        let timeHours = optimalTimes.map { Calendar.current.component(.hour, from: $0) }
        let startTime = timeHours.min() ?? 9
        let endTime = timeHours.max() ?? 21
        
        // Use existing notification preparation with AI-optimized timing
        prepareNotifications(declarations: declarations, startTime: startTime, endTime: endTime, count: count, callback: callback)
        
    }
}


final class UpdateNotificationsOperation: Operation {
    
    private let appState: AppState
    
    init(appState: AppState) {
        self.appState = appState
    }
    
    override func start() {
        let categories = appState.selectedNotificationCategories.components(separatedBy: ",").compactMap({ DeclarationCategory($0) })
        let setCategories = Set(categories)
        // Respect the user's saved selection exactly — no implicit widening.
        let selectedCategories = setCategories.isEmpty ? nil : setCategories
        
        NotificationManager.shared.notificationsPending { [weak self] pending, count in
            
            guard let self = self else { return }
            
            if self.appState.notificationEnabled {
                self.appState.lastNotificationSetDate = Date()
                NotificationManager.shared.registerNotifications(count: self.appState.notificationCount,
                                                                 startTime: self.appState.startTimeIndex,
                                                                 endTime: self.appState.endTimeIndex,
                                                                 categories: selectedCategories)
                self.completionBlock?()
                
            }
            
        }
    }
}
