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

    /// The card shows the reference under the line and the push appends it, so a
    /// declaration without one leaves a blank row and a push trailing in " ~ ".
    func testAssembly_SkipsDeclarationsWithNoScriptureReference() {
        var pool = declarations(.hope, 7)
        pool += (1...20).map { n in
            Declaration(text: "hope unreferenced \(n)", book: nil,
                        bibleVerseText: nil, category: .hope)
        }
        let result = EnforcementAssembler.assemble(primary: .hope, pool: pool, seed: "s")

        XCTAssertEqual(result?.days.count, Enforcement.length)
        for day in result?.days ?? [] {
            XCTAssertFalse(day.anchorBook.isEmpty,
                           "day \(day.dayNumber) has no reference: \(day.anchorText)")
            XCTAssertFalse(day.anchorText.contains("unreferenced"))
        }
    }

    func testAssembly_ReturnsNilWhenOnlyUnreferencedDeclarationsExist() {
        let pool = (1...20).map { n in
            Declaration(text: "no ref \(n)", book: nil, bibleVerseText: nil, category: .favor)
        }
        XCTAssertNil(EnforcementAssembler.assemble(primary: .favor, pool: pool, seed: "s"),
                     "better no campaign than seven blank references")
    }

    /// Thin *and* nothing to fall back on — the fallback chain is walked first,
    /// so this only fails because no category in the chain has content either.
    func testAssembly_ReturnsNilWhenPoolTooThin() {
        let pool = declarations(.grief, 3)   // fewer than seven, no siblings present
        XCTAssertNil(EnforcementAssembler.assemble(primary: .grief, pool: pool, seed: "s"))
    }

    // MARK: - Never fail on a clean input
    //
    // Seventeen categories the matcher can return ship with no declarations of
    // their own. Before the fallback chain, "I want to start a business" matched
    // `business`, found nothing, and the user was told their own words couldn't
    // build a week. These lock the guarantee that never happens again.

    func testAssembly_EmptyCategoryStillBuildsAWeekFromItsSiblings() {
        // Nothing in the pool is `business` — exactly the shipped situation.
        let pool = declarations(.destiny, 20) + declarations(.work, 20) + declarations(.wealth, 20)
        let result = EnforcementAssembler.assemble(primary: .business, pool: pool, seed: "s")

        XCTAssertEqual(result?.days.count, Enforcement.length)
        let texts = result?.days.map(\.anchorText) ?? []
        XCTAssertEqual(Set(texts).count, texts.count, "no line may appear twice")
    }

    /// The week is named after what they said, not after where the lines came
    /// from. Someone who typed a business goal should not see "Enforcing Destiny".
    func testAssembly_FallbackWeekKeepsTheNameOfWhatTheyMatched() {
        let pool = declarations(.destiny, 20) + declarations(.work, 20)
        let result = EnforcementAssembler.assemble(primary: .business, pool: pool, seed: "s")

        XCTAssertEqual(result?.theme, DeclarationCategory.business.rawValue)
        XCTAssertEqual(result?.title, "Enforcing " + DeclarationCategory.business.name)
    }

    /// A substitute carries at most three days, so an empty match blends its
    /// siblings instead of turning into seven days of one borrowed theme.
    func testAssembly_NoSubstituteCarriesMoreThanThreeDays() {
        let pool = declarations(.destiny, 20) + declarations(.work, 20) + declarations(.wealth, 20)
        let result = EnforcementAssembler.assemble(primary: .business, pool: pool, seed: "s")

        let texts = result?.days.map(\.anchorText) ?? []
        for prefix in ["destiny", "work", "wealth"] {
            XCTAssertLessThanOrEqual(texts.filter { $0.hasPrefix(prefix) }.count, 3,
                                     "\(prefix) took over a week that was meant to blend")
        }
    }

    /// A matched category is not a substitute: when a secondary runs thin the
    /// lead still covers the whole remainder, which is the pre-existing behavior.
    func testAssembly_MatchedLeadStillCarriesMoreThanThreeDays() {
        let pool = declarations(.marriage, 20) + declarations(.rest, 1)
        let result = EnforcementAssembler.assemble(primary: .marriage,
                                                   secondaries: [.rest],
                                                   pool: pool, seed: "s")

        let texts = result?.days.map(\.anchorText) ?? []
        XCTAssertEqual(texts.filter { $0.hasPrefix("marriage") }.count, 6)
    }

    /// A category with no content and no mapping still lands somewhere real.
    func testAssembly_UnmappedEmptyCategoryFallsBackToTheUniversalBackstop() {
        XCTAssertNil(EnforcementAssembler.contentFallbacks[.godsheart],
                     "this test is only meaningful while godsheart is unmapped")
        let pool = declarations(.faith, 20)
        let result = EnforcementAssembler.assemble(primary: .godsheart, pool: pool, seed: "s")

        XCTAssertEqual(result?.days.count, Enforcement.length)
        XCTAssertEqual(result?.theme, DeclarationCategory.godsheart.rawValue)
    }

    func testFallbackChain_LeadsWithTheMatchedCategoriesAndEndsInTheBackstop() {
        let chain = EnforcementAssembler.fallbackChain(for: [.business, .work])

        XCTAssertEqual(Array(chain.prefix(2)), [.business, .work],
                       "what they said is always drawn from first")
        for backstop in EnforcementAssembler.universalFallback {
            XCTAssertTrue(chain.contains(backstop), "\(backstop.rawValue) missing from the chain")
        }
        XCTAssertEqual(Set(chain).count, chain.count, "the chain must not repeat a category")
    }

    func testFallbackChain_DropsBookCategories() {
        let chain = EnforcementAssembler.fallbackChain(for: [.psalms, .grief])
        XCTAssertFalse(chain.contains(.psalms))
        XCTAssertTrue(chain.contains(.grief))
    }

    /// Every fallback target must itself be campaignable and must exist in the
    /// shipped pool, or the chain just relocates the dead end.
    func testFallbackTargets_AreAllCampaignable() {
        for (source, targets) in EnforcementAssembler.contentFallbacks {
            XCTAssertTrue(EnforcementAssembler.isCampaignable(source),
                          "\(source.rawValue) is mapped but can never be matched")
            for target in targets {
                XCTAssertTrue(EnforcementAssembler.isCampaignable(target),
                              "\(source.rawValue) falls back to \(target.rawValue), a book category")
            }
        }
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

    // MARK: - Curated path

    /// Claude returns indexes, never text, so a curated week is still made
    /// entirely of reviewed declarations — in the order it chose.
    func testCurated_PreservesTheChosenOrder() {
        let picked = declarations(.addiction, Enforcement.length)
        let result = EnforcementAssembler.assemble(curated: picked, primary: .addiction)

        XCTAssertEqual(result?.days.map(\.anchorText), picked.map(\.text))
        XCTAssertEqual(result?.days.map(\.dayNumber), Array(1...Enforcement.length))
        XCTAssertEqual(result?.theme, DeclarationCategory.addiction.rawValue)
    }

    func testCurated_RejectsWrongDayCount() {
        XCTAssertNil(EnforcementAssembler.assemble(curated: declarations(.hope, 5), primary: .hope))
        XCTAssertNil(EnforcementAssembler.assemble(curated: declarations(.hope, 9), primary: .hope))
    }

    /// The shortlist the curator sees must be reviewed content only: right
    /// categories, and every one carrying a scripture reference.
    func testCurationCandidates_SpanTheMatchedCategoriesAndAreReferenced() {
        var pool = declarations(.marriage, 10) + declarations(.rest, 10)
        pool += [Declaration(text: "no ref", book: nil, bibleVerseText: nil, category: .marriage)]

        let candidates = EnforcementAssembler.candidates(for: [.marriage, .rest],
                                                         in: pool, seed: "s")
        XCTAssertEqual(candidates.count, 20)
        XCTAssertFalse(candidates.contains { $0.text == "no ref" })
        XCTAssertTrue(candidates.contains { $0.category == .marriage })
        XCTAssertTrue(candidates.contains { $0.category == .rest })
    }

    func testCurationCandidates_ExcludeBookCategories() {
        let pool = declarations(.psalms, 20) + declarations(.joy, 10)
        let candidates = EnforcementAssembler.candidates(for: [.psalms, .joy], in: pool, seed: "s")

        XCTAssertFalse(candidates.contains { $0.category == .psalms })
        XCTAssertEqual(candidates.count, 10)
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

    /// The guarantee, end to end: **every** category Claude is allowed to return
    /// builds a real seven-day week against the shipped pool.
    ///
    /// Seventeen of them — business, grief, debt, mentalHealth and the rest —
    /// have no declarations of their own; they reach seven days only through the
    /// fallback chain. Read straight out of `AnthropicConfig.systemPrompt` so a
    /// category added to the prompt without content fails here rather than in
    /// someone's hands.
    func testShippedPool_BuildsAWeekForEveryCategoryClaudeCanReturn() {
        let names = categoriesClaudeCanReturn()
        XCTAssertGreaterThanOrEqual(names.count, 40,
                                    "failed to parse the category list out of the system prompt")

        guard let url = Bundle.main.url(forResource: "declarationsv10", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let pool = try? JSONDecoder().decode(WelcomeResponse.self, from: data).declarations,
              !pool.isEmpty else {
            return XCTFail("declarationsv10.json missing or undecodable")
        }

        var unknown: [String] = []
        var unbuildable: [String] = []
        var noCandidates: [String] = []

        for name in names {
            guard let category = DeclarationCategory(rawValue: name) else {
                unknown.append(name)
                continue
            }
            if EnforcementAssembler.assemble(primary: category, pool: pool, seed: "s") == nil {
                unbuildable.append(name)
            }
            // The curated path needs a shortlist too, or curation silently drops
            // and only the assembled week survives.
            if EnforcementAssembler.candidates(for: [category], in: pool, seed: "s").count
                < Enforcement.length {
                noCandidates.append(name)
            }
        }

        XCTAssertTrue(unknown.isEmpty, "system prompt offers categories the app has no case for: \(unknown)")
        XCTAssertTrue(unbuildable.isEmpty, "no seven-day week can be built for: \(unbuildable)")
        XCTAssertTrue(noCandidates.isEmpty, "curator would get an empty shortlist for: \(noCandidates)")
    }

    // MARK: - Screening what we won't build a week on
    //
    // The expensive failure here is not a miss — Claude backstops those inside
    // `curate`. It's a false positive: telling a grieving or furious person that
    // what they're carrying is out of bounds. So the false-positive test below
    // is the one that matters most, and it's the one to extend first whenever a
    // phrase is added to the local screen.

    func testScreen_DeclinesAnotherPersonsPartner() {
        let inputs = [
            "I'm believing for someone else's husband to notice me",
            "I want another man's wife",
            "I'm tired of being his side chick"
        ]
        for input in inputs {
            XCTAssertEqual(SituationScreen.screen(input),
                           .redirect(.anotherPersonsPartner),
                           "not screened: \(input)")
        }
    }

    func testScreen_DeclinesHarmToAnother() {
        let inputs = [
            "I want to get revenge on my brother",
            "I'm believing God will make him suffer for what he did",
            "I want to ruin his life the way he ruined mine",
            "I hope she dies"
        ]
        for input in inputs {
            XCTAssertEqual(SituationScreen.screen(input),
                           .redirect(.harmToAnother),
                           "not screened: \(input)")
        }
    }

    func testScreen_CatchesSelfHarmAndDoesNotBuildACampaign() {
        let inputs = [
            "I want to kill myself",
            "I have no reason to live anymore",
            "everyone would be better off without me",
            "I have been suicidal for weeks",
            "I'm having thoughts of suicide again"
        ]
        for input in inputs {
            XCTAssertEqual(SituationScreen.screen(input), .reachOut, "not caught: \(input)")
        }
    }

    /// The one that must never regress. Every line here is something a real
    /// believer types on a bad day, and every one collides with a phrase on the
    /// screen lists. If any of these starts getting declined, the feature is
    /// telling hurting people their pain is out of bounds.
    func testScreen_LetsThroughHardButLegitimateInput() {
        let inputs = [
            // Collides with the self-harm list, means the opposite.
            "I want to die to self and live for Christ",
            "I'm learning to die daily like Paul said",
            // Grief and death of others — not self-harm.
            "my husband died in March and I can't breathe",
            "my dad is dying of cancer and I'm believing for a miracle",
            // An affair done TO them: the most common painful input there is.
            "I'm believing for my marriage after my husband's affair",
            "my wife had an affair and I want our family restored",
            // Money owed — collides with a revenge phrasing we deliberately cut.
            "I'm believing God will make them pay me what they owe",
            // Anger, doubt, and desperation are all allowed.
            "I am furious at God right now and I don't know why He let this happen",
            "I hate my job and every day feels pointless",
            "my wife left me and I started drinking again",
            // Ordinary vision input.
            "I'm believing God to start my own business",
            // Bereavement by suicide. Bare "suicide" used to route this to the
            // personal-safety message: no campaign, no scripture, and a reply
            // aimed at the wrong person entirely.
            "I lost my son to suicide last year and I need God",
            "my best friend died by suicide and I can't stop replaying it",
            // Praying someone OUT of a marriage that is hurting them.
            "I'm believing my daughter will leave her husband who hits her",
            "praying my brother will leave his wife's abuse behind",
            // A betrayed spouse naming the other woman.
            "my husband and his mistress destroyed our family, I want healing",
            // The idiom, not revenge.
            "I fell off my routine and I'm ready to get back at it"
        ]
        for input in inputs {
            XCTAssertEqual(SituationScreen.screen(input), .standable,
                           "wrongly screened: \(input)")
        }
    }

    // MARK: - Campaign titles

    /// The title is the loudest type on the card, and it used to be built from
    /// `name`, a browse label. That shipped "Enforcing Warfare & Victory",
    /// "Enforcing Anxiety & Worry" and "Enforcing Hard Times" — the card
    /// announcing that the user is enforcing the thing they came here to beat.
    func testTitle_NamesTheVictoryNeverTheStruggle() {
        let expected: [DeclarationCategory: String] = [
            .warfare:   "Enforcing Victory",
            .anxiety:   "Enforcing Peace",
            .fear:      "Enforcing Courage",
            .hardtimes: "Enforcing Strength",
            .addiction: "Enforcing Freedom",
            .health:    "Enforcing Healing",
            .wealth:    "Enforcing Provision",
            .business:  "Enforcing Increase"
        ]
        let pool = declarations(.faith, 40)
        for (category, title) in expected {
            let assembled = EnforcementAssembler.assemble(primary: category, pool: pool, seed: "s")
            XCTAssertEqual(assembled?.title, title, "\(category.rawValue) titled wrong")

            let curated = EnforcementAssembler.assemble(curated: declarations(.faith, Enforcement.length),
                                                        primary: category)
            XCTAssertEqual(curated?.title, title, "\(category.rawValue) curated title drifted from assembled")
        }
    }

    /// Guards the whole surface, not just the eight above: no campaign title may
    /// contain a word for the thing being fought.
    func testTitle_NeverContainsAStrugglingWord() {
        let forbidden = ["anxiety", "worry", "fear", "hard times", "addiction",
                         "warfare", "grief", "divorce", "debt", "sick", "depress"]
        for category in DeclarationCategory.allCases
        where EnforcementAssembler.isCampaignable(category) {
            let title = "Enforcing \(category.enforcementTitle)".lowercased()
            for word in forbidden {
                XCTAssertFalse(title.contains(word),
                               "\(category.rawValue) produces \"\(title)\", which names the struggle")
            }
        }
    }

    /// The hand-authored campaigns set the pattern the assembled path has to
    /// match, so a theme present in both must read the same either way.
    func testTitle_AssembledMatchesTheHandAuthoredCatalogPattern() {
        XCTAssertEqual("Enforcing " + DeclarationCategory.warfare.enforcementTitle, "Enforcing Victory")
        XCTAssertEqual("Enforcing " + DeclarationCategory.anxiety.enforcementTitle, "Enforcing Peace")
        XCTAssertEqual("Enforcing " + DeclarationCategory.wealth.enforcementTitle, "Enforcing Provision")
        XCTAssertEqual("Enforcing " + DeclarationCategory.health.enforcementTitle, "Enforcing Healing")
    }

    /// The one message in the app that must not be wrong, and the one most
    /// likely to drift now that two screens show it.
    func testReachOutCopy_OffersTheSupportAddressAfterAPerson() {
        let message = SituationScreen.reachOutMessage
        XCTAssertTrue(message.contains(SituationScreen.supportEmail))
        XCTAssertEqual(SituationScreen.supportEmail, "speaklife@diosesaqui.com")

        // A person comes before the address: email is not answered in the
        // moment, so it must never read as the emergency path.
        let person = message.range(of: "right now")
        let address = message.range(of: SituationScreen.supportEmail)
        XCTAssertNotNil(person)
        XCTAssertNotNil(address)
        if let person, let address {
            XCTAssertLessThan(person.lowerBound, address.lowerBound,
                              "the address must not come before 'reach out to someone you trust right now'")
        }
    }

    func testScreen_MapsClaudeDeclineCodes() {
        XCTAssertEqual(EnforcementCurator.redirect(forCode: "another_persons_partner"),
                       .anotherPersonsPartner)
        XCTAssertEqual(EnforcementCurator.redirect(forCode: "harm_to_another"),
                       .harmToAnother)
    }

    /// A model that invents a reason has still said it won't back this. Guessing
    /// a week from that is the one outcome worse than a vague message.
    func testScreen_UnknownDeclineCodeStillDeclines() {
        XCTAssertEqual(EnforcementCurator.redirect(forCode: "something_new"), .unscriptural)
        XCTAssertEqual(EnforcementCurator.redirect(forCode: ""), .unscriptural)
    }

    /// A redirect that offers a week we can't actually build is a second dead
    /// end stacked on the first.
    func testScreen_EveryOfferedRedirectBuildsARealWeek() {
        guard let url = Bundle.main.url(forResource: "declarationsv10", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let pool = try? JSONDecoder().decode(WelcomeResponse.self, from: data).declarations,
              !pool.isEmpty else {
            return XCTFail("declarationsv10.json missing or undecodable")
        }
        let offered: [SituationScreen.Redirect] = [.anotherPersonsPartner, .harmToAnother, .unscriptural]
        for redirect in offered {
            guard let category = redirect.offerCategory else { continue }
            XCTAssertNotNil(EnforcementAssembler.assemble(primary: category, pool: pool, seed: "s"),
                            "\(redirect.reason) offers \(category.rawValue), which can't fill a week")
        }
    }

    /// Pulls the comma-separated list that follows the `CATEGORIES` heading in
    /// the Claude system prompt, so the test tracks the prompt instead of a copy.
    private func categoriesClaudeCanReturn() -> [String] {
        let lines = AnthropicConfig.systemPrompt.components(separatedBy: "\n")
        guard let heading = lines.firstIndex(where: { $0.hasPrefix("CATEGORIES") }) else { return [] }
        let list = lines
            .dropFirst(heading + 1)   // past the heading, which has commas of its own
            .first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
        return (list ?? "")
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}
