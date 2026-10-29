//
//  TrialExperienceService.swift
//  SpeakLife
//
//  Manages the trial closing sequence, length-aware (3-day, 7-day, ... SKUs).
//  Day 1: Burst fires immediately after onboarding (triggered via HomeView)
//  Day 5 of 7 (day n-1 under 5 days): personalized "ends in 2 days" push + in-app stats card
//  Day n (last day): Loss-aversion push + ending banner with inline convert CTA
//

import Foundation
import StoreKit
import UserNotifications

final class TrialExperienceService: ObservableObject {
    static let shared = TrialExperienceService()
    private init() {}

    private let center = UNUserNotificationCenter.current()

    // Keys
    private let kTrialStartDate         = "trial_experience_start_date"
    private let kTrialDeclarationCount  = "trial_declaration_count"
    private let kTrialDay               = "trial_current_day"
    private let kTrialActive            = "trial_experience_active"
    private let kTrialLengthDays        = "trial_experience_length_days"
    private let kTrialCancelled         = "trial_experience_cancelled"

    // MARK: - Public State

    var isTrialActive: Bool {
        UserDefaults.standard.bool(forKey: kTrialActive)
    }

    var trialDay: Int {
        guard let start = trialStartDate else { return 0 }
        let days = Calendar.current.dateComponents([.day], from: start, to: Date()).day ?? 0
        return min(days + 1, trialLengthDays)
    }

    /// Length of the active trial in days, persisted at trial start from the
    /// purchased product's intro offer. Falls back to 3 (the historical
    /// hardcoded assumption) for trials started before length was tracked.
    var trialLengthDays: Int {
        let stored = UserDefaults.standard.integer(forKey: kTrialLengthDays)
        return stored > 0 ? stored : 3
    }

    /// Declarations spoken since the trial began.
    ///
    /// **Do not use this in push copy.** Notification bodies are baked into a
    /// `UNMutableNotificationContent` at SCHEDULE time, and every scheduling
    /// path runs before the user can have spoken anything: `onTrialStarted`
    /// zeroes this counter three lines before it calls `scheduleTrialPushes`,
    /// and `reschedulePendingTrialPushesIfNeeded` is only ever called from the
    /// onboarding notification-permission callbacks, still ahead of the feed.
    /// `onDeclarationSpoken` is called from the declaration feed, which the user
    /// reaches afterwards. So this reads 0 in any copy builder, always.
    ///
    /// It is still valid at `onTrialConverted`, which runs long after, and that
    /// is the one place it is read for real.
    ///
    /// Making it usable in a push needs render-at-delivery (a notification
    /// service extension) or a re-schedule from a foreground hook late in the
    /// trial. Neither exists today.
    var declarationCountDuringTrial: Int {
        UserDefaults.standard.integer(forKey: kTrialDeclarationCount)
    }

    /// Now is before the trial's end date.
    private var isWithinTrialWindow: Bool {
        guard let start = trialStartDate,
              let end = Calendar.current.date(byAdding: .day, value: trialLengthDays, to: start) else { return false }
        return Date() < end
    }

    private var trialStartDate: Date? {
        UserDefaults.standard.object(forKey: kTrialStartDate) as? Date
    }

    // MARK: - Entry Points

    /// Call when trial begins (after onboarding completes).
    /// - Parameter lengthInDays: the purchased product's intro-offer trial
    ///   length (e.g. 3 or 7) — see `introTrialDays(for:)`. nil or 0 marks the
    ///   trial active but schedules no trial-ending pushes.
    func onTrialStarted(lengthInDays: Int? = 3) {
        guard !isTrialActive else { return }
        let now = Date()
        let length = max(lengthInDays ?? 0, 0)
        UserDefaults.standard.set(now, forKey: kTrialStartDate)
        UserDefaults.standard.set(true, forKey: kTrialActive)
        UserDefaults.standard.set(0, forKey: kTrialDeclarationCount)
        UserDefaults.standard.set(length, forKey: kTrialLengthDays)
        UserDefaults.standard.set(false, forKey: kTrialCancelled)

        assignHabitGroup(trialLengthDays: length)
        scheduleTrialPushes(from: now, trialLengthDays: length)
        // Start every trial at "not used", so a trial that never touches a
        // feature reads false rather than missing, and the two groups can be
        // compared on trial-to-paid.
        for (_, property) in Self.trackedTrialFeatures {
            UserDefaults.standard.removeObject(forKey: property)
            AnalyticsService.shared.setUserProperty(property, value: false)
        }
        AnalyticsService.shared.track("trial_experience_started", parameters: [
            "trial_length_days": length
        ])
    }

