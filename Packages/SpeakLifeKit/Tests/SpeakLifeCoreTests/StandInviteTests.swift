//
//  StandInviteTests.swift
//  SpeakLifeCoreTests
//
//  The invite loop's pure rules: the copy's grammar for every theme, the day-1
//  ask firing once per run (and on every new run), and the pair streak the
//  Today row draws from a room it already holds.
//

import XCTest
@testable import SpeakLifeCore

final class StandInviteTests: XCTestCase {

    // MARK: - Copy

    func testFirstPersonLowercasesButKeepsGod() {
        XCTAssertEqual(StandInviteCopy.firstPerson(.anxiety), "peace")
        XCTAssertEqual(StandInviteCopy.firstPerson(.marriage), "my marriage")
        XCTAssertEqual(StandInviteCopy.firstPerson(.fertility), "God's promise")
        XCTAssertEqual(StandInviteCopy.firstPerson(.spiritualGrowth), "my walk with God")
        XCTAssertEqual(StandInviteCopy.firstPerson(.mentalHealth), "a sound mind")
    }

    func testSecondPersonSwapsThePossessive() {
        XCTAssertEqual(StandInviteCopy.secondPerson(.marriage), "your marriage")
        XCTAssertEqual(StandInviteCopy.secondPerson(.newSeason), "your new season")
        XCTAssertEqual(StandInviteCopy.secondPerson(.health), "healing")
    }

    /// Every theme must produce a usable, dash-free phrase in both voices.
    func testEveryThemeProducesAPlainPhrase() {
        for theme in DeclarationCategory.allCases {
            for phrase in [StandInviteCopy.firstPerson(theme), StandInviteCopy.secondPerson(theme)] {
                XCTAssertFalse(phrase.isEmpty, "\(theme)")
                XCTAssertFalse(phrase.contains("\u{2014}") || phrase.contains("\u{2013}"), "\(theme)")
            }
            XCTAssertFalse(StandInviteCopy.secondPerson(theme).hasPrefix("my "),
                           "second person kept 'my' for \(theme)")
        }
    }

    // MARK: - Typed code

    func testTypingFormatsAsYouGo() {
        XCTAssertEqual(StandCodeInput.display(""), "")
        XCTAssertEqual(StandCodeInput.display("ab"), "AB")
        XCTAssertEqual(StandCodeInput.display("abcd"), "ABCD")
        XCTAssertEqual(StandCodeInput.display("abcd2"), "ABCD-2")
        // Backspacing over the dash drops it rather than trapping the cursor.
        XCTAssertEqual(StandCodeInput.display("ABCD-"), "ABCD")
        XCTAssertEqual(StandCodeInput.display("ABCD-2345"), "ABCD-2345")
    }

    func testPasteWithOrWithoutDashOrSpaces() {
        XCTAssertEqual(StandCodeInput.display("ABCD2345"), "ABCD-2345")
        XCTAssertEqual(StandCodeInput.display("abcd-2345"), "ABCD-2345")
        XCTAssertEqual(StandCodeInput.display(" abcd 2345 "), "ABCD-2345")
        XCTAssertEqual(StandCodeInput.display("ABCD-2345-XYZ"), "ABCD-2345")
    }

    func testPasteTheLink() {
        XCTAssertEqual(StandCodeInput.display("https://speaklife.app.link/stand/ABCD2345"), "ABCD-2345")
        XCTAssertEqual(StandCodeInput.display("speaklife://stand/abcd2345"), "ABCD-2345")
        XCTAssertEqual(StandCodeInput.display("https://go.speaklife.app/x?stand=ABCD2345"), "ABCD-2345")
    }

    func testPasteTheWholeMessage() {
        let message = "Will you stand with me this week?\n\nhttps://speaklife.app.link/stand/WXYZ6789\n\nLink won't open? Use code WXYZ-6789 in SpeakLife."
        XCTAssertEqual(StandCodeInput.display(message), "WXYZ-6789")
        XCTAssertEqual(StandCodeInput.display("Use code WXYZ-6789 in SpeakLife."), "WXYZ-6789")
    }

