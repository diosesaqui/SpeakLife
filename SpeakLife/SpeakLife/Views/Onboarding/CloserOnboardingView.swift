//
//  CloserOnboardingView.swift
//  SpeakLife
//
//  A nearness-and-commitment onboarding A/B variant, and the first arm that
//  changes the *visual* system rather than only the angle. Where warfare leads
//  with the fight, outcomes with the win, and promises with the settled fact,
//  this arm leads with RELATIONSHIP — you can be closer to God than you are
//  right now, and speaking His Word is what closes the distance. The narrative
//  arc is:
//
//    0. Nearness    — God is nearer than you feel; the invitation is open
//    1. Longing     — yes/no: do you want to feel closer than you do now?
//    2. Growth      — the proof curve: closeness compounds when you speak daily
//    3. Drift       — yes/no: have you started strong with God and then drifted?
//    4. Spoken      — the mechanism: read alone it stays a page, spoken it moves
//    5. Rhythm      — reminders + streaks are what carry you past the drift
//
//  Then the product-capability recap, a "where do you most want to feel Him
//  move first?" picker (which seeds the home feed), the same extended
//  personalization quiz the warfare/outcomes/promises arms run, and the proven
//  back-half — with one insertion: an "I'm In" PLEDGE screen between the plan
//  reveal and the social-proof wall, so the user makes an explicit commitment
//  immediately before the ask. The pledge is remote-gated
//  (`closerPledgeEnabled`), giving a 2-cell split inside the arm: it is the one
//  element here that could plausibly go negative, since a sense of completion
//  one screen early may discharge the tension the paywall runs on.
//
//  Two things are deliberately different from the other arms, and they are the
//  point of the test:
//
//    • Visual system. A flat SpeakLife-navy canvas with full-bleed cinematic
//      hero art dissolving into it, a segmented progress bar, and full-width
//      gold CTAs — instead of the shared blurred theme background, gold icon
//      circles, and capsule buttons every other arm uses. (The reference flow
//      uses pure black; navy keeps the same cinematic contrast without the
//      shared quiz screens reading as dead space, and stays on brand.)
//    • Agreement ladder. Two binary yes/no micro-commitments in the front half
//      instead of statement-only screens, so the user is saying yes before the
//      quiz ever starts.
//
//  Everything else is mechanically identical to the outcomes arm — same quiz,
//  same back-half, same seeding — so the A/B isolates the look and the angle,
//  not the funnel depth. The picker maps each choice to a HeaviestBurden /
//  category so the shared screens + seeding work unchanged.
//
//  Note: the competitor flow this is modeled on offers a "Skip" affordance on
//  every screen. That is deliberately NOT carried over — every other arm makes
//  the personalization quiz mandatory, and adding a bail-out here would confound
//  the comparison with a funnel-depth change.
//
//  One arm of the onboarding A/B: HomeView routes here when Remote Config
//  `onboardingVariant` == "closer".
//

import SwiftUI
import UserNotifications
import UIKit

