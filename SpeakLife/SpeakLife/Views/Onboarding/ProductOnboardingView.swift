//
//  ProductOnboardingView.swift
//  SpeakLife
//
//  A value-led ("product type") onboarding A/B variant. Instead of
//  interrogating the user with quiz/poll questions up front, it leads with
//  the product's promise using the five marketing-psychology principles:
//
//    1. Speed            — peace in under 60 seconds
//    2. New mechanism    — speaking the Word, not just reading it
//    3. Good experience  — designed for the middle of the storm
//    4. Clarity          — done-for-you declarations for what you're facing
//    5. Avoid discomfort — stop white-knuckling the anxiety loop
//
//  After the value screens it reuses the proven back-half (taste of a
//  personalized declaration → record your own → paywall → notification time
//  → rating), and seeds the home feed from a single light category picker.
//
//  Gated by Remote Config `useProductOnboarding`, evaluated only for the
//  non-quiz cohort (useQuizOnboarding == false).
//

import SwiftUI
import FirebaseAnalytics
import UserNotifications
import UIKit

struct ProductOnboardingView: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var declarationStore: DeclarationViewModel
    let size: CGSize
    let onComplete: () -> Void

    // Reuse the survey response model so the shared back-half screens
    // (first-declaration taste, notification time) and the seeding logic all
    // work unchanged. Only `heaviestBurden` and `notificationTime` are set here.
    @StateObject private var responses = SurveyResponses()
    @State private var currentStep: ProductStep = .hook
    @State private var savedDeclaration: PersonalDeclaration? = nil

    private var valueProgress: Double {
        guard let idx = currentStep.valueScreenIndex else { return 0 }
        return Double(idx) / Double(ProductStep.totalValueScreens)
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
        .onAppear { Analytics.logEvent("product_onboarding_started", parameters: nil) }
    }

    // Split to stay within SwiftUI's 10-branch ViewBuilder limit.
    @ViewBuilder
    private var currentStepView: some View {
        switch currentStep {
        case .hook:        ProductHookScreen(size: size) { advance() }
        case .speed:       ProductSpeedScreen(size: size) { advance() }
        case .mechanism:   ProductMechanismScreen(size: size) { advance() }
        case .experience:  ProductExperienceScreen(size: size) { advance() }
        case .categoryPicker:
            ProductCategoryPickerScreen(size: size, responses: responses) { advance() }
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
        case .paywall:
            HighConversionPaywallView(callback: { advance() })
        case .notificationTime:
            SurveyQ8NotificationScreen(size: size, responses: responses) { advance() }
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
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        Analytics.logEvent("product_step_completed", parameters: ["step": currentStep.rawValue])

        switch currentStep {
        case .rating:
            onComplete()
        case .notificationTime:
            applyResponsesAndContinueToRating()
        default:
            let nextRaw = currentStep.rawValue + 1
            guard let next = ProductStep(rawValue: nextRaw) else {
                assertionFailure("ProductOnboardingView.advance(): no successor for \(currentStep). .rating should be terminal.")
                onComplete()
                return
            }
            withAnimation(.easeInOut(duration: 0.35)) { currentStep = next }
        }
    }

    // Mirrors SurveyOnboardingView's completion: persist the user's selected
    // category, seed the home feed + notifications from it, then prime rating.
    private func applyResponsesAndContinueToRating() {
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
        Analytics.logEvent("product_onboarding_completed", parameters: [
            "goal_word": goalWord.rawValue,
            "burden": responses.heaviestBurden?.rawValue ?? "unknown",
            "set_personal_declaration": (savedDeclaration != nil) as NSNumber
        ])

        requestNotificationPermissionThenAdvanceToRating(categories: notificationCategoriesSet)
    }

    private func requestNotificationPermissionThenAdvanceToRating(categories: Set<DeclarationCategory>) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            Analytics.logEvent("notification_permission", parameters: ["granted": granted, "source": "product_onboarding"])
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
                withAnimation(.easeInOut(duration: 0.35)) { currentStep = .rating }
            }
        }
    }
}

// MARK: - Flow Steps

enum ProductStep: Int, CaseIterable {
    // Value-led screens (the five marketing principles)
    case hook            = 0   // Avoid discomfort
    case speed           = 1   // Speed
    case mechanism       = 2   // New mechanism
    case experience      = 3   // Good experience
    case categoryPicker  = 4   // Clarity + personalization
    // Shared back-half (reused from the survey flow)
    case firstDeclaration = 5  // taste before paywall
    case personalDeclaration = 6
    case paywall         = 7
    case notificationTime = 8  // post-paywall
    case rating          = 9   // terminal — SKStoreReviewController prime

