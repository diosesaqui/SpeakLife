//
//  OutcomesOnboardingView.swift
//  SpeakLife
//
//  An outcome-visualization onboarding A/B variant. Where the warfare arm leads
//  with the fight (the thief), this arm leads with the WIN — each screen
//  demonstrates the best-case life that speaking God's Word produces, the
//  "after" the user is reaching for. The narrative arc is:
//
//    0. Pray like Jesus   — the store-listing promise, delivered on screen one:
//                           He spoke to the storm, and that is how you pray here
//    1. The stakes        — the cost of staying where you are (the fear trigger,
//                           so the dream-first flow still carries both angles)
//    2. Health restored   — a body walking in the healing already paid for
//    3. Open doors        — provision, opportunity, breakthrough
//    4. Peace in your home — the storm stilled, relationships mended
//    5. Victorious identity — authority over warfare + who you are in Christ
//
//  Then a product-capability recap, a "which breakthrough do you most need to
//  see?" picker (which seeds the home feed), the same extended personalization
//  quiz the warfare/product arms run, and the proven back-half (taste → record
//  your own → rating → plan-building loader → named plan reveal → paywall →
//  notification time). Mechanically identical to the warfare arm so an A/B test
//  isolates the angle (dream-first vs fight-first), not the funnel depth. The
//  picker maps each outcome to a HeaviestBurden/category so the shared screens +
//  seeding work unchanged.
//
//  One arm of the onboarding A/B: HomeView routes here when Remote Config
//  `onboardingVariant` == "outcomes".
//

import SwiftUI
import UserNotifications
import UIKit

