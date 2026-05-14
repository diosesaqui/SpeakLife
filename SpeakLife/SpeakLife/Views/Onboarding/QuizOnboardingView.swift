//
//  QuizOnboardingView.swift
//  SpeakLife
//
//  Personalized 5-screen onboarding (Treatment cohort of the install→trial A/B).
//  Gated by Remote Config flag `useQuizOnboarding`. Routes the user from one of
//  4 felt-need ad campaigns into matching mirror copy, declaration, trial pitch,
//  and paywall framing — see DEV_TICKET_Onboarding_Quiz.md.
//

import SwiftUI
import FirebaseAnalytics
import UserNotifications
import UIKit

// MARK: - QuizSegment

enum QuizSegment: String, CaseIterable {
    case battlefieldMind   = "battlefield_mind"
    case believerAuthority = "believer_authority"
    case alreadyYours      = "already_yours"
    case hisHeart          = "his_heart"
    case unsegmented       = "unsegmented"

    // The quiz answer button (Screen 1)
    var buttonHeadline: String {
        switch self {
        case .battlefieldMind:   return "My thoughts are out of control."
        case .believerAuthority: return "I've prayed for years and nothing's moved."
        case .alreadyYours:      return "I keep begging for what God already gave me."
        case .hisHeart:          return "I need to feel His love again."
        case .unsegmented:       return "Just exploring — show me everything."
        }
    }

    var buttonSubhead: String {
        switch self {
        case .battlefieldMind:   return "Anxiety, fear, 3am wake-ups."
        case .believerAuthority: return ""
        case .alreadyYours:      return ""
        case .hisHeart:          return ""
        case .unsegmented:       return ""
        }
    }

    // Screen 2 mirror message
    var mirrorHeadline: String {
        switch self {
        case .battlefieldMind:   return "You're in a battle for your mind."
        case .believerAuthority: return "Long prayers aren't the answer. Authority is."
        case .alreadyYours:      return "You've been working for what's already yours."
        case .hisHeart:          return "He's not far. He's been waiting."
        case .unsegmented:       return "Welcome to SpeakLife."
        }
    }

    var mirrorBody: String {
        switch self {
        case .battlefieldMind:   return "You're not alone, and you're not powerless. There's a Scripture written for this exact storm."
        case .believerAuthority: return "Jesus didn't beg the storm. He spoke to it. So can you."
        case .alreadyYours:      return "It's time to stop begging and start agreeing."
        case .hisHeart:          return "Let's put His love in your mouth daily."
        case .unsegmented:       return "Speak the truth. Win the day."
        }
    }

    // Screen 3 declaration
    var declarationText: String {
        switch self {
        case .battlefieldMind:
            return "I take every thought captive to the obedience of Christ. No fear, no lie, no anxiety has authority over my mind."
        case .believerAuthority:
            return "Whatsoever I say to this mountain, believing, shall come to pass. I speak with authority, not in begging."
        case .alreadyYours:
            return "His divine power has GIVEN unto me all things that pertain unto life and godliness. I receive what's already mine."
        case .hisHeart:
            return "As the Father has loved me, so have I loved you. I am deeply, specifically, eternally loved."
        case .unsegmented:
            return "I am more than a conqueror through Christ who loves me. I take more ground today than I took yesterday."
        }
    }

    var declarationVerse: String {
        switch self {
        case .battlefieldMind:   return "2 Corinthians 10:5"
        case .believerAuthority: return "Mark 11:23"
        case .alreadyYours:      return "2 Peter 1:3"
        case .hisHeart:          return "John 15:9"
        case .unsegmented:       return "Romans 8:37"
        }
    }

    // Screen 5 paywall framing
    var paywallHeadline: String {
        switch self {
        case .battlefieldMind:   return "Take every thought captive."
        case .believerAuthority: return "Stop begging. Start agreeing."
        case .alreadyYours:      return "Claim what's already yours."
        case .hisHeart:          return "Hear Him speak love over you."
        case .unsegmented:       return "Speak life today."
        }
    }