    // Index within the value-led intro screens, used to drive the progress bar.
    var valueScreenIndex: Int? {
        let screens: [ProductStep] = [.hook, .speed, .mechanism, .experience, .categoryPicker]
        return screens.firstIndex(of: self).map { $0 + 1 }
    }

    static let totalValueScreens = 5
}

// MARK: - Shared Components

private struct ProductContinueButton: View {
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

// A staggered fade/rise modifier used by the value screens.
private struct AppearStagger: ViewModifier {
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
    func appearStagger(_ shown: Bool, delay: Double = 0) -> some View {
        modifier(AppearStagger(shown: shown, delay: delay))
    }
}

// MARK: - 1. Hook (Avoid Discomfort)

private struct ProductHookScreen: View {
    let size: CGSize
    let onContinue: () -> Void
    @State private var v = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                Text("When life hits hard,\nyou don't have to face it alone.")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .appearStagger(v)

                Text("In the middle of a storm, you don't need a 45-minute sermon.\nYou need God's Word for this exact moment.")
                    .font(.system(size: 19, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .appearStagger(v, delay: 0.12)

                Text("There's a way through every storm. It's been in the Bible the whole time. We put it right in your hands.")
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 24)
                    .fixedSize(horizontal: false, vertical: true)
                    .appearStagger(v, delay: 0.24)
            }
            .padding(.horizontal, 28)

            Spacer()

            ProductContinueButton(label: "Show Me How →") { onContinue() }
                .padding(.bottom, 36)
                .appearStagger(v, delay: 0.36)
        }
        .onAppear {
            Analytics.logEvent("product_hook_shown", parameters: nil)
            withAnimation { v = true }
        }
    }
}

// MARK: - 2. Speed

private struct ProductSpeedScreen: View {
    let size: CGSize
    let onContinue: () -> Void
    @State private var v = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 28) {
                // Stopwatch motif for the speed promise
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.15), lineWidth: 6)
                        .frame(width: 132, height: 132)
                    Circle()
                        .trim(from: 0, to: 0.92)
                        .stroke(Color.white, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 132, height: 132)
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text(":60")
                            .font(.system(size: 40, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        Text("seconds")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.55))
                    }
                }
                .appearStagger(v)

                VStack(spacing: 12) {
                    Text("Peace in under 60 seconds.")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .appearStagger(v, delay: 0.12)

                    Text("No chapters to find. No study to sit through.\nOpen SpeakLife, speak the exact word for your moment, and you're standing again. Faster than the spiral.")
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 24)
                        .fixedSize(horizontal: false, vertical: true)
                        .appearStagger(v, delay: 0.24)
                }
            }
            .padding(.horizontal, 28)

            Spacer()

            ProductContinueButton(label: "Continue →") { onContinue() }
                .padding(.bottom, 36)
                .appearStagger(v, delay: 0.36)
        }
        .onAppear {
            Analytics.logEvent("product_speed_shown", parameters: nil)
            withAnimation { v = true }
        }
    }
}

// MARK: - 3. New Mechanism

