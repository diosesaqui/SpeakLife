//
//  SurveyOnboardingScreens.swift
//  SpeakLife
//

import SwiftUI
import FirebaseAnalytics

// MARK: - Shared Private Components

private struct SurveyOptionRow: View {
    let text: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: {
            Juice.play(.tapLight)
            action()
        }) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .strokeBorder(
                            isSelected ? Color.white : Color.white.opacity(0.35),
                            lineWidth: 1.5
                        )
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
                            .strokeBorder(
                                isSelected ? Color.white.opacity(0.5) : Color.white.opacity(0.12),
                                lineWidth: 1
                            )
                    )
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct SurveyCheckRow: View {
    let text: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: {
            Juice.play(.tapLight)
            action()
        }) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(
                            isSelected ? Color.white : Color.white.opacity(0.35),
                            lineWidth: 1.5
                        )
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
                            .strokeBorder(
                                isSelected ? Color.white.opacity(0.5) : Color.white.opacity(0.12),
                                lineWidth: 1
                            )
                    )
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

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

// MARK: - Intro

struct SurveyIntroScreen: View {
    let size: CGSize
    let onContinue: () -> Void

    @State private var h = false
    @State private var s = false
    @State private var b = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 28) {
                VStack(spacing: 12) {
                    Text("Before we take back what's yours —")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .opacity(h ? 1 : 0)
                        .offset(y: h ? 0 : 16)
                        .animation(.easeOut(duration: 0.6), value: h)
                    Text("tell us where the enemy\nhas been attacking.")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .opacity(h ? 1 : 0)
                        .offset(y: h ? 0 : 16)
                        .animation(.easeOut(duration: 0.6).delay(0.1), value: h)
                }
                Text("A few questions. Your declarations, your daily plan, and your inheritance — all built around your answer.")
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
                    .opacity(s ? 1 : 0)
                    .offset(y: s ? 0 : 12)
                    .animation(.easeOut(duration: 0.5), value: s)
            }
            Spacer()
            SurveyContinueButton(label: "Let's Take It Back") { onContinue() }
                .padding(.bottom, 36)
                .opacity(b ? 1 : 0)
                .offset(y: b ? 0 : 20)
                .animation(.easeOut(duration: 0.5), value: b)
        }
        .onAppear {
            withAnimation { h = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { withAnimation { s = true } }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { withAnimation { b = true } }
        }
    }
}

// MARK: - Q1: Territory (merged Burden + DeclarationStyle)

private struct TerritoryOptionRow: View {
    let burden: HeaviestBurden
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: {
            Juice.play(.tapLight)
            action()
        }) {
            HStack(spacing: 14) {
                Text(burden.icon)
                    .font(.system(size: 24))
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 3) {
                    Text(burden.rawValue)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(burden.description)
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                ZStack {
                    Circle()
                        .strokeBorder(
                            isSelected ? Color.white : Color.white.opacity(0.35),
                            lineWidth: 1.5
                        )
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 12, height: 12)
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
                            .strokeBorder(
                                isSelected ? Color.white.opacity(0.5) : Color.white.opacity(0.12),
                                lineWidth: 1
                            )
                    )
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SurveyQ1BurdenScreen: View {
    let size: CGSize
    @ObservedObject var responses: SurveyResponses
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    Spacer().frame(height: size.height * 0.10)

                    // Revelation header — inline to support scripture + bridge
                    VStack(spacing: 12) {
                        Text("What you've been struggling with?\nIt's not from God.")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("\"The thief comes to steal, kill, and destroy.\nI came that they may have life — and have it abundantly.\"\n— John 10:10")
                            .font(.system(size: 14, weight: .regular, design: .serif))
                            .italic()
                            .foregroundColor(.red.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("The enemy has been blocking your inheritance.\nName what he's been after. Then we take it back.")
                            .font(.system(size: 15, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 28)

                    VStack(spacing: 10) {
                        ForEach(HeaviestBurden.allCases) { option in
                            TerritoryOptionRow(
                                burden: option,
                                isSelected: responses.heaviestBurden == option
                            ) {
                                responses.heaviestBurden = option
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    Spacer().frame(height: 8)
                }
            }
            SurveyContinueButton(isEnabled: responses.heaviestBurden != nil, action: onContinue)
                .padding(.top, 8).padding(.bottom, 36)
        }
        .onAppear { Analytics.logEvent("survey_q1_shown", parameters: nil) }
    }
}

// MARK: - Q2: Wherever You Are With God

struct SurveyQ2DurationScreen: View {
    let size: CGSize
    @ObservedObject var responses: SurveyResponses
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    Spacer().frame(height: size.height * 0.12)
                    VStack(spacing: 10) {
                        Text("Wherever you are with God right now — your inheritance is already secured.")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 28)
                        Text("Tell us where you are so we meet you there.\nBut know this: the chest doesn't get fuller for the mature or emptier for the new.")
                            .font(.system(size: 15, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.65))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 28)
                        Text("It's been full since the cross.")
                            .font(.system(size: 15, weight: .regular, design: .serif))
                            .italic()
                            .foregroundColor(.white.opacity(0.75))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 28)
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
                    Spacer().frame(height: 8)
                }
            }
            SurveyContinueButton(isEnabled: responses.burdenDuration != nil, action: onContinue)
                .padding(.top, 8).padding(.bottom, 36)
        }
        .onAppear { Analytics.logEvent("survey_q2_shown", parameters: nil) }
    }
}

// MARK: - Merged Barriers (was Q3 + Q4)

