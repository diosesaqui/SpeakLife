//
//  ThreeDayChallengeView.swift
//  SpeakLife
//

import SwiftUI
import FirebaseAnalytics

struct ThreeDayChallengeCard: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var manager: ThreeDayChallengeManager
    @EnvironmentObject var tabViewModel: TabViewModel
    @State private var showCompletionSheet = false
    @State private var cardVisible = false

    private var engine: SurveyPersonalizationEngine { SurveyPersonalizationEngine(goalWordRaw: appState.surveyGoalWord) }
    private var goalWord: SurveyGoalWord? { SurveyGoalWord(rawValue: appState.surveyGoalWord) }
    private var challengeName: String { engine.paywallCopy.challengeName }
    private var currentDay: Int { manager.currentDayNumber ?? 1 }

    private struct DayContent { let title: String; let action: String; let ctaLabel: String }
    private func content(for day: Int) -> DayContent {
        switch day {
        case 1: return DayContent(title: "Day 1 — Speak It", action: "Read and declare today's declarations out loud. Your voice is the weapon.", ctaLabel: "Start Day 1")
        case 2: return DayContent(title: "Day 2 — Go Deeper", action: "Return to your declarations. Say them out loud. Feel the shift.", ctaLabel: "Start Day 2")
        case 3: return DayContent(title: "Day 3 — Finish Strong", action: "Complete your final session. Three days of truth changes the trajectory.", ctaLabel: "Complete My Challenge")
        default: return DayContent(title: "", action: "", ctaLabel: "")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: goalWord?.icon ?? "flame.fill").font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
                Text(challengeName.uppercased()).font(.system(size: 11, weight: .bold, design: .rounded)).foregroundColor(.white.opacity(0.9)).tracking(1.0)
                Spacer()
                HStack(spacing: 5) {
                    ForEach(1...3, id: \.self) { day in
                        Circle().fill(manager.isDayComplete(day) ? Color.white : Color.white.opacity(0.3)).frame(width: 7, height: 7)
                    }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(challengeGradient)

            let dayContent = content(for: currentDay)
            VStack(alignment: .leading, spacing: 10) {
                Text(dayContent.title).font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(.white)
                Text(dayContent.action).font(.system(size: 13, weight: .regular, design: .rounded)).foregroundColor(.white.opacity(0.75)).fixedSize(horizontal: false, vertical: true)
                Button { handleDayCTA(day: currentDay) } label: {
                    Text(dayContent.ctaLabel).font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(challengeAccentColor).padding(.horizontal, 16).padding(.vertical, 8)
                        .background(Capsule().fill(Color.white))
                }
            }
            .padding(16).background(Color.black.opacity(0.55))
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.white.opacity(0.15), lineWidth: 1))
        .padding(.horizontal, 16)
        .shadow(color: Color.black.opacity(0.3), radius: 12, x: 0, y: 4)
        .scaleEffect(cardVisible ? 1 : 0.95).opacity(cardVisible ? 1 : 0)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: cardVisible)
        .onAppear {
            withAnimation { cardVisible = true }
            Analytics.logEvent("challenge_card_shown", parameters: ["day": currentDay, "goal_word": appState.surveyGoalWord])
        }
        .sheet(isPresented: $showCompletionSheet) {
            ChallengeCompletionSheet(challengeName: challengeName, goalWord: goalWord).environmentObject(appState)
        }
    }

    private var challengeGradient: LinearGradient {
        let c: [Color]
        switch goalWord {
        case .peace:      c = [Color(red:0.2,green:0.4,blue:0.7), Color(red:0.1,green:0.3,blue:0.6)]
        case .identity:   c = [Color(red:0.4,green:0.2,blue:0.7), Color(red:0.3,green:0.1,blue:0.6)]
        case .purpose:    c = [Color(red:0.8,green:0.3,blue:0.1), Color(red:0.7,green:0.2,blue:0.0)]
        case .joy:        c = [Color(red:0.8,green:0.6,blue:0.0), Color(red:0.7,green:0.5,blue:0.0)]
        case .confidence: c = [Color(red:0.2,green:0.5,blue:0.8), Color(red:0.1,green:0.4,blue:0.7)]
        case .healing:    c = [Color(red:0.1,green:0.5,blue:0.3), Color(red:0.0,green:0.4,blue:0.2)]
        case .none:       c = [Color(red:0.2,green:0.4,blue:0.7), Color(red:0.1,green:0.3,blue:0.6)]
        }
        return LinearGradient(colors: c, startPoint: .leading, endPoint: .trailing)
    }

    private var challengeAccentColor: Color {
        switch goalWord {
        case .purpose: return Color(red:0.8,green:0.3,blue:0.1)
        case .joy:     return Color(red:0.8,green:0.6,blue:0.0)
        default:       return Color(red:0.1,green:0.3,blue:0.6)
        }
    }

    private func handleDayCTA(day: Int) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        Analytics.logEvent("challenge_day_cta_tapped", parameters: ["day": day, "goal_word": appState.surveyGoalWord])
        if day == 3 { manager.completeDay(3); showCompletionSheet = true }
        else { manager.completeDay(day); tabViewModel.resetToHome() }
    }
}