private struct ProductMechanismScreen: View {
    let size: CGSize
    let onContinue: () -> Void
    @State private var v = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 26) {
                    Spacer().frame(height: size.height * 0.12)

                    VStack(spacing: 12) {
                        Text("You've read it.\nHave you spoken it?")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .appearStagger(v)

                        Text("Most apps hand you something to read.\nSpeakLife puts the Word in your mouth.")
                            .font(.system(size: 16, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.horizontal, 24)
                            .fixedSize(horizontal: false, vertical: true)
                            .appearStagger(v, delay: 0.12)
                    }
                    .padding(.horizontal, 28)

                    // Old way vs SpeakLife way
                    HStack(spacing: 12) {
                        mechanismCard(
                            tag: "THE OLD WAY",
                            icon: "book.closed",
                            title: "Reading about\nthe storm",
                            highlighted: false
                        )
                        mechanismCard(
                            tag: "SPEAKLIFE",
                            icon: "waveform",
                            title: "Speaking to\nthe storm",
                            highlighted: true
                        )
                    }
                    .padding(.horizontal, 24)
                    .appearStagger(v, delay: 0.24)

                    VStack(spacing: 4) {
                        Text("\"Death and life are in the power of the tongue.\"")
                            .font(.system(size: 15, weight: .regular, design: .serif))
                            .italic()
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                        Text("Proverbs 18:21")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.45))
                    }
                    .padding(.horizontal, 28)
                    .appearStagger(v, delay: 0.36)

                    Spacer().frame(height: 8)
                }
            }

            ProductContinueButton(label: "I Want That →") { onContinue() }
                .padding(.top, 8).padding(.bottom, 36)
                .appearStagger(v, delay: 0.42)
        }
        .onAppear {
            Analytics.logEvent("product_mechanism_shown", parameters: nil)
            withAnimation { v = true }
        }
    }

    private func mechanismCard(tag: String, icon: String, title: String, highlighted: Bool) -> some View {
        VStack(spacing: 12) {
            Text(tag)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(highlighted ? .white : .white.opacity(0.45))
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

// MARK: - 4. Good Experience

private struct ProductExperienceScreen: View {
    let size: CGSize
    let onContinue: () -> Void
    @State private var v = false

    private let features: [(icon: String, title: String, body: String)] = [
        ("hand.tap", "Tap and hold", "Let a declaration sink in deep. The Word goes from your screen to your spirit."),
        ("bubble.left.and.bubble.right.fill", "Bible Chat", "Ask anything and get answers rooted in Scripture. Like having a wise friend in the Word, any hour of the day."),
        ("car", "Built for real life", "Use it in the car, before a hard conversation, or late at night. Simple when everything else feels heavy.")
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    Spacer().frame(height: size.height * 0.12)

                    VStack(spacing: 12) {
                        Text("Built for the middle\nof the storm.")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .appearStagger(v)

                        Text("No friction when you're at your lowest.\nJust the Word, the moment you need it.")
                            .font(.system(size: 16, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.horizontal, 24)
                            .fixedSize(horizontal: false, vertical: true)
                            .appearStagger(v, delay: 0.12)
                    }
                    .padding(.horizontal, 28)

                    VStack(spacing: 12) {
                        ForEach(Array(features.enumerated()), id: \.offset) { idx, feature in
                            featureRow(feature)
                                .appearStagger(v, delay: 0.22 + Double(idx) * 0.1)
                        }
                    }
                    .padding(.horizontal, 24)

                    Spacer().frame(height: 8)
                }
            }

            ProductContinueButton(label: "Continue →") { onContinue() }
                .padding(.top, 8).padding(.bottom, 36)
                .appearStagger(v, delay: 0.52)
        }
        .onAppear {
            Analytics.logEvent("product_experience_shown", parameters: nil)
            withAnimation { v = true }
        }
    }

    private func featureRow(_ feature: (icon: String, title: String, body: String)) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 46, height: 46)
                Image(systemName: feature.icon)
                    .font(.system(size: 20))
                    .foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(feature.title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                Text(feature.body)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }
}

// MARK: - 5. Clarity + Category Picker

private struct ProductCategoryPickerScreen: View {
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
                        Text("Done-for-you declarations\nfor exactly what you're facing.")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .appearStagger(v)

                        Text("Pick where you need God's Word most.\nWe'll build your daily declarations around it.")
                            .font(.system(size: 15, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.65))
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                            .appearStagger(v, delay: 0.1)
                    }
                    .padding(.horizontal, 28)

                    VStack(spacing: 10) {
                        ForEach(HeaviestBurden.allCases) { option in
                            categoryRow(option)
                        }
                    }
                    .padding(.horizontal, 20)
                    .appearStagger(v, delay: 0.2)

                    Spacer().frame(height: 8)
                }
            }

            ProductContinueButton(isEnabled: responses.heaviestBurden != nil, action: onContinue)
                .padding(.top, 8).padding(.bottom, 36)
        }
        .onAppear {
            Analytics.logEvent("product_category_picker_shown", parameters: nil)
            withAnimation { v = true }
        }
    }

    private func categoryRow(_ option: HeaviestBurden) -> some View {
        let isSelected = responses.heaviestBurden == option
        return Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            responses.heaviestBurden = option
        }) {
            HStack(spacing: 14) {
                Text(option.icon)
                    .font(.system(size: 24))
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 3) {
                    Text(option.rawValue)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    if !option.description.isEmpty {
                        Text(option.description)
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.55))
                            .fixedSize(horizontal: false, vertical: true)
                    }
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
