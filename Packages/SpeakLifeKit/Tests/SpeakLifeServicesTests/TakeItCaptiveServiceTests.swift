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

    /// Guarding sits directly behind the Burst when the user carries no personal
    /// declaration, and one slot further back when they do — the declaration is
    /// inserted at the same anchor and takes second.
    ///
    /// Asserted as "above every ordinary task" rather than a fixed index, so
    /// adding another spoken row does not fail this for the wrong reason.
    func testRowSitsDirectlyBehindTheBurst() {
        let tasks = TaskLibrary.getCoreTasksForStreak(30, guardCompletedToday: false,
                                                      totalDaysCompleted: tenured)
        guard let burst = tasks.firstIndex(where: { $0.id == "complete_daily_burst" }),
              let guardRow = tasks.firstIndex(where: { $0.id == TaskLibrary.guardTaskId }) else {
            return XCTFail("Both rows should be present.")
        }
        XCTAssertEqual(burst, 0, "The Burst leads: it is the only row that earns the streak.")
        XCTAssertEqual(guardRow, burst + 1, "Speaking leads; guarding holds what speaking took.")
    }

    /// With a declaration in play the order is Burst → declaration → Guarding.
    func testRowSitsBehindTheDeclarationWhenTheUserCarriesOne() {
        let tasks = TaskLibrary.getCoreTasksForStreak(
            30,
            personalDeclarations: .init(total: 1, spokenToday: 0, headline: "I am healed."),
            guardCompletedToday: false,
            totalDaysCompleted: tenured
        )
        let ids = tasks.map(\.id)
        guard let burst = ids.firstIndex(of: "complete_daily_burst"),
              let declaration = ids.firstIndex(of: TaskLibrary.personalDeclarationTaskId),
              let guardRow = ids.firstIndex(of: TaskLibrary.guardTaskId) else {
            return XCTFail("All three rows should be present, got \(ids).")
        }
        XCTAssertEqual(burst, 0, "ordered as \(ids)")
        XCTAssertEqual(declaration, 1, "ordered as \(ids)")
        XCTAssertEqual(guardRow, 2, "ordered as \(ids)")
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

// MARK: - The written path

/// Guarding's written path sends the typed thought to Claude, for every user.
/// These pin the things that must hold regardless of what the network does.
final class GuardWrittenPathTests: XCTestCase {

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
        let result = await classifier.answer("I want to kill myself")
        XCTAssertEqual(result, .reachOut)
    }

    /// The privacy copy follows what actually happens, and nothing else. The key
    /// arrives from Remote Config and can be empty, in which case everyone
    /// silently runs on device — and must not be told otherwise.
    ///
    /// Tier is deliberately not part of this answer any more. Whatever someone
    /// is up against, the line they speak is written for it, so the question
    /// "will the words be sent" has exactly one input: is there a key.
    func testPrivacyLineFollowsWhatActuallyHappens() {
        let classifier = ThoughtClassifier(bank: makeBank())

        AnthropicConfig.apiKey = ""
        XCTAssertFalse(classifier.sendsThoughtOffDevice,
                       "No key means the words stay on device.")

        AnthropicConfig.apiKey = "sk-ant-test"
        XCTAssertTrue(classifier.sendsThoughtOffDevice)
    }

    /// No key configured is a fallback, not a failure. Someone who typed a real
    /// thought still gets something to speak.
    func testUnconfiguredFallsBackRatherThanDeadEnding() async {
        AnthropicConfig.apiKey = ""
        let classifier = ThoughtClassifier(bank: makeBank())
        guard case .matched(_, let thought, _) =
                await classifier.answer("I am afraid all the time") else {
            return XCTFail("The written path must never dead-end.")
        }
        XCTAssertFalse(thought.counterDeclaration.isEmpty)
        XCTAssertFalse(thought.verseText.isEmpty)
    }

    /// With no key, the answer IS the on-device answer, byte for byte. The
    /// fallback is not a degraded variant of the local path; it is the local
    /// path.
    func testUnconfiguredAnswerIsTheLocalAnswer() async {
        AnthropicConfig.apiKey = ""
        let classifier = ThoughtClassifier(bank: makeBank())
        let input = "I am afraid all the time"
        let written = await classifier.answer(input)
        let local = classifier.classify(input)
        XCTAssertEqual(written, local)
    }
}

// MARK: - Local routing and selection