    // MARK: - Day-1 ask

    func testAsksOnDayOneOfANewRun() {
        XCTAssertTrue(StandInvitePromptRule.shouldPrompt(runKey: "peace|100",
                                                         completedDays: 1,
                                                         promptedRuns: []))
    }

    func testNeverAsksTwiceForTheSameRun() {
        let asked = StandInvitePromptRule.recording("peace|100", in: [])
        for day in 1...7 {
            XCTAssertFalse(StandInvitePromptRule.shouldPrompt(runKey: "peace|100",
                                                              completedDays: day,
                                                              promptedRuns: asked))
        }
    }

    /// The old lifetime budget stopped asking after the first campaign. Every
    /// new run, including a second run of the same campaign, gets its ask.
    func testEveryNewRunIsAskedEvenAfterManyRuns() {
        var asked: [String] = []
        for n in 0..<10 {
            let key = "peace|\(n)"
            XCTAssertTrue(StandInvitePromptRule.shouldPrompt(runKey: key,
                                                             completedDays: 1,
                                                             promptedRuns: asked))
            asked = StandInvitePromptRule.recording(key, in: asked)
        }
    }

    func testFallsBackToDaysTwoAndThreeOnly() {
        XCTAssertFalse(StandInvitePromptRule.shouldPrompt(runKey: "r", completedDays: 0, promptedRuns: []))
        XCTAssertTrue(StandInvitePromptRule.shouldPrompt(runKey: "r", completedDays: 2, promptedRuns: []))
        XCTAssertTrue(StandInvitePromptRule.shouldPrompt(runKey: "r", completedDays: 3, promptedRuns: []))
        XCTAssertFalse(StandInvitePromptRule.shouldPrompt(runKey: "r", completedDays: 4, promptedRuns: []))
    }

    func testEmptyRunKeyNeverAsks() {
        XCTAssertFalse(StandInvitePromptRule.shouldPrompt(runKey: "", completedDays: 1, promptedRuns: []))
        XCTAssertEqual(StandInvitePromptRule.recording("", in: ["a"]), ["a"])
    }

    func testRecordingIsIdempotentAndBounded() {
        XCTAssertEqual(StandInvitePromptRule.recording("a", in: ["a"]), ["a"])

        var asked: [String] = []
        for n in 0..<(StandInvitePromptRule.memory + 5) {
            asked = StandInvitePromptRule.recording("run\(n)", in: asked)
        }
        XCTAssertEqual(asked.count, StandInvitePromptRule.memory)
        XCTAssertEqual(asked.last, "run\(StandInvitePromptRule.memory + 4)")
        XCTAssertFalse(asked.contains("run0"))
    }

    // MARK: - Pair streak

    private let today = "2026-10-25"
    private let yesterday = "2026-10-24"