    /// Days in the introductory free-trial offer for the given StoreKit
    /// product. nil when the product has no free-trial intro offer (discounted
    /// pay-as-you-go/pay-up-front intro offers are not trials and must not get
    /// trial-ending pushes). Mirrors the paywall's intro-offer reading so the
    /// reminders always match the trial length the user was shown.
    static func introTrialDays(for product: StoreKit.Product) -> Int? {
        guard let offer = product.subscription?.introductoryOffer,
              offer.paymentMode == .freeTrial else { return nil }
        switch offer.period.unit {
        case .day:   return offer.period.value
        case .week:  return offer.period.value * 7
        case .month: return offer.period.value * 30
        case .year:  return offer.period.value * 365
        @unknown default: return nil
        }
    }

    /// Features whose use during the trial is recorded per user, and the
    /// PostHog person property each one sets.
    static let trackedTrialFeatures: [String: String] = [
        "audio": "used_audio_in_trial",
        "bible_chat": "used_chat_in_trial"
    ]

    /// Records the first use of a feature inside an active trial: its person
    /// property (`used_audio_in_trial`, `used_chat_in_trial`) flips to true and
    /// `trial_feature_used` fires once, with the trial day. The trial-week push
    /// introducing that feature is cancelled: she found it already. Joined to RevenueCat's conversion, this
    /// is how the "users who touch audio / Bible chat convert more" claim gets
    /// confirmed. No-op outside a trial and after the first use.
    func recordTrialFeatureUse(_ feature: String) {
        // `isTrialActive` is only cleared by an in-app purchase, so a trial
        // that lapsed or renewed on its own still reads active. The window
        // check keeps a first listen three months later out of the numbers.
        guard isTrialActive, isWithinTrialWindow,
              let key = Self.trackedTrialFeatures[feature] else { return }
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        StormTrialPushes.cancel(forFeature: feature)
        UserDefaults.standard.set(true, forKey: key)
        AnalyticsService.shared.setUserProperty(key, value: true)
        AnalyticsService.shared.track("trial_feature_used", parameters: [
            "feature": feature,
            "trial_day": trialDay
        ])
    }

    /// Call on every swipe_affirmation or declaration spoken during trial
    func onDeclarationSpoken() {
        guard isTrialActive else { return }
        let count = declarationCountDuringTrial + 1
        UserDefaults.standard.set(count, forKey: kTrialDeclarationCount)
    }

    /// Call when user converts (premium_succeeded)
    func onTrialConverted() {
        UserDefaults.standard.set(false, forKey: kTrialActive)
        center.removePendingNotificationRequests(withIdentifiers: ["trial_d2", "trial_d3", StormTrialReminder.identifier, StormTrialPushes.bibleChatID] + Self.nudgeIDs)
        AnalyticsService.shared.track("trial_experience_converted", parameters: [
            "declarations_during_trial": declarationCountDuringTrial,
            "trial_day": trialDay
        ])
    }