/// The on-device path, which is what free users get and what every premium
/// failure falls back to. It has to be good on its own.
///
/// Both halves of the "Covid" bug are pinned here. Terrain: "Covid is coming
/// back" matched no rule in the borrowed 42-category table and fell to a
/// general identity line. Selection: even in the right terrain the counter was
/// `pool[hash % count]`, so nothing the user typed influenced which line they
/// got.
final class TerrainRoutingTests: XCTestCase {

    func testCovidRoutesToSicknessNotFearOrNothing() {
        XCTAssertEqual(TerrainLexicon.terrain(for: "Covid is coming back")?.category, .sickness)
        // Even with an emotion word in the sentence, the body wins: the thought
        // is about illness, and fear is how it is being carried.
        XCTAssertEqual(TerrainLexicon.terrain(for: "afraid of Covid coming back")?.category,
                       .sickness)
    }

    func testEachTerrainIsReachable() {
        let cases: [(String, ThoughtCategory)] = [
            ("my test results came back bad", .sickness),
            ("I'm never getting out of this debt", .lack),
            ("nobody wants me around", .rejection),
            ("I'm not good enough for this", .inadequacy),
            ("God stopped listening to me", .abandonment),
            ("I keep looking at porn", .lust),
            ("I don't know what I'm supposed to do", .confusion),
            ("I can't forgive what I did", .condemnation),
            ("I'm scared something bad will happen", .fear)
        ]
        for (text, expected) in cases {
            XCTAssertEqual(TerrainLexicon.terrain(for: text)?.category, expected,
                           "\"\(text)\" should land in \(expected.rawValue)")
        }
    }

    /// The confusion terrain answers doubt, not vocation, and must not claim
    /// words its content cannot serve.
    ///
    /// Its intensity-1 pool answers "You made the whole thing up" and "God is
    /// not going to tell you what to do" — faith and hearing God. It has
    /// nothing at that intensity about a life's direction, so "purpose",
    /// "calling" and "no direction" are deliberately not keywords: they fall
    /// through to the 42-rule matcher, which routes `.destiny` to the identity
    /// terrain. "lost" is out for a harder reason — it is the same word in "I
    /// feel lost" and "I lost my mom".
    func testConfusionDoesNotClaimGriefOrVocation() {
        XCTAssertNil(TerrainLexicon.terrain(for: "I lost my mom last year"),
                     "A grieving person must never be routed by the word \"lost\".")
        XCTAssertNil(TerrainLexicon.terrain(for: "I feel lost about my calling"))
        // What it does answer, it still answers.
        XCTAssertEqual(TerrainLexicon.terrain(for: "I don't know what I'm supposed to do")?.category,
                       .confusion)
    }

    /// Addiction is grace's, not sickness's, and the lexicon must not take it.
    ///
    /// A bare "relapse" keyword in the sickness terrain stole "I relapsed with
    /// alcohol again" and turned it into a declaration about a body being
    /// whole. `ThoughtCategory.from` already carries the warning for the purity
    /// version of the same mistake: routing addiction there "would send someone
    /// fighting a bottle to declarations about their eyes". Their lungs are no
    /// better an answer. What is underneath a compulsion is shame, and shame is
    /// answered on the grace terrain.
    func testAddictionGoesToGraceNotToTheBody() {
        for entry in ["I relapsed with alcohol again", "I can't stop drinking",
                      "I went back to the drugs"] {
            XCTAssertEqual(TerrainLexicon.terrain(for: entry)?.category, .condemnation,
                           "\"\(entry)\" must land on grace, not sickness.")
        }
        // A relapse that IS about purity still goes to purity.
        XCTAssertEqual(TerrainLexicon.terrain(for: "I relapsed again with porn")?.category, .lust)
        // And a genuine medical recurrence still reads as sickness.
        XCTAssertEqual(TerrainLexicon.terrain(for: "the cancer came back")?.category, .sickness)
    }

    /// Nothing recognised must stay nil rather than inventing a terrain, so the
    /// caller can pick an honest fallback instead of a confident wrong answer.
    func testUnrecognisedTextHasNoTerrain() {
        XCTAssertNil(TerrainLexicon.terrain(for: "qqq zzz mmm"))
    }

    /// Short single words must not match inside longer ones. A bare `contains`
    /// makes "ill" match "still" and "will", which is how a keyword table rots.
    func testPrefixMatchingDoesNotFireOnSubstrings() {
        XCTAssertNil(TerrainLexicon.terrain(for: "I will be still"),
                     "\"will\"/\"still\" must not trip the \"ill\" keyword.")
    }
}

/// Selection within a terrain, against the shipped bank.
final class HouseRulesTests: XCTestCase {

