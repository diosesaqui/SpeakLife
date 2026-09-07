//
//  OnboardingAngle.swift
//  SpeakLife
//
//  The shared copy model behind every "angle" onboarding arm.
//
//  The promises, warfare and outcomes arms were three ~800-line files that
//  differed only in COPY. The narrative screens, the burden picker, the extended
//  quiz, the back-half (taste → record your own → rating → plan loader → plan
//  reveal → testimonials → paywall → notification time), the progress bar, the
//  quiz-v2 skip logic, the rating gate and the completion/seeding block were
//  duplicated verbatim in all three. `AngleOnboardingView` now owns that
//  machinery once, and an arm is a value of this type: scenes, a picker, and a
//  handful of analytics strings.
//
//  Adding an arm is therefore adding a constant to `OnboardingAngles`, a case to
//  `SubscriptionStore.OnboardingVariant`, and a line to `HomeView.onboardingFlow`.
//  Because `OnboardingVariant` is what `?ob=` deep links validate against, a new
//  angle is deep-linkable the moment its case exists: an ad can point at
//  `speaklife://open?ob=healing` and the healing arc is what the install opens to.
//
//  Analytics note: every event name and property emitted by a ported arm is
//  carried on the angle constant, not derived from it. The three live arms keep
//  the exact event names, step raw values and `flow_schema` values they had as
//  hand-written views, so the running A/B funnels still join across the port.
//

import SwiftUI

// MARK: - Angle

struct OnboardingAngle {
    /// Matches the `OnboardingVariant` raw value and the `?ob=` deep-link code.
    let id: String
    /// Analytics slug: prefixes `<flow>_onboarding_started`, `<flow>_step_completed`,
    /// `<flow>_onboarding_completed`, the `onboardingSegment` and the shared
    /// screens' `flow:` argument.
    let flow: String
    /// Bumped whenever the step ORDER changes, so `<flow>_step_completed`'s
    /// integer `step` can still be interpreted. Ported arms keep the value they
    /// were already emitting.
    let flowSchema: Int
    /// Icon treatment for the narrative screens. Warfare runs ember; the rest gold.
    let iconStyle: AngleIconStyle
    /// Whether the arc opens on the shared "Pray Like Jesus" storm screen.
    let opensWithStormScreen: Bool
    /// Whether the product-capability recap sits between the scenes and the picker.
    let showsExperienceScreen: Bool
    /// The narrative screens, in order.
    let scenes: [AngleScene]
    /// The burden picker. This is the screen that seeds the feed, so every angle has one.
    let picker: AnglePicker
    /// Optional burden-matched payoff screen shown immediately after the picker
    /// (warfare's victory vision). Nil for arms that don't run one.
    let burdenScene: AngleBurdenScene?

    init(
        id: String,
        flow: String,
        flowSchema: Int,
        iconStyle: AngleIconStyle = .gold,
        opensWithStormScreen: Bool = false,
        showsExperienceScreen: Bool = true,
        scenes: [AngleScene],
        picker: AnglePicker,
        burdenScene: AngleBurdenScene? = nil
    ) {
        self.id = id
        self.flow = flow
        self.flowSchema = flowSchema
        self.iconStyle = iconStyle
        self.opensWithStormScreen = opensWithStormScreen
        self.showsExperienceScreen = showsExperienceScreen
        self.scenes = scenes
        self.picker = picker
        self.burdenScene = burdenScene
    }
}

// MARK: - Steps

/// One screen in an angle flow. The flow's step list is derived from the angle
/// (see `OnboardingAngle.steps`), and a step's INDEX in that list is the integer
/// reported as `step` on `<flow>_step_completed` — which is why the list always
/// contains `.belief` and `.rating` even when they're skipped at runtime. Both
/// are conditionally jumped over in `advance()`, exactly as the hand-written
/// arms did, so the numbering never shifts under a remote flag.
enum AngleStep: Equatable {
    case storm
    case scene(Int)
    case experience
    case picker
    case burdenScene
    // Extended personalization quiz (shared screens in SurveyOnboardingScreens)
    case battleDuration
    case alreadyTried
    case insight
    case hitsHardest
    case connectStyle
    case belief
    case dailyMinutes
    // Shared back-half
    case firstDeclaration
    case personalDeclaration
    case rating
    case planBuilding
    case planReveal
    case testimonials
    case paywall
    case notificationTime
}

extension OnboardingAngle {
    /// The full step list, in order. Index == the `step` value in analytics.
    var steps: [AngleStep] {
        var steps: [AngleStep] = []
        if opensWithStormScreen { steps.append(.storm) }
        steps.append(contentsOf: scenes.indices.map { AngleStep.scene($0) })
        if showsExperienceScreen { steps.append(.experience) }
        steps.append(.picker)
        if burdenScene != nil { steps.append(.burdenScene) }
        steps.append(contentsOf: [
            AngleStep.battleDuration, .alreadyTried, .insight, .hitsHardest, .connectStyle, .belief, .dailyMinutes
        ])
        steps.append(contentsOf: [
            AngleStep.firstDeclaration, .personalDeclaration, .rating,
            .planBuilding, .planReveal, .testimonials, .paywall, .notificationTime
        ])
        return steps
    }

