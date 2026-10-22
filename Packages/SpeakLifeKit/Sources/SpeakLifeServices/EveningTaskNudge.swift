//
//  EveningTaskNudge.swift
//  SpeakLifeServices
//
//  The evening push for a user whose streak is already safe. Once the burst
//  is spoken, "your streak ends tonight" would be false, so the evening slot
//  names the first thing still open on today's list and what it gives them.
//

import Foundation
import SpeakLifeCore

public struct EveningTaskNudge: Equatable {
    public let taskId: String
    public let title: String
    public let body: String
    /// Matches the app's notification deep-link routes ("audio", "bibleChat").
    /// Nil opens the Today tab, where the checklist row is one tap away.
    public let deepLink: String?
    /// Foundation-week episode the audio row points at, so the tap plays it.
    public let audioId: String?

    /// Which open task to call out when several are. Audio, gratitude and
    /// journal lead: they are the ones the user asked to surface, and the ones
    /// whose payoff fits the end of a day.
    static let priority = [
        "listen_audio",
        TaskLibrary.gratitudeTaskId,
        "journal_insight",
        "read_devotional",
        TaskLibrary.personalDeclarationTaskId,
        TaskLibrary.guardTaskId,
        "ask_the_bible",
        "memorize_verse",
        "share_affirmation",
    ]

    /// The nudge for today's checklist, or nil when there is nothing to nudge:
    /// the burst is not done yet (that is the streak-at-risk push's job), or
    /// every task is finished.
    public static func next(for checklist: DailyChecklist) -> EveningTaskNudge? {
        guard checklist.isStreakEarned else { return nil }
        let open = checklist.tasks.filter { !$0.isCompleted && $0.id != "complete_daily_burst" }
        guard !open.isEmpty else { return nil }
        let task = priority.lazy.compactMap { id in open.first { $0.id == id } }.first ?? open[0]
        return make(for: task, openCount: open.count)
    }

    static func make(for task: DailyTask, openCount: Int) -> EveningTaskNudge {
        switch task.id {
        case "listen_audio":
            return EveningTaskNudge(
                taskId: task.id,
                title: "Burst spoken. Now let faith rise 🎧",
                body: "Faith comes by hearing. Give the Word a few minutes tonight and fall asleep with it settling in.",
                deepLink: "audio", audioId: task.recommendedAudioId)
        case TaskLibrary.gratitudeTaskId:
            return EveningTaskNudge(
                taskId: task.id,
                title: "Three things you're grateful for 🙏",
                body: "Before you sleep, write down three good things from today and thank God for each one.",
                deepLink: nil, audioId: nil)
        case "journal_insight":
            return EveningTaskNudge(
                taskId: task.id,
                title: "What did God show you today? ✍️",
                body: "Write one line before bed. What you write down, you keep, and you'll read it back on the day you need it.",
                deepLink: nil, audioId: nil)
        case "read_devotional":
            return EveningTaskNudge(
                taskId: task.id,
                title: "Five minutes in the Word tonight 📖",
                body: "Your burst is done. Today's devotional plants truth deep, so tomorrow starts on solid ground.",
                deepLink: nil, audioId: nil)
        case TaskLibrary.personalDeclarationTaskId:
            return EveningTaskNudge(
                taskId: task.id,
                title: "Speak what you're believing for 🙌",
                body: "Your burst is done. Now say your own promise out loud. What you speak in faith, you build.",
                deepLink: nil, audioId: nil)
        case TaskLibrary.guardTaskId:
            return EveningTaskNudge(
                taskId: task.id,
                title: "Take one thought captive tonight 🛡️",
                body: "Pick one thought, speak the truth over it, and go to sleep with a sound mind.",
                deepLink: nil, audioId: nil)
        case "ask_the_bible":
            return EveningTaskNudge(
                taskId: task.id,
                title: "What are you carrying tonight? 💬",
                body: "Bring it to the Word before bed and get Scripture on the exact thing in front of you.",
                deepLink: "bibleChat", audioId: nil)
        case "memorize_verse":
            return EveningTaskNudge(
                taskId: task.id,
                title: "Hide one verse in your heart tonight 🧠",
                body: "A verse you know by heart is one you can speak anywhere, the moment you need it.",
                deepLink: nil, audioId: nil)
        case "share_affirmation":
            return EveningTaskNudge(
                taskId: task.id,
                title: "Share the life you've been speaking ✨",
                body: "Send one declaration to someone tonight. A word in season can turn their whole day.",
                deepLink: nil, audioId: nil)
        default:
            let more = openCount == 1 ? "One thing left" : "\(openCount) things left"
            return EveningTaskNudge(
                taskId: task.id,
                title: "Burst spoken. Finish strong tonight 🔥",
                body: "\(more) on today's list. Next up: \(task.title).",
                deepLink: nil, audioId: nil)
        }
    }
}
