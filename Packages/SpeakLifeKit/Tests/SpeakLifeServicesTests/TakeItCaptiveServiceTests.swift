//
//  TakeItCaptiveServiceTests.swift
//  SpeakLifeTests
//
//  Guarding's value rests on a handful of behaviors that are easy to "tidy"
//  into something harmful, so each one is pinned here:
//
//  1. Ground taken NEVER decreases and never resets. There is no reset method
//     to test, so the test is that repeated days only ever add.
//  2. A new user never gets the heaviest thought in the bank.
//  3. The same day always serves the same thought — the pin survives re-reads.
//  4. Crisis text routes to reachOut BEFORE any matching or quota check.
//  5. The escape hatch's raw text never reaches the log.
//

import XCTest
import SpeakLifeCore
@testable import SpeakLifeServices

final class TakeItCaptiveServiceTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "TakeItCaptiveTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    // MARK: - Fixtures

    /// A bank that never depends on shipped content: two categories, three
    /// intensities each.
    private func makeBank() -> [IncomingThought] {
        var bank: [IncomingThought] = []
        for category in [ThoughtCategory.fear, .lack] {
            for intensity in 1...3 {
                for index in 1...3 {
                    bank.append(IncomingThought(
                        id: "\(category.rawValue)_\(intensity)_\(index)",
                        text: "incoming \(category.rawValue) \(intensity) \(index)",
                        category: category,
                        intensity: intensity,
                        counterDeclaration: "I stand on solid ground.",
                        verseText: "The Lord is my rock.",
                        book: "Psalm 18:2",
                        declarationCategory: "godsprotection"
                    ))
                }
            }
        }
        return bank
    }

    /// `syncCounters` is stubbed out: banking ground would otherwise stand up
    /// CloudKit through `ProgressSyncStore`, which has nothing to do with what
    /// these tests are pinning and is tested in its own right.
    ///
    /// `featureFlags` defaults to an empty `StaticFeatureFlags` so nothing
    /// here brings Firebase Remote Config in through the back door; the
    /// isEnabled tests below override it.
    private func makeService(bank: [IncomingThought]? = nil,
                             featureFlags: FeatureFlagProviding = StaticFeatureFlags()) -> TakeItCaptiveService {
        TakeItCaptiveService(defaults: defaults, calendar: .current,
                             bank: bank ?? makeBank(), syncCounters: {},
                             featureFlags: featureFlags)
    }

    // MARK: - Kill switch
    //
    // The flag used to route through Firebase Remote Config, so nothing in
    // this file could exercise it — now it's injected and each state pins
    // straight through.

    func testIsEnabled_DefaultsToFalseWhenFlagUnset() {
        XCTAssertFalse(makeService().isEnabled,
                       "An unset flag must read false — a cold start before Firebase fetches must not surface the pillar.")
    }

    func testIsEnabled_TrueWhenFlagOn() {
        let service = makeService(featureFlags: StaticFeatureFlags(["guardEnabled": true]))
        XCTAssertTrue(service.isEnabled)
    }

    func testIsEnabled_FalseWhenFlagOff() {
        let service = makeService(featureFlags: StaticFeatureFlags(["guardEnabled": false]))
        XCTAssertFalse(service.isEnabled)
    }

    /// `TaskLibrary` reads `enabledCompletedToday`: nil leaves the row out
    /// entirely rather than offering a task the user cannot finish.
    func testEnabledCompletedToday_NilWhenSwitchOff_EvenWithLoadedBank() {
        let service = makeService(featureFlags: StaticFeatureFlags(["guardEnabled": false]))
        XCTAssertFalse(service.bank.isEmpty, "precondition: a bank is loaded")
        XCTAssertNil(service.enabledCompletedToday,
                     "Kill switch off must drop the checklist row rather than expose a dead task.")
    }

    func testEnabledCompletedToday_NonNilWhenSwitchOn() {
        let service = makeService(featureFlags: StaticFeatureFlags(["guardEnabled": true]))
        XCTAssertEqual(service.enabledCompletedToday, false,
                       "Switch on and bank loaded: the row exists and today's rep is not yet done.")
    }

    // MARK: - Ground taken

    func testGroundOnlyEverIncreases() {
        let service = makeService()
        XCTAssertEqual(service.groundTaken, 0)

        let first = service.takeGround(category: .fear, thoughtId: "a",
                                       source: .escapeHatch, spoken: true,
                                       completesDailyRep: false)
        let second = service.takeGround(category: .lack, thoughtId: "b",
                                        source: .escapeHatch, spoken: true,
                                        completesDailyRep: false)
        XCTAssertEqual(first, 1)
        XCTAssertEqual(second, 2)

        // Nothing in the API can lower it, and a fresh service over the same
        // defaults reads the same number back.
        let reloaded = makeService()
        XCTAssertEqual(reloaded.groundTaken, 2)
    }

    /// The daily rep is idempotent within a calendar day, so a double-tap can't
    /// inflate the count. Escape-hatch reps are separate ground and always count.
    func testDailyRepIsIdempotentButEscapeHatchIsNot() {
        let service = makeService()

        XCTAssertEqual(service.takeGround(category: .fear, thoughtId: "a",
                                          source: .daily, spoken: true,
                                          completesDailyRep: true), 1)
        XCTAssertEqual(service.takeGround(category: .fear, thoughtId: "a",
                                          source: .daily, spoken: true,
                                          completesDailyRep: true), 1)
        XCTAssertTrue(service.isCompletedToday)

        XCTAssertEqual(service.takeGround(category: .lack, thoughtId: "b",
                                          source: .escapeHatch, spoken: true,
                                          completesDailyRep: false), 2)
    }

    // MARK: - Intensity ladder

    func testNewUserOnlyEverSeesIntensityOne() {
        let service = makeService()
        XCTAssertEqual(service.intensityCeiling(), 1)

        let served = service.thought(isPremium: true)
        XCTAssertNotNil(served)
        XCTAssertEqual(served?.intensity, 1,
                       "A brand new user must never open on a heavy thought.")
    }

    func testIntensityThreeUnlocksOnlyAfterEnoughReps() {
        let service = makeService()
        // Backdate the first open so the seven-day gentle window is behind us.
        let old = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        defaults.set(TakeItCaptiveService.dayStamp(old, calendar: .current),
                     forKey: "guardFirstOpenedDay")

        defaults.set(TakeItCaptiveService.intensityThreeUnlocksAfter - 1,
                     forKey: "guardCompletionCount")
        XCTAssertEqual(service.intensityCeiling(), 2)

        defaults.set(TakeItCaptiveService.intensityThreeUnlocksAfter,
                     forKey: "guardCompletionCount")
        XCTAssertEqual(service.intensityCeiling(), 3)
    }

    /// Escape-hatch reps must not advance the intensity ladder.
    ///
    /// Counting every rep let fourteen hatch entries on day one unlock intensity
    /// 3 on day two, straight through the gentle opening the ladder exists to
    /// protect — and someone reaching for the hatch that often is precisely the
    /// person who should not be handed the heaviest thought in the bank.
    func testEscapeHatchRepsDoNotAdvanceTheIntensityLadder() {
        let service = makeService()
        // Put the seven-day gentle window behind us so only the rep count is
        // in play.
        let old = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        defaults.set(TakeItCaptiveService.dayStamp(old, calendar: .current),
                     forKey: "guardFirstOpenedDay")

        for index in 0..<(TakeItCaptiveService.intensityThreeUnlocksAfter * 2) {
            service.takeGround(category: .fear, thoughtId: "hatch\(index)",
                               source: .escapeHatch, spoken: true, completesDailyRep: false)
        }
        XCTAssertEqual(service.intensityCeiling(), 2,
                       "Only day-reps earn the ladder.")
    }

    /// The row's tick is derived, so a stale cached boolean pre-ticks the new
    /// day at midnight. `isCompletedToday` re-derives from the stored stamp.
    func testCompletionDoesNotCarryOverToTheNextDay() {
        let service = makeService()
        service.takeGround(category: .fear, thoughtId: "a", source: .daily,
                           spoken: true, completesDailyRep: true)
        XCTAssertTrue(service.isCompletedToday)

        // Rewind the stored stamp by a day — the same state the app is in the
        // morning after a completed rep.
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        defaults.set(TakeItCaptiveService.dayStamp(yesterday, calendar: .current),
                     forKey: "guardLastCompletedDay")

        XCTAssertFalse(service.isCompletedToday,
                       "Yesterday's rep must not tick today's row.")
    }

    // MARK: - Pinning

    func testTodaysThoughtIsPinnedAcrossReads() {
        let service = makeService()
        let first = service.thought(isPremium: true)
        XCTAssertNotNil(first)

        // Engagement changes underneath, which would move the weighting — the
        // pin must win, or someone could swipe one lie away and be asked to
        // speak the counter to a different one.
        defaults.set(["lack": 99], forKey: "guardCategoryEngagement")

        XCTAssertEqual(service.thought(isPremium: true)?.id, first?.id)
        XCTAssertEqual(makeService().thought(isPremium: true)?.id, first?.id,
                       "A relaunch on the same day must serve the same thought.")
    }

    // MARK: - Free tier

    func testFreeSliceIsFixedAndSmallerThanTheFullBank() {
        let service = makeService()
        let slice = service.freeSlice()

        // Two categories in the fixture × three each.
        XCTAssertEqual(slice.count, 2 * TakeItCaptiveService.freeThoughtsPerCategory)
        XCTAssertLessThan(slice.count, service.bank.count)
        // Deterministic: the same set every time, on every install.
        XCTAssertEqual(slice.map(\.id), makeService().freeSlice().map(\.id))
    }

    func testFreeUserIsServedFromTheFreeSliceOnly() {
        let service = makeService()
        let sliceIds = Set(service.freeSlice().map(\.id))
        let served = service.thought(isPremium: false)
        XCTAssertNotNil(served)
        XCTAssertTrue(sliceIds.contains(served!.id))
    }

    /// The rotation must keep rotating after the pool is exhausted.
    ///
    /// The free pool is 24 against a 60-day cooldown, so from about day 25 every
    /// candidate has been served and the cooldown filter relaxes away. A flat
    /// "has been served" penalty scored them all identically, the id tie-break
    /// fired, and the same thought came back every single day — a free user's
    /// drill quietly froze. Scoring by days-since turns that into least-recently-
    /// used instead.
    func testRotationKeepsMovingOnceEveryThoughtHasBeenServed() {
        let service = makeService()
        let calendar = Calendar.current

        // Lift the intensity ceiling to 3 so the whole fixture bank is eligible
        // and the exhaustion path — not the ladder — is what's being measured.
        let old = calendar.date(byAdding: .day, value: -60, to: Date())!
        defaults.set(TakeItCaptiveService.dayStamp(old, calendar: calendar),
                     forKey: "guardFirstOpenedDay")
        defaults.set(TakeItCaptiveService.intensityThreeUnlocksAfter,
                     forKey: "guardCompletionCount")

        // Every thought served, each on a different day, all inside the cooldown
        // so the relaxation path is the one under test.
        var served: [String: String] = [:]
        for (offset, thought) in service.bank.enumerated() {
            let day = calendar.date(byAdding: .day, value: -(offset + 1), to: Date())!
            served[thought.id] = TakeItCaptiveService.dayStamp(day, calendar: calendar)
        }
        defaults.set(served, forKey: "guardServedThoughts")

        let pick = service.thought(isPremium: true)
        XCTAssertNotNil(pick)
        // The oldest served entry is the last one in the loop above.
        XCTAssertEqual(pick?.id, service.bank.last?.id,
                       "Exhausted pool must serve the least-recently-seen thought, not the first by id.")
    }

    // MARK: - Escape-hatch quota

    func testFreeEscapeHatchesRunOutAndPremiumIsUnlimited() {
        let service = makeService()
        XCTAssertNil(service.escapeHatchesRemaining(isPremium: true))
        XCTAssertTrue(service.canUseEscapeHatch(isPremium: true))

        XCTAssertEqual(service.escapeHatchesRemaining(isPremium: false),
                       TakeItCaptiveService.freeEscapeHatchesPerMonth)
        for _ in 0..<TakeItCaptiveService.freeEscapeHatchesPerMonth {
            service.recordEscapeHatchUse(isPremium: false)
        }
        XCTAssertEqual(service.escapeHatchesRemaining(isPremium: false), 0)
        XCTAssertFalse(service.canUseEscapeHatch(isPremium: false))

        // A premium use must never be charged against the free allowance, so a
        // lapse doesn't hand the user a bill for months they paid for.
        service.recordEscapeHatchUse(isPremium: true)
        XCTAssertEqual(service.escapeHatchesRemaining(isPremium: false), 0)
    }

    // MARK: - Privacy

    /// The one thing this feature promises about the escape hatch: the sentence
    /// someone typed does not survive the call. The log carries a category and
    /// a placeholder id, and `CapturedThought` has nowhere to put text.
    func testEscapeHatchTextNeverReachesTheLog() {
        let service = makeService()
        service.takeGround(category: .fear,
                           thoughtId: CapturedThought.escapeHatchDeclarationId,
                           source: .escapeHatch,
                           spoken: true,
                           completesDailyRep: true)

        let captures = service.recentCaptures()
        XCTAssertEqual(captures.count, 1)
        XCTAssertEqual(captures.first?.thoughtId, CapturedThought.escapeHatchDeclarationId)

        // Encoded form must contain no free text either — this is what actually
        // ships to disk.
        let encoded = try? JSONEncoder().encode(captures)
        let json = String(data: encoded ?? Data(), encoding: .utf8) ?? ""
        XCTAssertFalse(json.contains("text"), "CapturedThought must never carry raw text.")
    }

    // MARK: - Terrain

    func testStrongestTerrainFollowsEngagement() {
        let service = makeService()
        service.takeGround(category: .lack, thoughtId: "a", source: .escapeHatch,
                           spoken: true, completesDailyRep: false)
        service.takeGround(category: .lack, thoughtId: "b", source: .escapeHatch,
                           spoken: true, completesDailyRep: false)
        service.takeGround(category: .fear, thoughtId: "c", source: .escapeHatch,
                           spoken: true, completesDailyRep: false)

        XCTAssertEqual(service.strongestTerrain(), .lack)
        // And it is named as ground, never as a diagnosis.
        XCTAssertEqual(ThoughtCategory.lack.terrainName, "provision")
    }

    // MARK: - Terrain naming

    /// The case names what comes IN; the terrain name is the higher reality the
    /// speaker takes. They must never be the same word, or the "ground taken"
    /// line degenerates into naming the low thing back at the user — "you've
    /// been taking a lot of ground in fear" is the exact sentence Rule 12
    /// forbids.
    func testTerrainNameIsNeverTheNameOfTheThingItDisplaces() {
        for category in ThoughtCategory.allCases {
            XCTAssertNotEqual(category.terrainName.lowercased(), category.rawValue.lowercased(),
                              "\(category.rawValue) names the incoming thought, not the ground.")
            XCTAssertFalse(category.terrainName.isEmpty)
        }
    }

    /// Fear lives in the mind, so the ground taken there is peace. Courage was
    /// wrong: it is a response to fear and keeps fear in the frame, where peace
    /// is what actually replaces it.
    func testFearTerrainIsPeace() {
        XCTAssertEqual(ThoughtCategory.fear.terrainName, "peace")
    }

    // MARK: - Empty bank

    func testEmptyBankServesNothingAndHidesTheRow() {
        let service = makeService(bank: [])
        XCTAssertNil(service.thought(isPremium: true))
    }

    // MARK: - Intent launch

    func testPendingLaunchIsConsumedExactlyOnce() {
        TakeItCaptiveService.requestPendingLaunch(defaults: defaults)
        XCTAssertTrue(TakeItCaptiveService.consumePendingLaunch(defaults: defaults))
        XCTAssertFalse(TakeItCaptiveService.consumePendingLaunch(defaults: defaults),
                       "A consumed request must not re-fire on the next launch.")
    }

    func testStaleLaunchRequestIsIgnored() {
        TakeItCaptiveService.requestPendingLaunch(defaults: defaults)
        let muchLater = Date().addingTimeInterval(600)
        XCTAssertFalse(TakeItCaptiveService.consumePendingLaunch(defaults: defaults, now: muchLater),
                       "A stale request must not ambush someone who opened the app for something else.")
    }
}

