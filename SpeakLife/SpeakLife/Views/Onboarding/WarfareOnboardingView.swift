//
//  WarfareOnboardingView.swift
//  SpeakLife
//
//  A spiritual-warfare onboarding A/B variant built on the core SpeakLife angle:
//  you are fighting for what is ALREADY yours. The narrative arc is:
//
//    1. The thief        — the enemy comes to steal, kill, and destroy (John 10:10)
//    2. Already paid for  — health, provision, peace were bought at the cross;
//                           you're an heir defending an inheritance, not a beggar
//    3. The weapon        — you take it back by speaking; death and life are in
//                           the power of the tongue, so you stand your ground
//    4. Activation        — in Christ you already have it in the spirit; speaking
//                           pulls it down into the physical realm
//
//  Then a product-capability recap (matching the product arm's mid-flow
//  placement), a "what is the enemy trying to steal from you?" picker (which
//  seeds the home feed), and the proven back-half (taste → record your own →
//  rating → plan-building loader → named plan reveal → paywall → notification
//  time). The picker maps each answer to a HeaviestBurden/category so the
//  shared screens + seeding work unchanged.
//
//  One arm of the onboarding A/B: HomeView routes here when Remote Config
//  `onboardingVariant` == "warfare".
//

import SwiftUI
import UserNotifications
import UIKit

struct WarfareOnboardingView: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var declarationStore: DeclarationViewModel
    let size: CGSize
    let onComplete: () -> Void

    // Reuse the survey response model so the shared back-half screens and the
    // seeding logic work unchanged. Only `heaviestBurden` and `notificationTime`
    // are set here (the take-back picker writes `heaviestBurden`).
    @StateObject private var responses = SurveyResponses()
    @State private var currentStep: WarfareStep = .thief
    @State private var savedDeclaration: PersonalDeclaration? = nil

    // Snapshot accessor for the quiz v2 Remote Config flag. When false the
    // flow is byte-for-byte the current quiz (belief step skipped, connect
    // style question shown, no plan-reveal echo).
    private var quizV2: Bool { subscriptionStore.useQuizV2 }

    private var valueProgress: Double {
        guard let idx = currentStep.valueScreenIndex(quizV2: quizV2) else { return 0 }
        return Double(idx) / Double(WarfareStep.totalValueScreens(quizV2: quizV2))
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
        .onAppear { AnalyticsService.shared.track("warfare_onboarding_started") }
    }

    @ViewBuilder
    private var currentStepView: some View {
        switch currentStep {
        case .thief:      WarfareSceneScreen(size: size, scene: .thief) { advance() }
        case .paidFor:    WarfareSceneScreen(size: size, scene: .paidFor) { advance() }
        case .weapon:     WarfareSceneScreen(size: size, scene: .weapon) { advance() }
        case .activation: WarfareSceneScreen(size: size, scene: .activation) { advance() }
        case .experience:
            OnboardingProductExperienceScreen(size: size, flow: "warfare") { advance() }
        case .takeBackPicker:
            WarfareTakeBackPickerScreen(size: size, responses: responses) { advance() }
        case .battleDuration, .alreadyTried, .insight, .hitsHardest, .connectStyle, .belief, .dailyMinutes:
            quizStepView
        default: backHalfView
        }
    }

    // Extended quiz steps (Q2-Q6 + insight), shared with the product arm.
    @ViewBuilder
    private var quizStepView: some View {
        switch currentStep {
        case .battleDuration:
            SurveyExtendedQuizScreen(size: size, flow: "warfare", question: .battleDuration, selection: $responses.battleDuration) { advance() }
        case .alreadyTried:
            SurveyExtendedQuizScreen(size: size, flow: "warfare", question: .alreadyTried, selection: $responses.alreadyTried) { advance() }
        case .insight:
            SurveyQuizInsightScreen(size: size, flow: "warfare") { advance() }
        case .hitsHardest:
            SurveyExtendedQuizScreen(size: size, flow: "warfare", question: .hitsHardest, selection: $responses.hitsHardest) { advance() }
        case .connectStyle:
            // Quiz v2 swaps the connect-style question for the burden-aware
            // outcome question in the same slot; v1 is unchanged.
            if quizV2 {
                SurveyExtendedQuizScreen(size: size, flow: "warfare", question: .victoryLooksLike(for: responses.heaviestBurden ?? .peace), selection: $responses.victoryOutcome) { advance() }
            } else {
                SurveyExtendedQuizScreen(size: size, flow: "warfare", question: .connectStyle, selection: $responses.connectStyle) { advance() }
            }
        case .belief:
            // Quiz v2 only — v1's advance() jumps over this step entirely.
            SurveyExtendedQuizScreen(size: size, flow: "warfare", question: .belief, selection: $responses.beliefLevel) { advance() }
        case .dailyMinutes:
            SurveyExtendedQuizScreen(size: size, flow: "warfare", question: .dailyMinutes, selection: $responses.dailyMinutes) { advance() }
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var backHalfView: some View {
        switch currentStep {
        case .firstDeclaration:
            SurveyFirstDeclarationScreen(size: size, responses: responses, flow: "warfare") { advance() }
        case .personalDeclaration:
            PersonalDeclarationOnboardingView(
                viewModel: DIContainer.shared.makePersonalDeclarationViewModel(),
                size: size,
                flow: "warfare"
            ) { declaration in
                savedDeclaration = declaration
                advance()
            }
        case .rating:
            RatingView(size: size) { advance() }
        case .planBuilding:
            SurveyPlanBuildingScreen(burden: responses.heaviestBurden ?? .peace, flow: "warfare") { advance() }
        case .planReveal:
            SurveyPlanRevealScreen(
                size: size,
                burden: responses.heaviestBurden ?? .peace,
                flow: "warfare",
                personalDeclaration: savedDeclaration?.declarationText,
                dailyMinutes: responses.dailyMinutes,
                victoryEcho: responses.victoryEcho  // nil in quiz v1
            ) { advance() }
        case .paywall:
            HighConversionPaywallView(callback: { advance() }, source: "onboarding", isHardPaywall: true)
        case .notificationTime:
            SurveyQ8NotificationScreen(size: size, responses: responses, flow: "warfare") { advance() }
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
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        AnalyticsService.shared.track("warfare_step_completed", parameters: ["step": currentStep.rawValue])

        // Leaving the take-back picker: stamp the segment so downstream paywall
        // events carry a meaningful segment for this arm (quiz sets its own).
        if currentStep == .takeBackPicker, let burden = responses.heaviestBurden {
            appState.onboardingSegment = "warfare_\(burden.shortLabel)"
        }

        // Leaving the hits-hardest question: pre-select the notification-time
        // screen from when their battle hits (no auto-advance; still editable).
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
            if !quizV2, WarfareStep(rawValue: nextRaw) == .belief {
                nextRaw += 1
            }
            guard let next = WarfareStep(rawValue: nextRaw) else {
                assertionFailure("WarfareOnboardingView.advance(): no successor for \(currentStep). .notificationTime should be terminal.")
                onComplete()
                return
            }
            withAnimation(.easeInOut(duration: 0.35)) { currentStep = next }
        }
    }

    // Mirrors the outcomes/identity completion: persist the chosen category, seed
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
        declarationStore.choose(category) { _ in }
        if let notifTime = responses.notificationTime {
            appState.startTimeIndex = notifTime.startTimeIndex
            appState.endTimeIndex   = notifTime.endTimeIndex
            appState.personalDeclarationTimeIndex = notifTime.startTimeIndex
        }
        appState.hasPersonalDeclaration = savedDeclaration != nil
        AnalyticsService.shared.track("warfare_onboarding_completed", parameters: [
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
            "set_personal_declaration": (savedDeclaration != nil) as NSNumber
        ])

        requestNotificationPermissionThenComplete(categories: notificationCategoriesSet)
    }

    private func requestNotificationPermissionThenComplete(categories: Set<DeclarationCategory>) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            AnalyticsService.shared.track("notification_permission", parameters: ["granted": granted, "source": "warfare_onboarding"])
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
                }
                onComplete()
            }
        }
    }
}

