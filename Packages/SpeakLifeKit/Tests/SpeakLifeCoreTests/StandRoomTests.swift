//
//  StandRoomTests.swift
//  SpeakLifeCoreTests
//
//  Two things carry real risk here and are covered hardest:
//
//    1. Decoding. A room is OTHER PEOPLE'S content, arriving from other
//       people's devices and other app versions. It must degrade rather than
//       fail, and must never trust a number it is handed.
//
//    2. Join conflict resolution. EnforcementService.begin clears
//       completedDayNumbers, startedOn and lastAdvancedOn — so a wrong answer
//       here silently destroys a week someone actually held.
//

import XCTest
@testable import SpeakLifeCore

final class StandRoomTests: XCTestCase {

    // MARK: - Fixtures

    /// The date converter the app target supplies for Firestore `Timestamp`.
    /// Tests only ever put `Date`s in, so this is the identity case.
    private let passthroughDate: (Any?) -> Date? = { $0 as? Date }

    private func enforcementDict(id: String = "peace",
                                 theme: String = "peace") -> [String: Any] {
        [
            "id": id, "title": "Enforcing Peace", "tagline": "Seven days.",
            "theme": theme,
            "days": (1...Enforcement.length).map { n in
                [
                    "dayNumber": n,
                    "anchorText": "Day \(n) anchor.",
                    "anchorVerse": "You will keep in perfect peace.",
                    "anchorBook": "Isaiah 26:3",
                    "anchorTranslation": "NIV",
                    "audioId": "a\(n)", "audioTitle": "Peace", "audioMinutes": 10,
                ] as [String: Any]
            },
        ]
    }

    private func memberDict(name: String, day: Int, spoken: [String],
                            joined: Date = Date(timeIntervalSince1970: 0),
                            left: Bool = false, owner: Bool = false) -> [String: Any] {
        [
            "name": name, "initial": String(name.prefix(1)), "colorIndex": 2,
            "dayNumber": day, "daysSpoken": spoken, "joinedAt": joined,
            "lastSpokeAt": Date(timeIntervalSince1970: 100),
            "tz": "America/New_York", "left": left, "isOwner": owner,
        ]
    }

    private func roomDict(members: [String: Any],
                          status: String = "active") -> [String: Any] {
        [
            "id": "r1", "status": status, "createdBy": "owner",
            "enforcement": enforcementDict(),
            "memberUids": Array(members.keys),
            "members": members,
            "lastActivityAt": Date(timeIntervalSince1970: 200),
        ]
    }

    private func room(_ data: [String: Any]) -> StandRoom? {
        StandRoom(id: "r1", data: data, date: passthroughDate)
    }

    private func enforcement(_ id: String) -> Enforcement {
        Enforcement(id: id, title: "Enforcing \(id)", tagline: "t",
                    theme: .peace,
                    days: (1...Enforcement.length).map {
                        EnforcementDay(dayNumber: $0, anchorText: "a", anchorVerse: "v",
                                       anchorBook: "B 1:1", anchorTranslation: "NIV",
                                       audioId: "x", audioTitle: "t", audioMinutes: 1)
                    })
    }

    // MARK: - Decoding

    func testDecodesARoom() throws {
        let r = try XCTUnwrap(room(roomDict(members: [
            "owner": memberDict(name: "Sarah", day: 3, spoken: ["2026-09-15"], owner: true),
            "mom": memberDict(name: "Mom", day: 1, spoken: []),
        ])))

        XCTAssertEqual(r.status, .active)
        XCTAssertEqual(r.enforcement.id, "peace")
        XCTAssertEqual(r.activeMembers.count, 2)
        XCTAssertEqual(r.member("owner")?.dayNumber, 3)
        XCTAssertTrue(r.member("owner")?.isOwner == true)
        XCTAssertTrue(r.isDuo)
    }

    func testMissingCampaignIsTheOnlyFatalCase() {
        var data = roomDict(members: ["a": memberDict(name: "A", day: 1, spoken: [])])
        data["enforcement"] = nil
        XCTAssertNil(room(data), "a room without a campaign is not a room")
    }

    func testUnknownThemeDegradesRatherThanDroppingTheRoom() throws {
        // Mirrors Enforcement's own lenient decoding. An older build must still
        // be able to open a room built on a category it has never heard of.
        var data = roomDict(members: ["a": memberDict(name: "A", day: 1, spoken: [])])
        data["enforcement"] = enforcementDict(theme: "a_theme_from_the_future")
        let r = try XCTUnwrap(room(data))
        XCTAssertEqual(r.enforcement.theme, .faith)
    }

