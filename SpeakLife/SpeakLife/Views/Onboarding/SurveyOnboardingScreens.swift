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
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
                Text("8 questions. Your declarations, your daily plan, and your inheritance — all built around your answer.")
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
                .padding(.bottom, 52)
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
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
                    Spacer().frame(height: size.height * 0.12)
                    SurveyQuestionHeader(
                        "What has the enemy been stealing from you?",
                        subtitle: "Pick your territory. We'll build your declarations around it."
                    )
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
                .padding(.vertical, 16)
        }
        .onAppear { Analytics.logEvent("survey_q1_shown", parameters: nil) }
    }
}

// MARK: - Q2: Duration

struct SurveyQ2DurationScreen: View {
    let size: CGSize
    @ObservedObject var responses: SurveyResponses
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    Spacer().frame(height: size.height * 0.12)
                    SurveyQuestionHeader(
                        "How long have you been walking with God?",
                        subtitle: "No matter where you've been — what matters is where you're going."
                    )
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
                .padding(.vertical, 16)
        }
        .onAppear { Analytics.logEvent("survey_q2_shown", parameters: nil) }
    }
}

// MARK: - Interstitial A

private struct TestimonialReview {
    let quote: String
    let author: String
}

struct SurveyInterstitialAScreen: View {
    let size: CGSize
    @ObservedObject var responses: SurveyResponses
    let onContinue: () -> Void

    @State private var v = false

    private var testimonial: TestimonialReview {
        switch responses.heaviestBurden?.testimonialGroup {
        case .fearAndHealth:
            return TestimonialReview(
                quote: "\"I used to wake up every morning in anxiety. 21 days of healing declarations later — I wake up in peace. I didn't change my circumstances. I changed what I was speaking over them.\"",
                author: "— Jasmine R., Houston"
            )
        case .identityAndPurpose:
            return TestimonialReview(
                quote: "\"I spent years asking God to show me my purpose. SpeakLife taught me to stop asking and start declaring. Within 60 days, doors opened that I'd been knocking on for years.\"",
                author: "— David M., Atlanta"
            )
        default:
            return TestimonialReview(
                quote: "\"My faith used to crumble under pressure. After 30 days of declaring God's Word, I stopped doubting and started standing. God's Word became my first response — not my last resort.\"",
                author: "— Marcus T., Atlanta"
            )
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 32) {
                VStack(spacing: 14) {
                    Text("You're not walking this alone.")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .opacity(v ? 1 : 0)
                        .offset(y: v ? 0 : 20)
                    Text("Over 100,000 believers have opened SpeakLife and discovered that speaking God's Word out loud daily doesn't just build faith — it rewires what you believe about yourself.")
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .opacity(v ? 1 : 0)
                        .offset(y: v ? 0 : 16)
                        .animation(.easeOut(duration: 0.5).delay(0.15), value: v)
                }
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 2) {
                        ForEach(0..<5, id: \.self) { _ in
                            Image(systemName: "star.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.yellow)
                        }
                    }
                    Text(testimonial.quote)
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))
                        .italic()
                        .fixedSize(horizontal: false, vertical: true)
                    Text(testimonial.author)
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
                .opacity(v ? 1 : 0)
                .offset(y: v ? 0 : 12)
                .animation(.easeOut(duration: 0.5).delay(0.3), value: v)
            }
            Spacer()
            SurveyContinueButton(label: "Keep Going →") { onContinue() }
                .padding(.bottom, 52)
                .opacity(v ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.5), value: v)
        }
        .onAppear { withAnimation(.easeOut(duration: 0.6)) { v = true } }
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
                .padding(.vertical, 16)
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

                Text("He doesn't want you healthy. He doesn't want you walking in your calling. He doesn't want you experiencing God's full abundance. That's John 10:10 — steal, kill, destroy.\n\nBut here's what 100,000 believers have discovered:\nWhen you open your mouth and declare God's Word, you don't just cope. You advance. You take ground. You receive what was already prepared and paid for in Christ.")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
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
            .padding(.bottom, 52)
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
                "Have you ever declared God's Word out loud — and felt something in the atmosphere shift?",
                subtitle: "This is the moment most believers realize the Word isn't just to be read. It's to be released."
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
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }

            Spacer()

            SurveyContinueButton(label: "Continue", isEnabled: responses.declarationExperience != nil) {
                onContinue()
            }
            .padding(.bottom, 52)
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
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 72, height: 72)

                        Image(systemName: goalWord.icon)
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                    }
                    .scaleEffect(cv ? 1 : 0.6)
                    .opacity(cv ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.65), value: cv)

                    Text("Here's your inheritance activation plan.")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                        .opacity(cv ? 1 : 0)
                        .offset(y: cv ? 0 : 10)
                        .animation(.easeOut(duration: 0.45).delay(0.15), value: cv)

                    Text("God didn't put a limit on what He prepared for you. You're not here to survive — you're here to possess.\n\nFor 30 days, declare God's Word over the exact inheritance you named. Every declaration is a step forward. Every day you show up is ground taken.\n\nThe enemy loses ground. You gain it. That's how this works.")
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
                                .foregroundColor(.white.opacity(0.5))
                                .kerning(1.2)

                            Text(goalWord.rawValue)
                                .font(.system(size: 28, weight: .black, design: .rounded))
                                .foregroundColor(.white)

                            Text(goalWord.challengeName)
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.75))

                            Text("Built for You")
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
            .padding(.bottom, 36)
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
    var onContinue: () -> Void

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
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }

            Spacer()

            SurveyContinueButton(label: "Continue", isEnabled: responses.notificationTime != nil) {
                onContinue()
            }
            .padding(.bottom, 52)
        }
        .onAppear {
            Analytics.logEvent("survey_q8_shown", parameters: nil)
        }
    }
}

