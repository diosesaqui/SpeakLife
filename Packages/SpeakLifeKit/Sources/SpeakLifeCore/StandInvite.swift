//
//  StandInvite.swift
//  SpeakLifeCore
//
//  The pure rules behind the invite loop: what the invite says, when the day-1
//  ask appears, and what the Today row shows once somebody is standing with
//  you. Foundation only, like `StandRoom`, so every rule here runs under
//  `swift test` without a simulator.
//

import Foundation

// MARK: - Copy

/// How a campaign is named inside invite copy.
///
/// `theme.name` is a browse label ("Anxiety & Worry", "Warfare & Victory"), and
/// "I'm standing for anxiety & worry" names the low thing as the goal.
/// `enforcementTitle` is already the victory ("Peace", "Victory", "My
/// Marriage"), so the invite says what is being stood FOR.
public enum StandInviteCopy {

    /// "peace", "my marriage", "God's promise". For the sender's own voice:
    /// "I'm standing on God's word for my marriage."
    public static func firstPerson(_ theme: DeclarationCategory) -> String {
        sentenceCase(theme.enforcementTitle)
    }

    /// "peace", "your marriage", "God's promise". For lines addressed to the
    /// sender: "They'll see you're standing for your marriage." Without the
    /// swap a dozen possessive titles read "you're standing for my marriage".
    public static func secondPerson(_ theme: DeclarationCategory) -> String {
        let phrase = firstPerson(theme)
        guard phrase.hasPrefix("my ") else { return phrase }
        return "your " + String(phrase.dropFirst(3))
    }

    /// Lowercases every word except the name of God, so "My Walk With God"
    /// becomes "my walk with God" and "God's Promise" keeps its capital.
    static func sentenceCase(_ title: String) -> String {
        title
            .split(separator: " ", omittingEmptySubsequences: true)
            .map { word -> String in
                word.hasPrefix("God") ? String(word) : word.lowercased()
            }
            .joined(separator: " ")
    }
}

// MARK: - Day-1 ask

/// When the "Who needs this with you?" sheet may appear.
///
/// It used to share a lifetime budget of three asks, and only somebody who had
/// never been asked could be asked again. So a person's first campaign got the
/// ask and every campaign after it got nothing, which is most of why 56 stands
/// a month were created from 23 prompts. The rule now is per run: every new
/// campaign gets the ask once, and no campaign gets it twice.
public enum StandInvitePromptRule {

    /// Day 1 is the moment: they have just spoken it out loud. Days 2 and 3
    /// are only a fallback for a run whose day-1 ask was pushed aside by a
    /// higher-priority sheet (the welcome offer fires on the same burst). A run
    /// that was asked on day 1 is never asked again.
    public static let window: ClosedRange<Int> = 1...3

    /// How many run keys are remembered. A run is seven days, so twenty covers
    /// months of campaigns while keeping the stored list tiny.
    public static let memory = 20

    /// - Parameters:
    ///   - runKey: identifies this run of the campaign
    ///     (`EnforcementProgress.activeRunKey`, falling back to the id).
    ///   - completedDays: days banked in the run so far.
    ///   - promptedRuns: run keys already asked.
    public static func shouldPrompt(runKey: String,
                                    completedDays: Int,
                                    promptedRuns: [String]) -> Bool {
        !runKey.isEmpty
            && window.contains(completedDays)
            && !promptedRuns.contains(runKey)
    }

    /// `promptedRuns` with `runKey` added, oldest dropped past `memory`.
    public static func recording(_ runKey: String, in promptedRuns: [String]) -> [String] {
        guard !runKey.isEmpty, !promptedRuns.contains(runKey) else { return promptedRuns }
        return Array((promptedRuns + [runKey]).suffix(memory))
    }
}

// MARK: - Pair streak

/// What the Today row shows once somebody else is standing with you: who, what
/// day, and a dot per person for today. Built from the room the listener
/// already holds, so it costs no network call.
public struct StandPairStreak: Equatable {

    public struct Dot: Equatable, Identifiable {
        public let uid: String
        public let initial: String
        public let colorIndex: Int
        public let spokeToday: Bool
        public let isViewer: Bool
        public var id: String { uid }
    }

    /// The most dots the row draws. Everyone past this is in the title count.
    public static let maxDots = 4

    /// "You and Maria" or "You and 3 others".
    public let title: String
    /// The viewer's day in this stand, 1...7. Today's day if they have not
    /// spoken yet, the day they just banked if they have.
    public let day: Int
    /// The viewer first, then everyone else in join order.
    public let dots: [Dot]
    public let everyoneSpokeToday: Bool
}

public extension StandRoom {

    /// Nil unless `viewer` is in this stand with at least one other person.
    /// A stand of one has not started (see `dayToRecord`), so it has no streak.
    func pairStreak(viewer: String, todayStamp: String) -> StandPairStreak? {
        guard let me = member(viewer) else { return nil }
        let others = activeMembers.filter { $0.uid != viewer }
        guard let first = others.first else { return nil }

        let title = others.count == 1
            ? "You and \(first.displayName)"
            : "You and \(others.count) others"

        let spoke = me.spoke(on: todayStamp)
        let day = spoke
            ? max(me.standDay, 1)
            : min(me.standDay + 1, Enforcement.length)

        let dots = ([me] + others)
            .prefix(StandPairStreak.maxDots)
            .map { m in
                StandPairStreak.Dot(uid: m.uid,
                                    initial: m.displayInitial,
                                    colorIndex: m.colorIndex,
                                    spokeToday: m.spoke(on: todayStamp),
                                    isViewer: m.uid == viewer)
            }

        let everyone = ([me] + others).allSatisfy { $0.spoke(on: todayStamp) }
        return StandPairStreak(title: title, day: day,
                               dots: Array(dots), everyoneSpokeToday: everyone)
    }
}