    func testUnknownStatusDegradesToActive() throws {
        let r = try XCTUnwrap(room(roomDict(
            members: ["a": memberDict(name: "A", day: 1, spoken: [])],
            status: "some_future_status")))
        XCTAssertEqual(r.status, .active)
    }

    func testDayNumberFromAnotherDeviceIsClamped() throws {
        // This number indexes a fixed set of day slots in the UI and arrives
        // from somebody else's device. Trusting it is a crash.
        let r = try XCTUnwrap(room(roomDict(members: [
            "high": memberDict(name: "H", day: 99, spoken: []),
            "low": memberDict(name: "L", day: -5, spoken: []),
        ])))
        XCTAssertEqual(r.member("high")?.dayNumber, Enforcement.length)
        XCTAssertEqual(r.member("low")?.dayNumber, 0)
    }

    func testMalformedDayStampsAreDropped() throws {
        let r = try XCTUnwrap(room(roomDict(members: [
            "a": memberDict(name: "A", day: 1,
                            spoken: ["2026-09-15", "not-a-date", "", "2026-9-1"]),
        ])))
        XCTAssertEqual(r.member("a")?.daysSpoken, ["2026-09-15"])
    }

    func testMissingOptionalFieldsFallBack() throws {
        let r = try XCTUnwrap(room(roomDict(members: [
            "a": ["name": "Amy"],   // everything else absent
        ])))
        let m = try XCTUnwrap(r.member("a"))
        XCTAssertEqual(m.dayNumber, 0)
        XCTAssertEqual(m.daysSpoken, [])
        XCTAssertEqual(m.initial, "A", "an absent initial is derived from the name")
        XCTAssertEqual(m.timeZoneIdentifier, "UTC")
        XCTAssertFalse(m.hasLeft)
        XCTAssertFalse(m.isOwner)
    }

    func testAClearedNameStillRenders() throws {
        // leaveStand wipes the name but keeps the row, so the remaining members'
        // strip does not renumber around somebody who was there yesterday.
        let r = try XCTUnwrap(room(roomDict(members: [
            "a": memberDict(name: "A", day: 1, spoken: []),
            "gone": memberDict(name: "", day: 4, spoken: [], left: true),
        ])))
        XCTAssertNil(r.member("gone"), "a departed member is not in the roster")
        XCTAssertEqual(r.members["gone"]?.displayName, "Someone")
        XCTAssertEqual(r.members["gone"]?.displayInitial, "•")
    }

    // MARK: - Roster

    func testRosterIsStableAndOrderedByJoin() throws {
        let r = try XCTUnwrap(room(roomDict(members: [
            "third": memberDict(name: "C", day: 0, spoken: [], joined: Date(timeIntervalSince1970: 300)),
            "first": memberDict(name: "A", day: 0, spoken: [], joined: Date(timeIntervalSince1970: 100)),
            "second": memberDict(name: "B", day: 0, spoken: [], joined: Date(timeIntervalSince1970: 200)),
        ])))
        XCTAssertEqual(r.activeMembers.map(\.uid), ["first", "second", "third"],
                       "the roster must not reshuffle every time somebody speaks")
    }

    func testDepartedMembersAreExcludedFromTheRoster() throws {
        let r = try XCTUnwrap(room(roomDict(members: [
            "a": memberDict(name: "A", day: 1, spoken: []),
            "b": memberDict(name: "B", day: 1, spoken: [], left: true),
        ])))
        XCTAssertEqual(r.activeMembers.map(\.uid), ["a"])
        XCTAssertFalse(r.isDuo)
    }

    func testEveryoneFinished() throws {
        let done = try XCTUnwrap(room(roomDict(members: [
            "a": memberDict(name: "A", day: 7, spoken: []),
            "b": memberDict(name: "B", day: 7, spoken: []),
        ])))
        XCTAssertTrue(done.everyoneFinished)

        let partial = try XCTUnwrap(room(roomDict(members: [
            "a": memberDict(name: "A", day: 7, spoken: []),
            "b": memberDict(name: "B", day: 6, spoken: []),
        ])))
        XCTAssertFalse(partial.everyoneFinished)
    }

    func testADepartedMemberDoesNotHoldUpCompletion() throws {
        let r = try XCTUnwrap(room(roomDict(members: [
            "a": memberDict(name: "A", day: 7, spoken: []),
            "gone": memberDict(name: "", day: 2, spoken: [], left: true),
        ])))
        XCTAssertTrue(r.everyoneFinished)
    }

    // MARK: - Presence