struct OutcomesOnboardingView: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var declarationStore: DeclarationViewModel
    let size: CGSize
    let onComplete: () -> Void

    // Reuse the survey response model so the shared back-half screens and the
    // seeding logic work unchanged. Only `heaviestBurden` and `notificationTime`
    // are set here (the outcome picker writes `heaviestBurden`).
    @StateObject private var responses = SurveyResponses()
    @State private var currentStep: OutcomesStep = .storm
    @State private var savedDeclaration: PersonalDeclaration? = nil

    // Quiz v2 flag, frozen at the flow's first appearance (mirroring
    // lockOnboardingVariant's intent) so a realtime Remote Config activation
    // mid-session can't swap questions, progress totals, or quiz_version
    // under the user. The live-read fallback only covers pre-onAppear access.
    // When false the flow is byte-for-byte the current quiz (belief step
    // skipped, connect style question shown, no plan-reveal echo).
    @State private var quizV2Snapshot: Bool? = nil
    private var quizV2: Bool { quizV2Snapshot ?? subscriptionStore.useQuizV2 }

    private var valueProgress: Double {
        guard let idx = currentStep.valueScreenIndex(quizV2: quizV2) else { return 0 }
        return Double(idx) / Double(OutcomesStep.totalValueScreens(quizV2: quizV2))
    }

    var body: some View {
        ZStack(alignment: .top) {
            backgroundView

            currentStepView
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .offset(x: 0, y: 24)),
                    removal: .opacity.combined(with: .offset(x: 0, y: -16))
                ))
                .id(currentStep.rawValue)

            if currentStep.valueScreenIndex(quizV2: quizV2) != nil {
                VStack {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Rectangle().fill(Color.white.opacity(0.15)).frame(height: 3)
                            Rectangle().fill(Color.white)
                                .frame(width: geo.size.width * valueProgress, height: 3)
                                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: valueProgress)
                        }
                    }
                    .frame(height: 3)
                    .padding(.horizontal, 28)
                    .padding(.top, size.height * 0.065)
                    Spacer()
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            if quizV2Snapshot == nil { quizV2Snapshot = subscriptionStore.useQuizV2 }
            AnalyticsService.shared.track("outcomes_onboarding_started")
        }
    }

    @ViewBuilder
    private var currentStepView: some View {
        switch currentStep {
        case .storm:     StormOpenerScreen(size: size, flow: "outcomes") { advance() }
        case .stakes:    OutcomeStakesScreen(size: size) { advance() }
        case .health:    OutcomeVisionScreen(size: size, vision: .health) { advance() }
        case .provision: OutcomeVisionScreen(size: size, vision: .provision) { advance() }
        case .peace:     OutcomeVisionScreen(size: size, vision: .peace) { advance() }
        case .identity:  OutcomeVisionScreen(size: size, vision: .identity) { advance() }
        case .experience:
            OnboardingProductExperienceScreen(size: size, flow: "outcomes") { advance() }
        case .outcomePicker:
            OutcomePickerScreen(size: size, responses: responses) { advance() }
        case .battleDuration, .alreadyTried, .insight, .hitsHardest, .connectStyle, .belief, .dailyMinutes:
            quizStepView
        default: backHalfView
        }
    }

    // Extended quiz steps (Q2-Q6 + insight), shared with the warfare/product arms.
    @ViewBuilder
    private var quizStepView: some View {
        switch currentStep {
        case .battleDuration:
            SurveyExtendedQuizScreen(size: size, flow: "outcomes", question: .battleDuration, selection: $responses.battleDuration) { advance() }
        case .alreadyTried:
            SurveyExtendedQuizScreen(size: size, flow: "outcomes", question: .alreadyTried, selection: $responses.alreadyTried) { advance() }
        case .insight:
            SurveyQuizInsightScreen(size: size, flow: "outcomes") { advance() }
        case .hitsHardest:
            SurveyExtendedQuizScreen(size: size, flow: "outcomes", question: .hitsHardest, selection: $responses.hitsHardest) { advance() }
        case .connectStyle:
            // Quiz v2 swaps the connect-style question for the burden-aware
            // outcome question in the same slot; v1 is unchanged.
            if quizV2 {
                SurveyExtendedQuizScreen(size: size, flow: "outcomes", question: .victoryLooksLike(for: responses.heaviestBurden ?? .peace), selection: $responses.victoryOutcome) { advance() }
            } else {
                SurveyExtendedQuizScreen(size: size, flow: "outcomes", question: .connectStyle, selection: $responses.connectStyle) { advance() }
            }
        case .belief:
            // Quiz v2 only — v1's advance() jumps over this step entirely.
            SurveyExtendedQuizScreen(size: size, flow: "outcomes", question: .belief, selection: $responses.beliefLevel) { advance() }
        case .dailyMinutes:
            SurveyExtendedQuizScreen(size: size, flow: "outcomes", question: .dailyMinutes, selection: $responses.dailyMinutes) { advance() }
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var backHalfView: some View {
        switch currentStep {
        case .firstDeclaration:
            SurveyFirstDeclarationScreen(size: size, responses: responses, flow: "outcomes") { advance() }
        case .personalDeclaration:
            PersonalDeclarationOnboardingView(
                viewModel: DIContainer.shared.makePersonalDeclarationViewModel(),
                size: size,
                flow: "outcomes"
            ) { declaration in
                savedDeclaration = declaration
                advance()
            }
        case .rating:
            RatingView(size: size) { advance() }
        case .planBuilding:
            SurveyPlanBuildingScreen(burden: responses.heaviestBurden ?? .peace, flow: "outcomes") { advance() }
        case .planReveal:
            SurveyPlanRevealScreen(
                size: size,
                burden: responses.heaviestBurden ?? .peace,
                flow: "outcomes",
                personalDeclaration: savedDeclaration?.declarationText,
                dailyMinutes: responses.dailyMinutes,
                victoryEcho: responses.victoryEcho  // nil in quiz v1
            ) { advance() }
        case .testimonials:
            TestimonialWallView(size: size, flow: "outcomes") { advance() }
        case .paywall:
            HighConversionPaywallView(callback: { advance() }, source: "onboarding", isHardPaywall: true)
        case .notificationTime:
            SurveyQ8NotificationScreen(size: size, responses: responses, flow: "outcomes") { advance() }
        default:
            EmptyView()
        }
    }

    private var backgroundView: some View {
        ZStack {
            Image(subscriptionStore.onboardingBGImage)
                .resizable().aspectRatio(contentMode: .fill)
                .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                .clipped()
            LinearGradient(
                gradient: Gradient(colors: [Color.black.opacity(0.82), Color.black.opacity(0.55), Color.black.opacity(0.72)]),
                startPoint: .top, endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }

    private func advance() {
        Juice.play(.tapLight)
        // flow_schema 4 = storm opener prepended as step 0 (3 = testimonial wall inserted before paywall, 2 = matched-to-warfare layout, 1 = original short outcomes flow). Bump when step raw values are renumbered again.
        AnalyticsService.shared.track("outcomes_step_completed", parameters: ["step": currentStep.rawValue, "flow_schema": 4])

        // Leaving the outcome picker: stamp the segment so downstream paywall
        // events carry a meaningful segment for this arm (quiz sets its own).
        if currentStep == .outcomePicker, let burden = responses.heaviestBurden {
            appState.onboardingSegment = "outcomes_\(burden.shortLabel)"
        }

        // Leaving the hits-hardest question: pre-select the notification-time
        // screen from when their struggle hits (no auto-advance; still editable).
        if currentStep == .hitsHardest, responses.notificationTime == nil,
           let suggested = responses.suggestedNotificationTime {
            responses.notificationTime = suggested
        }

        switch currentStep {
        case .notificationTime:
            applyResponsesAndComplete()
        default:
            var nextRaw = currentStep.rawValue + 1
            // Quiz v1 has no belief step — jump straight from connect style
            // to daily minutes, exactly the pre-v2 sequence.
            if !quizV2, OutcomesStep(rawValue: nextRaw) == .belief {
                nextRaw += 1
            }
            // Rating ask is remote-gated (onboardingRatingEnabled); when off,
            // skip straight past it to the next step.
            if OutcomesStep(rawValue: nextRaw) == .rating, !subscriptionStore.onboardingRatingEnabled {
                nextRaw += 1
            }
            guard let next = OutcomesStep(rawValue: nextRaw) else {
                assertionFailure("OutcomesOnboardingView.advance(): no successor for \(currentStep). .notificationTime should be terminal.")
                onComplete()
                return
            }
            withAnimation(.easeInOut(duration: 0.35)) { currentStep = next }
        }
    }

    // Mirrors the warfare/product completion: persist the chosen category, seed
    // the home feed + notifications from it, then finish.
    private func applyResponsesAndComplete() {
        let goalWord = responses.resolvedGoalWord
        appState.surveyGoalWord = goalWord.rawValue
        if let style = responses.primaryDeclarationStyle {
            appState.selectedDeclarationStyles = [style.rawValue]
        }
        let category = goalWord.declarationCategory
        let notificationCategoriesSet: Set<DeclarationCategory> = [category]
        appState.selectedNotificationCategories = category.rawValue
        UserDefaults.standard.set(category.rawValue, forKey: "selectedCategory")
        UserPreferencesTracker.shared.trackCategorySelection(category.rawValue)
        // The answer has to outlive onboarding to be worth asking. Every arm
        // that asks this question kept it on `SurveyResponses`, where it died
        // with the flow — which is why 527 answers were collected and read by
        // nothing. `TaskLibrary` reads this key when it builds the day.
        ConnectStyle.store(responses.connectStyle.flatMap(ConnectStyle.init(rawValue:)))
        declarationStore.choose(category) { _ in }
        if let notifTime = responses.notificationTime {
            appState.startTimeIndex = notifTime.startTimeIndex
            appState.endTimeIndex   = notifTime.endTimeIndex
            appState.personalDeclarationTimeIndex = notifTime.startTimeIndex
        }
        appState.hasPersonalDeclaration = savedDeclaration != nil
        AnalyticsService.shared.track("outcomes_onboarding_completed", parameters: [
            "goal_word": goalWord.rawValue,
            "burden": responses.heaviestBurden?.rawValue ?? "unknown",
            "battle_duration": responses.battleDuration ?? "unknown",
            "already_tried": responses.alreadyTried ?? "unknown",
            "hits_hardest": responses.hitsHardest ?? "unknown",
            "connect_style": responses.connectStyle ?? "unknown",
            "daily_minutes": responses.dailyMinutes ?? "unknown",
            "victory_looks_like": responses.victoryOutcome ?? "unknown",
            "belief": responses.beliefLevel ?? "unknown",
            "quiz_version": quizV2 ? "v2" : "v1",
            "flow_schema": 4,  // joins with outcomes_step_completed; bump when step raw values are renumbered again
            "set_personal_declaration": (savedDeclaration != nil) as NSNumber
        ])

        requestNotificationPermissionThenComplete(categories: notificationCategoriesSet)
    }

    private func requestNotificationPermissionThenComplete(categories: Set<DeclarationCategory>) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            AnalyticsService.shared.track("notification_permission", parameters: ["granted": granted, "source": "outcomes_onboarding"])
            DispatchQueue.main.async {
                appState.notificationEnabled = granted
                if granted {
                    UIApplication.shared.registerForRemoteNotifications()
                    NotificationManager.shared.registerNotifications(
                        count: appState.notificationCount,
                        startTime: appState.startTimeIndex,
                        endTime: appState.endTimeIndex,
                        categories: categories
                    )
                    appState.lastNotificationSetDate = Date()
                    // Trial pushes may have been scheduled pre-authorization on the paywall; re-add now that delivery is guaranteed.
                    TrialExperienceService.shared.reschedulePendingTrialPushesIfNeeded()
                }
                onComplete()
            }
        }
    }
}

// MARK: - Flow Steps

enum OutcomesStep: Int, CaseIterable {
    // Outcome-demonstration screens
    case storm          = 0   // "Pray Like Jesus" — the store listing, answered on screen one
    case stakes         = 1   // the cost of staying where you are (the fear trigger)
    case health         = 2
    case provision      = 3
    case peace          = 4
    case identity       = 5   // warfare authority + new identity in Christ
    case experience     = 6   // product-capability recap (matching warfare/product)
    case outcomePicker  = 7   // pick the breakthrough to see first (seeds the feed)
    // Extended personalization quiz (shared screens in SurveyOnboardingScreens)
    case battleDuration = 8   // Q2: how long has this been going on?
    case alreadyTried   = 9   // Q3: what have you already tried?
    case insight        = 10  // micro-insight interstitial (reading vs speaking)
    case hitsHardest    = 11  // Q4: when does it hit hardest? (preselects notification time)
    case connectStyle   = 12  // Q5: connect style (quiz v1) or victory outcome (quiz v2)
    case belief         = 13  // quiz v2 only: do you believe God wants more? (v1 skips it)
    case dailyMinutes   = 14  // Q6: how much time daily? (drives plan reveal rhythm)
    // Shared back-half (reused from the survey flow)
    case firstDeclaration = 15
    case personalDeclaration = 16
    case rating          = 17  // rating ask at the personal-declaration peak
    case planBuilding    = 18  // "building your plan" loader (transition, no bar)
    case planReveal      = 19  // named 30-day plan reveal — sets up the paywall ask
    case testimonials    = 20  // App Store review wall — social proof right before the ask
    case paywall         = 21
    case notificationTime = 22 // terminal — completes onboarding

    func valueScreenIndex(quizV2: Bool) -> Int? {
        var screens: [OutcomesStep] = [
            .storm, .stakes, .health, .provision, .peace, .identity, .experience, .outcomePicker,
            .battleDuration, .alreadyTried, .insight, .hitsHardest, .connectStyle, .belief, .dailyMinutes
        ]
        if !quizV2 { screens.removeAll { $0 == .belief } }
        return screens.firstIndex(of: self).map { $0 + 1 }
    }

    static func totalValueScreens(quizV2: Bool) -> Int { quizV2 ? 15 : 14 }
}

// MARK: - Outcome content

private enum OutcomeVision {
    case health, provision, peace, identity

    var eyebrow: String { "WHAT HAPPENS WHEN YOU SPEAK" }

    var title: String {
        switch self {
        case .health:    return "Your body,\nrestored."
        case .provision: return "Doors you couldn't open,\nopening."
        case .peace:     return "Peace settling\nover your home."
        case .identity:  return "Standing in who\nyou really are."
        }
    }

    var body: String {
        switch self {
        case .health:
            return "The diagnosis loses its grip. Strength comes back. You wake up in a body that lines up with the healing Jesus already paid for."
        case .provision:
            return "The right call. The unexpected offer. Provision arriving ahead of the need. You walk in opportunity, not lack."
        case .peace:
            return "The tension breaks. The arguments quiet. Your home becomes the calm place, anchored, where anxiety used to live."
        case .identity:
            return "The lies fall silent. The enemy flees at your voice. You stop fighting for victory and start living from it, as the redeemed child of God you already are."
        }
    }

    var verse: String {
        switch self {
        case .health:    return "By his wounds you have been healed."
        case .provision: return "And my God will meet all your needs according to the riches of his glory in Christ Jesus."
        case .peace:     return "You will keep in perfect peace those whose minds are steadfast, because they trust in you."
        case .identity:  return "In all these things we are more than conquerors through him who loved us."
        }
    }

    var reference: String {
        switch self {
        case .health:    return "1 Peter 2:24"
        case .provision: return "Philippians 4:19"
        case .peace:     return "Isaiah 26:3"
        case .identity:  return "Romans 8:37"
        }
    }

    var symbol: String {
        switch self {
        case .health:    return "heart.fill"
        case .provision: return "key.fill"
        case .peace:     return "house.fill"
        case .identity:  return "crown.fill"
        }
    }

    var buttonLabel: String {
        switch self {
        case .identity: return "This Is the Life I Want →"
        default:        return "Continue →"
        }
    }

    var analyticsName: String {
        switch self {
        case .health:    return "health"
        case .provision: return "provision"
        case .peace:     return "peace"
        case .identity:  return "identity"
        }
    }
}

// Each HeaviestBurden carries an outcome-framed label for the picker. Selecting
// one writes `responses.heaviestBurden`, which the shared back-half (preview
// declaration, notification subtitle) and the seeding logic already understand.
private struct OutcomeChoice {
    let statement: String
    let subtitle: String
    let symbol: String

    static func of(_ burden: HeaviestBurden) -> OutcomeChoice {
        switch burden {
        case .health:
            return OutcomeChoice(statement: "Healing in my body",
                                 subtitle: "Restored, whole, strong again",
                                 symbol: "heart.fill")
        case .abundance:
            return OutcomeChoice(statement: "Open doors and provision",
                                 subtitle: "Opportunity and overflow, not lack",
                                 symbol: "key.fill")
        case .peace:
            return OutcomeChoice(statement: "Peace in my home",
                                 subtitle: "The storm stilled, relationships mended",
                                 symbol: "house.fill")
        case .allOfIt:
            return OutcomeChoice(statement: "Victory over what's against me",
                                 subtitle: "Standing in authority, the enemy flees",
                                 symbol: "bolt.fill")
        case .identity:
            return OutcomeChoice(statement: "Knowing who I am in Christ",
                                 subtitle: "Secure, chosen, redeemed",
                                 symbol: "crown.fill")
        case .purpose:
            return OutcomeChoice(statement: "Walking in my calling",
                                 subtitle: "Stepping into what God made me for",
                                 symbol: "flag.fill")
        case .joy:
            return OutcomeChoice(statement: "Joy that holds",
                                 subtitle: "Unshakeable, whatever comes",
                                 symbol: "sun.max.fill")
        }
    }
}

// Lead the picker with the four demonstrated outcomes.
private let outcomePickerOrder: [HeaviestBurden] = [
    .health, .abundance, .peace, .allOfIt, .identity, .purpose, .joy
]

// MARK: - Shared Components

private struct OutcomeContinueButton: View {
    let label: String
    let isEnabled: Bool
    let action: () -> Void

    init(label: String = "Continue", isEnabled: Bool = true, action: @escaping () -> Void) {
        self.label = label
        self.isEnabled = isEnabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(isEnabled ? DS.Palette.deepBlue : .white.opacity(0.4))
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    Capsule()
                        .fill(isEnabled ? AnyShapeStyle(DS.Gradient.gold) : AnyShapeStyle(Color.white.opacity(0.12)))
                        .shadow(color: isEnabled ? DS.Palette.gold.opacity(0.45) : .clear, radius: 14, x: 0, y: 6)
                )
        }
        .buttonStyle(.dsPressable(feel: .tapSolid))
        .disabled(!isEnabled)
        .padding(.horizontal, 28)
        .animation(.easeInOut(duration: 0.2), value: isEnabled)
    }
}

