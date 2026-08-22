//
//  DirectOnboardingView.swift
//  SpeakLife
//
//  The pain-led arm. Every other arm opens by talking — a storm scene, a
//  thief, a promise, a nearness statement — and only asks the user what is
//  actually wrong five or six screens in. This one inverts that completely:
//
//    0. Pain      — "What brought you here?" on the very first frame, before
//                   a single word of pitch. The answer seeds everything.
//    1. Mechanism — how Jesus handled the exact thing they just named: He
//                   never begged it to leave, He spoke to it.
//    2. Payoff    — their personalized declaration, on screen, said out loud.
//    3. Proof     — the review wall, immediately before the ask.
//    4. Paywall
//    5. Time      — when their declaration arrives daily (terminal).
//
//  That is the whole flow. Four screens before the ask instead of sixteen.
//  Nothing here exists that does not either (a) personalize the product to
//  the user's pain, (b) explain the one mechanism the app runs on, or (c)
//  close. There is no extended quiz, no plan-building loader, no product
//  capability recap, no pledge, no rating interstitial — those are exactly
//  the screens this arm is testing the absence of.
//
//  The bet: a user who names their pain, hears how Jesus answered it, and
//  speaks a declaration over it inside 45 seconds arrives at the paywall with
//  more intent than one walked through a sixteen-screen quiz, and far more of
//  them arrive at all.
//
//  Mechanically it still writes the same `SurveyResponses.heaviestBurden` the
//  other arms write, so the shared back-half screens, the category seeding,
//  and the notification scheduling all work unchanged.
//
//  One arm of the onboarding A/B: HomeView routes here when Remote Config
//  `onboardingVariant` == "direct".
//

import SwiftUI
import UserNotifications

struct DirectOnboardingView: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var declarationStore: DeclarationViewModel
    let size: CGSize
    let onComplete: () -> Void

    // Reuse the survey response model so the shared back-half screens and the
    // seeding logic work unchanged. Only `heaviestBurden` (the opening
    // question) and `notificationTime` (the terminal screen) are ever set.
    @StateObject private var responses = SurveyResponses()
    @State private var currentStep: DirectStep = .pain

    var body: some View {
        ZStack(alignment: .top) {
            backgroundView

            currentStepView
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .offset(x: 0, y: 24)),
                    removal: .opacity.combined(with: .offset(x: 0, y: -16))
                ))
                .id(currentStep.rawValue)

            if let idx = currentStep.valueScreenIndex {
                VStack {
                    DirectProgressBar(current: idx, total: DirectStep.totalValueScreens)
                        .padding(.horizontal, 28)
                        .padding(.top, size.height * 0.065)
                    Spacer()
                }
                .allowsHitTesting(false)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            AnalyticsService.shared.track("direct_onboarding_started")
        }
    }

    @ViewBuilder
    private var currentStepView: some View {
        switch currentStep {
        case .pain:
            DirectPainScreen(size: size, responses: responses) { advance() }
        case .mechanism:
            DirectMechanismScreen(size: size, burden: responses.heaviestBurden ?? .peace) { advance() }
        case .declaration:
            DirectDeclarationScreen(size: size, burden: responses.heaviestBurden ?? .peace) { advance() }
        case .testimonials:
            TestimonialWallView(size: size, flow: "direct") { advance() }
        case .paywall:
            HighConversionPaywallView(callback: { advance() }, source: "onboarding", isHardPaywall: true)
        case .notificationTime:
            SurveyQ8NotificationScreen(size: size, responses: responses, flow: "direct") { advance() }
        }
    }

    private func advance() {
        Juice.play(.tapLight)
        AnalyticsService.shared.track("direct_step_completed", parameters: [
            "step": currentStep.rawValue,
            "flow_schema": 1  // bump when step raw values are renumbered
        ])

        // Leaving the opening question: stamp the segment so every downstream
        // paywall event carries a meaningful segment for this arm.
        if currentStep == .pain, let burden = responses.heaviestBurden {
            appState.onboardingSegment = "direct_\(burden.shortLabel)"
        }

        switch currentStep {
        case .notificationTime:
            applyResponsesAndComplete()
        default:
            guard let next = DirectStep(rawValue: currentStep.rawValue + 1) else {
                assertionFailure("DirectOnboardingView.advance(): no successor for \(currentStep). .notificationTime should be terminal.")
                onComplete()
                return
            }
            withAnimation(.easeInOut(duration: 0.35)) { currentStep = next }
        }
    }

    // Mirrors the warfare/closer completion: persist the chosen category, seed
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
        AnalyticsService.shared.track("direct_onboarding_completed", parameters: [
            "goal_word": goalWord.rawValue,
            "burden": responses.heaviestBurden?.rawValue ?? "unknown",
            "flow_schema": 1  // joins with direct_step_completed
        ])

        requestNotificationPermissionThenComplete(categories: notificationCategoriesSet)
    }

    private func requestNotificationPermissionThenComplete(categories: Set<DeclarationCategory>) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            AnalyticsService.shared.track("notification_permission", parameters: ["granted": granted, "source": "direct_onboarding"])
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
                    // Trial pushes may have been scheduled pre-authorization on
                    // the paywall; re-add now that delivery is guaranteed.
                    TrialExperienceService.shared.reschedulePendingTrialPushesIfNeeded()
                }
                onComplete()
            }
        }
    }

    private var backgroundView: some View {
        ZStack {
            Image(subscriptionStore.onboardingBGImage)
                .resizable().aspectRatio(contentMode: .fill)
                .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                .clipped()
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.86),
                    Color.black.opacity(0.62),
                    Color.black.opacity(0.78)
                ]),
                startPoint: .top, endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - Flow Steps

