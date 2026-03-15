//
//  EmailConfirmationView.swift
//  SpeakLife
//
//  Shown to premium users who already have a locally stored email.
//  Lets them confirm (or skip) — on confirm, Firestore record is
//  updated with source: "post_purchase" so Meta Lookalike can use it.
//

import SwiftUI
import FirebaseAnalytics

struct EmailConfirmationView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var subscriptionStore: SubscriptionStore

    /// Pre-filled from AppState.email (AppStorage)
    let storedEmail: String

    @State private var isConfirming = false
    @State private var confirmed = false
    @State private var errorMessage: String?

    private let emailService = EmailMarketingService.shared

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "envelope.badge.fill")
                .font(.system(size: 44))
                .foregroundColor(.blue)
                .padding(.top, 8)

            Text("Confirm Your Email")
                .font(.title2)
                .fontWeight(.semibold)

            Text("We have this email on file for your account. Confirm it to stay connected and receive updates.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            // Read-only email display
            HStack {
                Image(systemName: "envelope")
                    .foregroundColor(.blue)
                Text(storedEmail)
                    .font(.body)
                    .fontWeight(.medium)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(10)
            .padding(.horizontal)

            if let error = errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }

            if confirmed {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                    Text("Email confirmed!")
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                }
                .transition(.scale.combined(with: .opacity))
            } else {
                Button(action: confirmEmail) {
                    if isConfirming {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        Text("Confirm Email")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
                .disabled(isConfirming)
                .padding(.horizontal)

                Button("This isn't my email") {
                    // Let them update — dismiss and re-open capture sheet
                    markShown()
                    subscriptionStore.showEmailConfirmAfterPurchase = false
                    appState.needEmail = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        subscriptionStore.showEmailCaptureAfterPurchase = true
                    }
                }
                .font(.footnote)
                .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .animation(.easeInOut, value: confirmed)
        .onDisappear {
            markShown()
        }
    }

    private func confirmEmail() {
        guard !storedEmail.isEmpty else {
            // No email stored — switch to capture sheet instead
            markShown()
            subscriptionStore.showEmailConfirmAfterPurchase = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                subscriptionStore.showEmailCaptureAfterPurchase = true
            }
            return
        }

        isConfirming = true
        errorMessage = nil

        Analytics.logEvent("email_confirm_attempt", parameters: [
            "source": "post_purchase_confirm"
        ])

        Task {
            do {
                try await emailService.addSubscriber(
                    email: storedEmail,
                    firstName: nil,
                    source: "post_purchase"
                )

                Analytics.logEvent("email_confirm_success", parameters: [
                    "source": "post_purchase_confirm"
                ])

                await MainActor.run {
                    isConfirming = false
                    confirmed = true
                    markShown()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        subscriptionStore.showEmailConfirmAfterPurchase = false
                    }
                }
            } catch {
                Analytics.logEvent("email_confirm_failed", parameters: [
                    "source": "post_purchase_confirm",
                    "error": error.localizedDescription
                ])
                await MainActor.run {
                    isConfirming = false
                    // Mark as shown so they're not stuck in a loop — they can retry from Settings
                    markShown()
                    errorMessage = "Something went wrong. You can update your email anytime in Settings."
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        subscriptionStore.showEmailConfirmAfterPurchase = false
                    }
                }
            }
        }
    }

    private func markShown() {
        UserDefaults.standard.set(true, forKey: "hasConfirmedPostPurchaseEmail")
    }
}
