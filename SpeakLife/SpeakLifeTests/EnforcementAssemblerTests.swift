//
//  EnforcementAssemblerTests.swift
//  SpeakLifeTests
//
//  Assembly turns 4 hand-authored campaigns into coverage for every
//  life-situation category. The properties that would break silently:
//
//  - Determinism. Swift's `hashValue` is seeded per process, so a naive sort
//    would hand the user a different day-3 line on every launch and the campaign
//    would stop feeling like a campaign.
//  - No repeats. A seven-day week that says the same thing twice is a bug the
//    user notices immediately.
//  - Real coverage. The point of the feature is that someone facing addiction or
//    a failing marriage gets *their* week, so the shipped pool must actually be
//    able to build one for every category we offer.
//

import XCTest
@testable import SpeakLife

final class EnforcementAssemblerTests: XCTestCase {

    // MARK: - Fixtures

    private func declarations(_ category: DeclarationCategory, _ count: Int) -> [Declaration] {
        (1...count).map { n in
            Declaration(text: "\(category.rawValue) line \(n)",
                        book: "Book \(n):\(n)",
                        bibleVerseText: "verse \(n)",
                        category: category)
        }
    }

    // MARK: - Determinism

    func testAssembly_IsDeterministicForTheSameSeed() {
        let pool = declarations(.addiction, 40)
        let a = EnforcementAssembler.assemble(primary: .addiction, pool: pool, seed: "seed-1")
        let b = EnforcementAssembler.assemble(primary: .addiction, pool: pool, seed: "seed-1")

        XCTAssertNotNil(a)
        XCTAssertEqual(a?.days.map(\.anchorText), b?.days.map(\.anchorText),
                       "the same seed must always produce the same week")
    }

    func testAssembly_DiffersBetweenSeeds() {
        let pool = declarations(.addiction, 40)
        let a = EnforcementAssembler.assemble(primary: .addiction, pool: pool, seed: "user-A")
        let b = EnforcementAssembler.assemble(primary: .addiction, pool: pool, seed: "user-B")

        XCTAssertNotEqual(a?.days.map(\.anchorText), b?.days.map(\.anchorText),
                          "two users facing the same thing shouldn't get identical weeks")
    }

    /// Guards against someone swapping in `String.hashValue`, which is seeded per
    /// process and would silently reshuffle the campaign on every app launch.
    func testStableHash_IsConstantAcrossCalls() {
        XCTAssertEqual(EnforcementAssembler.stableHash("marriage"),
                       EnforcementAssembler.stableHash("marriage"))
        XCTAssertNotEqual(EnforcementAssembler.stableHash("marriage"),
                          EnforcementAssembler.stableHash("addiction"))
    }

    // MARK: - Shape

    func testAssembly_ProducesSevenNumberedDays() {
        let pool = declarations(.hardtimes, 20)
        let result = EnforcementAssembler.assemble(primary: .hardtimes, pool: pool, seed: "s")

        XCTAssertEqual(result?.days.count, Enforcement.length)
        XCTAssertEqual(result?.days.map(\.dayNumber), Array(1...Enforcement.length))
    }

    func testAssembly_NeverRepeatsADeclaration() {
        let pool = declarations(.rest, 12)
        let result = EnforcementAssembler.assemble(primary: .rest, pool: pool, seed: "s")

        let texts = result?.days.map(\.anchorText) ?? []
        XCTAssertEqual(Set(texts).count, texts.count, "no line may appear twice in one week")
    }

    func testAssembly_EveryDayHasAudio() {
        let pool = declarations(.parenting, 20)
        let result = EnforcementAssembler.assemble(primary: .parenting, pool: pool, seed: "s")

        for day in result?.days ?? [] {
            XCTAssertFalse(day.audioId.isEmpty, "day \(day.dayNumber) has no audio")
            XCTAssertFalse(day.audioTitle.isEmpty)
        }
    }

    func testAssembly_ReturnsNilWhenPoolTooThin() {
        let pool = declarations(.grief, 3)   // fewer than seven
        XCTAssertNil(EnforcementAssembler.assemble(primary: .grief, pool: pool, seed: "s"))
    }

    // MARK: - Blending