struct SurveyMergedBarriersScreen: View {
    let size: CGSize
    @ObservedObject var responses: SurveyResponses
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    Spacer().frame(height: size.height * 0.12)
                    SurveyQuestionHeader(
                        "What's been getting in the way — be real.",
                        subtitle: "Select all that apply."
                    )
                    VStack(spacing: 10) {
                        ForEach(BarrierOption.allCases) { option in
                            SurveyCheckRow(
                                text: option.rawValue,
                                isSelected: responses.barriers.contains(option)
                            ) {
                                if responses.barriers.contains(option) {
                                    responses.barriers.remove(option)
                                } else {
                                    responses.barriers.insert(option)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    Spacer().frame(height: 8)
                }
            }
            SurveyContinueButton(isEnabled: !responses.barriers.isEmpty, action: onContinue)
                .padding(.top, 8).padding(.bottom, 36)
        }
        .onAppear { Analytics.logEvent("survey_merged_barriers_shown", parameters: nil) }
    }
}

struct SurveyInterstitialBScreen: View {
    let size: CGSize
    var onContinue: () -> Void
    @State private var v = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 28) {
                VStack(spacing: 20) {
                    Text("Everything you just named?\nThe enemy is working overtime\nto keep it from you.")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)
                        .opacity(v ? 1 : 0)
                        .offset(y: v ? 0 : 16)
                        .animation(.easeOut(duration: 0.5).delay(0), value: v)

                    Text("Because he knows what's in your treasure chest.")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .opacity(v ? 1 : 0)
                        .offset(y: v ? 0 : 12)
                        .animation(.easeOut(duration: 0.5).delay(0.1), value: v)
                }

                VStack(spacing: 16) {
                    Text("He doesn't want you healthy. He doesn't want you walking in your calling. He doesn't want you experiencing God's full abundance.\nThat's John 10:10 — steal, kill, destroy.")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)

                    Text("But here's what 100,000 believers have discovered:")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                        .multilineTextAlignment(.center)

                    Text("When you open your mouth and declare God's Word, you don't just cope.\nYou advance. You take ground.\nYou receive what was already prepared and paid for in Christ.")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .padding(.horizontal, 32)
                .opacity(v ? 1 : 0)
                .offset(y: v ? 0 : 12)
                .animation(.easeOut(duration: 0.5).delay(0.2), value: v)

                VStack(spacing: 6) {
                    Text("\"Death and life are in the power of the tongue.\"")
                        .font(.system(size: 16, weight: .semibold, design: .serif))
                        .italic()
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    Text("Proverbs 18:21")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.45))
                }
                .opacity(v ? 1 : 0)
                .offset(y: v ? 0 : 10)
                .animation(.easeOut(duration: 0.5).delay(0.35), value: v)
            }

            Spacer()

            SurveyContinueButton(label: "I'm Ready to Take More Ground →", isEnabled: true) {
                onContinue()
            }
            .padding(.bottom, 36)
            .opacity(v ? 1 : 0)
            .animation(.easeOut(duration: 0.5).delay(0.35), value: v)
        }
        .onAppear {
            Analytics.logEvent("survey_interstitial_b_shown", parameters: nil)
            withAnimation {
                v = true
            }
        }
    }
}

struct SurveyQ5DeclarationExpScreen: View {
    let size: CGSize
    @ObservedObject var responses: SurveyResponses
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            SurveyQuestionHeader(
                "Have you ever declared God's Word out loud — and felt something shift?",
                subtitle: "The Word isn't just to be read. It's to be released."
            )
            .padding(.top, size.height * 0.12)

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(DeclarationExperience.allCases, id: \.self) { option in
                        SurveyOptionRow(
                            text: option.rawValue,
                            isSelected: responses.declarationExperience == option
                        ) {
                            responses.declarationExperience = option
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                                onContinue()
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }

            Spacer()
        }
        .onAppear {
            Analytics.logEvent("survey_q5_shown", parameters: nil)
        }
    }
}


struct SurveyGoalRevealScreen: View {
    let size: CGSize
    @ObservedObject var responses: SurveyResponses
    var onContinue: () -> Void
    @State private var cv = false
    @State private var chv = false

    private var goalWord: SurveyGoalWord { responses.resolvedGoalWord }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    Spacer().frame(height: size.height * 0.1)

                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [DS.Palette.gold.opacity(0.95), DS.Palette.gold.opacity(0.55)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 72, height: 72)
                            .shadow(color: DS.Palette.gold.opacity(0.5), radius: 8, x: 0, y: 4)

                        Image(systemName: goalWord.icon)
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                    }
                    .scaleEffect(cv ? 1 : 0.6)
                    .opacity(cv ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.65), value: cv)

                    Text("Here's your 30-day war plan.")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                        .opacity(cv ? 1 : 0)
                        .offset(y: cv ? 0 : 10)
                        .animation(.easeOut(duration: 0.45).delay(0.15), value: cv)

                    Text("Declare God's Word over your \(responses.burdenShortLabel) every single day. The enemy loses ground. You gain it.")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.white.opacity(0.7))
                        .lineSpacing(3)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                        .opacity(cv ? 1 : 0)
                        .offset(y: cv ? 0 : 10)
                        .animation(.easeOut(duration: 0.45).delay(0.25), value: cv)

                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
                            )

                        VStack(spacing: 8) {
                            Text("YOUR INHERITANCE")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(DS.Palette.gold.opacity(0.9))
                                .kerning(1.2)

                            Text(goalWord.rawValue)
                                .font(.system(size: 28, weight: .black, design: .rounded))
                                .foregroundColor(.white)

                            Text(goalWord.challengeName)
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.75))

                            Text("Your 30-day war plan")
                                .font(.system(size: 13, weight: .regular, design: .rounded))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .padding(.vertical, 24)
                    }
                    .padding(.horizontal, 28)
                    .scaleEffect(chv ? 1 : 0.92)
                    .opacity(chv ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.4), value: chv)

                    Spacer().frame(height: 16)
                }
            }

            SurveyContinueButton(label: "Start Taking Ground →", isEnabled: true) {
                onContinue()
            }
            .padding(.top, 8).padding(.bottom, 36)
            .opacity(chv ? 1 : 0)
            .animation(.easeOut(duration: 0.4).delay(0.6), value: chv)
        }
        .onAppear {
            Analytics.logEvent("survey_goal_reveal_shown", parameters: ["goal_word": goalWord.rawValue])
            withAnimation {
                cv = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation {
                    chv = true
                }
            }
        }
    }
}

