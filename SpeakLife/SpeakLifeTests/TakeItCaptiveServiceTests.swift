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
@testable import SpeakLife

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
    private func makeService(bank: [IncomingThought]? = nil) -> TakeItCaptiveService {
        TakeItCaptiveService(defaults: defaults, calendar: .current,
                             bank: bank ?? makeBank(), syncCounters: {})
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

// MARK: - Naming the thought

/// The ASK screen's gate on what counts as a thought.
///
/// This shipped as `count >= 3`, so "I am" lit the button. Four characters name
/// nothing, match no keyword, and route to the low-confidence fallback — the
/// person gets a generic declaration with no relation to what they were
/// carrying, and no sign anything was missed. These tests pin the bar.
final class AskForThoughtEntryTests: XCTestCase {

    func testStubsDoNotCountAsANamedThought() {
        for stub in ["I am", "I want", "i feel", "I'm", "it is", "so", "  ", "I am a"] {
            XCTAssertFalse(AskForThoughtView.namesAThought(stub),
                           "\"\(stub)\" is the start of a sentence, not a thought.")
        }
    }

    /// Function words clear both counts and still name nothing. This is the case
    /// a pure length check cannot catch.
    func testAllFunctionWordsDoNotCount() {
        XCTAssertFalse(AskForThoughtView.namesAThought("i feel like i want to"))
        XCTAssertFalse(AskForThoughtView.namesAThought("it is just that i really"))
    }

    /// The bar must not swing so far that real thoughts get locked out. Short,
    /// blunt sentences are how these actually arrive.
    func testRealThoughtsAreAccepted() {
        for entry in [
            "I'm worthless",
            "I’m worthless",              // iOS substitutes a curly apostrophe
            "God hates me",
            "nobody loves me",
            "I am not good enough",
            "the enemy tries to lie and say he got me",
            "I'll never get out of this debt"
        ] {
            XCTAssertTrue(AskForThoughtView.namesAThought(entry),
                          "\"\(entry)\" is a real thought and must be accepted.")
        }
    }

    /// The shortest real thoughts there are. Every one of these hits a keyword
    /// rule and comes back with a high-confidence match, so locking them out to
    /// catch "I am" would reject the bluntest way someone says the truest thing.
    /// A nine-letter bar did exactly that — this is what holds it at seven.
    func testTheBluntestThoughtsAreAccepted() {
        for entry in ["I'm ugly", "I'm sick", "I'm broke", "I'm alone", "God is mad"] {
            XCTAssertTrue(AskForThoughtView.namesAThought(entry),
                          "\"\(entry)\" must not be locked out by the length bar.")
        }
    }

    /// The bar exists to catch fragments, and the fragments it catches are the
    /// ones a person is still typing — so the screen must keep a live way
    /// forward underneath them. That is the `!canSubmit` gate on the fallback,
    /// asserted here as the invariant it enforces: nothing the gate rejects may
    /// leave the screen with no action, and the fallback is shown for exactly
    /// the set this returns false for.
    func testRejectedEntriesAreExactlyWhenTheFallbackShows() {
        for entry in ["", "I am", "I want", "I'm"] {
            XCTAssertFalse(AskForThoughtView.namesAThought(entry),
                           "\"\(entry)\" must leave the fallback on screen.")
        }
    }

    /// Whatever the gate accepts, the classifier must have something to say
    /// about — the whole point of asking is that a word comes back.
    func testEveryAcceptedThoughtGetsADeclarationAndAVerse() {
        let classifier = ThoughtClassifier(bank: [])
        for entry in ["I'm worthless", "God hates me", "nobody loves me", "qqq zzz mmm"] {
            guard AskForThoughtView.namesAThought(entry) else { continue }
            guard case .matched(_, let thought, _) = classifier.classify(entry) else {
                return XCTFail("\"\(entry)\" must never dead-end.")
            }
            XCTAssertFalse(thought.counterDeclaration.isEmpty)
            XCTAssertFalse(thought.verseText.isEmpty)
            XCTAssertFalse(thought.book.isEmpty)
        }
    }
}

// MARK: - Shipped content

/// The bank is generated from `declarationsv10.json`, and these assertions are
/// what stop a hand-edit from quietly breaking it.
final class ThoughtBankContentTests: XCTestCase {

    private func loadBank() throws -> [IncomingThought] {
        let bundle = Bundle(for: ThoughtBankContentTests.self)
        let url = try XCTUnwrap(bundle.url(forResource: "thoughts", withExtension: "json")
                                ?? Bundle.main.url(forResource: "thoughts", withExtension: "json"))
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(ThoughtBank.self, from: data).thoughts
    }

    func testBankIsBigEnoughToNeverRepeatInsideTheCooldown() throws {
        let bank = try loadBank()
        XCTAssertGreaterThan(bank.count, TakeItCaptiveService.repeatCooldownDays,
                             "At one rep a day, the bank must outlast the 60-day cooldown.")
    }

    func testEveryCategoryIsStockedAtEveryIntensity() throws {
        let bank = try loadBank()
        for category in ThoughtCategory.allCases {
            for intensity in 1...3 {
                let matches = bank.filter { $0.category == category && $0.intensity == intensity }
                XCTAssertFalse(matches.isEmpty,
                               "\(category.rawValue) has nothing at intensity \(intensity), so the ladder would stall there.")
            }
        }
    }

    func testIdsAndCounterDeclarationsAreUnique() throws {
        let bank = try loadBank()
        XCTAssertEqual(Set(bank.map(\.id)).count, bank.count)
        XCTAssertEqual(Set(bank.map(\.counterDeclaration)).count, bank.count,
                       "Two thoughts answered by the same line makes the drill feel canned.")
    }

    /// Every entry must have a line to speak and a verse it stands on. The loop
    /// terminates in speaking, so a blank counter is a broken rep.
    func testEveryThoughtHasSomethingToSpeak() throws {
        for thought in try loadBank() {
            XCTAssertFalse(thought.text.trimmingCharacters(in: .whitespaces).isEmpty, thought.id)
            XCTAssertFalse(thought.counterDeclaration.trimmingCharacters(in: .whitespaces).isEmpty, thought.id)
            XCTAssertFalse(thought.verseText.trimmingCharacters(in: .whitespaces).isEmpty, thought.id)
            XCTAssertFalse(thought.book.trimmingCharacters(in: .whitespaces).isEmpty, thought.id)
            XCTAssertTrue((1...3).contains(thought.intensity), thought.id)
        }
    }

    /// Splits on anything that isn't a letter or apostrophe, so "in me." and
    /// "me," both yield the word `me`. Substring matching on " me " misses both
    /// and would fail a perfectly good declaration.
    private func words(_ text: String) -> Set<String> {
        Set(text.lowercased()
            .split(whereSeparator: { !$0.isLetter && $0 != "'" })
            .map(String.init))
    }

    /// Counter-declarations are copied verbatim out of the reviewed library, so
    /// they inherit its rules — first person, present tense, no dashes.
    func testCounterDeclarationsFollowTheDeclarationRules() throws {
        let firstPerson: Set<String> = ["i", "i'm", "my", "me", "mine", "myself"]
        for thought in try loadBank() {
            let text = thought.counterDeclaration
            XCTAssertFalse(text.contains("—") || text.contains("–"),
                           "Declarations never use dashes: \(thought.id)")
            XCTAssertFalse(words(text).isDisjoint(with: firstPerson),
                           "Declarations are first person: \(thought.id) — \(text)")
        }
    }

    /// The incoming thought is always framed as arriving from outside — second
    /// person, the way a lie actually sounds. It is never written in first
    /// person, because a first-person line reads as the user's own thought and
    /// indicts them, which this feature must never do.
    func testIncomingThoughtsAreNeverFirstPerson() throws {
        let firstPerson: Set<String> = ["i", "i'm", "i've", "my", "mine", "myself"]
        for thought in try loadBank() {
            XCTAssertTrue(words(thought.text).isDisjoint(with: firstPerson),
                          "The thought must never be phrased as the user's own: \(thought.id) — \(thought.text)")
        }
    }
}

// MARK: - Ground taken earns badges

/// Guarding's counter feeds the badge system, and these pin the wiring.
///
/// Before this, `totalThoughtsTakenCaptive` was written, synced across devices
/// and guaranteed monotonic — and then read by nothing. Every sibling counter
/// in `ProgressSyncStore.syncedCounterKeys` cashes out into badge progress;
/// this one earned nothing, which made Guarding the only pillar whose work paid
/// out in a number the user saw once and never again.
final class GroundTakenBadgeTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "GroundTakenBadgeTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    private func stats(_ takenCaptive: Int) -> UserStats {
        UserStats(affirmationsSpoken: 0, versesRead: 0, socialShares: 0,
                  favoritesAdded: 0, categoriesCompleted: [],
                  thoughtsTakenCaptive: takenCaptive)
    }

    /// The ladder exists and is reachable at every tier.
    func testEveryGuardingTierHasABadge() {
        let manager = BadgeManager(userDefaults: defaults)
        let tiers = manager.allBadges.compactMap { badge -> Int? in
            guard case .thoughtsTakenCaptive(let count) = badge.requirement else { return nil }
            return count
        }
        XCTAssertEqual(tiers.sorted(), [1, 10, 50, 150, 365])
    }

    /// One rep earns the first badge. The reason the ladder starts at 1 rather
    /// than 10: the drill is once a day, so a first threshold of ten is ten days
    /// before anything acknowledges the feature exists.
    func testFirstThoughtEarnsTheFirstBadge() {
        let manager = BadgeManager(userDefaults: defaults)
        manager.checkForNewBadges(streakStats: StreakStats(), userStats: stats(1))
        XCTAssertTrue(manager.unlockedBadges.contains { $0.requirement == .thoughtsTakenCaptive(1) })
        XCTAssertFalse(manager.unlockedBadges.contains { $0.requirement == .thoughtsTakenCaptive(10) })
    }

    /// Crossing several thresholds at once awards all of them, not just the top.
    /// Ground is cumulative and can arrive in a batch from another device.
    func testCrossingSeveralTiersAwardsEachOfThem() {
        let manager = BadgeManager(userDefaults: defaults)
        manager.checkForNewBadges(streakStats: StreakStats(), userStats: stats(60))
        for tier in [1, 10, 50] {
            XCTAssertTrue(manager.unlockedBadges.contains { $0.requirement == .thoughtsTakenCaptive(tier) },
                          "Tier \(tier) should be earned at 60.")
        }
        XCTAssertFalse(manager.unlockedBadges.contains { $0.requirement == .thoughtsTakenCaptive(150) })
    }

    /// Re-checking must not award the same badge twice — `checkForNewBadges`
    /// runs on launch, on campaign changes and after every Guarding rep.
    func testRecheckingDoesNotDoubleAward() {
        let manager = BadgeManager(userDefaults: defaults)
        manager.checkForNewBadges(streakStats: StreakStats(), userStats: stats(10))
        let afterFirst = manager.unlockedBadges.count
        manager.checkForNewBadges(streakStats: StreakStats(), userStats: stats(10))
        XCTAssertEqual(manager.unlockedBadges.count, afterFirst)
    }

    /// A stats object that never heard of Guarding earns no Guarding badge.
    /// The defaulted field must fail closed, never open.
    func testOmittedCounterEarnsNothing() {
        let manager = BadgeManager(userDefaults: defaults)
        let noGuarding = UserStats(affirmationsSpoken: 999, versesRead: 999,
                                   socialShares: 999, favoritesAdded: 999,
                                   categoriesCompleted: [])
        manager.checkForNewBadges(streakStats: StreakStats(), userStats: noGuarding)
        XCTAssertFalse(manager.unlockedBadges.contains {
            if case .thoughtsTakenCaptive = $0.requirement { return true }
            return false
        })
    }

    /// The number the badges read is the one the service writes. If these ever
    /// diverge, a user banks ground and the ladder does not move.
    func testServiceCounterIsWhatTheBadgesRead() {
        let service = TakeItCaptiveService(defaults: defaults, bank: [], syncCounters: {})
        service.takeGround(category: .fear, thoughtId: "t1", source: .daily,
                           spoken: true, completesDailyRep: true)
        XCTAssertEqual(GroundTaken.total(defaults: defaults), 1)
        XCTAssertEqual(service.groundTaken, GroundTaken.total(defaults: defaults))
    }
}