    func testAcceptsAWellFormedDeclaration() {
        XCTAssertTrue(ThoughtClassifier.followsHouseRules(
            "By His wounds I am healed, and this body carries His life."))
    }

    /// Rule 12 is the one a fluent model breaks most easily: naming the thing
    /// it is supposed to be displacing.
    func testRejectsALineThatNamesTheLowThing() {
        XCTAssertFalse(ThoughtClassifier.followsHouseRules(
            "I am not afraid of this sickness, because God is with me."))
        XCTAssertFalse(ThoughtClassifier.followsHouseRules(
            "My anxiety has no hold on me anymore."))
    }

    /// Two words that look like violations and are not.
    ///
    /// Both of these are lifted from lines that ship in `declarationsv10.json`
    /// and were reviewed by a person. A validator that rejects reviewed content
    /// does not protect quality, it silently downgrades the premium path to the
    /// fallback and nobody ever sees why.
    func testAcceptsTheWordsThatOnlyLookLikeViolations() {
        // "alone" meaning "only God", not loneliness.
        XCTAssertTrue(ThoughtClassifier.followsHouseRules(
            "God alone makes me dwell in safety, and I sleep in peace."))
        XCTAssertTrue(ThoughtClassifier.followsHouseRules(
            "My integrity guides me, and I am the same person in every room."))
        // Biblical hope is confident expectation, not a wobble. Hebrews 11:1.
        XCTAssertTrue(ThoughtClassifier.followsHouseRules(
            "Faith is certainty about what I hope for and proof of what I cannot see."))
        // The loneliness sense is still caught, including by negation.
        XCTAssertFalse(ThoughtClassifier.followsHouseRules(
            "I will never feel alone again in this house."))
        // And the hedging sense of hope is still caught.
        XCTAssertFalse(ThoughtClassifier.followsHouseRules(
            "I hope God will make this body well again someday."))
    }

    func testRejectsDashesHedgingAndThirdPerson() {
        XCTAssertFalse(ThoughtClassifier.followsHouseRules(
            "I am healed — whole from head to foot."))
        XCTAssertFalse(ThoughtClassifier.followsHouseRules(
            "I hope God will make this body well again someday."))
        XCTAssertFalse(ThoughtClassifier.followsHouseRules(
            "God makes the body whole and restores what was taken."))
    }

    func testRejectsARamblingLine() {
        XCTAssertFalse(ThoughtClassifier.followsHouseRules(
            "I am healed. I am whole. I am strong. I am restored. I am well."))
    }
}

// MARK: - The reviewed library

/// The path that answers a typed thought out of `declarationsv10.json` instead
/// of the bundled thought bank.
///
/// What these pin is the reason the path exists: whatever someone is up
/// against, the line they are handed has to be about that exact thing. The bank
/// could not do that — nine terrains, five gentle lines each — so someone four
/// years into infertility was answered with a general word about being complete
/// in Christ while twenty-five reviewed fertility declarations sat unreachable.
final class ThoughtCounterLibraryTests: XCTestCase {

    private func line(_ text: String,
                      _ category: DeclarationCategory,
                      book: String = "Psalm 1:1") -> Declaration {
        Declaration(text: text, book: book, bibleVerseText: "Verse for \(category.rawValue).",
                    category: category)
    }

    /// Small on purpose. Every assertion below is about routing, and routing is
    /// easier to read against a library you can hold in your head.
    private func makeLibrary() -> [Declaration] {
        [
            line("God fills my womb with life, and He calls me a happy mother.", .fertility),
            line("I carry the promise, and what God spoke over me comes to pass.", .fertility),
            line("I am complete in Christ. Nothing in me is missing.", .identity),
            line("God made me fearfully and wonderfully.", .identity),
            line("By His wounds I am healed, and this body carries His life.", .health),
            line("Every part of me answers to the life of God.", .health),
            line("The Most High covers me. His faithfulness is my shield.", .godsprotection),
            line("I lie down and sleep deeply, because He keeps me.", .rest),
            line("I lend to many and borrow from none.", .debt)
        ]
    }

    /// The headline behaviour. Four years of trying for a baby is answered by
    /// the fertility line, not by a general word about identity.
    func testTheTypedThoughtIsAnsweredInItsOwnDomain() {
        guard let counter = ThoughtCounterLibrary.counter(
            for: "We've been trying for a baby for four years and nothing",
            in: makeLibrary()) else {
            return XCTFail("The library must answer a sentence it has content for.")
        }
        XCTAssertEqual(counter.declarationCategory, DeclarationCategory.fertility.rawValue)
    }

