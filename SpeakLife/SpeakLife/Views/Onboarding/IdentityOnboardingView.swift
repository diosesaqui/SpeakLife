//
//  IdentityOnboardingView.swift
//  SpeakLife
//
//  An identity-led onboarding A/B variant. Where the quiz flow leads with a
//  belief sequence and the product flow leads with value props, this flow is
//  built entirely around IDENTITY IN CHRIST — silencing the labels the world
//  assigns and replacing them with who God says the user is:
//
//    1. The lie       — you are not who your worst day says you are
//    2. The verdict   — in Christ you are a new creation
//    3. Named & chosen— chosen, redeemed, called by name (1 Peter 2:9)
//    4. The mechanism — identity is renewed by declaring it out loud
//    5. Stand in it   — pick the truth to anchor (seeds the home feed)
//
//  After the identity screens it reuses the proven back-half (taste of a
//  personalized declaration → record your own → rating → paywall →
//  notification time), and seeds the home feed from the identity picker, which maps
//  each truth to a HeaviestBurden/category so the shared screens work unchanged.
//
//  Shown when Remote Config `onboardingVariant` == "identity".
//

import SwiftUI
import FirebaseAnalytics
import UserNotifications
import UIKit

struct IdentityOnboardingView: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var declarationStore: DeclarationViewModel
    let size: CGSize
    let onComplete: () -> Void

    // Reuse the survey response model so the shared back-half screens and the
    // seeding logic work unchanged. Only `heaviestBurden` and `notificationTime`
    // are set here (the identity picker writes `heaviestBurden`).
    @StateObject private var responses = SurveyResponses()
    @State private var currentStep: IdentityStep = .lie
    @State private var savedDeclaration: PersonalDeclaration? = nil

    private var valueProgress: Double {
        guard let idx = currentStep.valueScreenIndex else { return 0 }
        return Double(idx) / Double(IdentityStep.totalValueScreens)
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
        .onAppear { AnalyticsService.shared.track("identity_onboarding_started") }
    }

    @ViewBuilder
    private var currentStepView: some View {
        switch currentStep {
        case .lie:         IdentityLieScreen(size: size) { advance() }
        case .verdict:     IdentityVerdictScreen(size: size) { advance() }
        case .named:       IdentityNamedScreen(size: size) { advance() }
        case .mechanism:   IdentityMechanismScreen(size: size) { advance() }
        case .identityPicker:
            IdentityPickerScreen(size: size, responses: responses) { advance() }
        default: backHalfView
        }
    }

    @ViewBuilder
    private var backHalfView: some View {
        switch currentStep {
        case .firstDeclaration:
            SurveyFirstDeclarationScreen(size: size, responses: responses, flow: "identity") { advance() }
        case .personalDeclaration:
            PersonalDeclarationOnboardingView(
                viewModel: DIContainer.shared.makePersonalDeclarationViewModel(),
                size: size,
                flow: "identity"
            ) { declaration in
                savedDeclaration = declaration
                advance()
            }
        case .testimonials:
            TestimonialWallView(size: size, flow: "identity") { advance() }
        case .paywall:
            HighConversionPaywallView(callback: { advance() }, source: "onboarding", isHardPaywall: true)
        case .notificationTime:
            SurveyQ8NotificationScreen(size: size, responses: responses, flow: "identity") { advance() }
        case .rating:
            RatingView(size: size) { advance() }
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
        // flow_schema 2 = testimonial wall inserted before paywall (absent/1 = original layout); bump when step raw values are renumbered again.
        AnalyticsService.shared.track("identity_step_completed", parameters: ["step": currentStep.rawValue, "flow_schema": 2])

        // Leaving the identity picker: stamp the segment so downstream paywall
        // events carry a meaningful segment for this arm (quiz sets its own).
        // Without this the identity arm was invisible to segment-based paywall
        // copy — every other variant has had this block since launch.
        if currentStep == .identityPicker, let burden = responses.heaviestBurden {
            appState.onboardingSegment = "identity_\(burden.shortLabel)"
        }

        switch currentStep {
        case .notificationTime:
            applyResponsesAndComplete()
        default:
            var nextRaw = currentStep.rawValue + 1
            // Rating ask is remote-gated (onboardingRatingEnabled); when off,
            // skip straight past it to the next step.
            if IdentityStep(rawValue: nextRaw) == .rating, !subscriptionStore.onboardingRatingEnabled {
                nextRaw += 1
            }
            guard let next = IdentityStep(rawValue: nextRaw) else {
                assertionFailure("IdentityOnboardingView.advance(): no successor for \(currentStep). .notificationTime should be terminal.")
                onComplete()
                return
            }
            withAnimation(.easeInOut(duration: 0.35)) { currentStep = next }
        }
    }

    // Mirrors the product/survey completion: persist the chosen category, seed
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
        // Capture what this arm learned. It asks the fewest questions of the
        // seven, so most fields land nil — that's expected, the profile is
        // built to be partial. Shared mapping — see SoulProfileBuilder.
        SoulProfileBuilder.captureAtOnboardingCompletion(
            responses: responses,
            appState: appState,
            variant: "identity",
            quizVersion: "v1",
            anchorBeliefText: savedDeclaration?.beliefText
        )
        AnalyticsService.shared.track("identity_onboarding_completed", parameters: [
            "goal_word": goalWord.rawValue,
            "burden": responses.heaviestBurden?.rawValue ?? "unknown",
            "set_personal_declaration": (savedDeclaration != nil) as NSNumber
        ])

        requestNotificationPermissionThenComplete(categories: notificationCategoriesSet)
    }

    private func requestNotificationPermissionThenComplete(categories: Set<DeclarationCategory>) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            AnalyticsService.shared.track("notification_permission", parameters: ["granted": granted, "source": "identity_onboarding"])
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

