//
//  BurstReminderPlannerTests.swift
//  SpeakLifeTests
//
//  The Daily Burst went from a single 7:30am alarm to a rhythm — three
//  invitations a day by default. These cover the two things that decide whether
//  that rhythm reads as an invitation or as nagging: WHERE the slots land (clear
//  of the user's own reminders and of each other, and never in the small hours)
//  and WHAT each one says (rotating, and never two identical lines on the same
//  day).
//

import XCTest
@testable import SpeakLifeServices

final class BurstReminderPlannerTests: XCTestCase {

    // MARK: - Count clamping

    func testAbsentSettingResolvesToTheDefaultRhythm() {
        // `UserDefaults.integer(forKey:)` returns 0 for a key that was never
        // written, which means "never chose", not "no bursts". An existing user
        // upgrading into this feature has to land on three a day, not zero.
        XCTAssertEqual(BurstReminderPlanner.clampBurstsPerDay(0), 3)
    }

    func testCountIsClampedIntoTheAllowedRange() {
        XCTAssertEqual(BurstReminderPlanner.clampBurstsPerDay(1), 1)
        XCTAssertEqual(BurstReminderPlanner.clampBurstsPerDay(4), 4)
        XCTAssertEqual(BurstReminderPlanner.clampBurstsPerDay(9), 4)
        XCTAssertEqual(BurstReminderPlanner.clampBurstsPerDay(-3), 3)
    }

    func testPlanHonoursTheChosenCount() {
        for count in BurstReminderPlanner.allowedBurstsPerDay {
            let plan = BurstReminderPlanner.plan(count: count, userReminderMinutes: [], dayIndex: 0)
            XCTAssertEqual(plan.count, count)
            XCTAssertEqual(plan.map(\.total), Array(repeating: count, count: count))
        }
    }

    // MARK: - Identifiers

    func testSlotIdentifiersAreStableAndUnique() {
        let first = BurstReminderPlanner.plan(count: 3, userReminderMinutes: [], dayIndex: 4)
        let second = BurstReminderPlanner.plan(count: 3, userReminderMinutes: [420], dayIndex: 200)

        // Stability is what lets a refresh on every foreground replace the
        // pending requests in place instead of queueing duplicates.
        XCTAssertEqual(first.map(\.identifier), second.map(\.identifier))
        XCTAssertEqual(Set(first.map(\.identifier)).count, 3)
    }

    func testSweepCoversEveryIdentifierTheRangeCanProduce() {
        // Turning the rhythm down from 4 a day to 1 must actually retire slots
        // 2-4; a sweep keyed on the CURRENT count would leave them pending.
        let sweep = Set(BurstReminderPlanner.allSlotIdentifiers)
        for count in BurstReminderPlanner.allowedBurstsPerDay {
            let plan = BurstReminderPlanner.plan(count: count, userReminderMinutes: [], dayIndex: 0)
            for reminder in plan {
                XCTAssertTrue(sweep.contains(reminder.identifier), reminder.identifier)
            }
        }
    }

    func testLegacyIdentifiersAreSwept() {
        let legacy = Set(BurstReminderPlanner.legacyIdentifiers)
        // The single-trigger IDs, and the weekday-rotated ones that replaced them.
        XCTAssertTrue(legacy.contains("daily_declaration_reminder"))
        XCTAssertTrue(legacy.contains("daily_declaration_evening_reminder"))
        XCTAssertTrue(legacy.contains("daily_burst_morning_w1"))
        XCTAssertTrue(legacy.contains("daily_burst_morning_w7"))
        XCTAssertTrue(legacy.contains("daily_burst_evening_w4"))
        // And none of them collides with a live slot ID, or the sweep would
        // cancel what it had just scheduled.
        XCTAssertTrue(legacy.isDisjoint(with: Set(BurstReminderPlanner.allSlotIdentifiers)))
    }

    // MARK: - Times

    func testWithNoUserRemindersTheSlotsSitOnTheirAnchors() {
        let times = BurstReminderPlanner.slotTimes(count: 3, userReminderMinutes: [])
        XCTAssertEqual(times.map { $0.hour }, [7, 12, 19])
        XCTAssertEqual(times.map { $0.minute }, [30, 30, 30])
    }

    func testFirstSlotMovesClearOfTheDefaultReminderWindow() {
        // The default window opens at 7:00am and the first burst anchor is 7:30,
        // so out of the box the user caught two SpeakLife pushes half an hour
        // apart every morning. The burst moves; it is never dropped.
        let userSlots = [7 * 60, 11 * 60, 15 * 60, 19 * 60, 23 * 60]
        let times = BurstReminderPlanner.slotTimes(count: 3, userReminderMinutes: userSlots)

        for time in times {
            let minutes = time.hour * 60 + time.minute
            for user in userSlots {
                XCTAssertGreaterThanOrEqual(
                    abs(minutes - user),
                    BurstReminderPlanner.minGapFromUserRemindersMinutes,
                    "burst at \(time) sits on top of a user reminder at \(user / 60):\(user % 60)"
                )
            }
        }
        XCTAssertEqual(times.count, 3)
    }

