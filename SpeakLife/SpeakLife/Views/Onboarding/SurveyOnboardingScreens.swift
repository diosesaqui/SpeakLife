//
//  SurveyOnboardingScreens.swift
//  SpeakLife
//

import SwiftUI
import FirebaseAnalytics

// MARK: - Shared Components

private struct SurveyOptionRow: View {
    let text: String
    let isSelected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: { UIImpactFeedbackGenerator(style: .light).impactOccurred(); action() }) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().strokeBorder(isSelected ? Color.white : Color.white.opacity(0.35), lineWidth: 1.5).frame(width: 22, height: 22)
                    if isSelected { Circle().fill(Color.white).frame(width: 12, height: 12) }
                }
                Text(text).font(.system(size: 15, weight: isSelected ? .semibold : .regular, design: .rounded))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.8)).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isSelected ? Color.white.opacity(0.15) : Color.white.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isSelected ? Color.white.opacity(0.5) : Color.white.opacity(0.12), lineWidth: 1)))
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isSelected)
        }.buttonStyle(PlainButtonStyle())
    }
}

private struct SurveyCheckRow: View {
    let text: String
    let isSelected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: { UIImpactFeedbackGenerator(style: .light).impactOccurred(); action() }) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(isSelected ? Color.white : Color.white.opacity(0.35), lineWidth: 1.5).frame(width: 22, height: 22)
                    if isSelected { Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundColor(.white) }
                }
                Text(text).font(.system(size: 15, weight: isSelected ? .semibold : .regular, design: .rounded))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.8)).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isSelected ? Color.white.opacity(0.15) : Color.white.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isSelected ? Color.white.opacity(0.5) : Color.white.opacity(0.12), lineWidth: 1)))
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isSelected)
        }.buttonStyle(PlainButtonStyle())
    }
}

private struct SurveyContinueButton: View {
    let label: String; let isEnabled: Bool; let action: () -> Void
    init(label: String = "Continue", isEnabled: Bool = true, action: @escaping () -> Void) {
        self.label = label; self.isEnabled = isEnabled; self.action = action
    }
    var body: some View {
        Button(action: action) {
            Text(label).font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(isEnabled ? .black : .white.opacity(0.4))
                .frame(maxWidth: .infinity).frame(height: 56)
                .background(Capsule().fill(isEnabled ? Color.white : Color.white.opacity(0.12)))
        }.disabled(!isEnabled).padding(.horizontal, 28).animation(.easeInOut(duration: 0.2), value: isEnabled)
    }
}

private struct SurveyQuestionHeader: View {
    let question: String; let subtitle: String?
    init(_ question: String, subtitle: String? = nil) { self.question = question; self.subtitle = subtitle }
    var body: some View {
        VStack(spacing: 8) {
            Text(question).font(.system(size: 26, weight: .bold, design: .rounded)).foregroundColor(.white)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            if let sub = subtitle {
                Text(sub).font(.system(size: 15, weight: .regular, design: .rounded)).foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            }
        }.padding(.horizontal, 28)
    }
}

// MARK: - Intro

struct SurveyIntroScreen: View {
    let size: CGSize; let onContinue: () -> Void
    @State private var h = false; @State private var s = false; @State private var b = false
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 28) {
                VStack(spacing: 12) {
                    Text("Before we build your experience —").font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.75)).multilineTextAlignment(.center)
                        .opacity(h ? 1 : 0).offset(y: h ? 0 : 16).animation(.easeOut(duration: 0.6), value: h)
                    Text("we need to understand\nwhat you're carrying.").font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white).multilineTextAlignment(.center)
                        .opacity(h ? 1 : 0).offset(y: h ? 0 : 16).animation(.easeOut(duration: 0.6).delay(0.1), value: h)
                }
                Text("9 questions. Your answers shape your declarations, your devotionals, and your first breakthrough.")
                    .font(.system(size: 16, weight: .regular, design: .rounded)).foregroundColor(.white.opacity(0.65))
                    .multilineTextAlignment(.center).padding(.horizontal, 36)
                    .opacity(s ? 1 : 0).offset(y: s ? 0 : 12).animation(.easeOut(duration: 0.5), value: s)
            }
            Spacer()
            SurveyContinueButton(label: "Let's Begin") { onContinue() }
                .padding(.bottom, 52).opacity(b ? 1 : 0).offset(y: b ? 0 : 20).animation(.easeOut(duration: 0.5), value: b)
        }
        .onAppear {
            withAnimation { h = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { withAnimation { s = true } }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { withAnimation { b = true } }
        }
    }
}