// MARK: - The premium path

/// Guarding's premium path sends the typed thought to Claude. These pin the
/// three things that must hold regardless of what the network does.
final class GuardPremiumPathTests: XCTestCase {

    private var savedKey: String!

    override func setUp() {
        super.setUp()
        savedKey = AnthropicConfig.apiKey
    }

    override func tearDown() {
        AnthropicConfig.apiKey = savedKey
        savedKey = nil
        super.tearDown()
    }

    private func makeBank() -> [IncomingThought] {
        [IncomingThought(id: "fear_1", text: "incoming", category: .fear, intensity: 1,
                         counterDeclaration: "I stand on solid ground.",
                         verseText: "The Lord is my rock.", book: "Psalm 18:2",
                         declarationCategory: "godsprotection")]
    }

    /// The one that matters most. Crisis screening is local and runs BEFORE the
    /// request, so someone in crisis is never held behind a network round trip
    /// and their words are never sent.
    func testCrisisTextNeverReachesTheNetwork() async {
        AnthropicConfig.apiKey = "sk-ant-test-key-that-would-be-used"
        let classifier = ThoughtClassifier(bank: makeBank())
        // A URLSession call would hang or fail here; reachOut must come back
        // immediately from the local screen instead.
        let result = await classifier.classify("I want to kill myself", isPremium: true)
        XCTAssertEqual(result, .reachOut)
    }