// MARK: - Flow Steps

enum WarfareStep: Int, CaseIterable {
    // Warfare-narrative screens
    case thief          = 0   // the enemy comes to steal, kill, destroy
    case paidFor        = 1   // it's already yours — Jesus paid for it
    case weapon         = 2   // you take it back by speaking
    case activation     = 3   // spiritual truth activated into the physical realm
    case experience     = 4   // product-capability recap (mid-flow, matching the product arm)
    case takeBackPicker = 5   // what is the enemy trying to steal? (seeds the feed)
    // Extended personalization quiz (shared screens in SurveyOnboardingScreens)
    case battleDuration = 6   // Q2: how long has this battle been going on?
    case alreadyTried   = 7   // Q3: what have you already tried?
    case insight        = 8   // micro-insight interstitial (reading vs speaking)
    case hitsHardest    = 9   // Q4: when does it hit hardest? (preselects notification time)
    case connectStyle   = 10  // Q5: connect style (quiz v1) or victory outcome (quiz v2)
    case belief         = 11  // quiz v2 only: do you believe God wants more? (v1 skips it)
    case dailyMinutes   = 12  // Q6: how much time daily? (drives plan reveal rhythm)
    // Shared back-half (reused from the survey flow)
    case firstDeclaration = 13
    case personalDeclaration = 14
    case rating          = 15  // rating ask at the personal-declaration peak
    case planBuilding    = 16  // "building your battle plan" loader (transition, no bar)
    case planReveal      = 17  // named 30-day plan reveal — sets up the paywall ask
    case paywall         = 18
    case notificationTime = 19 // terminal — completes onboarding