    /// The trial's auto-renew state, from RevenueCat on every foreground and
    /// customer-info update (`QualifiedTrialTracker.evaluate`). A trial the
    /// user cancelled in Settings gets no "your trial is ending" pushes: they
    /// already decided, and the reminder exists for people who have not.
    /// Turning auto-renew back on restores them. A local notification cannot
    /// be withdrawn from a phone whose app is never opened again, so someone
    /// who cancels and never comes back may still get one.
    func onTrialRenewalStatus(willRenew: Bool) {
        guard isTrialActive else { return }
        let wasCancelled = UserDefaults.standard.bool(forKey: kTrialCancelled)
        if !willRenew && !wasCancelled {
            UserDefaults.standard.set(true, forKey: kTrialCancelled)
            // Only the "trial is ending" warnings. The habit nudges stay: the
            // trial still runs to its last day, and using it is the best case
            // for turning auto-renew back on.
            center.removePendingNotificationRequests(withIdentifiers: ["trial_d2", "trial_d3", StormTrialReminder.identifier])
            AnalyticsService.shared.track("trial_reminders_cancelled", parameters: ["trial_day": trialDay])
        } else if willRenew && wasCancelled {
            UserDefaults.standard.set(false, forKey: kTrialCancelled)
            reschedulePendingTrialPushesIfNeeded()
        }
    }

    /// Clear any pending D2/D3 trial-ending pushes without flipping any state.
    /// Used as a defensive cleanup after a non-trial purchase by a user who
    /// has stale pushes from the pre-fix isTrialProduct/willStartTrial bug.
    func clearPendingTrialPushes() {
        center.removePendingNotificationRequests(withIdentifiers: ["trial_d2", "trial_d3", StormTrialReminder.identifier] + Self.nudgeIDs)
    }

    /// Re-schedule the D2/D3 trial-ending pushes from the persisted trial
    /// state. Flows should call this right after the user grants notification
    /// permission: the paywall runs BEFORE the onboarding notification ask, so
    /// the original scheduling may have happened while authorization was still
    /// .notDetermined and relied on undocumented OS queuing. Safe to call any
    /// time — the trial_d2/trial_d3 identifiers are constant, so re-adding
    /// replaces the pending requests (no duplicates), and the scheduling
    /// path's past-date guards keep late re-scheduling from firing stale
    /// pushes. No-op when no trial is active or no start date was stored.
    func reschedulePendingTrialPushesIfNeeded() {
        guard isTrialActive, !UserDefaults.standard.bool(forKey: kTrialCancelled),
              let start = trialStartDate else { return }
        scheduleTrialPushes(from: start, trialLengthDays: trialLengthDays)
    }

    // MARK: - Push Notifications

    private func scheduleTrialPushes(from startDate: Date, trialLengthDays: Int) {
        // 0/unknown length: nothing to schedule. A 1-day trial skips the
        // "ends tomorrow" push and gets only the final-24h reminder.
        guard trialLengthDays >= 1 else { return }
        center.getNotificationSettings { [weak self] settings in
            // Schedule while permission is still .notDetermined too: the paywall
            // (and trial timeline) runs BEFORE the onboarding notification ask,
            // and pending requests added pre-authorization deliver normally once
            // the user grants permission. Only a hard denial makes them pointless.
            guard settings.authorizationStatus != .denied else { return }
            // A storm-paywall purchase has its own "ends in 2 days" reminder
            // (the one the user switched on, or off). Sending this one too put
            // two different trial warnings on the same morning.
            if trialLengthDays >= 2 && !StormTrialReminder.ownsTrialWarning {
                self?.scheduleDay2Push(from: startDate, trialLengthDays: trialLengthDays)
            }
            self?.scheduleDay3Push(from: startDate, trialLengthDays: trialLengthDays)
            self?.scheduleHabitPushes(from: startDate, trialLengthDays: trialLengthDays,
                                      ownedByStormArm: StormTrialReminder.ownsTrialWarning)
        }
    }

    /// Days after the purchase day that the trial-ending reminder fires (9am).
    /// Day 1 is the purchase day. From a 5-day trial up it lands two days
    /// before the last day (day 5 of 7), so there is still time to decide;
    /// shorter trials keep the day n-1 "ends tomorrow" slot. The paywall's
    /// trial timelines read this too, so the date they show is the date sent.
    static func reminderDayOffset(trialLengthDays n: Int) -> Int {
        n >= 5 ? n - 3 : n - 2
    }