struct CloserOnboardingView: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var declarationStore: DeclarationViewModel
    let size: CGSize
    let onComplete: () -> Void

    // Reuse the survey response model so the shared back-half screens and the
    // seeding logic work unchanged. Only `heaviestBurden` and `notificationTime`
    // are set here (the closeness picker writes `heaviestBurden`).
    @StateObject private var responses = SurveyResponses()
    @State private var currentStep: CloserStep = .nearness
    @State private var savedDeclaration: PersonalDeclaration? = nil

    // The two front-half agreement answers. Recorded for analytics only — they
    // deliberately do not branch the flow, so every user walks the same steps.
    @State private var wantsCloser: Bool? = nil
    @State private var hasDrifted: Bool? = nil

    // Quiz v2 flag, frozen at the flow's first appearance (mirroring
    // lockOnboardingVariant's intent) so a realtime Remote Config activation
    // mid-session can't swap questions, progress totals, or quiz_version under
    // the user. The live-read fallback only covers pre-onAppear access.
    @State private var quizV2Snapshot: Bool? = nil
    private var quizV2: Bool { quizV2Snapshot ?? subscriptionStore.useQuizV2 }

    // Pledge cell, frozen the same way and for the same reason: a user must not
    // be counted into one cell at funnel entry and then walk the other one.
    @State private var pledgeEnabledSnapshot: Bool? = nil
    private var pledgeEnabled: Bool { pledgeEnabledSnapshot ?? subscriptionStore.closerPledgeEnabled }

    private var valueScreenIndex: Int? { currentStep.valueScreenIndex(quizV2: quizV2) }

    var body: some View {
        ZStack(alignment: .top) {
            CloserTheme.canvas.ignoresSafeArea()

            currentStepView
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .offset(x: 0, y: 24)),
                    removal: .opacity.combined(with: .offset(x: 0, y: -16))
                ))
                .id(currentStep.rawValue)

            if let idx = valueScreenIndex {
                VStack {
                    CloserSegmentedProgressBar(
                        current: idx,
                        total: CloserStep.totalValueScreens(quizV2: quizV2)
                    )
                    .padding(.horizontal, 24)
                    .padding(.top, CloserInsets.top + 12)
                    Spacer()
                }
                .allowsHitTesting(false)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            if quizV2Snapshot == nil { quizV2Snapshot = subscriptionStore.useQuizV2 }
            if pledgeEnabledSnapshot == nil { pledgeEnabledSnapshot = subscriptionStore.closerPledgeEnabled }
            // Stamp the pledge cell at funnel entry so the two cells are
            // separable even for users who drop before reaching the pledge.
            AnalyticsService.shared.track("closer_onboarding_started", parameters: [
                "pledge_enabled": pledgeEnabled as NSNumber
            ])
        }
    }

    @ViewBuilder
    private var currentStepView: some View {
        switch currentStep {
        case .nearness:
            CloserSceneScreen(size: size, scene: .nearness) { advance() }
        case .longingQ:
            CloserAgreementScreen(
                size: size,
                question: .longing,
                answer: $wantsCloser
            ) { advance() }
        case .growth:
            CloserGrowthScreen(size: size) { advance() }
        case .driftQ:
            CloserAgreementScreen(
                size: size,
                question: .drift,
                answer: $hasDrifted
            ) { advance() }
        case .spoken:
            CloserSceneScreen(size: size, scene: .spoken) { advance() }
        case .rhythm:
            CloserRhythmScreen(size: size) { advance() }
        case .experience:
            OnboardingProductExperienceScreen(size: size, flow: "closer") { advance() }
        case .closenessPicker:
            CloserPickerScreen(size: size, responses: responses) { advance() }
        case .battleDuration, .alreadyTried, .insight, .hitsHardest, .connectStyle, .belief, .dailyMinutes:
            quizStepView
        default:
            backHalfView
        }
    }

    // Extended quiz steps (Q2-Q6 + insight), shared with the warfare/outcomes/promises arms.
    @ViewBuilder
    private var quizStepView: some View {
        switch currentStep {
        case .battleDuration:
            SurveyExtendedQuizScreen(size: size, flow: "closer", question: .battleDuration, selection: $responses.battleDuration) { advance() }
        case .alreadyTried:
            SurveyExtendedQuizScreen(size: size, flow: "closer", question: .alreadyTried, selection: $responses.alreadyTried) { advance() }
        case .insight:
            SurveyQuizInsightScreen(size: size, flow: "closer") { advance() }
        case .hitsHardest:
            SurveyExtendedQuizScreen(size: size, flow: "closer", question: .hitsHardest, selection: $responses.hitsHardest) { advance() }
        case .connectStyle:
            // Quiz v2 swaps the connect-style question for the burden-aware
            // outcome question in the same slot; v1 is unchanged.
            if quizV2 {
                SurveyExtendedQuizScreen(size: size, flow: "closer", question: .victoryLooksLike(for: responses.heaviestBurden ?? .peace), selection: $responses.victoryOutcome) { advance() }
            } else {
                SurveyExtendedQuizScreen(size: size, flow: "closer", question: .connectStyle, selection: $responses.connectStyle) { advance() }
            }
        case .belief:
            // Quiz v2 only — v1's advance() jumps over this step entirely.
            SurveyExtendedQuizScreen(size: size, flow: "closer", question: .belief, selection: $responses.beliefLevel) { advance() }
        case .dailyMinutes:
            SurveyExtendedQuizScreen(size: size, flow: "closer", question: .dailyMinutes, selection: $responses.dailyMinutes) { advance() }
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var backHalfView: some View {
        switch currentStep {
        case .firstDeclaration:
            SurveyFirstDeclarationScreen(size: size, responses: responses, flow: "closer") { advance() }
        case .personalDeclaration:
            PersonalDeclarationOnboardingView(
                viewModel: DIContainer.shared.makePersonalDeclarationViewModel(),
                size: size,
                flow: "closer"
            ) { declaration in
                savedDeclaration = declaration
                advance()
            }
        case .rating:
            RatingView(size: size) { advance() }
        case .planBuilding:
            SurveyPlanBuildingScreen(burden: responses.heaviestBurden ?? .peace, flow: "closer") { advance() }
        case .planReveal:
            SurveyPlanRevealScreen(
                size: size,
                burden: responses.heaviestBurden ?? .peace,
                flow: "closer",
                personalDeclaration: savedDeclaration?.declarationText,
                dailyMinutes: responses.dailyMinutes,
                victoryEcho: responses.victoryEcho  // nil in quiz v1
            ) { advance() }
        case .pledge:
            // Unique to this arm: an explicit "I'm In" commitment immediately
            // after the plan is revealed and before the ask.
            CloserPledgeScreen(size: size, burden: responses.heaviestBurden ?? .peace) { advance() }
        case .testimonials:
            TestimonialWallView(size: size, flow: "closer") { advance() }
        case .paywall:
            HighConversionPaywallView(callback: { advance() }, source: "onboarding", isHardPaywall: true)
        case .notificationTime:
            SurveyQ8NotificationScreen(size: size, responses: responses, flow: "closer") { advance() }
        default:
            EmptyView()
        }
    }

    private func advance() {
        Juice.play(.tapLight)
        // flow_schema 1 = original closer arc (nearness → pledge → paywall). Bump when step raw values are renumbered.
        AnalyticsService.shared.track("closer_step_completed", parameters: [
            "step": currentStep.rawValue,
            "flow_schema": 1,
            "pledge_enabled": pledgeEnabled as NSNumber
        ])

        // Leaving the closeness picker: stamp the segment so downstream paywall
        // events carry a meaningful segment for this arm (quiz sets its own).
        if currentStep == .closenessPicker, let burden = responses.heaviestBurden {
            appState.onboardingSegment = "closer_\(burden.shortLabel)"
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
            if !quizV2, CloserStep(rawValue: nextRaw) == .belief {
                nextRaw += 1
            }
            // Rating ask is remote-gated (onboardingRatingEnabled); when off,
            // skip straight past it to the next step.
            if CloserStep(rawValue: nextRaw) == .rating, !subscriptionStore.onboardingRatingEnabled {
                nextRaw += 1
            }
            // Pledge is remote-gated (closerPledgeEnabled) so this arm can run a
            // no-pledge cell; when off, the plan reveal leads straight into the
            // testimonial wall.
            if CloserStep(rawValue: nextRaw) == .pledge, !pledgeEnabled {
                nextRaw += 1
            }
            guard let next = CloserStep(rawValue: nextRaw) else {
                assertionFailure("CloserOnboardingView.advance(): no successor for \(currentStep). .notificationTime should be terminal.")
                onComplete()
                return
            }
            withAnimation(.easeInOut(duration: 0.35)) { currentStep = next }
        }
    }

    // Mirrors the warfare/outcomes/promises completion: persist the chosen
    // category, seed the home feed + notifications from it, then finish.
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
        AnalyticsService.shared.track("closer_onboarding_completed", parameters: [
            "goal_word": goalWord.rawValue,
            "burden": responses.heaviestBurden?.rawValue ?? "unknown",
            "wants_closer": wantsCloser.map { $0 ? "yes" : "no" } ?? "unknown",
            "has_drifted": hasDrifted.map { $0 ? "yes" : "no" } ?? "unknown",
            "battle_duration": responses.battleDuration ?? "unknown",
            "already_tried": responses.alreadyTried ?? "unknown",
            "hits_hardest": responses.hitsHardest ?? "unknown",
            "connect_style": responses.connectStyle ?? "unknown",
            "daily_minutes": responses.dailyMinutes ?? "unknown",
            "victory_looks_like": responses.victoryOutcome ?? "unknown",
            "belief": responses.beliefLevel ?? "unknown",
            "quiz_version": quizV2 ? "v2" : "v1",
            "pledge_enabled": pledgeEnabled as NSNumber,
            "flow_schema": 1,  // joins with closer_step_completed; bump when step raw values are renumbered
            "set_personal_declaration": (savedDeclaration != nil) as NSNumber
        ])

        requestNotificationPermissionThenComplete(categories: notificationCategoriesSet)
    }

    private func requestNotificationPermissionThenComplete(categories: Set<DeclarationCategory>) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            AnalyticsService.shared.track("notification_permission", parameters: ["granted": granted, "source": "closer_onboarding"])
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

enum CloserStep: Int, CaseIterable {
    // Nearness narrative + agreement ladder
    case nearness        = 0   // God is nearer than you feel (the invitation)
    case longingQ        = 1   // yes/no: do you want to feel closer than you do now?
    case growth          = 2   // the proof curve: closeness compounds when you speak
    case driftQ          = 3   // yes/no: have you started strong and then drifted?
    case spoken          = 4   // the mechanism: a word spoken is a word that moves
    case rhythm          = 5   // reminders + streaks carry you past the drift
    case experience      = 6   // product-capability recap (shared with the other arms)
    case closenessPicker = 7   // where do you want to feel Him move first? (seeds the feed)
    // Extended personalization quiz (shared screens in SurveyOnboardingScreens)
    case battleDuration  = 8   // Q2: how long has this been going on?
    case alreadyTried    = 9   // Q3: what have you already tried?
    case insight         = 10  // micro-insight interstitial (reading vs speaking)
    case hitsHardest     = 11  // Q4: when does it hit hardest? (preselects notification time)
    case connectStyle    = 12  // Q5: connect style (quiz v1) or victory outcome (quiz v2)
    case belief          = 13  // quiz v2 only: do you believe God wants more? (v1 skips it)
    case dailyMinutes    = 14  // Q6: how much time daily? (drives plan reveal rhythm)
    // Shared back-half (reused from the survey flow)
    case firstDeclaration    = 15
    case personalDeclaration = 16
    case rating              = 17  // rating ask at the personal-declaration peak
    case planBuilding        = 18  // "building your plan" loader (transition, no bar)
    case planReveal          = 19  // named 30-day plan reveal
    case pledge              = 20  // unique to this arm: the "I'm In" commitment
    case testimonials        = 21  // App Store review wall — social proof right before the ask
    case paywall             = 22
    case notificationTime    = 23  // terminal — completes onboarding

    func valueScreenIndex(quizV2: Bool) -> Int? {
        var screens: [CloserStep] = [
            .nearness, .longingQ, .growth, .driftQ, .spoken, .rhythm, .experience, .closenessPicker,
            .battleDuration, .alreadyTried, .insight, .hitsHardest, .connectStyle, .belief, .dailyMinutes
        ]
        if !quizV2 { screens.removeAll { $0 == .belief } }
        return screens.firstIndex(of: self).map { $0 + 1 }
    }

    static func totalValueScreens(quizV2: Bool) -> Int { quizV2 ? 15 : 14 }
}

// MARK: - Canvas + insets

/// The arm's canvas. Built on the SpeakLife brand navy rather than the pure
/// black the reference flow uses: black left the shared quiz screens (which
/// draw white type with no background of their own) sitting on dead space, and
/// it read as a different app rather than a different flow. The navy keeps the
/// cinematic, high-contrast feel while staying unmistakably SpeakLife, and the
/// amber CTA glow pops harder against it than it did against black.
private enum CloserTheme {
    static let canvasTop    = Color(hex: "#16213F")
    static let canvasMid    = DS.Palette.deepBlue
    static let canvasBottom = Color(hex: "#0A0F1F")

    static let canvas = LinearGradient(
        colors: [canvasTop, canvasMid, canvasBottom],
        startPoint: .top, endPoint: .bottom
    )
}

/// Window safe-area insets, read from UIKit.
///
/// HomeView applies `.ignoresSafeArea()` to every onboarding arm from the
/// outside, which zeroes out the insets a SwiftUI GeometryReader would report
/// in here — that is why the other arms position chrome with percentages of
/// screen height. Those percentages predate the Dynamic Island: 5.5% of an
/// iPhone 15 Pro's height is 47pt, which lands the progress bar underneath a
/// 59pt status bar. Reading the window directly is stable across every device
/// and is what keeps the bar and the CTAs clear of the hardware.
private enum CloserInsets {
    private static var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }

    /// Falls back to the common notch height if no window is available yet.
    static var top: CGFloat { keyWindow?.safeAreaInsets.top ?? 47 }
    static var bottom: CGFloat { keyWindow?.safeAreaInsets.bottom ?? 34 }

    /// Standard bottom padding for a primary CTA: clear of the home indicator
    /// on every device, comfortable on the ones without one.
    static var ctaBottom: CGFloat { bottom + 24 }
}

