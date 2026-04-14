//
//  NotificationScene.swift
//  SpeakLife
//
//  Personalized notification onboarding — driven by SurveyPersonalizationEngine.
//  Headline, stat line, and CTA copy all reflect the user's survey goal word.
//  Start time is pre-seeded from the user's survey notification timing answer.
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

    private var copy: SurveyNotificationCopy {
        engine.notificationCopy
    }

    var body: some View {
        personalizedNotificationScene(size: size)
    }

    private func personalizedNotificationScene(size: CGSize) -> some View {
        VStack(spacing: 0) {
            Spacer().frame(height: size.height * 0.07)

            // Header
            VStack(spacing: 14) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.white.opacity(0.9))

                Text(copy.headline)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.75)
                    .padding(.horizontal, 28)

                Text(copy.subheadline)
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .lineSpacing(2)
            }

            Spacer().frame(height: 20)

            // Stat pill
            HStack(spacing: 6) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.green)
                Text(copy.statLine)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.1))
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.15), lineWidth: 1))
            )
            .padding(.horizontal, 28)

            Spacer().frame(height: 28)

            // Time controls
            VStack(spacing: 14) {
                StepperNotificationCountView(appState.notificationCount) { valueCount in
                    appState.notificationCount = valueCount
                }
                .foregroundColor(.white)
                .frame(width: size.width * 0.87, height: size.height * 0.09)

                TimeNotificationCountView(value: appState.startTimeIndex) {
                    Text("Start time")
                } valueTime: { valueTime in
                    appState.startTimeNotification = valueTime
                } valueIndex: { valueIndex in
                    appState.startTimeIndex = valueIndex
                }
                .foregroundColor(.white)
                .frame(width: size.width * 0.87, height: size.height * 0.09)

                TimeNotificationCountView(value: appState.endTimeIndex) {
                    Text("End time")
                } valueTime: { valueTime in
                    appState.endTimeNotification = valueTime
                } valueIndex: { valueIndex in
                    appState.endTimeIndex = valueIndex
                }
                .foregroundColor(.white)
                .frame(width: size.width * 0.87, height: size.height * 0.09)
            }

            Spacer()

            // CTA
            VStack(spacing: 10) {
                Button(action: callBack) {
                    Text(copy.ctaText)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Capsule().fill(Color.white))
                }
                .padding(.horizontal, 28)

                HStack(spacing: 4) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.green)
                    Text("You can update these anytime in Settings")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(.bottom, size.height * 0.07)
        }
        .frame(width: size.width, height: size.height)
        .background(
            ZStack {
                Image(subscriptionStore.onboardingBGImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .edgesIgnoringSafeArea(.all)
                LinearGradient(
                    colors: [Color.black.opacity(0.75), Color.black.opacity(0.5)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .edgesIgnoringSafeArea(.all)
            }
        )
    }
}