enum IdentityStep: Int, CaseIterable {
    // Identity-led screens
    case lie            = 0   // the world's labels
    case verdict        = 1   // new creation
    case named          = 2   // chosen, redeemed, called by name
    case mechanism      = 3   // renew the mind by declaring
    case identityPicker = 4   // pick the truth to stand in (seeds the feed)
    // Shared back-half (reused from the survey flow)
    case firstDeclaration = 5
    case personalDeclaration = 6
    case rating          = 7   // rating ask at the personal-declaration peak
    case testimonials    = 8   // App Store review wall — social proof right before the ask
    case paywall         = 9
    case notificationTime = 10 // terminal — completes onboarding

    var valueScreenIndex: Int? {
        let screens: [IdentityStep] = [.lie, .verdict, .named, .mechanism, .identityPicker]
        return screens.firstIndex(of: self).map { $0 + 1 }
    }

    static let totalValueScreens = 5
}

// MARK: - Identity truth mapping
//
// Each HeaviestBurden carries an identity-framed label + a curated "I am"
// statement. Selecting one writes `responses.heaviestBurden`, which the shared
// back-half (preview declaration, notification subtitle) and the seeding logic
// already understand — so the identity picker stays fully compatible.
private struct IdentityTruth {
    let statement: String   // headline "I am ..." for the row
    let subtitle: String    // supporting line
    let symbol: String      // SF Symbol

    static func of(_ burden: HeaviestBurden) -> IdentityTruth {
        switch burden {
        case .identity:
            return IdentityTruth(statement: "I am chosen and dearly loved",
                                 subtitle: "Secure in who God says I am",
                                 symbol: "crown.fill")
        case .purpose:
            return IdentityTruth(statement: "I am called and sent",
                                 subtitle: "Living out what God made me for",
                                 symbol: "flag.fill")
        case .allOfIt:
            return IdentityTruth(statement: "I am more than a conqueror",
                                 subtitle: "Victorious in every battle",
                                 symbol: "bolt.fill")
        case .peace:
            return IdentityTruth(statement: "I am anchored in peace",
                                 subtitle: "Unshaken no matter the storm",
                                 symbol: "leaf.fill")
        case .joy:
            return IdentityTruth(statement: "I carry unshakeable joy",
                                 subtitle: "Strength no circumstance can touch",
                                 symbol: "sun.max.fill")
        case .health:
            return IdentityTruth(statement: "I am healed and whole",
                                 subtitle: "Restored in body, mind, and spirit",
                                 symbol: "heart.fill")
        case .abundance:
            return IdentityTruth(statement: "I have more than enough",
                                 subtitle: "Provided for, never in lack",
                                 symbol: "sparkles")
        }
    }
}

// Order the picker so the most identity-core truths lead.
private let identityPickerOrder: [HeaviestBurden] = [
    .identity, .purpose, .allOfIt, .peace, .joy, .health, .abundance
]

// MARK: - Shared Components

