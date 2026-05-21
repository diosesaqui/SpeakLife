//
//  SurveyOnboardingView.swift
//  SpeakLife
//

import SwiftUI
import FirebaseAnalytics
import UserNotifications
import UIKit

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

            currentStepView
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

    // Split into two @ViewBuilder properties to stay within SwiftUI's 10-branch ViewBuilder limit
    @ViewBuilder
    private var currentStepView: some View {
        switch currentStep {
        case .intro:              SurveyIntroScreen(size: size) { advance() }
        case .heaviestBurden:     SurveyQ1BurdenScreen(size: size, responses: responses) { advance() }
        case .productPositioning: SurveyProductPositioningScreen(size: size, responses: responses) { advance() }
        case .burdenDuration:     SurveyQ2DurationScreen(size: size, responses: responses) { advance() }
        case .mergedBarriers:     SurveyMergedBarriersScreen(size: size, responses: responses) { advance() }
        case .interstitialB:      SurveyInterstitialBScreen(size: size) { advance() }
        default: lateStepView
        }
    }

    @ViewBuilder
    private var lateStepView: some View {
        switch currentStep {
        case .declarationExp:
            SurveyQ5DeclarationExpScreen(size: size, responses: responses) { advance() }
        case .firstDeclaration:
            SurveyFirstDeclarationScreen(size: size, responses: responses) { advance() }
        case .goalReveal:
            SurveyGoalRevealScreen(size: size, responses: responses) { advance() }
        case .personalDeclaration:
            PersonalDeclarationOnboardingView(
                viewModel: DIContainer.shared.makePersonalDeclarationViewModel(),
                size: size
            ) { declaration in
                savedDeclaration = declaration
                advance()
            }
        case .takeAStand:
            SurveyTakeAStandScreen(responses: responses) { advance() }
        case .commitmentHold:
            SurveyCommitmentHoldScreen(size: size) { advance() }
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
        Analytics.logEvent("survey_step_completed", parameters: ["step": currentStep.rawValue])

        // Leaving the rating screen is the true end of onboarding.
        if currentStep == .rating {
            onComplete()
            return
        }

        // Leaving the notification step: persist survey responses, ask for the
        // iOS notification permission, then route to the rating screen — the
        // rating tap fires the SKStoreReviewController prompt cleanly after the
        // notification prompt has resolved.
        if currentStep == .notificationTime {
            applyResponsesAndContinueToRating()
            return
        }

        let nextRaw = currentStep.rawValue + 1
        guard let next = SurveyStep(rawValue: nextRaw) else {
            // Defensive — should be unreachable now that .rating is the terminal step.
            onComplete()
            return
        }
        withAnimation(.easeInOut(duration: 0.35)) { currentStep = next }
    }

    private func applyResponsesAndContinueToRating() {
        let goalWord = responses.resolvedGoalWord
        appState.surveyGoalWord = goalWord.rawValue
        if let style = responses.primaryDeclarationStyle {
            appState.selectedDeclarationStyles = [style.rawValue]
        }
        // Persist the goal-word's curated notification mix so SpeakLifeApp.resetNotifications
        // schedules personalized content instead of falling back to NotificationManager's
        // generic [destiny, gratitude, faith, identity, grace, joy, rest] default.
        let notificationCategoriesSet = goalWord.notificationCategories
        appState.selectedNotificationCategories = notificationCategoriesSet
            .map { $0.rawValue }
            .joined(separator: ",")
        let category = goalWord.declarationCategory
        UserDefaults.standard.set(category.rawValue, forKey: "selectedCategory")
        UserPreferencesTracker.shared.trackCategorySelection(category.rawValue)
        declarationStore.choose(category) { _ in }
        if let notifTime = responses.notificationTime {
            appState.startTimeIndex = notifTime.startTimeIndex
            appState.endTimeIndex   = notifTime.endTimeIndex
            // Mirror to the personal declaration push time. The dedicated field
            // exists for future independence, but there's no UI to set it
            // separately today — so onboarding's window choice is the user's
            // implicit preference for when their personal declaration fires too.
            appState.personalDeclarationTimeIndex = notifTime.startTimeIndex
        }
        appState.hasPersonalDeclaration = savedDeclaration != nil
        Analytics.logEvent("survey_onboarding_completed", parameters: [
            "goal_word": goalWord.rawValue,
            "burden": responses.heaviestBurden?.rawValue ?? "unknown",
            "declaration_style": responses.primaryDeclarationStyle?.rawValue ?? "none",
            "set_personal_declaration": (savedDeclaration != nil) as NSNumber
        ])

        requestNotificationPermissionThenAdvanceToRating(categories: notificationCategoriesSet)
    }

    private func requestNotificationPermissionThenAdvanceToRating(categories: Set<DeclarationCategory>) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            Analytics.logEvent("notification_permission", parameters: ["granted": granted, "source": "survey_onboarding"])
            DispatchQueue.main.async {
                appState.notificationEnabled = granted
                if granted {
                    UIApplication.shared.registerForRemoteNotifications()
                    // Register the daily declaration batch immediately so the user starts
                    // receiving content notifications today rather than waiting for the
                    // next cold launch's foreground reschedule.
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
