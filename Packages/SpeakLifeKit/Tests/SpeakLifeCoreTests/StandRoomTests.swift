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

    /// Mirrors the real catalog entry: enforcements.json ships id "peace" with
    /// theme "anxiety". There is no `.peace` category — an earlier version of
    /// this fixture invented one.
    ///
    /// Using a valid theme that is NOT `.faith` is also what gives the
    /// lenient-decoding test below any meaning: with `.faith` as the fixture it
    /// would pass whether the fallback worked or not.
    private func enforcementDict(id: String = "peace",
                                 theme: String = "anxiety") -> [String: Any] {
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
                    theme: .anxiety,
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

    // MARK: - What a stand records
    //
    // The room read wrong in two different ways, and both land here.
    //
    // Stamps must be well formed. `StandRoom`'s decoder filters `daysSpoken`
    // through `StandDayStamp.isWellFormed`, so a made-up fixture like "d1" is
    // silently dropped and every member arrives having spoken nothing — which
    // is exactly how the first version of these tests failed.

    /// Day stamps that survive decoding, in order.
    private func stamps(_ n: Int) -> [String] {
        (1...max(n, 1)).prefix(n).map { String(format: "2026-09-%02d", $0) }
    }

    /// The number is days spoken IN THIS STAND. `mirrorDay` used to write the
    /// caller's local campaign day straight in, so somebody who joined a stand
    /// running the very week they were already on — `.sameCampaign`, which
    /// keeps their progress by design — showed up at day 3 next to the owner's
    /// day 5 without having spoken once in the room.
    func testDayToRecord_CountsDaysSpokenInTheStandNotTheLocalCampaign() {
        let r = room(roomDict(members: [
            "owner": memberDict(name: "Ann", day: 5, spoken: stamps(5), owner: true),
            "king": memberDict(name: "King", day: 3, spoken: [], owner: false),
        ]))
        // Joined mid-week, has spoken nothing here: their first day is day 1,
        // whatever their own campaign says.
        XCTAssertEqual(r?.dayToRecord(for: "king", todayStamp: "2026-09-06"), 1)
        XCTAssertEqual(r?.dayToRecord(for: "owner", todayStamp: "2026-09-06"), 6)
    }

    /// The shared week starts when the stand does. A stand of one is somebody
    /// waiting on an invite, not day 1 of anything — holding at zero is what
    /// lets both members read Day 1 on the same day.
    func testDayToRecord_RecordsNothingUntilSomebodyElseIsStanding() {
        let alone = room(roomDict(members: [
            "owner": memberDict(name: "Ann", day: 0, spoken: [], owner: true),
        ]))
        XCTAssertNil(alone?.dayToRecord(for: "owner", todayStamp: "2026-09-01"))

        let joined = room(roomDict(members: [
            "owner": memberDict(name: "Ann", day: 0, spoken: [], owner: true),
            "king": memberDict(name: "King", day: 0, spoken: [], owner: false),
        ]))
        XCTAssertEqual(joined?.dayToRecord(for: "owner", todayStamp: "2026-09-01"), 1)
        XCTAssertEqual(joined?.dayToRecord(for: "king", todayStamp: "2026-09-01"), 1)
    }

    /// A member who left does not make it a stand of two.
    func testDayToRecord_IgnoresMembersWhoLeft() {
        let r = room(roomDict(members: [
            "owner": memberDict(name: "Ann", day: 2, spoken: stamps(2), owner: true),
            "gone": memberDict(name: "Gone", day: 1, spoken: stamps(1), left: true),
        ]))
        XCTAssertNil(r?.dayToRecord(for: "owner", todayStamp: "2026-09-03"))
    }

    /// The burst can complete more than once in a day.
    func testDayToRecord_IsIdempotentWithinADay() {
        let r = room(roomDict(members: [
            "owner": memberDict(name: "Ann", day: 2, spoken: stamps(2), owner: true),
            "king": memberDict(name: "King", day: 2, spoken: stamps(2), owner: false),
        ]))
        XCTAssertNil(r?.dayToRecord(for: "owner", todayStamp: "2026-09-02"))
        XCTAssertEqual(r?.dayToRecord(for: "owner", todayStamp: "2026-09-03"), 3)
    }

    /// Seven days is the whole campaign. A stale cache must not push anyone
    /// past the end of one.
    func testDayToRecord_NeverExceedsTheCampaignLength() {
        let r = room(roomDict(members: [
            "owner": memberDict(name: "Ann", day: Enforcement.length,
                                spoken: stamps(Enforcement.length), owner: true),
            "king": memberDict(name: "King", day: 1, spoken: stamps(1), owner: false),
        ]))
        XCTAssertEqual(r?.dayToRecord(for: "owner", todayStamp: "2026-09-08"),
                       Enforcement.length)
    }

    /// A finished or dormant stand records nothing.
    func testDayToRecord_RecordsNothingOnAStandThatIsNotActive() {
        let r = room(roomDict(members: [
            "owner": memberDict(name: "Ann", day: 7, spoken: stamps(1), owner: true),
            "king": memberDict(name: "King", day: 7, spoken: stamps(1), owner: false),
        ], status: "completed"))
        XCTAssertNil(r?.dayToRecord(for: "owner", todayStamp: "2026-09-02"))
    }

    /// Somebody who is not in this stand.
    func testDayToRecord_RecordsNothingForANonMember() {
        let r = room(roomDict(members: [
            "owner": memberDict(name: "Ann", day: 1, spoken: stamps(1), owner: true),
            "king": memberDict(name: "King", day: 1, spoken: stamps(1), owner: false),
        ]))
        XCTAssertNil(r?.dayToRecord(for: "stranger", todayStamp: "2026-09-02"))
    }

    /// A stand of one reports waiting, not silence. An owner who had just
    /// spoken was reading "Nobody has spoken yet today."
    func testPresenceOnAStandOfOneReportsWaiting() {
        let r = room(roomDict(members: [
            "owner": memberDict(name: "Ann", day: 0, spoken: stamps(1), owner: true),
        ]))
        XCTAssertEqual(r?.presenceSummary(todayStamp: "2026-09-01"),
                       "Waiting for someone to join.")
    }

    // MARK: - Which stand the card row opens

    /// Reported from the device: the card read "Your stand is ready / Nobody
    /// else yet" while a friend was standing in another of this person's
    /// stands. An empty stand on THIS card's campaign was outranking a real one
    /// on another campaign, which is the same hole the fallback was added to
    /// close.
    func testRowStand_PrefersAStandSomebodyIsActuallyInOverAnEmptyOne() throws {
        let emptyOnThisCampaign = try XCTUnwrap(room(roomDict(members: [
            "me": memberDict(name: "Me", day: 0, spoken: [], owner: true),
        ])))
        let peopledOnAnother = try XCTUnwrap(StandRoom(
            id: "r2",
            data: roomDict(members: [
                "me": memberDict(name: "Me", day: 1, spoken: stamps(1), owner: true),
                "king": memberDict(name: "King", day: 1, spoken: stamps(1)),
            ]).merging(["enforcement": enforcementDict(id: "healing")]) { _, new in new },
            date: passthroughDate))

        let picked = StandRoom.rowStand(in: [emptyOnThisCampaign, peopledOnAnother],
                                        campaignId: "peace", uid: "me")
        XCTAssertEqual(picked?.id, "r2",
                       "a stand with somebody in it beats an empty one on this week")
    }

    /// With people in both, this card's own campaign is the right one to show.
    func testRowStand_PrefersThisCampaignWhenBothHavePeople() throws {
        let thisCampaign = try XCTUnwrap(room(roomDict(members: [
            "me": memberDict(name: "Me", day: 1, spoken: stamps(1), owner: true),
            "ann": memberDict(name: "Ann", day: 1, spoken: stamps(1)),
        ])))
        let other = try XCTUnwrap(StandRoom(
            id: "r2",
            data: roomDict(members: [
                "me": memberDict(name: "Me", day: 1, spoken: stamps(1), owner: true),
                "king": memberDict(name: "King", day: 1, spoken: stamps(1)),
            ]).merging(["enforcement": enforcementDict(id: "healing")]) { _, new in new },
            date: passthroughDate))

        XCTAssertEqual(StandRoom.rowStand(in: [other, thisCampaign],
                                          campaignId: "peace", uid: "me")?.id, "r1")
    }

    /// Alone in both: this card's campaign is still the better row.
    func testRowStand_FallsBackToThisCampaignWhenAlone() throws {
        let thisCampaign = try XCTUnwrap(room(roomDict(members: [
            "me": memberDict(name: "Me", day: 0, spoken: [], owner: true),
        ])))
        let other = try XCTUnwrap(StandRoom(
            id: "r2",
            data: roomDict(members: [
                "me": memberDict(name: "Me", day: 0, spoken: [], owner: true),
            ]).merging(["enforcement": enforcementDict(id: "healing")]) { _, new in new },
            date: passthroughDate))

        XCTAssertEqual(StandRoom.rowStand(in: [other, thisCampaign],
                                          campaignId: "peace", uid: "me")?.id, "r1")
    }

    /// A finished stand is not what the row opens.
    func testRowStand_IgnoresStandsThatAreNotActive() throws {
        let done = try XCTUnwrap(room(roomDict(members: [
            "me": memberDict(name: "Me", day: 7, spoken: stamps(7), owner: true),
            "king": memberDict(name: "King", day: 7, spoken: stamps(7)),
        ], status: "completed")))
        XCTAssertNil(StandRoom.rowStand(in: [done], campaignId: "peace", uid: "me"))
        XCTAssertNil(StandRoom.rowStand(in: [], campaignId: "peace", uid: "me"))
    }

    /// A member who left does not make a stand peopled.
    func testRowStand_DoesNotCountAMemberWhoLeftAsCompany() throws {
        let abandoned = try XCTUnwrap(room(roomDict(members: [
            "me": memberDict(name: "Me", day: 1, spoken: stamps(1), owner: true),
            "gone": memberDict(name: "Gone", day: 1, spoken: stamps(1), left: true),
        ])))
        let peopled = try XCTUnwrap(StandRoom(
            id: "r2",
            data: roomDict(members: [
                "me": memberDict(name: "Me", day: 1, spoken: stamps(1), owner: true),
                "king": memberDict(name: "King", day: 1, spoken: stamps(1)),
            ]).merging(["enforcement": enforcementDict(id: "healing")]) { _, new in new },
            date: passthroughDate))

        XCTAssertEqual(StandRoom.rowStand(in: [abandoned, peopled],
                                          campaignId: "peace", uid: "me")?.id, "r2")
    }
}
