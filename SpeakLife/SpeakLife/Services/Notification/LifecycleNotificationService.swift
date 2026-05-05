//
//  LifecycleNotificationService.swift
//  SpeakLife
//
//  Retention-engineered push sequence personalized by survey goal word.
//
//  Lifecycle (install-anchored, one-time):
//      D1 8am, D2 6pm, D3 9am, D4 9am, D7 8am, D14 8am, D30 9am
//  Streak:
//      streak_at_risk daily 6:30pm (replaces old 9pm; 9pm is too late for action)
//      streak_break next morning 9am (replaces old +2h; comeback > guilt)
//  Lapsed:
//      lapsed_d5, lapsed_d10 — soft re-engagement based on no app open
//
//  Call .scheduleLifecycleNotifications() once after onboarding completes.
//  Call .onAppOpen() on every cold launch + warm foreground to reset lapsed timers.
//

import Foundation
import UserNotifications
import FirebaseAnalytics

final class LifecycleNotificationService {
    static let shared = LifecycleNotificationService()
    private init() {}

    private let center = UNUserNotificationCenter.current()

    // UserDefaults keys
    private let kInstallDate        = "lifecycle_install_date"
    private let kLastOpenDate       = "lifecycle_last_open_date"
    private let kLifecycleScheduled = "lifecycle_notifications_scheduled"

    // MARK: - Entry Points

    /// Call once after onboarding completes
    func scheduleLifecycleNotifications() {
        guard !UserDefaults.standard.bool(forKey: kLifecycleScheduled) else { return }

        let installDate = Date()
        UserDefaults.standard.set(installDate, forKey: kInstallDate)

        center.getNotificationSettings { [weak self] settings in
            guard let self = self else { return }
            // Only mark as scheduled once we successfully add the requests.
            // If permission isn't granted yet, leave the flag unset so the
            // next call (e.g. after user enables in settings) can retry.
            guard settings.authorizationStatus == .authorized else { return }
            self.scheduleAll(from: installDate)
            UserDefaults.standard.set(true, forKey: self.kLifecycleScheduled)
            Analytics.logEvent("lifecycle_notifications_scheduled", parameters: [:])
        }
    }

    /// One-time heal for users whose lifecycle pushes (D1-D30) were wiped by
    /// the legacy `removeAllPendingNotificationRequests()` bug in
    /// NotificationManager. Re-schedules from the original install date so
    /// already-passed days don't fire. Idempotent: only runs once via the
    /// `lifecycle_repaired_v1` flag, and a no-op if the user never had a
    /// lifecycle batch scheduled in the first place (fresh installs).
    func repairLifecycleIfNeeded() {
        let healFlag = "lifecycle_repaired_v1"
        guard !UserDefaults.standard.bool(forKey: healFlag) else { return }
        guard UserDefaults.standard.bool(forKey: kLifecycleScheduled),
              let installDate = UserDefaults.standard.object(forKey: kInstallDate) as? Date else {
            // Mark as repaired so brand-new installs don't keep retrying this branch.
            UserDefaults.standard.set(true, forKey: healFlag)
            return
        }

        center.getNotificationSettings { [weak self] settings in
            guard let self = self else { return }
            guard settings.authorizationStatus == .authorized else { return }
            self.scheduleAll(from: installDate)
            UserDefaults.standard.set(true, forKey: healFlag)
            Analytics.logEvent("lifecycle_notifications_repaired", parameters: [:])
        }
    }

    /// Call on every app open (cold launch + warm foreground)
    func onAppOpen() {
        UserDefaults.standard.set(Date(), forKey: kLastOpenDate)
        // Cancel any pending lapsed re-engagement since user came back
        center.removePendingNotificationRequests(withIdentifiers: ["lapsed_d5", "lapsed_d10"])
        // Re-schedule lapsed detection
        scheduleLapsedDetection()
    }

    // MARK: - Schedule All Lifecycle Notifications

