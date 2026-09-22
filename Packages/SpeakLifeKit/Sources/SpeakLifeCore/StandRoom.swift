//
//  StandRoom.swift
//  SpeakLifeCore
//
//  A "stand" is one seven-day Enforcement run by 2-12 people at once.
//  Full design: docs/STAND_TOGETHER_SPEC.md.
//
//  THE INVARIANT THIS FILE EXISTS TO PROTECT (spec §2):
//
//      The room is a MIRROR of each member's local EnforcementProgress.
//      It is never the source of truth.
//
//  Nothing here can advance, reset or roll back a campaign. `EnforcementService`
//  remains the offline, lock-guarded owner of where someone actually is. Every
//  failure mode of the network therefore costs a dot on a week strip and never a
//  day of someone's week. Any change that makes the room authoritative
//  reintroduces all of them as data loss.
//
//  Foundation only — no Firebase. Firestore hands back `[String: Any]` with
//  `Timestamp` values that this module cannot name, so decoding takes an
//  injected date converter (see `StandRoom.init?`). That keeps the model, and
//  all the logic below, testable without a simulator or a network.
//

import Foundation

// MARK: - Status

public enum StandStatus: String, Codable, Equatable {
    case active
    case completed
    /// Nobody has spoken in a fortnight. Nudges stop; the room is kept, because
    /// campaigns wait rather than expire and that principle outlives the room.
    case dormant
    case archived

    /// Lenient, for the same reason `Enforcement` decodes its theme leniently:
    /// a status this build does not know must not take the whole room down.
    public init(lenient raw: String?) {
        self = StandStatus(rawValue: raw ?? "") ?? .active
    }
}

// MARK: - Member

public struct StandMember: Equatable, Identifiable {

    public let uid: String
    public let name: String
    public let initial: String
    /// 0...7, derived server-side from a hash of the uid so a person keeps the
    /// same colour in every room and on every device.
    public let colorIndex: Int
    /// 0...7. Mirrors this member's `EnforcementProgress.currentDay`.
    public let dayNumber: Int
    /// Local day stamps, at most 14. Display only — see `StandDayStamp`.
    public let daysSpoken: [String]
    public let joinedAt: Date?
    public let lastSpokeAt: Date?
    public let timeZoneIdentifier: String
    public let hasLeft: Bool
    public let isOwner: Bool

    public var id: String { uid }

    public init(uid: String, name: String, initial: String, colorIndex: Int,
                dayNumber: Int, daysSpoken: [String], joinedAt: Date?,
                lastSpokeAt: Date?, timeZoneIdentifier: String,
                hasLeft: Bool, isOwner: Bool) {
        self.uid = uid
        self.name = name
        self.initial = initial
        self.colorIndex = colorIndex
        self.dayNumber = dayNumber
        self.daysSpoken = daysSpoken
        self.joinedAt = joinedAt
        self.lastSpokeAt = lastSpokeAt
        self.timeZoneIdentifier = timeZoneIdentifier
        self.hasLeft = hasLeft
        self.isOwner = isOwner
    }

    public func spoke(on stamp: String) -> Bool {
        daysSpoken.contains(stamp)
    }

    public var hasFinished: Bool { dayNumber >= Enforcement.length }

    /// A member who joined and has never spoken. The UI shows them present but
    /// never marks them late — the feature does not shame anyone.
    public var hasStarted: Bool { dayNumber > 0 }

    /// Name for display. A member who left, or an archived room, has had the
    /// name cleared server-side; the row survives so the strip does not
    /// renumber around somebody who was there yesterday.
    public var displayName: String {
        name.isEmpty ? "Someone" : name
    }

    public var displayInitial: String {
        initial.isEmpty ? "•" : initial
    }
}

// MARK: - Room

public struct StandRoom: Equatable, Identifiable {

    /// Matches `MAX_MEMBERS` in functions/standTogether.js. The cap is what
    /// lets a room be one document and one snapshot listener rather than N+1
    /// reads, so raising it is a data-model change, not a constant change.
    public static let maxMembers = 12

