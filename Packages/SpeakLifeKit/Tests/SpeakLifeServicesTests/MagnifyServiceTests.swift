//
//  MagnifyServiceTests.swift
//  SpeakLifeServicesTests
//
//  The rotation engine, the continuity guarantees, and storm mode.
//
//  The bugs these pin were all paid for once in the pillar this replaced, and
//  the engine was ported across specifically because they had been. Every one of
//  them is a test here rather than a comment.
//

import XCTest
@testable import SpeakLifeCore
@testable import SpeakLifeServices

private func makeEntry(_ id: String,
                       domain: MagnifyDomain,
                       intensity: Int = 1) -> MagnifyEntry {
    MagnifyEntry(id: id,
                 domain: domain,
                 intensity: intensity,
                 nameOfGod: "Name \(id)",
                 attribute: "Attribute \(id)",
                 exaltation: "You are the God of \(id).",
                 declaration: "I stand in what You are, \(id).",
                 verseText: "Verse \(id)",
                 book: "Book \(id):1",
                 declarationCategory: "identity")
}

/// A full-shape bank: 9 domains, 15 each, 5 per intensity — the shape every
/// rotation constant assumes.
private func makeBank() -> [MagnifyEntry] {
    var bank: [MagnifyEntry] = []
    for domain in MagnifyDomain.allCases {
        for index in 0..<15 {
            bank.append(makeEntry("\(domain.rawValue)_\(index)",
                                  domain: domain,
                                  intensity: index / 5 + 1))
        }
    }
    return bank
}

private func freshDefaults(_ name: String = UUID().uuidString) -> UserDefaults {
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    return defaults
}

private func makeService(defaults: UserDefaults,
                         bank: [MagnifyEntry]? = nil,
                         whyLines: [String] = ["Whatever you magnify, you get more of.",
                                               "He was always this big."],
                         enabled: Bool = true) -> MagnifyService {
    MagnifyService(defaults: defaults,
                   calendar: .current,
                   bank: bank ?? makeBank(),
                   whyLines: whyLines,
                   syncCounters: {},
                   featureFlags: StaticFeatureFlags(["guardEnabled": enabled]))
}

// MARK: - Serving

final class MagnifyServiceServingTests: XCTestCase {

    /// Rule 2 in the service header. Rotation reads live signals, so re-deriving
    /// on every read could hand someone a different facet mid-flow — they would
    /// behold one name of God and be asked to speak the line belonging to another.
    func testTodaysEntryIsPinnedForTheDay() {
        let service = makeService(defaults: freshDefaults())
        let first = service.entry(isPremium: true)
        XCTAssertNotNil(first)
        for _ in 0..<5 {
            XCTAssertEqual(service.entry(isPremium: true)?.id, first?.id)
        }
    }

    /// A tapped domain is new information from the user, arriving after the pin
    /// was set. Honouring the stale pin would mean ignoring the one thing they
    /// explicitly told us.
    func testATappedDomainOverridesThePin() {
        let service = makeService(defaults: freshDefaults())
        _ = service.entry(isPremium: true)
        let picked = service.entry(isPremium: true, domain: .healing)
        XCTAssertEqual(picked?.domain, .healing)
    }

    /// A free user who taps a domain must still get that domain — which is
    /// exactly why the free slice is built per domain rather than as a flat
    /// prefix of the bank.
    func testFreeSliceStillHonoursEveryDomain() {
        let service = makeService(defaults: freshDefaults())
        let slice = service.freeSlice()
        XCTAssertEqual(slice.count, MagnifyDomain.allCases.count * MagnifyService.freeEntriesPerDomain)
        for domain in MagnifyDomain.allCases {
            let picked = service.entry(isPremium: false, domain: domain)
            XCTAssertEqual(picked?.domain, domain, "A free user must reach \(domain.rawValue).")
        }
    }

    /// The ladder protects new users. Never open someone on the deepest facet in
    /// the bank.
    func testNewUserOnlySeesIntensityOne() {
        let service = makeService(defaults: freshDefaults())
        XCTAssertEqual(service.intensityCeiling(), 1)
        XCTAssertEqual(service.entry(isPremium: true)?.intensity, 1)
    }