    private func scheduleAll(from installDate: Date) {
        // Pull personalization context once. Goal word drives copy, name when available.
        let goal = SurveyGoalWord(rawValue: UserDefaults.standard.string(forKey: "surveyGoalWord") ?? "")
        let nameRaw = UserDefaults.standard.string(forKey: "userName") ?? ""
        let name = nameRaw.isEmpty ? nil : nameRaw

        let messages: [(id: String, days: Int, hour: Int, minute: Int, copy: LifecycleCopy)] = [
            (id: "lifecycle_d1",  days: 1,  hour: 8,  minute: 0,  copy: copyD1(goal: goal,  name: name)),
            (id: "lifecycle_d2",  days: 2,  hour: 18, minute: 0,  copy: copyD2(goal: goal,  name: name)),
            (id: "lifecycle_d3",  days: 3,  hour: 9,  minute: 0,  copy: copyD3(goal: goal,  name: name)),
            // D4 fills the real day-3-to-7 cliff. Mixpanel/Amplitude data on
            // habit-formation apps shows day 4 is where users either commit or quit.
            (id: "lifecycle_d4",  days: 4,  hour: 9,  minute: 0,  copy: copyD4(goal: goal,  name: name)),
            (id: "lifecycle_d7",  days: 7,  hour: 8,  minute: 0,  copy: copyD7(goal: goal,  name: name)),
            (id: "lifecycle_d14", days: 14, hour: 8,  minute: 0,  copy: copyD14(goal: goal, name: name)),
            (id: "lifecycle_d30", days: 30, hour: 9,  minute: 0,  copy: copyD30(goal: goal, name: name)),
        ]

        for msg in messages {
            schedule(
                id: msg.id,
                title: msg.copy.title,
                body: msg.copy.body,
                daysFromNow: msg.days,
                hour: msg.hour,
                minute: msg.minute,
                from: installDate
            )
        }
    }

    // MARK: - Streak At-Risk Notification

    /// Schedule a daily 6:30pm notification reminding the user their streak is on the line.
    /// 6:30pm is intentional: late enough that the user has had a workday, early enough that
    /// there's still a meaningful evening window to come back. 9pm (the old time) lands when
    /// people are winding down with phones face-down.
    func scheduleStreakAtRiskNotification(currentStreak: Int) {
        // Cancel first to avoid duplicates
        center.removePendingNotificationRequests(withIdentifiers: ["streak_at_risk"])

        guard currentStreak >= 1 else { return }

        center.getNotificationSettings { [weak self] settings in
            guard settings.authorizationStatus == .authorized else { return }

            let content = UNMutableNotificationContent()
            content.title = "Your \(currentStreak)-day streak ends tonight 🔥"
            content.body = "You've come too far to lose it. 60 seconds saves it — open SpeakLife and speak one declaration before midnight."
            content.sound = .default
            content.userInfo = ["notificationType": "streakAtRisk"]

            var components = DateComponents()
            components.hour = 18
            components.minute = 30
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(identifier: "streak_at_risk", content: content, trigger: trigger)
            self?.center.add(request, withCompletionHandler: nil)
        }
    }

    func cancelStreakAtRiskNotification() {
        center.removePendingNotificationRequests(withIdentifiers: ["streak_at_risk"])
    }

    // MARK: - Streak Milestones

