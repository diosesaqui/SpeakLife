//
//  PushOfferView.swift
//  SpeakLife
//
//  The discount screen a `deepLink == "offer"` push opens for users who are
//  not subscribed. Send it from Firebase Messaging with custom data:
//
//      deepLink  = offer
//      productId = SpeakLife1YR29     (optional, this is the default)
//      campaign  = fall_40            (optional, tags the analytics)
//
//  The percentage is worked out from the two live StoreKit prices (the offer
//  product against the regular yearly product Remote Config points at), never
//  typed in. If the regular price ever drops to the offer price or below, the
//  "% off" badge disappears instead of making a false claim.
//

import SwiftUI
import StoreKit

/// What a tapped offer push asked for. Boxed for `.sheet(item:)`.
struct PushOfferRoute: Identifiable, Equatable {
    let productId: String
    let campaign: String
    var id: String { productId + campaign }

    static let defaultProductId = InAppId.Subscription.speakLife1YR29.id
}

struct PushOfferView: View {

    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @Environment(\.dismiss) private var dismiss

    let route: PushOfferRoute

    @State private var isPurchasing = false
    @State private var errorMessage: String?
    @State private var showPrivacyPolicy = false
    @State private var productLoadFailed = false
    @State private var trialEligible = false
    @State private var hasTrackedImpression = false
    @State private var shownAt = Date()

    private static let paywallName = "push_offer_v1"

    private var offerProduct: Product? {
        subscriptionStore.subscriptions.first { $0.id == route.productId }
    }

    /// The regular yearly price the discount is measured against.
    private var regularProduct: Product? { subscriptionStore.currentOfferedPremium }

    /// Whole percent off the regular yearly price, or nil when there is no
    /// honest discount to show.
    private var percentOff: Int? {
        guard let offer = offerProduct, let regular = regularProduct,
              offer.id != regular.id, regular.price > 0, offer.price < regular.price else { return nil }
        let ratio = NSDecimalNumber(decimal: (regular.price - offer.price) / regular.price).doubleValue
        let percent = Int((ratio * 100).rounded(.down))
        return percent >= 5 ? percent : nil
    }