    /// The bug this exists for: with a flat "has been served" penalty, every
    /// candidate scored identically once the free pool was exhausted, the id
    /// tie-break fired, and the same entry was served every single day from then
    /// on. A free user's rep quietly froze. Scoring by how long ago turns the
    /// exhausted case into a proper least-recently-used rotation.
    func testFreeRotationDoesNotFreezeOnceThePoolIsExhausted() {
        let defaults = freshDefaults()
        let service = makeService(defaults: defaults)
        var seen: [String] = []
        // Far more days than the free pool holds, so the cooldown relaxes away.
        for _ in 0..<40 {
            defaults.removeObject(forKey: "magnifyPinnedEntry")
            guard let entry = service.entry(isPremium: false) else { return XCTFail("No entry.") }
            seen.append(entry.id)
        }
        XCTAssertGreaterThan(Set(seen).count, 1,
                             "The rotation must not collapse onto a single entry.")
    }

    /// Two devices on the same day must land on the same facet, or a user with an
    /// iPhone and an iPad sees two different names of God for one rep.
    func testSelectionIsDeterministicAcrossInstances() {
        let bank = makeBank()
        let a = makeService(defaults: freshDefaults(), bank: bank).entry(isPremium: true)
        let b = makeService(defaults: freshDefaults(), bank: bank).entry(isPremium: true)
        XCTAssertEqual(a?.id, b?.id)
    }

    /// A rep with no facet is a dead end the user cannot fix, so selection falls
    /// back rather than returning nil on a non-empty bank.
    func testNeverReturnsNilOnANonEmptyBank() {
        let single = [makeEntry("only", domain: .peace, intensity: 3)]
        let service = makeService(defaults: freshDefaults(), bank: single)
        XCTAssertNotNil(service.entry(isPremium: false),
                        "Even one deep entry against a ceiling of 1 must still serve.")
    }
}

// MARK: - Completing

final class MagnifyServiceCompletionTests: XCTestCase {

    func testMagnifyingBanksTheRepAndTicksTheDay() {
        let service = makeService(defaults: freshDefaults())
        XCTAssertFalse(service.isCompletedToday)
        let total = service.magnify(domain: .peace, entryId: "x", source: .daily,
                                    spoken: true, completesDailyRep: true)
        XCTAssertEqual(total, 1)
        XCTAssertTrue(service.isCompletedToday)
        XCTAssertEqual(service.enabledCompletedToday, true)
    }

    /// A double-tap must not inflate the count.
    func testTheDayRepIsIdempotent() {
        let service = makeService(defaults: freshDefaults())
        _ = service.magnify(domain: .peace, entryId: "x", source: .daily,
                            spoken: true, completesDailyRep: true)
        let again = service.magnify(domain: .peace, entryId: "x", source: .daily,
                                    spoken: true, completesDailyRep: true)
        XCTAssertEqual(again, 1, "The day's rep may only be banked once.")
    }

    /// Extra reps beyond the day's are each their own and always count.
    func testExtraRepsAlwaysCount() {
        let service = makeService(defaults: freshDefaults())
        _ = service.magnify(domain: .peace, entryId: "x", source: .daily,
                            spoken: true, completesDailyRep: true)
        let extra = service.magnify(domain: .healing, entryId: "y", source: .extra,
                                    spoken: true, completesDailyRep: false)
        XCTAssertEqual(extra, 2)
    }

    /// Rule 1: nothing in the service can decrease. There is no method that
    /// clears the count, and this is the test that stops one being added.
    func testTheCountOnlyEverGoesUp() {
        let defaults = freshDefaults()
        let service = makeService(defaults: defaults)
        var last = 0
        for index in 0..<12 {
            let total = service.magnify(domain: .peace, entryId: "x\(index)", source: .extra,
                                        spoken: true, completesDailyRep: false)
            XCTAssertGreaterThan(total, last)
            last = total
        }
        XCTAssertEqual(TimesMagnified.total(defaults: defaults), last)
    }

    /// Only day-reps advance the ladder. Counting every rep let fourteen extras
    /// on day one unlock the deepest intensity on day two, which is exactly the
    /// gentle opening the ladder exists to protect.
    func testExtraRepsDoNotAdvanceTheIntensityLadder() {
        let service = makeService(defaults: freshDefaults())
        for index in 0..<20 {
            _ = service.magnify(domain: .peace, entryId: "x\(index)", source: .extra,
                                spoken: true, completesDailyRep: false)
        }
        XCTAssertEqual(service.intensityCeiling(), 1)
    }
}

// MARK: - Storm mode

final class MagnifyStormTests: XCTestCase {