    /// Trial-ending reminder, 9:00am local on the day `reminderDayOffset`
    /// picks: day 5 of a 7-day trial, day 2 of a 3-day trial.
    private func scheduleDay2Push(from startDate: Date, trialLengthDays: Int) {
        let category = UserPreferencesTracker.shared.primaryCategory
        let offset = Self.reminderDayOffset(trialLengthDays: trialLengthDays)
        let daysLeft = trialLengthDays - (offset + 1)
        let (title, rawBody) = day2Copy(for: category, onDay: offset + 1)
        let body = daysLeft > 1
            ? rawBody.replacingOccurrences(of: "Your trial ends tomorrow.", with: "Your trial ends in \(daysLeft) days.")
            : rawBody

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = ["lifecycle_id": "trial_d2"]

        guard let fireDate = Calendar.current.date(byAdding: .day, value: offset, to: startDate) else { return }
        let adjusted = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: fireDate) ?? fireDate
        // A 2-day trial purchased after 9am puts this slot in the past — skip
        // it (the trigger would never fire); the last-day push still covers.
        guard adjusted > Date() else { return }
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: adjusted)

        center.add(UNNotificationRequest(
            identifier: "trial_d2",
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        ))
    }

    /// "Last day" reminder: day n of an n-day trial, 8:30am local. The trial
    /// converts at startDate + n days (same clock time as the purchase), so
    /// the 8:30am slot on day n (= startDate + (n-1) days) always lands before
    /// conversion for n >= 2. If the fixed slot misses the window (1-day
    /// trials), fall back to 12 hours before conversion instead.
    private func scheduleDay3Push(from startDate: Date, trialLengthDays: Int) {
        let category = UserPreferencesTracker.shared.primaryCategory
        let (title, body) = day3Copy(for: category)

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = ["lifecycle_id": "trial_d3"]

        let calendar = Calendar.current
        guard let conversionDate = calendar.date(byAdding: .day, value: trialLengthDays, to: startDate),
              let lastDay = calendar.date(byAdding: .day, value: trialLengthDays - 1, to: startDate) else { return }
        var fireDate = calendar.date(bySettingHour: 8, minute: 30, second: 0, of: lastDay) ?? lastDay
        if fireDate <= Date() || fireDate >= conversionDate {
            fireDate = conversionDate.addingTimeInterval(-12 * 60 * 60)
        }
        // Invariant: fire within the trial, strictly before conversion.
        guard fireDate > Date(), fireDate < conversionDate else { return }
        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)

        center.add(UNNotificationRequest(
            identifier: "trial_d3",
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        ))
    }

    // MARK: - Personalized Copy

    /// The push that lands the day before the card is charged.
    ///
    /// Every branch here used to close with a testimonial whose timeline ran
    /// longer than the trial: 14 days for anxiety, one month for fear, 60 days
    /// for marriage, 21 for confidence, 30 for faith and the default. Sent on
    /// day 6 of a 7-day trial, that told a user the result arrives somewhere
    /// between a week and seven weeks AFTER their trial ends, at the exact
    /// moment they were deciding whether to pay for it. It argued the case for
    /// cancelling in the product's own voice.
    ///
    /// What replaces it names what they came for and the decision in front of
    /// them, and claims nothing about a result. **It deliberately does not
    /// mention how much they have spoken** — see `declarationCountDuringTrial`
    /// for why that number is unavailable here.
    private func day2Copy(for category: UserPreferencesTracker.CategoryType, onDay day: Int) -> (String, String) {
        switch category {
        case .anxiety:
            return (
                "Day \(day) — speak over your mind ✨",
                "Your trial ends tomorrow. Your mind does not have to carry this on its own, and God's Word said so first."
            )
        case .fear:
            return (
                "Day \(day) — speak to it 💪",
                "Your trial ends tomorrow. You came here to speak to the thing instead of listening to it. Today still counts."
            )
        case .marriage:
            return (
                "Day \(day) — speak peace over your home ❤️",
                "Your trial ends tomorrow. Speak God's peace over your marriage while today is still in front of you."
            )
        case .health:
            return (
                "Day \(day) — speak over your body 🙏",
                "Your trial ends tomorrow. Speak God's Word over your body today, out loud, the way Jesus did."
            )
        case .faith:
            return (
                "Day \(day) — faith comes by hearing ⚡",
                "Your trial ends tomorrow. Faith is built declaration by declaration, and there is still one to speak today."
            )
        case .confidence:
            return (
                "Day \(day) — who God says you are 👑",
                "Your trial ends tomorrow. Speak who God already says you are before you decide anything else."
            )
        case .hope:
            return (
                "Day \(day) — speak over what's ahead 🌅",
                "Your trial ends tomorrow. Speak God's Word over what is coming while today is still yours."
            )
        default:
            return (
                "Day \(day) — one declaration today 🔥",
                "Your trial ends tomorrow. One declaration, out loud, over your own life. That is the whole practice."
            )
        }
    }

    /// Last-day push. Like `day2Copy`, it cannot report a declaration count —
    /// this function used to build a `countText` prefix that has rendered as the
    /// empty string on every delivery since it was written, for the reason
    /// documented on `declarationCountDuringTrial`. Removed rather than left in
    /// place looking like a working feature.
    private func day3Copy(for category: UserPreferencesTracker.CategoryType) -> (String, String) {
        switch category {
        case .anxiety:
            return (
                "Your free trial ends today 🙏",
                "Your mind has started shifting from worry to worship. That doesn't stop if you don't let it. Open SpeakLife to continue."
            )
        case .fear:
            return (
                "Trial ending today — don't lose this 💙",
                "Fear shrinks when you speak truth over it daily. You've started that process. Open SpeakLife and keep the momentum."
            )
        case .marriage:
            return (
                "Your trial ends today ❤️",
                "You've started speaking life over your relationship. That matters. Don't let it stop today. Open SpeakLife to continue."
            )
        default:
            return (
                "Last day of your free trial ⚡",
                "You're becoming someone who speaks God's truth over their life daily. Don't quit on that person. Open SpeakLife to continue your journey."
            )
        }
    }
}