// MARK: - Q1: What feels heaviest

struct SurveyQ1BurdenScreen: View {
    let size: CGSize; @ObservedObject var responses: SurveyResponses; let onContinue: () -> Void
    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    Spacer().frame(height: size.height * 0.12)
                    SurveyQuestionHeader("What brought you to SpeakLife today?", subtitle: "Be honest. This is just between you and God.")
                    VStack(spacing: 10) {
                        ForEach(HeaviestBurden.allCases) { o in
                            SurveyOptionRow(text: o.rawValue, isSelected: responses.heaviestBurden == o) { responses.heaviestBurden = o }
                        }
                    }.padding(.horizontal, 20)
                    Spacer().frame(height: 8)
                }
            }
            SurveyContinueButton(isEnabled: responses.heaviestBurden != nil, action: onContinue)
                .padding(.vertical, 16)
        }.onAppear { Analytics.logEvent("survey_q1_shown", parameters: nil) }
    }
}

// MARK: - Q2: How long

struct SurveyQ2DurationScreen: View {
    let size: CGSize; @ObservedObject var responses: SurveyResponses; let onContinue: () -> Void
    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    Spacer().frame(height: size.height * 0.12)
                    SurveyQuestionHeader("How long have you been carrying this?")
                    if responses.heaviestBurden != nil {
                        Text("Thank you for being honest. That took courage.")
                            .font(.system(size: 14, weight: .medium, design: .rounded)).foregroundColor(.white.opacity(0.55))
                            .multilineTextAlignment(.center).padding(.horizontal, 32)
                    }
                    VStack(spacing: 10) {
                        ForEach(BurdenDuration.allCases) { o in
                            SurveyOptionRow(text: o.rawValue, isSelected: responses.burdenDuration == o) { responses.burdenDuration = o }
                        }
                    }.padding(.horizontal, 20)
                    Spacer().frame(height: 8)
                }
            }
            SurveyContinueButton(isEnabled: responses.burdenDuration != nil, action: onContinue)
                .padding(.vertical, 16)
        }.onAppear { Analytics.logEvent("survey_q2_shown", parameters: nil) }
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

    private var headline: String {
        switch responses.heaviestBurden {
        case .prosperity:  return "You're not building this alone."
        case .calling:     return "You're not walking this alone."
        default:           return "You're not carrying this alone."
        }
    }

    private var subtext: String {
        switch responses.heaviestBurden {
        case .prosperity:
            return "Over 100,000 men and women have opened SpeakLife hungry for more — more abundance, more provision, more of what God promised.\n\nYou're in good company."
        case .calling:
            return "Over 100,000 believers have opened SpeakLife asking God to make their faith unshakeable — and found that daily declaration is what moved the needle.\n\nYou're in good company."
        default:
            return "Over 100,000 men and women have opened SpeakLife carrying the same weight you just described.\n\nThe feelings are real. So is the way out."
        }
    }

    private var testimonial: TestimonialReview {
        switch responses.heaviestBurden {
        case .anxiety:
            return TestimonialReview(
                quote: "\"I've had anxiety for 12 years. After 3 weeks of daily declarations, my mornings changed. I finally feel like myself.\"",
                author: "— Sarah M., Texas"
            )
        case .purpose:
            return TestimonialReview(
                quote: "\"I felt lost for years — no direction, no clarity. SpeakLife helped me hear God's voice again. I finally know what I'm here for.\"",
                author: "— Marcus T., Georgia"
            )
        case .worthiness:
            return TestimonialReview(
                quote: "\"I used to wake up every day feeling like I wasn't enough. After 30 days of declarations, I stopped apologizing for existing.\"",
                author: "— Keisha R., Atlanta"
            )
        case .joyless:
            return TestimonialReview(
                quote: "\"I hadn't felt real joy in two years. I thought I just had to live that way. Then I started declaring God's Word every morning. Something shifted.\"",
                author: "— Tanya B., Ohio"
            )
        case .hardSeason:
            return TestimonialReview(
                quote: "\"I was in the darkest season of my life, health issues, barely holding on. SpeakLife was the daily anchor that kept me standing.\"",
                author: "— Rachel D., Florida"
            )
        case .prosperity:
            return TestimonialReview(
                quote: "\"I was stuck in a scarcity mindset for years. After speaking abundance declarations daily, my business doubled in 90 days. God's Word works.\"",
                author: "— Angela W., Dallas"
            )
        case .calling:
            return TestimonialReview(
                quote: "\"My faith used to crumble under pressure. After 30 days of declaring God's Word, I stopped doubting and started standing. My whole life shifted.\"",
                author: "— Marcus T., Atlanta"
            )
        case .none:
            return TestimonialReview(
                quote: "\"After 3 weeks of daily declarations, my mornings changed. I finally feel like myself.\"",
                author: "— Sarah M., Texas"
            )
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 32) {
                VStack(spacing: 14) {
                    Text(headline)
                        .font(.system(size: 28, weight: .bold, design: .rounded)).foregroundColor(.white).multilineTextAlignment(.center)
                        .opacity(v ? 1 : 0).offset(y: v ? 0 : 20)
                    Text(subtext)
                        .font(.system(size: 16, weight: .regular, design: .rounded)).foregroundColor(.white.opacity(0.75)).multilineTextAlignment(.center).padding(.horizontal, 32)
                        .opacity(v ? 1 : 0).offset(y: v ? 0 : 16).animation(.easeOut(duration: 0.5).delay(0.15), value: v)
                }
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 2) { ForEach(0..<5, id: \.self) { _ in Image(systemName: "star.fill").font(.system(size: 11)).foregroundColor(.yellow) } }
                    Text(testimonial.quote)
                        .font(.system(size: 14, weight: .regular, design: .rounded)).foregroundColor(.white.opacity(0.85)).italic().fixedSize(horizontal: false, vertical: true)
                    Text(testimonial.author).font(.system(size: 12, weight: .medium, design: .rounded)).foregroundColor(.white.opacity(0.5))
                }
                .padding(18)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.08))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.white.opacity(0.14), lineWidth: 1)))
                .padding(.horizontal, 28).opacity(v ? 1 : 0).offset(y: v ? 0 : 12).animation(.easeOut(duration: 0.5).delay(0.3), value: v)
            }
            Spacer()
            SurveyContinueButton(label: "Keep Going") { onContinue() }
                .padding(.bottom, 52).opacity(v ? 1 : 0).animation(.easeOut(duration: 0.4).delay(0.5), value: v)
        }
        .onAppear { withAnimation(.easeOut(duration: 0.6)) { v = true } }
    }
}