private struct OutcomeAppearStagger: ViewModifier {
    let shown: Bool
    let delay: Double
    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 16)
            .animation(.easeOut(duration: 0.55).delay(delay), value: shown)
    }
}

private extension View {
    func outcomeStagger(_ shown: Bool, delay: Double = 0) -> some View {
        modifier(OutcomeAppearStagger(shown: shown, delay: delay))
    }
}

// MARK: - Stakes Screen (the cost of staying — the fear trigger)

// The outcome visions deliver the dream; this cold open gives the flow its
// fear-of-loss beat first, so the dream-first arm still fires both triggers
// (a someday you keep postponing is a cost, not a neutral) before it pivots to
// the life that's available.
private struct OutcomeStakesScreen: View {
    let size: CGSize
    let onContinue: () -> Void
    @State private var v = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 26) {
                ZStack {
                    Circle()
                        .fill(DS.Gradient.gold)
                        .frame(width: 96, height: 96)
                        .shadow(color: DS.Palette.gold.opacity(0.45), radius: 12, x: 0, y: 6)
                    Image(systemName: "hourglass")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                }
                .outcomeStagger(v)

                VStack(spacing: 14) {
                    Text("BEFORE WE SHOW YOU WHAT'S POSSIBLE")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(DS.Palette.gold.opacity(0.9))
                        .kerning(1.4)
                        .multilineTextAlignment(.center)
                        .outcomeStagger(v, delay: 0.08)

                    Text("How much longer\nwill you wait?")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .outcomeStagger(v, delay: 0.14)

                    Text("The healing. The open doors. The peace at home. They were never meant to be someday promises. Every day you settle for less is a day the enemy keeps what was already bought for you.")
                        .font(.system(size: 17, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 22)
                        .fixedSize(horizontal: false, vertical: true)
                        .outcomeStagger(v, delay: 0.22)
                }

                VStack(spacing: 4) {
                    Text("\"The thief comes only to steal and kill and destroy; I have come that they may have life, and have it to the full.\"")
                        .font(.system(size: 15, weight: .regular, design: .serif))
                        .italic()
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("John 10:10")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.45))
                }
                .padding(.horizontal, 28)
                .outcomeStagger(v, delay: 0.32)
            }
            .padding(.horizontal, 28)

            Spacer()

            OutcomeContinueButton(label: "Show Me What's Possible →") { onContinue() }
                .padding(.bottom, 36)
                .outcomeStagger(v, delay: 0.42)
        }
        .onAppear {
            AnalyticsService.shared.track("outcome_stakes_shown")
            withAnimation { v = true }
        }
    }
}