struct SurveyProductPositioningScreen: View {
    let size: CGSize
    let onContinue: () -> Void

    @State private var v = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(maxHeight: size.height * 0.08)

            VStack(spacing: 24) {
                // Headline block
                VStack(spacing: 8) {
                    Text("God already filled\nyour treasure chest.")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    Text("Health. Peace. Joy. Abundance. Purpose.")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.75))
                        .multilineTextAlignment(.center)

                    Text("It's prepared. It has your name on it.")
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)

                    Text("SpeakLife is how you reach in\nand take what's yours.")
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

                    // Divider + arrow
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
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 28)

                // Scripture chip
                VStack(spacing: 4) {
                    Text("\"Every spiritual blessing in the heavenly places is already yours in Christ.\"")
                        .font(.system(size: 14, weight: .regular, design: .serif))
                        .italic()
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)

                    Text("Ephesians 1:3")
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

            Spacer().frame(maxHeight: 40)

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


struct SurveyStyleProofScreen: View {
    let size: CGSize
    @ObservedObject var responses: SurveyResponses
    let onContinue: () -> Void

    @State private var barsVisible = false

    private struct StyleBarRow: View {
        let style: DeclarationStyle
        let isSelected: Bool
        let barsVisible: Bool

        var body: some View {
            HStack(spacing: 10) {
                Text(style.icon)
                    .font(.system(size: 16))

                Text(style.chartLabel)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular, design: .rounded))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.7))
                    .frame(width: 110, alignment: .leading)
                    .lineLimit(1)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.1))
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isSelected ? Color.white : Color.white.opacity(0.35))
                            .frame(width: barsVisible ? geo.size.width * style.barFraction : 0)
                            .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.1), value: barsVisible)
                    }
                }
                .frame(height: 8)

                Text(style.percentLabel)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.5))
                    .frame(width: 32, alignment: .trailing)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            SurveyQuestionHeader(
                "You're choosing what 100,000 believers chose.",
                subtitle: "Here's what our community is declaring daily.\nYou can update this anytime."
            )
            .padding(.top, size.height * 0.12)

            ScrollView {
                VStack(spacing: 20) {
                    // Bar chart
                    VStack(spacing: 14) {
                        ForEach(DeclarationStyle.allCases, id: \.self) { style in
                            StyleBarRow(
                                style: style,
                                isSelected: responses.primaryDeclarationStyle == style,
                                barsVisible: barsVisible
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 20)

                    // Dynamic callout
                    if let primary = responses.primaryDeclarationStyle {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("You're one of \(primary.communityCount) believers declaring \(primary.chartLabel) every single day.")
                                .font(.system(size: 14, weight: .regular, design: .rounded))
                                .foregroundColor(.white.opacity(0.85))
                                .multilineTextAlignment(.leading)
                                .lineSpacing(3)
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal, 28)
                    }
                }
                .padding(.vertical, 16)
            }

            SurveyContinueButton(label: "I'm Ready →", action: onContinue)
        }
        .onAppear {
            Analytics.logEvent("survey_style_proof_shown", parameters: nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation {
                    barsVisible = true
                }
            }
        }
    }
}

