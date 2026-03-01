//
//  CancelInterventionView.swift
//  SpeakLife
//
//  Cancel flow intervention — shows before user reaches Apple's cancel screen.
//  Goal: surface value, offer pause framing, convert at least 20% of cancellers.
//  Replaces CancellationConfirmationView.
//

import SwiftUI
import FirebaseAnalytics

struct CancelInterventionView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @ObservedObject private var preferencesTracker = UserPreferencesTracker.shared
    let onProceedToCancel: () -> Void

    @State private var step: Step = .reason
    @State private var selectedReason: CancelReason? = nil

    enum Step { case reason, retention, confirm }

    enum CancelReason: String, CaseIterable {
        case tooExpensive   = "It's too expensive"
        case notUsing       = "I'm not using it enough"
        case missingFeature = "Missing a feature I need"
        case technical      = "Technical issues"
        case other          = "Other reason"

        var retentionMessage: String {
            switch self {
            case .tooExpensive:
                return "We get it — every dollar counts. Remember you're locked into your current rate. If you cancel and come back, prices may be higher."
            case .notUsing:
                return "Life gets busy. But 5 minutes of declarations a day is enough to rewire how you think. What if you just set a daily reminder and gave it one more week?"
            case .missingFeature:
                return "We're building fast. What's missing matters to us — your feedback directly shapes what we build next."
            case .technical:
                return "We're sorry you hit a problem. Most issues clear up after a quick reinstall. Before you go, would you give us a chance to fix it?"
            case .other:
                return "Whatever brought you here, thank you for being part of the SpeakLife community. The Word you've been speaking over your life doesn't stop working."
            }
        }

        var retentionCTA: String {
            switch self {
            case .tooExpensive:   return "Keep My Rate & Stay"
            case .notUsing:       return "Set a Reminder & Stay"
            case .missingFeature: return "Stay & Share Feedback"
            case .technical:      return "I'll Try Again"
            case .other:          return "Actually, I'll Stay"
            }
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.05, green: 0.05, blue: 0.12).ignoresSafeArea()

                VStack(spacing: 0) {
                    switch step {
                    case .reason:   reasonStep
                    case .retention: retentionStep
                    case .confirm:  confirmStep
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { isPresented = false }
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .onAppear {
            Analytics.logEvent("cancel_intervention_shown", parameters: [
                "user_category": preferencesTracker.primaryCategory.rawValue
            ])
        }
    }

    // MARK: - Step 1: Reason
    private var reasonStep: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Text("😔")
                            .font(.system(size: 48))
                        Text("Before you go...")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                        Text("Help us understand what went wrong so we can do better.")
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.65))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .padding(.top, 32)

                    // Streak reminder
                    streakReminderCard

                    // Reason picker
                    VStack(spacing: 10) {
                        ForEach(CancelReason.allCases, id: \.self) { reason in
                            Button(action: {
                                selectedReason = reason
                                Analytics.logEvent("cancel_reason_selected", parameters: ["reason": reason.rawValue])
                                withAnimation { step = .retention }
                            }) {
                                HStack {
                                    Text(reason.rawValue)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(.white)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white.opacity(0.4))
                                }
                                .padding(.horizontal, 20).padding(.vertical, 16)
                                .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.07)))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }

            // Skip to confirm
            Button(action: {
                Analytics.logEvent("cancel_skipped_reason", parameters: [:])
                withAnimation { step = .confirm }
            }) {
                Text("Skip & cancel anyway")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.35))
                    .padding(.vertical, 16)
            }
        }
    }

    // MARK: - Step 2: Retention
    private var retentionStep: some View {
        guard let reason = selectedReason else { return AnyView(EmptyView()) }
        return AnyView(
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 28) {
                        // Value they've built
                        VStack(spacing: 12) {
                            Text("🙏")
                                .font(.system(size: 48))
                                .padding(.top, 32)
                            Text("Don't lose what you've built")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                            Text(reason.retentionMessage)
                                .font(.system(size: 15))
                                .foregroundColor(.white.opacity(0.75))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }

                        // What they lose card
                        loseValueCard

                        Spacer(minLength: 20)
                    }
                }

                // Buttons
                VStack(spacing: 12) {
                    // Stay button
                    Button(action: {
                        Analytics.logEvent("cancel_intervention_retained", parameters: [
                            "reason": reason.rawValue,
                            "step": "retention"
                        ])
                        isPresented = false
                    }) {
                        Text(reason.retentionCTA)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 17)
                            .background(RoundedRectangle(cornerRadius: 30).fill(Constants.DAMidBlue))
                    }
                    .buttonStyle(PlainButtonStyle())

                    // Proceed to cancel
                    Button(action: {
                        Analytics.logEvent("cancel_intervention_not_retained", parameters: ["reason": reason.rawValue])
                        withAnimation { step = .confirm }
                    }) {
                        Text("I still want to cancel")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.35))
                            .padding(.vertical, 12)
                    }
                }
                .padding(.horizontal, 24).padding(.bottom, 24)
            }
        )
    }

    // MARK: - Step 3: Confirm
    private var confirmStep: some View {
        VStack(spacing: 28) {
            Spacer()
            VStack(spacing: 16) {
                Text("We'll miss you 💙")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                Text("You can manage or cancel your subscription through Apple. Your current rate won't be available if you return.")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                Text("The declarations you've been speaking are still working. Come back anytime.")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            Spacer()
            VStack(spacing: 16) {
                Button(action: {
                    Analytics.logEvent("cancel_intervention_stayed_last_chance", parameters: [:])
                    isPresented = false
                }) {
                    Text("Actually, I'll stay")
                        .font(.system(size: 17, weight: .bold)).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 17)
                        .background(RoundedRectangle(cornerRadius: 30).fill(Constants.DAMidBlue))
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: {
                    Analytics.logEvent("cancel_confirmed_proceed", parameters: [:])
                    isPresented = false
                    onProceedToCancel()
                }) {
                    Text("Cancel Subscription")
                        .font(.system(size: 15))
                        .foregroundColor(.red.opacity(0.7))
                        .padding(.vertical, 12)
                }
            }
            .padding(.horizontal, 24).padding(.bottom, 32)
        }
    }

    // MARK: - Streak Reminder Card
    private var streakReminderCard: some View {
        let streak = UserDefaults.standard.integer(forKey: "currentStreak")
        guard streak > 0 else { return AnyView(EmptyView()) }
        return AnyView(
            HStack(spacing: 14) {
                Text("🔥")
                    .font(.system(size: 28))
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(streak)-day streak")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    Text("Cancelling will put this at risk.")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.6))
                }
                Spacer()
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.orange.opacity(0.15)).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.orange.opacity(0.3), lineWidth: 1)))
            .padding(.horizontal, 20)
        )
    }

    // MARK: - Lose Value Card
    private var loseValueCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("What you'd be giving up:")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
            loseRow(icon: "text.bubble.fill",    text: "Unlimited Scripture declarations across all categories")
            loseRow(icon: "waveform",             text: "All audio meditations & faith-building series")
            loseRow(icon: "book.fill",            text: "Daily devotionals & Bible reading plans")
            loseRow(icon: "flame.fill",           text: "Your streak, badges & spiritual growth history")
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.05)).overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1)))
        .padding(.horizontal, 20)
    }

    private func loseRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(Constants.DAMidBlue)
                .frame(width: 18)
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
    }
}