// MARK: - Outcome Vision Screen

private struct OutcomeVisionScreen: View {
    let size: CGSize
    let vision: OutcomeVision
    let onContinue: () -> Void
    @State private var v = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 26) {
                ZStack {
                    Circle()
                        .fill(DS.Gradient.gold)
                        .frame(width: 96, height: 96)
                        .shadow(color: DS.Palette.gold.opacity(0.45), radius: 12, x: 0, y: 6)
                    Image(systemName: vision.symbol)
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                }
                .outcomeStagger(v)

                VStack(spacing: 14) {
                    Text(vision.eyebrow)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(DS.Palette.gold.opacity(0.9))
                        .kerning(1.4)
                        .outcomeStagger(v, delay: 0.08)

                    Text(vision.title)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .outcomeStagger(v, delay: 0.14)

                    Text(vision.body)
                        .font(.system(size: 17, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 22)
                        .fixedSize(horizontal: false, vertical: true)
                        .outcomeStagger(v, delay: 0.22)
                }

                VStack(spacing: 4) {
                    Text("\"\(vision.verse)\"")
                        .font(.system(size: 15, weight: .regular, design: .serif))
                        .italic()
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(vision.reference)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.45))
                }
                .padding(.horizontal, 28)
                .outcomeStagger(v, delay: 0.32)
            }
            .padding(.horizontal, 28)

            Spacer()

            OutcomeContinueButton(label: vision.buttonLabel) { onContinue() }
                .padding(.bottom, 36)
                .outcomeStagger(v, delay: 0.42)
        }
        .onAppear {
            AnalyticsService.shared.track("outcome_vision_shown", parameters: ["outcome": vision.analyticsName])
            withAnimation { v = true }
        }
    }
}

