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

    /// Raw values from `WarfareStep`, before the port. Warfare is the one arm
    /// with no storm opener, and the first of the two that run a burden-matched
    /// payoff (`command` is the other), so its indices sit one lower than the
    /// other ported arms from the picker on.
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

    /// The command arm is the only broad arm that opens on the storm screen AND
    /// runs a burden-matched payoff, so it is one screen longer than every other
    /// arm. Nothing historical is riding on these indices yet (flowSchema 1), but
    /// they are the contract `command_step_completed` is read against from here
    /// on: change the order and bump the schema with it.
    func testCommandStepIndices() {
        let steps = OnboardingAngles.command.steps
        XCTAssertEqual(steps.count, 24)
        XCTAssertEqual(steps[0], .storm)
        XCTAssertEqual(steps[5], .scene(4))       // sixty seconds
        XCTAssertEqual(steps[6], .experience)
        XCTAssertEqual(steps[7], .picker)
        XCTAssertEqual(steps[8], .burdenScene)    // tomorrow morning's words
        XCTAssertEqual(steps[9], .battleDuration)
        XCTAssertEqual(steps[14], .belief)
        XCTAssertEqual(steps[15], .dailyMinutes)
        XCTAssertEqual(steps[18], .rating)
        XCTAssertEqual(steps[22], .paywall)
        XCTAssertEqual(steps[23], .notificationTime)
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
        XCTAssertEqual(OnboardingAngles.command.valueScreens(quizV2: true).count, 16)
        XCTAssertEqual(OnboardingAngles.command.valueScreens(quizV2: false).count, 15)
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
}