    func valueScreenIndex(quizV2: Bool) -> Int? {
        var screens: [WarfareStep] = [
            .thief, .paidFor, .weapon, .activation, .experience, .takeBackPicker,
            .battleDuration, .alreadyTried, .insight, .hitsHardest, .connectStyle, .belief, .dailyMinutes
        ]
        if !quizV2 { screens.removeAll { $0 == .belief } }
        return screens.firstIndex(of: self).map { $0 + 1 }
    }

    static func totalValueScreens(quizV2: Bool) -> Int { quizV2 ? 13 : 12 }
}

// MARK: - Warfare scene content

private enum WarfareScene {
    case thief, paidFor, weapon, activation

    var eyebrow: String {
        switch self {
        case .thief:      return "THERE'S A FIGHT OVER YOUR LIFE"
        case .paidFor:    return "BUT IT'S ALREADY YOURS"
        case .weapon:     return "THIS IS HOW YOU FIGHT BACK"
        case .activation: return "ACTIVATE WHAT'S ALREADY YOURS"
        }
    }

    var title: String {
        switch self {
        case .thief:      return "The thief came\nto take it all."
        case .paidFor:    return "Already bought.\nAlready paid for."
        case .weapon:     return "You take it back\nby speaking."
        case .activation: return "Pull heaven down\ninto your life."
        }
    }

    var body: String {
        switch self {
        case .thief:
            return "Your health. Your provision. Your peace. The enemy comes only to steal, kill, and destroy. Every attack is aimed at something that was meant to be yours."
        case .paidFor:
            return "Healing, provision, peace, freedom. Jesus already purchased every one of them at the cross. You're not begging God for what He's already given. You're an heir defending an inheritance."
        case .weapon:
            return "Death and life are in the power of your tongue. You stand your ground and refuse to let the enemy keep what was bought for you. Every word you speak in faith drives him back."
        case .activation:
            return "In Christ you already have it in the spirit. Speaking is what activates it here, in your body, your home, your finances. You call what's already true in heaven down into your everyday life."
        }
    }

    var verse: String {
        switch self {
        case .thief:      return "The thief comes only to steal and kill and destroy; I have come that they may have life, and have it to the full."
        case .paidFor:    return "He who did not spare his own Son, but gave him up for us all, how will he not also, along with him, graciously give us all things?"
        case .weapon:     return "Death and life are in the power of the tongue, and those who love it will eat its fruit."
        case .activation: return "Your kingdom come, your will be done, on earth as it is in heaven."
        }
    }

    var reference: String {
        switch self {
        case .thief:      return "John 10:10"
        case .paidFor:    return "Romans 8:32"
        case .weapon:     return "Proverbs 18:21"
        case .activation: return "Matthew 6:10"
        }
    }

    var symbol: String {
        switch self {
        case .thief:      return "exclamationmark.shield.fill"
        case .paidFor:    return "checkmark.seal.fill"
        case .weapon:     return "bolt.fill"
        case .activation: return "arrow.down.circle.fill"
        }
    }

    var buttonLabel: String {
        switch self {
        case .activation: return "I'm Ready to Fight →"
        default:          return "Continue →"
        }
    }

    var analyticsName: String {
        switch self {
        case .thief:      return "thief"
        case .paidFor:    return "paid_for"
        case .weapon:     return "weapon"
        case .activation: return "activation"
        }
    }
}

// Each HeaviestBurden carries a "take it back" framed label for the picker.
// Selecting one writes `responses.heaviestBurden`, which the shared back-half
// (preview declaration, notification subtitle) and seeding logic already use.
private struct WarfareTakeBackChoice {
    let statement: String
    let subtitle: String
    let symbol: String

    static func of(_ burden: HeaviestBurden) -> WarfareTakeBackChoice {
        switch burden {
        case .health:
            return WarfareTakeBackChoice(statement: "My health and strength",
                                         subtitle: "Take back the healing already paid for",
                                         symbol: "heart.fill")
        case .abundance:
            return WarfareTakeBackChoice(statement: "My provision",
                                         subtitle: "Take back open doors and overflow",
                                         symbol: "key.fill")
        case .peace:
            return WarfareTakeBackChoice(statement: "My peace and my home",
                                         subtitle: "Take back calm where there's chaos",
                                         symbol: "house.fill")
        case .allOfIt:
            return WarfareTakeBackChoice(statement: "Victory over the attack",
                                         subtitle: "Stand in authority, the enemy flees",
                                         symbol: "bolt.fill")
        case .identity:
            return WarfareTakeBackChoice(statement: "Who I am in Christ",
                                         subtitle: "Take back my secure identity",
                                         symbol: "crown.fill")
        case .purpose:
            return WarfareTakeBackChoice(statement: "My calling and destiny",
                                         subtitle: "Take back the future God promised",
                                         symbol: "flag.fill")
        case .joy:
            return WarfareTakeBackChoice(statement: "My joy",
                                         subtitle: "Take back joy nothing can steal",
                                         symbol: "sun.max.fill")
        }
    }
}