    /// Rule 4: storm mode is never metered, never gated, and never spends the
    /// day's pin. A storm at midnight must not cost the morning its facet.
    func testStormDoesNotConsumeTheDaysPin() {
        let service = makeService(defaults: freshDefaults())
        let pinned = service.entry(isPremium: true)
        XCTAssertNotNil(service.stormEntry())
        XCTAssertEqual(service.entry(isPremium: true)?.id, pinned?.id,
                       "Storm mode must leave the day's pinned facet alone.")
    }

    /// It has to work for a brand-new free user with nothing behind them. That
    /// is precisely who reaches for it.
    func testStormServesOnADeadColdInstall() {
        let service = makeService(defaults: freshDefaults())
        XCTAssertNotNil(service.stormEntry())
    }

    func testStormRespectsTheIntensityCeiling() {
        let service = makeService(defaults: freshDefaults())
        XCTAssertEqual(service.stormEntry()?.intensity, 1)
    }
}

// MARK: - Continuity across the rename

final class MagnifyContinuityTests: XCTestCase {

    /// The load-bearing one. A user with reps behind them must not be reset to
    /// zero on upgrade day, so the counter key is deliberately unchanged.
    func testAnExistingCountCarriesOver() {
        let defaults = freshDefaults()
        defaults.set(412, forKey: "totalThoughtsTakenCaptive")
        let service = makeService(defaults: defaults)
        XCTAssertEqual(service.timesMagnified, 412)
        XCTAssertEqual(TimesMagnified.counterKey, "totalThoughtsTakenCaptive",
                       "Renaming this key would silently reset every existing user.")
    }

    /// Someone who already did today's rep under the old pillar must not be asked
    /// to do it again on the day they upgrade.
    func testTodaysCompletionCarriesOver() {
        let defaults = freshDefaults()
        defaults.set(MagnifyService.dayStamp(Date(), calendar: .current),
                     forKey: "guardLastCompletedDay")
        XCTAssertTrue(makeService(defaults: defaults).isCompletedToday)
    }

    /// A long-tenured user must not be demoted to the gentlest facets in the bank.
    func testTheIntensityLadderCarriesOver() {
        let defaults = freshDefaults()
        defaults.set(400, forKey: "guardCompletionCount")
        XCTAssertEqual(makeService(defaults: defaults).intensityCeiling(), 3)
    }

    /// Engagement is the signal for where a person's fight actually is, earned one
    /// rep at a time over months. Dropping it would quietly reset every tenured
    /// user to an unweighted rotation with nothing on screen explaining why.
    func testLegacyEngagementIsMigratedOnce() {
        let defaults = freshDefaults()
        defaults.set(["sickness": 9, "lack": 4, "bogus": 3], forKey: "guardCategoryEngagement")
        let service = makeService(defaults: defaults)
        XCTAssertEqual(service.strongestDomain(), .healing,
                       "\"sickness\" must migrate to the healing domain.")

        let migrated = defaults.dictionary(forKey: "magnifyDomainEngagement") as? [String: Int]
        XCTAssertEqual(migrated?["healing"], 9)
        XCTAssertEqual(migrated?["provision"], 4)
        XCTAssertNil(migrated?["bogus"], "Unmappable legacy keys are dropped, not crashed on.")

        // Second construction must not double-count.
        _ = makeService(defaults: defaults)
        let again = defaults.dictionary(forKey: "magnifyDomainEngagement") as? [String: Int]
        XCTAssertEqual(again?["healing"], 9, "Migration must run exactly once.")
    }

    /// Every legacy terrain must land somewhere, or a returning user loses part of
    /// their history for no reason.
    func testEveryLegacyTerrainMaps() {
        for raw in ["fear", "condemnation", "lack", "rejection", "sickness",
                    "inadequacy", "abandonment", "confusion", "lust"] {
            XCTAssertNotNil(MagnifyDomain.fromLegacyRawValue(raw), "\(raw) must map.")
        }
    }
}

// MARK: - Kill switch and the teaching layer

final class MagnifyPillarStateTests: XCTestCase {

    /// nil leaves the checklist row out entirely rather than offering a task that
    /// cannot be finished.
    func testDarkPillarReportsNil() {
        XCTAssertNil(makeService(defaults: freshDefaults(), enabled: false).enabledCompletedToday)
        XCTAssertNil(makeService(defaults: freshDefaults(), bank: []).enabledCompletedToday)
    }