// MARK: - Trial-week habit (all onboarding arms, 10% holdout)
//
// Trial-week app days predict paying more than anything else we track
// (trials since Sep 2026): 5-7 days converted 68%, 3-4 days 48%, 1-2 days
// 19%, and 1-2 days is the biggest group (54 of 140). Converters also used
// audio (79-84% vs 39%). So the trial week aims at three app days:
//
// - the storm arm's first-night audio and Day-2 Ask the Bible pushes, for
//   every arm (the storm arm keeps its own, storm-worded ones);
// - "haven't opened today" nudges at 7pm on days 2-4, each cleared the
//   moment the app opens that day, so engaged trialists never see them;
// - a progress card on Today (TrialProgressCard).
//
// Controlled test: a stable 10% of installs (Remote Config
// `trialHabitHoldoutPct`) get today's trial week instead. The person
// property `trial_habit_group` marks the side, so trial-to-paid compares
// treatment against holdout. Remote Config `trialHabit` (unset = on)
// switches the whole layer off.
extension TrialExperienceService {

    static let habitEnabledKey = "trial_habit_enabled"
    static let habitHoldoutKey = "trial_habit_holdout_pct"
    private static let habitBucketKey = "trial_habit_bucket"
    private static let habitGroupKey = "trial_habit_group"
    private static let activeDaysKey = "trial_habit_active_days"
    private static let stoppedKey = "trial_habit_stopped"
    /// The layer needs room for the days 2-4 nudges and a three-day goal.
    private static let minimumTrialDays = 5
    static let nudgeIDs = ["trial_nudge_d2", "trial_nudge_d3", "trial_nudge_d4"]

    /// Remote Config side, persisted so trial start (in onboarding, often
    /// before config lands on a fresh install) reads the last known value.
    static func updateHabitConfig(enabled: Bool, holdoutPercent: Int) {
        let defaults = UserDefaults.standard
        defaults.set(enabled, forKey: habitEnabledKey)
        defaults.set(min(max(holdoutPercent, 0), 100), forKey: habitHoldoutKey)
    }

