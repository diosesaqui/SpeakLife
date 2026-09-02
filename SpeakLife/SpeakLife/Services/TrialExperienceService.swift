//
//  TrialExperienceService.swift
//  SpeakLife
//
//  Manages the trial closing sequence, length-aware (3-day, 7-day, ... SKUs).
//  Day 1: Burst fires immediately after onboarding (triggered via HomeView)
//  Day n-1: Personalized category-matched "ends tomorrow" push + in-app stats card
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

    var declarationCountDuringTrial: Int {
        UserDefaults.standard.integer(forKey: kTrialDeclarationCount)
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

        scheduleTrialPushes(from: now, trialLengthDays: length)
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

    /// Call on every swipe_affirmation or declaration spoken during trial
    func onDeclarationSpoken() {
        guard isTrialActive else { return }
        let count = declarationCountDuringTrial + 1
        UserDefaults.standard.set(count, forKey: kTrialDeclarationCount)
    }

    /// Call when user converts (premium_succeeded)
    func onTrialConverted() {
        UserDefaults.standard.set(false, forKey: kTrialActive)
        center.removePendingNotificationRequests(withIdentifiers: ["trial_d2", "trial_d3"])
        AnalyticsService.shared.track("trial_experience_converted", parameters: [
            "declarations_during_trial": declarationCountDuringTrial,
            "trial_day": trialDay
        ])
    }

    /// Clear any pending D2/D3 trial-ending pushes without flipping any state.
    /// Used as a defensive cleanup after a non-trial purchase by a user who
    /// has stale pushes from the pre-fix isTrialProduct/willStartTrial bug.
    func clearPendingTrialPushes() {
        center.removePendingNotificationRequests(withIdentifiers: ["trial_d2", "trial_d3"])
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
        guard isTrialActive, let start = trialStartDate else { return }
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
            if trialLengthDays >= 2 {
                self?.scheduleDay2Push(from: startDate, trialLengthDays: trialLengthDays)
            }
            self?.scheduleDay3Push(from: startDate, trialLengthDays: trialLengthDays)
        }
    }

    /// "Ends tomorrow" reminder: day n-1 of an n-day trial, 9:00am local.
    /// Day 1 is the purchase day, so day n-1 = startDate + (n-2) days. For the
    /// historical 3-day trial this stays the Day 2 / +1 day / 9am push.
    private func scheduleDay2Push(from startDate: Date, trialLengthDays: Int) {
        let category = UserPreferencesTracker.shared.primaryCategory
        let (title, body) = day2Copy(for: category, onDay: trialLengthDays - 1)

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = ["lifecycle_id": "trial_d2"]

        guard let fireDate = Calendar.current.date(byAdding: .day, value: trialLengthDays - 2, to: startDate) else { return }
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
    /// What replaces it is the evidence the user actually generated this week,
    /// which `day3Copy` was already doing one day later. Nothing here claims an
    /// outcome and nothing borrows someone else's clock.
    ///
    /// The zero-declaration branch matters as much as the rest: a user who has
    /// spoken nothing is both the likeliest to cancel and the likeliest to
    /// notice being congratulated for a week they did not have. They get an
    /// invitation instead of a receipt.
    private func day2Copy(for category: UserPreferencesTracker.CategoryType, onDay day: Int) -> (String, String) {
        let daysText = day == 1 ? "a day" : "\(day) days"
        let count = declarationCountDuringTrial

        guard count > 0 else {
            let (title, opening) = day2EmptyCopy(for: category)
            return (title, "\(opening) Your trial ends tomorrow, and one declaration is all today asks.")
        }

        let spoken = "You've spoken \(count) \(count == 1 ? "declaration" : "declarations") in \(daysText). "
        switch category {
        case .anxiety:
            return (
                "Day \(day) of your free trial ✨",
                "\(spoken)That's \(daysText) of answering your mind with God's Word instead of arguing with it. Your trial ends tomorrow."
            )
        case .fear:
            return (
                "Day \(day) — keep going 💪",
                "\(spoken)That's \(daysText) of speaking to the thing instead of listening to it. Your trial ends tomorrow."
            )
        case .marriage:
            return (
                "Day \(day) of your trial ❤️",
                "\(spoken)That's \(daysText) of speaking peace over your home. Your trial ends tomorrow."
            )
        case .health:
            return (
                "Day \(day) — speaking over your body 🙏",
                "\(spoken)That's \(daysText) of God's Word spoken over your body. Your trial ends tomorrow."
            )
        case .faith:
            return (
                "Day \(day) of building unshakeable faith ⚡",
                "\(spoken)Faith is built declaration by declaration, and you've been building for \(daysText). Your trial ends tomorrow."
            )
        case .confidence:
            return (
                "Day \(day) — you're becoming someone new 👑",
                "\(spoken)That's \(daysText) of speaking who God says you are. Your trial ends tomorrow."
            )
        case .hope:
            return (
                "Day \(day) — hope is being restored 🌅",
                "\(spoken)That's \(daysText) of God's Word over what's ahead of you. Your trial ends tomorrow."
            )
        default:
            return (
                "Day \(day) of your free trial 🔥",
                "\(spoken)That's \(daysText) of God's Word out loud over your own life. Your trial ends tomorrow."
            )
        }
    }

    /// Opening line for a trial with no declarations spoken yet. Names the thing
    /// they came in for and asks for one, rather than reporting a week back to
    /// them that did not happen.
    private func day2EmptyCopy(for category: UserPreferencesTracker.CategoryType) -> (String, String) {
        switch category {
        case .anxiety:
            return ("Speak one over your mind today ✨", "Your mind has been carrying this on its own.")
        case .fear:
            return ("Speak to it today 💪", "You came here to stop listening to it.")
        case .marriage:
            return ("Speak peace over your home ❤️", "You came here for your marriage.")
        case .health:
            return ("Speak over your body today 🙏", "You came here for your body.")
        case .faith:
            return ("One declaration today ⚡", "Faith is built declaration by declaration.")
        case .confidence:
            return ("Speak who God says you are 👑", "You came here to hear who you actually are.")
        case .hope:
            return ("Speak over what's ahead 🌅", "You came here for what's ahead of you.")
        default:
            return ("One declaration today 🔥", "You came here to speak God's Word over your life.")
        }
    }

    private func day3Copy(for category: UserPreferencesTracker.CategoryType) -> (String, String) {
        let count = declarationCountDuringTrial
        let countText = count > 0 ? "You've already spoken \(count) declarations. " : ""
        switch category {
        case .anxiety:
            return (
                "Your free trial ends today 🙏",
                "\(countText)Your mind has started shifting from worry to worship. That doesn't stop if you don't let it. Open SpeakLife to continue."
            )
        case .fear:
            return (
                "Trial ending today — don't lose this 💙",
                "\(countText)Fear shrinks when you speak truth over it daily. You've started that process. Open SpeakLife and keep the momentum."
            )
        case .marriage:
            return (
                "Your trial ends today ❤️",
                "\(countText)You've started speaking life over your relationship. That matters. Don't let it stop today. Open SpeakLife to continue."
            )
        default:
            return (
                "Last day of your free trial ⚡",
                "\(countText)You're becoming someone who speaks God's truth over their life daily. Don't quit on that person. Open SpeakLife to continue your journey."
            )
        }
    }
}