// MARK: - Outcome Picker (seeds the feed)

private struct OutcomePickerScreen: View {
    let size: CGSize
    @ObservedObject var responses: SurveyResponses
    let onContinue: () -> Void
    @State private var v = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    Spacer().frame(height: size.height * 0.10)

                    VStack(spacing: 12) {
                        Text("Which breakthrough do you\nmost need to see first?")
                            .font(.system(size: 27, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .outcomeStagger(v)

                        Text("We'll build your daily declarations around it\nand start calling it into your life.")
                            .font(.system(size: 15, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.65))
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                            .outcomeStagger(v, delay: 0.1)
                    }
                    .padding(.horizontal, 28)

                    VStack(spacing: 10) {
                        ForEach(outcomePickerOrder) { burden in
                            outcomeRow(burden)
                        }
                    }
                    .padding(.horizontal, 20)
                    .outcomeStagger(v, delay: 0.2)

                    Spacer().frame(height: 8)
                }
            }

            OutcomeContinueButton(isEnabled: responses.heaviestBurden != nil, action: onContinue)
                .padding(.top, 8).padding(.bottom, 36)
        }
        .onAppear {
            AnalyticsService.shared.track("outcome_picker_shown")
            withAnimation { v = true }
        }
    }

    private func outcomeRow(_ burden: HeaviestBurden) -> some View {
        let choice = OutcomeChoice.of(burden)
        let isSelected = responses.heaviestBurden == burden
        return Button(action: {
            Juice.play(.tapLight)
            responses.heaviestBurden = burden
        }) {
            HStack(spacing: 14) {
                Image(systemName: choice.symbol)
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? DS.Palette.gold : .white.opacity(0.7))
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 3) {
                    Text(choice.statement)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(choice.subtitle)
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? DS.Palette.gold : Color.white.opacity(0.35), lineWidth: 1.5)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle().fill(DS.Palette.gold).frame(width: 12, height: 12)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.15) : Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(isSelected ? DS.Palette.gold.opacity(0.55) : Color.white.opacity(0.12), lineWidth: 1)
                    )
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
