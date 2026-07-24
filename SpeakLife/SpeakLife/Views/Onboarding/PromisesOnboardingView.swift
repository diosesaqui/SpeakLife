//
//  PromisesOnboardingView.swift
//  SpeakLife
//
//  A trust-and-activation onboarding A/B variant. Where the outcomes arm leads
//  with the WIN and the warfare arm leads with the FIGHT, this arm leads with a
//  settled fact and a single question: God's promises always work — the only
//  variable is whether you'll trust them and put them to work over your own
//  life. The narrative arc is:
//
//    0. Proven        — God's promises have never failed, not once (the thesis)
//    1. The question  — it was never IF they work; it's whether you'll trust them
//    2. Yours too     — the promise has your name on it, not just someone else's
//    3. Activation    — a promise you SPEAK goes to work (the app's core mechanic)
//    4. Every area    — nothing in your life sits outside the promise
//
//  Then a product-capability recap, a "which promise will you activate first?"
//  picker (which seeds the home feed), the same extended personalization quiz
//  the warfare/outcomes/product arms run, and the proven back-half (taste →
//  record your own → rating → plan-building loader → named plan reveal → paywall
//  → notification time). Mechanically identical to the outcomes arm so an A/B
//  test isolates the angle (trust-and-activate vs dream-first vs fight-first),
//  not the funnel depth. The picker maps each promise to a HeaviestBurden /
//  category so the shared screens + seeding work unchanged.
//
//  One arm of the onboarding A/B: HomeView routes here when Remote Config
//  `onboardingVariant` == "promises".
//

import SwiftUI
import UserNotifications
import UIKit

