//
//  SurveyOnboardingView.swift
//  SpeakLife
//

import SwiftUI
import FirebaseAnalytics

struct SurveyOnboardingView: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var declarationStore: DeclarationViewModel
    let size: CGSize
    let onComplete: () -> Void

    @StateObject private var responses = SurveyResponses()
    @State private var currentStep: SurveyStep = .intro
    @State private var savedDeclaration: PersonalDeclaration? = nil

    private var progressFraction: Double {
        guard let qi = currentStep.questionIndex else { return 0 }
        return Double(qi) / Double(SurveyStep.totalQuestions)
    }

    var body: some View {
        ZStack(alignment: .top) {
            backgroundView

            Group {
                switch currentStep {
                case .intro:            SurveyIntroScreen(size: size) { advance() }
                case .heaviestBurden:   SurveyQ1BurdenScreen(size: size, responses: responses) { advance() }
                case .burdenDuration:   SurveyQ2DurationScreen(size: size, responses: responses) { advance() }
                case .interstitialA:    SurveyInterstitialAScreen(size: size, responses: responses) { advance() }
                case .failedAttempts:   SurveyQ3AttemptsScreen(size: size, responses: responses) { advance() }
                case .innerLie:         SurveyQ4LieScreen(size: size, responses: responses) { advance() }
                case .interstitialB:    SurveyInterstitialBScreen(size: size) { advance() }
                case .declarationExp:   SurveyQ5DeclarationExpScreen(size: size, responses: responses) { advance() }
                case .futurePacing:     SurveyQ6FutureScreen(size: size, responses: responses) { advance() }
                case .readiness:        SurveyQ7ReadinessScreen(size: size, responses: responses) { advance() }
                case .notificationTime: SurveyQ8NotificationScreen(size: size, responses: responses) { advance() }
                case .goalWord:         SurveyQ9GoalWordScreen(size: size, responses: responses) { advance() }
                case .goalReveal:       SurveyGoalRevealScreen(size: size, responses: responses) { advance() }
                case .personalDeclaration:
                    PersonalDeclarationOnboardingView(
                        viewModel: DIContainer.shared.makePersonalDeclarationViewModel(),
                        size: size
                    ) { declaration in
                        savedDeclaration = declaration
                        applyResponsesAndComplete()
                    }
                }
            }
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .offset(x: 0, y: 24)),
                removal: .opacity.combined(with: .offset(x: 0, y: -16))
            ))
            .id(currentStep.rawValue)

            if currentStep.questionIndex != nil {
                VStack {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Rectangle().fill(Color.white.opacity(0.15)).frame(height: 3)
                            Rectangle().fill(Color.white)
                                .frame(width: geo.size.width * progressFraction, height: 3)
                                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progressFraction)
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
        .onAppear { Analytics.logEvent("survey_onboarding_started", parameters: nil) }
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
        Analytics.logEvent("survey_step_completed", parameters: ["step": currentStep.rawValue])
        let nextRaw = currentStep.rawValue + 1
        guard let next = SurveyStep(rawValue: nextRaw) else {
            applyResponsesAndComplete()
            return
        }
        withAnimation(.easeInOut(duration: 0.35)) { currentStep = next }
    }

    private func applyResponsesAndComplete() {
        let goalWord = responses.resolvedGoalWord
        appState.surveyGoalWord = goalWord.rawValue
        if let notifTime = responses.notificationTime {
            appState.startTimeIndex = notifTime.startTimeIndex
        }
        // Seed the declarations tab with the category that matches the user's goal word
        let category = goalWord.declarationCategory
        UserDefaults.standard.set(category.rawValue, forKey: "selectedCategory")
        UserPreferencesTracker.shared.trackCategorySelection(category.rawValue)
        // Force the already-loaded DeclarationViewModel to switch to the new category immediately
        declarationStore.choose(category) { _ in }
        // Mark personal declaration active if user set one
        if savedDeclaration != nil {
            appState.hasPersonalDeclaration = true
        }
        Analytics.logEvent("survey_onboarding_completed", parameters: [
            "goal_word": goalWord.rawValue,
            "burden": responses.heaviestBurden?.rawValue ?? "unknown",
            "set_personal_declaration": (savedDeclaration != nil) as NSNumber
        ])
        onComplete()
    }
}