// Lead the picker with the most-attacked areas.
private let warfarePickerOrder: [HeaviestBurden] = [
    .health, .abundance, .peace, .allOfIt, .identity, .purpose, .joy
]

// MARK: - Shared Components

private struct WarfareContinueButton: View {
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
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(isEnabled ? .black : .white.opacity(0.4))
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    Capsule()
                        .fill(isEnabled ? Color.white : Color.white.opacity(0.12))
                )
        }
        .disabled(!isEnabled)
        .padding(.horizontal, 28)
        .animation(.easeInOut(duration: 0.2), value: isEnabled)
    }
}

private struct WarfareAppearStagger: ViewModifier {
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
    func warfareStagger(_ shown: Bool, delay: Double = 0) -> some View {
        modifier(WarfareAppearStagger(shown: shown, delay: delay))
    }
}

// MARK: - Warfare Scene Screen

private struct WarfareSceneScreen: View {
    let size: CGSize
    let scene: WarfareScene
    let onContinue: () -> Void
    @State private var v = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 26) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.10))
                        .frame(width: 96, height: 96)
                    Image(systemName: scene.symbol)
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                }
                .warfareStagger(v)

                VStack(spacing: 14) {
                    Text(scene.eyebrow)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                        .kerning(1.4)
                        .multilineTextAlignment(.center)
                        .warfareStagger(v, delay: 0.08)

                    Text(scene.title)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .warfareStagger(v, delay: 0.14)

                    Text(scene.body)
                        .font(.system(size: 17, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 22)
                        .fixedSize(horizontal: false, vertical: true)
                        .warfareStagger(v, delay: 0.22)
                }

                VStack(spacing: 4) {
                    Text("\"\(scene.verse)\"")
                        .font(.system(size: 15, weight: .regular, design: .serif))
                        .italic()
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(scene.reference)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.45))
                }
                .padding(.horizontal, 28)
                .warfareStagger(v, delay: 0.32)
            }
            .padding(.horizontal, 28)

            Spacer()

            WarfareContinueButton(label: scene.buttonLabel) { onContinue() }
                .padding(.bottom, 36)
                .warfareStagger(v, delay: 0.42)
        }
        .onAppear {
            AnalyticsService.shared.track("warfare_scene_shown", parameters: ["scene": scene.analyticsName])
            withAnimation { v = true }
        }
    }
}

// MARK: - Take-Back Picker (seeds the feed)

private struct WarfareTakeBackPickerScreen: View {
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
                        Text("What is the enemy trying\nto steal from you right now?")
                            .font(.system(size: 27, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .warfareStagger(v)

                        Text("We'll arm you with daily declarations\nto take it back and stand your ground.")
                            .font(.system(size: 15, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.65))
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                            .warfareStagger(v, delay: 0.1)
                    }
                    .padding(.horizontal, 28)

                    VStack(spacing: 10) {
                        ForEach(warfarePickerOrder) { burden in
                            takeBackRow(burden)
                        }
                    }
                    .padding(.horizontal, 20)
                    .warfareStagger(v, delay: 0.2)

                    Spacer().frame(height: 8)
                }
            }

            WarfareContinueButton(isEnabled: responses.heaviestBurden != nil, action: onContinue)
                .padding(.top, 8).padding(.bottom, 36)
        }
        .onAppear {
            AnalyticsService.shared.track("warfare_picker_shown")
            withAnimation { v = true }
        }
    }

    private func takeBackRow(_ burden: HeaviestBurden) -> some View {
        let choice = WarfareTakeBackChoice.of(burden)
        let isSelected = responses.heaviestBurden == burden
        return Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            responses.heaviestBurden = burden
        }) {
            HStack(spacing: 14) {
                Image(systemName: choice.symbol)
                    .font(.system(size: 22))
                    .foregroundColor(.white.opacity(isSelected ? 1 : 0.7))
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
                        .strokeBorder(isSelected ? Color.white : Color.white.opacity(0.35), lineWidth: 1.5)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle().fill(Color.white).frame(width: 12, height: 12)
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
                            .strokeBorder(isSelected ? Color.white.opacity(0.5) : Color.white.opacity(0.12), lineWidth: 1)
                    )
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