// MARK: - Checklist wiring

/// The row is the feature's only entry point outside the App Intent, so how it
/// appears and disappears is part of the contract.
final class GuardChecklistRowTests: XCTestCase {

    private let tenured = TaskLibrary.guardIntroducedAfterDaysCompleted + 10

    func testRowIsAbsentWhenThePillarIsDark() {
        // nil = kill switch off, or the bank failed to load.
        let tasks = TaskLibrary.getCoreTasksForStreak(30, guardCompletedToday: nil,
                                                      totalDaysCompleted: tenured)
        XCTAssertFalse(tasks.contains { $0.id == TaskLibrary.guardTaskId },
                       "A task nobody can finish is worse than no task.")
    }

    func testRowIsHeldBackUntilTheCoreLoopHasTakenHold() {
        for days in 0..<TaskLibrary.guardIntroducedAfterDaysCompleted {
            let tasks = TaskLibrary.getCoreTasksForStreak(days + 1, guardCompletedToday: false,
                                                          totalDaysCompleted: days)
            XCTAssertFalse(tasks.contains { $0.id == TaskLibrary.guardTaskId },
                           "The first days must stay light so the streak is easy to earn.")
        }
        let tasks = TaskLibrary.getCoreTasksForStreak(
            3, guardCompletedToday: false,
            totalDaysCompleted: TaskLibrary.guardIntroducedAfterDaysCompleted)
        XCTAssertTrue(tasks.contains { $0.id == TaskLibrary.guardTaskId })
    }