// MARK: - Hero art

/// The cinematic hero images this arm is built around. Each falls back to the
/// shared onboarding background if the asset hasn't shipped yet, so the flow is
/// always renderable — a missing catalog entry degrades to the old look rather
/// than to an empty frame.
private enum CloserArt: String {
    case dawn   = "closerDawn"
    case prayer = "closerPrayer"
    case bible  = "closerBible"
    case spoken = "closerSpoken"
    case pledge = "closerPledge"

    /// `nil` when the asset is absent from the catalog, so callers can fall back.
    var assetName: String? { UIImage(named: rawValue) != nil ? rawValue : nil }
}

/// Full-bleed hero anchored to the top of the screen, dissolving into black.
/// The mask is what makes the pure-black canvas read as one continuous surface
/// instead of a photo sitting on a background.
private struct CloserHero: View {
    let art: CloserArt
    let height: CGFloat
    /// Grayscale + lifted contrast for the two agreement screens, matching the
    /// editorial black-and-white treatment they were designed for.
    var monochrome: Bool = false

    var body: some View {
        Group {
            if let name = art.assetName {
                Image(name)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                // Asset not shipped yet — fall back to a wash of the canvas so
                // the screen still composes correctly.
                LinearGradient(
                    colors: [CloserTheme.canvasTop, CloserTheme.canvasMid],
                    startPoint: .top, endPoint: .bottom
                )
            }
        }
        .frame(width: UIScreen.main.bounds.width, height: height)
        .clipped()
        .saturation(monochrome ? 0 : 1)
        // Tint the lower half toward the canvas BEFORE fading it out. The art
        // dissolves to black on its own, and black over navy would read as a
        // smudge at the seam; tinting first makes the handoff invisible.
        .overlay(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.40),
                    .init(color: CloserTheme.canvasMid.opacity(0.75), location: 0.80),
                    .init(color: CloserTheme.canvasMid, location: 1.0)
                ],
                startPoint: .top, endPoint: .bottom
            )
        )
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .black, location: 0.0),
                    .init(color: .black, location: 0.55),
                    .init(color: .clear, location: 1.0)
                ],
                startPoint: .top, endPoint: .bottom
            )
        )
    }
}