struct SurveyQ8NotificationScreen: View {
    let size: CGSize
    @ObservedObject var responses: SurveyResponses
    /// Which onboarding flow is showing this screen ("quiz" | "survey" |
    /// "identity" | "outcomes" | "warfare" | "product"). Stamped onto
    /// `survey_q8_shown` so funnels can split the shared back-half by arm.
    /// Defaults to "quiz" for the quiz flow's existing call site.
    var flow: String = "quiz"
    var onContinue: () -> Void

    @State private var showPreview = false

    private var subtitle: String {
        if let burden = responses.heaviestBurden {
            return "When should we send your \(burden.shortLabel) declaration?"
        } else {
            return "When should we send your daily declaration?"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            SurveyQuestionHeader(
                "Habits are built at the same time every day.",
                subtitle: subtitle
            )
            .padding(.top, size.height * 0.12)

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(NotificationTime.allCases, id: \.self) { option in
                        SurveyOptionRow(
                            text: option.rawValue,
                            isSelected: responses.notificationTime == option
                        ) {
                            responses.notificationTime = option
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                showPreview = true
                            }
                        }
                    }

                    if showPreview, let time = responses.notificationTime {
                        notificationPreview(time: time)
                            .transition(.opacity.combined(with: .offset(x: 0, y: 10)))
                            .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }

            Spacer()

            SurveyContinueButton(label: "Lock It In →", isEnabled: responses.notificationTime != nil) {
                onContinue()
            }
            .padding(.bottom, 36)
        }
        .onAppear {
            AnalyticsService.shared.track("survey_q8_shown", parameters: ["flow": flow])
        }
    }

    private func notificationPreview(time: NotificationTime) -> some View {
        let preview = responses.heaviestBurden?.previewDeclaration
        return HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: "bell.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text("SpeakLife")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    Spacer()
                    Text(time.previewTime)
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                }
                Text(preview?.text ?? "Your daily declaration is ready.")
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .dsGlass(cornerRadius: DS.Radius.md)
    }
}

// MARK: - First Declaration (taste before paywall)

struct SurveyFirstDeclarationScreen: View {
    let size: CGSize
    @ObservedObject var responses: SurveyResponses
    /// Which onboarding flow is showing this screen ("survey" | "identity" |
    /// "outcomes" | "warfare" | "product"). Stamped onto the shared
    /// first-declaration events so funnels can split them by arm.
    var flow: String = "survey"
    let onContinue: () -> Void

    @State private var labelShown = false
    @State private var cardShown = false

    private var preview: (text: String, verse: String, reference: String) {
        responses.heaviestBurden?.previewDeclaration ?? HeaviestBurden.peace.previewDeclaration
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                Text("Speak this. Out loud. Right now.")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(DS.Palette.gold.opacity(0.9))
                    .kerning(0.8)
                    .multilineTextAlignment(.center)
                    .opacity(labelShown ? 1 : 0)
                    .animation(.easeOut(duration: 0.4), value: labelShown)

                VStack(spacing: 20) {
                    Text(preview.text)
                        .font(.system(size: 21, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(spacing: 4) {
                        Text("\"\(preview.verse)\"")
                            .font(.system(size: 14, weight: .regular, design: .serif))
                            .italic()
                            .foregroundColor(.white.opacity(0.55))
                            .multilineTextAlignment(.center)
                        Text(preview.reference)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.35))
                    }
                }
                .padding(28)
                .dsGlass(cornerRadius: DS.Radius.lg)
                .padding(.horizontal, 24)
                .scaleEffect(cardShown ? 1 : 0.94)
                .opacity(cardShown ? 1 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.15), value: cardShown)

                Text("That's one declaration. Hundreds more are waiting, built for your exact battle.")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
                    .opacity(cardShown ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.4), value: cardShown)
            }

            Spacer()

            SurveyContinueButton(label: "I Want Them All →") {
                AnalyticsService.shared.track("survey_first_declaration_continue", parameters: ["flow": flow])
                onContinue()
            }
            .padding(.bottom, 36)
            .opacity(cardShown ? 1 : 0)
            .animation(.easeOut(duration: 0.4).delay(0.55), value: cardShown)
        }
        .onAppear {
            AnalyticsService.shared.track("survey_first_declaration_shown", parameters: [
                "burden": responses.heaviestBurden?.rawValue ?? "unknown",
                "flow": flow
            ])
            withAnimation { labelShown = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation { cardShown = true }
            }
        }
    }
}

struct SurveyProductPositioningScreen: View {
    let size: CGSize
    @ObservedObject var responses: SurveyResponses
    let onContinue: () -> Void

