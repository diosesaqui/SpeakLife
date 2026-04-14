//
//  SurveyOnboardingScreens.swift
//  SpeakLife
//
//  All individual screens for the survey onboarding flow.
//  Every question screen follows the same structural pattern:
//    - Headline (the question)
//    - Answer options (selectable rows or tiles)
//    - Continue button (enabled once an answer is selected)
//
//  Interstitial screens are non-question trust/insight moments that
//  validate the user and introduce the solution concept.
//

import SwiftUI
import FirebaseAnalytics

// MARK: - Shared Components

/// Standard selectable row for single-choice questions
private struct SurveyOptionRow: View {
    let text: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? Color.white : Color.white.opacity(0.35), lineWidth: 1.5)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 12, height: 12)
                    }
                }
                Text(text)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .regular, design: .rounded))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.8))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
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

/// Multi-select checkbox row
private struct SurveyCheckRow: View {
    let text: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(isSelected ? Color.white : Color.white.opacity(0.35), lineWidth: 1.5)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                Text(text)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .regular, design: .rounded))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.8))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
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

/// Standard continue button used across all screens
private struct SurveyContinueButton: View {
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

/// Reusable question headline block
private struct SurveyQuestionHeader: View {
    let question: String
    let subtitle: String?

    init(_ question: String, subtitle: String? = nil) {
        self.question = question
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(spacing: 8) {
            Text(question)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let sub = subtitle {
                Text(sub)
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 28)
    }
}

// MARK: - SCREEN 0: Intro

struct SurveyIntroScreen: View {
    let size: CGSize
    let onContinue: () -> Void

    @State private var headlineVisible = false
    @State private var subVisible = false
    @State private var buttonVisible = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 28) {
                VStack(spacing: 12) {
                    Text("Before we build your experience —")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .opacity(headlineVisible ? 1 : 0)
                        .offset(y: headlineVisible ? 0 : 16)
                        .animation(.easeOut(duration: 0.6), value: headlineVisible)

                    Text("we need to understand\nwhat you're carrying.")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .opacity(headlineVisible ? 1 : 0)
                        .offset(y: headlineVisible ? 0 : 16)
                        .animation(.easeOut(duration: 0.6).delay(0.1), value: headlineVisible)
                }

                Text("9 questions. Your answers shape your declarations, your devotionals, and your first breakthrough.")
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
                    .opacity(subVisible ? 1 : 0)
                    .offset(y: subVisible ? 0 : 12)
                    .animation(.easeOut(duration: 0.5), value: subVisible)
            }

            Spacer()

            SurveyContinueButton(label: "Let's Begin") { onContinue() }
                .padding(.bottom, 52)
                .opacity(buttonVisible ? 1 : 0)
                .offset(y: buttonVisible ? 0 : 20)
                .animation(.easeOut(duration: 0.5), value: buttonVisible)
        }
        .onAppear {
            withAnimation { headlineVisible = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation { subVisible = true }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation { buttonVisible = true }
            }
            Analytics.logEvent("survey_intro_shown", parameters: nil)
        }
    }
}

// MARK: - SCREEN 1: What feels heaviest?

struct SurveyQ1BurdenScreen: View {
    let size: CGSize
    @ObservedObject var responses: SurveyResponses
    let onContinue: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                Spacer().frame(height: size.height * 0.12)

                SurveyQuestionHeader(
                    "Right now, what feels the heaviest?",
                    subtitle: "Be honest. This is just between you and God."
                )

                VStack(spacing: 10) {
                    ForEach(HeaviestBurden.allCases) { option in
                        SurveyOptionRow(
                            text: option.rawValue,
                            isSelected: responses.heaviestBurden == option
                        ) {
                            responses.heaviestBurden = option
                        }
                    }
                }
                .padding(.horizontal, 20)

                SurveyContinueButton(
                    isEnabled: responses.heaviestBurden != nil,
                    action: onContinue
                )
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            Analytics.logEvent("survey_q1_shown", parameters: nil)
        }
    }
}

// MARK: - SCREEN 2: How long?

struct SurveyQ2DurationScreen: View {
    let size: CGSize
    @ObservedObject var responses: SurveyResponses
    let onContinue: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                Spacer().frame(height: size.height * 0.12)

                SurveyQuestionHeader(
                    "How long have you been carrying this?",
                    subtitle: nil
                )