    /// The regression this pins is the worst one the feature could ship: gating
    /// the row on `currentStreak` deleted the pillar for two days the morning a
    /// streak broke — punishing someone for a lapse by removing the tool, on the
    /// exact day they need it most. Tenure is monotonic, so it cannot happen.
    func testABrokenStreakNeverRemovesThePillar() {
        let tasks = TaskLibrary.getCoreTasksForStreak(0, guardCompletedToday: false,
                                                      totalDaysCompleted: 200)
        XCTAssertTrue(tasks.contains { $0.id == TaskLibrary.guardTaskId },
                      "A 200-day user whose streak just died must keep Guarding.")
    }

    /// Guarding is a lifelong daily habit like speaking and hearing, not a
    /// first-week exercise. It must survive every progression phase — the bug
    /// this pins is the row silently vanishing around day 8 when the phase mix
    /// narrows.
    func testRowSurvivesEveryPhase() {
        for day in [3, 7, 8, 30, 31, 99, 100, 365] {
            let tasks = TaskLibrary.getCoreTasksForStreak(day, guardCompletedToday: false,
                                                          totalDaysCompleted: day)
            XCTAssertTrue(tasks.contains { $0.id == TaskLibrary.guardTaskId },
                          "Guard row went missing on day \(day)")
        }
    }