    @State private var v = false

    private var burdenLabel: String {
        responses.heaviestBurden?.shortLabel.capitalized ?? "your inheritance"
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(maxHeight: size.height * 0.06)

            VStack(spacing: 24) {
                // Treasure chest illustration
                Image("treasure-chest-icon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 160, height: 160)

                // Personalized headline block
                VStack(spacing: 8) {
                    Text("Your \(burdenLabel) is already\nin the treasure chest.")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    Text("The harvest was prepared before you were born.\nThe inheritance has your name on it.")
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.65))
                        .multilineTextAlignment(.center)

                    Text("God's Word is the key.\nWhen you speak it, your \(burdenLabel.lowercased()) rises up in your life.")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 28)

                // Two-panel card
                HStack(spacing: 0) {
                    // LEFT panel
                    VStack(spacing: 8) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.4))
                        Text("Waiting")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(16)

                    Text("→")
                        .font(.system(size: 20))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 32)

                    // RIGHT panel
                    VStack(spacing: 8) {
                        Image(systemName: "gift.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                        Text("Possessing")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white.opacity(0.12))
                    )
                }
                .padding(4)
                .dsGlass(cornerRadius: DS.Radius.md)
                .padding(.horizontal, 28)

                // Seed + scripture
                VStack(spacing: 4) {
                    Text("\"The seed is the word of God.\"")
                        .font(.system(size: 14, weight: .regular, design: .serif))
                        .italic()
                        .foregroundColor(.red.opacity(0.8))
                        .multilineTextAlignment(.center)
                    Text("Luke 8:11")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.45))
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 28)
            }
            .opacity(v ? 1 : 0)
            .offset(y: v ? 0 : 20)

            Spacer()

            SurveyContinueButton(label: "I'm ready to take what's mine →", action: onContinue)
                .padding(.bottom, 36)
        }
        .onAppear {
            Analytics.logEvent("survey_product_positioning_shown", parameters: nil)
            withAnimation(.easeOut(duration: 0.6)) {
                v = true
            }
        }
    }
}


// MARK: - Take a Stand (Screen 13 — auto-advance transition)

struct SurveyTakeAStandScreen: View {
    @ObservedObject var responses: SurveyResponses
    let onContinue: () -> Void

    @State private var line1Opacity: Double = 0
    @State private var line2Opacity: Double = 0
    @State private var bgBrightness: Double = 0
    @State private var hasAdvanced = false

    var body: some View {
        ZStack {
            Color.white.opacity(bgBrightness)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 2.0), value: bgBrightness)

            VStack(spacing: 20) {
                Text("God has already spoken over your \(responses.resolvedGoalWord.rawValue.capitalized).")
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .opacity(line1Opacity)
                    .animation(.easeOut(duration: 0.6), value: line1Opacity)

                Text("Now it's time to stand in it.")
                    .font(.system(size: 20, weight: .regular, design: .rounded))
                    .italic()
                    .foregroundColor(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .opacity(line2Opacity)
                    .animation(.easeOut(duration: 0.6), value: line2Opacity)
            }
            .padding(.horizontal, 36)

            // VoiceOver users get a tappable Continue that sighted users can't see
            VStack {
                Spacer()
                Button("Continue") { advance(isSkip: true) }
                    .opacity(0)
                    .frame(height: 1)
                    .accessibilityLabel("Continue")
                    .padding(.bottom, 8)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { advance(isSkip: true) }
        .onAppear {
            Analytics.logEvent("onboarding_takeAStand_view", parameters: nil)
            withAnimation { line1Opacity = 1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation { line2Opacity = 1 }
            }
            withAnimation(.easeInOut(duration: 2.0)) { bgBrightness = 0.12 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                advance(isSkip: false)
            }
        }
    }

    private func advance(isSkip: Bool) {
        guard !hasAdvanced else { return }
        hasAdvanced = true
        let event = isSkip ? "onboarding_takeAStand_skip" : "onboarding_takeAStand_advance"
        Analytics.logEvent(event, parameters: nil)
        onContinue()
    }
}


struct SurveyCommitmentHoldScreen: View {
    let size: CGSize
    let onContinue: () -> Void

    @State private var appeared = false
    @State private var phase: CommitmentPhase = .idle
    @State private var holdProgress: Double = 0
    @State private var holdTimer: Timer? = nil
    @State private var glowOpacity: Double = 0
    @State private var ringScale: CGFloat = 1.0
    @State private var celebrationScale: CGFloat = 0.6

    private enum CommitmentPhase { case idle, holding, complete }

    private let holdDuration: Double = 4.0

    private let declarationText = "I will show up daily.\nI will open my mouth and declare God's Word\nover my life — every single day.\n\nI will not settle. I will not retreat.\nI will take more ground tomorrow than I took today.\n\nThe enemy will not steal another day from me.\nHealth. Peace. Joy. Purpose. Abundance.\nAll of it belongs to me in Christ — and I am taking it.\n\nHoly Spirit, use SpeakLife to make Your Word\nthe first thing I speak every morning\nand the last thing standing over my life."

