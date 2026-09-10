//
//  OnboardingAngleTests.swift
//  SpeakLifeTests
//
//  Guards the two things that break silently when an onboarding angle is added
//  or edited:
//
//  1. The wiring. An angle is reachable only if `OnboardingVariant` has a case
//     whose raw value matches its id — that string is also the `?ob=` deep-link
//     code an ad spends money pointing at. A mismatch produces an arm that
//     compiles, ships, and can never be entered.
//  2. The step numbering. `<flow>_step_completed` reports an INDEX, so the live
//     A/B funnels only stay readable while the ported arms keep the exact
//     indices their hand-written enums had. The expectations below are those
//     enums' raw values, transcribed. If a change here is deliberate, bump the
//     angle's `flowSchema` and update these numbers together.
//

import XCTest
@testable import SpeakLife

final class OnboardingAngleTests: XCTestCase {

    // MARK: - Wiring

    func testEveryAngleHasAMatchingVariantCase() {
        for (id, angle) in OnboardingAngles.all {
            XCTAssertEqual(angle.id, id, "OnboardingAngles.all is keyed by id")
            XCTAssertNotNil(
                SubscriptionStore.OnboardingVariant(code: id),
                "Angle '\(id)' has no OnboardingVariant case, so nothing can route to it and ?ob=\(id) is rejected"
            )
        }
    }

    func testVariantAngleLookupMatchesRawValue() {
        for variant in SubscriptionStore.OnboardingVariant.allCases {
            guard let angle = variant.angle else { continue }
            XCTAssertEqual(angle.id, variant.rawValue)
        }
    }

    func testBespokeVariantsHaveNoAngle() {
        // These five have their own views; handing them to AngleOnboardingView
        // would be a routing bug.
        for variant in [SubscriptionStore.OnboardingVariant.quiz, .product, .identity, .closer, .direct] {
            XCTAssertNil(variant.angle, "\(variant.rawValue) is a bespoke flow, not an angle arm")
        }
    }

    func testDeepLinkCodesAreCaseInsensitive() {
        // Ad platforms mangle case in URLs; `init(code:)` lowercases for that reason.
        XCTAssertEqual(SubscriptionStore.OnboardingVariant(code: "HEALING"), .healing)
        XCTAssertEqual(SubscriptionStore.OnboardingVariant(code: "Renewal"), .renewal)
        XCTAssertNil(SubscriptionStore.OnboardingVariant(code: "not_an_arm"))
    }

    // MARK: - Step numbering (analytics contract)

    /// Raw values from `PromisesStep`, before the port.
    func testPromisesStepIndicesAreUnchanged() {
        let steps = OnboardingAngles.promises.steps
        XCTAssertEqual(steps.count, 23)
        XCTAssertEqual(steps[0], .storm)
        XCTAssertEqual(steps[5], .scene(4))       // everyArea
        XCTAssertEqual(steps[6], .experience)
        XCTAssertEqual(steps[7], .picker)
        XCTAssertEqual(steps[8], .battleDuration)
        XCTAssertEqual(steps[13], .belief)
        XCTAssertEqual(steps[14], .dailyMinutes)
        XCTAssertEqual(steps[17], .rating)
        XCTAssertEqual(steps[21], .paywall)
        XCTAssertEqual(steps[22], .notificationTime)
    }

    /// Raw values from `WarfareStep`, before the port. Warfare is the one PORTED
    /// arm with no storm opener, and the first of the two that run a
    /// burden-matched payoff (`command` is the other), so its indices sit one
    /// lower than the other ported arms from the picker on.
    func testWarfareStepIndicesAreUnchanged() {
        let steps = OnboardingAngles.warfare.steps
        XCTAssertEqual(steps.count, 22)
        XCTAssertEqual(steps[0], .scene(0))       // thief
        XCTAssertEqual(steps[3], .scene(3))       // activation
        XCTAssertEqual(steps[4], .experience)
        XCTAssertEqual(steps[5], .picker)
        XCTAssertEqual(steps[6], .burdenScene)    // victory vision
        XCTAssertEqual(steps[7], .battleDuration)
        XCTAssertEqual(steps[12], .belief)
        XCTAssertEqual(steps[13], .dailyMinutes)
        XCTAssertEqual(steps[16], .rating)
        XCTAssertEqual(steps[20], .paywall)
        XCTAssertEqual(steps[21], .notificationTime)
    }