    var paywallSubheadline: String {
        switch self {
        case .battlefieldMind:   return "Start your 3-day free trial. Speak truth before the next 3am wake-up."
        case .believerAuthority: return "Start your 3-day free trial. Speak God's Word with authority."
        case .alreadyYours:      return "Start your 3-day free trial. Stop earning what He's already given."
        case .hisHeart:          return "Start your 3-day free trial. Receive His love every morning."
        case .unsegmented:       return "Start your 3-day free trial. 500,000+ believers do this daily."
        }
    }

    // Default declaration category seeded into the user's home screen + push mix
    var primaryCategory: DeclarationCategory {
        switch self {
        case .battlefieldMind:   return .anxiety
        case .believerAuthority: return .confidence
        case .alreadyYours:      return .wealth
        case .hisHeart:          return .godsheart
        case .unsegmented:       return .destiny
        }
    }

    var notificationCategories: Set<DeclarationCategory> {
        switch self {
        case .battlefieldMind:   return [.anxiety, .rest, .identity, .fear]
        case .believerAuthority: return [.faith, .confidence, .destiny, .praise]
        case .alreadyYours:      return [.wealth, .health, .grace, .favor]
        case .hisHeart:          return [.godsheart, .love, .identity, .grace]
        case .unsegmented:       return [.destiny, .faith, .identity, .grace, .joy, .rest]
        }
    }
}

// MARK: - QuizOnboardingView