    var body: some View {
        ZStack {
            if phase == .holding {
                RadialGradient(
                    gradient: Gradient(colors: [Color.white.opacity(0.22), Color.clear]),
                    center: .bottom,
                    startRadius: 40,
                    endRadius: size.height * 0.7
                )
                .opacity(glowOpacity)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .transition(.opacity)
            }

            if phase == .complete {
                RadialGradient(
                    gradient: Gradient(colors: [Color(red: 1.0, green: 0.82, blue: 0.25).opacity(0.3), Color.clear]),
                    center: .center,
                    startRadius: 60,
                    endRadius: size.height * 0.65
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .transition(.opacity)
            }

            if phase == .complete {
                celebrationView
                    .opacity(appeared ? 1 : 0)
            } else {
                declarationView
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)
            }
        }
        .onAppear {
            Analytics.logEvent("survey_commitment_hold_shown", parameters: nil)
            withAnimation(.easeOut(duration: 0.6)) { appeared = true }
        }
    }

    @ViewBuilder
    private var declarationView: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: size.height * 0.08)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    Text("My Daily Commitment as a Ground-Taker")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    Text(declarationText)
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .lineSpacing(5)
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.white.opacity(0.08))
                        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.18), lineWidth: 1))
                )
                .padding(.horizontal, 28)
            }

            Spacer()

            VStack(spacing: 4) {
                Text("I commit to every word above.")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
                Text(phase == .holding ? "I'm Showing Up. Starting Now." : "Hold to seal it.")
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(phase == .holding ? .white : .white.opacity(0.5))
                    .animation(.easeInOut(duration: 0.25), value: phase == .holding)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)

            Spacer().frame(height: 24)

            holdButtonView

            Spacer().frame(height: 52)
        }
    }

    @ViewBuilder
    private var holdButtonView: some View {
        ZStack {
            if phase == .holding {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(Color.white.opacity(max(0, 0.25 - Double(i) * 0.07)), lineWidth: 1.5)
                        .frame(width: 90 + CGFloat(i * 32), height: 90 + CGFloat(i * 32))
                        .scaleEffect(ringScale)
                }
            }

            Circle()
                .trim(from: 0, to: holdProgress)
                .stroke(Color.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: 88, height: 88)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.05), value: holdProgress)

            Circle()
                .fill(phase == .holding ? Color.white.opacity(0.25) : Color.white.opacity(0.12))
                .frame(width: 80, height: 80)
                .animation(.easeInOut(duration: 0.2), value: phase == .holding)

            Image(systemName: phase == .holding ? "hand.raised.fill" : "hand.raised")
                .font(.system(size: 28))
                .foregroundColor(.white)
                .animation(.easeInOut(duration: 0.2), value: phase == .holding)
        }
        .frame(width: 160, height: 160)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in startHold() }
                .onEnded { _ in cancelHold() }
        )
    }

    @ViewBuilder
    private var celebrationView: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                Text("🔥")
                    .font(.system(size: 72))
                    .scaleEffect(celebrationScale)
                    .onAppear {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) {
                            celebrationScale = 1.0
                        }
                    }

                Text("Ground Taken.")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text("The enemy heard that.\nAnd so did heaven.")
                    .font(.system(size: 18, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 28)

            Spacer()

            SurveyContinueButton(label: "Let's Go →") {
                Analytics.logEvent("survey_commitment_sealed", parameters: nil)
                onContinue()
            }
            .padding(.bottom, 36)
        }
    }

    private func startHold() {
        guard phase == .idle else { return }
        Juice.play(.tapSolid)
        withAnimation(.easeInOut(duration: 0.3)) { phase = .holding }
        withAnimation(.easeInOut(duration: 0.5)) { glowOpacity = 1.0 }
        withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { ringScale = 1.15 }

        let start = Date()
        var lastHapticSecond = -1
        holdTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            let elapsed = Date().timeIntervalSince(start)
            holdProgress = min(elapsed / holdDuration, 1.0)
            let currentSecond = Int(elapsed)
            if currentSecond != lastHapticSecond && currentSecond > 0 && holdProgress < 1.0 {
                lastHapticSecond = currentSecond
                Juice.play(.tapSolid)
            }
            if holdProgress >= 1.0 {
                timer.invalidate()
                holdTimer = nil
                Juice.play(.success)
                withAnimation(.easeInOut(duration: 0.45)) {
                    glowOpacity = 0
                    phase = .complete
                }
            }
        }
    }

    private func cancelHold() {
        guard phase == .holding else { return }
        holdTimer?.invalidate()
        holdTimer = nil
        Juice.play(.tapLight)
        withAnimation(.easeOut(duration: 0.3)) { phase = .idle }
        withAnimation(.easeOut(duration: 0.4)) { glowOpacity = 0 }
        withAnimation(.easeOut(duration: 0.3)) { ringScale = 1.0 }
        withAnimation(.linear(duration: 0.2)) { holdProgress = 0 }
    }
}

// MARK: - Extended Quiz (Q2-Q6 in the warfare/product flows)

/// One selectable answer in an extended-quiz question. `value` is the raw
/// analytics value stored on SurveyResponses and stamped onto
/// `quiz_question_answered` + the flow-completed events.
struct ExtendedQuizOption: Identifiable {
    let value: String
    let label: String
    let sublabel: String?
    let symbol: String

    var id: String { value }

    init(value: String, label: String, sublabel: String? = nil, symbol: String) {
        self.value = value
        self.label = label
        self.sublabel = sublabel
        self.symbol = symbol
    }
}

/// Copy + options for one extended-quiz question. The five questions inserted
/// after the burden picker in the warfare and product arms live here so both
/// flows render identical screens.
struct ExtendedQuizQuestion {
    let key: String
    let title: String
    let subtitle: String
    let options: [ExtendedQuizOption]