    func testPresenceReportsWhoHasSpokenNeverWhoHasNot() throws {
        let today = "2026-09-15"
        let duo = try XCTUnwrap(room(roomDict(members: [
            "a": memberDict(name: "Sarah", day: 3, spoken: [today]),
            "b": memberDict(name: "Mom", day: 2, spoken: []),
        ])))
        XCTAssertEqual(duo.presenceSummary(todayStamp: today), "Sarah spoke today.")

        let group = try XCTUnwrap(room(roomDict(members: [
            "a": memberDict(name: "A", day: 1, spoken: [today]),
            "b": memberDict(name: "B", day: 1, spoken: [today]),
            "c": memberDict(name: "C", day: 1, spoken: []),
        ])))
        XCTAssertEqual(group.presenceSummary(todayStamp: today), "2 of 3 have spoken today.")

        let silent = try XCTUnwrap(room(roomDict(members: [
            "a": memberDict(name: "A", day: 1, spoken: []),
            "b": memberDict(name: "B", day: 1, spoken: []),
        ])))
        XCTAssertEqual(silent.presenceSummary(todayStamp: today), "Nobody has spoken yet today.")

        let all = try XCTUnwrap(room(roomDict(members: [
            "a": memberDict(name: "A", day: 1, spoken: [today]),
            "b": memberDict(name: "B", day: 1, spoken: [today]),
        ])))
        XCTAssertEqual(all.presenceSummary(todayStamp: today), "Everyone has spoken today.")
    }

    func testOthersWhoSpokeExcludesSelfAndDeparted() throws {
        let today = "2026-09-15"
        let r = try XCTUnwrap(room(roomDict(members: [
            "me": memberDict(name: "Me", day: 1, spoken: [today]),
            "them": memberDict(name: "Them", day: 1, spoken: [today]),
            "gone": memberDict(name: "", day: 1, spoken: [today], left: true),
        ])))
        XCTAssertEqual(r.others(besides: "me", whoSpokeOn: today).map(\.uid), ["them"])
        XCTAssertTrue(r.hasSpokenToday("me", stamp: today))
        XCTAssertFalse(r.hasSpokenToday("me", stamp: "2026-09-14"))
    }

    // MARK: - Join conflict

    private func progress(active id: String?, completedDays: Int) -> EnforcementProgress {
        // `Set(1...completedDays)` traps when completedDays is 0 — a closed
        // range requires lowerBound <= upperBound, so `1...0` is a fatal error,
        // not an empty set. Day 0 is a real case (a member who joined and has
        // not spoken), so build it with a stride instead.
        let days = Set(stride(from: 1, through: max(completedDays, 0), by: 1))
        return EnforcementProgress(
            activeEnforcementId: id,
            assembledEnforcement: nil,
            startedOn: id == nil ? nil : Date(),
            completedDayNumbers: days,
            lastAdvancedOn: nil,
            completedEnforcementIds: []
        )
    }

    func testNoActiveCampaignJoinsCleanly() {
        let result = StandJoinResolver.resolve(
            roomEnforcementId: "peace",
            progress: EnforcementProgress(),
            active: nil,
            hasUnseenCelebration: false)
        XCTAssertEqual(result, .clear)
    }

    func testSameCampaignAdoptsRatherThanResetting() {
        // The important one. Returning anything else here routes to begin(),
        // which would reset a member to day 1 for joining a stand running the
        // very campaign they are already on.
        let result = StandJoinResolver.resolve(
            roomEnforcementId: "peace",
            progress: progress(active: "peace", completedDays: 4),
            active: enforcement("peace"),
            hasUnseenCelebration: false)
        XCTAssertEqual(result, .sameCampaign)
    }

    func testADifferentCampaignBarelyBegunOffersReplacement() {
        let current = enforcement("healing")
        let result = StandJoinResolver.resolve(
            roomEnforcementId: "peace",
            progress: progress(active: "healing", completedDays: 1),
            active: current,
            hasUnseenCelebration: false)
        XCTAssertEqual(result, .replaceEarly(current: current, day: 2))
    }

    func testThreeDaysInIsTreatedAsAWeekWorthKeeping() {
        let current = enforcement("healing")
        let result = StandJoinResolver.resolve(
            roomEnforcementId: "peace",
            progress: progress(active: "healing", completedDays: 2),
            active: current,
            hasUnseenCelebration: false)
        XCTAssertEqual(result, .replaceLate(current: current, day: 3))
    }

    func testAnUnseenCelebrationWinsOverEverything() {
        let result = StandJoinResolver.resolve(
            roomEnforcementId: "peace",
            progress: progress(active: "healing", completedDays: 6),
            active: enforcement("healing"),
            hasUnseenCelebration: true)
        XCTAssertEqual(result, .awaitingCelebration,
                       "the one celebration they earned must not be swallowed")
    }
}