                // Positive reinforcement tied to the previous answer
                if responses.heaviestBurden != nil {
                    Text("Thank you for being honest. That took courage.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                VStack(spacing: 10) {
                    ForEach(BurdenDuration.allCases) { option in
                        SurveyOptionRow(
                            text: option.rawValue,
                            isSelected: responses.burdenDuration == option
                        ) {
                            responses.burdenDuration = option
                        }
                    }
                }
                .padding(.horizontal, 20)

                SurveyContinueButton(
                    isEnabled: responses.burdenDuration != nil,
                    action: onContinue
                )
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            Analytics.logEvent("survey_q2_shown", parameters: nil)
        }
    }
}

// MARK: - INTERSTITIAL A: You're not alone

struct SurveyInterstitialAScreen: View {
    let size: CGSize
    let onContinue: () -> Void

    @State private var contentVisible = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 32) {
                VStack(spacing: 14) {
                    Text("You're not carrying this alone.")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .opacity(contentVisible ? 1 : 0)
                        .offset(y: contentVisible ? 0 : 20)

                    Text("Over 100,000 women have opened SpeakLife carrying the same weight you just described.\n\nThe feelings are real. So is the way out.")
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .opacity(contentVisible ? 1 : 0)
                        .offset(y: contentVisible ? 0 : 16)
                        .animation(.easeOut(duration: 0.5).delay(0.15), value: contentVisible)
                }

                // Testimonial card
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 2) {
                        ForEach(0..<5, id: \.self) { _ in
                            Image(systemName: "star.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.yellow)
                        }
                    }
                    Text("\"I've had anxiety for 12 years. After 3 weeks of daily declarations, my mornings changed. I finally feel like myself.\"")
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))
                        .italic()
                        .fixedSize(horizontal: false, vertical: true)

                    Text("— Sarah M., Texas")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 28)
                .opacity(contentVisible ? 1 : 0)
                .offset(y: contentVisible ? 0 : 12)
                .animation(.easeOut(duration: 0.5).delay(0.3), value: contentVisible)
            }

            Spacer()

            SurveyContinueButton(label: "Keep Going") { onContinue() }
                .padding(.bottom, 52)
                .opacity(contentVisible ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.5), value: contentVisible)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) { contentVisible = true }
            Analytics.logEvent("survey_interstitial_a_shown", parameters: nil)
        }
    }
}

// MARK: - SCREEN 3: Failed attempts (multi-select)

struct SurveyQ3AttemptsScreen: View {
    let size: CGSize
    @ObservedObject var responses: SurveyResponses
    let onContinue: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                Spacer().frame(height: size.height * 0.12)

                SurveyQuestionHeader(
                    "Have you tried to fight through this before?",
                    subtitle: "Select all that apply."
                )

                VStack(spacing: 10) {
                    ForEach(PreviousAttempt.allCases) { option in
                        SurveyCheckRow(
                            text: option.rawValue,
                            isSelected: responses.previousAttempts.contains(option)
                        ) {
                            if responses.previousAttempts.contains(option) {
                                responses.previousAttempts.remove(option)
                            } else {
                                responses.previousAttempts.insert(option)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)

                SurveyContinueButton(
                    isEnabled: !responses.previousAttempts.isEmpty,
                    action: onContinue
                )
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            Analytics.logEvent("survey_q3_shown", parameters: nil)
        }
    }
}

// MARK: - SCREEN 4: The inner lie

struct SurveyQ4LieScreen: View {
    let size: CGSize
    @ObservedObject var responses: SurveyResponses
    let onContinue: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                Spacer().frame(height: size.height * 0.12)

                SurveyQuestionHeader(
                    "When you're at your lowest — what's going through your mind?",
                    subtitle: "Pick the one that hits closest to home."
                )

                VStack(spacing: 10) {
                    ForEach(InnerLie.allCases) { option in
                        SurveyOptionRow(
                            text: option.rawValue,
                            isSelected: responses.innerLie == option
                        ) {
                            responses.innerLie = option
                        }
                    }
                }
                .padding(.horizontal, 20)

                SurveyContinueButton(
                    isEnabled: responses.innerLie != nil,
                    action: onContinue
                )
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            Analytics.logEvent("survey_q4_shown", parameters: nil)
        }
    }
}

// MARK: - INTERSTITIAL B: The Pivot — solution concept

struct SurveyInterstitialBScreen: View {
    let size: CGSize
    let onContinue: () -> Void