    /// Celebrates 3/7/30/100-day streak crossings. Scheduled for the next morning at
    /// 9 AM so the user wakes up to a win — a same-day push would just duplicate the
    /// in-app celebration animation that fires on completion. Each milestone has a
    /// stable ID, so re-hitting after a break (e.g. building back to 3) refires the
    /// celebration without stacking.
    ///
    /// Returns true if a milestone push was scheduled.
    @discardableResult
    func scheduleStreakMilestoneIfNeeded(currentStreak: Int, previousStreak: Int) -> Bool {
        // Only fire on the exact crossing — not every subsequent day past the milestone.
        let milestones = [3, 7, 30, 100]
        guard milestones.contains(currentStreak), previousStreak < currentStreak else {
            return false
        }

        let copy = streakMilestoneCopy(for: currentStreak)
        let id = "streak_milestone_\(currentStreak)"

        center.getNotificationSettings { [weak self] settings in
            guard let self = self else { return }
            guard settings.authorizationStatus == .authorized else { return }

            self.center.removePendingNotificationRequests(withIdentifiers: [id])

            let content = UNMutableNotificationContent()
            content.title = copy.title
            content.body = copy.body
            content.sound = .default
            content.userInfo = ["lifecycle_id": id, "deepLink": "declarations"]

            let calendar = Calendar.current
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
            let fireDate = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow) ?? tomorrow
            let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            self.center.add(request, withCompletionHandler: nil)
        }
        Analytics.logEvent("streak_milestone_scheduled", parameters: ["streak": currentStreak])
        return true
    }

    private func streakMilestoneCopy(for streak: Int) -> (title: String, body: String) {
        switch streak {
        case 3:
            return (
                title: "Three. Days. In a row 🔥",
                body: "You're official now. The first 3 days are where most quit — and you didn't. Keep going."
            )
        case 7:
            return (
                title: "ONE. WEEK. 💪",
                body: "Seven days of speaking life. You're not someone who tries — you're someone who shows up. Day 8 starts now."
            )
        case 30:
            return (
                title: "30 days. You changed your life 🙌",
                body: "A month of declarations. This isn't motivation anymore. This is who you are. Don't stop here."
            )
        case 100:
            return (
                title: "100 days, you absolute monster 👑",
                body: "100 days of consistency. That's rare air. You've built something most people only talk about. Keep building."
            )
        default:
            return (
                title: "\(streak)-day streak 🔥",
                body: "Keep going."
            )
        }
    }

    // MARK: - Streak Break Notification

    /// Call when a streak is broken (streak resets to 0). Fires the next morning at 9am
    /// instead of two hours after the break — comeback framing outperforms guilt framing
    /// for habit re-engagement (Duolingo's research on streak revival).
    func scheduleStreakBreakNotification(previousStreak: Int) {
        guard previousStreak >= 3 else { return } // Only notify if streak was meaningful
        center.getNotificationSettings { [weak self] settings in
            guard let self = self else { return }
            guard settings.authorizationStatus == .authorized else { return }

            self.center.removePendingNotificationRequests(withIdentifiers: ["streak_break"])

            let content = UNMutableNotificationContent()
            content.title = "Yesterday slipped. Today's clean."
            content.body = "Your \(previousStreak)-day streak broke. Champions break streaks. The ones who win come back the next morning. Restart today."
            content.sound = .default
            content.userInfo = ["lifecycle_id": "streak_break", "deepLink": "declarations"]

            // Fire tomorrow at 9 AM regardless of when the break happened.
            let calendar = Calendar.current
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
            let fireDate = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow) ?? tomorrow
            let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let request = UNNotificationRequest(identifier: "streak_break", content: content, trigger: trigger)
            self.center.add(request, withCompletionHandler: nil)
        }
        Analytics.logEvent("streak_break_notification_scheduled", parameters: ["previous_streak": previousStreak])
    }

    // MARK: - Lapsed Re-engagement

    private func scheduleLapsedDetection() {
        center.getNotificationSettings { [weak self] settings in
            guard settings.authorizationStatus == .authorized else { return }
            self?.scheduleImmediate(
                id: "lapsed_d5",
                title: "Your mind is waiting for you 🙏",
                body: "You haven't declared in a few days. The enemy loves silence. Come back and speak life over yourself today.",
                delayHours: 5 * 24
            )
            self?.scheduleImmediate(
                id: "lapsed_d10",
                title: "Still thinking about you ❤️",
                body: "SpeakLife works when you show up. 60 seconds of declarations is all it takes. Your breakthrough is one open away.",
                delayHours: 10 * 24
            )
        }
    }

    // MARK: - Helpers

    private func schedule(id: String, title: String, body: String, daysFromNow: Int, hour: Int, minute: Int = 0, from date: Date) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = ["lifecycle_id": id, "deepLink": "declarations"]

        var triggerDate = Calendar.current.date(byAdding: .day, value: daysFromNow, to: date) ?? date
        triggerDate = Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: triggerDate) ?? triggerDate
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.add(request) { error in
            if let error = error {
                Analytics.logEvent("lifecycle_notification_error", parameters: ["id": id, "error": error.localizedDescription])
            }
        }
    }

    private func scheduleImmediate(id: String, title: String, body: String, delayHours: Double) {
        center.removePendingNotificationRequests(withIdentifiers: [id])

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = ["lifecycle_id": id, "deepLink": "declarations"]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delayHours * 3600, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.add(request, withCompletionHandler: nil)
    }
}

// MARK: - Personalized Copy

/// Lifecycle copy is goal-word-aware so a user pursuing peace doesn't get the same
/// generic D1 push as a user pursuing healing or prosperity. Iterable's 2023 push
/// data showed 4× engagement lift on personalized vs. generic body copy.
private struct LifecycleCopy {
    let title: String
    let body: String
}

private func nameToken(_ name: String?) -> String {
    name.map { ", \($0)" } ?? ""
}

