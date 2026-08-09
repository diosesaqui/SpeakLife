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
                                       source: .escapeHatch, spoken: true)
        let second = service.takeGround(category: .lack, thoughtId: "b",
                                        source: .escapeHatch, spoken: true)
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
                                          source: .daily, spoken: true), 1)
        XCTAssertEqual(service.takeGround(category: .fear, thoughtId: "a",
                                          source: .daily, spoken: true), 1)
        XCTAssertTrue(service.completedToday)

        XCTAssertEqual(service.takeGround(category: .lack, thoughtId: "b",
                                          source: .escapeHatch, spoken: true), 2)
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
                           spoken: true)

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
        service.takeGround(category: .lack, thoughtId: "a", source: .escapeHatch, spoken: true)
        service.takeGround(category: .lack, thoughtId: "b", source: .escapeHatch, spoken: true)
        service.takeGround(category: .fear, thoughtId: "c", source: .escapeHatch, spoken: true)

        XCTAssertEqual(service.strongestTerrain(), .lack)
        // And it is named as ground, never as a diagnosis.
        XCTAssertEqual(ThoughtCategory.lack.terrainName, "provision")
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

    func testRowIsAbsentWhenThePillarIsDark() {
        // nil = kill switch off, or the bank failed to load.
        let tasks = TaskLibrary.getCoreTasksForStreak(30, guardCompletedToday: nil)
        XCTAssertFalse(tasks.contains { $0.id == TaskLibrary.guardTaskId },
                       "A task nobody can finish is worse than no task.")
    }

    func testRowIsHeldBackUntilTheCoreLoopHasTakenHold() {
        for day in 1..<TaskLibrary.guardIntroducedOnDay {
            let tasks = TaskLibrary.getCoreTasksForStreak(day, guardCompletedToday: false)
            XCTAssertFalse(tasks.contains { $0.id == TaskLibrary.guardTaskId },
                           "Day \(day) must stay light so the streak is easy to earn.")
        }
        let tasks = TaskLibrary.getCoreTasksForStreak(TaskLibrary.guardIntroducedOnDay,
                                                      guardCompletedToday: false)
        XCTAssertTrue(tasks.contains { $0.id == TaskLibrary.guardTaskId })
    }

    /// Guarding is a lifelong daily habit like speaking and hearing, not a
    /// first-week exercise. It must survive every progression phase — the bug
    /// this pins is the row silently vanishing around day 8 when the phase mix
    /// narrows.
    func testRowSurvivesEveryPhase() {
        for day in [3, 7, 8, 30, 31, 99, 100, 365] {
            let tasks = TaskLibrary.getCoreTasksForStreak(day, guardCompletedToday: false)
            XCTAssertTrue(tasks.contains { $0.id == TaskLibrary.guardTaskId },
                          "Guard row went missing on day \(day)")
        }
    }

    func testRowSitsDirectlyBehindTheBurst() {
        let tasks = TaskLibrary.getCoreTasksForStreak(30, guardCompletedToday: false)
        guard let burst = tasks.firstIndex(where: { $0.id == "complete_daily_burst" }),
              let guardRow = tasks.firstIndex(where: { $0.id == TaskLibrary.guardTaskId }) else {
            return XCTFail("Both rows should be present.")
        }
        XCTAssertEqual(guardRow, burst + 1, "Speaking leads; guarding holds what speaking took.")
    }

    func testRowCompletionIsDerivedFromTheService() {
        let done = TaskLibrary.getCoreTasksForStreak(30, guardCompletedToday: true)
        XCTAssertEqual(done.first { $0.id == TaskLibrary.guardTaskId }?.isCompleted, true)

        let notDone = TaskLibrary.getCoreTasksForStreak(30, guardCompletedToday: false)
        XCTAssertEqual(notDone.first { $0.id == TaskLibrary.guardTaskId }?.isCompleted, false)
    }

    /// Adding a pillar must not change what earns a streak. Someone who never
    /// opens Guarding has lost nothing.
    func testGuardNeverGatesTheStreak() {
        var tasks = TaskLibrary.getCoreTasksForStreak(30, guardCompletedToday: false)
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
        let tasks = TaskLibrary.getCoreTasksForStreak(30, guardCompletedToday: false)
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

    func testMoneyThoughtMapsToProvisionTerrain() {
        let classifier = ThoughtClassifier(bank: makeBank())
        guard case .matched(let category, _, let confidence) =
                classifier.classify("I'm drowning in debt and can't pay the bills") else {
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
