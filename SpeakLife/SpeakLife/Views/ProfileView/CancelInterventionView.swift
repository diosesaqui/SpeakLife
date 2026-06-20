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
import StoreKit

struct CancelInterventionView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @ObservedObject private var preferencesTracker = UserPreferencesTracker.shared
    let onProceedToCancel: () -> Void

    @State private var step: Step = .reason
    @State private var selectedReason: CancelReason? = nil
    @State private var isPurchasing = false
    @State private var purchaseError: String? = nil

    enum Step { case reason, retention, discount, confirm }

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
                    case .reason:    reasonStep
                    case .retention: retentionStep
                    case .discount:  discountStep
                    case .confirm:   confirmStep
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
        .navigationViewStyle(.stack)
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
                                Analytics.logEvent("cancel_reason_selected", parameters: ["reason": reason.rawValue as NSString])
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

                    // Proceed to discount offers
                    Button(action: {
                        Analytics.logEvent("cancel_intervention_not_retained", parameters: ["reason": reason.rawValue])
                        withAnimation { step = .discount }
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

    // MARK: - Step 4: Confirm
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

    // MARK: - Step 3: Discount Offer

    private var discountProducts: [(product: Product, label: String)] {
        let candidates: [(Product?, String)] = [
            (subscriptionStore.currentOfferedDiscount,        "Best Deal"),
            (subscriptionStore.currentOfferedPremium,         "Annual"),
            (subscriptionStore.currentOfferedPremiumMonthly,  "Premium"),
            (subscriptionStore.currentOfferedMonthly,         "Monthly"),
            (subscriptionStore.currentOfferedWeekly,          "Weekly"),
            (subscriptionStore.currentOfferedLifetime,        "Lifetime"),
        ]
        var seen = Set<String>()
        return candidates.compactMap { product, label -> (Product, String)? in
            guard let p = product, seen.insert(p.id).inserted else { return nil }
            return (p, label)
        }
    }

    private var discountStep: some View {
        let products = discountProducts
        return VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 12) {
                        Text("🎁")
                            .font(.system(size: 48))
                            .padding(.top, 32)
                        Text("Before you go — a better deal")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        Text("Switch to a plan that fits your budget and keep everything you've built.")
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.65))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    if products.isEmpty {
                        Text("No alternative plans available right now.")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.5))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(products, id: \.product.id) { item in
                                discountProductCard(product: item.product, label: item.label)
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    if let error = purchaseError {
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundColor(.red.opacity(0.85))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    Spacer(minLength: 20)
                }
            }

            Button(action: {
                Analytics.logEvent("cancel_intervention_declined_discount", parameters: [:])
                withAnimation { step = .confirm }
            }) {
                Text("No thanks, cancel my subscription")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.35))
                    .padding(.vertical, 16)
            }
            .padding(.bottom, 8)
        }
    }

    private func discountProductCard(product: Product, label: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.displayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    Text(product.description)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(2)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(label)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Constants.DAMidBlue)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Constants.DAMidBlue.opacity(0.15)))
                    Text(product.displayPrice)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
            }

            Button(action: {
                Task { await purchaseProduct(product) }
            }) {
                HStack(spacing: 8) {
                    if isPurchasing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.85)
                    }
                    Text(isPurchasing ? "Processing..." : "Switch to this plan")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous).fill(Constants.DAMidBlue))
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isPurchasing)
        }
        .padding(DS.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.12), lineWidth: 1))
        )
    }

    @MainActor
    private func purchaseProduct(_ product: Product) async {
        isPurchasing = true
        purchaseError = nil
        do {
            let success = try await subscriptionStore.purchase(product, paywallName: "cancel_intervention")
            if success {
                Analytics.logEvent("cancel_intervention_discount_purchased", parameters: [
                    "product_id": product.id as NSString
                ])
                isPresented = false
            }
        } catch {
            purchaseError = "Purchase failed. Please try again."
            Analytics.logEvent("cancel_intervention_discount_failed", parameters: [
                "product_id": product.id as NSString
            ])
        }
        isPurchasing = false
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
            .padding(DS.Spacing.md)
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