    /// Stable for the whole day: someone who opens the rep twice must not be told
    /// two different reasons.
    func testWhyLineIsStableWithinADay() {
        let service = makeService(defaults: freshDefaults())
        XCTAssertNotNil(service.whyLine())
        XCTAssertEqual(service.whyLine(), service.whyLine())
    }

    /// `BeholdView` tolerates a nil line and simply holds its shape, so an empty
    /// pool must not trap or crash the rep.
    func testAnEmptyWhyPoolIsSupported() {
        XCTAssertNil(makeService(defaults: freshDefaults(), whyLines: []).whyLine())
    }

    /// One-way. Someone a month in does not need to be taught it again.
    func testWhySeenIsOneWay() {
        let service = makeService(defaults: freshDefaults())
        XCTAssertFalse(service.hasSeenWhy)
        service.markWhySeen()
        XCTAssertTrue(service.hasSeenWhy)
    }

    /// Stale intent requests are dropped: a flag written minutes ago belongs to a
    /// launch that already happened, and firing off it would ambush someone who
    /// opened the app for something else.
    func testPendingLaunchIsConsumedOnceAndExpires() {
        let defaults = freshDefaults()
        MagnifyService.requestPendingLaunch(storm: true, defaults: defaults)
        XCTAssertTrue(MagnifyService.consumePendingLaunch(defaults: defaults))
        XCTAssertTrue(MagnifyService.consumePendingStorm(defaults: defaults))
        XCTAssertFalse(MagnifyService.consumePendingLaunch(defaults: defaults),
                       "A request may only be consumed once.")

        MagnifyService.requestPendingLaunch(defaults: defaults)
        XCTAssertFalse(MagnifyService.consumePendingLaunch(defaults: defaults,
                                                           now: Date().addingTimeInterval(300)),
                       "A stale request must be dropped.")
    }
}

// MARK: - Model

final class MagnifyEntryTests: XCTestCase {

    /// `ExaltAndDeclareView` primes the verifier with the two lines joined and
    /// splits the matched indices at exactly `exaltationWords.count`.
    func testSpokenLineJoinsCleanly() {
        let entry = makeEntry("x", domain: .peace)
        XCTAssertEqual(entry.spokenLine, "\(entry.exaltation) \(entry.declaration)")
        XCTAssertEqual(entry.spokenLine.split(separator: " ").count,
                       entry.exaltation.split(separator: " ").count
                       + entry.declaration.split(separator: " ").count)
    }

    /// Only the declaration moves on the written route. The answer to "here is
    /// what I'm carrying" is not a rewritten God — it is this God, over that thing.
    func testAnsweringOnlyReplacesTheDeclaration() {
        let base = makeEntry("x", domain: .healing, intensity: 2)
        let answered = base.answering((declaration: "I am whole.",
                                       verseText: "V", book: "B:1", category: "health"))
        XCTAssertEqual(answered.nameOfGod, base.nameOfGod)
        XCTAssertEqual(answered.exaltation, base.exaltation)
        XCTAssertEqual(answered.domain, base.domain)
        XCTAssertEqual(answered.intensity, base.intensity)
        XCTAssertEqual(answered.declaration, "I am whole.")
        XCTAssertEqual(answered.id, MagnifiedMoment.writtenEntryId,
                       "A written rep must not be logged against a bank entry the user never saw.")
    }

    /// Rule 3: the low thing is never named, not even in a raw value.
    func testNoDomainNamesTheLowThing() {
        let banned = ["fear", "lack", "sickness", "lust", "shame", "condemnation",
                      "rejection", "inadequacy", "abandonment", "confusion"]
        for domain in MagnifyDomain.allCases {
            XCTAssertFalse(banned.contains(domain.rawValue),
                           "\(domain.rawValue) names what is being displaced, not the ground taken.")
            let copy = (domain.chipTitle + " " + domain.groundName).lowercased()
            for word in banned {
                XCTAssertFalse(copy.contains(word), "\(domain.rawValue) copy names \"\(word)\".")
            }
        }
    }

    /// Every fallback is spoken UP, to God. These are what a user gets when the
    /// bank fails, and a fallback that slipped into commanding a thing would
    /// reintroduce the rule-12 exception this pillar exists without.
    func testEveryFallbackExaltationIsAddressedToGod() {
        for domain in MagnifyDomain.allCases {
            let lowered = domain.fallbackExaltation.lowercased()
            XCTAssertTrue(lowered.contains("you"),
                          "\(domain.rawValue) fallback must speak to God: \(domain.fallbackExaltation)")
        }
    }
}
