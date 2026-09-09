//
//  AngleOnboardingView.swift
//  SpeakLife
//
//  The single driver behind every angle onboarding arm. It owns the machinery
//  that used to be copy-pasted across PromisesOnboardingView, WarfareOnboardingView
//  and OutcomesOnboardingView — progress bar, step advance, quiz-v2 skip, rating
//  gate, completion + seeding, notification permission — and takes the parts that
//  actually differed between them as data (`OnboardingAngle`).
//
//  Flow shape, identical for every angle:
//
//    [storm opener] → narrative scenes → [product recap] → burden picker
//      → [burden-matched payoff] → extended quiz (Q2–Q6 + insight)
//      → first declaration → record your own → [rating] → plan loader
//      → plan reveal → testimonials → paywall → notification time
//
//  Bracketed screens are per-angle. Everything else is fixed, which is the point:
//  an A/B across angles isolates the ANGLE, never the funnel depth.
//
//  HomeView routes here for every angle arm; which angle is decided by
//  `SubscriptionStore.resolvedOnboardingVariant`, which honours the `?ob=` deep
//  link ahead of Remote Config.
//

import SwiftUI
import UserNotifications
import UIKit

struct AngleOnboardingView: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var declarationStore: DeclarationViewModel

    let angle: OnboardingAngle
    let size: CGSize
    let onComplete: () -> Void

    // Reuse the survey response model so the shared back-half screens and the
    // seeding logic work unchanged. Only `heaviestBurden` and `notificationTime`
    // are set here (the picker writes `heaviestBurden`).
    @StateObject private var responses = SurveyResponses()
    @State private var stepIndex: Int = 0
    @State private var selectedChoiceID: String? = nil
    @State private var savedDeclaration: PersonalDeclaration? = nil

    // Quiz v2 flag, frozen at the flow's first appearance (mirroring
    // lockOnboardingVariant's intent) so a realtime Remote Config activation
    // mid-session can't swap questions, progress totals, or quiz_version under
    // the user. The live-read fallback only covers pre-onAppear access.
    @State private var quizV2Snapshot: Bool? = nil
    private var quizV2: Bool { quizV2Snapshot ?? subscriptionStore.useQuizV2 }

    private var steps: [AngleStep] { angle.steps }
    private var currentStep: AngleStep { steps[min(stepIndex, steps.count - 1)] }

    private var valueProgress: Double {
        let screens = angle.valueScreens(quizV2: quizV2)
        guard let idx = screens.firstIndex(of: currentStep) else { return 0 }
        return Double(idx + 1) / Double(screens.count)
    }

    private var isValueScreen: Bool {
        angle.valueScreens(quizV2: quizV2).contains(currentStep)
    }

    var body: some View {
        ZStack(alignment: .top) {
            backgroundView

            currentStepView
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .offset(x: 0, y: 24)),
                    removal: .opacity.combined(with: .offset(x: 0, y: -16))
                ))
                .id(stepIndex)

            if isValueScreen {
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
            AnalyticsService.shared.track("\(angle.flow)_onboarding_started")
        }
    }

    @ViewBuilder
    private var currentStepView: some View {
        switch currentStep {
        case .storm:
            StormOpenerScreen(size: size, flow: angle.flow) { advance() }
        case .scene(let i):
            AngleSceneScreen(scene: angle.scenes[i], iconStyle: angle.iconStyle) { advance() }
        case .experience:
            OnboardingProductExperienceScreen(size: size, flow: angle.flow) { advance() }
        case .picker:
            AnglePickerScreen(
                size: size,
                picker: angle.picker,
                responses: responses,
                selectedChoiceID: $selectedChoiceID
            ) { advance() }
        case .burdenScene:
            if let scene = angle.burdenScene {
                AngleBurdenSceneScreen(
                    scene: scene,
                    burden: responses.heaviestBurden ?? .peace,
                    iconStyle: angle.iconStyle
                ) { advance() }
            }
        case .battleDuration, .alreadyTried, .insight, .hitsHardest, .connectStyle, .belief, .dailyMinutes:
            quizStepView
        default:
            backHalfView
        }
    }

    // Extended quiz steps (Q2-Q6 + insight), shared with the product/quiz arms.
    @ViewBuilder
    private var quizStepView: some View {
        switch currentStep {
        case .battleDuration:
            SurveyExtendedQuizScreen(size: size, flow: angle.flow, question: .battleDuration, selection: $responses.battleDuration) { advance() }
        case .alreadyTried:
            SurveyExtendedQuizScreen(size: size, flow: angle.flow, question: .alreadyTried, selection: $responses.alreadyTried) { advance() }
        case .insight:
            SurveyQuizInsightScreen(size: size, flow: angle.flow) { advance() }
        case .hitsHardest:
            SurveyExtendedQuizScreen(size: size, flow: angle.flow, question: .hitsHardest, selection: $responses.hitsHardest) { advance() }
        case .connectStyle:
            // Quiz v2 swaps the connect-style question for the burden-aware
            // outcome question in the same slot; v1 is unchanged.
            if quizV2 {
                SurveyExtendedQuizScreen(size: size, flow: angle.flow, question: .victoryLooksLike(for: responses.heaviestBurden ?? .peace), selection: $responses.victoryOutcome) { advance() }
            } else {
                SurveyExtendedQuizScreen(size: size, flow: angle.flow, question: .connectStyle, selection: $responses.connectStyle) { advance() }
            }
        case .belief:
            // Quiz v2 only — v1's advance() jumps over this step entirely.
            SurveyExtendedQuizScreen(size: size, flow: angle.flow, question: .belief, selection: $responses.beliefLevel) { advance() }
        case .dailyMinutes:
            SurveyExtendedQuizScreen(size: size, flow: angle.flow, question: .dailyMinutes, selection: $responses.dailyMinutes) { advance() }
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var backHalfView: some View {
        switch currentStep {
        case .firstDeclaration:
            SurveyFirstDeclarationScreen(size: size, responses: responses, flow: angle.flow) { advance() }
        case .personalDeclaration:
            PersonalDeclarationOnboardingView(
                viewModel: DIContainer.shared.makePersonalDeclarationViewModel(),
                size: size,
                flow: angle.flow
            ) { declaration in
                savedDeclaration = declaration
                advance()
            }
        case .rating:
            RatingView(size: size) { advance() }
        case .planBuilding:
            SurveyPlanBuildingScreen(burden: responses.heaviestBurden ?? .peace, flow: angle.flow) { advance() }
        case .planReveal:
            SurveyPlanRevealScreen(
                size: size,
                burden: responses.heaviestBurden ?? .peace,
                flow: angle.flow,
                personalDeclaration: savedDeclaration?.declarationText,
                dailyMinutes: responses.dailyMinutes,
                victoryEcho: responses.victoryEcho,  // nil in quiz v1
                // The arc's last beat has to land on the day the card is
                // charged, and the SKU is Remote Config resolved. Fall back to
                // the default only if products have not loaded.
                trialDays: subscriptionStore.currentOfferedPremium
                    .flatMap(TrialExperienceService.introTrialDays) ?? 7
            ) { advance() }
        case .testimonials:
            TestimonialWallView(size: size, flow: angle.flow) { advance() }
        case .paywall:
            HighConversionPaywallView(callback: { advance() }, source: "onboarding", isHardPaywall: true)
        case .notificationTime:
            SurveyQ8NotificationScreen(size: size, responses: responses, flow: angle.flow) { advance() }
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
        AnalyticsService.shared.track("\(angle.flow)_step_completed", parameters: [
            "step": stepIndex,
            "flow_schema": angle.flowSchema
        ])

        // Leaving the picker: stamp the segment so downstream paywall events
        // carry a meaningful segment for this arm (quiz sets its own).
        if currentStep == .picker,
           let choice = angle.picker.choices.first(where: { $0.id == selectedChoiceID }) {
            appState.onboardingSegment = "\(angle.flow)_\(choice.segmentLabel)"
        }

        if currentStep == .notificationTime {
            applyResponsesAndComplete()
            return
        }

        var next = stepIndex + 1
        // Quiz v1 has no belief step — jump straight from connect style to
        // daily minutes, exactly the pre-v2 sequence.
        if !quizV2, next < steps.count, steps[next] == .belief {
            next += 1
        }
        // Rating ask is remote-gated (onboardingRatingEnabled); when off, skip
        // straight past it to the next step.
        if next < steps.count, steps[next] == .rating, !subscriptionStore.onboardingRatingEnabled {
            next += 1
        }
        guard next < steps.count else {
            assertionFailure("AngleOnboardingView.advance(): no successor for step \(stepIndex) in angle \(angle.id). .notificationTime should be terminal.")
            onComplete()
            return
        }
        withAnimation(.easeInOut(duration: 0.35)) { stepIndex = next }
    }

    // Persist the chosen category, seed the home feed + notifications from it,
    // then finish.
    private func applyResponsesAndComplete() {
        let goalWord = responses.resolvedGoalWord
        appState.surveyGoalWord = goalWord.rawValue
        if let style = responses.primaryDeclarationStyle {
            appState.selectedDeclarationStyles = [style.rawValue]
        }
        // Seeded from the burden, not from the goal word's branding category.
        let category = responses.seedCategory
        let notificationCategoriesSet: Set<DeclarationCategory> = [category]
        appState.selectedNotificationCategories = category.rawValue
        UserDefaults.standard.set(category.rawValue, forKey: "selectedCategory")
        UserPreferencesTracker.shared.trackCategorySelection(category.rawValue)
        // The answer has to outlive onboarding to be worth asking. Every arm
        // that asks this question kept it on `SurveyResponses`, where it died
        // with the flow — which is why 527 answers were collected and read by
        // nothing. `TaskLibrary` reads this key when it builds the day.
        ConnectStyle.store(responses.connectStyle.flatMap(ConnectStyle.init(rawValue:)))
        // Same reason, same fate without it: the time answer decides how many
        // rows the daily checklist shows, and it can only do that if it
        // outlives the flow. Raw values match the quiz options exactly.
        DailyTimeBudget.store(responses.dailyMinutes.flatMap(DailyTimeBudget.init(rawValue:)))
        declarationStore.choose(category) { _ in }
        if let notifTime = responses.notificationTime {
            appState.startTimeIndex = notifTime.startTimeIndex
            appState.endTimeIndex   = notifTime.endTimeIndex
            // No `personalDeclarationTimeIndex` mirror: onboarding no longer asks
            // for a window, so there is no user preference to mirror. The
            // personal declaration push keeps its own 8:00 AM default and stays
            // adjustable independently.
        }
        appState.hasPersonalDeclaration = savedDeclaration != nil
        AnalyticsService.shared.track("\(angle.flow)_onboarding_completed", parameters: [
            "goal_word": goalWord.rawValue,
            "burden": responses.heaviestBurden?.rawValue ?? "unknown",
            // Which picker ROW was chosen. On a single-issue arm every row maps
            // to the same burden, so this is the only thing that tells a
            // "chronic pain" install apart from a "believing for someone I love"
            // one — the segmentation an angle-matched ad is bought for.
            "picker_choice": selectedChoiceID ?? "unknown",
            "battle_duration": responses.battleDuration ?? "unknown",
            "already_tried": responses.alreadyTried ?? "unknown",
            "hits_hardest": responses.hitsHardest ?? "unknown",
            "connect_style": responses.connectStyle ?? "unknown",
            "daily_minutes": responses.dailyMinutes ?? "unknown",
            "victory_looks_like": responses.victoryOutcome ?? "unknown",
            "belief": responses.beliefLevel ?? "unknown",
            "quiz_version": quizV2 ? "v2" : "v1",
            "flow_schema": angle.flowSchema,  // joins with <flow>_step_completed
            "set_personal_declaration": (savedDeclaration != nil) as NSNumber
        ])

        requestNotificationPermissionThenComplete(categories: notificationCategoriesSet)
    }

    private func requestNotificationPermissionThenComplete(categories: Set<DeclarationCategory>) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            AnalyticsService.shared.track("notification_permission", parameters: ["granted": granted, "source": "\(angle.flow)_onboarding"])
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

// MARK: - Shared Components

private struct AngleContinueButton: View {
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

private struct AngleAppearStagger: ViewModifier {
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
    func angleStagger(_ shown: Bool, delay: Double = 0) -> some View {
        modifier(AngleAppearStagger(shown: shown, delay: delay))
    }
}

/// The narrative-screen layout, shared by `AngleSceneScreen` and
/// `AngleBurdenSceneScreen` so a burden-matched payoff is visually identical to
/// a scripted scene.
private struct AngleNarrativeLayout: View {
    let symbol: String
    let eyebrow: String
    let title: String
    let bodyText: String
    let verse: String
    let reference: String
    let buttonLabel: String
    let iconStyle: AngleIconStyle
    let onContinue: () -> Void
    @State private var v = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 26) {
                ZStack {
                    Circle()
                        .fill(iconStyle.gradient)
                        .frame(width: 96, height: 96)
                        .shadow(color: iconStyle.glow, radius: 12, x: 0, y: 6)
                    Image(systemName: symbol)
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                }
                .angleStagger(v)

                VStack(spacing: 14) {
                    Text(eyebrow)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(DS.Palette.gold.opacity(0.9))
                        .kerning(1.4)
                        .multilineTextAlignment(.center)
                        .angleStagger(v, delay: 0.08)

                    Text(title)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .angleStagger(v, delay: 0.14)

                    Text(bodyText)
                        .font(.system(size: 17, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 22)
                        .fixedSize(horizontal: false, vertical: true)
                        .angleStagger(v, delay: 0.22)
                }

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
                .padding(.horizontal, 28)
                .angleStagger(v, delay: 0.32)
            }
            .padding(.horizontal, 28)

            Spacer()

            AngleContinueButton(label: buttonLabel) { onContinue() }
                .padding(.bottom, 36)
                .angleStagger(v, delay: 0.42)
        }
        .onAppear { withAnimation { v = true } }
    }
}

// MARK: - Scene Screen

private struct AngleSceneScreen: View {
    let scene: AngleScene
    let iconStyle: AngleIconStyle
    let onContinue: () -> Void

    var body: some View {
        AngleNarrativeLayout(
            symbol: scene.symbol,
            eyebrow: scene.eyebrow,
            title: scene.title,
            bodyText: scene.body,
            verse: scene.verse,
            reference: scene.reference,
            buttonLabel: scene.buttonLabel,
            iconStyle: iconStyle,
            onContinue: onContinue
        )
        .onAppear {
            AnalyticsService.shared.track(scene.analyticsEvent, parameters: scene.analyticsParameters)
        }
    }
}

// MARK: - Burden-Matched Scene Screen

private struct AngleBurdenSceneScreen: View {
    let scene: AngleBurdenScene
    let burden: HeaviestBurden
    let iconStyle: AngleIconStyle
    let onContinue: () -> Void

    var body: some View {
        let content = scene.content(for: burden)
        return AngleNarrativeLayout(
            symbol: content.symbol,
            eyebrow: scene.eyebrow,
            title: content.title,
            bodyText: content.body,
            verse: content.verse,
            reference: content.reference,
            buttonLabel: scene.buttonLabel,
            iconStyle: iconStyle,
            onContinue: onContinue
        )
        .onAppear {
            AnalyticsService.shared.track(scene.analyticsEvent, parameters: ["burden": burden.shortLabel])
        }
    }
}

// MARK: - Picker (seeds the feed)

private struct AnglePickerScreen: View {
    let size: CGSize
    let picker: AnglePicker
    @ObservedObject var responses: SurveyResponses
    @Binding var selectedChoiceID: String?
    let onContinue: () -> Void
    @State private var v = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    Spacer().frame(height: size.height * 0.10)

                    VStack(spacing: 12) {
                        Text(picker.headline)
                            .font(.system(size: 27, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .angleStagger(v)

                        Text(picker.subtitle)
                            .font(.system(size: 15, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.65))
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                            .angleStagger(v, delay: 0.1)
                    }
                    .padding(.horizontal, 28)

                    VStack(spacing: 10) {
                        ForEach(picker.choices) { choice in
                            choiceRow(choice)
                        }
                    }
                    .padding(.horizontal, 20)
                    .angleStagger(v, delay: 0.2)

                    Spacer().frame(height: 8)
                }
            }

            AngleContinueButton(isEnabled: selectedChoiceID != nil, action: onContinue)
                .padding(.top, 8).padding(.bottom, 36)
        }
        .onAppear {
            AnalyticsService.shared.track(picker.analyticsEvent)
            withAnimation { v = true }
        }
    }

    private func choiceRow(_ choice: AnglePickerChoice) -> some View {
        // Selection is tracked by row id, not by burden: a single-issue arm's
        // rows all share one burden, so keying off `heaviestBurden` would light
        // up every row at once.
        let isSelected = selectedChoiceID == choice.id
        return Button(action: {
            Juice.play(.tapLight)
            selectedChoiceID = choice.id
            responses.heaviestBurden = choice.burden
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
