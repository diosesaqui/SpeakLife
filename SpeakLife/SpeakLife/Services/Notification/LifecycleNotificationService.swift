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
//  Bedtime audio:
//      bedtime_audio nightly 9:30pm (one repeating slot), rewritten on every app open
//
//  Call .scheduleLifecycleNotifications() once after onboarding completes.
//  Call .onAppOpen() on every cold launch + warm foreground to reset lapsed timers.
//

import Foundation
import UserNotifications

// `StreakNotifying` moved into SpeakLifeServices (Sources/SpeakLifeServices/StreakNotifying.swift)
// so `EnhancedStreakViewModel` — which lives in the package — can reference it
// without pulling the app target into the package graph. The conformance below
// is unchanged; the protocol just lives in Services now.
extension LifecycleNotificationService: StreakNotifying {}

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
            AnalyticsService.shared.track("lifecycle_notifications_scheduled", parameters: [:])
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
            AnalyticsService.shared.track("lifecycle_notifications_repaired", parameters: [:])
        }
    }

    /// Call on every app open (cold launch + warm foreground)
    func onAppOpen() {
        UserDefaults.standard.set(Date(), forKey: kLastOpenDate)
        // Cancel any pending lapsed re-engagement since user came back.
        // "lapsed_d10" is retired but still listed so devices carrying a
        // pending one from a previous build get it cleared on next launch.
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
        AnalyticsService.shared.track("streak_milestone_scheduled", parameters: ["streak": currentStreak])
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
        AnalyticsService.shared.track("streak_break_notification_scheduled", parameters: ["previous_streak": previousStreak])
    }

    /// Revokes the streak-break push. Because it fires the NEXT morning rather
    /// than on the break itself, there is a long window in which its premise
    /// can stop being true — a freeze bridges the gap, a day earned on another
    /// device syncs in, or the user simply comes back and completes. Delivered
    /// copies are pulled too: a break notice sitting in Notification Center is
    /// just as wrong as one about to fire, and it carries a streak count that
    /// by then contradicts the badge.
    func cancelStreakBreakNotification() {
        center.removePendingNotificationRequests(withIdentifiers: ["streak_break"])
        center.removeDeliveredNotifications(withIdentifiers: ["streak_break"])
    }

    // MARK: - Lapsed Re-engagement

    /// One re-engagement push, not two. `lapsed_d10` was retired: it only ever
    /// reached someone who had already ignored `lapsed_d5`, so it was a second
    /// ask of the least receptive audience we have. The d5 push stays because
    /// it's re-armed on every app open and therefore only fires on genuine
    /// absence.
    private func scheduleLapsedDetection() {
        center.getNotificationSettings { [weak self] settings in
            guard settings.authorizationStatus == .authorized else { return }
            self?.scheduleImmediate(
                id: "lapsed_d5",
                title: "Your mind is waiting for you 🙏",
                body: "You haven't declared in a few days. The enemy loves silence. Come back and speak life over yourself today.",
                delayHours: 5 * 24
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
                AnalyticsService.shared.track("lifecycle_notification_error", parameters: ["id": id, "error": error.localizedDescription])
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

// MARK: - Bedtime Audio

// Audio listening peaks twice a day: 6–9 AM, and again 10 PM–midnight, when
// almost no push lands (Sep 2026, US users). The morning slot already belongs
// to the burst push, so this takes the empty one: a nightly 9:30 PM nudge that
// opens a sleep-time episode and starts it playing (`deepLink: "audio"`,
// SpeakLifeApp).
//
// ONE repeating request, not a week of dated ones. The 64-pending budget is
// already spoken for (see `NotificationManager.daysAhead`), and seven more
// would make iOS silently drop other sends. It is rewritten on every app open,
// so the episode follows the user's current category and plan and the copy
// moves to the next line; someone who never reopens keeps tonight's line.
extension LifecycleNotificationService {

    static let bedtimeAudioEnabledKey = "bedtimeAudioEnabled"
    private static let bedtimeHour = 21
    private static let bedtimeMinute = 30
    private static let bedtimeID = "bedtime_audio"
    static let trialAudioID = "trial_audio_d1"
    private static let trialAudioNightKey = "trial_audio_d1_night"

    /// Day 1 of a trial: tonight's bedtime push introduces the audio library
    /// in the storm's words ("For tonight's quiet") instead of the usual line.
    /// It replaces tonight's nightly push rather than adding a second one.
    /// Users who touch audio in the trial convert more, so the first night is
    /// where it is introduced.
    func scheduleTrialFirstNightAudio(category: String, title: String, body: String) {
        // Turned off on the Reminders screen: no bedtime push of any kind.
        if UserDefaults.standard.object(forKey: Self.bedtimeAudioEnabledKey) as? Bool == false { return }
        let calendar = Calendar.current
        guard let fire = calendar.date(bySettingHour: Self.bedtimeHour, minute: Self.bedtimeMinute,
                                       second: 0, of: Date()),
              fire > Date() else { return }
        let episode = Self.bedtimeEpisode(isPremium: true, category: category)

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = [
            "action": Self.trialAudioID,
            "deepLink": "audio",
            "audioId": episode.audioId
        ]
        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
        UserDefaults.standard.set(Date(), forKey: Self.trialAudioNightKey)
        center.removePendingNotificationRequests(withIdentifiers: [Self.bedtimeID])
        center.add(UNNotificationRequest(
            identifier: Self.trialAudioID,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        ))
    }

    private struct BedtimeEpisode {
        let audioId: String
        let copy: [(title: String, body: String)]
    }

    // Free episodes only for free users: a paywall is the wrong thing to hand
    // someone at bedtime. Peace Beyond Understanding is premium, so it is kept
    // for subscribers.
    private static let psalm91 = BedtimeEpisode(audioId: "psalm9_11.mp3", copy: [
        ("Rest under His shadow 🕊️", "You dwell in the shelter of the Most High tonight (Ps 91:1). Let Psalm 91 play as you fall asleep."),
        ("Hear it before you sleep", "Faith comes by hearing (Rom 10:17). Let His promises be the last words you hear today."),
        ("Safe through the night", "\"You will not fear the terror of night.\" (Ps 91:5) Press play on Psalm 91 and rest in it."),
        ("Your refuge tonight", "He is your refuge and your fortress (Ps 91:2). Hear Psalm 91 over you and sleep in His peace."),
        ("End the day in the Word", "Before the screen goes dark, let the Word go in. Psalm 91 is ready for you."),
        ("His angels keep watch", "\"He will command His angels concerning you.\" (Ps 91:11) Hear it tonight, then rest."),
        ("Sleep covered 🎧", "Covered by His feathers, sheltered under His wings (Ps 91:4). Let Psalm 91 carry you to sleep.")
    ])

    private static let healing = BedtimeEpisode(audioId: "healed_v2.mp3", copy: [
        ("Health to all your flesh", "His words are life and health to all your flesh (Prov 4:22). Take tonight's dose before you sleep."),
        ("One more dose tonight 💊", "Let His Word work while you rest. Play Healing Declarations and fall asleep in His promise."),
        ("By His wounds", "\"By His wounds you have been healed.\" (1 Pet 2:24) Hear it over your body tonight.")
    ])

    private static let peace = BedtimeEpisode(audioId: "peace_v2.mp3", copy: [
        ("Peace for tonight 🕊️", "His peace guards your heart and your mind (Phil 4:7). Play Peace Beyond Understanding and rest."),
        ("Sweet sleep is yours", "\"When you lie down, your sleep will be sweet.\" (Prov 3:24) Let His Word be the last thing you hear."),
        ("A sound mind at rest", "You have the mind of Christ (1 Cor 2:16). Hear His promises of peace tonight and rest in them.")
    ])

    private static func bedtimeEpisode(isPremium: Bool, category: String?) -> BedtimeEpisode {
        let category = category ?? UserDefaults.standard.string(forKey: "selectedCategory") ?? ""
        switch category {
        case "health", "wellness", "fertility":
            return healing
        case "anxiety", "fear", "mentalHealth", "rest":
            return isPremium ? peace : psalm91
        default:
            return psalm91
        }
    }

    /// Schedules the nightly bedtime audio push, replacing the queued one.
    /// Safe to call on every open. No-op without permission; clears it when
    /// the user has turned it off. The first call with permission sets the
    /// on/off default from the Daily Declaration Reminder switch.
    ///
    /// `category` overrides the saved one: onboarding schedules this before
    /// the category is saved, since the paywall comes first.
    func scheduleBedtimeAudio(isPremium: Bool, category: String? = nil) {
        let defaults = UserDefaults.standard
        // Tonight belongs to the trial's first-night audio push. The nightly
        // request repeats, so re-adding it now would send both at 9:30pm; it
        // comes back on the first open after tonight.
        if let night = defaults.object(forKey: Self.trialAudioNightKey) as? Date,
           Calendar.current.isDateInToday(night) { return }
        center.removePendingNotificationRequests(withIdentifiers: [Self.bedtimeID])
        // Turned off on the Reminders screen.
        if defaults.object(forKey: Self.bedtimeAudioEnabledKey) as? Bool == false { return }

        let episode = Self.bedtimeEpisode(isPremium: isPremium, category: category)
        center.getNotificationSettings { [weak self] settings in
            guard let self = self, settings.authorizationStatus == .authorized else { return }

            // First schedule with permission: inherit the in-app Daily
            // Declaration Reminder switch. Someone who turned reminders off
            // but kept iOS permission (common for users who update into this
            // feature) must not start getting a nightly push they never asked
            // for. Seeded here, behind the permission check, because
            // `notificationEnabled` is false for every install until
            // onboarding grants, and seeding earlier would switch bedtime off
            // for all of them. From then on only the Bedtime Audio toggle
            // decides.
            if defaults.object(forKey: Self.bedtimeAudioEnabledKey) == nil {
                let remindersOn = defaults.bool(forKey: "notificationEnabled")
                defaults.set(remindersOn, forKey: Self.bedtimeAudioEnabledKey)
                guard remindersOn else { return }
            }

            // Rotate by calendar day, so opening the app picks today's line
            // rather than resetting everyone to the first.
            let day = Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
            let line = episode.copy[day % episode.copy.count]

            let content = UNMutableNotificationContent()
            content.title = line.title
            content.body = line.body
            content.sound = .default
            content.userInfo = [
                "action": "bedtime_audio",   // notification_opened type
                "deepLink": "audio",
                "audioId": episode.audioId
            ]

            var comps = DateComponents()
            comps.hour = Self.bedtimeHour
            comps.minute = Self.bedtimeMinute
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            self.center.add(UNNotificationRequest(identifier: Self.bedtimeID, content: content, trigger: trigger))
        }
    }
}