    /// Free trial length in days, when this user can still take one.
    private var trialDays: Int? {
        guard trialEligible,
              let intro = offerProduct?.subscription?.introductoryOffer,
              intro.paymentMode == .freeTrial else { return nil }
        let period = intro.period
        let days: Int
        switch period.unit {
        case .day: days = period.value
        case .week: days = period.value * 7
        case .month: days = period.value * 30
        case .year: days = period.value * 365
        @unknown default: return nil
        }
        return days * max(intro.periodCount, 1)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: DS.Spacing.lg) {
                    header
                    benefits
                    Spacer(minLength: DS.Spacing.md)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .safeAreaInset(edge: .bottom) { footer }

            Button {
                AnalyticsService.shared.track("push_offer_dismissed", parameters: dismissParams)
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 44, height: 44)
            }
            .padding(.trailing, 8)
            .padding(.top, 8)
            .accessibilityLabel("Close")
        }
        .task(id: offerProduct?.id) { await resolveTrialEligibility() }
        .task { await loadProducts() }
        .onChange(of: subscriptionStore.isPremium) { isPremium in
            if isPremium { dismiss() }
        }
        .alert("Something went wrong", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .sheet(isPresented: $showPrivacyPolicy) { PrivacyPolicyView() }
    }

    // MARK: - Sections

    private var background: some View {
        LinearGradient(
            colors: [Color(red: 0.07, green: 0.10, blue: 0.22), Color(red: 0.12, green: 0.07, blue: 0.20), Color(red: 0.04, green: 0.04, blue: 0.12)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    private var header: some View {
        VStack(spacing: DS.Spacing.sm) {
            Image("appIconDisplay")
                .resizable().frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.2), lineWidth: 1))
                .padding(.top, 48)

            if let percentOff {
                Text("\(percentOff)% OFF")
                    .font(.system(size: 14, weight: .heavy))
                    .tracking(1.5)
                    .foregroundColor(.white)
                    .padding(.horizontal, 14).padding(.vertical, 6)
                    .background(Capsule().fill(Constants.DAMidBlue))
            }

            Text("A gift for your year ahead")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Text("Speak life over every morning of the next twelve months, for less than ever.")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.72))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 16) {
            benefitRow(icon: "sun.max.fill", title: "Your Daily Burst", detail: "Seven Scripture declarations to speak every morning.")
            benefitRow(icon: "headphones", title: "Scripture audio", detail: "Declarations and Bible audio for the commute and for sleep.")
            benefitRow(icon: "book.fill", title: "Ask the Bible", detail: "Answers rooted in God's Word, any time you need them.")
            benefitRow(icon: "flame.fill", title: "Every category unlocked", detail: "Healing, provision, peace, family and more.")
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Constants.DAMidBlue.opacity(0.35), lineWidth: 1))
    }

    private func benefitRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(Constants.DAMidBlue)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                Text(detail).font(.system(size: 13)).foregroundColor(.white.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 12) {
            if let offerProduct {
                priceBlock(for: offerProduct)
            } else if productLoadFailed {
                VStack(spacing: 6) {
                    Text("We couldn't reach the App Store.")
                        .font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                    Button("Try again") { Task { await loadProducts() } }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Constants.DAMidBlue)
                }
                .frame(minHeight: 44)
            } else {
                ProgressView().tint(.white).frame(height: 44)
            }

            Button(action: purchase) {
                Group {
                    if isPurchasing {
                        ProgressView().tint(.white)
                    } else {
                        Text(trialDays != nil ? "Start free trial" : "Claim my offer")
                            .font(.system(size: 17, weight: .bold)).foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity).padding(.vertical, 17)
                .background(RoundedRectangle(cornerRadius: 30).fill(LinearGradient(colors: [Constants.DAMidBlue, Constants.DAMidBlue.opacity(0.85)], startPoint: .leading, endPoint: .trailing)))
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isPurchasing || offerProduct == nil)
            .opacity(isPurchasing || offerProduct == nil ? 0.7 : 1.0)

            Text("Renews automatically. Cancel anytime in Settings.")
                .font(.system(size: 12)).foregroundColor(.white.opacity(0.5))

            HStack(spacing: DS.Spacing.lg) {
                Button("Restore", action: restore)
                Link("Terms", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                Button("Privacy") { showPrivacyPolicy = true }
            }
            .font(.system(size: 12)).foregroundColor(.white.opacity(0.4))
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(Color(red: 0.04, green: 0.04, blue: 0.12).opacity(0.96).ignoresSafeArea())
    }

    /// The amount billed is the most prominent price (App Review 3.1.2); the
    /// regular price sits beside it struck through, only when it is higher.
    @ViewBuilder
    private func priceBlock(for product: Product) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                if percentOff != nil, let regularProduct {
                    Text(regularProduct.displayPrice)
                        .strikethrough()
                        .font(.system(size: 17)).foregroundColor(.white.opacity(0.5))
                }
                Text("\(product.displayPrice)/year")
                    .font(.system(size: 20, weight: .bold)).foregroundColor(.white)
            }
            if let trialDays {
                Text("\(trialDays) days free, then \(product.displayPrice)/year")
                    .font(.system(size: 14)).foregroundColor(.white.opacity(0.65))
            } else {
                Text("Just \((product.price / 12).formatted(product.priceFormatStyle))/month, billed yearly")
                    .font(.system(size: 14)).foregroundColor(.white.opacity(0.65))
            }
        }
        .multilineTextAlignment(.center)
    }

    // MARK: - Actions

    private func loadProducts() async {
        productLoadFailed = false
        for attempt in 0..<3 {
            if offerProduct != nil { break }
            if attempt > 0 { try? await Task.sleep(nanoseconds: 3_000_000_000) }
            await subscriptionStore.requestProducts()
        }
        if offerProduct == nil {
            productLoadFailed = true
            AnalyticsService.shared.track("push_offer_product_unavailable", parameters: analyticsParams)
        }
    }

    private func resolveTrialEligibility() async {
        guard let subscription = offerProduct?.subscription else { return }
        trialEligible = await subscription.isEligibleForIntroOffer
        trackImpressionOnce()
    }

    private func trackImpressionOnce() {
        guard !hasTrackedImpression else { return }
        hasTrackedImpression = true
        shownAt = Date()
        AnalyticsService.shared.track("push_offer_shown", parameters: analyticsParams)
    }

    private var analyticsParams: [String: Any] {
        [
            "paywall_name": Self.paywallName,
            "campaign": route.campaign,
            "product_id": offerProduct?.id ?? route.productId,
            "regular_product_id": regularProduct?.id ?? "none",
            "percent_off": percentOff ?? 0,
            "trial_offered": trialDays != nil
        ]
    }

    private var dismissParams: [String: Any] {
        var params = analyticsParams
        params["seconds_on_paywall"] = Int(Date().timeIntervalSince(shownAt))
        return params
    }

    private func purchase() {
        guard let product = offerProduct, !isPurchasing else { return }
        isPurchasing = true
        Task {
            do {
                let outcome = try await subscriptionStore.purchaseOutcome(product, paywallName: Self.paywallName)
                await MainActor.run {
                    isPurchasing = false
                    switch outcome {
                    case .purchased:
                        AnalyticsService.shared.track("push_offer_converted", parameters: dismissParams)
                        dismiss()
                    case .pending:
                        errorMessage = "Your purchase is waiting for approval. You'll get full access as soon as it's approved."
                    case .notEntitled:
                        errorMessage = "The purchase went through but access didn't unlock. Tap Restore to try again."
                    case .cancelled:
                        break
                    }
                }
            } catch {
                await MainActor.run {
                    isPurchasing = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func restore() {
        guard !isPurchasing else { return }
        isPurchasing = true
        Task {
            let restored = await subscriptionStore.restore()
            await MainActor.run {
                isPurchasing = false
                AnalyticsService.shared.track("push_offer_restore", parameters: ["restored": restored])
                if restored { dismiss() } else { errorMessage = "No active subscription found to restore." }
            }
        }
    }
}