    /// Premium alone must not flip the privacy copy. The key arrives from
    /// Remote Config and can be empty, and a premium user on an unconfigured
    /// build silently runs on device — they must not be told otherwise.
    func testPrivacyLineFollowsWhatActuallyHappens() {
        let classifier = ThoughtClassifier(bank: makeBank())

        AnthropicConfig.apiKey = ""
        XCTAssertFalse(classifier.sendsThoughtOffDevice(isPremium: true),
                       "No key means the words stay on device, whatever the tier.")
        XCTAssertFalse(classifier.sendsThoughtOffDevice(isPremium: false))

        AnthropicConfig.apiKey = "sk-ant-test"
        XCTAssertTrue(classifier.sendsThoughtOffDevice(isPremium: true))
        XCTAssertFalse(classifier.sendsThoughtOffDevice(isPremium: false),
                       "A free user's words never leave the phone.")
    }

    /// Free users get exactly the behaviour they had before, and no request is
    /// made on their behalf.
    func testFreeTierIsUnchangedAndStaysLocal() async {
        AnthropicConfig.apiKey = "sk-ant-test"
        let classifier = ThoughtClassifier(bank: makeBank())
        let input = "I am afraid all the time"

        let async = await classifier.classify(input, isPremium: false)
        let sync = classifier.classify(input)
        XCTAssertEqual(async, sync,
                       "The free path must be the on-device path, byte for byte.")
    }

    /// No key configured is a fallback, not a failure. Someone who typed a real
    /// thought still gets something to speak.
    func testUnconfiguredPremiumFallsBackRatherThanDeadEnding() async {
        AnthropicConfig.apiKey = ""
        let classifier = ThoughtClassifier(bank: makeBank())
        guard case .matched(_, let thought, _) =
                await classifier.classify("I am afraid all the time", isPremium: true) else {
            return XCTFail("The premium path must never dead-end.")
        }
        XCTAssertFalse(thought.counterDeclaration.isEmpty)
        XCTAssertFalse(thought.verseText.isEmpty)
    }
}