// MARK: - Q3: Failed attempts

struct SurveyQ3AttemptsScreen: View {
    let size: CGSize; @ObservedObject var responses: SurveyResponses; let onContinue: () -> Void

    private var questionText: String {
        switch responses.heaviestBurden {
        case .prosperity: return "What have you already tried in pursuit of this?"
        case .calling:    return "What have you tried to grow your faith before?"
        default:          return "Have you tried to fight through this before?"
        }
    }
    private var options: [PreviousAttempt] {
        switch responses.heaviestBurden {
        case .prosperity: return PreviousAttempt.aspirationOptions
        case .calling:    return PreviousAttempt.faithOptions
        default:          return PreviousAttempt.painOptions
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    Spacer().frame(height: size.height * 0.12)
                    SurveyQuestionHeader(questionText, subtitle: "Select all that apply.")
                    VStack(spacing: 10) {
                        ForEach(options) { o in
                            SurveyCheckRow(text: o.rawValue, isSelected: responses.previousAttempts.contains(o)) {
                                if responses.previousAttempts.contains(o) { responses.previousAttempts.remove(o) }
                                else { responses.previousAttempts.insert(o) }
                            }
                        }
                    }.padding(.horizontal, 20)
                    Spacer().frame(height: 8)
                }
            }
            SurveyContinueButton(isEnabled: !responses.previousAttempts.isEmpty, action: onContinue)
                .padding(.vertical, 16)
        }.onAppear { Analytics.logEvent("survey_q3_shown", parameters: nil) }
    }
}

// MARK: - Q4: Inner lie