struct QuizOnboardingView: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var declarationStore: DeclarationViewModel
    let size: CGSize
    let onComplete: () -> Void

    static let quizVersion = "v1"

    enum Step: Int, CaseIterable {
        case quiz, mirror, declaration, trialPitch, paywall
    }

    @State private var currentStep: Step = .quiz
    @State private var selectedSegment: QuizSegment? = nil
    @State private var quizShownAt: Date = Date()
    @State private var stepEnteredAt: Date = Date()

    private var segment: QuizSegment { selectedSegment ?? .unsegmented }

    var body: some View {
        ZStack {
            backgroundView

            Group {
                switch currentStep {
                case .quiz:
                    QuizQuestionScreen(size: size) { picked in
                        handleAnswer(picked)
                    }
                case .mirror:
                    QuizMirrorScreen(size: size, segment: segment) {
                        advanceFromMirror()
                    }
                case .declaration:
                    QuizDeclarationScreen(size: size, segment: segment) {
                        advanceFromDeclaration()
                    }
                case .trialPitch:
                    QuizTrialPitchScreen(size: size, segment: segment) {
                        advanceFromTrialPitch()
                    }
                case .paywall:
                    HighConversionPaywallView(callback: {
                        finishOnboarding()
                    }, source: "onboarding")
                }
            }
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .offset(x: 0, y: 24)),
                removal: .opacity.combined(with: .offset(x: 0, y: -16))
            ))
            .id(currentStep.rawValue)
        }
        .ignoresSafeArea()
        .onAppear {
            quizShownAt = Date()
            stepEnteredAt = Date()
            Analytics.logEvent("onboarding_quiz_shown", parameters: [
                "quiz_version": Self.quizVersion
            ])
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
                    Color.black.opacity(0.82),
                    Color.black.opacity(0.55),
                    Color.black.opacity(0.72)
                ]),
                startPoint: .top, endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }

    // MARK: - Step transitions

    private func handleAnswer(_ picked: QuizSegment) {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        selectedSegment = picked
        appState.onboardingSegment = picked.rawValue
        appState.onboardingQuizVersion = Self.quizVersion

        let timeToAnswer = Int(Date().timeIntervalSince(quizShownAt))
        Analytics.logEvent("onboarding_quiz_answered", parameters: [
            "quiz_version": Self.quizVersion,
            "answer": picked.rawValue,
            "time_to_answer_seconds": timeToAnswer
        ])

        // Per ticket: "Just exploring" skips the mirror screen.
        let nextStep: Step = (picked == .unsegmented) ? .declaration : .mirror
        transition(to: nextStep)

        if nextStep == .mirror {
            Analytics.logEvent("onboarding_mirror_shown", parameters: [
                "segment": picked.rawValue
            ])
        } else {
            fireDeclarationShown(for: picked)
        }
    }

    private func advanceFromMirror() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        transition(to: .declaration)
        fireDeclarationShown(for: segment)
    }

    private func advanceFromDeclaration() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        let timeOnScreen = Int(Date().timeIntervalSince(stepEnteredAt))
        Analytics.logEvent("onboarding_first_declaration_spoken", parameters: [
            "segment": segment.rawValue,
            "declaration_id": segment.declarationVerse,
            "time_on_screen_seconds": timeOnScreen
        ])
        transition(to: .trialPitch)
        Analytics.logEvent("onboarding_trial_pitch_shown", parameters: [
            "segment": segment.rawValue
        ])
    }

    private func advanceFromTrialPitch() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        // Apply segment defaults BEFORE the paywall renders so HighConversionPaywallView
        // (and analytics events fired from it) see the chosen segment.
        applySegmentDefaults()
        let totalDuration = Int(Date().timeIntervalSince(quizShownAt))
        Analytics.logEvent("onboarding_completed", parameters: [
            "segment": segment.rawValue,
            "total_duration_seconds": totalDuration
        ])
        transition(to: .paywall)
    }

    private func finishOnboarding() {
        // Request notification permission as the final step so the user lands with
        // push enabled and segment-matched content already scheduled — mirrors
        // SurveyOnboardingView's request-then-complete pattern.
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            Analytics.logEvent("notification_permission", parameters: [
                "granted": granted,
                "source": "quiz_onboarding"
            ])
            DispatchQueue.main.async {
                appState.notificationEnabled = granted
                if granted {
                    UIApplication.shared.registerForRemoteNotifications()
                    NotificationManager.shared.registerNotifications(
                        count: appState.notificationCount,
                        startTime: appState.startTimeIndex,
                        endTime: appState.endTimeIndex,
                        categories: segment.notificationCategories
                    )
                    appState.lastNotificationSetDate = Date()
                }
                onComplete()
            }
        }
    }

    private func transition(to step: Step) {
        withAnimation(.easeInOut(duration: 0.35)) {
            currentStep = step
        }
        stepEnteredAt = Date()
    }

    private func fireDeclarationShown(for segment: QuizSegment) {
        Analytics.logEvent("onboarding_first_declaration_shown", parameters: [
            "segment": segment.rawValue,
            "declaration_id": segment.declarationVerse
        ])
    }

    private func applySegmentDefaults() {
        appState.onboardingCompletedAt = Date()

        // Seed home screen + Daily Burst defaults so the first session shows
        // segment-matched content. After ~7-14 days normal usage-driven
        // personalization takes over (DeclarationViewModel.choose, etc.).
        let category = segment.primaryCategory
        UserDefaults.standard.set(category.rawValue, forKey: "selectedCategory")
        UserPreferencesTracker.shared.trackCategorySelection(category.rawValue)
        declarationStore.choose(category) { _ in }

        // Persist the notification category mix for SpeakLifeApp.resetNotifications
        // to schedule segment-aligned pushes instead of the generic default.
        appState.selectedNotificationCategories = segment.notificationCategories
            .map { $0.rawValue }
            .joined(separator: ",")
    }
}

// MARK: - Screen 1: Quiz

private struct QuizQuestionScreen: View {
    let size: CGSize
    let onSelect: (QuizSegment) -> Void

    private let primaryAnswers: [QuizSegment] = [
        .battlefieldMind, .believerAuthority, .alreadyYours, .hisHeart
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: size.height * 0.10)

            VStack(spacing: 12) {
                Text("Welcome.")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("Before we start, what brought you here today?")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                Text("Pick the one that hits closest. We'll match Scripture to your storm.")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer().frame(height: 28)

            VStack(spacing: 12) {
                ForEach(primaryAnswers, id: \.self) { segment in
                    AnswerButton(segment: segment, isPrimary: true) {
                        onSelect(segment)
                    }
                }
            }
            .padding(.horizontal, 24)

            Spacer().frame(height: 20)

            AnswerButton(segment: .unsegmented, isPrimary: false) {
                onSelect(.unsegmented)
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    private struct AnswerButton: View {
        let segment: QuizSegment
        let isPrimary: Bool
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(segment.buttonHeadline)
                        .font(.system(size: isPrimary ? 16 : 14, weight: isPrimary ? .semibold : .regular))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                    if !segment.buttonSubhead.isEmpty {
                        Text(segment.buttonSubhead)
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.leading)
                    }
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 18)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(isPrimary ? Color.white.opacity(0.12) : Color.white.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.white.opacity(isPrimary ? 0.25 : 0.12), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel(Text(segment.buttonHeadline))
            .accessibilityHint(Text(segment.buttonSubhead.isEmpty ? "Select this answer" : segment.buttonSubhead))
        }
    }
}

