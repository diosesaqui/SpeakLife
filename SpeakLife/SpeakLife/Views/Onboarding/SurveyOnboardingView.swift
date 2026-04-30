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
        case .productPositioning: SurveyProductPositioningScreen(size: size) { advance() }
        case .theSeed:            SurveyTheSeedScreen(size: size) { advance() }
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
            SurveyTakeAStandScreen { advance() }
        case .commitmentHold:
            SurveyCommitmentHoldScreen(size: size) { advance() }
        case .paywall:
            HighConversionPaywallView(callback: { advance() })
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
        if savedDeclaration != nil {
            appState.hasPersonalDeclaration = true
        }
        Analytics.logEvent("survey_onboarding_completed", parameters: [
            "goal_word": goalWord.rawValue,
            "burden": responses.heaviestBurden?.rawValue ?? "unknown",
            "declaration_style": responses.primaryDeclarationStyle?.rawValue ?? "none",
            "set_personal_declaration": (savedDeclaration != nil) as NSNumber
        ])

        // Ask for notification permission BEFORE handing off to onComplete (which
        // schedules lifecycle pushes + content batch). Without this, every survey
        // user lands with notificationEnabled=false and gets zero pushes until
        // they manually toggle Reminders on.
        requestNotificationPermissionThenComplete(categories: notificationCategoriesSet)
    }

    private func requestNotificationPermissionThenComplete(categories: Set<DeclarationCategory>) {
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
                onComplete()
            }
        }
    }
}
