//
//  OutcomesOnboardingView.swift
//  SpeakLife
//
//  An outcome-visualization onboarding A/B variant. Instead of asking questions
//  or pitching features, each screen DEMONSTRATES the best-case life that
//  speaking God's Word produces — the "after" the user is reaching for:
//
//    1. Health restored      — a body walking in the healing already paid for
//    2. Open doors           — provision, opportunity, breakthrough
//    3. Peace in your home    — the storm stilled, relationships mended
//    4. Victorious identity   — authority over warfare + who you are in Christ
//
//  Then a "which breakthrough do you most need to see?" picker (which seeds the
//  home feed), and the proven back-half (taste → record your own → rating →
//  paywall → notification time). The picker maps each outcome to a
//  HeaviestBurden/category so the shared screens + seeding work unchanged.
//
//  One arm of the onboarding A/B: HomeView routes here when Remote Config
//  `onboardingVariant` == "outcomes".
//

import SwiftUI
import FirebaseAnalytics
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
    @State private var currentStep: OutcomesStep = .health
    @State private var savedDeclaration: PersonalDeclaration? = nil

    private var valueProgress: Double {
        guard let idx = currentStep.valueScreenIndex else { return 0 }
        return Double(idx) / Double(OutcomesStep.totalValueScreens)
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
        .onAppear { Analytics.logEvent("outcomes_onboarding_started", parameters: nil) }
    }

    @ViewBuilder
    private var currentStepView: some View {
        switch currentStep {
        case .health:    OutcomeVisionScreen(size: size, vision: .health) { advance() }
        case .provision: OutcomeVisionScreen(size: size, vision: .provision) { advance() }
        case .peace:     OutcomeVisionScreen(size: size, vision: .peace) { advance() }
        case .identity:  OutcomeVisionScreen(size: size, vision: .identity) { advance() }
        case .outcomePicker:
            OutcomePickerScreen(size: size, responses: responses) { advance() }
        default: backHalfView
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
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        Analytics.logEvent("outcomes_step_completed", parameters: ["step": currentStep.rawValue])

        switch currentStep {
        case .notificationTime:
            applyResponsesAndComplete()
        default:
            let nextRaw = currentStep.rawValue + 1
            guard let next = OutcomesStep(rawValue: nextRaw) else {
                assertionFailure("OutcomesOnboardingView.advance(): no successor for \(currentStep). .notificationTime should be terminal.")
                onComplete()
                return
            }
            withAnimation(.easeInOut(duration: 0.35)) { currentStep = next }
        }
    }

    // Mirrors the product/identity completion: persist the chosen category, seed
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
        Analytics.logEvent("outcomes_onboarding_completed", parameters: [
            "goal_word": goalWord.rawValue,
            "burden": responses.heaviestBurden?.rawValue ?? "unknown",
            "set_personal_declaration": (savedDeclaration != nil) as NSNumber
        ])

        requestNotificationPermissionThenComplete(categories: notificationCategoriesSet)
    }

    private func requestNotificationPermissionThenComplete(categories: Set<DeclarationCategory>) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            Analytics.logEvent("notification_permission", parameters: ["granted": granted, "source": "outcomes_onboarding"])
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

enum OutcomesStep: Int, CaseIterable {
    // Outcome-demonstration screens
    case health         = 0
    case provision      = 1
    case peace          = 2
    case identity       = 3   // warfare authority + new identity in Christ
    case outcomePicker  = 4   // pick the breakthrough to see first (seeds the feed)
    // Shared back-half (reused from the survey flow)
    case firstDeclaration = 5
    case personalDeclaration = 6
    case rating          = 7   // rating ask at the personal-declaration peak
    case paywall         = 8
    case notificationTime = 9  // terminal — completes onboarding

    var valueScreenIndex: Int? {
        let screens: [OutcomesStep] = [.health, .provision, .peace, .identity, .outcomePicker]
        return screens.firstIndex(of: self).map { $0 + 1 }
    }

    static let totalValueScreens = 5
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
                        .fill(Color.white.opacity(0.10))
                        .frame(width: 96, height: 96)
                    Image(systemName: vision.symbol)
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                }
                .outcomeStagger(v)

                VStack(spacing: 14) {
                    Text(vision.eyebrow)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
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
            Analytics.logEvent("outcome_vision_shown", parameters: ["outcome": vision.analyticsName])
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
            Analytics.logEvent("outcome_picker_shown", parameters: nil)
            withAnimation { v = true }
        }
    }

    private func outcomeRow(_ burden: HeaviestBurden) -> some View {
        let choice = OutcomeChoice.of(burden)
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