struct PromisesOnboardingView: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var declarationStore: DeclarationViewModel
    let size: CGSize
    let onComplete: () -> Void

    // Reuse the survey response model so the shared back-half screens and the
    // seeding logic work unchanged. Only `heaviestBurden` and `notificationTime`
    // are set here (the promise picker writes `heaviestBurden`).
    @StateObject private var responses = SurveyResponses()
    @State private var currentStep: PromisesStep = .proven
    @State private var savedDeclaration: PersonalDeclaration? = nil

    // Quiz v2 flag, frozen at the flow's first appearance (mirroring
    // lockOnboardingVariant's intent) so a realtime Remote Config activation
    // mid-session can't swap questions, progress totals, or quiz_version under
    // the user. The live-read fallback only covers pre-onAppear access.
    @State private var quizV2Snapshot: Bool? = nil
    private var quizV2: Bool { quizV2Snapshot ?? subscriptionStore.useQuizV2 }

    private var valueProgress: Double {
        guard let idx = currentStep.valueScreenIndex(quizV2: quizV2) else { return 0 }
        return Double(idx) / Double(PromisesStep.totalValueScreens(quizV2: quizV2))
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
            AnalyticsService.shared.track("promises_onboarding_started")
        }
    }

    @ViewBuilder
    private var currentStepView: some View {
        switch currentStep {
        case .proven:    PromiseSceneScreen(size: size, scene: .proven) { advance() }
        case .question:  PromiseSceneScreen(size: size, scene: .question) { advance() }
        case .yours:     PromiseSceneScreen(size: size, scene: .yours) { advance() }
        case .activate:  PromiseSceneScreen(size: size, scene: .activate) { advance() }
        case .everyArea: PromiseSceneScreen(size: size, scene: .everyArea) { advance() }
        case .experience:
            OnboardingProductExperienceScreen(size: size, flow: "promises") { advance() }
        case .promisePicker:
            PromisePickerScreen(size: size, responses: responses) { advance() }
        case .battleDuration, .alreadyTried, .insight, .hitsHardest, .connectStyle, .belief, .dailyMinutes:
            quizStepView
        default: backHalfView
        }
    }

    // Extended quiz steps (Q2-Q6 + insight), shared with the warfare/outcomes/product arms.
    @ViewBuilder
    private var quizStepView: some View {
        switch currentStep {
        case .battleDuration:
            SurveyExtendedQuizScreen(size: size, flow: "promises", question: .battleDuration, selection: $responses.battleDuration) { advance() }
        case .alreadyTried:
            SurveyExtendedQuizScreen(size: size, flow: "promises", question: .alreadyTried, selection: $responses.alreadyTried) { advance() }
        case .insight:
            SurveyQuizInsightScreen(size: size, flow: "promises") { advance() }
        case .hitsHardest:
            SurveyExtendedQuizScreen(size: size, flow: "promises", question: .hitsHardest, selection: $responses.hitsHardest) { advance() }
        case .connectStyle:
            // Quiz v2 swaps the connect-style question for the burden-aware
            // outcome question in the same slot; v1 is unchanged.
            if quizV2 {
                SurveyExtendedQuizScreen(size: size, flow: "promises", question: .victoryLooksLike(for: responses.heaviestBurden ?? .peace), selection: $responses.victoryOutcome) { advance() }
            } else {
                SurveyExtendedQuizScreen(size: size, flow: "promises", question: .connectStyle, selection: $responses.connectStyle) { advance() }
            }
        case .belief:
            // Quiz v2 only — v1's advance() jumps over this step entirely.
            SurveyExtendedQuizScreen(size: size, flow: "promises", question: .belief, selection: $responses.beliefLevel) { advance() }
        case .dailyMinutes:
            SurveyExtendedQuizScreen(size: size, flow: "promises", question: .dailyMinutes, selection: $responses.dailyMinutes) { advance() }
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var backHalfView: some View {
        switch currentStep {
        case .firstDeclaration:
            SurveyFirstDeclarationScreen(size: size, responses: responses, flow: "promises") { advance() }
        case .personalDeclaration:
            PersonalDeclarationOnboardingView(
                viewModel: DIContainer.shared.makePersonalDeclarationViewModel(),
                size: size,
                flow: "promises"
            ) { declaration in
                savedDeclaration = declaration
                advance()
            }
        case .rating:
            RatingView(size: size) { advance() }
        case .planBuilding:
            SurveyPlanBuildingScreen(burden: responses.heaviestBurden ?? .peace, flow: "promises") { advance() }
        case .planReveal:
            SurveyPlanRevealScreen(
                size: size,
                burden: responses.heaviestBurden ?? .peace,
                flow: "promises",
                personalDeclaration: savedDeclaration?.declarationText,
                dailyMinutes: responses.dailyMinutes,
                victoryEcho: responses.victoryEcho  // nil in quiz v1
            ) { advance() }
        case .testimonials:
            TestimonialWallView(size: size, flow: "promises") { advance() }
        case .paywall:
            HighConversionPaywallView(callback: { advance() }, source: "onboarding", isHardPaywall: true)
        case .notificationTime:
            SurveyQ8NotificationScreen(size: size, responses: responses, flow: "promises") { advance() }
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
        // flow_schema 2 = testimonial wall inserted before paywall (1 = original promises arc). Bump when step raw values are renumbered.
        AnalyticsService.shared.track("promises_step_completed", parameters: ["step": currentStep.rawValue, "flow_schema": 2])

        // Leaving the promise picker: stamp the segment so downstream paywall
        // events carry a meaningful segment for this arm (quiz sets its own).
        if currentStep == .promisePicker, let burden = responses.heaviestBurden {
            appState.onboardingSegment = "promises_\(burden.shortLabel)"
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
            if !quizV2, PromisesStep(rawValue: nextRaw) == .belief {
                nextRaw += 1
            }
            // Rating ask is remote-gated (onboardingRatingEnabled); when off,
            // skip straight past it to the next step.
            if PromisesStep(rawValue: nextRaw) == .rating, !subscriptionStore.onboardingRatingEnabled {
                nextRaw += 1
            }
            guard let next = PromisesStep(rawValue: nextRaw) else {
                assertionFailure("PromisesOnboardingView.advance(): no successor for \(currentStep). .notificationTime should be terminal.")
                onComplete()
                return
            }
            withAnimation(.easeInOut(duration: 0.35)) { currentStep = next }
        }
    }

    // Mirrors the warfare/outcomes completion: persist the chosen category, seed
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
        AnalyticsService.shared.track("promises_onboarding_completed", parameters: [
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
            "flow_schema": 2,  // joins with promises_step_completed; bump when step raw values are renumbered
            "set_personal_declaration": (savedDeclaration != nil) as NSNumber
        ])

        requestNotificationPermissionThenComplete(categories: notificationCategoriesSet)
    }

    private func requestNotificationPermissionThenComplete(categories: Set<DeclarationCategory>) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            AnalyticsService.shared.track("notification_permission", parameters: ["granted": granted, "source": "promises_onboarding"])
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

enum PromisesStep: Int, CaseIterable {
    // Trust-and-activation narrative screens
    case proven         = 0   // God's promises have never failed (the thesis)
    case question       = 1   // it was never IF they work; it's whether you'll trust them
    case yours          = 2   // the promise has your name on it, not just someone else's
    case activate       = 3   // a promise you SPEAK goes to work (the core mechanic)
    case everyArea      = 4   // nothing in your life sits outside the promise
    case experience     = 5   // product-capability recap (matching warfare/outcomes/product)
    case promisePicker  = 6   // pick the promise to activate first (seeds the feed)
    // Extended personalization quiz (shared screens in SurveyOnboardingScreens)
    case battleDuration = 7   // Q2: how long has this been going on?
    case alreadyTried   = 8   // Q3: what have you already tried?
    case insight        = 9   // micro-insight interstitial (reading vs speaking)
    case hitsHardest    = 10  // Q4: when does it hit hardest? (preselects notification time)
    case connectStyle   = 11  // Q5: connect style (quiz v1) or victory outcome (quiz v2)
    case belief         = 12  // quiz v2 only: do you believe God wants more? (v1 skips it)
    case dailyMinutes   = 13  // Q6: how much time daily? (drives plan reveal rhythm)
    // Shared back-half (reused from the survey flow)
    case firstDeclaration = 14
    case personalDeclaration = 15
    case rating          = 16  // rating ask at the personal-declaration peak
    case planBuilding    = 17  // "building your plan" loader (transition, no bar)
    case planReveal      = 18  // named 30-day plan reveal — sets up the paywall ask
    case testimonials    = 19  // App Store review wall — social proof right before the ask
    case paywall         = 20
    case notificationTime = 21 // terminal — completes onboarding

    func valueScreenIndex(quizV2: Bool) -> Int? {
        var screens: [PromisesStep] = [
            .proven, .question, .yours, .activate, .everyArea, .experience, .promisePicker,
            .battleDuration, .alreadyTried, .insight, .hitsHardest, .connectStyle, .belief, .dailyMinutes
        ]
        if !quizV2 { screens.removeAll { $0 == .belief } }
        return screens.firstIndex(of: self).map { $0 + 1 }
    }

    static func totalValueScreens(quizV2: Bool) -> Int { quizV2 ? 14 : 13 }
}

// MARK: - Promise scene content

private enum PromiseScene {
    case proven, question, yours, activate, everyArea

    var symbol: String {
        switch self {
        case .proven:    return "checkmark.seal.fill"
        case .question:  return "questionmark.circle.fill"
        case .yours:     return "person.fill.checkmark"
        case .activate:  return "waveform"
        case .everyArea: return "sparkles"
        }
    }

    var eyebrow: String {
        switch self {
        case .proven:    return "START HERE"
        case .question:  return "THE REAL QUESTION"
        case .yours:     return "THE PART MOST PEOPLE MISS"
        case .activate:  return "HOW A PROMISE GOES TO WORK"
        case .everyArea: return "OVER EVERY AREA"
        }
    }

    var title: String {
        switch self {
        case .proven:    return "God's promises have\nnever failed. Not once."
        case .question:  return "It was never\nif they work."
        case .yours:     return "Every promise\nhas your name on it."
        case .activate:  return "A promise you speak\ngoes to work."
        case .everyArea: return "Nothing is left\noutside the promise."
        }
    }

    var body: String {
        switch self {
        case .proven:
            return "Every word He spoke has come to pass. Not one has fallen to the ground. The promises were settled long before you ever needed them."
        case .question:
            return "They always work. The only question left is whether you'll trust them, and put them to work, over your own life."
        case .yours:
            return "It's easy to believe God comes through for someone else. Everything changes the moment you believe He meant them for you, over your body, your home, your future."
        case .activate:
            return "Left on the page, it stays a someday. Spoken over your life, it moves. Speak it daily until your heart catches up to what's already yours."
        case .everyArea:
            return "Your peace. Your health. Your family. Your provision. There's no corner of your life His Word doesn't reach. You activate it one area at a time."
        }
    }

    var verse: String {
        switch self {
        case .proven:    return "Not one word has failed of all the good promises he gave."
        case .question:  return "For no matter how many promises God has made, they are 'Yes' in Christ."
        case .yours:     return "He has given us his very great and precious promises."
        case .activate:  return "The tongue has the power of life and death."
        case .everyArea: return "His divine power has given us everything we need for a godly life."
        }
    }

    var reference: String {
        switch self {
        case .proven:    return "1 Kings 8:56"
        case .question:  return "2 Corinthians 1:20"
        case .yours:     return "2 Peter 1:4"
        case .activate:  return "Proverbs 18:21"
        case .everyArea: return "2 Peter 1:3"
        }
    }

    var buttonLabel: String {
        switch self {
        case .everyArea: return "I'm Ready to Trust Them →"
        default:         return "Continue →"
        }
    }

    var analyticsName: String {
        switch self {
        case .proven:    return "proven"
        case .question:  return "question"
        case .yours:     return "yours"
        case .activate:  return "activate"
        case .everyArea: return "every_area"
        }
    }
}

// Each HeaviestBurden carries a promise-framed label for the picker. Selecting
// one writes `responses.heaviestBurden`, which the shared back-half (preview
// declaration, notification subtitle) and the seeding logic already understand.
private struct PromiseChoice {
    let statement: String
    let subtitle: String
    let symbol: String

    static func of(_ burden: HeaviestBurden) -> PromiseChoice {
        switch burden {
        case .health:
            return PromiseChoice(statement: "Healing over my body",
                                 subtitle: "His promise of wholeness, activated",
                                 symbol: "heart.fill")
        case .abundance:
            return PromiseChoice(statement: "Provision over my finances",
                                 subtitle: "His promise to supply every need",
                                 symbol: "key.fill")
        case .peace:
            return PromiseChoice(statement: "Peace over my home",
                                 subtitle: "His promise of rest, settling in",
                                 symbol: "house.fill")
        case .allOfIt:
            return PromiseChoice(statement: "Victory over what's against me",
                                 subtitle: "His promise that no weapon prospers",
                                 symbol: "bolt.fill")
        case .identity:
            return PromiseChoice(statement: "Knowing who I am in Christ",
                                 subtitle: "His promise that I am His, secured",
                                 symbol: "crown.fill")
        case .purpose:
            return PromiseChoice(statement: "Purpose over my future",
                                 subtitle: "His promise to finish what He started",
                                 symbol: "flag.fill")
        case .joy:
            return PromiseChoice(statement: "Joy that holds",
                                 subtitle: "His promise of unshakeable gladness",
                                 symbol: "sun.max.fill")
        }
    }
}

// Lead the picker with the promises in the same priority order the other arms use.
private let promisePickerOrder: [HeaviestBurden] = [
    .health, .abundance, .peace, .allOfIt, .identity, .purpose, .joy
]

// MARK: - Shared Components

private struct PromiseContinueButton: View {
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

private struct PromiseAppearStagger: ViewModifier {
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
    func promiseStagger(_ shown: Bool, delay: Double = 0) -> some View {
        modifier(PromiseAppearStagger(shown: shown, delay: delay))
    }
}

// MARK: - Promise Scene Screen

private struct PromiseSceneScreen: View {
    let size: CGSize
    let scene: PromiseScene
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
                    Image(systemName: scene.symbol)
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                }
                .promiseStagger(v)

                VStack(spacing: 14) {
                    Text(scene.eyebrow)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(DS.Palette.gold.opacity(0.9))
                        .kerning(1.4)
                        .multilineTextAlignment(.center)
                        .promiseStagger(v, delay: 0.08)

                    Text(scene.title)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .promiseStagger(v, delay: 0.14)

                    Text(scene.body)
                        .font(.system(size: 17, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 22)
                        .fixedSize(horizontal: false, vertical: true)
                        .promiseStagger(v, delay: 0.22)
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
                .promiseStagger(v, delay: 0.32)
            }
            .padding(.horizontal, 28)

            Spacer()

            PromiseContinueButton(label: scene.buttonLabel) { onContinue() }
                .padding(.bottom, 36)
                .promiseStagger(v, delay: 0.42)
        }
        .onAppear {
            AnalyticsService.shared.track("promise_scene_shown", parameters: ["scene": scene.analyticsName])
            withAnimation { v = true }
        }
    }
}

// MARK: - Promise Picker (seeds the feed)

private struct PromisePickerScreen: View {
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
                        Text("Which promise will you\nactivate first?")
                            .font(.system(size: 27, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .promiseStagger(v)

                        Text("We'll build your daily declarations around it\nand put it to work over your life.")
                            .font(.system(size: 15, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.65))
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                            .promiseStagger(v, delay: 0.1)
                    }
                    .padding(.horizontal, 28)

                    VStack(spacing: 10) {
                        ForEach(promisePickerOrder) { burden in
                            promiseRow(burden)
                        }
                    }
                    .padding(.horizontal, 20)
                    .promiseStagger(v, delay: 0.2)

                    Spacer().frame(height: 8)
                }
            }

            PromiseContinueButton(isEnabled: responses.heaviestBurden != nil, action: onContinue)
                .padding(.top, 8).padding(.bottom, 36)
        }
        .onAppear {
            AnalyticsService.shared.track("promise_picker_shown")
            withAnimation { v = true }
        }
    }

    private func promiseRow(_ burden: HeaviestBurden) -> some View {
        let choice = PromiseChoice.of(burden)
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