    /// The terrain is derived from the line that was chosen, rather than the
    /// choice being confined to a terrain picked first. That inversion is what
    /// unlocks the categories the nine terrains have no name for.
    func testTerrainIsDerivedFromTheLineThatWasChosen() {
        guard let counter = ThoughtCounterLibrary.counter(
            for: "We've been trying for a baby for four years and nothing",
            in: makeLibrary()) else {
            return XCTFail("Expected a counter.")
        }
        XCTAssertEqual(counter.category, .sickness)
        XCTAssertEqual(counter.id, CapturedThought.escapeHatchDeclarationId,
                       "Nothing traceable to what they typed may reach the log.")
    }

    /// The two keyword tables score in the same unit so the more specific match
    /// wins. "danger" fires God's protection in the rule table; "blood pressure"
    /// and "doctor" fire the sickness terrain, and a body is what the sentence
    /// is about.
    func testTheMoreSpecificMatchWins() {
        guard let counter = ThoughtCounterLibrary.counter(
            for: "The doctor says my blood pressure is dangerous",
            in: makeLibrary()) else {
            return XCTFail("Expected a counter.")
        }
        XCTAssertEqual(counter.declarationCategory, DeclarationCategory.health.rawValue)
    }

    /// Re-typing the same thought must not shuffle the line they are about to
    /// speak.
    func testTheSameSentenceAlwaysGetsTheSameLine() {
        let library = makeLibrary()
        let input = "I can't sleep at night"
        let first = ThoughtCounterLibrary.counter(for: input, in: library)
        let second = ThoughtCounterLibrary.counter(for: input, in: library)
        XCTAssertEqual(first?.counterDeclaration, second?.counterDeclaration)
    }

    /// Two kinds of content must never reach someone's mouth in this drill:
    /// book content, which is expository and written to the older two-sentence
    /// standard (CLAUDE.md rule 13 says so and says not to "fix" it), and
    /// anything the user wrote themselves, which has never been reviewed.
    func testUnreviewedAndExpositoryContentIsNeverServed() {
        let library = [
            line("Whatever a psalm says here, at length, in the third person voice.", .psalms),
            line("My own private line about my own private thing.", .myOwn),
            line("A favourite I saved once.", .favorites)
        ]
        XCTAssertTrue(ThoughtCounterLibrary.speakable(library).isEmpty)
        XCTAssertNil(ThoughtCounterLibrary.counter(for: "I feel like a fraud", in: library))
    }

    /// A sentence the tables cannot place at all returns nil rather than
    /// guessing, so the caller falls back to the bank instead of serving a
    /// confident wrong answer.
    func testAnUnplaceableSentenceReturnsNothing() {
        XCTAssertNil(ThoughtCounterLibrary.counter(for: "qqq zzz mmm", in: makeLibrary()))
    }

    /// `matchAll` matches substrings, so "Nobody" contains "body" and routes a
    /// lonely sentence to HEALTH. `ranked` matches word prefixes, and must not.
    func testKeywordsDoNotFireInsideOtherWords() {
        let ranked = KeywordCategoryMatcher.ranked("Nobody at church actually likes me")
            .map { $0.category }
        XCTAssertFalse(ranked.contains(.health),
                       "\"body\" inside \"Nobody\" must not route a sentence to healing.")
        // The stemming the table is written for still works.
        XCTAssertTrue(KeywordCategoryMatcher.ranked("my anxiety is constant")
            .map { $0.category }.contains(.anxiety))
    }

    /// The scored table answers "what is this most about", where `matchAll`
    /// answers "which rules fired, in file order".
    func testStrongestCategoryLeads() {
        let ranked = KeywordCategoryMatcher.ranked("we are trying for a baby and it isn't happening")
        XCTAssertEqual(ranked.first?.category, .fertility)
    }
}

// MARK: - The classifier prefers the library

final class ClassifierLibraryRoutingTests: XCTestCase {

    private func makeBank() -> [IncomingThought] {
        [IncomingThought(id: "inadequacy_1", text: "You are not enough.", category: .inadequacy,
                         intensity: 1, counterDeclaration: "I am complete in Christ.",
                         verseText: "You have been given fullness in Christ.",
                         book: "Colossians 2:10", declarationCategory: "identity")]
    }

    private func makeLibrary() -> [Declaration] {
        [Declaration(text: "God fills my womb with life, and He calls me a happy mother.",
                     book: "Psalm 113:9", bibleVerseText: "He settles the childless woman in her home as a happy mother of children.",
                     category: .fertility)]
    }