    /// Raw values from `OutcomesStep`, before the port.
    func testOutcomesStepIndicesAreUnchanged() {
        let steps = OnboardingAngles.outcomes.steps
        XCTAssertEqual(steps.count, 23)
        XCTAssertEqual(steps[0], .storm)
        XCTAssertEqual(steps[1], .scene(0))       // stakes
        XCTAssertEqual(steps[6], .experience)
        XCTAssertEqual(steps[7], .picker)
        XCTAssertEqual(steps[22], .notificationTime)
    }

    /// The command arm is the lean one: no storm opener, no product recap, three
    /// scenes, two quiz questions and no plan loader, because a 24-screen flow
    /// selling a sixty-second habit argues against itself. 14 screens against the
    /// other broad arms' 22 to 23. Nothing historical is riding on these indices
    /// (flowSchema 1, never shipped at any other depth), but they are the contract
    /// `command_step_completed` is read against from here on: change the order and
    /// bump the schema with it.
    func testCommandStepIndices() {
        let steps = OnboardingAngles.command.steps
        XCTAssertEqual(steps.count, 14)
        XCTAssertEqual(steps[0], .scene(0))       // Jesus' morning, screen one
        XCTAssertEqual(steps[2], .scene(2))       // sixty seconds
        XCTAssertEqual(steps[3], .picker)
        XCTAssertEqual(steps[4], .burdenScene)    // tomorrow morning's words
        XCTAssertEqual(steps[5], .connectStyle)
        XCTAssertEqual(steps[6], .dailyMinutes)
        XCTAssertEqual(steps[7], .firstDeclaration)
        XCTAssertEqual(steps[9], .rating)
        XCTAssertEqual(steps[12], .paywall)
        XCTAssertEqual(steps[13], .notificationTime)
        // The trimmed screens are gone, not reordered.
        for dropped in [AngleStep.storm, .experience, .battleDuration, .alreadyTried,
                        .insight, .hitsHardest, .belief, .planBuilding] {
            XCTAssertFalse(steps.contains(dropped), "command should not run \(dropped)")
        }
    }

    /// Trimming depth is data (`quizSteps`), so the compiler cannot stop an arm
    /// from dropping a question whose answer something downstream still reads.
    /// `ConnectStyle` (v1) and `DailyTimeBudget` both outlive onboarding and are
    /// read by `TaskLibrary` when it builds the day, and in quiz v2 the connect
    /// slot carries the victory question the plan reveal echoes. Every arm keeps
    /// both, and `dailyMinutes` stays last so the progress bar's denominator ends
    /// where `valueScreens` expects.
    func testEveryAngleAsksTheQuestionsThatOutliveOnboarding() {
        for (id, angle) in OnboardingAngles.all {
            XCTAssertTrue(angle.quizSteps.contains(.connectStyle),
                          "\(id): dropping the connect slot loses ConnectStyle (v1) and the victory echo (v2)")
            XCTAssertTrue(angle.quizSteps.contains(.dailyMinutes),
                          "\(id): dropping daily minutes loses DailyTimeBudget, which sizes the checklist")
            XCTAssertEqual(angle.quizSteps.last, .dailyMinutes, "\(id): the quiz has to end on daily minutes")
            XCTAssertEqual(Set(angle.quizSteps).count, angle.quizSteps.count, "\(id): a question is asked twice")
            for step in angle.quizSteps {
                XCTAssertTrue(OnboardingAngle.fullQuiz.contains(step),
                              "\(id): \(step) is not one of the extended-quiz screens")
            }
        }
    }