struct SurveyQ4LieScreen: View {
    let size: CGSize; @ObservedObject var responses: SurveyResponses; let onContinue: () -> Void

    private var questionText: String {
        switch responses.heaviestBurden {
        case .prosperity: return "What thought keeps you from believing this is really possible for you?"
        case .calling:    return "What thought makes it hard to fully trust God and step into deeper faith?"
        default:          return "When you're at your lowest — what's going through your mind?"
        }
    }
    private var options: [InnerLie] {
        switch responses.heaviestBurden {
        case .prosperity: return InnerLie.aspirationOptions
        case .calling:    return InnerLie.faithOptions
        default:          return InnerLie.painOptions
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    Spacer().frame(height: size.height * 0.12)
                    SurveyQuestionHeader(questionText, subtitle: "Pick the one that hits closest to home.")
                    VStack(spacing: 10) {
                        ForEach(options) { o in
                            SurveyOptionRow(text: o.rawValue, isSelected: responses.innerLie == o) { responses.innerLie = o }
                        }
                    }.padding(.horizontal, 20)
                    Spacer().frame(height: 8)
                }
            }
            SurveyContinueButton(isEnabled: responses.innerLie != nil, action: onContinue)
                .padding(.vertical, 16)
        }.onAppear { Analytics.logEvent("survey_q4_shown", parameters: nil) }
    }
}

// MARK: - Interstitial B

struct SurveyInterstitialBScreen: View {
    let size: CGSize; let onContinue: () -> Void
    @State private var v = false
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 28) {
                VStack(spacing: 14) {
                    Text("Here's what 100,000 people have discovered.").font(.system(size: 26, weight: .bold, design: .rounded)).foregroundColor(.white)
                        .multilineTextAlignment(.center).padding(.horizontal, 28).opacity(v ? 1 : 0).offset(y: v ? 0 : 20)
                    Text("Every thought you just named?\nIt didn't come from God.").font(.system(size: 17, weight: .semibold, design: .rounded)).foregroundColor(.white.opacity(0.85))
                        .multilineTextAlignment(.center).padding(.horizontal, 28)
                        .opacity(v ? 1 : 0).offset(y: v ? 0 : 16).animation(.easeOut(duration: 0.5).delay(0.1), value: v)
                    Text("Most people try willpower, motivation, or one-time decisions. But none of it sticks.\n\nThe people who actually change — they build a daily habit of speaking God's truth until it rewires everything.")
                        .font(.system(size: 15, weight: .regular, design: .rounded)).foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center).padding(.horizontal, 32)
                        .opacity(v ? 1 : 0).offset(y: v ? 0 : 12).animation(.easeOut(duration: 0.5).delay(0.2), value: v)
                }
                VStack(spacing: 6) {
                    Text("\"Death and life are in the power of the tongue.\"").font(.system(size: 16, weight: .semibold, design: .serif)).foregroundColor(.white)
                        .multilineTextAlignment(.center).italic().padding(.horizontal, 32)
                    Text("Proverbs 18:21").font(.system(size: 13, weight: .medium, design: .rounded)).foregroundColor(.white.opacity(0.45))
                }.opacity(v ? 1 : 0).animation(.easeOut(duration: 0.5).delay(0.35), value: v)
            }
            Spacer()
            SurveyContinueButton(label: "Build the Habit") { onContinue() }
                .padding(.bottom, 52).opacity(v ? 1 : 0).animation(.easeOut(duration: 0.4).delay(0.5), value: v)
        }
        .onAppear { withAnimation(.easeOut(duration: 0.6)) { v = true } }
    }
}

// MARK: - Q5: Declaration experience

struct SurveyQ5DeclarationExpScreen: View {
    let size: CGSize; @ObservedObject var responses: SurveyResponses; let onContinue: () -> Void
    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    Spacer().frame(height: size.height * 0.12)
                    SurveyQuestionHeader("Have you ever spoken God's Word out loud over your life — and felt something shift?")
                    VStack(spacing: 10) {
                        ForEach(DeclarationExperience.allCases) { o in
                            SurveyOptionRow(text: o.rawValue, isSelected: responses.declarationExperience == o) { responses.declarationExperience = o }
                        }
                    }.padding(.horizontal, 20)
                    Spacer().frame(height: 8)
                }
            }
            SurveyContinueButton(isEnabled: responses.declarationExperience != nil, action: onContinue)
                .padding(.vertical, 16)
        }.onAppear { Analytics.logEvent("survey_q5_shown", parameters: nil) }
    }
}

