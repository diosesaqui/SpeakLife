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
//  Depth is data too: `quizSteps` and `showsPlanBuilding` let an arm run a
//  shorter funnel without a second driver. Both default to what every arm did
//  when the lists were hardcoded, so an arm that ignores them is unchanged.
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
    /// Which extended-quiz questions this arm asks, in order. Defaults to
    /// `fullQuiz`, which is what every arm asked when the quiz block was
    /// hardcoded, so an arm that says nothing is unchanged.
    ///
    /// A shorter list is how an arm trims its depth. Four of the seven questions
    /// (`battleDuration`, `alreadyTried`, `hitsHardest`, `belief`) are read by
    /// NOTHING but the completion event, and `insight` takes no input at all, so
    /// dropping them costs analytics segmentation and the commitment beat, not
    /// behaviour. The two that are not optional are `connectStyle` (v1 stores
    /// `ConnectStyle`; v2 puts the victory question in the same slot, which the
    /// plan reveal echoes) and `dailyMinutes` (stores `DailyTimeBudget`, which
    /// sizes the daily checklist) — `OnboardingAngleTests` holds every arm to
    /// both.
    let quizSteps: [AngleStep]
    /// Whether the "building your plan" loader runs before the plan reveal. Pure
    /// theatre, so a lean arm can skip it; every ported arm keeps it.
    let showsPlanBuilding: Bool

    /// The seven-question block, in the order the ported arms ask it.
    static let fullQuiz: [AngleStep] = [
        .battleDuration, .alreadyTried, .insight, .hitsHardest, .connectStyle, .belief, .dailyMinutes
    ]

    /// The shortest quiz an arm may run: the two questions whose answers outlive
    /// onboarding. Both are needed, and in this order, for the progress bar's
    /// last screen to stay `dailyMinutes`.
    static let leanQuiz: [AngleStep] = [.connectStyle, .dailyMinutes]

    init(
        id: String,
        flow: String,
        flowSchema: Int,
        iconStyle: AngleIconStyle = .gold,
        opensWithStormScreen: Bool = false,
        showsExperienceScreen: Bool = true,
        scenes: [AngleScene],
        picker: AnglePicker,
        burdenScene: AngleBurdenScene? = nil,
        quizSteps: [AngleStep] = OnboardingAngle.fullQuiz,
        showsPlanBuilding: Bool = true
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
        self.quizSteps = quizSteps
        self.showsPlanBuilding = showsPlanBuilding
    }
}

// MARK: - Steps

/// One screen in an angle flow. The flow's step list is derived from the angle
/// (see `OnboardingAngle.steps`), and a step's INDEX in that list is the integer
/// reported as `step` on `<flow>_step_completed` — which is why an arm that ASKS
/// `.belief` keeps it in the list even when quiz v1 skips it, and why `.rating`
/// stays in every arm's list even when the remote flag is off. Both are
/// conditionally jumped over in `advance()`, exactly as the hand-written arms
/// did, so the numbering never shifts under a remote flag. An arm that drops a
/// question from `quizSteps` altogether is a different matter: that changes the
/// step ORDER, so it belongs to a new arm or a `flowSchema` bump.
enum AngleStep: Hashable {
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
        steps.append(contentsOf: quizSteps)
        steps.append(contentsOf: [AngleStep.firstDeclaration, .personalDeclaration, .rating])
        if showsPlanBuilding { steps.append(.planBuilding) }
        steps.append(contentsOf: [AngleStep.planReveal, .testimonials, .paywall, .notificationTime])
        return steps
    }

    /// The screens the progress bar counts: everything from the opener through
    /// the last quiz question. The belief step only exists in quiz v2, so the
    /// denominator has to know which quiz is running (an arm that never asks it
    /// reads the same on both).
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
    /// The feed/notification category this row seeds, when `HeaviestBurden`
    /// cannot name it.
    ///
    /// `HeaviestBurden` has seven cases and maps to seven categories, which was
    /// enough while every arm was some flavour of peace, health, joy, identity,
    /// purpose or money. It cannot express grief, purity, salvation or the fear
    /// of death, and a single-issue arm that cannot name its own subject defeats
    /// the point of having one: a grief ad would seed an anxiety feed on the
    /// first morning, which is the exact failure these arms exist to prevent.
    ///
    /// Nil on every broad arm and on the four original single-issue arms, whose
    /// burden already names the right category. Set it only when the row's real
    /// subject has no burden of its own, and keep the burden itself as the
    /// closest neighbour, since it still drives declaration style and the plan
    /// reveal's domain wording.
    let seedCategory: DeclarationCategory?
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
        segmentLabel: String? = nil,
        seedCategory: DeclarationCategory? = nil
    ) {
        self.id = id
        self.burden = burden
        self.statement = statement
        self.subtitle = subtitle
        self.symbol = symbol
        self.segmentLabel = segmentLabel ?? burden.shortLabel
        self.seedCategory = seedCategory
    }

    /// What this row actually seeds: its own category when it has one, otherwise
    /// the burden's. Read this rather than `burden.seedCategory` anywhere the
    /// answer decides what the user is shown.
    var resolvedSeedCategory: DeclarationCategory {
        seedCategory ?? burden.seedCategory
    }
}