enum DirectStep: Int, CaseIterable {
    case pain            = 0  // "What brought you here?" — first frame, no preamble
    case mechanism       = 1  // how Jesus answered that exact thing
    case declaration     = 2  // their declaration, spoken out loud
    case testimonials    = 3  // the review wall, right before the ask
    case paywall         = 4
    case notificationTime = 5 // terminal — completes onboarding

    /// Index in the pre-paywall progress bar; nil once the bar should disappear.
    var valueScreenIndex: Int? {
        switch self {
        case .pain:         return 1
        case .mechanism:    return 2
        case .declaration:  return 3
        case .testimonials: return 4
        default:            return nil
        }
    }

    static let totalValueScreens = 4
}

// MARK: - Progress bar

private struct DirectProgressBar: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...total, id: \.self) { i in
                Capsule()
                    .fill(i <= current ? Color.white : Color.white.opacity(0.18))
                    .frame(height: 3)
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: current)
    }
}

// MARK: - Shared components

private struct DirectStagger: ViewModifier {
    let shown: Bool
    let delay: Double
    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 16)
            .animation(.easeOut(duration: 0.5).delay(delay), value: shown)
    }
}

private extension View {
    func directStagger(_ shown: Bool, delay: Double = 0) -> some View {
        modifier(DirectStagger(shown: shown, delay: delay))
    }
}

/// The arm's single CTA style: full-width gold, matching the storm opener the
/// other arms lead with so the brand moment is unchanged even though the
/// pacing is not.
private struct DirectCTA: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(DS.Palette.deepBlue)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    Capsule()
                        .fill(DS.Gradient.gold)
                        .shadow(color: DS.Palette.gold.opacity(0.45), radius: 14, x: 0, y: 6)
                )
        }
        .buttonStyle(.dsPressable(feel: .tapSolid))
        .padding(.horizontal, 28)
    }
}

// MARK: - Screen 0: What brought you here?

/// The pain the user is carrying, in their own words, phrased the way they
/// would actually say it — not as a category name. Each maps to the shared
/// `HeaviestBurden` so seeding and the back-half work unchanged.
private struct DirectPain: Identifiable {
    let id = UUID()
    let burden: HeaviestBurden
    let icon: String
    let line: String