    func testRowSitsDirectlyBehindTheBurst() {
        let tasks = TaskLibrary.getCoreTasksForStreak(30, guardCompletedToday: false,
                                                      totalDaysCompleted: tenured)
        guard let burst = tasks.firstIndex(where: { $0.id == "complete_daily_burst" }),
              let guardRow = tasks.firstIndex(where: { $0.id == TaskLibrary.guardTaskId }) else {
            return XCTFail("Both rows should be present.")
        }
        XCTAssertEqual(guardRow, burst + 1, "Speaking leads; guarding holds what speaking took.")
    }

    func testRowCompletionIsDerivedFromTheService() {
        let done = TaskLibrary.getCoreTasksForStreak(30, guardCompletedToday: true,
                                                     totalDaysCompleted: tenured)
        XCTAssertEqual(done.first { $0.id == TaskLibrary.guardTaskId }?.isCompleted, true)

        let notDone = TaskLibrary.getCoreTasksForStreak(30, guardCompletedToday: false,
                                                        totalDaysCompleted: tenured)
        XCTAssertEqual(notDone.first { $0.id == TaskLibrary.guardTaskId }?.isCompleted, false)
    }

    /// Adding a pillar must not change what earns a streak. Someone who never
    /// opens Guarding has lost nothing.
    func testGuardNeverGatesTheStreak() {
        var tasks = TaskLibrary.getCoreTasksForStreak(30, guardCompletedToday: false,
                                                      totalDaysCompleted: tenured)
        for index in tasks.indices where tasks[index].id == "complete_daily_burst" {
            tasks[index].isCompleted = true
        }
        let checklist = DailyChecklist(date: Date(), tasks: tasks, currentPhase: .impact)
        XCTAssertTrue(checklist.isStreakEarned,
                      "The Burst alone earns the streak — Guarding must never gate it.")
    }

