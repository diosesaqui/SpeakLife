//
//  NotificationScene.swift
//  SpeakLife
//
//  Personalized notification onboarding — copy driven by SurveyPersonalizationEngine.
//  Start time is pre-seeded from the user's survey Q8 answer.
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
               
                
                TimeNotificationCountView(value: appState.startTimeIndex) {
                    Text("Start_time", comment: "notification start time")
                    
                } valueTime:  { valueTime in
                    appState.startTimeNotification = valueTime
                } valueIndex: { valueIndex in
                    appState.startTimeIndex = valueIndex
                }
                
                .foregroundColor(appState.onBoardingTest ? .white : Constants.DEABlack)
                .frame(width: size.width * 0.87 ,height: size.height * 0.09)

                TimeNotificationCountView(value: appState.endTimeIndex) {
                    Text("End_time", comment: "notification end time")
                } valueTime: { valueTime in
                    appState.endTimeNotification = valueTime
                } valueIndex: { valueIndex in
                    appState.endTimeIndex = valueIndex
                }
                .foregroundColor(appState.onBoardingTest ? .white : Constants.DEABlack)
               
                .frame(width: size.width * 0.87 ,height: size.height * 0.09)
                }

                Spacer()
                
                
            }
            
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
            
            Spacer()
                .frame(width: 5, height: size.height * 0.07)
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