    private func enforcement() -> Enforcement {
        let raw: [String: Any] = [
            "id": "peace", "title": "Enforcing Peace", "tagline": "Seven days.",
            "theme": "anxiety",
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
        guard let plan = StandRoom.decodeEnforcement(raw) else {
            XCTFail("fixture enforcement did not decode")
            return Enforcement(id: "x", title: "x", tagline: "x", theme: .faith, days: [])
        }
        return plan
    }

    private func member(_ uid: String, _ name: String, spoken: [String],
                        joined: TimeInterval, left: Bool = false) -> StandMember {
        StandMember(uid: uid, name: name, initial: String(name.prefix(1)),
                    colorIndex: 1, dayNumber: spoken.count, daysSpoken: spoken,
                    joinedAt: Date(timeIntervalSince1970: joined),
                    lastSpokeAt: nil, timeZoneIdentifier: "UTC",
                    hasLeft: left, isOwner: uid == "me")
    }

    private func room(_ members: [StandMember]) -> StandRoom {
        StandRoom(id: "room", status: .active, enforcement: enforcement(),
                  createdBy: "me", memberUids: members.map(\.uid),
                  members: Dictionary(uniqueKeysWithValues: members.map { ($0.uid, $0) }),
                  completedAt: nil, lastActivityAt: nil)
    }

    func testStandOfOneHasNoStreak() {
        let r = room([member("me", "Ana", spoken: [], joined: 0)])
        XCTAssertNil(r.pairStreak(viewer: "me", todayStamp: today))
    }

    func testNonMemberHasNoStreak() {
        let r = room([member("me", "Ana", spoken: [], joined: 0),
                      member("b", "Maria", spoken: [], joined: 1)])
        XCTAssertNil(r.pairStreak(viewer: "stranger", todayStamp: today))
    }

    func testDuoNamesThePartnerAndPutsTheViewerFirst() throws {
        let r = room([member("b", "Maria", spoken: [yesterday, today], joined: 0),
                      member("me", "Ana", spoken: [yesterday], joined: 1)])
        let streak = try XCTUnwrap(r.pairStreak(viewer: "me", todayStamp: today))
        XCTAssertEqual(streak.title, "You and Maria")
        XCTAssertEqual(streak.dots.map(\.uid), ["me", "b"])
        XCTAssertEqual(streak.dots.map(\.spokeToday), [false, true])
        XCTAssertTrue(streak.dots[0].isViewer)
        // One day banked, today not spoken yet: they are on day 2.
        XCTAssertEqual(streak.day, 2)
        XCTAssertFalse(streak.everyoneSpokeToday)
    }

    func testDayIsTheBankedDayOnceTheViewerHasSpoken() throws {
        let r = room([member("me", "Ana", spoken: [yesterday, today], joined: 0),
                      member("b", "Maria", spoken: [today], joined: 1)])
        let streak = try XCTUnwrap(r.pairStreak(viewer: "me", todayStamp: today))
        XCTAssertEqual(streak.day, 2)
        XCTAssertTrue(streak.everyoneSpokeToday)
    }

    func testFreshDuoIsDayOne() throws {
        let r = room([member("me", "Ana", spoken: [], joined: 0),
                      member("b", "", spoken: [], joined: 1)])
        let streak = try XCTUnwrap(r.pairStreak(viewer: "me", todayStamp: today))
        XCTAssertEqual(streak.day, 1)
        // A cleared name still reads as a person.
        XCTAssertEqual(streak.title, "You and Someone")
    }

    func testFinishedWeekStaysOnDaySeven() throws {
        let week = (19...25).map { "2026-10-\($0)" }
        let r = room([member("me", "Ana", spoken: Array(week.dropLast()), joined: 0),
                      member("b", "Maria", spoken: week, joined: 1)])
        // Six banked, today not yet: day 7.
        XCTAssertEqual(try XCTUnwrap(r.pairStreak(viewer: "me", todayStamp: today)).day, 7)

        let done = room([member("me", "Ana", spoken: week, joined: 0),
                         member("b", "Maria", spoken: week, joined: 1)])
        XCTAssertEqual(try XCTUnwrap(done.pairStreak(viewer: "me", todayStamp: today)).day, 7)
    }

    func testGroupCountsOthersAndCapsDots() throws {
        var people = [member("me", "Ana", spoken: [], joined: 0)]
        for n in 1...5 { people.append(member("u\(n)", "P\(n)", spoken: [], joined: Double(n))) }
        people.append(member("gone", "Left", spoken: [], joined: 9, left: true))
        let streak = try XCTUnwrap(room(people).pairStreak(viewer: "me", todayStamp: today))
        XCTAssertEqual(streak.title, "You and 5 others")
        XCTAssertEqual(streak.dots.count, StandPairStreak.maxDots)
        XCTAssertEqual(streak.dots.first?.uid, "me")
        XCTAssertFalse(streak.dots.contains { $0.uid == "gone" })
    }
}