    public let id: String
    public let status: StandStatus
    public let enforcement: Enforcement
    public let createdBy: String
    public let memberUids: [String]
    public let members: [String: StandMember]
    public let completedAt: Date?
    public let lastActivityAt: Date?

    public init(id: String, status: StandStatus, enforcement: Enforcement,
                createdBy: String, memberUids: [String],
                members: [String: StandMember], completedAt: Date?,
                lastActivityAt: Date?) {
        self.id = id
        self.status = status
        self.enforcement = enforcement
        self.createdBy = createdBy
        self.memberUids = memberUids
        self.members = members
        self.completedAt = completedAt
        self.lastActivityAt = lastActivityAt
    }

    // MARK: Roster

    /// Everyone still standing, ordered by when they joined so the roster does
    /// not reshuffle itself every time somebody speaks.
    public var activeMembers: [StandMember] {
        members.values
            .filter { !$0.hasLeft }
            .sorted {
                let l = $0.joinedAt ?? .distantPast
                let r = $1.joinedAt ?? .distantPast
                return l == r ? $0.uid < $1.uid : l < r
            }
    }

    public func member(_ uid: String) -> StandMember? {
        guard let m = members[uid], !m.hasLeft else { return nil }
        return m
    }

    public var isDuo: Bool { activeMembers.count == 2 }

    public var isFull: Bool { activeMembers.count >= Self.maxMembers }

    /// True once every active member has finished all seven days.
    public var everyoneFinished: Bool {
        let active = activeMembers
        return !active.isEmpty && active.allSatisfy(\.hasFinished)
    }

    // MARK: Today

    /// Everyone except `uid` who has spoken on `stamp`.
    ///
    /// The stamp is the caller's OWN local day. A room spanning time zones is
    /// read from each member's own calendar, so nobody is rendered as behind
    /// because of where they live.
    public func others(besides uid: String, whoSpokeOn stamp: String) -> [StandMember] {
        activeMembers.filter { $0.uid != uid && $0.spoke(on: stamp) }
    }

    public func hasSpokenToday(_ uid: String, stamp: String) -> Bool {
        member(uid)?.spoke(on: stamp) ?? false
    }

    /// The stand the campaign card's row should open, out of every stand this
    /// person is in.
    ///
    /// Ranked, because the row is one line and there can be several stands.
    /// A stand somebody is ACTUALLY IN outranks an empty one, whatever campaign
    /// it runs — that is the whole point of the row. Preferring the card's own
    /// campaign first meant an empty stand on this week hid a real stand with a
    /// friend in it on another week, which is the same "you are in a stand and
    /// cannot reach it" this row exists to fix.
    ///
    ///   3  this card's campaign, and somebody is in it
    ///   2  another campaign, and somebody is in it
    ///   1  this card's campaign, alone
    ///   0  another campaign, alone
    ///
    /// Ties break on most recent activity rather than on `rooms` order, which
    /// the listener does not promise — otherwise the row could flip between two
    /// stands between launches.
    public static func rowStand(in rooms: [StandRoom],
                                campaignId: String,
                                uid: String) -> StandRoom? {
        func rank(_ room: StandRoom) -> Int {
            let peopled = room.activeMembers.contains { $0.uid != uid }
            return (peopled ? 2 : 0) + (room.enforcement.id == campaignId ? 1 : 0)
        }
        return rooms
            .filter { $0.status == .active }
            .max { lhs, rhs in
                let l = rank(lhs), r = rank(rhs)
                if l != r { return l < r }
                return (lhs.lastActivityAt ?? .distantPast) < (rhs.lastActivityAt ?? .distantPast)
            }
    }