    static let all: [DirectPain] = [
        .init(burden: .peace,     icon: "🕊", line: "My mind won't stop racing"),
        .init(burden: .health,    icon: "🌿", line: "My body needs healing"),
        .init(burden: .abundance, icon: "💰", line: "The money isn't there"),
        .init(burden: .identity,  icon: "👑", line: "I've lost sight of who I am"),
        .init(burden: .joy,       icon: "☀️", line: "I feel flat and empty"),
        .init(burden: .purpose,   icon: "🧭", line: "I'm off track from my calling"),
        .init(burden: .allOfIt,   icon: "⚡", line: "I just want more of God"),
    ]
}

private struct DirectPainRow: View {
    let pain: DirectPain
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Text(pain.icon)
                    .font(.system(size: 22))
                Text(pain.line)
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 17)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .fill(isSelected ? Color.white.opacity(0.22) : Color.white.opacity(0.09))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .stroke(isSelected ? DS.Palette.gold : Color.white.opacity(0.14), lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.dsPressable(feel: .tapLight))
    }
}

/// Screen one. No logo, no scene, no promise — the question is the first thing
/// on screen, and tapping an answer advances immediately. There is deliberately
/// no Continue button: a second tap to confirm a one-tap question is the exact
/// kind of friction this arm exists to remove.
private struct DirectPainScreen: View {
    let size: CGSize
    @ObservedObject var responses: SurveyResponses
    let onContinue: () -> Void

    @State private var v = false
    @State private var selected: HeaviestBurden? = nil

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    Spacer().frame(height: size.height * 0.12)

                    VStack(spacing: 10) {
                        Text("What brought you\nhere today?")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .directStagger(v)

                        Text("Say it plain. We'll build everything around it.")
                            .font(.system(size: 15, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.65))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .directStagger(v, delay: 0.08)
                    }
                    .padding(.horizontal, 28)

                    VStack(spacing: 10) {
                        ForEach(DirectPain.all) { pain in
                            DirectPainRow(pain: pain, isSelected: selected == pain.burden) {
                                choose(pain.burden)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .directStagger(v, delay: 0.16)

                    Spacer().frame(height: 40)
                }
            }
        }
        .onAppear {
            AnalyticsService.shared.track("direct_pain_shown")
            withAnimation { v = true }
        }
    }

    /// Selects, then advances on a short beat so the highlight is visible
    /// before the screen changes — the tap still feels acknowledged without
    /// costing a second tap.
    private func choose(_ burden: HeaviestBurden) {
        guard selected == nil else { return }  // ignore double taps mid-transition
        withAnimation(.easeOut(duration: 0.15)) { selected = burden }
        responses.heaviestBurden = burden
        AnalyticsService.shared.track("direct_pain_answered", parameters: [
            "burden": burden.rawValue
        ])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) { onContinue() }
    }
}

// MARK: - Screen 1: How Jesus handled it

/// The mechanism, aimed at the pain they just named. Every burden gets the
/// same three-beat proof — He spoke to the storm, He spoke to sickness, He
/// spoke to the grave — and then one line that lands it on their specific
/// answer, so the teaching never reads as generic.
private struct DirectMechanismScreen: View {
    let size: CGSize
    let burden: HeaviestBurden
    let onContinue: () -> Void

    @State private var v = false

    /// The line that ties Jesus' method to the exact thing they just tapped.
    private var applied: String {
        switch burden {
        case .peace:     return "So you won't beg your mind to settle. You'll speak peace to it."
        case .health:    return "So you won't beg your body to hold on. You'll speak healing to it."
        case .abundance: return "So you won't beg for provision. You'll speak God's supply over it."
        case .identity:  return "So you won't hope you matter. You'll speak who God says you are."
        case .joy:       return "So you won't wait to feel better. You'll speak His joy over your day."
        case .purpose:   return "So you won't wonder about your calling. You'll speak it into motion."
        case .allOfIt:   return "So you won't ask for more. You'll speak the more God already gave you."
        }
    }