    func testBlend_TwoCategoriesSplitFourThree() {
        XCTAssertEqual(EnforcementAssembler.dayShares(for: 2), [4, 3])
        XCTAssertEqual(EnforcementAssembler.dayShares(for: 1), [7])
        XCTAssertEqual(EnforcementAssembler.dayShares(for: 3), [3, 2, 2])
        XCTAssertEqual(EnforcementAssembler.dayShares(for: 9), [3, 2, 2],
                       "never split a week finer than three themes")
    }

    /// "My marriage is falling apart and I can't sleep" must not produce seven
    /// days that ignore the sleep.
    func testBlend_SecondaryCategoryAppearsInTheWeek() {
        let pool = declarations(.marriage, 20) + declarations(.rest, 20)
        let result = EnforcementAssembler.assemble(primary: .marriage,
                                                   secondaries: [.rest],
                                                   pool: pool, seed: "s")

        let texts = result?.days.map(\.anchorText) ?? []
        XCTAssertEqual(texts.filter { $0.hasPrefix("marriage") }.count, 4)
        XCTAssertEqual(texts.filter { $0.hasPrefix("rest") }.count, 3)
    }

    func testBlend_LeadCategoryOpensTheWeek() {
        let pool = declarations(.marriage, 20) + declarations(.rest, 20)
        let result = EnforcementAssembler.assemble(primary: .marriage,
                                                   secondaries: [.rest],
                                                   pool: pool, seed: "s")

        XCTAssertTrue(result?.days.first?.anchorText.hasPrefix("marriage") ?? false,
                      "the week opens on the thing they actually named")
        XCTAssertEqual(result?.theme, DeclarationCategory.marriage.rawValue)
    }

    func testBlend_ThinSecondaryTopsUpFromLead() {
        // Only two `rest` declarations exist, so the lead must cover the rest.
        let pool = declarations(.marriage, 20) + declarations(.rest, 2)
        let result = EnforcementAssembler.assemble(primary: .marriage,
                                                   secondaries: [.rest],
                                                   pool: pool, seed: "s")

        XCTAssertEqual(result?.days.count, Enforcement.length)
        let texts = result?.days.map(\.anchorText) ?? []
        XCTAssertEqual(Set(texts).count, texts.count)
    }

    // MARK: - Book categories

    /// declarationsv10 buckets content by book as well as by life situation.
    /// Nobody is walking through "a hard week of Leviticus".
    func testBookCategories_AreNotCampaignable() {
        XCTAssertFalse(EnforcementAssembler.isCampaignable(.psalms))
        XCTAssertFalse(EnforcementAssembler.isCampaignable(.romans))
        XCTAssertTrue(EnforcementAssembler.isCampaignable(.addiction))
        XCTAssertTrue(EnforcementAssembler.isCampaignable(.marriage))
    }

    func testAssembly_RejectsABookCategoryAsPrimary() {
        let pool = declarations(.psalms, 40)
        XCTAssertNil(EnforcementAssembler.assemble(primary: .psalms, pool: pool, seed: "s"),
                     "a book of the Bible is not a life situation")
    }

    // MARK: - Against the real shipped pool

    /// The whole premise is that someone facing addiction or a failing marriage
    /// gets their own week. That's only true if the shipped declarations can
    /// actually fill seven days for each category we're willing to match.
    func testShippedPool_CanBuildACampaignForEveryOfferedCategory() {
        guard let url = Bundle.main.url(forResource: "declarationsv10", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return XCTFail("declarationsv10.json missing from the bundle")
        }
        let decoded = try? JSONDecoder().decode(WelcomeResponse.self, from: data)
        let pool = decoded?.declarations ?? []
        XCTAssertFalse(pool.isEmpty, "declaration pool failed to decode")

        var built: [String] = []
        var failed: [String] = []
        for category in DeclarationCategory.allCases where EnforcementAssembler.isCampaignable(category) {
            let count = pool.filter { $0.category == category }.count
            guard count >= Enforcement.length else { continue }   // not offered
            if EnforcementAssembler.assemble(primary: category, pool: pool, seed: "s") != nil {
                built.append(category.rawValue)
            } else {
                failed.append(category.rawValue)
            }
        }

        XCTAssertTrue(failed.isEmpty, "these categories have enough declarations but failed to assemble: \(failed)")
        XCTAssertGreaterThanOrEqual(built.count, 20,
                                    "expected broad coverage, only built \(built.count): \(built)")
    }
}