    /// The default has to stay the full block, or trimming one arm silently
    /// shortens every arm that never asked to be trimmed.
    func testOnlyTheCommandArmRunsShort() {
        for id in ["promises", "warfare", "outcomes", "healing", "provision", "anxiety", "renewal"] {
            guard let angle = OnboardingAngles.angle(id: id) else {
                return XCTFail("missing angle '\(id)'")
            }
            XCTAssertEqual(angle.quizSteps, OnboardingAngle.fullQuiz, "\(id): quiz depth changed")
            XCTAssertTrue(angle.showsPlanBuilding, "\(id): lost the plan loader")
        }
        XCTAssertEqual(OnboardingAngles.command.quizSteps, OnboardingAngle.leanQuiz)
        XCTAssertFalse(OnboardingAngles.command.showsPlanBuilding)
    }

    /// `totalValueScreens` drove the progress bar in all three arms; quiz v1
    /// drops the belief question, so the denominator differs by one.
    func testValueScreenCountsAreUnchanged() {
        XCTAssertEqual(OnboardingAngles.promises.valueScreens(quizV2: true).count, 15)
        XCTAssertEqual(OnboardingAngles.promises.valueScreens(quizV2: false).count, 14)
        XCTAssertEqual(OnboardingAngles.warfare.valueScreens(quizV2: true).count, 14)
        XCTAssertEqual(OnboardingAngles.warfare.valueScreens(quizV2: false).count, 13)
        XCTAssertEqual(OnboardingAngles.outcomes.valueScreens(quizV2: true).count, 15)
        XCTAssertEqual(OnboardingAngles.outcomes.valueScreens(quizV2: false).count, 14)
        // The command arm never asks the belief question, so its bar reads the
        // same on both quizzes: 3 scenes + picker + payoff + 2 questions.
        XCTAssertEqual(OnboardingAngles.command.valueScreens(quizV2: true).count, 7)
        XCTAssertEqual(OnboardingAngles.command.valueScreens(quizV2: false).count, 7)
    }

    func testValueScreensStopBeforeTheBackHalf() {
        for (id, angle) in OnboardingAngles.all {
            let screens = angle.valueScreens(quizV2: true)
            XCTAssertEqual(screens.last, .dailyMinutes, "\(id): the bar should run to the last quiz question")
            XCTAssertFalse(screens.contains(.paywall), "\(id): the paywall is not a value screen")
        }
    }

    // MARK: - Shape invariants every angle has to satisfy

    func testEveryAngleIsWellFormed() {
        for (id, angle) in OnboardingAngles.all {
            XCTAssertFalse(angle.scenes.isEmpty, "\(id): an angle needs at least one narrative screen")
            XCTAssertFalse(angle.picker.choices.isEmpty, "\(id): the picker seeds the feed, so it needs rows")

            // The picker is what writes heaviestBurden. Without it the flow would
            // reach the plan reveal and the feed seeding with no answer at all.
            XCTAssertTrue(angle.steps.contains(.picker), "\(id): missing the picker step")
            XCTAssertEqual(angle.steps.last, .notificationTime, "\(id): notificationTime must be terminal")

            let ids = angle.picker.choices.map(\.id)
            XCTAssertEqual(Set(ids).count, ids.count, "\(id): duplicate picker choice ids would merge in analytics")

            let segments = angle.picker.choices.map(\.segmentLabel)
            XCTAssertEqual(Set(segments).count, segments.count,
                           "\(id): rows sharing a segment label are indistinguishable in onboardingSegment")

            for scene in angle.scenes {
                XCTAssertFalse(scene.analyticsEvent.isEmpty, "\(id): every scene needs an impression event")
                // Em/en dashes are banned in SpeakLife copy: they run two thoughts
                // together where two sentences should land two blows.
                for text in [scene.title, scene.body, scene.eyebrow, scene.buttonLabel] {
                    XCTAssertFalse(text.contains("—") || text.contains("–"),
                                   "\(id): dash in copy \"\(text)\"")
                }
            }
        }
    }