    /// The day to record for `uid` speaking on `todayStamp`, or nil when this
    /// stand should record nothing.
    ///
    /// Two rules, both learned from the room reading wrong.
    ///
    /// 1. THE NUMBER IS DAYS SPOKEN IN THIS STAND, never the caller's local
    ///    campaign day. `mirrorDay` used to write the local day straight in, so
    ///    somebody who joined a stand running the very week they were already
    ///    on ( `.sameCampaign`, which keeps their progress by design) appeared
    ///    at day 3 without having spoken a word in the room.
    ///
    /// 2. THE WEEK STARTS WHEN THE STAND DOES. A stand of one is somebody
    ///    waiting on an invite, not day 1 of anything, so nothing counts until
    ///    a second person is standing with them. That is what lets both members
    ///    read Day 1 on the same day instead of the invitee starting a week
    ///    behind the person who sent the link.
    ///
    /// The count comes from `daysSpoken` rather than from `dayNumber`, so a
    /// stale cached room self-corrects on the next day rather than compounding:
    /// the stamps are the record, the number is a readout of them.
    public func dayToRecord(for uid: String, todayStamp: String) -> Int? {
        guard status == .active,
              activeMembers.count > 1,
              let me = member(uid),
              !me.spoke(on: todayStamp) else { return nil }
        return min(me.daysSpoken.count + 1, Enforcement.length)
    }

    /// The day this room is missing for `uid`, given what their own device
    /// already banked today. Nil when there is nothing to repair.
    ///
    /// This exists because the mirror write is a single fire-and-forget attempt
    /// made inside the burst-completion call stack, and every way that instant
    /// can miss is silent and permanent:
    ///
    /// - the room listener had not delivered this room yet, so the write loop
    ///   had nothing to iterate and returned;
    /// - the local day was already banked before the stand was joined, so
    ///   `advanceIfNeeded` answered `.alreadyAdvancedToday` and the mirror was
    ///   never called at all;
    /// - the write was queued offline and the app died before it flushed.
    ///
    /// In all three the speaker's own progress says they spoke today and the
    /// room disagrees, with nothing in the system that would ever notice. This
    /// turns that disagreement into something a caller can act on every time a
    /// room arrives, which is what makes the mirror eventually consistent
    /// rather than one-shot.
    ///
    /// `spokeTodayLocally` is the caller's `EnforcementProgress.hasAdvancedToday`
    /// — LOCAL truth, deliberately. The room is still only ever a mirror of it
    /// (spec §2); this re-asserts local into the room and never the reverse.
    public func dayToBackfill(for uid: String,
                              todayStamp: String,
                              spokeTodayLocally: Bool) -> Int? {
        guard spokeTodayLocally else { return nil }
        return dayToRecord(for: uid, todayStamp: todayStamp)
    }

    /// The line under the room title: who has spoken today.
    ///
    /// Deliberately never phrased as who has NOT. The room reports presence,
    /// not absence — that is the difference between accountability and a
    /// scoreboard, and it is the reason there is no "behind" state anywhere in
    /// this model.
    public func presenceSummary(todayStamp: String) -> String {
        let active = activeMembers
        guard !active.isEmpty else { return "" }
        // A stand of one has not started. Its seven days begin when somebody
        // else is standing too (`dayToRecord`), so reporting on today would be
        // reporting on a week that is not running — and an owner who had just
        // spoken read "Nobody has spoken yet today."
        guard active.count > 1 else { return "Waiting for someone to join." }
        let spoken = active.filter { $0.spoke(on: todayStamp) }
        if spoken.isEmpty { return "Nobody has spoken yet today." }
        if spoken.count == active.count { return "Everyone has spoken today." }
        if active.count == 2, let one = spoken.first {
            return "\(one.displayName) spoke today."
        }
        return "\(spoken.count) of \(active.count) have spoken today."
    }

    // MARK: Decoding

