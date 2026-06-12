//
//  TrialExperienceService.swift
//  SpeakLife
//
//  Manages the 3-day trial closing sequence.
//  Day 1: Burst fires immediately after onboarding (triggered via HomeView)
//  Day 2: Personalized category-matched push + in-app stats card
//  Day 3: Loss-aversion push + ending banner with inline convert CTA
//

import Foundation
import UserNotifications
import FirebaseAnalytics

final class TrialExperienceService: ObservableObject {
    static let shared = TrialExperienceService()
    private init() {}

    private let center = UNUserNotificationCenter.current()

    // Keys
    private let kTrialStartDate         = "trial_experience_start_date"
    private let kTrialDeclarationCount  = "trial_declaration_count"
    private let kTrialDay               = "trial_current_day"
    private let kTrialActive            = "trial_experience_active"

    // MARK: - Public State

    var isTrialActive: Bool {
        UserDefaults.standard.bool(forKey: kTrialActive)
    }

    var trialDay: Int {
        guard let start = trialStartDate else { return 0 }
        let days = Calendar.current.dateComponents([.day], from: start, to: Date()).day ?? 0
        return min(days + 1, 3)
    }

    var declarationCountDuringTrial: Int {
        UserDefaults.standard.integer(forKey: kTrialDeclarationCount)
    }

    private var trialStartDate: Date? {
        UserDefaults.standard.object(forKey: kTrialStartDate) as? Date
    }

    // MARK: - Entry Points

    /// Call when trial begins (after onboarding completes)
    func onTrialStarted() {
        guard !isTrialActive else { return }
        let now = Date()
        UserDefaults.standard.set(now, forKey: kTrialStartDate)
        UserDefaults.standard.set(true, forKey: kTrialActive)
        UserDefaults.standard.set(0, forKey: kTrialDeclarationCount)

        scheduleTrialPushes(from: now)
        Analytics.logEvent("trial_experience_started", parameters: [:])
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
        Analytics.logEvent("trial_experience_converted", parameters: [
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

    // MARK: - Push Notifications

    private func scheduleTrialPushes(from startDate: Date) {
        center.getNotificationSettings { [weak self] settings in
            // Schedule while permission is still .notDetermined too: the paywall
            // (and trial timeline) runs BEFORE the onboarding notification ask,
            // and pending requests added pre-authorization deliver normally once
            // the user grants permission. Only a hard denial makes them pointless.
            guard settings.authorizationStatus != .denied else { return }
            self?.scheduleDay2Push(from: startDate)
            self?.scheduleDay3Push(from: startDate)
        }
    }

    private func scheduleDay2Push(from startDate: Date) {
        let category = UserPreferencesTracker.shared.primaryCategory
        let (title, body) = day2Copy(for: category)

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = ["lifecycle_id": "trial_d2"]

        guard let fireDate = Calendar.current.date(byAdding: .day, value: 1, to: startDate) else { return }
        let adjusted = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: fireDate) ?? fireDate
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: adjusted)

        center.add(UNNotificationRequest(
            identifier: "trial_d2",
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        ))
    }

    private func scheduleDay3Push(from startDate: Date) {
        let category = UserPreferencesTracker.shared.primaryCategory
        let (title, body) = day3Copy(for: category)

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = ["lifecycle_id": "trial_d3"]

        guard let fireDate = Calendar.current.date(byAdding: .day, value: 2, to: startDate) else { return }
        let adjusted = Calendar.current.date(bySettingHour: 8, minute: 30, second: 0, of: fireDate) ?? fireDate
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: adjusted)

        center.add(UNNotificationRequest(
            identifier: "trial_d3",
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        ))
    }

    // MARK: - Personalized Copy

    private func day2Copy(for category: UserPreferencesTracker.CategoryType) -> (String, String) {
        switch category {
        case .anxiety:
            return (
                "Day 2 of your free trial ✨",
                "Priya was having panic attacks at work every week. After 14 days of anxiety declarations she hasn't had one since. Your trial ends tomorrow — don't stop here."
            )
        case .fear:
            return (
                "Day 2 — keep going 💪",
                "Marcus was paralyzed by fear of failure for 3 years. One month of declarations later, he launched his business. You're on day 2. Don't quit on yourself now."
            )
        case .marriage:
            return (
                "Day 2 of your trial ❤️",
                "Samantha and her husband were on the verge of separation. They started declaring together every morning. 60 days later, completely different marriage. Your trial ends tomorrow."
            )
        case .health:
            return (
                "Day 2 — your healing is activating 🙏",
                "David was told his diagnosis was permanent. He started declaring healing scriptures daily. His doctors called his recovery remarkable. Don't stop speaking life over your body."
            )
        case .faith:
            return (
                "Day 2 of building unshakeable faith ⚡",
                "Faith isn't built in a day — it's built declaration by declaration. You've been at it for 2 days. The people who keep going for 30 days say their entire outlook changes. Trial ends tomorrow."
            )
        case .confidence:
            return (
                "Day 2 — you're becoming someone new 👑",
                "Jordan couldn't speak up in meetings for years. 21 days of identity declarations later, she got promoted. You're on day 2 of that same transformation. Keep going."
            )
        case .hope:
            return (
                "Day 2 — hope is being restored 🌅",
                "After losing his job, Michael felt hopeless for months. Daily declarations rebuilt his expectation. Within 60 days he had two offers. Your trial ends tomorrow — stay the course."
            )
        default:
            return (
                "Day 2 of your free trial 🔥",
                "You've already spoken declarations that are rewiring how you think. The people who make it to day 30 say the change is undeniable. Your trial ends tomorrow — don't stop now."
            )
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
