//
//  CancelInterventionView.swift
//  SpeakLife
//
//  Cancel flow intervention — shows before user reaches Apple's cancel screen.
//  Goal: surface value, offer pause framing, convert at least 20% of cancellers.
//  Replaces CancellationConfirmationView.
//
//  Also home to `BillingIssueView` (bottom of file): the other place we catch a
//  subscriber on the way out, except that one never chose to leave.
//

import SwiftUI
import StoreKit

struct CancelInterventionView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @ObservedObject private var preferencesTracker = UserPreferencesTracker.shared
    let onProceedToCancel: () -> Void

    @State private var step: Step = .reason
    @State private var selectedReason: CancelReason? = nil
    @State private var reasonNote: String = ""
    @State private var noteSubmitted = false
    @State private var isPurchasing = false
    @State private var purchaseError: String? = nil
    @FocusState private var noteFocused: Bool

    enum Step { case reason, retention, discount, confirm }

    // Reason list is deliberately specific. The first version offered four
    // reasons plus "Other reason", and "Other" took nearly half of all answers —
    // which told us nothing about why anyone leaves. Every option below names a
    // real, distinct exit, and the free-text note on the next step catches
    // whatever the list still misses.
    enum CancelReason: String, CaseIterable {
        case tooExpensive    = "It's too expensive"
        case notUsing        = "I'm not using it enough"
        case missingFeature  = "Missing a feature I need"
        case notWhatExpected = "Not what I expected"
        case gotWhatINeeded  = "I got what I needed"
        case technical       = "Technical issues"
        case other           = "Something else"

        /// Reasons where the honest answer is a cheaper plan, not a paragraph.
        /// These skip the retention pitch and go straight to the offer.
        var goesStraightToOffer: Bool { self == .tooExpensive }

        var retentionMessage: String {
            switch self {
            case .tooExpensive:
                return "We get it — every dollar counts. Remember you're locked into your current rate. If you cancel and come back, prices may be higher."
            case .notUsing:
                return "Life gets busy. But 5 minutes of declarations a day is enough to rewire how you think. What if you just set a daily reminder and gave it one more week?"
            case .missingFeature:
                return "We're building fast. What's missing matters to us — your feedback directly shapes what we build next."
            case .notWhatExpected:
                return "That's on us, and we'd rather know than guess. Tell us what you were hoping for and it goes straight to the people building this."
            case .gotWhatINeeded:
                return "That's the best reason to go, and we're glad you got it. The Word you've been speaking doesn't stop working when the subscription does."
            case .technical:
                return "We're sorry you hit a problem. Most issues clear up after a quick reinstall. Before you go, would you give us a chance to fix it?"
            case .other:
                return "Whatever brought you here, thank you for being part of the SpeakLife community. The Word you've been speaking over your life doesn't stop working."
            }
        }

        var retentionCTA: String {
            switch self {
            case .tooExpensive:    return "Keep My Rate & Stay"
            case .notUsing:        return "Set a Reminder & Stay"
            case .missingFeature:  return "Stay & Share Feedback"
            case .notWhatExpected: return "Stay & Share Feedback"
            case .gotWhatINeeded:  return "Actually, I'll Stay"
            case .technical:       return "I'll Try Again"
            case .other:           return "Actually, I'll Stay"
            }
        }

        /// Prompt above the free-text box. Specific beats "Anything else?" —
        /// a pointed question is what gets an actual sentence back.
        var notePrompt: String {
            switch self {
            case .tooExpensive:    return "What would feel fair to pay?"
            case .notUsing:        return "What got in the way?"
            case .missingFeature:  return "What's missing?"
            case .notWhatExpected: return "What were you hoping for?"
            case .gotWhatINeeded:  return "What changed for you? (we'd love to hear it)"
            case .technical:       return "What went wrong?"
            case .other:           return "What made you decide?"
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
            AnalyticsService.shared.track("cancel_intervention_shown", parameters: [
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
                            .font(DS.Typography.title)
                            .foregroundColor(.white)
                        Text("Help us understand what went wrong so we can do better.")
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.65))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .padding(.top, 32)
                    .dsAppear(0)

                    // Streak reminder
                    streakReminderCard
                        .dsAppear(0.08)

                    // Reason picker
                    VStack(spacing: 10) {
                        ForEach(CancelReason.allCases, id: \.self) { reason in
                            Button(action: {
                                selectedReason = reason
                                AnalyticsService.shared.track("cancel_reason_selected", parameters: ["reason": reason.rawValue as NSString])
                                // "Too expensive" is a price objection, and the
                                // only honest answer to a price objection is a
                                // price. Skip the pitch, open with the offer.
                                withAnimation { step = reason.goesStraightToOffer ? .discount : .retention }
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
                AnalyticsService.shared.track("cancel_skipped_reason", parameters: [:])
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
                                .font(DS.Typography.title)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                            Text(reason.retentionMessage)
                                .font(.system(size: 15))
                                .foregroundColor(.white.opacity(0.75))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                        .dsAppear(0)

                        // What they lose card
                        loseValueCard
                            .dsAppear(0.08)

                        // Free-text note. The single highest-value thing on this
                        // screen: a picked-from-a-list reason tells us a bucket,
                        // this tells us the actual sentence. Always optional —
                        // both buttons below work whether or not it's filled.
                        noteField(for: reason)
                            .dsAppear(0.16)

                        Spacer(minLength: 20)
                    }
                }

                // Buttons
                VStack(spacing: 12) {
                    // Stay button
                    Button(action: {
                        submitNoteIfNeeded(reason: reason, outcome: "retained")
                        AnalyticsService.shared.track("cancel_intervention_retained", parameters: [
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
                        submitNoteIfNeeded(reason: reason, outcome: "continued_to_offer")
                        AnalyticsService.shared.track("cancel_intervention_not_retained", parameters: [
                            "reason": reason.rawValue,
                            "step": "retention"
                        ])
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

    // MARK: - Free-text Note

    private func noteField(for reason: CancelReason) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(reason.notePrompt)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))

            TextField("", text: $reasonNote, axis: .vertical)
                .lineLimit(2...4)
                .font(.system(size: 15))
                .foregroundColor(.white)
                .tint(Constants.DAMidBlue)
                .focused($noteFocused)
                // Placeholder sits on the field itself, before the padding, so
                // it lands exactly on the text origin instead of being nudged
                // into place with guessed insets.
                .overlay(alignment: .topLeading) {
                    if reasonNote.isEmpty {
                        Text("Optional, but it genuinely helps.")
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.3))
                            .allowsHitTesting(false)
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.07))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(noteFocused ? 0.25 : 0.1), lineWidth: 1)
                        )
                )
        }
        .padding(.horizontal, 20)
    }

    /// Sends the typed note once, whichever way the user leaves this step.
    /// `outcome` records what they did right after writing it, so a note that
    /// came with a save reads differently from one that came with a cancel.
    private func submitNoteIfNeeded(reason: CancelReason, outcome: String) {
        noteFocused = false
        let trimmed = reasonNote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !noteSubmitted else { return }
        noteSubmitted = true
        AnalyticsService.shared.track("cancel_reason_note", parameters: [
            "reason": reason.rawValue,
            "note": trimmed,
            "note_length": trimmed.count,
            "outcome": outcome
        ])
    }

    // MARK: - Step 4: Confirm
    private var confirmStep: some View {
        VStack(spacing: 28) {
            Spacer()
            VStack(spacing: 16) {
                Text("We'll miss you 💙")
                    .font(DS.Typography.title)
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
                    // Same event as the other two stay-paths, separated by
                    // `step`, so the save rate is one number instead of three
                    // that have to be added up by hand.
                    AnalyticsService.shared.track("cancel_intervention_retained", parameters: [
                        "reason": selectedReason?.rawValue ?? "",
                        "step": "confirm"
                    ])
                    isPresented = false
                }) {
                    Text("Actually, I'll stay")
                        .font(.system(size: 17, weight: .bold)).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 17)
                        .background(RoundedRectangle(cornerRadius: 30).fill(Constants.DAMidBlue))
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: {
                    AnalyticsService.shared.track("cancel_confirmed_proceed", parameters: [
                        "reason": selectedReason?.rawValue ?? ""
                    ])
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

    /// Alternative plans, **cheapest first**. Ordering is the whole point: this
    /// screen is shown to someone leaving, most often over price, and the old
    /// order led with Annual and Lifetime — the two most expensive things we
    /// sell. The first card someone sees on the way out has to be the smallest
    /// number we can honestly show them.
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
        let unique = candidates.compactMap { product, label -> (product: Product, label: String)? in
            guard let p = product, seen.insert(p.id).inserted else { return nil }
            return (product: p, label: label)
        }
        let sorted = unique.sorted { $0.product.price < $1.product.price }
        // Relabel the cheapest so the lead card says what it is. The configured
        // discount SKU keeps its "Best Deal" badge wherever it lands.
        return sorted.enumerated().map { index, item -> (product: Product, label: String) in
            guard index == 0, item.label != "Best Deal" else { return item }
            return (product: item.product, label: "Lowest Price")
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
                            .font(DS.Typography.title)
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

                    // Reasons that skip the retention step never get offered the
                    // note field there, and "what would feel fair to pay?" is
                    // the most useful sentence anyone on this screen can give
                    // us. Ask it here instead.
                    if let reason = selectedReason, reason.goesStraightToOffer {
                        noteField(for: reason)
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

            VStack(spacing: 12) {
                // Staying on the current plan is a real outcome here and used to
                // have no button. Someone who opened this screen to price-shop
                // and decided they were fine had to click "cancel my
                // subscription" to get out of it.
                Button(action: {
                    if let reason = selectedReason {
                        submitNoteIfNeeded(reason: reason, outcome: "retained")
                    }
                    AnalyticsService.shared.track("cancel_intervention_retained", parameters: [
                        "reason": selectedReason?.rawValue ?? "",
                        "step": "discount"
                    ])
                    isPresented = false
                }) {
                    Text("Keep my current plan")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 17)
                        .background(RoundedRectangle(cornerRadius: 30).fill(Color.white.opacity(0.12)))
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: {
                    if let reason = selectedReason {
                        submitNoteIfNeeded(reason: reason, outcome: "declined_offer")
                    }
                    AnalyticsService.shared.track("cancel_intervention_declined_discount", parameters: [
                        "reason": selectedReason?.rawValue ?? ""
                    ])
                    withAnimation { step = .confirm }
                }) {
                    Text("No thanks, cancel my subscription")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.35))
                        .padding(.vertical, 12)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
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
                if let reason = selectedReason {
                    submitNoteIfNeeded(reason: reason, outcome: "switched_plan")
                }
                AnalyticsService.shared.track("cancel_intervention_discount_purchased", parameters: [
                    "product_id": product.id as NSString,
                    "reason": selectedReason?.rawValue ?? ""
                ])
                isPresented = false
            }
        } catch {
            purchaseError = "Purchase failed. Please try again."
            AnalyticsService.shared.track("cancel_intervention_discount_failed", parameters: [
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

// MARK: - Billing Issue Recovery
//
// The silent churn path. When Apple can't charge a card it does NOT cancel the
// subscription — it enters a retry window, keeps serving the entitlement, and
// tells the user nothing. If the retries fail, the subscription simply expires
// and RevenueCat reports the loss as `BILLING_ERROR`, which is a third of our
// trial cancellations and a share of paid ones. Those subscribers never decided
// to leave. This screen is the only place they're told, and the fix is two taps.

struct BillingIssueView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @Environment(\.openURL) private var openURL

    /// Apple's payment-method settings. Deliberately not the manage-subscriptions
    /// URL — nothing is wrong with the subscription, the card is the problem.
    private static let paymentSettingsURL = URL(string: "https://apps.apple.com/account/billing")!

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.12).ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                VStack(spacing: 16) {
                    Image(systemName: "creditcard.trianglebadge.exclamationmark")
                        .font(.system(size: 46))
                        .foregroundColor(.orange)

                    Text("Your payment didn't go through")
                        .font(DS.Typography.title)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    Text("Apple couldn't charge your card, so your subscription is set to end. Nothing is lost yet. Update your payment method and everything keeps running.")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                keepAccessCard

                Spacer()

                VStack(spacing: 14) {
                    Button(action: {
                        AnalyticsService.shared.track("billing_issue_update_tapped", parameters: [:])
                        openURL(Self.paymentSettingsURL)
                        isPresented = false
                    }) {
                        Text("Update Payment Method")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 17)
                            .background(RoundedRectangle(cornerRadius: 30).fill(Constants.DAMidBlue))
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: {
                        AnalyticsService.shared.track("billing_issue_prompt_dismissed", parameters: [:])
                        isPresented = false
                    }) {
                        Text("Remind me later")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.4))
                            .padding(.vertical, 12)
                    }
                }
                .padding(.horizontal, 24).padding(.bottom, 32)
            }
        }
        .onAppear {
            AnalyticsService.shared.track("billing_issue_prompt_shown", parameters: [
                "is_trial": subscriptionStore.isInTrial
            ])
        }
    }

    private var keepAccessCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Still yours, for now:")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
            keepRow(icon: "text.bubble.fill", text: "Every declaration, across all categories")
            keepRow(icon: "waveform",         text: "All audio meditations & faith-building series")
            keepRow(icon: "flame.fill",       text: "Your streak, badges & growth history")
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.05))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
        )
        .padding(.horizontal, 20)
    }

    private func keepRow(icon: String, text: String) -> some View {
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