    static let battleDuration = ExtendedQuizQuestion(
        key: "battle_duration",
        title: "How long has this battle\nbeen going on?",
        subtitle: "Be honest. This shapes your plan.",
        options: [
            ExtendedQuizOption(value: "weeks",  label: "A few weeks", symbol: "clock"),
            ExtendedQuizOption(value: "months", label: "A few months", symbol: "calendar"),
            ExtendedQuizOption(value: "years",  label: "Years", symbol: "hourglass"),
            ExtendedQuizOption(value: "always", label: "As long as I can remember", symbol: "infinity")
        ]
    )

    static let alreadyTried = ExtendedQuizQuestion(
        key: "already_tried",
        title: "What have you already tried?",
        subtitle: "There's no wrong answer here.",
        options: [
            ExtendedQuizOption(value: "prayer",      label: "Prayer when it gets bad", symbol: "hands.sparkles.fill"),
            ExtendedQuizOption(value: "devotionals", label: "Devotionals and reading plans", symbol: "book.fill"),
            ExtendedQuizOption(value: "therapy",     label: "Therapy or counseling", symbol: "person.2.fill"),
            ExtendedQuizOption(value: "willpower",   label: "Pushing through on my own", symbol: "figure.walk"),
            ExtendedQuizOption(value: "everything",  label: "All of it. I'm still in the fight", symbol: "flame.fill")
        ]
    )

    static let hitsHardest = ExtendedQuizQuestion(
        key: "hits_hardest",
        title: "When does it hit hardest?",
        subtitle: "We'll arm you for that exact moment.",
        options: [
            ExtendedQuizOption(value: "night",   label: "3am wake-ups and racing thoughts", symbol: "moon.zzz.fill"),
            ExtendedQuizOption(value: "morning", label: "First thing in the morning", symbol: "sunrise.fill"),
            ExtendedQuizOption(value: "midday",  label: "Under pressure during the day", symbol: "sun.max.fill"),
            ExtendedQuizOption(value: "evening", label: "When everything goes quiet at night", symbol: "moon.stars.fill")
        ]
    )

    static let connectStyle = ExtendedQuizQuestion(
        key: "connect_style",
        title: "How do you connect best\nwith God's Word?",
        subtitle: "Your plan will lead with this.",
        options: [
            ExtendedQuizOption(value: "speaking",   label: "Speaking it out loud", symbol: "waveform"),
            ExtendedQuizOption(value: "listening",  label: "Listening on the go", symbol: "headphones"),
            ExtendedQuizOption(value: "reading",    label: "Reading and reflecting", symbol: "book.closed.fill"),
            ExtendedQuizOption(value: "journaling", label: "Writing and journaling", symbol: "square.and.pencil")
        ]
    )

    static let dailyMinutes = ExtendedQuizQuestion(
        key: "daily_minutes",
        title: "How much time can you\ngive this daily?",
        subtitle: "Small and daily beats big and rare.",
        options: [
            ExtendedQuizOption(value: "one",   label: "1 minute. I need it fast", symbol: "bolt.fill"),
            ExtendedQuizOption(value: "three", label: "3 minutes morning and night", symbol: "clock.fill"),
            ExtendedQuizOption(value: "ten",   label: "10 minutes. I want to go deep", symbol: "books.vertical.fill")
        ]
    )

    /// Quiz v2 only: the outcome question that replaces `connectStyle` when
    /// Remote Config `useQuizV2` is on. Options are burden-aware so victory
    /// reads in the user's own battle (see HeaviestBurden.victoryOptions).
    static func victoryLooksLike(for burden: HeaviestBurden) -> ExtendedQuizQuestion {
        ExtendedQuizQuestion(
            key: "victory_looks_like",
            title: "What would change if this\nbattle was actually won?",
            subtitle: "Name it. That's what we aim at.",
            options: burden.victoryOptions.map {
                ExtendedQuizOption(value: $0.value, label: $0.label, symbol: $0.symbol)
            }
        )
    }

    /// Quiz v2 only: asked right after the outcome question. Every answer
    /// simply advances — no judgmental follow-up.
    static let belief = ExtendedQuizQuestion(
        key: "belief",
        title: "Do you believe God wants\nmore for you in this area?",
        subtitle: "There's no wrong answer. This is between you and Him.",
        options: [
            ExtendedQuizOption(value: "yes",     label: "Yes, absolutely", symbol: "flame.fill"),
            ExtendedQuizOption(value: "want_to", label: "I want to believe it", symbol: "heart.fill"),
            ExtendedQuizOption(value: "unsure",  label: "Honestly, I'm not sure", symbol: "questionmark.circle.fill")
        ]
    )
}

/// Icon-tile answer row matching the burden pickers' chrome (icon, label,
/// optional sub-label, radio circle, selection highlight).
private struct QuizOptionRow: View {
    let option: ExtendedQuizOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: {
            Juice.play(.tapLight)
            action()
        }) {
            HStack(spacing: 14) {
                Image(systemName: option.symbol)
                    .font(.system(size: 22))
                    .foregroundColor(.white.opacity(isSelected ? 1 : 0.7))
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 3) {
                    Text(option.label)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    if let sub = option.sublabel {
                        Text(sub)
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.55))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer()
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? Color.white : Color.white.opacity(0.35), lineWidth: 1.5)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle().fill(Color.white).frame(width: 12, height: 12)
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
                            .strokeBorder(isSelected ? Color.white.opacity(0.5) : Color.white.opacity(0.12), lineWidth: 1)
                    )
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// Reusable single-select question screen for the extended quiz. Continue is
/// disabled until an option is selected; no auto-advance. Fires
/// `quiz_question_shown` on appear and `quiz_question_answered` on continue,
/// both tagged with the flow ("warfare" | "product").
struct SurveyExtendedQuizScreen: View {
    let size: CGSize
    let flow: String
    let question: ExtendedQuizQuestion
    @Binding var selection: String?
    let onContinue: () -> Void

