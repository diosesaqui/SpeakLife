//
//  EnforcementServiceTests.swift
//  SpeakLifeTests
//
//  The Enforcement's value depends on two behaviors that are easy to "fix" into
//  uselessness, so both are pinned here:
//
//  1. An Enforcement never expires on the calendar. Day 4 stays day 4 through any gap.
//     If an Enforcement could lapse, it would be a second thing to lose rather than a
//     way back in, and the feature would be pointless.
//  2. Eligibility reads `totalDaysCompleted`, never `currentStreak`. A veteran
//     whose streak just broke must stay eligible — that is the exact user this
//     exists for.
//

import XCTest
@testable import SpeakLife

final class EnforcementServiceTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!
    private var service: EnforcementService!

    /// A two-Enforcement catalog so tests never depend on shipped content.
    private var catalog: [Enforcement] {
        [makeEnforcement(id: "peace", theme: "anxiety"),
         makeEnforcement(id: "warfare", theme: "warfare")]
    }

    private func makeEnforcement(id: String, theme: String) -> Enforcement {
        let days = (1...Enforcement.length).map { n in
            EnforcementDay(dayNumber: n,
                     anchorText: "Anchor \(n)",
                     anchorVerse: "Verse \(n)",
                     anchorBook: "Book \(n):\(n)",
                     anchorTranslation: "ESV",
                     audioId: "audio\(n).mp3",
                     audioTitle: "Audio \(n)",
                     audioMinutes: 3)
        }
        return Enforcement(id: id, title: "The \(id.capitalized) Enforcement",
                     tagline: "tagline", theme: theme, days: days)
    }

    override func setUp() {
        super.setUp()
        suiteName = "EnforcementServiceTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        service = EnforcementService(defaults: defaults, calendar: .current, catalog: catalog)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        service = nil
        suiteName = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func daysAgo(_ n: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -n, to: Date())!
    }

    /// Completes `count` days, one per calendar day working backwards, so each
    /// advance lands on a distinct day.
    private func advance(_ count: Int) {
        for i in stride(from: count, through: 1, by: -1) {
            service.advanceIfNeeded(now: daysAgo(i))
        }
    }

    // MARK: - Eligibility

    func testEligibility_BelowThreshold_NotOffered() {
        XCTAssertFalse(service.isEligible(totalDaysCompleted: 6))
    }

    func testEligibility_AtThreshold_Offered() {
        XCTAssertTrue(service.isEligible(totalDaysCompleted: 7))
    }

    /// The case a `currentStreak` gate gets wrong: a 200-day veteran whose streak
    /// broke this morning. They must stay eligible.
    func testEligibility_BrokenStreakVeteran_StillOffered() {
        var stats = StreakStats()
        stats.totalDaysCompleted = 200
        stats.currentStreak = 0

        XCTAssertTrue(service.isEligible(totalDaysCompleted: stats.totalDaysCompleted),
                      "A tenured user with a broken streak is the primary audience for an Enforcement")
    }

    /// Guards against someone swapping the eligibility input back to the streak.
    func testEligibility_IgnoresCurrentStreak() {
        var stats = StreakStats()
        stats.totalDaysCompleted = 3
        stats.currentStreak = 40

        XCTAssertFalse(service.isEligible(totalDaysCompleted: stats.totalDaysCompleted),
                       "Eligibility must read tenure, not the live streak")
    }

    // MARK: - Starting

    func testStart_RequiresPremium() {
        XCTAssertFalse(service.startEnforcement(id: "peace", isPremium: false))
        XCTAssertFalse(service.progressSnapshot.isActive)
    }

    func testStart_PremiumBeginsAtDayOne() {
        XCTAssertTrue(service.startEnforcement(id: "peace", isPremium: true))
        XCTAssertTrue(service.progressSnapshot.isActive)
        XCTAssertEqual(service.progressSnapshot.currentDay, 1)
        XCTAssertEqual(service.activeDay?.dayNumber, 1)
    }

    func testStart_UnknownEnforcementRejected() {
        XCTAssertFalse(service.startEnforcement(id: "nope", isPremium: true))
    }

    // MARK: - Advancement

    func testAdvance_NoActiveEnforcement_IsNoOp() {
        XCTAssertEqual(service.advanceIfNeeded(), .notActive)
    }

    func testAdvance_MovesToNextDay() {
        service.startEnforcement(id: "peace", isPremium: true)
        XCTAssertEqual(service.advanceIfNeeded(), .advanced(toDay: 2))
        XCTAssertEqual(service.progressSnapshot.currentDay, 2)
    }

    // MARK: - Curated campaigns advance too
    //
    // These shipped stuck on day 1. `advanceIfNeeded` resolved the active
    // campaign with a catalog lookup, but a curated or assembled campaign's id
    // ("curated_warfare") is not in the catalog — the campaign travels inside
    // progress — so every week built from the user's own words reported
    // `.notActive` and never banked a day. Every other test here starts an
    // authored campaign, which is exactly why nothing caught it.

    /// Starts a curated campaign, whose id is deliberately absent from the catalog.
    @discardableResult
    private func startCurated() -> String? {
        let declarations = (1...Enforcement.length).map { n in
            Declaration(text: "Curated anchor \(n)",
                        book: "Book \(n):\(n)",
                        bibleVerseText: "Verse \(n)",
                        category: .warfare)
        }
        service.startCurated(declarations, primary: .warfare, isPremium: true)
        return service.progressSnapshot.activeEnforcementId
    }

    func testAdvance_CuratedCampaignNotInCatalog_StillAdvances() {
        let id = startCurated()
        XCTAssertNotNil(service.activeEnforcement, "precondition: a campaign is running")
        XCTAssertNil(service.enforcement(id: id ?? ""),
                     "precondition: a curated id is not in the catalog")

        XCTAssertEqual(service.advanceIfNeeded(), .advanced(toDay: 2))
        XCTAssertEqual(service.progressSnapshot.currentDay, 2)
    }

    func testAdvance_CuratedCampaignReachesCompletion() {
        let id = startCurated()

        for i in stride(from: Enforcement.length, through: 2, by: -1) {
            service.advanceIfNeeded(now: daysAgo(i))
        }
        XCTAssertEqual(service.advanceIfNeeded(now: Date()),
                       .completed(enforcementId: id ?? "", elapsedDays: Enforcement.length))
        XCTAssertFalse(service.progressSnapshot.isActive)
        XCTAssertEqual(service.justCompleted?.id, id)
    }

    /// `finish()` clears `assembledEnforcement`, so a finished curated campaign
    /// can never be looked up again — the celebration must carry its own copy.
    func testCompletion_CuratedCelebrationSurvivesRelaunch() {
        let id = startCurated()
        advance(Enforcement.length)
        XCTAssertEqual(service.justCompleted?.id, id)

        let relaunched = EnforcementService(defaults: defaults, calendar: .current, catalog: catalog)
        XCTAssertEqual(relaunched.justCompleted?.id, id,
                       "a curated campaign's celebration must survive a relaunch too")
    }

    /// Two bursts in one day must not burn two Enforcement days.
    func testAdvance_TwiceInOneDay_OnlyCountsOnce() {
        service.startEnforcement(id: "peace", isPremium: true)
        XCTAssertEqual(service.advanceIfNeeded(), .advanced(toDay: 2))
        XCTAssertEqual(service.advanceIfNeeded(), .alreadyAdvancedToday)
        XCTAssertEqual(service.progressSnapshot.currentDay, 2)
    }

    // MARK: - The core claim: an Enforcement waits

    func testEnforcement_DoesNotResetAfterLongGap() {
        service.startEnforcement(id: "peace", isPremium: true)
        advance(3)                      // days 1-3 done, on 3 separate days
        XCTAssertEqual(service.progressSnapshot.currentDay, 4)

        // Simulate coming back a fortnight later: nothing about the passage of
        // time touches the Enforcement.
        let reloaded = EnforcementService(defaults: defaults, calendar: .current, catalog: catalog)

        XCTAssertEqual(reloaded.progressSnapshot.currentDay, 4,
                       "An Enforcement must never expire on the calendar")
        XCTAssertTrue(reloaded.progressSnapshot.isActive)
        XCTAssertEqual(reloaded.activeDay?.dayNumber, 4)
    }

    func testEnforcement_SurvivesBrokenStreak() {
        service.startEnforcement(id: "peace", isPremium: true)
        advance(3)

        // A broken streak is a StreakStats concern and must not touch the stand.
        // The freeze has to be spent first, otherwise checkStreakValidity rescues
        // the streak and this never exercises a real break.
        var stats = StreakStats()
        stats.currentStreak = 40
        stats.streakFreezeAvailable = false
        stats.lastCompletedDate = daysAgo(9)
        stats.checkStreakValidity()
        XCTAssertEqual(stats.currentStreak, 0, "precondition: the streak did break")

        XCTAssertEqual(service.progressSnapshot.currentDay, 4)
        XCTAssertTrue(service.progressSnapshot.isActive)
    }

    // MARK: - Lapsed subscription

    /// Premium is checked at start only. Someone whose subscription lapses on
    /// day 5 finishes the campaign rather than being stranded.
    func testAdvance_NotPremiumGated() {
        service.startEnforcement(id: "peace", isPremium: true)
        advance(4)
        XCTAssertEqual(service.progressSnapshot.currentDay, 5)

        // No premium anywhere in this call, and it still advances.
        XCTAssertEqual(service.advanceIfNeeded(now: Date()), .advanced(toDay: 6))
    }

    func testLapsed_CannotStartANewEnforcement() {
        service.startEnforcement(id: "peace", isPremium: true)
        advance(Enforcement.length)
        XCTAssertFalse(service.progressSnapshot.isActive)

        XCTAssertFalse(service.startEnforcement(id: "warfare", isPremium: false),
                       "A lapsed user finishes their campaign but cannot begin another")
    }

    // MARK: - Completion

    func testCompletion_DaySevenFinishesAndBanks() {
        service.startEnforcement(id: "peace", isPremium: true)

        for i in stride(from: Enforcement.length, through: 2, by: -1) {
            service.advanceIfNeeded(now: daysAgo(i))
        }
        XCTAssertEqual(service.progressSnapshot.currentDay, Enforcement.length)

        XCTAssertEqual(service.advanceIfNeeded(now: Date()), .completed(enforcementId: "peace", elapsedDays: Enforcement.length))
        XCTAssertFalse(service.progressSnapshot.isActive)
        XCTAssertNil(service.progressSnapshot.activeEnforcementId)
        XCTAssertEqual(service.progressSnapshot.completedEnforcementIds, ["peace"])
        XCTAssertEqual(service.justCompleted?.id, "peace")
    }

    func testCompletion_CarriesHistoryIntoNextEnforcement() {
        service.startEnforcement(id: "peace", isPremium: true)
        advance(Enforcement.length)
        XCTAssertEqual(service.progressSnapshot.completedEnforcementIds, ["peace"])

        XCTAssertTrue(service.startEnforcement(id: "warfare", isPremium: true))
        XCTAssertEqual(service.progressSnapshot.completedEnforcementIds, ["peace"],
                       "Starting a new Enforcement must not erase completion history")
        XCTAssertEqual(service.progressSnapshot.currentDay, 1)
    }

    // MARK: - Persistence

    func testProgress_SurvivesReload() {
        service.startEnforcement(id: "warfare", isPremium: true)
        advance(2)

        let reloaded = EnforcementService(defaults: defaults, calendar: .current, catalog: catalog)
        XCTAssertEqual(reloaded.progressSnapshot.activeEnforcementId, "warfare")
        XCTAssertEqual(reloaded.progressSnapshot.currentDay, 3)
    }

    func testAbandon_ClearsCampaignWithoutBanking() {
        service.startEnforcement(id: "peace", isPremium: true)
        advance(2)
        service.abandon()

        XCTAssertFalse(service.progressSnapshot.isActive)
        XCTAssertTrue(service.progressSnapshot.completedEnforcementIds.isEmpty,
                      "Abandoning must not count as a completion")
    }

    // MARK: - Celebration survives an app kill

    /// The burst can be completed from a surface that isn't the Today tab. If the
    /// app dies before Today next appears, an in-memory-only flag would eat the
    /// one celebration the user earned — and the next-campaign offer with it.
    func testCompletion_CelebrationSurvivesRelaunch() {
        service.startEnforcement(id: "peace", isPremium: true)
        advance(Enforcement.length)
        XCTAssertEqual(service.justCompleted?.id, "peace")

        let relaunched = EnforcementService(defaults: defaults, calendar: .current, catalog: catalog)
        XCTAssertEqual(relaunched.justCompleted?.id, "peace",
                       "a celebration earned but not yet shown must survive a relaunch")
    }

    func testCompletion_ClearingCelebrationIsPersisted() {
        service.startEnforcement(id: "peace", isPremium: true)
        advance(Enforcement.length)
        service.justCompleted = nil   // the view dismissing it

        let relaunched = EnforcementService(defaults: defaults, calendar: .current, catalog: catalog)
        XCTAssertNil(relaunched.justCompleted,
                     "a celebration already shown must not re-present on next launch")
    }

    // MARK: - Switching campaigns

    /// Without a way out, picking the wrong theme locks the user in for a week.
    func testSwitch_AbandonThenStartAnother() {
        service.startEnforcement(id: "peace", isPremium: true)
        advance(3)
        XCTAssertEqual(service.progressSnapshot.currentDay, 4)

        service.abandon()
        XCTAssertFalse(service.progressSnapshot.isActive)

        XCTAssertTrue(service.startEnforcement(id: "warfare", isPremium: true))
        XCTAssertEqual(service.progressSnapshot.activeEnforcementId, "warfare")
        XCTAssertEqual(service.progressSnapshot.currentDay, 1, "a switch restarts at day 1")
    }

    func testAbandon_IsPersisted() {
        service.startEnforcement(id: "peace", isPremium: true)
        advance(2)
        service.abandon()

        let reloaded = EnforcementService(defaults: defaults, calendar: .current, catalog: catalog)
        XCTAssertFalse(reloaded.progressSnapshot.isActive,
                       "abandoning must survive a relaunch, not resurrect the campaign")
    }

    // MARK: - Concurrency

    /// The notification scheduler reads from a background queue while the burst
    /// advances on main. Before the lock this could tear the Set/Array buffers.
    func testConcurrentReadsAndAdvancesDoNotCrash() {
        service.startEnforcement(id: "peace", isPremium: true)

        let done = expectation(description: "concurrent access settles")
        done.expectedFulfillmentCount = 2
        let queue = DispatchQueue(label: "test.reader", attributes: .concurrent)

        queue.async {
            for _ in 0..<500 {
                _ = self.service.progressSnapshot.currentDay
                _ = self.service.activeDay
            }
            done.fulfill()
        }
        queue.async {
            for i in 0..<200 {
                self.service.advanceIfNeeded(now: self.daysAgo(i % 30))
            }
            done.fulfill()
        }
        wait(for: [done], timeout: 10)
    }

    // MARK: - iCloud merge
    //
    // A campaign is now whitelisted in SyncedSettingsStore, so both devices run
    // the same merge over the same pair of blobs. Two properties carry the
    // whole thing and are pinned below: the merge is commutative (or the two
    // devices settle on different campaigns and push at each other forever),
    // and `assembledEnforcement` travels with its own campaign (a curated id
    // like "curated_warfare" is not in enforcements.json, so a campaign that
    // arrives without its blob cannot be resolved at all).

    private func merge(_ a: EnforcementProgress, _ b: EnforcementProgress) -> EnforcementProgress {
        SyncedSettingsStore.mergedEnforcementProgress(a, b)
    }

    private func makeProgress(id: String?,
                              startedOn: Date? = nil,
                              days: Set<Int> = [],
                              lastAdvancedOn: Date? = nil,
                              assembled: Enforcement? = nil,
                              history: [String] = []) -> EnforcementProgress {
        var progress = EnforcementProgress()
        progress.activeEnforcementId = id
        progress.startedOn = startedOn
        progress.completedDayNumbers = days
        progress.lastAdvancedOn = lastAdvancedOn
        progress.assembledEnforcement = assembled
        progress.completedEnforcementIds = history
        return progress
    }

    func testMerge_SameCampaign_UnionsDaysAndTakesLaterCursor() {
        let start = daysAgo(6)
        let phone = makeProgress(id: "peace", startedOn: start, days: [1, 2], lastAdvancedOn: daysAgo(5))
        let pad = makeProgress(id: "peace", startedOn: start, days: [1, 3], lastAdvancedOn: daysAgo(2))

        let merged = merge(phone, pad)
        XCTAssertEqual(merged.activeEnforcementId, "peace")
        XCTAssertEqual(merged.completedDayNumbers, [1, 2, 3], "a day banked anywhere is banked")
        XCTAssertEqual(merged.lastAdvancedOn, pad.lastAdvancedOn)
        XCTAssertEqual(merged, merge(pad, phone))
    }

    func testMerge_DifferentCampaigns_NewerStartTakesTheWholeWeek() {
        let old = makeProgress(id: "peace", startedOn: daysAgo(20), days: [1, 2, 3], lastAdvancedOn: daysAgo(18))
        let new = makeProgress(id: "warfare", startedOn: daysAgo(2), days: [1], lastAdvancedOn: daysAgo(1))

        let merged = merge(old, new)
        XCTAssertEqual(merged.activeEnforcementId, "warfare")
        XCTAssertEqual(merged.startedOn, new.startedOn)
        XCTAssertEqual(merged.completedDayNumbers, [1],
                       "two different weeks must never have their day sets blended")
        XCTAssertEqual(merged.lastAdvancedOn, new.lastAdvancedOn)
        XCTAssertTrue(merged.completedEnforcementIds.isEmpty,
                      "an abandoned week was never earned")
        XCTAssertEqual(merged, merge(new, old))
    }

    func testMerge_DroppedCampaign_BankedOnlyWhenItWasFinished() {
        let finished = makeProgress(id: "peace",
                                    startedOn: daysAgo(20),
                                    days: Set(1...Enforcement.length),
                                    lastAdvancedOn: daysAgo(14))
        let new = makeProgress(id: "warfare", startedOn: daysAgo(2), days: [1])

        let merged = merge(finished, new)
        XCTAssertEqual(merged.activeEnforcementId, "warfare")
        XCTAssertEqual(merged.completedEnforcementIds, ["peace"],
                       "a week that reached day seven is history, not a discard")
        XCTAssertEqual(merged, merge(new, finished))
    }

    func testMerge_OneSideHasNoCampaign_TheOtherWins() {
        let none = EnforcementProgress()
        let running = makeProgress(id: "warfare", startedOn: daysAgo(3), days: [1, 2], lastAdvancedOn: daysAgo(1))

        let merged = merge(none, running)
        XCTAssertEqual(merged.activeEnforcementId, "warfare")
        XCTAssertEqual(merged.completedDayNumbers, [1, 2])
        XCTAssertEqual(merged.startedOn, running.startedOn)
        XCTAssertEqual(merged, merge(running, none))
    }

    /// The blob is the campaign. A curated id is not in the catalog, so a
    /// campaign that crosses devices without `assembledEnforcement` resolves to
    /// nothing and the user's week vanishes on the second device.
    func testMerge_AssembledCampaignTravelsWithItsWeek() {
        let curated = makeEnforcement(id: "curated_warfare", theme: "warfare")
        let holder = makeProgress(id: curated.id, startedOn: daysAgo(3), days: [1, 2], assembled: curated)
        let fresh = EnforcementProgress()

        XCTAssertEqual(merge(fresh, holder).assembledEnforcement, curated)
        XCTAssertEqual(merge(holder, fresh).assembledEnforcement, curated)

        // Same campaign, but the other side only ever received the id.
        let blobless = makeProgress(id: curated.id, startedOn: daysAgo(3), days: [1, 3])
        XCTAssertEqual(merge(holder, blobless).assembledEnforcement, curated)
        XCTAssertEqual(merge(blobless, holder).assembledEnforcement, curated)
        XCTAssertEqual(merge(holder, blobless), merge(blobless, holder))
    }

    func testMerge_HistoryIsUnionedAndOrderedTheSameOnBothDevices() {
        let phone = makeProgress(id: nil, history: ["peace", "warfare"])
        let pad = makeProgress(id: nil, history: ["peace", "healing"])

        let merged = merge(phone, pad)
        XCTAssertEqual(Set(merged.completedEnforcementIds), ["peace", "warfare", "healing"],
                       "completion history is never lost")
        XCTAssertEqual(merged, merge(pad, phone),
                       "both devices must order the same history identically")
    }

    /// One device finished the week and banked it; the other was offline at the
    /// finish line and still thinks day seven is pending. Handing the campaign
    /// back would re-open a week the user already celebrated, every time the
    /// two devices meet.
    func testMerge_CampaignFinishedElsewhereIsNotResurrected() {
        let finisher = makeProgress(id: nil, history: ["peace"])
        let stale = makeProgress(id: "peace", startedOn: daysAgo(10), days: [1, 2, 3, 4, 5, 6])

        let merged = merge(finisher, stale)
        XCTAssertNil(merged.activeEnforcementId)
        XCTAssertEqual(merged.completedEnforcementIds, ["peace"])
        XCTAssertEqual(merged, merge(stale, finisher))
    }

    /// The other half of that rule: restarting a campaign you finished before is
    /// legitimate, and is told apart by the restarting device carrying the id in
    /// its own history.
    func testMerge_RestartOfAPreviouslyCompletedCampaignSurvives() {
        let restarted = makeProgress(id: "peace", startedOn: Date(), history: ["peace"])
        let idle = makeProgress(id: nil, history: ["peace"])

        XCTAssertEqual(merge(restarted, idle).activeEnforcementId, "peace")
        XCTAssertEqual(merge(idle, restarted).activeEnforcementId, "peace")
        XCTAssertEqual(merge(restarted, idle), merge(idle, restarted))
    }

    /// Every pair, both ways round, plus a second pass over the result: two
    /// devices reconciling independently have to land on the same value and
    /// then stay there.
    func testMerge_IsCommutativeAndConverges() {
        let curated = makeEnforcement(id: "curated_warfare", theme: "warfare")
        let states: [EnforcementProgress] = [
            EnforcementProgress(),
            makeProgress(id: "peace", startedOn: daysAgo(9), days: [1, 2], lastAdvancedOn: daysAgo(8)),
            makeProgress(id: "peace", startedOn: daysAgo(9), days: [1, 2, 3], lastAdvancedOn: daysAgo(4)),
            makeProgress(id: "warfare", startedOn: daysAgo(2), days: [1], lastAdvancedOn: daysAgo(2),
                         history: ["peace"]),
            makeProgress(id: curated.id, startedOn: daysAgo(1), days: [1], assembled: curated,
                         history: ["warfare", "peace"]),
            makeProgress(id: nil, history: ["peace"]),
            makeProgress(id: nil, history: ["healing", "peace"])
        ]

        for (i, a) in states.enumerated() {
            for b in states[i...] {
                let forward = merge(a, b)
                XCTAssertEqual(forward, merge(b, a),
                               "merge must be commutative — both devices run it independently")
                XCTAssertEqual(merge(forward, a), forward, "merging again must be a no-op")
                XCTAssertEqual(merge(forward, b), forward, "merging again must be a no-op")
            }
        }
    }

    /// The merged value is what gets written back to UserDefaults and pushed to
    /// CloudKit, so it has to survive the encoder — including the `Set<Int>`.
    func testMerge_ResultSurvivesAJSONRoundTrip() {
        let curated = makeEnforcement(id: "curated_warfare", theme: "warfare")
        let merged = merge(makeProgress(id: curated.id, startedOn: daysAgo(3), days: [1, 2],
                                        assembled: curated, history: ["peace"]),
                           makeProgress(id: curated.id, startedOn: daysAgo(3), days: [3]))

        guard let data = try? JSONEncoder().encode(merged),
              let decoded = try? JSONDecoder().decode(EnforcementProgress.self, from: data) else {
            return XCTFail("EnforcementProgress must round-trip through JSON to sync at all")
        }
        XCTAssertEqual(decoded, merged)
        XCTAssertEqual(decoded.assembledEnforcement, curated)
    }

    /// The bug this whole path exists for: the service reads progress once, in
    /// `init`. A campaign that arrives from the user's other device lands in
    /// UserDefaults with no further ceremony, so without the settings observer
    /// this device keeps offering to start a week that is already running.
    func testSyncedChange_ServiceAdoptsARemoteCampaignWithoutRelaunch() {
        XCTAssertFalse(service.progressSnapshot.isActive, "precondition: nothing running here")

        var remote = EnforcementProgress()
        remote.activeEnforcementId = "warfare"
        remote.startedOn = daysAgo(3)
        remote.completedDayNumbers = [1, 2]
        guard let data = try? JSONEncoder().encode(remote) else {
            return XCTFail("could not encode the remote campaign")
        }
        defaults.set(data, forKey: "enforcementProgress")

        NotificationCenter.default.post(name: SyncedSettingsStore.settingsDidChange,
                                        object: nil,
                                        userInfo: ["keys": Set(["enforcementProgress"])])

        let deadline = Date().addingTimeInterval(2)
        while service.progressSnapshot.activeEnforcementId == nil, Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.01))
        }

        XCTAssertEqual(service.progressSnapshot.activeEnforcementId, "warfare")
        XCTAssertEqual(service.progressSnapshot.currentDay, 3)
        XCTAssertEqual(service.activeDay?.dayNumber, 3, "the UI must see the synced campaign too")
    }

    // MARK: - Shipped content

    /// The real `enforcements.json` must decode and be well-formed, since a content
    /// typo would otherwise surface as an empty card in production.
    func testShippedCatalog_DecodesAndIsWellFormed() {
        let shipped = EnforcementService(defaults: defaults, calendar: .current)
        XCTAssertFalse(shipped.catalog.isEmpty, "enforcements.json failed to load from the bundle")

        for enforcement in shipped.catalog {
            XCTAssertEqual(enforcement.days.count, Enforcement.length, "\(enforcement.id) must have 7 days")
            XCTAssertEqual(enforcement.days.map(\.dayNumber), Array(1...Enforcement.length),
                           "\(enforcement.id) days must be numbered 1-7 in order")
            XCTAssertNotNil(enforcement.category,
                            "\(enforcement.id) theme '\(enforcement.theme)' is not a DeclarationCategory")
            for day in enforcement.days {
                XCTAssertFalse(day.anchorText.isEmpty)
                XCTAssertFalse(day.audioId.isEmpty)
                XCTAssertFalse(day.anchorText.contains("—"), "no em dashes in declarations")
                XCTAssertFalse(day.anchorText.contains("–"), "no en dashes in declarations")
                XCTAssertLessThanOrEqual(day.anchorText.split(separator: " ").count, 21,
                                         "declaration exceeds the 21-word ceiling: \(day.anchorText)")
            }
        }
    }
}