private struct IdentityContinueButton: View {
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

private struct IdentityAppearStagger: ViewModifier {
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
    func identityStagger(_ shown: Bool, delay: Double = 0) -> some View {
        modifier(IdentityAppearStagger(shown: shown, delay: delay))
    }
}

// A simple scripture block reused across the identity screens.
private struct IdentityScripture: View {
    let verse: String
    let reference: String

    var body: some View {
        VStack(spacing: 4) {
            Text("\"\(verse)\"")
                .font(.system(size: 15, weight: .regular, design: .serif))
                .italic()
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text(reference)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.45))
        }
    }
}

// MARK: - 1. The Lie

private struct IdentityLieScreen: View {
    let size: CGSize
    let onContinue: () -> Void
    @State private var v = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                Text("You are not who your\nworst day says you are.")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .identityStagger(v)

                Text("The world keeps handing you labels.\nNot enough. Too much. Too far gone.\nWear them long enough and they start to feel true.")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .identityStagger(v, delay: 0.12)

                Text("But a label is not the truth about you.\nGod already decided who you are.")
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 24)
                    .fixedSize(horizontal: false, vertical: true)
                    .identityStagger(v, delay: 0.24)
            }
            .padding(.horizontal, 28)

            Spacer()

            IdentityContinueButton(label: "Show Me Who I Am →") { onContinue() }
                .padding(.bottom, 36)
                .identityStagger(v, delay: 0.36)
        }
        .onAppear {
            AnalyticsService.shared.track("identity_lie_shown")
            withAnimation { v = true }
        }
    }
}

// MARK: - 2. The Verdict (new creation)

private struct IdentityVerdictScreen: View {
    let size: CGSize
    let onContinue: () -> Void
    @State private var v = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 26) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 54, weight: .light))
                    .foregroundColor(.white)
                    .identityStagger(v)

                VStack(spacing: 14) {
                    Text("In Christ, you are made new.")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .identityStagger(v, delay: 0.12)

                    Text("The old you. The failures, the shame, the labels.\nNot patched up. Not on probation. Gone.\nYou are a new creation.")
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.72))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 24)
                        .fixedSize(horizontal: false, vertical: true)
                        .identityStagger(v, delay: 0.24)
                }

                IdentityScripture(
                    verse: "If anyone is in Christ, the new creation has come: The old has gone, the new is here.",
                    reference: "2 Corinthians 5:17"
                )
                .padding(.horizontal, 28)
                .identityStagger(v, delay: 0.36)
            }
            .padding(.horizontal, 28)

            Spacer()

            IdentityContinueButton(label: "Continue →") { onContinue() }
                .padding(.bottom, 36)
                .identityStagger(v, delay: 0.46)
        }
        .onAppear {
            AnalyticsService.shared.track("identity_verdict_shown")
            withAnimation { v = true }
        }
    }
}

// MARK: - 3. Named & Chosen

private struct IdentityNamedScreen: View {
    let size: CGSize
    let onContinue: () -> Void
    @State private var v = false

    private let truths = ["I am chosen.", "I am redeemed.", "I am called by name.", "I am God's own."]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 26) {
                    Spacer().frame(height: size.height * 0.12)

                    VStack(spacing: 12) {
                        Text("Chosen. Redeemed.\nCalled by name.")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .identityStagger(v)

                        Text("You are not an accident or an afterthought.\nBefore your first breath, God chose you\nand wrote His name over your life.")
                            .font(.system(size: 16, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.horizontal, 20)
                            .fixedSize(horizontal: false, vertical: true)
                            .identityStagger(v, delay: 0.12)
                    }
                    .padding(.horizontal, 28)

                    VStack(spacing: 10) {
                        ForEach(Array(truths.enumerated()), id: \.offset) { idx, truth in
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(DS.Palette.gold.opacity(0.95))
                                Text(truth)
                                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 14)
                            .dsGlass(cornerRadius: DS.Radius.md)
                            .identityStagger(v, delay: 0.2 + Double(idx) * 0.08)
                        }
                    }
                    .padding(.horizontal, 24)

                    IdentityScripture(
                        verse: "You are a chosen people, a royal priesthood, a holy nation, God's special possession.",
                        reference: "1 Peter 2:9"
                    )
                    .padding(.horizontal, 28)
                    .identityStagger(v, delay: 0.56)

                    Spacer().frame(height: 8)
                }
            }

            IdentityContinueButton(label: "I Want to Believe This →") { onContinue() }
                .padding(.top, 8).padding(.bottom, 36)
                .identityStagger(v, delay: 0.62)
        }
        .onAppear {
            AnalyticsService.shared.track("identity_named_shown")
            withAnimation { v = true }
        }
    }
}