    /// Builds a room from the raw Firestore document.
    ///
    /// `date` converts whatever the store hands back for a timestamp into a
    /// `Date`. The app target passes a closure that knows about
    /// `FirebaseFirestore.Timestamp`; tests pass one that handles `Date`. That
    /// injection is the whole reason this type can live in a Foundation-only
    /// module and still be exercised without a simulator.
    ///
    /// Returns nil only when the document could not be a room at all. Anything
    /// recoverable degrades instead of failing: a room is other people's
    /// content, arriving from other people's devices and other app versions,
    /// and dropping the whole thing because one field is unfamiliar is the
    /// wrong trade.
    public init?(id: String, data: [String: Any], date: (Any?) -> Date?) {
        guard let rawEnforcement = data["enforcement"] as? [String: Any],
              let enforcement = StandRoom.decodeEnforcement(rawEnforcement) else { return nil }

        self.id = id
        self.enforcement = enforcement
        self.status = StandStatus(lenient: data["status"] as? String)
        self.createdBy = data["createdBy"] as? String ?? ""
        self.memberUids = data["memberUids"] as? [String] ?? []
        self.completedAt = date(data["completedAt"])
        self.lastActivityAt = date(data["lastActivityAt"])

        var built: [String: StandMember] = [:]
        for (uid, raw) in (data["members"] as? [String: Any] ?? [:]) {
            guard let m = raw as? [String: Any] else { continue }
            let name = m["name"] as? String ?? ""
            built[uid] = StandMember(
                uid: uid,
                name: name,
                initial: m["initial"] as? String ?? String(name.prefix(1)).uppercased(),
                colorIndex: (m["colorIndex"] as? Int) ?? 0,
                // Clamped rather than trusted. This number indexes a fixed set
                // of day slots in the UI and arrives from another device.
                dayNumber: min(max((m["dayNumber"] as? Int) ?? 0, 0), Enforcement.length),
                daysSpoken: (m["daysSpoken"] as? [String] ?? []).filter(StandDayStamp.isWellFormed),
                joinedAt: date(m["joinedAt"]),
                lastSpokeAt: date(m["lastSpokeAt"]),
                timeZoneIdentifier: m["tz"] as? String ?? "UTC",
                hasLeft: (m["left"] as? Bool) ?? false,
                isOwner: (m["isOwner"] as? Bool) ?? false
            )
        }
        self.members = built
    }

    /// Round-trips the campaign dictionary through `Enforcement`'s own decoder
    /// so its lenient theme handling applies here too: a room built on a theme
    /// this build has never heard of degrades to `.faith` rather than making
    /// the whole room undecodable on an older app version.
    public static func decodeEnforcement(_ raw: [String: Any]) -> Enforcement? {
        guard JSONSerialization.isValidJSONObject(raw),
              let data = try? JSONSerialization.data(withJSONObject: raw) else { return nil }
        return try? JSONDecoder().decode(Enforcement.self, from: data)
    }
}

// MARK: - Join conflict resolution

/// What joining a stand would do to the campaign the user is already running.
///
/// Pure, and separated from any UI, because getting this wrong silently
/// destroys someone's week: `EnforcementService.begin` clears
/// `completedDayNumbers`, `startedOn` and `lastAdvancedOn`. Every path that
/// reaches it must be one the user explicitly agreed to.
public enum StandJoinConflict: Equatable {

    /// No active campaign. Join and start the room's.
    case clear

    /// Already running this exact campaign. Adopt the room and KEEP existing
    /// progress — do not call `begin`, which would reset it to day 1.
    case sameCampaign

    /// A different campaign, barely begun. Confirm, then replace.
    case replaceEarly(current: Enforcement, day: Int)

    /// A different campaign, three days or more in. Offer to finish it first
    /// and join at day 0, because silently discarding half a week someone
    /// actually held is not a trade the app gets to make for them.
    case replaceLate(current: Enforcement, day: Int)

    /// A finished campaign whose celebration has not been shown. Let that land
    /// first — `justCompleted` is persisted precisely so it survives a kill,
    /// and stepping on it swallows the one celebration they earned.
    case awaitingCelebration
}

public enum StandJoinResolver {

    /// Day 3 is the line. Two days is a false start; three is a week someone is
    /// holding on to.
    public static let lateThreshold = 3

    public static func resolve(roomEnforcementId: String,
                               progress: EnforcementProgress,
                               active: Enforcement?,
                               hasUnseenCelebration: Bool) -> StandJoinConflict {
        if hasUnseenCelebration { return .awaitingCelebration }
        guard progress.isActive, let active else { return .clear }
        if active.id == roomEnforcementId { return .sameCampaign }
        let day = progress.currentDay
        return day >= lateThreshold
            ? .replaceLate(current: active, day: day)
            : .replaceEarly(current: active, day: day)
    }
}