// MARK: - Shared Components

/// Segmented progress bar. Distinct from the continuous bar every other arm
/// uses — one of the two deliberate visual manipulations in this test.
private struct CloserSegmentedProgressBar: View {
    let current: Int   // 1-based
    let total: Int

    var body: some View {
        HStack(spacing: 5) {
            ForEach(1...max(total, 1), id: \.self) { i in
                Capsule()
                    .fill(i <= current ? Color.white : Color.white.opacity(0.18))
                    .frame(height: 3)
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: current)
    }
}

/// Full-width gold CTA with a trailing arrow, seated on an amber glow. The
/// other arms use a centered capsule; this shape is part of the manipulation.
private struct CloserCTAButton: View {
    let label: String
    let isEnabled: Bool
    let action: () -> Void

    init(label: String = "Continue", isEnabled: Bool = true, action: @escaping () -> Void) {
        self.label = label
        self.isEnabled = isEnabled
        self.action = action
    }

    var body: some View {
        ZStack {
            // Warm bloom behind the CTA, so the bottom of a black screen still
            // has somewhere for the eye to land.
            if isEnabled {
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [DS.Palette.gold.opacity(0.32), .clear],
                            center: .center, startRadius: 0, endRadius: 190
                        )
                    )
                    .frame(height: 190)
                    .blur(radius: 18)
                    .allowsHitTesting(false)
            }

            Button(action: action) {
                HStack {
                    Spacer()
                    Text(label)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(isEnabled ? Color.black.opacity(0.88) : .white.opacity(0.35))
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(isEnabled ? Color.black.opacity(0.88) : .white.opacity(0.35))
                }
                .padding(.horizontal, 26)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(isEnabled ? AnyShapeStyle(DS.Gradient.gold) : AnyShapeStyle(Color.white.opacity(0.10)))
                )
            }
            .buttonStyle(.dsPressable(feel: .tapSolid))
            .disabled(!isEnabled)
        }
        .padding(.horizontal, 24)
        .animation(.easeInOut(duration: 0.2), value: isEnabled)
    }
}