    /// The row never names the low thing. No "anxious", no "negative", no
    /// "your thought" — see rule 2 of the guardrails.
    func testRowCopyNeverAccusesTheUser() {
        let tasks = TaskLibrary.getCoreTasksForStreak(30, guardCompletedToday: false,
                                                      totalDaysCompleted: tenured)
        guard let row = tasks.first(where: { $0.id == TaskLibrary.guardTaskId }) else {
            return XCTFail("Expected the Guard row.")
        }
        let copy = (row.title + " " + row.description).lowercased()
        for banned in ["your thought", "anxious", "anxiety", "negative", "sinful", "struggle"] {
            XCTAssertFalse(copy.contains(banned),
                           "Guard copy must arm, never accuse. Found \"\(banned)\" in: \(copy)")
        }
    }
}

// MARK: - Classifier

final class ThoughtClassifierTests: XCTestCase {

    private func makeBank() -> [IncomingThought] {
        ThoughtCategory.allCases.map { category in
            IncomingThought(
                id: "\(category.rawValue)_1",
                text: "incoming \(category.rawValue)",
                category: category,
                intensity: 1,
                counterDeclaration: "I stand on solid ground.",
                verseText: "The Lord is my rock.",
                book: "Psalm 18:2",
                declarationCategory: "godsprotection"
            )
        }
    }

