//
//  TrialEndingBanner.swift
//  SpeakLife
//
//  Shown on HomeView on trial day 3. Surfaces user stats + inline convert CTA.
//

import SwiftUI
import FirebaseAnalytics

struct TrialEndingBanner: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @EnvironmentObject var declarationStore: DeclarationViewModel
    @State private var showPaywall = false
    @State private var dismissed = false

    private var declarationCount: Int { TrialExperienceService.shared.declarationCountDuringTrial }

    var body: some View {
        if !dismissed && TrialExperienceService.shared.isTrialActive && TrialExperienceService.shared.trialDay >= 3 && !subscriptionStore.isPremium {
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Your free trial ends today")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)

                        if declarationCount > 0 {
                            Text("You've spoken \(declarationCount) declarations in 3 days.")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.75))
                        }

                        Text("Don't stop what's already working.")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.75))
                    }

                    Spacer()

                    Button(action: { dismissed = true }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }

                Button(action: {
                    Analytics.logEvent("trial_banner_cta_tapped", parameters: [
                        "declaration_count": declarationCount,
                        "trial_day": TrialExperienceService.shared.trialDay
                    ])
                    showPaywall = true
                }) {
                    Text("Continue My Journey")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 25).fill(Constants.DAMidBlue))
                }
                .padding(.top, 12)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(LinearGradient(
                        colors: [Color(red:0.12,green:0.07,blue:0.28), Color(red:0.07,green:0.10,blue:0.22)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Constants.DAMidBlue.opacity(0.4), lineWidth: 1))
            )
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .onAppear {
                Analytics.logEvent("trial_ending_banner_shown", parameters: [
                    "declaration_count": declarationCount
                ])
            }
            .fullScreenCover(isPresented: $showPaywall) {
                OptimizedSubscriptionView { showPaywall = false }
                    .environmentObject(subscriptionStore)
                    .environmentObject(declarationStore)
            }
        }
    }
}