private struct CloserAppearStagger: ViewModifier {
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
    func closerStagger(_ shown: Bool, delay: Double = 0) -> some View {
        modifier(CloserAppearStagger(shown: shown, delay: delay))
    }
}

/// Headline built from a white sentence with a gold-highlighted phrase, the
/// signature type treatment of this arm.
private struct CloserHeadline: View {
    let leading: String
    let highlight: String
    let trailing: String
    var size: CGFloat = 30

    var body: some View {
        (
            Text(leading).foregroundColor(.white)
            + Text(highlight).foregroundColor(DS.Palette.gold)
            + Text(trailing).foregroundColor(.white)
        )
        .font(.system(size: size, weight: .bold, design: .rounded))
        .multilineTextAlignment(.center)
        .lineSpacing(2)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// Scripture block in a bordered card with a gold rule, matching the pledge
/// screen's quote treatment.
private struct CloserVerseCard: View {
    let verse: String
    let reference: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(DS.Palette.gold)
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 6) {
                Text(verse)
                    .font(.system(size: 15, weight: .regular, design: .serif))
                    .foregroundColor(.white.opacity(0.86))
                    .fixedSize(horizontal: false, vertical: true)
                Text(reference.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .kerning(1.1)
                    .foregroundColor(.white.opacity(0.45))
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.07))
        )
    }
}

// MARK: - Narrative scene content

private enum CloserScene {
    case nearness, spoken

    var art: CloserArt {
        switch self {
        case .nearness: return .dawn
        case .spoken:   return .spoken
        }
    }

    var eyebrow: String {
        switch self {
        case .nearness: return "START HERE"
        case .spoken:   return "HOW THE DISTANCE CLOSES"
        }
    }

    // Headline split so one phrase carries the gold.
    var headline: (leading: String, highlight: String, trailing: String) {
        switch self {
        case .nearness: return ("God is ", "closer", " than you feel right now.")
        case .spoken:   return ("A word you ", "speak", " is a word that moves.")
        }
    }

    var body: String {
        switch self {
        case .nearness:
            return "He never stepped back. The distance you feel is not where He is. Draw near, and He closes the gap Himself."
        case .spoken:
            return "Left on the page, His Word stays information. Spoken over your life, it becomes the thing your heart starts to believe."
        }
    }

    var verse: String {
        switch self {
        case .nearness: return "Come near to God and he will come near to you."
        case .spoken:   return "The tongue has the power of life and death."
        }
    }

    var reference: String {
        switch self {
        case .nearness: return "James 4:8"
        case .spoken:   return "Proverbs 18:21"
        }
    }

    var buttonLabel: String {
        switch self {
        case .nearness: return "I Want That"
        case .spoken:   return "Continue"
        }
    }

    var analyticsName: String {
        switch self {
        case .nearness: return "nearness"
        case .spoken:   return "spoken"
        }
    }
}

// MARK: - Narrative Scene Screen

private struct CloserSceneScreen: View {
    let size: CGSize
    let scene: CloserScene
    let onContinue: () -> Void
    @State private var v = false

    private var hasArt: Bool { scene.art.assetName != nil }

    var body: some View {
        ZStack(alignment: .top) {
            if hasArt {
                CloserHero(art: scene.art, height: size.height * 0.48)
            }

            VStack(spacing: 0) {
                // With hero art the copy is offset to sit below it. Without,
                // that offset would open the screen on a half-height empty
                // band, so the top spacer goes flexible and the copy centers
                // against the Spacer above the CTA instead.
                if hasArt {
                    Spacer().frame(height: size.height * 0.40)
                } else {
                    Spacer(minLength: CloserInsets.top + 32)
                }

                VStack(spacing: 16) {
                    Text(scene.eyebrow)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .kerning(1.5)
                        .foregroundColor(DS.Palette.gold.opacity(0.9))
                        .closerStagger(v, delay: 0.05)

                    CloserHeadline(
                        leading: scene.headline.leading,
                        highlight: scene.headline.highlight,
                        trailing: scene.headline.trailing
                    )
                    .padding(.horizontal, 26)
                    .closerStagger(v, delay: 0.12)

                    Text(scene.body)
                        .font(.system(size: 17, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.68))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 30)
                        .fixedSize(horizontal: false, vertical: true)
                        .closerStagger(v, delay: 0.2)

                    CloserVerseCard(verse: scene.verse, reference: scene.reference)
                        .padding(.horizontal, 26)
                        .padding(.top, 6)
                        .closerStagger(v, delay: 0.28)
                }

                Spacer()

                CloserCTAButton(label: scene.buttonLabel) { onContinue() }
                    .padding(.bottom, CloserInsets.ctaBottom)
                    .closerStagger(v, delay: 0.36)
            }
        }
        .onAppear {
            AnalyticsService.shared.track("closer_scene_shown", parameters: ["scene": scene.analyticsName])
            withAnimation { v = true }
        }
    }
}

// MARK: - Agreement (yes/no) screens

private enum CloserAgreementQuestion {
    case longing, drift

    var art: CloserArt {
        switch self {
        case .longing: return .prayer
        case .drift:   return .bible
        }
    }

    var question: String {
        switch self {
        case .longing: return "Do you want to feel closer to God than you do right now?"
        case .drift:   return "Have you ever started strong with God, then slowly drifted?"
        }
    }

    var affirmative: String {
        switch self {
        case .longing: return "Yes, I do"
        case .drift:   return "Yes, more than once"
        }
    }

    var negative: String {
        switch self {
        case .longing: return "Not really"
        case .drift:   return "No, I've stayed steady"
        }
    }