// MARK: - 4. The Mechanism (renew the mind)

private struct IdentityMechanismScreen: View {
    let size: CGSize
    let onContinue: () -> Void
    @State private var v = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 26) {
                    Spacer().frame(height: size.height * 0.12)

                    VStack(spacing: 12) {
                        Text("You become what you\nkeep agreeing with.")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .identityStagger(v)

                        Text("You don't fix your identity by trying harder.\nYou say what God says about you, out loud, until your heart starts to believe it too.")
                            .font(.system(size: 16, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.horizontal, 22)
                            .fixedSize(horizontal: false, vertical: true)
                            .identityStagger(v, delay: 0.12)
                    }
                    .padding(.horizontal, 28)

                    HStack(spacing: 12) {
                        mechanismCard(
                            tag: "THE OLD STORY",
                            icon: "exclamationmark.bubble",
                            title: "Repeating\nthe lie",
                            highlighted: false
                        )
                        mechanismCard(
                            tag: "SPEAKLIFE",
                            icon: "waveform",
                            title: "Declaring\nthe truth",
                            highlighted: true
                        )
                    }
                    .padding(.horizontal, 24)
                    .identityStagger(v, delay: 0.24)

                    IdentityScripture(
                        verse: "Be transformed by the renewing of your mind.",
                        reference: "Romans 12:2"
                    )
                    .padding(.horizontal, 28)
                    .identityStagger(v, delay: 0.36)

                    Spacer().frame(height: 8)
                }
            }

            IdentityContinueButton(label: "Continue →") { onContinue() }
                .padding(.top, 8).padding(.bottom, 36)
                .identityStagger(v, delay: 0.42)
        }
        .onAppear {
            AnalyticsService.shared.track("identity_mechanism_shown")
            withAnimation { v = true }
        }
    }

    private func mechanismCard(tag: String, icon: String, title: String, highlighted: Bool) -> some View {
        VStack(spacing: 12) {
            Text(tag)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(highlighted ? DS.Palette.gold.opacity(0.9) : .white.opacity(0.45))
                .kerning(1.0)
            Image(systemName: icon)
                .font(.system(size: 30))
                .foregroundColor(highlighted ? .white : .white.opacity(0.4))
            Text(title)
                .font(.system(size: 15, weight: highlighted ? .bold : .regular, design: .rounded))
                .foregroundColor(highlighted ? .white : .white.opacity(0.6))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(highlighted ? Color.white.opacity(0.14) : Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(highlighted ? Color.white.opacity(0.5) : Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }
}

// MARK: - 5. Identity Picker (seeds the feed)

private struct IdentityPickerScreen: View {
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
                        Text("Which truth do you most\nneed to hold onto?")
                            .font(.system(size: 27, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .identityStagger(v)

                        Text("We'll build your daily declarations around it,\nso this truth sinks in deep.")
                            .font(.system(size: 15, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.65))
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                            .identityStagger(v, delay: 0.1)
                    }
                    .padding(.horizontal, 28)

                    VStack(spacing: 10) {
                        ForEach(identityPickerOrder) { burden in
                            truthRow(burden)
                        }
                    }
                    .padding(.horizontal, 20)
                    .identityStagger(v, delay: 0.2)

                    Spacer().frame(height: 8)
                }
            }

            IdentityContinueButton(isEnabled: responses.heaviestBurden != nil, action: onContinue)
                .padding(.top, 8).padding(.bottom, 36)
        }
        .onAppear {
            AnalyticsService.shared.track("identity_picker_shown")
            withAnimation { v = true }
        }
    }

    private func truthRow(_ burden: HeaviestBurden) -> some View {
        let truth = IdentityTruth.of(burden)
        let isSelected = responses.heaviestBurden == burden
        return Button(action: {
            Juice.play(.tapLight)
            responses.heaviestBurden = burden
        }) {
            HStack(spacing: 14) {
                Image(systemName: truth.symbol)
                    .font(.system(size: 22))
                    .foregroundColor(.white.opacity(isSelected ? 1 : 0.7))
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 3) {
                    Text(truth.statement)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(truth.subtitle)
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
