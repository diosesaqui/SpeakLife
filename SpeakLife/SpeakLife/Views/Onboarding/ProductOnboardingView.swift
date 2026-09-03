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
//    5. Avoid discomfort — God's Word for the middle of a life storm
//
//  After the value screens it reuses the proven back-half (taste of a
//  personalized declaration → record your own → rating → plan-building loader →
//  named plan reveal → paywall → notification time), and seeds the home feed
//  from a single light category picker.
//
//  One arm of the onboarding A/B: HomeView routes here when Remote Config
//  `onboardingVariant` == "product" (see SubscriptionStore.resolvedOnboardingVariant).
//

import SwiftUI
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

    // Quiz v2 flag, frozen at the flow's first appearance (mirroring
    // lockOnboardingVariant's intent) so a realtime Remote Config activation
    // mid-session can't swap questions, progress totals, or quiz_version
    // under the user. The live-read fallback only covers pre-onAppear access.
    // When false the flow is byte-for-byte the current quiz (belief step
    // skipped, connect style question shown, no plan-reveal echo).
    @State private var quizV2Snapshot: Bool? = nil
    private var quizV2: Bool { quizV2Snapshot ?? subscriptionStore.useQuizV2 }

    private var valueProgress: Double {
        guard let idx = currentStep.valueScreenIndex(quizV2: quizV2) else { return 0 }
        return Double(idx) / Double(ProductStep.totalValueScreens(quizV2: quizV2))
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
            AnalyticsService.shared.track("product_onboarding_started")
        }
    }

    // Split to stay within SwiftUI's 10-branch ViewBuilder limit.
    @ViewBuilder
    private var currentStepView: some View {
        switch currentStep {
        case .hook:        ProductHookScreen(size: size) { advance() }
        case .speed:       ProductSpeedScreen(size: size) { advance() }
        case .mechanism:   ProductMechanismScreen(size: size) { advance() }
        case .experience:  OnboardingProductExperienceScreen(size: size, flow: "product") { advance() }
        case .categoryPicker:
            ProductCategoryPickerScreen(size: size, responses: responses) { advance() }
        case .battleDuration, .alreadyTried, .insight, .hitsHardest, .connectStyle, .belief, .dailyMinutes:
            quizStepView
        default: backHalfView
        }
    }

    // Extended quiz steps (Q2-Q6 + insight), shared with the warfare arm.
    @ViewBuilder
    private var quizStepView: some View {
        switch currentStep {
        case .battleDuration:
            SurveyExtendedQuizScreen(size: size, flow: "product", question: .battleDuration, selection: $responses.battleDuration) { advance() }
        case .alreadyTried:
            SurveyExtendedQuizScreen(size: size, flow: "product", question: .alreadyTried, selection: $responses.alreadyTried) { advance() }
        case .insight:
            SurveyQuizInsightScreen(size: size, flow: "product") { advance() }
        case .hitsHardest:
            SurveyExtendedQuizScreen(size: size, flow: "product", question: .hitsHardest, selection: $responses.hitsHardest) { advance() }
        case .connectStyle:
            // Quiz v2 swaps the connect-style question for the burden-aware
            // outcome question in the same slot; v1 is unchanged.
            if quizV2 {
                SurveyExtendedQuizScreen(size: size, flow: "product", question: .victoryLooksLike(for: responses.heaviestBurden ?? .peace), selection: $responses.victoryOutcome) { advance() }
            } else {
                SurveyExtendedQuizScreen(size: size, flow: "product", question: .connectStyle, selection: $responses.connectStyle) { advance() }
            }
        case .belief:
            // Quiz v2 only — v1's advance() jumps over this step entirely.
            SurveyExtendedQuizScreen(size: size, flow: "product", question: .belief, selection: $responses.beliefLevel) { advance() }
        case .dailyMinutes:
            SurveyExtendedQuizScreen(size: size, flow: "product", question: .dailyMinutes, selection: $responses.dailyMinutes) { advance() }
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var backHalfView: some View {
        switch currentStep {
        case .firstDeclaration:
            SurveyFirstDeclarationScreen(size: size, responses: responses, flow: "product") { advance() }
        case .personalDeclaration:
            PersonalDeclarationOnboardingView(
                viewModel: DIContainer.shared.makePersonalDeclarationViewModel(),
                size: size,
                flow: "product"
            ) { declaration in
                savedDeclaration = declaration
                advance()
            }
        case .rating:
            RatingView(size: size) { advance() }
        case .planBuilding:
            SurveyPlanBuildingScreen(burden: responses.heaviestBurden ?? .peace, flow: "product") { advance() }
        case .planReveal:
            SurveyPlanRevealScreen(
                size: size,
                burden: responses.heaviestBurden ?? .peace,
                flow: "product",
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
            TestimonialWallView(size: size, flow: "product") { advance() }
        case .paywall:
            HighConversionPaywallView(callback: { advance() }, source: "onboarding", isHardPaywall: true)
        case .notificationTime:
            SurveyQ8NotificationScreen(size: size, responses: responses, flow: "product") { advance() }
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
        // flow_schema 3 = testimonial wall inserted before paywall (2 = pre-testimonials, 1 = pre-renumbering); bump when step raw values are renumbered again.
        AnalyticsService.shared.track("product_step_completed", parameters: ["step": currentStep.rawValue, "flow_schema": 3])

        // Leaving the category picker: stamp the segment so downstream paywall
        // events carry a meaningful segment for this arm (quiz sets its own).
        if currentStep == .categoryPicker, let burden = responses.heaviestBurden {
            appState.onboardingSegment = "product_\(burden.shortLabel)"
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
            if !quizV2, ProductStep(rawValue: nextRaw) == .belief {
                nextRaw += 1
            }
            // Rating ask is remote-gated (onboardingRatingEnabled); when off,
            // skip straight past it to the next step.
            if ProductStep(rawValue: nextRaw) == .rating, !subscriptionStore.onboardingRatingEnabled {
                nextRaw += 1
            }
            guard let next = ProductStep(rawValue: nextRaw) else {
                assertionFailure("ProductOnboardingView.advance(): no successor for \(currentStep). .notificationTime should be terminal.")
                onComplete()
                return
            }
            withAnimation(.easeInOut(duration: 0.35)) { currentStep = next }
        }
    }

    // Mirrors SurveyOnboardingView's completion: persist the user's selected
    // category, seed the home feed + notifications from it, then finish.
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
            appState.personalDeclarationTimeIndex = notifTime.startTimeIndex
        }
        appState.hasPersonalDeclaration = savedDeclaration != nil
        AnalyticsService.shared.track("product_onboarding_completed", parameters: [
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
            "flow_schema": 3,  // joins with product_step_completed; bump when step raw values are renumbered again
            "set_personal_declaration": (savedDeclaration != nil) as NSNumber
        ])

        requestNotificationPermissionThenComplete(categories: notificationCategoriesSet)
    }

    private func requestNotificationPermissionThenComplete(categories: Set<DeclarationCategory>) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            AnalyticsService.shared.track("notification_permission", parameters: ["granted": granted, "source": "product_onboarding"])
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

enum ProductStep: Int, CaseIterable {
    // Value-led screens (the five marketing principles)
    case hook            = 0   // Avoid discomfort
    case speed           = 1   // Speed
    case mechanism       = 2   // New mechanism
    case experience      = 3   // Good experience
    case categoryPicker  = 4   // Clarity + personalization
    // Extended personalization quiz (shared screens in SurveyOnboardingScreens)
    case battleDuration  = 5   // Q2: how long has this battle been going on?
    case alreadyTried    = 6   // Q3: what have you already tried?
    case insight         = 7   // micro-insight interstitial (reading vs speaking)
    case hitsHardest     = 8   // Q4: when does it hit hardest? (preselects notification time)
    case connectStyle    = 9   // Q5: connect style (quiz v1) or victory outcome (quiz v2)
    case belief          = 10  // quiz v2 only: do you believe God wants more? (v1 skips it)
    case dailyMinutes    = 11  // Q6: how much time daily? (drives plan reveal rhythm)
    // Shared back-half (reused from the survey flow)
    case firstDeclaration = 12 // taste of the matched declaration
    case personalDeclaration = 13
    case rating          = 14  // rating ask at the personal-declaration peak
    case planBuilding    = 15  // "building your plan" loader (transition, no bar)
    case planReveal      = 16  // named 30-day plan reveal — sets up the paywall ask
    case testimonials    = 17  // App Store review wall — social proof right before the ask
    case paywall         = 18
    case notificationTime = 19 // terminal — completes onboarding

    // Index within the value-led intro + quiz screens, used to drive the
    // progress bar (visible investment across the question screens too).
    func valueScreenIndex(quizV2: Bool) -> Int? {
        var screens: [ProductStep] = [
            .hook, .speed, .mechanism, .experience, .categoryPicker,
            .battleDuration, .alreadyTried, .insight, .hitsHardest, .connectStyle, .belief, .dailyMinutes
        ]
        if !quizV2 { screens.removeAll { $0 == .belief } }
        return screens.firstIndex(of: self).map { $0 + 1 }
    }

    static func totalValueScreens(quizV2: Bool) -> Int { quizV2 ? 12 : 11 }
}

// MARK: - Shared Components

// Internal (not private) so the shared OnboardingProductExperienceScreen can
// reuse it. Single definition in the module, so no redeclaration conflict.
struct ProductContinueButton: View {
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
            AnalyticsService.shared.track("product_hook_shown")
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
            AnalyticsService.shared.track("product_speed_shown")
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
            AnalyticsService.shared.track("product_mechanism_shown")
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
            AnalyticsService.shared.track("product_category_picker_shown")
            withAnimation { v = true }
        }
    }

    private func categoryRow(_ option: HeaviestBurden) -> some View {
        let isSelected = responses.heaviestBurden == option
        return Button(action: {
            Juice.play(.tapLight)
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