struct SurveyCommitmentHoldScreen: View {
    let size: CGSize
    let onContinue: () -> Void

    @StateObject private var verifier = DeclarationVerificationService()
    @State private var appeared = false
    @State private var phase: CommitmentPhase = .idle
    @State private var ringScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0
    @State private var celebrationScale: CGFloat = 0.6

    private enum CommitmentPhase { case idle, complete, retry }

    private let declarationText = "I am not a settler. I am a possessor. I advance. I don't retreat. I am grateful for every breakthrough and I am never satisfied with less than my full inheritance.\n\nHealth. Peace. Joy. Purpose. Abundance. All of it. Not some of it.\n\nThe enemy will not steal another day from me. Starting today I speak, I declare, I take more ground.\n\nHoly Spirit, use SpeakLife to make Your Word the first thing I speak and the last thing standing."

    private let matchThreshold = 0.15

    var body: some View {
        ZStack {
            // White glow while recording
            if verifier.isRecording {
                RadialGradient(
                    gradient: Gradient(colors: [Color.white.opacity(0.18), Color.clear]),
                    center: .bottom,
                    startRadius: 40,
                    endRadius: size.height * 0.65
                )
                .opacity(glowOpacity)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .transition(.opacity)
            }

            // Gold glow on completion
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
            verifier.prepare(declarationText: declarationText)
            withAnimation(.easeOut(duration: 0.6)) { appeared = true }
        }
        .onChange(of: verifier.isRecording) { isNowRecording in
            if isNowRecording {
                withAnimation(.easeInOut(duration: 0.5)) { glowOpacity = 1.0 }
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { ringScale = 1.2 }
            } else {
                withAnimation(.easeOut(duration: 0.4)) { glowOpacity = 0 }
                withAnimation(.easeOut(duration: 0.3)) { ringScale = 1.0 }
            }
        }
    }

    @ViewBuilder
    private var declarationView: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: size.height * 0.08)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    Text("🤝")
                        .font(.system(size: 36))
                    Text("My Declaration as a Ground-Taker")
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

            Text(statusText)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundColor(phase == .retry ? Color(red: 1.0, green: 0.65, blue: 0.4) : .white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .animation(.easeInOut, value: verifier.isRecording)

            Spacer().frame(height: 24)

            micButtonView

            Spacer().frame(height: 52)
        }
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
                Analytics.logEvent("survey_commitment_spoken", parameters: ["match_pct": Int(verifier.matchPercentage * 100)])
                onContinue()
            }
            .padding(.bottom, 52)
        }
    }

    private var statusText: String {
        if verifier.isTranscribing { return "Processing your declaration..." }
        if phase == .retry { return "We didn't catch that clearly. Speak out loud and tap mic again." }
        if verifier.isRecording { return "Speak it out. Tap the mic when you're done." }
        return "Read it. Then tap the mic and speak it aloud."
    }

    @ViewBuilder
    private var micButtonView: some View {
        ZStack {
            if verifier.isRecording {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(Color.white.opacity(max(0, 0.28 - Double(i) * 0.08)), lineWidth: 1.5)
                        .frame(width: 90 + CGFloat(i * 32), height: 90 + CGFloat(i * 32))
                        .scaleEffect(ringScale)
                }
            }
            Button(action: handleMicTap) {
                ZStack {
                    Circle()
                        .fill(verifier.isRecording ? Color.red.opacity(0.85) : Color.white.opacity(0.2))
                        .frame(width: 80, height: 80)
                    if verifier.isTranscribing {
                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: verifier.isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: verifier.isRecording)
            }
            .disabled(verifier.isTranscribing)
        }
        .frame(height: 160)
    }

    private func handleMicTap() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        if verifier.isRecording {
            Task {
                let matchPct = await verifier.stopAndTranscribe()
                if matchPct >= matchThreshold {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    withAnimation(.easeInOut(duration: 0.45)) { phase = .complete }
                } else {
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    withAnimation(.easeInOut(duration: 0.3)) { phase = .retry }
                }
            }
        } else {
            phase = .idle
            Task { try? await verifier.startRecording() }
        }
    }
}