    /// The single most important behavior in the feature. Crisis text must not
    /// reach matching, a quota check, or a paywall.
    func testCrisisTextRoutesToReachOut() {
        let classifier = ThoughtClassifier(bank: makeBank())
        let result = classifier.classify("I want to kill myself")
        XCTAssertEqual(result, .reachOut)
    }

    /// Bare "suicide" in a bereavement sentence must NOT route to reach-out —
    /// telling a grieving parent their pain is out of bounds is the worst thing
    /// this screen could do. Pinned here because it is a real regression this
    /// codebase already fixed once in `SituationScreen`.
    func testBereavementIsNotTreatedAsCrisis() {
        let classifier = ThoughtClassifier(bank: makeBank())
        guard case .matched = classifier.classify("I lost my son to suicide and I feel alone") else {
            return XCTFail("A bereaved parent must still get a declaration to speak.")
        }
    }

    func testPurityThoughtMapsToTheLustTerrain() {
        let classifier = ThoughtClassifier(bank: makeBank())
        guard case .matched(let category, _, let confidence) =
                classifier.classify("I keep giving in to lust and temptation") else {
            return XCTFail("Expected a match.")
        }
        XCTAssertEqual(category, .lust)
        XCTAssertEqual(confidence, .high)
        // Named as ground taken, never as a label on the speaker.
        XCTAssertEqual(ThoughtCategory.lust.terrainName, "purity")
    }

    /// Deliberate, and pinned so it isn't "fixed" by accident: the addiction
    /// keyword rule owns "porn" and fires before the purity rule, so that input
    /// lands on grace rather than purity. It also carries alcohol and drugs, and
    /// grace is the right medicine for the shame underneath any of them.
    func testAddictionStaysOnTheGraceTerrain() {
        let classifier = ThoughtClassifier(bank: makeBank())
        guard case .matched(let category, _, _) =
                classifier.classify("I relapsed with alcohol again") else {
            return XCTFail("Expected a match.")
        }
        XCTAssertEqual(category, .condemnation)
    }

    /// The input deliberately avoids "bills": the shared keyword table matches on
    /// substrings, and "bills" contains "ill", which fires the health rule first
    /// and routes a money worry to the healing terrain. That is a quirk of the
    /// table this feature borrows, not something to work around here — but a test
    /// written over it would be asserting the wrong thing.
    func testMoneyThoughtMapsToProvisionTerrain() {
        let classifier = ThoughtClassifier(bank: makeBank())
        guard case .matched(let category, _, let confidence) =
                classifier.classify("I am drowning in debt and cannot make the payments") else {
            return XCTFail("Expected a match.")
        }
        XCTAssertEqual(category, .lack)
        XCTAssertEqual(confidence, .high)
    }

    /// There is no error state. Unmatched input still gets a declaration —
    /// someone who just typed a real thought must never be left holding it.
    func testUnmatchedInputStillGetsSomethingToSpeak() {
        let classifier = ThoughtClassifier(bank: makeBank())
        guard case .matched(_, let thought, let confidence) =
                classifier.classify("qqq zzz mmm nnn") else {
            return XCTFail("The escape hatch must never dead-end.")
        }
        XCTAssertEqual(confidence, .low)
        XCTAssertFalse(thought.counterDeclaration.isEmpty)
    }

    /// Re-typing the same thought must not shuffle the line they are about to
    /// speak. `String.hashValue` is process-seeded, which is why this is pinned.
    func testMatchIsStableForTheSameInput() {
        let classifier = ThoughtClassifier(bank: makeBank())
        let input = "nobody wants me around anymore"
        guard case .matched(_, let first, _) = classifier.classify(input),
              case .matched(_, let second, _) = classifier.classify(input) else {
            return XCTFail("Expected matches.")
        }
        XCTAssertEqual(first.id, second.id)
    }

    func testEmptyBankFallsBackToAReviewedDeclaration() {
        let classifier = ThoughtClassifier(bank: [])
        guard case .matched(_, let thought, _) = classifier.classify("I feel like a fraud") else {
            return XCTFail("Expected the last-resort declaration.")
        }
        XCTAssertEqual(thought.book, "2 Corinthians 5:17")
    }
}