struct ChallengeCompletionSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    let challengeName: String
    let goalWord: SurveyGoalWord?
    @State private var v = false

    var body: some View {
        ZStack {
            Color(red:0.07,green:0.08,blue:0.18).ignoresSafeArea()
            VStack(spacing: 32) {
                Spacer()
                ZStack {
                    Circle().fill(Color.white.opacity(0.1)).frame(width: 100, height: 100)
                    Image(systemName: "checkmark.seal.fill").font(.system(size: 52)).foregroundColor(.yellow)
                }
                .scaleEffect(v ? 1 : 0.5).opacity(v ? 1 : 0).animation(.spring(response: 0.5, dampingFraction: 0.6), value: v)

                VStack(spacing: 12) {
                    Text("Challenge Complete.").font(.system(size: 28, weight: .black, design: .rounded)).foregroundColor(.white)
                    Text("You finished your \(challengeName).\nThree days of speaking truth over your life.")
                        .font(.system(size: 16, weight: .regular, design: .rounded)).foregroundColor(.white.opacity(0.75)).multilineTextAlignment(.center).padding(.horizontal, 32)
                }
                .opacity(v ? 1 : 0).offset(y: v ? 0 : 20).animation(.easeOut(duration: 0.5).delay(0.2), value: v)

                VStack(spacing: 6) {
                    Text("\"Let the weak say, 'I am strong.'\"").font(.system(size: 15, weight: .semibold, design: .serif)).foregroundColor(.white.opacity(0.85)).italic()
                    Text("Joel 3:10").font(.system(size: 12, weight: .medium, design: .rounded)).foregroundColor(.white.opacity(0.4))
                }
                .opacity(v ? 1 : 0).animation(.easeOut(duration: 0.5).delay(0.35), value: v)

                Spacer()
                VStack(spacing: 12) {
                    Button { Analytics.logEvent("challenge_completed_keep_going", parameters: ["goal_word": appState.surveyGoalWord]); dismiss() } label: {
                        Text("Keep Going — Don't Stop Now").font(.system(size: 17, weight: .bold, design: .rounded)).foregroundColor(.black)
                            .frame(maxWidth: .infinity).frame(height: 56).background(Capsule().fill(Color.white))
                    }.padding(.horizontal, 28)
                    Button { dismiss() } label: {
                        Text("Done").font(.system(size: 14, weight: .medium, design: .rounded)).foregroundColor(.white.opacity(0.45))
                    }
                }
                .opacity(v ? 1 : 0).animation(.easeOut(duration: 0.4).delay(0.5), value: v).padding(.bottom, 48)
            }
        }
        .onAppear {
            withAnimation { v = true }
            Analytics.logEvent("challenge_completed", parameters: ["challenge_name": challengeName, "goal_word": appState.surveyGoalWord])
        }
    }
}