    @State private var v = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    Spacer().frame(height: size.height * 0.10)

                    VStack(spacing: 12) {
                        Text(question.title)
                            .font(.system(size: 27, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .planRevealStagger(v)

                        Text(question.subtitle)
                            .font(.system(size: 15, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.65))
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                            .planRevealStagger(v, delay: 0.1)
                    }
                    .padding(.horizontal, 28)

                    VStack(spacing: 10) {
                        ForEach(question.options) { option in
                            QuizOptionRow(option: option, isSelected: selection == option.value) {
                                selection = option.value
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .planRevealStagger(v, delay: 0.2)

                    Spacer().frame(height: 8)
                }
            }

            SurveyContinueButton(isEnabled: selection != nil) {
                AnalyticsService.shared.track("quiz_question_answered", parameters: [
                    "flow": flow,
                    "question": question.key,
                    "answer": selection ?? "unknown"
                ])
                onContinue()
            }
            .padding(.top, 8).padding(.bottom, 36)
        }
        .onAppear {
            AnalyticsService.shared.track("quiz_question_shown", parameters: [
                "flow": flow,
                "question": question.key
            ])
            withAnimation { v = true }
        }
    }
}

/// Micro-insight interstitial between Q3 and Q4: reframes the product
/// mechanism (speaking vs reading) right after the user names what they've
/// already tried. Tap-through, no selection. Qualitative claims only.
struct SurveyQuizInsightScreen: View {
    let size: CGSize
    let flow: String
    let onContinue: () -> Void

    @State private var v = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 26) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.10))
                        .frame(width: 96, height: 96)
                    Image(systemName: "waveform")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                }
                .planRevealStagger(v)

                VStack(spacing: 14) {
                    Text("HERE'S THE SHIFT")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                        .kerning(1.4)
                        .multilineTextAlignment(.center)
                        .planRevealStagger(v, delay: 0.08)

                    Text("Reading calms the mind.\nSpeaking takes ground.")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .planRevealStagger(v, delay: 0.14)

                    Text("Most believers read about peace and feel better for an hour. Jesus spoke to storms, and they obeyed. Your plan is built around your voice, because faith comes by hearing, and hearing by the word of God.")
                        .font(.system(size: 17, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 22)
                        .fixedSize(horizontal: false, vertical: true)
                        .planRevealStagger(v, delay: 0.22)
                }

                VStack(spacing: 4) {
                    Text("\"So then faith comes by hearing, and hearing by the word of God.\"")
                        .font(.system(size: 15, weight: .regular, design: .serif))
                        .italic()
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Romans 10:17")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.45))
                }
                .padding(.horizontal, 28)
                .planRevealStagger(v, delay: 0.32)
            }
            .padding(.horizontal, 28)

            Spacer()

            SurveyContinueButton(label: "That's What I Want →") { onContinue() }
                .padding(.bottom, 36)
                .planRevealStagger(v, delay: 0.42)
        }
        .onAppear {
            AnalyticsService.shared.track("quiz_insight_shown", parameters: ["flow": flow])
            withAnimation { v = true }
        }
    }
}

// MARK: - Plan Building (pre-paywall loader)

/// A ~4s "building your plan" loader shown right before the plan reveal +
/// paywall (the Noom / Bible Chat pattern). Four checkmark lines tick in one
/// by one with a soft haptic each, then it auto-advances. No button, no
/// progress bar — it reads as a transition, not a step.
struct SurveyPlanBuildingScreen: View {
    let burden: HeaviestBurden
    /// Which onboarding flow is showing this screen ("warfare" | "product").
    let flow: String
    let onComplete: () -> Void

    @State private var visibleLines = 0
    @State private var spinnerAngle: Double = 0
    @State private var hasCompleted = false

    private static let checkGreen = Color(red: 0.36, green: 0.84, blue: 0.55)

    private var title: String {
        flow == "warfare" ? "Building your battle plan..." : "Building your plan..."
    }

    private var lines: [String] {
        let matching: String
        if burden == .allOfIt {
            matching = "Matching declarations to your fight"
        } else {
            matching = "Matching declarations to your battle for \(burden.shortLabel)"
        }
        return [
            matching,
            "Choosing your verses",
            "Setting your daily rhythm",
            "Trusted by \(SocialProof.believersCount) believers"
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 36) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.15), lineWidth: 4)
                        .frame(width: 56, height: 56)
                    Circle()
                        .trim(from: 0, to: 0.3)
                        .stroke(Color.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 56, height: 56)
                        .rotationEffect(.degrees(spinnerAngle))
                }

                Text(title)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 28)

                VStack(alignment: .leading, spacing: 18) {
                    ForEach(lines.indices, id: \.self) { i in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 19))
                                .foregroundColor(Self.checkGreen)
                            Text(lines[i])
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.85))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .opacity(i < visibleLines ? 1 : 0)
                        .offset(y: i < visibleLines ? 0 : 8)
                        .animation(.easeOut(duration: 0.35), value: visibleLines)
                    }
                }
                .padding(.horizontal, 44)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer()
            Spacer().frame(height: 80)
        }
        .onAppear { start() }
    }

    private func start() {
        AnalyticsService.shared.track("plan_building_shown", parameters: [
            "flow": flow,
            "burden": burden.shortLabel
        ])
        withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
            spinnerAngle = 360
        }
        let lineCount = lines.count
        for i in 1...lineCount {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4 + Double(i - 1) * 0.9) {
                Juice.play(.tapLight)
                withAnimation { visibleLines = i }
            }
        }
        // Last line lands at 0.4 + 2.7 = 3.1s; settle ~1s, advance at ~4.1s.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4 + Double(lineCount - 1) * 0.9 + 1.0) {
            guard !hasCompleted else { return }
            hasCompleted = true
            onComplete()
        }
    }
}