    @State private var contentVisible = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 28) {
                VStack(spacing: 14) {
                    Text("Here's what 100,000 people have discovered.")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                        .opacity(contentVisible ? 1 : 0)
                        .offset(y: contentVisible ? 0 : 20)

                    Text("Every thought you just named?\nIt didn't come from God.")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                        .opacity(contentVisible ? 1 : 0)
                        .offset(y: contentVisible ? 0 : 16)
                        .animation(.easeOut(duration: 0.5).delay(0.1), value: contentVisible)

                    Text("Most people fight these thoughts with willpower — or silence. But the people who actually break free?\n\nThey learn to speak differently.")
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .opacity(contentVisible ? 1 : 0)
                        .offset(y: contentVisible ? 0 : 12)
                        .animation(.easeOut(duration: 0.5).delay(0.2), value: contentVisible)
                }

                // Scripture anchor
                VStack(spacing: 6) {
                    Text("\"Death and life are in the power of the tongue.\"")
                        .font(.system(size: 16, weight: .semibold, design: .serif))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .italic()
                        .padding(.horizontal, 32)

                    Text("Proverbs 18:21")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.45))
                }
                .opacity(contentVisible ? 1 : 0)
                .animation(.easeOut(duration: 0.5).delay(0.35), value: contentVisible)
            }

            Spacer()

            SurveyContinueButton(label: "I Want That") { onContinue() }
                .padding(.bottom, 52)
                .opacity(contentVisible ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.5), value: contentVisible)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) { contentVisible = true }
            Analytics.logEvent("survey_interstitial_b_shown", parameters: nil)
        }
    }
}

// MARK: - SCREEN 5: Declaration experience

struct SurveyQ5DeclarationExpScreen: View {
    let size: CGSize
    @ObservedObject var responses: SurveyResponses
    let onContinue: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                Spacer().frame(height: size.height * 0.12)

                SurveyQuestionHeader(
                    "Have you ever spoken God's Word out loud over your life — and felt something shift?",
                    subtitle: nil
                )

                VStack(spacing: 10) {
                    ForEach(DeclarationExperience.allCases) { option in
                        SurveyOptionRow(
                            text: option.rawValue,
                            isSelected: responses.declarationExperience == option
                        ) {
                            responses.declarationExperience = option
                        }
                    }
                }
                .padding(.horizontal, 20)

                SurveyContinueButton(
                    isEnabled: responses.declarationExperience != nil,
                    action: onContinue
                )
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            Analytics.logEvent("survey_q5_shown", parameters: nil)
        }
    }
}

// MARK: - SCREEN 6: Future pacing (multi-select, max 2)

struct SurveyQ6FutureScreen: View {
    let size: CGSize
    @ObservedObject var responses: SurveyResponses
    let onContinue: () -> Void

    private var burdenLabel: String {
        responses.burdenShortLabel
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                Spacer().frame(height: size.height * 0.12)

                SurveyQuestionHeader(
                    "Imagine waking up free from \(burdenLabel). What changes?",
                    subtitle: "Choose up to 2."
                )

                VStack(spacing: 10) {
                    ForEach(FutureChange.allCases) { option in
                        let isSelected = responses.futureChanges.contains(option)
                        SurveyCheckRow(
                            text: option.rawValue,
                            isSelected: isSelected
                        ) {
                            if isSelected {
                                responses.futureChanges.remove(option)
                            } else if responses.futureChanges.count < 2 {
                                responses.futureChanges.insert(option)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)

                SurveyContinueButton(
                    isEnabled: !responses.futureChanges.isEmpty,
                    action: onContinue
                )
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            Analytics.logEvent("survey_q6_shown", parameters: nil)
        }
    }
}

// MARK: - SCREEN 7: Readiness

struct SurveyQ7ReadinessScreen: View {
    let size: CGSize
    @ObservedObject var responses: SurveyResponses
    let onContinue: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                Spacer().frame(height: size.height * 0.12)

                SurveyQuestionHeader(
                    "How serious are you about making a change — starting today?",
                    subtitle: nil
                )

                VStack(spacing: 10) {
                    ForEach(ReadinessLevel.allCases) { option in
                        SurveyOptionRow(
                            text: option.rawValue,
                            isSelected: responses.readinessLevel == option
                        ) {
                            responses.readinessLevel = option
                        }
                    }
                }
                .padding(.horizontal, 20)

                SurveyContinueButton(
                    isEnabled: responses.readinessLevel != nil,
                    action: onContinue
                )
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            Analytics.logEvent("survey_q7_shown", parameters: nil)
        }
    }
}

// MARK: - SCREEN 8: Notification time

struct SurveyQ8NotificationScreen: View {
    let size: CGSize
    @ObservedObject var responses: SurveyResponses
    let onContinue: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                Spacer().frame(height: size.height * 0.12)

                SurveyQuestionHeader(
                    "The people who break through don't skip days.",
                    subtitle: "When do you need us standing with you?"
                )