    var analyticsName: String {
        switch self {
        case .longing: return "longing"
        case .drift:   return "drift"
        }
    }
}

private struct CloserAgreementScreen: View {
    let size: CGSize
    let question: CloserAgreementQuestion
    @Binding var answer: Bool?
    let onContinue: () -> Void
    @State private var v = false

    private var hasArt: Bool { question.art.assetName != nil }

    var body: some View {
        ZStack(alignment: .top) {
            if hasArt {
                CloserHero(art: question.art, height: size.height * 0.52, monochrome: true)
            }

            VStack(spacing: 0) {
                // See CloserSceneScreen: fixed offset under the art, centered
                // when there is no art to sit under.
                if hasArt {
                    Spacer().frame(height: size.height * 0.46)
                } else {
                    Spacer(minLength: CloserInsets.top + 32)
                }

                Text(question.question)
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 26)
                    .closerStagger(v, delay: 0.05)

                Spacer().frame(height: 28)

                VStack(spacing: 12) {
                    answerRow(label: question.affirmative, value: true)
                    answerRow(label: question.negative, value: false)
                }
                .padding(.horizontal, 24)
                .closerStagger(v, delay: 0.14)

                Spacer()

                CloserCTAButton(isEnabled: answer != nil) { onContinue() }
                    .padding(.bottom, CloserInsets.ctaBottom)
            }
        }
        .onAppear {
            AnalyticsService.shared.track("closer_agreement_shown", parameters: ["question": question.analyticsName])
            withAnimation { v = true }
        }
    }

    private func answerRow(label: String, value: Bool) -> some View {
        let isSelected = answer == value
        return Button(action: {
            Juice.play(.tapLight)
            answer = value
            AnalyticsService.shared.track("closer_agreement_answered", parameters: [
                "question": question.analyticsName,
                "answer": value ? "yes" : "no"
            ])
        }) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? DS.Palette.gold : Color.white.opacity(0.35), lineWidth: 1.5)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle().fill(DS.Palette.gold).frame(width: 12, height: 12)
                    }
                }
                Text(label)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.16) : Color.white.opacity(0.07))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(isSelected ? DS.Palette.gold.opacity(0.55) : Color.clear, lineWidth: 1)
                    )
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Growth proof screen

/// The compounding-closeness curve. Drawn natively rather than shipped as an
/// image so it stays crisp at every size class and the copy can change without
/// a new asset.
private struct CloserGrowthCurve: Shape {
    /// Normalized control points (x, y) with y measured from the bottom.
    private let points: [CGPoint] = [
        CGPoint(x: 0.00, y: 0.04),
        CGPoint(x: 0.14, y: 0.18),
        CGPoint(x: 0.28, y: 0.26),
        CGPoint(x: 0.42, y: 0.38),
        CGPoint(x: 0.56, y: 0.48),
        CGPoint(x: 0.70, y: 0.66),
        CGPoint(x: 0.85, y: 0.80),
        CGPoint(x: 1.00, y: 0.95)
    ]

    /// When true the path is closed to the baseline so it can be filled.
    var closed: Bool = false

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let mapped = points.map { p in
            CGPoint(x: rect.minX + p.x * rect.width,
                    y: rect.maxY - p.y * rect.height)
        }
        guard let first = mapped.first else { return path }
        path.move(to: first)
        // Smooth the polyline with midpoint quad curves so the rise reads as a
        // curve, not a chart of literal data.
        for i in 1..<mapped.count {
            let prev = mapped[i - 1]
            let curr = mapped[i]
            let mid = CGPoint(x: (prev.x + curr.x) / 2, y: (prev.y + curr.y) / 2)
            path.addQuadCurve(to: mid, control: prev)
        }
        if let last = mapped.last {
            path.addLine(to: last)
        }
        if closed, let last = mapped.last {
            path.addLine(to: CGPoint(x: last.x, y: rect.maxY))
            path.addLine(to: CGPoint(x: first.x, y: rect.maxY))
            path.closeSubpath()
        }
        return path
    }
}

private struct CloserGrowthScreen: View {
    let size: CGSize
    let onContinue: () -> Void
    @State private var v = false
    @State private var drawn: CGFloat = 0

