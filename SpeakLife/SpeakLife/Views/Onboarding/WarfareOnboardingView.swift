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
//  Then a "what is the enemy trying to steal from you?" picker (which seeds the
//  home feed), and the proven back-half (taste → record your own → rating →
//  paywall → notification time). The picker maps each answer to a
//  HeaviestBurden/category so the shared screens + seeding work unchanged.
//
//  One arm of the onboarding A/B: HomeView routes here when Remote Config
//  `onboardingVariant` == "warfare".
//

import SwiftUI
import FirebaseAnalytics
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

    private var valueProgress: Double {
        guard let idx = currentStep.valueScreenIndex else { return 0 }
        return Double(idx) / Double(WarfareStep.totalValueScreens)
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

            if currentStep.valueScreenIndex != nil {
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
        .onAppear { Analytics.logEvent("warfare_onboarding_started", parameters: nil) }
    }

    @ViewBuilder
    private var currentStepView: some View {
        switch currentStep {
        case .thief:      WarfareSceneScreen(size: size, scene: .thief) { advance() }
        case .paidFor:    WarfareSceneScreen(size: size, scene: .paidFor) { advance() }
        case .weapon:     WarfareSceneScreen(size: size, scene: .weapon) { advance() }
        case .activation: WarfareSceneScreen(size: size, scene: .activation) { advance() }
        case .takeBackPicker:
            WarfareTakeBackPickerScreen(size: size, responses: responses) { advance() }
        default: backHalfView
        }
    }

    @ViewBuilder
    private var backHalfView: some View {
        switch currentStep {
        case .firstDeclaration:
            SurveyFirstDeclarationScreen(size: size, responses: responses) { advance() }
        case .personalDeclaration:
            PersonalDeclarationOnboardingView(
                viewModel: DIContainer.shared.makePersonalDeclarationViewModel(),
                size: size
            ) { declaration in
                savedDeclaration = declaration
                advance()
            }
        case .rating:
            RatingView(size: size) { advance() }
        case .paywall:
            HighConversionPaywallView(callback: { advance() })
        case .notificationTime:
            SurveyQ8NotificationScreen(size: size, responses: responses) { advance() }
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
        Analytics.logEvent("warfare_step_completed", parameters: ["step": currentStep.rawValue])

        switch currentStep {
        case .notificationTime:
            applyResponsesAndComplete()
        default:
            let nextRaw = currentStep.rawValue + 1
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
        Analytics.logEvent("warfare_onboarding_completed", parameters: [
            "goal_word": goalWord.rawValue,
            "burden": responses.heaviestBurden?.rawValue ?? "unknown",
            "set_personal_declaration": (savedDeclaration != nil) as NSNumber
        ])

        requestNotificationPermissionThenComplete(categories: notificationCategoriesSet)
    }

    private func requestNotificationPermissionThenComplete(categories: Set<DeclarationCategory>) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            Analytics.logEvent("notification_permission", parameters: ["granted": granted, "source": "warfare_onboarding"])
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
    case takeBackPicker = 4   // what is the enemy trying to steal? (seeds the feed)
    // Shared back-half (reused from the survey flow)
    case firstDeclaration = 5
    case personalDeclaration = 6
    case rating          = 7   // rating ask at the personal-declaration peak
    case paywall         = 8
    case notificationTime = 9  // terminal — completes onboarding

    var valueScreenIndex: Int? {
        let screens: [WarfareStep] = [.thief, .paidFor, .weapon, .activation, .takeBackPicker]
        return screens.firstIndex(of: self).map { $0 + 1 }
    }

    static let totalValueScreens = 5
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
            Analytics.logEvent("warfare_scene_shown", parameters: ["scene": scene.analyticsName])
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
            Analytics.logEvent("warfare_picker_shown", parameters: nil)
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