                VStack(spacing: 10) {
                    ForEach(NotificationTime.allCases) { option in
                        SurveyOptionRow(
                            text: option.rawValue,
                            isSelected: responses.notificationTime == option
                        ) {
                            responses.notificationTime = option
                        }
                    }
                }
                .padding(.horizontal, 20)

                SurveyContinueButton(
                    isEnabled: responses.notificationTime != nil,
                    action: onContinue
                )
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            Analytics.logEvent("survey_q8_shown", parameters: nil)
        }
    }
}

// MARK: - SCREEN 9: Goal Word

struct SurveyQ9GoalWordScreen: View {
    let size: CGSize
    @ObservedObject var responses: SurveyResponses
    let onContinue: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {
                Spacer().frame(height: size.height * 0.12)

                SurveyQuestionHeader(
                    "One last thing.",
                    subtitle: "Choose the word you're believing God for:"
                )

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(SurveyGoalWord.allCases) { word in
                        let isSelected = responses.goalWord == word
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            responses.goalWord = word
                        } label: {
                            VStack(spacing: 10) {
                                Image(systemName: word.icon)
                                    .font(.system(size: 24))
                                    .foregroundColor(isSelected ? .white : .white.opacity(0.6))

                                Text(word.rawValue)
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)

                                Text(word.tagline)
                                    .font(.system(size: 11, weight: .regular, design: .rounded))
                                    .foregroundColor(.white.opacity(0.6))
                                    .multilineTextAlignment(.center)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.vertical, 18)
                            .padding(.horizontal, 12)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(isSelected ? Color.white.opacity(0.18) : Color.white.opacity(0.06))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .strokeBorder(isSelected ? Color.white.opacity(0.6) : Color.white.opacity(0.12), lineWidth: 1.5)
                                    )
                            )
                            .scaleEffect(isSelected ? 1.03 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 20)

                SurveyContinueButton(
                    label: "This Is My Goal",
                    isEnabled: responses.goalWord != nil,
                    action: onContinue
                )
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            // Pre-select derived goal word if user hasn't tapped yet
            if responses.goalWord == nil {
                responses.goalWord = responses.heaviestBurden?.goalWord
            }
            Analytics.logEvent("survey_q9_shown", parameters: nil)
        }
    }
}

// MARK: - GOAL REVEAL SCREEN

struct SurveyGoalRevealScreen: View {
    let size: CGSize
    @ObservedObject var responses: SurveyResponses
    let onContinue: () -> Void

    @State private var contentVisible = false
    @State private var challengeVisible = false

    private var goalWord: SurveyGoalWord { responses.resolvedGoalWord }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 28) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 72, height: 72)
                    Image(systemName: goalWord.icon)
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                }
                .scaleEffect(contentVisible ? 1 : 0.5)
                .opacity(contentVisible ? 1 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.65), value: contentVisible)

                // Personalized message
                VStack(spacing: 14) {
                    Text("Here's what we built for you.")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .opacity(contentVisible ? 1 : 0)
                        .animation(.easeOut(duration: 0.5).delay(0.15), value: contentVisible)

                    buildPersonalizedMessage()
                        .opacity(contentVisible ? 1 : 0)
                        .offset(y: contentVisible ? 0 : 12)
                        .animation(.easeOut(duration: 0.5).delay(0.25), value: contentVisible)
                }
                .padding(.horizontal, 28)

                // Challenge card
                VStack(spacing: 8) {
                    Text("Your Goal")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                        .tracking(1.2)

                    Text(goalWord.rawValue)
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundColor(.white)

                    Text(goalWord.challengeName)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.75))
                }
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 28)
                .scaleEffect(challengeVisible ? 1 : 0.92)
                .opacity(challengeVisible ? 1 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.4), value: challengeVisible)
            }

            Spacer()

            SurveyContinueButton(label: "Start My 3-Day Challenge") { onContinue() }
                .padding(.bottom, 52)
                .opacity(challengeVisible ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.6), value: challengeVisible)
        }
        .onAppear {
            withAnimation { contentVisible = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation { challengeVisible = true }
            }
            Analytics.logEvent("survey_goal_reveal_shown", parameters: [
                "goal_word": goalWord.rawValue
            ])
        }
    }

    @ViewBuilder
    private func buildPersonalizedMessage() -> some View {
        let burden = responses.burdenShortLabel
        let duration = responses.durationLabel

        VStack(spacing: 10) {
            Text("You've been carrying \(burden) — \(duration).")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Text("You've tried to push through. And for a moment things helped. But nothing stuck.\n\nWhat you haven't tried yet is this: speaking God's truth out loud — daily, over the exact lies you named.\n\nThat's what SpeakLife does. Starting now.")
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
    }
}
