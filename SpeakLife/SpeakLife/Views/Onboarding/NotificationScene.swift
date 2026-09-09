//
//  NotificationScene.swift
//  SpeakLife
//
//  Personalized notification onboarding — copy driven by SurveyPersonalizationEngine.
//  The delivery window is fixed at all day (7 AM to 9 PM); users narrow it
//  in Settings → Reminders.
//

import SwiftUI

struct NotificationOnboarding: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @EnvironmentObject var appState: AppState

    let size: CGSize
    let callBack: (() -> Void)

    private var engine: SurveyPersonalizationEngine {
        SurveyPersonalizationEngine(goalWordRaw: appState.surveyGoalWord)
    }
    private var copy: SurveyNotificationCopy { engine.notificationCopy }

    var body: some View {
        notificationSceneAlt(size: size)
    }
    
    private var allDayWindowRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "sun.max.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.yellow)
            VStack(alignment: .leading, spacing: 2) {
                Text("All day anchoring")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(appState.onBoardingTest ? .white : Constants.DEABlack)
                Text("7:00 AM to 9:00 PM. Nothing overnight.")
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor((appState.onBoardingTest ? Color.white : Constants.DEABlack).opacity(0.7))
            }
            Spacer()
        }
        .padding()
        .overlay(RoundedRectangle(cornerRadius: 20)
            .stroke(Constants.DAMidBlue, lineWidth: 1))
    }

    private func notificationSceneAlt(size: CGSize) -> some View  {
        VStack {
            // Progress dots at top
            HStack {
                Spacer()
                ProgressDots(current: 2, total: 5)
                    .padding(.top, 10)
                    .padding(.trailing, 20)
            }
            
            if appState.onBoardingTest {
                Spacer().frame(height: 30)
            } else {
                Spacer().frame(height: 50)
                
                Image("Notifications_illustration")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 235, height: size.height * 0.20)
                Spacer().frame(height: 20)
            }
            
            VStack {
                Text(copy.headline)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.7)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)

                Spacer().frame(height: 10)

                Text(copy.subheadline)
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Spacer().frame(height: 16)

                VStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 13, weight: .semibold)).foregroundColor(.green)
                        Text(copy.statLine)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.85)).multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Capsule().fill(Color.white.opacity(0.1))
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.15), lineWidth: 1)))
                }
                .frame(width: size.width * 0.85)
                
                Spacer().frame(height: 28)
                
                VStack (spacing: 16) {
                StepperNotificationCountView(appState.notificationCount) { valueCount in
                    appState.notificationCount = valueCount
                    
                }
                .foregroundColor(appState.onBoardingTest ? .white : Constants.DEABlack)
                .frame(width: size.width * 0.87 ,height: size.height * 0.09)

                // The start/end pickers are gone from onboarding. Everyone
                // starts anchored all day and narrows the window later in
                // Settings → Reminders if they want to — asking someone to
                // pick a 3-hour band before they have seen a single
                // declaration land was a choice they had no basis to make.
                allDayWindowRow
                    .frame(width: size.width * 0.87)
                }

                Spacer()


            }
            .dsAppear(0)

            VStack(spacing: 12) {
                ShimmerButton(colors: [.blue], buttonTitle: copy.ctaText, action: callBack)
                .frame(width: size.width * 0.87 ,height: 50)
                
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.green)
                    Text("You can change these anytime in settings")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(appState.onBoardingTest ? .white.opacity(0.7) : Constants.DALightBlue.opacity(0.7))
                }
            }
            .dsAppear(0.06)

            Spacer()
                .frame(width: 5, height: size.height * 0.07)
        }
        .onAppear {
            // Onboarding always hands the user the all-day window. Seeding it
            // here (rather than relying on the @AppStorage default) also covers
            // a replayed onboarding, where a previously narrowed window would
            // otherwise survive a flow that no longer offers a way to widen it.
            appState.startTimeIndex = NotificationWindow.defaultStartIndex
            appState.endTimeIndex = NotificationWindow.defaultEndIndex
        }
        .frame(width: size.width, height: size.height)
        .background(
            ZStack {
                Image(subscriptionStore.onboardingBGImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .edgesIgnoringSafeArea(.all)
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
            }
        )
    }
    
}
