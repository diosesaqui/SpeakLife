//
//  ReferralView.swift
//  SpeakLife
//
//  "Invite 3 friends, get a free month." Shown to non-subscribers from the
//  Profile → Premium section. Sharing builds an App Store link carrying the
//  user's referral code; the reward is granted server-side by the referral
//  Cloud Functions and applied via a RevenueCat promotional entitlement.
//

import SwiftUI
import FirebaseAnalytics

struct ReferralView: View {

    @ObservedObject private var service = ReferralService.shared

    @State private var enteredCode = ""
    @State private var redeemMessage: String?
    @State private var redeemSucceeded = false
    @State private var isRedeeming = false
    @State private var showShareSheet = false

    private let threshold = ReferralService.rewardThreshold

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                header
                progressCard
                inviteCard
                redeemCard
            }
            .padding()
            .padding(.bottom, 40)
        }
        .background(Color(red: 0.05, green: 0.07, blue: 0.16).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .foregroundColor(.white)
        .sheet(isPresented: $showShareSheet) {
            if let code = service.code {
                ShareSheet(activityItems: [service.shareMessage(for: code), service.shareURL(for: code)])
            }
        }
        .onAppear {
            Analytics.logEvent(Event.referralScreenViewed, parameters: nil)
            Task {
                await service.ensureCode()
                await service.refreshStatus()
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "gift.fill")
                .font(.system(size: 44))
                .foregroundColor(Constants.DAMidBlue)
            Text("Invite \(threshold) Friends, Get a Free Month")
                .font(.title2).bold()
                .multilineTextAlignment(.center)
            Text("Share SpeakLife with \(threshold) friends who join. When they do, a free month of Premium is yours.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(.top, 12)
    }

    private var progressCard: some View {
        VStack(spacing: 14) {
            HStack {
                Text("\(service.progressInCycle) of \(threshold) friends joined")
                    .font(.headline)
                Spacer()
            }
            ProgressView(value: Double(service.progressInCycle), total: Double(threshold))
                .tint(Constants.DAMidBlue)
            if service.rewardsEarned > 0 {
                HStack {
                    Image(systemName: "checkmark.seal.fill").foregroundColor(.green)
                    Text("You've earned \(service.rewardsEarned) free month\(service.rewardsEarned == 1 ? "" : "s")!")
                        .font(.subheadline).bold()
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.06))
        .cornerRadius(16)
    }

    private var inviteCard: some View {
        VStack(spacing: 16) {
            Text("YOUR INVITE CODE")
                .font(.caption).foregroundColor(.white.opacity(0.6))
            Text(service.code ?? "• • •")
                .font(.system(.title, design: .monospaced)).bold()
                .foregroundColor(Constants.DAMidBlue)

            Button {
                Analytics.logEvent(Event.referralInviteTapped, parameters: nil)
                Task {
                    if await service.ensureCode() != nil { showShareSheet = true }
                }
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Invite Friends").bold()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Constants.DAMidBlue)
                .foregroundColor(.white)
                .cornerRadius(14)
            }
            .disabled(service.code == nil)
        }
        .padding()
        .background(Color.white.opacity(0.06))
        .cornerRadius(16)
    }

    private var redeemCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Have a code from a friend?")
                .font(.headline)
            HStack {
                TextField("Enter code", text: $enteredCode)
                    .textInputAutocapitalization(.characters)
                    .disableAutocorrection(true)
                    .padding(12)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(10)
                    .foregroundColor(.white)

                Button {
                    Task { await redeem() }
                } label: {
                    Text("Redeem").bold()
                        .padding(.horizontal, 16).padding(.vertical, 12)
                        .background(Constants.DAMidBlue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(isRedeeming || enteredCode.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            if let redeemMessage {
                Text(redeemMessage)
                    .font(.footnote)
                    .foregroundColor(redeemSucceeded ? .green : .orange)
            }
        }
        .padding()
        .background(Color.white.opacity(0.06))
        .cornerRadius(16)
    }

    // MARK: - Actions

    private func redeem() async {
        isRedeeming = true
        defer { isRedeeming = false }
        redeemMessage = nil
        do {
            let result = try await service.redeem(code: enteredCode)
            switch result {
            case .granted:
                redeemSucceeded = true
                redeemMessage = "Code applied! Enjoy your bonus trial."
                enteredCode = ""
            case .alreadyRedeemed:
                redeemSucceeded = false
                redeemMessage = "You've already used a referral code."
            case .invalidCode:
                redeemSucceeded = false
                redeemMessage = "That code isn't valid. Double-check it and try again."
            case .selfReferral:
                redeemSucceeded = false
                redeemMessage = "You can't redeem your own code."
            case .alreadyPremium:
                redeemSucceeded = false
                redeemMessage = "You're already Premium, so this code isn't needed."
            }
        } catch {
            redeemSucceeded = false
            redeemMessage = "Something went wrong. Please try again."
        }
    }
}