// MARK: - Plan Reveal (named plan, shown right before the paywall)

private struct SurveyPlanRevealStagger: ViewModifier {
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
    func planRevealStagger(_ shown: Bool, delay: Double = 0) -> some View {
        modifier(SurveyPlanRevealStagger(shown: shown, delay: delay))
    }
}

/// The named-plan reveal: "Your 30-Day Take Back My Peace Plan" with a plan
/// card (their declaration, the scripture anchor, the daily rhythm) and a
/// realistic 3-line arc. CTA advances to the paywall.
struct SurveyPlanRevealScreen: View {
    let size: CGSize
    let burden: HeaviestBurden
    /// Which onboarding flow is showing this screen ("warfare" | "product").
    let flow: String
    /// The user's saved personal declaration, if they recorded one. When nil
    /// (or empty) the burden's curated preview declaration is shown instead.
    let personalDeclaration: String?
    /// Raw "daily_minutes" quiz answer ("one" | "three" | "ten"). Drives the
    /// "Daily rhythm" row copy; nil falls back to the generic line so callers
    /// without the extended quiz are unaffected.
    var dailyMinutes: String? = nil
    /// Quiz v2 only: the user's victory-outcome echo phrase. When present the
    /// week-4 arc line replays it in their own words; nil keeps the static line.
    var victoryEcho: String? = nil
    let onContinue: () -> Void

    @State private var v = false

    private var hasPersonalDeclaration: Bool {
        if let text = personalDeclaration, !text.isEmpty { return true }
        return false
    }

    private var dailyRhythmDetail: String {
        switch dailyMinutes {
        case "one":   return "1 minute, morning and evening"
        case "three": return "3 minutes, morning and evening"
        case "ten":   return "10 minutes of depth, morning and evening"
        default:      return "Morning and evening declarations, built around your day."
        }
    }

    private var declarationText: String {
        if let text = personalDeclaration, !text.isEmpty { return text }
        return burden.previewDeclaration.text
    }

    private var weekFourLine: String {
        if let echo = victoryEcho, !echo.isEmpty {
            return "\(echo). Standing on promises."
        }
        return "Standing on promises, not fighting for footing."
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    Spacer().frame(height: size.height * 0.09)

                    VStack(spacing: 12) {
                        Text("YOUR PLAN IS READY")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.5))
                            .kerning(1.4)
                            .planRevealStagger(v)

                        Text(burden.planTitle)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .planRevealStagger(v, delay: 0.08)
                    }
                    .padding(.horizontal, 28)

                    // Plan card
                    VStack(spacing: 0) {
                        planRow(
                            icon: "quote.opening",
                            title: "Your daily declaration",
                            detail: declarationText,
                            detailLineLimit: 3
                        )
                        cardDivider
                        planRow(
                            icon: "book.fill",
                            title: "Scripture-backed",
                            detail: "Every word stands on the Word, starting with \(burden.previewDeclaration.reference)."
                        )
                        cardDivider
                        planRow(
                            icon: "bell.badge.fill",
                            title: "Daily rhythm",
                            detail: dailyRhythmDetail
                        )
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.white.opacity(0.09))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 24)
                    .planRevealStagger(v, delay: 0.18)

                    // Realistic 3-line arc
                    VStack(alignment: .leading, spacing: 10) {
                        weekLine("WEEK 1", "Speak truth before the spiral starts.")
                        weekLine("WEEK 2", "God's Word becomes your first response.")
                        weekLine("WEEK 4", weekFourLine)
                    }
                    .padding(.horizontal, 32)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .planRevealStagger(v, delay: 0.3)

                    // Destination: the vivid won life this plan (and the unlock)
                    // is building toward — the bridge from product to the user's
                    // dream reality, landed right before the ask.
                    VStack(spacing: 6) {
                        Text("WHERE THIS TAKES YOU")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.5))
                            .kerning(1.2)
                        Text(burden.dreamOutcome)
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 4)
                    .planRevealStagger(v, delay: 0.36)

                    Spacer().frame(height: 8)
                }
            }

            SurveyContinueButton(label: "Unlock My Plan →") {
                AnalyticsService.shared.track("plan_reveal_continue", parameters: [
                    "flow": flow,
                    "burden": burden.shortLabel
                ])
                onContinue()
            }
            .padding(.top, 8).padding(.bottom, 36)
            .planRevealStagger(v, delay: 0.4)
        }
        .onAppear {
            AnalyticsService.shared.track("plan_reveal_shown", parameters: [
                "flow": flow,
                "burden": burden.shortLabel,
                "has_personal_declaration": hasPersonalDeclaration as NSNumber
            ])
            withAnimation { v = true }
        }
    }

    private var cardDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.12))
            .frame(height: 1)
            .padding(.horizontal, 16)
    }

    private func planRow(icon: String, title: String, detail: String, detailLineLimit: Int? = nil) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                Text(detail)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.65))
                    .lineLimit(detailLineLimit)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func weekLine(_ week: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(week)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.5))
                .kerning(0.8)
                .frame(width: 52, alignment: .leading)
            Text(text)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