    private let beats: [(String, String)] = [
        ("The storm",   "\"Quiet! Be still!\" — and the wind stopped."),
        ("The sickness","\"Be clean.\" — and the leprosy left."),
        ("The grave",   "\"Lazarus, come out!\" — and a dead man walked.")
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 26) {
                    Spacer().frame(height: size.height * 0.14)

                    VStack(spacing: 12) {
                        Text("SPEAKLIFE · PRAY LIKE JESUS")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(DS.Palette.gold.opacity(0.9))
                            .kerning(1.4)
                            .directStagger(v)

                        Text("Jesus never begged\nthe problem to leave.\nHe spoke to it.")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.8)
                            .fixedSize(horizontal: false, vertical: true)
                            .directStagger(v, delay: 0.08)
                    }
                    .padding(.horizontal, 28)

                    VStack(spacing: 14) {
                        ForEach(Array(beats.enumerated()), id: \.offset) { idx, beat in
                            HStack(alignment: .top, spacing: 12) {
                                Text(beat.0)
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(DS.Palette.gold)
                                    .frame(width: 92, alignment: .leading)
                                Text(beat.1)
                                    .font(.system(size: 15, weight: .regular, design: .rounded))
                                    .foregroundColor(.white.opacity(0.82))
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                            }
                            .directStagger(v, delay: 0.18 + Double(idx) * 0.08)
                        }
                    }
                    .padding(20)
                    .dsGlass(cornerRadius: DS.Radius.lg)
                    .padding(.horizontal, 24)

                    Text(applied)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 30)
                        .directStagger(v, delay: 0.46)

                    Spacer().frame(height: 8)
                }
            }

            DirectCTA(label: "Give Me Mine →") { onContinue() }
                .padding(.bottom, 36)
                .directStagger(v, delay: 0.54)
        }
        .onAppear {
            AnalyticsService.shared.track("direct_mechanism_shown", parameters: [
                "burden": burden.rawValue
            ])
            withAnimation { v = true }
        }
    }
}

// MARK: - Screen 2: Their declaration

/// The payoff, three screens in: the declaration built for the pain they named,
/// with the verse it stands on, and one instruction — say it out loud. The CTA
/// is the confirmation, so the act of speaking is the thing that advances the
/// flow rather than a generic Continue.
private struct DirectDeclarationScreen: View {
    let size: CGSize
    let burden: HeaviestBurden
    let onContinue: () -> Void

    @State private var v = false
    @State private var spoken = false

    private var preview: (text: String, verse: String, reference: String) {
        burden.previewDeclaration
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 22) {
                VStack(spacing: 6) {
                    Text("YOUR DECLARATION")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(DS.Palette.gold.opacity(0.9))
                        .kerning(1.4)
                    Text("Say this out loud. Right now.")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .directStagger(v)

                VStack(spacing: 20) {
                    Text(preview.text)
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(spacing: 4) {
                        Text("\"\(preview.verse)\"")
                            .font(.system(size: 14, weight: .regular, design: .serif))
                            .italic()
                            .foregroundColor(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(preview.reference)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
                .padding(28)
                .dsGlass(cornerRadius: DS.Radius.lg)
                .padding(.horizontal, 24)
                .directStagger(v, delay: 0.12)

                Text(spoken
                     ? "That's how you'll pray from here. Every day, over this exact thing."
                     : "Out loud is the whole point. Faith comes by hearing your own voice say it.")
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 34)
                    .directStagger(v, delay: 0.28)
                    .animation(.easeInOut(duration: 0.3), value: spoken)
            }

            Spacer()

            DirectCTA(label: spoken ? "Build My Daily Plan →" : "I Said It Out Loud") {
                if spoken {
                    onContinue()
                } else {
                    // No explicit haptic: DirectCTA's .dsPressable already
                    // fires one on press.
                    AnalyticsService.shared.track("direct_declaration_spoken", parameters: [
                        "burden": burden.rawValue
                    ])
                    withAnimation(.easeInOut(duration: 0.3)) { spoken = true }
                }
            }
            .padding(.bottom, 36)
            .directStagger(v, delay: 0.38)
        }
        .onAppear {
            AnalyticsService.shared.track("direct_declaration_shown", parameters: [
                "burden": burden.rawValue
            ])
            withAnimation { v = true }
        }
    }
}