    /// A single-issue arm exists so an ad's angle survives into the app. If its
    /// rows spread across burdens, a healing ad can seed a money feed.
    func testSingleIssueAnglesStayOnOneBurden() {
        let expected: [String: HeaviestBurden] = [
            "healing": .health,
            "provision": .abundance,
            "anxiety": .peace,
            "renewal": .identity,
        ]
        for (id, burden) in expected {
            guard let angle = OnboardingAngles.angle(id: id) else {
                return XCTFail("missing angle '\(id)'")
            }
            for choice in angle.picker.choices {
                XCTAssertEqual(choice.burden, burden,
                               "\(id): row '\(choice.id)' seeds \(choice.burden.shortLabel), not \(burden.shortLabel)")
            }
        }
    }

    /// The broad arms let the user name their own area, so every burden needs a row.
    func testBroadAnglesCoverEveryBurden() {
        for id in ["promises", "warfare", "outcomes", "command"] {
            guard let angle = OnboardingAngles.angle(id: id) else {
                return XCTFail("missing angle '\(id)'")
            }
            let covered = Set(angle.picker.choices.map(\.burden))
            XCTAssertEqual(covered, Set(HeaviestBurden.allCases), "\(id): picker doesn't cover every burden")
        }
    }

    /// Warfare's victory vision is keyed by the burden just chosen, so it has to
    /// answer for every row the picker can produce. `content(for:)` never traps
    /// — it falls back — which is exactly why a missing burden has to be caught
    /// here rather than in front of a user, who would otherwise be shown peace
    /// copy after choosing their finances.
    func testBurdenSceneCarriesCopyForEveryBurden() {
        for (id, angle) in OnboardingAngles.all {
            guard let scene = angle.burdenScene else { continue }
            let fallbackTitle = scene.defaultContent.title
            XCTAssertFalse(fallbackTitle.isEmpty, "\(id): burden scene has no default copy")
            for burden in HeaviestBurden.allCases {
                let content = scene.content(for: burden)
                XCTAssertFalse(content.title.isEmpty, "\(id): no payoff copy for \(burden.shortLabel)")
                // Every burden but the one the default stands in for (.peace)
                // must have its own entry, or it is silently getting the default.
                if burden != .peace {
                    XCTAssertNotNil(scene.content[burden],
                                    "\(id): \(burden.shortLabel) has no entry and would fall back to the default copy")
                }
            }
        }
    }

    // MARK: - Bible Chat seeding

    /// Bible Chat's empty state opens on a question built from the burden
    /// onboarding recorded, and that lookup runs through two different enums:
    /// `UserPreferencesTracker.CategoryType` (11 cases) and, for the burdens it
    /// has no case for, `DeclarationCategory` via `BibleChatConversationView.extendedOpener`.
    /// A burden that misses BOTH lands on the generic "what's the heaviest thing
    /// on you right now?" — which is worst precisely where it costs most, on a
    /// deep-linked arm where the ad already named the topic and the user knows
    /// we know.
    ///
    /// This would have caught `?ob=provision` and `?ob=renewal` on the day they
    /// landed: `abundance` seeds `.wealth` and `identity` seeds `.identity`, and
    /// neither round-trips through `CategoryType(rawValue:)`.
    ///
    /// `@MainActor` because `BibleChatConversationView` is a `View`, and `View` is
    /// `@MainActor` on the iOS 17+ SDK — which isolates its static members too.
    @MainActor
    func testEveryAngleSeedsAPersonalChatOpener() {
        for (id, angle) in OnboardingAngles.all {
            for choice in angle.picker.choices {
                let seed = choice.burden.seedCategory
                let hasExtended = BibleChatConversationView.extendedOpener(for: seed) != nil
                // nil and `.general` are the same outcome here: the generic opener.
                let categoryType = UserPreferencesTracker.CategoryType(rawValue: seed.rawValue)
                let hasCategoryType = categoryType != nil && categoryType != .general
                XCTAssertTrue(
                    hasExtended || hasCategoryType,
                    """
                    \(id): row '\(choice.id)' seeds \(seed.rawValue), which neither \
                    CategoryType nor BibleChatConversationView.extendedOpener has an opener for, \
                    so Bible Chat would open on the generic question. Add a case to \
                    extendedOpener.
                    """
                )
            }
        }
    }
}