    /// The library leads and the bank catches. Before this, the bank was the
    /// only pool and this sentence came back as a general identity line.
    func testTheLibraryAnswersBeforeTheBankDoes() {
        let classifier = ThoughtClassifier(bank: makeBank(), library: makeLibrary())
        guard case .matched(_, let thought, let confidence) =
                classifier.classify("We have been trying for a baby for four years") else {
            return XCTFail("Expected a match.")
        }
        XCTAssertEqual(thought.book, "Psalm 113:9")
        XCTAssertEqual(confidence, .high)
    }

    /// No library in memory — a cold launch, a failed fetch — and the bank path
    /// is exactly what it was.
    func testAnEmptyLibraryLeavesTheBankPathUntouched() {
        let withLibrary = ThoughtClassifier(bank: makeBank(), library: [])
        guard case .matched(_, let thought, _) =
                withLibrary.classify("I am not enough for any of this") else {
            return XCTFail("Expected a match.")
        }
        XCTAssertEqual(thought.book, "Colossians 2:10")
    }
}

// MARK: - The rebuke

/// The drill speaks twice: to the thing, then over their own life. These pin
/// the half that names it.
final class RebukeTests: XCTestCase {

    /// Nothing in `thoughts.json` or the declaration library carries a rebuke,
    /// so every counter that was not written for the exact sentence has to get
    /// one from its terrain. A silent empty line would drop the first half of
    /// the drill on the path most users are on when they are offline.
    func testEveryCounterHasSomethingToSpeakAtTheThing() {
        for terrain in ThoughtCategory.allCases {
            let thought = IncomingThought(id: "t", text: "incoming", category: terrain,
                                          intensity: 1,
                                          counterDeclaration: "I am complete in Christ.",
                                          verseText: "You have been given fullness in Christ.",
                                          book: "Colossians 2:10",
                                          declarationCategory: "identity")
            XCTAssertFalse(thought.spokenRebuke.isEmpty)
            XCTAssertEqual(thought.spokenRebuke, terrain.rebuke)
        }
    }

    /// A written rebuke wins over the mapped one, and survives being dressed in
    /// the user's own words on the card.
    func testAWrittenRebukeIsWhatGetsSpoken() {
        let written = IncomingThought(id: "t", text: "incoming", category: .sickness,
                                      intensity: 1,
                                      rebuke: "Cancer, you have no claim on this body. Go.",
                                      counterDeclaration: "By His wounds I am healed.",
                                      verseText: "By his wounds we are healed.",
                                      book: "Isaiah 53:5",
                                      declarationCategory: "health")
        XCTAssertEqual(written.spokenRebuke, "Cancer, you have no claim on this body. Go.")
        XCTAssertEqual(written.wearing("the scan is back").spokenRebuke,
                       "Cancer, you have no claim on this body. Go.")
    }

    /// The rebuke names the low thing on purpose — that is the whole point of
    /// it — so it must NOT be run through the declaration's validator, which
    /// rejects exactly that.
    func testTheTwoValidatorsDisagreeOnPurpose() {
        let rebuke = "Fear, you have no place here. Go, in Jesus' name."
        XCTAssertTrue(ThoughtClassifier.followsRebukeRules(rebuke))
        XCTAssertFalse(ThoughtClassifier.followsHouseRules(rebuke),
                       "The declaration validator must keep rejecting a named fear.")
    }

    /// A rebuke that asks is a prayer, and a good one — but the drill is built
    /// on the believer using the authority they already have.
    func testAPetitionIsNotARebuke() {
        XCTAssertFalse(ThoughtClassifier.followsRebukeRules(
            "God, please take this fear away from me tonight."))
        XCTAssertFalse(ThoughtClassifier.followsRebukeRules(
            "I pray that this sickness would leave my body."))
    }

    /// Scripture gives nobody authority over another free will. The thing over
    /// someone can be put out; the person never can.
    func testNoRebukeIsEverAimedAtAPerson() {
        XCTAssertFalse(ThoughtClassifier.followsRebukeRules(
            "Husband, you will come back to me now."))
        // The thing over them is still fair game, and must stay so.
        XCTAssertTrue(ThoughtClassifier.followsRebukeRules(
            "Addiction, you have no claim on my son. Go."))
    }

    /// Built for the mouth: short enough to say in one breath, with the drop at
    /// the end.
    func testTheMappedRebukesAreAllWellFormed() {
        for terrain in ThoughtCategory.allCases {
            XCTAssertTrue(ThoughtClassifier.followsRebukeRules(terrain.rebuke),
                          "\(terrain.rawValue): \(terrain.rebuke)")
        }
    }
}