    /// The screens the progress bar counts: everything from the opener through
    /// the last quiz question. The belief step only exists in quiz v2, so the
    /// denominator has to know which quiz is running.
    func valueScreens(quizV2: Bool) -> [AngleStep] {
        var screens = Array(steps.prefix(while: { $0 != .firstDeclaration }))
        if !quizV2 { screens.removeAll { $0 == .belief } }
        return screens
    }
}

// MARK: - Icon treatment

enum AngleIconStyle {
    case gold
    case ember

    var gradient: AnyShapeStyle {
        switch self {
        case .gold:  return AnyShapeStyle(DS.Gradient.gold)
        case .ember: return AnyShapeStyle(DS.Gradient.ember)
        }
    }

    var glow: Color {
        switch self {
        case .gold:  return DS.Palette.gold.opacity(0.45)
        case .ember: return Color(hex: "#FF3D2E").opacity(0.45)
        }
    }
}

// MARK: - Scene

/// One narrative screen: gold/ember icon, eyebrow, headline, body, verse, button.
/// Every angle arm's story screens use this single layout, so an arm's story is
/// pure data.
struct AngleScene {
    let symbol: String
    let eyebrow: String
    let title: String
    let body: String
    let verse: String
    let reference: String
    let buttonLabel: String
    /// Impression event, carried rather than derived: the ported arms emit three
    /// different names (`promise_scene_shown`, `warfare_scene_shown`,
    /// `outcome_vision_shown`) plus one screen with a bespoke event of its own
    /// (`outcome_stakes_shown`), and every one of those is already a live funnel.
    let analyticsEvent: String
    let analyticsParameters: [String: String]

    init(
        symbol: String,
        eyebrow: String,
        title: String,
        body: String,
        verse: String,
        reference: String,
        buttonLabel: String = "Continue →",
        analyticsEvent: String,
        analyticsParameters: [String: String] = [:]
    ) {
        self.symbol = symbol
        self.eyebrow = eyebrow
        self.title = title
        self.body = body
        self.verse = verse
        self.reference = reference
        self.buttonLabel = buttonLabel
        self.analyticsEvent = analyticsEvent
        self.analyticsParameters = analyticsParameters
    }
}

// MARK: - Burden-matched scene

/// A scene whose copy is chosen by the burden the user just picked (warfare's
/// victory vision). Same layout as `AngleScene`; only the content lookup differs.
struct AngleBurdenScene {
    let eyebrow: String
    let buttonLabel: String
    let analyticsEvent: String
    /// What a burden with no entry in `content` gets. Required rather than
    /// force-unwrapped out of the dictionary so the lookup is total: a future
    /// angle that forgets a burden renders the default instead of trapping on a
    /// user who picked it. By convention this holds the `.peace` copy, matching
    /// the `heaviestBurden ?? .peace` default the rest of the flow already uses
    /// — which is why `.peace` is the one burden NOT listed in `content`.
    let defaultContent: Content
    /// Copy for every other burden the picker can produce.
    let content: [HeaviestBurden: Content]

    struct Content {
        let symbol: String
        let title: String
        let body: String
        let verse: String
        let reference: String
    }

    func content(for burden: HeaviestBurden) -> Content {
        content[burden] ?? defaultContent
    }
}

// MARK: - Picker

/// The screen that names what the user is here for. It writes
/// `responses.heaviestBurden`, which seeds the feed, the daily pushes, the
/// preview declaration and the named 30-day plan.
///
/// Broad arms (promises/warfare/outcomes) list one row per `HeaviestBurden`.
/// Single-issue arms deep-linked from an ad list several rows that all resolve
/// to the SAME burden — a healing ad shouldn't offer to talk about money — and
/// distinguish themselves through `segmentLabel`, so the ad-level segment
/// survives into `onboardingSegment` and every downstream paywall event.
struct AnglePicker {
    let headline: String
    let subtitle: String
    let analyticsEvent: String
    let choices: [AnglePickerChoice]
}

struct AnglePickerChoice: Identifiable {
    /// Stable across copy edits: this is what lands in analytics.
    let id: String
    let burden: HeaviestBurden
    let statement: String
    let subtitle: String
    let symbol: String
    /// Suffix for `appState.onboardingSegment` (`"<flow>_<segmentLabel>"`).
    /// Defaults to the burden's short label, which is what the broad arms have
    /// always written; scoped pickers override it so rows sharing a burden stay
    /// distinguishable.
    let segmentLabel: String

    init(
        id: String,
        burden: HeaviestBurden,
        statement: String,
        subtitle: String,
        symbol: String,
        segmentLabel: String? = nil
    ) {
        self.id = id
        self.burden = burden
        self.statement = statement
        self.subtitle = subtitle
        self.symbol = symbol
        self.segmentLabel = segmentLabel ?? burden.shortLabel
    }
}