    private let weekLabels = ["Day 1", "Day 5", "Day 10", "Day 20", "Day 30"]

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: size.height * 0.14)

            CloserHeadline(
                leading: "Speaking His Word daily is what ",
                highlight: "closes the distance",
                trailing: ".",
                size: 28
            )
            .padding(.horizontal, 26)
            .closerStagger(v, delay: 0.05)

            Spacer().frame(height: 28)

            chart
                .frame(height: size.height * 0.26)
                .padding(.horizontal, 26)
                .closerStagger(v, delay: 0.14)

            Spacer().frame(height: 18)

            Text("How close God feels")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .closerStagger(v, delay: 0.22)

            Spacer().frame(height: 10)

            Text("A verse read once fades by lunch. A promise spoken every day settles in, and thirty days of it changes what your heart believes about Him.")
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.62))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 30)
                .fixedSize(horizontal: false, vertical: true)
                .closerStagger(v, delay: 0.28)

            Spacer()

            CloserCTAButton { onContinue() }
                .padding(.bottom, CloserInsets.ctaBottom)
                .closerStagger(v, delay: 0.36)
        }
        .onAppear {
            AnalyticsService.shared.track("closer_growth_shown")
            withAnimation { v = true }
            withAnimation(.easeOut(duration: 1.1).delay(0.3)) { drawn = 1 }
        }
    }

    private var chart: some View {
        VStack(spacing: 10) {
            ZStack {
                // Gridlines
                VStack(spacing: 0) {
                    ForEach(0..<5, id: \.self) { _ in
                        Rectangle()
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 1)
                        Spacer()
                    }
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 1)
                }

                GeometryReader { geo in
                    ZStack(alignment: .bottomLeading) {
                        CloserGrowthCurve(closed: true)
                            .fill(
                                LinearGradient(
                                    colors: [DS.Palette.gold.opacity(0.42), .clear],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                            .opacity(Double(drawn))

                        CloserGrowthCurve()
                            .trim(from: 0, to: drawn)
                            .stroke(DS.Gradient.gold, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                        // Endpoint marker, revealed once the line arrives.
                        Circle()
                            .fill(DS.Palette.gold)
                            .frame(width: 12, height: 12)
                            .shadow(color: DS.Palette.gold.opacity(0.7), radius: 8)
                            .position(x: geo.size.width, y: geo.size.height * 0.05)
                            .opacity(drawn > 0.95 ? 1 : 0)
                            .animation(.easeIn(duration: 0.25), value: drawn)
                    }
                }
            }

            HStack {
                ForEach(weekLabels, id: \.self) { label in
                    Text(label)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.4))
                    if label != weekLabels.last { Spacer() }
                }
            }
        }
    }
}

// MARK: - Rhythm screen (reminders + streak)

private struct CloserRhythmScreen: View {
    let size: CGSize
    let onContinue: () -> Void
    @State private var v = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: size.height * 0.13)

            ZStack {
                // Warm bloom behind the mockups.
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [Color(hex: "#FF9D2E").opacity(0.22), .clear],
                            center: .center, startRadius: 0, endRadius: 210
                        )
                    )
                    .frame(height: 300)
                    .blur(radius: 22)

                VStack(spacing: 14) {
                    streakCard
                        .closerStagger(v, delay: 0.06)
                    notificationCard(
                        title: "Your declaration is ready",
                        message: "Speak it once out loud. It takes twenty seconds.",
                        stamp: "now"
                    )
                    .closerStagger(v, delay: 0.16)
                    notificationCard(
                        title: "Before the day gets loud",
                        message: "One promise, spoken over today. Tap to open.",
                        stamp: "2h ago"
                    )
                    .closerStagger(v, delay: 0.24)
                }
                .padding(.horizontal, 24)
            }

            Spacer().frame(height: 34)

            CloserHeadline(
                leading: "Reminders and streaks are what carry you ",
                highlight: "past the drift",
                trailing: ".",
                size: 26
            )
            .padding(.horizontal, 26)
            .closerStagger(v, delay: 0.32)

            Spacer().frame(height: 12)

            Text("Nobody drifts on purpose. A nudge at the right hour and a streak worth keeping is what turns a good intention into a daily habit.")
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.62))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 30)
                .fixedSize(horizontal: false, vertical: true)
                .closerStagger(v, delay: 0.38)

            Spacer()

            CloserCTAButton { onContinue() }
                .padding(.bottom, CloserInsets.ctaBottom)
                .closerStagger(v, delay: 0.44)
        }
        .onAppear {
            AnalyticsService.shared.track("closer_rhythm_shown")
            withAnimation { v = true }
        }
    }

    private var streakCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(DS.Gradient.ember)
                    .frame(width: 52, height: 52)
                Image(systemName: "flame.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("7-Day Streak")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("Seven days of speaking His Word")
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.09))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                )
        )
    }

    private func notificationCard(title: String, message: String, stamp: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(DS.Gradient.brand)
                .frame(width: 38, height: 38)
                .overlay(
                    Image(systemName: "quote.bubble.fill")
                        .font(.system(size: 17))
                        .foregroundColor(.white)
                )
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(title)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Spacer(minLength: 8)
                    Text(stamp)
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.4))
                }
                Text(message)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.11))
        )
    }
}

// MARK: - Closeness picker (seeds the feed)

// Each HeaviestBurden carries a nearness-framed label. Selecting one writes
// `responses.heaviestBurden`, which the shared back-half (preview declaration,
// notification subtitle) and the seeding logic already understand.
private struct CloserChoice {
    let statement: String
    let subtitle: String
    let symbol: String

    static func of(_ burden: HeaviestBurden) -> CloserChoice {
        switch burden {
        case .peace:
            return CloserChoice(statement: "My mind and my home",
                                subtitle: "Rest where the noise used to be",
                                symbol: "house.fill")
        case .health:
            return CloserChoice(statement: "My body",
                                subtitle: "Strength and healing, restored",
                                symbol: "heart.fill")
        case .abundance:
            return CloserChoice(statement: "My provision",
                                subtitle: "Doors opening, every need met",
                                symbol: "key.fill")
        case .identity:
            return CloserChoice(statement: "Who I am to Him",
                                subtitle: "Secure, chosen, fully His",
                                symbol: "crown.fill")
        case .purpose:
            return CloserChoice(statement: "My calling",
                                subtitle: "Walking in what He made me for",
                                symbol: "flag.fill")
        case .joy:
            return CloserChoice(statement: "My joy",
                                subtitle: "Gladness that holds all week",
                                symbol: "sun.max.fill")
        case .allOfIt:
            return CloserChoice(statement: "Everything at once",
                                subtitle: "I want all of Him, in every area",
                                symbol: "bolt.fill")
        }
    }
}