    func testSlotsNeverStackOnEachOther() {
        // Nudging a slot away from a collision must not walk it into its
        // neighbour — two bursts twenty minutes apart is the same failure the
        // nudge exists to prevent.
        let dense = stride(from: 7 * 60, through: 22 * 60, by: 45).map { $0 }
        for count in BurstReminderPlanner.allowedBurstsPerDay {
            let times = BurstReminderPlanner.slotTimes(count: count, userReminderMinutes: dense)
                .map { $0.hour * 60 + $0.minute }
            for (i, a) in times.enumerated() {
                for b in times[(i + 1)...] {
                    XCTAssertGreaterThanOrEqual(abs(a - b), 60, "slots \(a) and \(b) too close")
                }
            }
        }
    }

    func testNudgingNeverPushesASlotIntoTheNight() {
        // Every candidate colliding is a real case on a dense reminder
        // schedule. The slot then falls back to its anchor — which is inside
        // waking hours — rather than wandering to 5am.
        let everyHalfHour = stride(from: 0, through: 23 * 60 + 30, by: 30).map { $0 }
        for count in BurstReminderPlanner.allowedBurstsPerDay {
            for time in BurstReminderPlanner.slotTimes(count: count, userReminderMinutes: everyHalfHour) {
                XCTAssertGreaterThanOrEqual(time.hour, 6)
                XCTAssertLessThanOrEqual(time.hour, 22)
            }
        }
    }

    func testAnEmptyReminderBatchIsNotTreatedAsACollision() {
        let withBatch = BurstReminderPlanner.slotTimes(count: 3, userReminderMinutes: [8 * 60])
        let withoutBatch = BurstReminderPlanner.slotTimes(count: 3, userReminderMinutes: [])
        // Only the colliding morning slot should have moved.
        XCTAssertNotEqual(withBatch[0].hour * 60 + withBatch[0].minute, 7 * 60 + 30)
        XCTAssertEqual(withoutBatch[0].hour * 60 + withoutBatch[0].minute, 7 * 60 + 30)
        XCTAssertEqual(withBatch[2].hour, withoutBatch[2].hour)
    }

    // MARK: - Copy

    func testEveryLineNamesTheSevenAndIsShortEnoughToLand() {
        let pools = BurstReminderPlanner.morningCopy
            + BurstReminderPlanner.middayCopy
            + BurstReminderPlanner.eveningCopy

        for line in pools {
            XCTAssertFalse(line.title.isEmpty)
            XCTAssertFalse(line.body.isEmpty)
            // iOS truncates a push body hard on the lock screen. The ask has to
            // survive the truncation.
            XCTAssertLessThanOrEqual(line.body.count, 110, line.body)
            XCTAssertLessThanOrEqual(line.title.count, 40, line.title)
            // A push that only says "open SpeakLife" is asking for a tap. This
            // one is asking for a voice, so it names what is being spoken.
            let names = line.body.lowercased().contains("seven")
                || line.title.lowercased().contains("seven")
                || line.body.lowercased().contains("burst")
                || line.title.lowercased().contains("burst")
            XCTAssertTrue(names, "no ask in: \(line.title) / \(line.body)")
        }
    }

    func testCopyRotatesFromOneDayToTheNext() {
        let today = BurstReminderPlanner.plan(count: 3, userReminderMinutes: [], dayIndex: 10)
        let tomorrow = BurstReminderPlanner.plan(count: 3, userReminderMinutes: [], dayIndex: 11)

        for (a, b) in zip(today, tomorrow) {
            XCTAssertNotEqual(a.title, b.title, "slot \(a.index) repeated its line the next day")
        }
    }

    func testTwoSlotsInTheSamePoolNeverCarryTheSameLine() {
        // At four a day, two invitations land in the midday pool. Keyed on the
        // day alone they would arrive carrying identical copy.
        let plan = BurstReminderPlanner.plan(count: 4, userReminderMinutes: [], dayIndex: 3)
        XCTAssertEqual(Set(plan.map(\.title)).count, plan.count)
        XCTAssertEqual(Set(plan.map(\.body)).count, plan.count)
    }

    func testCopyMatchesTheHourItActuallyFiresAt() {
        // A slot nudged out of the morning must not greet the evening with
        // "before the day starts" — the pool is chosen by the fire time, not by
        // the slot's position.
        XCTAssertEqual(BurstReminderPlanner.TimeOfDay.forHour(6), .morning)
        XCTAssertEqual(BurstReminderPlanner.TimeOfDay.forHour(10), .morning)
        XCTAssertEqual(BurstReminderPlanner.TimeOfDay.forHour(11), .midday)
        XCTAssertEqual(BurstReminderPlanner.TimeOfDay.forHour(15), .midday)
        XCTAssertEqual(BurstReminderPlanner.TimeOfDay.forHour(16), .evening)
        XCTAssertEqual(BurstReminderPlanner.TimeOfDay.forHour(21), .evening)

        let evening = BurstReminderPlanner.plan(count: 3, userReminderMinutes: [], dayIndex: 0)[2]
        XCTAssertTrue(
            BurstReminderPlanner.eveningCopy.contains { $0.title == evening.title },
            "the evening slot drew from the wrong pool"
        )
    }

    func testANegativeDayIndexStillResolvesToALine() {
        // Callers derive the index from date math that can hand back something
        // odd; an out-of-range index must never trap.
        let plan = BurstReminderPlanner.plan(count: 3, userReminderMinutes: [], dayIndex: -7)
        XCTAssertEqual(plan.count, 3)
        for reminder in plan {
            XCTAssertFalse(reminder.title.isEmpty)
        }
    }
}