// MARK: - Screen 2: Mirror

private struct QuizMirrorScreen: View {
    let size: CGSize
    let segment: QuizSegment
    let onAdvance: () -> Void

    @State private var autoAdvanceTask: DispatchWorkItem? = nil

    var body: some View {
        VStack {
            Spacer()
            VStack(spacing: 18) {
                Text(segment.mirrorHeadline)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                Text(segment.mirrorBody)
                    .font(.system(size: 17))
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            Spacer()
            Text("Tap to continue")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
                .padding(.bottom, size.height * 0.08)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            triggerAdvance()
        }
        .onAppear {
            let task = DispatchWorkItem { triggerAdvance() }
            autoAdvanceTask = task
            DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: task)
        }
        .onDisappear {
            autoAdvanceTask?.cancel()
        }
    }

    private func triggerAdvance() {
        guard autoAdvanceTask?.isCancelled == false else { return }
        autoAdvanceTask?.cancel()
        onAdvance()
    }
}

// MARK: - Screen 3: Matched declaration

private struct QuizDeclarationScreen: View {
    let size: CGSize
    let segment: QuizSegment
    let onSpoken: () -> Void

    @State private var isPressed = false

    var body: some View {
        VStack {
            Spacer()
            VStack(spacing: 24) {
                Text("\u{201C}\(segment.declarationText)\u{201D}")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                Text(segment.declarationVerse)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.65))
            }
            Spacer()
            Button(action: {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                    isPressed = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    onSpoken()
                }
            }) {
                Text("Speak this out loud.")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 28)
                            .fill(LinearGradient(
                                colors: [Constants.DAMidBlue, Constants.DAMidBlue.opacity(0.85)],
                                startPoint: .leading, endPoint: .trailing
                            ))
                    )
                    .scaleEffect(isPressed ? 1.04 : 1.0)
                    .shadow(color: Constants.DAMidBlue.opacity(0.4),
                            radius: isPressed ? 16 : 8, x: 0, y: 4)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 24)
            .padding(.bottom, size.height * 0.08)
            .accessibilityLabel(Text("Speak this declaration out loud."))
        }
    }
}

// MARK: - Screen 4: Trial pitch

private struct QuizTrialPitchScreen: View {
    let size: CGSize
    let segment: QuizSegment
    let onAdvance: () -> Void

    var body: some View {
        VStack {
            Spacer().frame(height: size.height * 0.12)
            VStack(spacing: 14) {
                Text("Speak this once.")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                Text("Tomorrow we'll give you the next one.")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                Text("Three minutes a day. Built on Joshua 1:8.")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.top, 6)
            }
            .padding(.horizontal, 28)

            Spacer().frame(height: 28)

            DailyBurstPreviewCard()
                .padding(.horizontal, 28)

            Spacer()

            Button(action: onAdvance) {
                Text("Start your 3-day free trial.")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 28)
                            .fill(LinearGradient(
                                colors: [Constants.DAMidBlue, Constants.DAMidBlue.opacity(0.85)],
                                startPoint: .leading, endPoint: .trailing
                            ))
                    )
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 24)
            .accessibilityLabel(Text("Start your three-day free trial."))

            Button(action: onAdvance) {
                Text("Already have an account? Sign in.")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.55))
                    .underline()
            }
            .padding(.top, 12)
            .padding(.bottom, size.height * 0.05)
        }
    }

    private struct DailyBurstPreviewCard: View {
        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.orange)
                    Text("Day 1 of \u{221E}")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    Text("3 min")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.55))
                }
                Text("Your Daily Burst")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                Text("Speak. Hear. Believe. Repeat.")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
            )
        }
    }
}