// MARK: D1 — morning after install. Reinforce yesterday's commitment.
private func copyD1(goal: SurveyGoalWord?, name: String?) -> LifecycleCopy {
    let n = nameToken(name)
    switch goal {
    case .peace:
        return LifecycleCopy(
            title: "Day 1 of taking back your peace ✨",
            body: "Yesterday you said anxiety was running your mornings. Today is where that changes\(n). 60 seconds. Speak."
        )
    case .identity:
        return LifecycleCopy(
            title: "Day 1 — who God says you are 👑",
            body: "You said you'd lost sight of your identity. The Word remembers. Open SpeakLife and let it speak who you really are."
        )
    case .purpose:
        return LifecycleCopy(
            title: "Day 1 of stepping into your calling 🧭",
            body: "Yesterday you owned that you weren't walking in your purpose\(n). Today's declarations call it forward. Speak."
        )
    case .joy:
        return LifecycleCopy(
            title: "Day 1 of choosing joy ☀️",
            body: "Joy isn't a feeling you wait for — it's a truth you declare. Open SpeakLife and speak it over today."
        )
    case .confidence:
        return LifecycleCopy(
            title: "Day 1 of becoming bold ⚡",
            body: "Yesterday you said you wanted confidence. Confidence is built one declaration at a time\(n). Open and speak."
        )
    case .healing:
        return LifecycleCopy(
            title: "Day 1 of speaking healing 🌿",
            body: "Healing scriptures are weapons\(n). Today is day 1 of putting them in your mouth. Open SpeakLife now."
        )
    case .prosperity:
        return LifecycleCopy(
            title: "Day 1 of walking in overflow 💰",
            body: "Provision is your portion\(n). Today's declarations align your words with what God already said. Open and speak."
        )
    case .none:
        return LifecycleCopy(
            title: "Day 1 — your mind is being renewed ✨",
            body: "One day in. Repetition is how truth sticks\(n). Open SpeakLife and speak 3 declarations right now."
        )
    }
}

// MARK: D2 — 6 PM. Anti-fade. Day 2 is where most quit.
private func copyD2(goal: SurveyGoalWord?, name: String?) -> LifecycleCopy {
    let n = nameToken(name)
    let goalLabel = goal?.shortGoalLabel ?? "the change you want"
    return LifecycleCopy(
        title: "Day 2 is where most quit\(n)",
        body: "The enemy of \(goalLabel) isn't your circumstances — it's forgetting tomorrow what you knew today. 60 seconds. Speak."
    )
}

// MARK: D3 — 9 AM. Identity emergence (replaces gimmicky "14% there").
private func copyD3(goal: SurveyGoalWord?, name: String?) -> LifecycleCopy {
    let n = nameToken(name)
    return LifecycleCopy(
        title: "3 mornings of speaking life 🔥",
        body: "You're not the same person who downloaded this on day 1\(n). Three mornings have shifted your default. Don't drop the rope today."
    )
}

// MARK: D4 — 9 AM. Past-the-cliff. NEW.
private func copyD4(goal: SurveyGoalWord?, name: String?) -> LifecycleCopy {
    let n = nameToken(name)
    return LifecycleCopy(
        title: "You're past the hardest part\(n)",
        body: "Most quit by day 4. You didn't. That's who you are now — someone who shows up. Speak today's declarations."
    )
}

// MARK: D7 — 8 AM. Week milestone. Goal-personalized payoff.
private func copyD7(goal: SurveyGoalWord?, name: String?) -> LifecycleCopy {
    let n = nameToken(name)
    let goalLabel = goal?.shortGoalLabel ?? "what you wanted"
    return LifecycleCopy(
        title: "One week of speaking life 💪",
        body: "Seven days ago you wanted \(goalLabel)\(n). Now you're walking toward it. Don't stop here — week two is where it sticks."
    )
}

// MARK: D14 — 8 AM. Compounding payoff.
private func copyD14(goal: SurveyGoalWord?, name: String?) -> LifecycleCopy {
    let n = nameToken(name)
    return LifecycleCopy(
        title: "Two weeks. You feel it yet\(n)?",
        body: "Even when the change is invisible, your default is shifting. Open and feel it."
    )
}

// MARK: D30 — 9 AM. Identity confirmation.
private func copyD30(goal: SurveyGoalWord?, name: String?) -> LifecycleCopy {
    let n = nameToken(name)
    let goalLabel = goal?.shortGoalLabel ?? "who you wanted to be"
    return LifecycleCopy(
        title: "30 days. You changed your life\(n).",
        body: "A month ago you wanted \(goalLabel). Today, that's who you are. Keep going — this is just the beginning."
    )
}

// MARK: - SurveyGoalWord helper

private extension SurveyGoalWord {
    /// Short, lowercase, in-sentence label of the goal. Used in body copy
    /// like "the change you want / your peace / your healing".
    var shortGoalLabel: String {
        switch self {
        case .peace:      return "your peace"
        case .identity:   return "knowing who you are"
        case .purpose:    return "your calling"
        case .joy:        return "your joy"
        case .confidence: return "your confidence"
        case .healing:    return "your healing"
        case .prosperity: return "your overflow"
        }
    }
}