// MARK: - Q6: Future pacing

struct SurveyQ6FutureScreen: View {
    let size: CGSize; @ObservedObject var responses: SurveyResponses; let onContinue: () -> Void

    private var questionText: String {
        switch responses.heaviestBurden {
        case .prosperity: return "When you walk in financial abundance — what opens up?"
        case .calling:    return "What would your life look like if you truly believed every promise God made you?"
        default:          return "If this was no longer your battle — what would change first?"
        }
    }
    private var options: [FutureChange] {
        switch responses.heaviestBurden {
        case .prosperity: return FutureChange.prosperityOptions
        case .calling:    return FutureChange.callingOptions
        default:          return FutureChange.painOptions
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    Spacer().frame(height: size.height * 0.12)
                    SurveyQuestionHeader(questionText, subtitle: "Choose up to 2.")
                    VStack(spacing: 10) {
                        ForEach(options) { o in
                            let sel = responses.futureChanges.contains(o)
                            SurveyCheckRow(text: o.rawValue, isSelected: sel) {
                                if sel { responses.futureChanges.remove(o) }
                                else if responses.futureChanges.count < 2 { responses.futureChanges.insert(o) }
                            }
                        }
                    }.padding(.horizontal, 20)
                    Spacer().frame(height: 8)
                }
            }
            SurveyContinueButton(isEnabled: !responses.futureChanges.isEmpty, action: onContinue)
                .padding(.vertical, 16)
        }.onAppear { Analytics.logEvent("survey_q6_shown", parameters: nil) }
    }
}

// MARK: - Q7: Readiness

struct SurveyQ7ReadinessScreen: View {
    let size: CGSize; @ObservedObject var responses: SurveyResponses; let onContinue: () -> Void
    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    Spacer().frame(height: size.height * 0.12)
                    SurveyQuestionHeader("How serious are you about making a change — starting today?")
                    VStack(spacing: 10) {
                        ForEach(ReadinessLevel.allCases) { o in
                            SurveyOptionRow(text: o.rawValue, isSelected: responses.readinessLevel == o) { responses.readinessLevel = o }
                        }
                    }.padding(.horizontal, 20)
                    Spacer().frame(height: 8)
                }
            }
            SurveyContinueButton(isEnabled: responses.readinessLevel != nil, action: onContinue)
                .padding(.vertical, 16)
        }.onAppear { Analytics.logEvent("survey_q7_shown", parameters: nil) }
    }
}

// MARK: - Q8: Notification time

struct SurveyQ8NotificationScreen: View {
    let size: CGSize; @ObservedObject var responses: SurveyResponses; let onContinue: () -> Void
    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    Spacer().frame(height: size.height * 0.12)
                    SurveyQuestionHeader("Habits are built at the same time every day.", subtitle: "When should we show up for you?")
                    VStack(spacing: 10) {
                        ForEach(NotificationTime.allCases) { o in
                            SurveyOptionRow(text: o.rawValue, isSelected: responses.notificationTime == o) { responses.notificationTime = o }
                        }
                    }.padding(.horizontal, 20)
                    Spacer().frame(height: 8)
                }
            }
            SurveyContinueButton(isEnabled: responses.notificationTime != nil, action: onContinue)
                .padding(.vertical, 16)
        }.onAppear { Analytics.logEvent("survey_q8_shown", parameters: nil) }
    }
}

// MARK: - Q9: Goal word