    /// "treatment" or "holdout" for the current trial, or nil when the layer
    /// is off or no trial has started.
    var habitGroup: String? {
        UserDefaults.standard.string(forKey: Self.habitGroupKey)
    }

    var isInHabitTreatment: Bool { habitGroup == "treatment" }

    /// Trial still running, in the treatment group: the progress card shows.
    var showsTrialProgress: Bool {
        isInHabitTreatment && isTrialActive && !habitStopped && Date() < trialEndDate
    }

    /// Calendar day of the trial, 1 on the day it started. The nudges are
    /// scheduled on calendar days, so clearing and the card must count the
    /// same way; `trialDay` counts 24-hour periods and lags after a late
    /// start.
    var trialCalendarDay: Int {
        guard let start = UserDefaults.standard.object(forKey: "trial_experience_start_date") as? Date else { return 0 }
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: start),
                                           to: calendar.startOfDay(for: Date())).day ?? 0
        return min(max(days + 1, 1), trialLengthDays)
    }

    /// Set when the trialist turns off auto-renew: no more nudges or card.
    private var habitStopped: Bool {
        UserDefaults.standard.bool(forKey: Self.stoppedKey)
    }

    /// Distinct calendar days the app was opened since the trial began.
    var trialActiveDays: Int {
        (UserDefaults.standard.stringArray(forKey: Self.activeDaysKey) ?? []).count
    }

    private var trialEndDate: Date {
        guard let start = UserDefaults.standard.object(forKey: "trial_experience_start_date") as? Date else {
            return .distantPast
        }
        return Calendar.current.date(byAdding: .day, value: trialLengthDays, to: start) ?? .distantPast
    }

    /// Draws the trial's group once, at trial start. Unset config reads on
    /// with a 10% holdout.
    func assignHabitGroup(trialLengthDays: Int) {
        let defaults = UserDefaults.standard
        // The trial starts inside the app, after this launch's foreground
        // hook has already run, so day 1 is counted here.
        defaults.set([Self.dayStamp(Date())], forKey: Self.activeDaysKey)
        defaults.removeObject(forKey: Self.stoppedKey)
        let enabled = defaults.object(forKey: Self.habitEnabledKey) as? Bool ?? true
        // Off, or a trial too short to treat: not in the test either way, and
        // the person property says so rather than keeping an earlier trial's.
        guard enabled, trialLengthDays >= Self.minimumTrialDays else {
            defaults.removeObject(forKey: Self.habitGroupKey)
            AnalyticsService.shared.setUserProperty("trial_habit_group", value: "not_eligible")
            return
        }
        let holdoutPct = defaults.object(forKey: Self.habitHoldoutKey) as? Int ?? 10
        let bucket: Int
        if let stored = defaults.object(forKey: Self.habitBucketKey) as? Int {
            bucket = stored
        } else {
            bucket = Int.random(in: 0..<100)
            defaults.set(bucket, forKey: Self.habitBucketKey)
        }
        let group = bucket < holdoutPct ? "holdout" : "treatment"
        defaults.set(group, forKey: Self.habitGroupKey)
        AnalyticsService.shared.setUserProperty("trial_habit_group", value: group)
        AnalyticsService.shared.track("trial_habit_assigned", parameters: [
            "group": group,
            "holdout_pct": holdoutPct
        ])
    }

    /// The trialist turned off auto-renew: stop nudging and hide the card.
    /// They have decided; the readout should not count them as nudged.
    func onTrialAutoRenewOff() {
        guard isTrialActive, !habitStopped, Date() < trialEndDate else { return }
        UserDefaults.standard.set(true, forKey: Self.stoppedKey)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: Self.nudgeIDs)
        AnalyticsService.shared.track("trial_habit_stopped", parameters: [
            "trial_day": trialCalendarDay,
            "active_days": trialActiveDays
        ])
    }

    /// Call on every foreground. Counts today as a trial day and clears
    /// today's "haven't opened" nudge, since they just did.
    func onAppOpenDuringTrial() {
        guard isTrialActive, Date() < trialEndDate else { return }
        let defaults = UserDefaults.standard
        let today = Self.dayStamp(Date())
        var days = defaults.stringArray(forKey: Self.activeDaysKey) ?? []
        if !days.contains(today) {
            days.append(today)
            defaults.set(days, forKey: Self.activeDaysKey)
        }
        let day = trialCalendarDay
        if (2...4).contains(day) {
            UNUserNotificationCenter.current().removePendingNotificationRequests(
                withIdentifiers: ["trial_nudge_d\(day)"])
        }
    }

    /// The treatment group's pushes. Called from the trial-push scheduler,
    /// which runs at trial start and again once notification permission is
    /// granted (onboarding asks after the paywall).
    func scheduleHabitPushes(from start: Date, trialLengthDays: Int, ownedByStormArm: Bool) {
        guard isInHabitTreatment, !habitStopped, trialLengthDays >= Self.minimumTrialDays else { return }
        let category = UserDefaults.standard.string(forKey: "selectedCategory")

        if !ownedByStormArm {
            // Night 1 audio replaces that night's bedtime push (see
            // scheduleTrialFirstNightAudio) rather than adding a second. A
            // trial started after 8:30pm gets it the next night: about a
            // quarter of trials start 9pm-midnight.
            LifecycleNotificationService.shared.scheduleTrialFirstNightAudio(
                category: category ?? "",
                title: "For tonight's quiet 🎧",
                body: "Your trial includes Scripture audio for sleep. Press play and let His Word be the last thing you hear.",
                rollToTomorrow: true
            )
            if UserDefaults.standard.bool(forKey: "enableAIFeatures") {
                scheduleTrialPush(
                    id: StormTrialPushes.bibleChatID, dayOffset: 1, hour: 12, minute: 0, start: start,
                    title: "Ask the Bible anything 💬",
                    body: "Bring the question you'd never ask out loud. It answers from Scripture.",
                    userInfo: ["action": StormTrialPushes.bibleChatID, "deepLink": "bibleChat"])
            }
        }

        // Days 2-4 at 7pm, each cleared by an open that day. A day already
        // counted active is skipped, so a re-schedule later in the day (the
        // permission grant path) cannot re-arm a nudge the open cleared.
        let calendar = Calendar.current
        let activeDays = Set(UserDefaults.standard.stringArray(forKey: Self.activeDaysKey) ?? [])
        let nudges: [(day: Int, title: String, body: String)] = [
            (2, "Day 2 of your week ☀️",
             "Your declarations for today are ready. Three minutes, out loud."),
            (3, "Day 3 is where it starts to stick 🔥",
             "Show up today and you're building a habit. Today's declarations are ready."),
            (4, "Halfway through your week",
             "Speak today's declarations over whatever is in front of you."),
        ]
        for nudge in nudges {
            if let date = calendar.date(byAdding: .day, value: nudge.day - 1, to: start),
               activeDays.contains(Self.dayStamp(date)) { continue }
            scheduleTrialPush(
                id: "trial_nudge_d\(nudge.day)", dayOffset: nudge.day - 1, hour: 19, minute: 0, start: start,
                title: nudge.title, body: nudge.body,
                userInfo: ["action": "daily_declaration_burst",
                           "notification_type": "trial_nudge_d\(nudge.day)"])
        }
    }

    private func scheduleTrialPush(id: String, dayOffset: Int, hour: Int, minute: Int, start: Date,
                                   title: String, body: String, userInfo: [String: Any]) {
        let calendar = Calendar.current
        guard let day = calendar.date(byAdding: .day, value: dayOffset, to: start),
              let fire = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day),
              fire > Date() else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = userInfo
        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
        UNUserNotificationCenter.current().add(UNNotificationRequest(
            identifier: id, content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static func dayStamp(_ date: Date) -> String {
        dayFormatter.string(from: date)
    }
}