// Lead with the nearness-first areas; keep the same set the other arms seed from.
private let closerPickerOrder: [HeaviestBurden] = [
    .peace, .health, .abundance, .identity, .purpose, .joy, .allOfIt
]

private struct CloserPickerScreen: View {
    let size: CGSize
    @ObservedObject var responses: SurveyResponses
    let onContinue: () -> Void
    @State private var v = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    // Clear the progress bar by a fixed amount rather than a
                    // percentage of height — 11% of a tall phone left only ~20pt
                    // of air under the bar.
                    Spacer().frame(height: CloserInsets.top + 46)

                    VStack(spacing: 12) {
                        CloserHeadline(
                            leading: "Where do you most want to feel Him ",
                            highlight: "move first",
                            trailing: "?",
                            size: 26
                        )
                        .padding(.horizontal, 24)
                        .closerStagger(v)

                        Text("We'll build your daily declarations around it\nand start there tomorrow morning.")
                            .font(.system(size: 15, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.62))
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                            .closerStagger(v, delay: 0.1)
                    }

                    VStack(spacing: 10) {
                        ForEach(closerPickerOrder) { burden in
                            closerRow(burden)
                        }
                    }
                    .padding(.horizontal, 20)
                    .closerStagger(v, delay: 0.2)

                    Spacer().frame(height: 20)
                }
            }

            CloserCTAButton(isEnabled: responses.heaviestBurden != nil, action: onContinue)
                .padding(.top, 8)
                .padding(.bottom, CloserInsets.ctaBottom)
        }
        .onAppear {
            AnalyticsService.shared.track("closer_picker_shown")
            withAnimation { v = true }
        }
    }

    private func closerRow(_ burden: HeaviestBurden) -> some View {
        let choice = CloserChoice.of(burden)
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

// MARK: - Pledge screen ("I'm In")

/// The commitment beat, unique to this arm. It lands after the plan reveal and
/// before the social-proof wall, so the user has said an explicit yes to the
/// next thirty days immediately before the paywall asks them to pay for it.
private struct CloserPledgeScreen: View {
    let size: CGSize
    let burden: HeaviestBurden
    let onContinue: () -> Void
    @State private var v = false

    private var hasArt: Bool { CloserArt.pledge.assetName != nil }

    private let commitments: [String] = [
        "Declarations written for what you're carrying",
        "Bible Chat when you need an answer tonight",
        "Audio to speak over the drive, the gym, the dark",
        "Your own declaration, in your own words",
        "Reminders that keep you from drifting again"
    ]

    var body: some View {
        ZStack(alignment: .top) {
            if hasArt {
                CloserHero(art: .pledge, height: size.height * 0.34)
            }

            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Reserve the hero band only when there is a hero.
                        Spacer().frame(height: hasArt ? size.height * 0.27 : CloserInsets.top + 28)

                        CloserHeadline(
                            leading: "Get closer to God, ",
                            highlight: "starting today",
                            trailing: ".",
                            size: 30
                        )
                        .padding(.horizontal, 26)
                        .closerStagger(v, delay: 0.05)

                        Spacer().frame(height: 16)

                        Text("The next thirty days, you speak His Word over \(burden.pledgePhrase) instead of hoping something changes. Here's what walks with you:")
                            .font(.system(size: 15, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.66))
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                            .padding(.horizontal, 28)
                            .fixedSize(horizontal: false, vertical: true)
                            .closerStagger(v, delay: 0.12)

                        Spacer().frame(height: 22)

                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(Array(commitments.enumerated()), id: \.offset) { _, line in
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(DS.Palette.gold)
                                        .frame(width: 18)
                                    Text(line)
                                        .font(.system(size: 16, weight: .regular, design: .rounded))
                                        .foregroundColor(.white.opacity(0.92))
                                        .fixedSize(horizontal: false, vertical: true)
                                    Spacer(minLength: 0)
                                }
                            }
                        }
                        .padding(.horizontal, 30)
                        .closerStagger(v, delay: 0.2)

                        Spacer().frame(height: 24)

                        CloserVerseCard(
                            verse: "Come near to God and he will come near to you.",
                            reference: "James 4:8"
                        )
                        .padding(.horizontal, 26)
                        .closerStagger(v, delay: 0.28)

                        Spacer().frame(height: 24)
                    }
                }

                // Pinned OUTSIDE the scroll view, the way every other screen in
                // this arm does it. Inside, the content ran just long enough to
                // push it under the fold, so the arm's commitment beat needed a
                // scroll before it could be tapped.
                CloserCTAButton(label: "I'm In") {
                    AnalyticsService.shared.track("closer_pledge_accepted", parameters: [
                        "burden": burden.rawValue
                    ])
                    onContinue()
                }
                .padding(.top, 8)
                .padding(.bottom, CloserInsets.ctaBottom)
                .closerStagger(v, delay: 0.34)
            }
        }
        .onAppear {
            AnalyticsService.shared.track("closer_pledge_shown", parameters: ["burden": burden.rawValue])
            withAnimation { v = true }
        }
    }
}

private extension HeaviestBurden {
    /// Sentence-fragment form used in the pledge copy ("...speak His Word over
    /// your body instead of hoping something changes").
    var pledgePhrase: String {
        switch self {
        case .peace:     return "your mind and your home"
        case .health:    return "your body"
        case .abundance: return "your provision"
        case .identity:  return "who God says you are"
        case .purpose:   return "your calling"
        case .joy:       return "your joy"
        case .allOfIt:   return "every area of your life"
        }
    }
}