struct SurveyQ9GoalWordScreen: View {
    let size: CGSize; @ObservedObject var responses: SurveyResponses; let onContinue: () -> Void
    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    Spacer().frame(height: size.height * 0.12)
                    SurveyQuestionHeader("One last thing.", subtitle: "Choose the word you're believing God for:")
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(SurveyGoalWord.allCases) { word in
                            let sel = responses.goalWord == word
                            Button {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                responses.goalWord = word
                            } label: {
                                VStack(spacing: 10) {
                                    Image(systemName: word.icon).font(.system(size: 24)).foregroundColor(sel ? .white : .white.opacity(0.6))
                                    Text(word.rawValue).font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(.white)
                                    Text(word.tagline).font(.system(size: 11, weight: .regular, design: .rounded)).foregroundColor(.white.opacity(0.6))
                                        .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(.vertical, 18).padding(.horizontal, 12).frame(maxWidth: .infinity, minHeight: 140)
                                .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(sel ? Color.white.opacity(0.18) : Color.white.opacity(0.06))
                                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .strokeBorder(sel ? Color.white.opacity(0.6) : Color.white.opacity(0.12), lineWidth: 1.5)))
                                .scaleEffect(sel ? 1.03 : 1.0).animation(.spring(response: 0.3, dampingFraction: 0.7), value: sel)
                            }.buttonStyle(PlainButtonStyle())
                        }
                    }.padding(.horizontal, 20)
                    Spacer().frame(height: 8)
                }
            }
            SurveyContinueButton(label: "This Is My Goal", isEnabled: responses.goalWord != nil, action: onContinue)
                .padding(.vertical, 16)
        }
        .onAppear {
            if responses.goalWord == nil { responses.goalWord = responses.heaviestBurden?.goalWord }
            Analytics.logEvent("survey_q9_shown", parameters: nil)
        }
    }
}

// MARK: - Goal Reveal

struct SurveyGoalRevealScreen: View {
    let size: CGSize; @ObservedObject var responses: SurveyResponses; let onContinue: () -> Void
    @State private var cv = false; @State private var chv = false
    private var goalWord: SurveyGoalWord { responses.resolvedGoalWord }
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 28) {
                ZStack {
                    Circle().fill(Color.white.opacity(0.1)).frame(width: 72, height: 72)
                    Image(systemName: goalWord.icon).font(.system(size: 32)).foregroundColor(.white)
                }
                .scaleEffect(cv ? 1 : 0.5).opacity(cv ? 1 : 0).animation(.spring(response: 0.5, dampingFraction: 0.65), value: cv)

                VStack(spacing: 14) {
                    Text("Here's what we built for you.").font(.system(size: 22, weight: .semibold, design: .rounded)).foregroundColor(.white.opacity(0.7)).multilineTextAlignment(.center)
                        .opacity(cv ? 1 : 0).animation(.easeOut(duration: 0.5).delay(0.15), value: cv)
                    VStack(spacing: 10) {
                        Text("You've been carrying \(responses.burdenShortLabel) — \(responses.durationLabel).")
                            .font(.system(size: 16, weight: .semibold, design: .rounded)).foregroundColor(.white).multilineTextAlignment(.center)
                        Text("You've tried to push through. Things helped for a moment. But nothing stuck.\n\nBecause real change isn't a moment — it's a habit.\n\n30 days of speaking God's Word out loud, every single day, over the exact thing you named. That's what rewires you. That's what SpeakLife builds.")
                            .font(.system(size: 15, weight: .regular, design: .rounded)).foregroundColor(.white.opacity(0.7)).multilineTextAlignment(.center).lineSpacing(3)
                    }
                    .opacity(cv ? 1 : 0).offset(y: cv ? 0 : 12).animation(.easeOut(duration: 0.5).delay(0.25), value: cv)
                }.padding(.horizontal, 28)

                VStack(spacing: 8) {
                    Text("YOUR GOAL").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(.white.opacity(0.5)).tracking(1.2)
                    Text(goalWord.rawValue).font(.system(size: 28, weight: .black, design: .rounded)).foregroundColor(.white)
                    Text(goalWord.challengeName).font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundColor(.white.opacity(0.75))
                }
                .padding(.vertical, 24).frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.white.opacity(0.1))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Color.white.opacity(0.25), lineWidth: 1)))
                .padding(.horizontal, 28)
                .scaleEffect(chv ? 1 : 0.92).opacity(chv ? 1 : 0).animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.4), value: chv)
            }
            Spacer()
            SurveyContinueButton(label: "Start My \(responses.resolvedGoalWord.challengeName)") { onContinue() }
                .padding(.bottom, 52).opacity(chv ? 1 : 0).animation(.easeOut(duration: 0.4).delay(0.6), value: chv)
        }
        .onAppear {
            withAnimation { cv = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { withAnimation { chv = true } }
            Analytics.logEvent("survey_goal_reveal_shown", parameters: ["goal_word": goalWord.rawValue])
        }
    }
}
