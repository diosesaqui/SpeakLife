//
//  LapsedPaywallView.swift
//  SpeakLife
//
//  The wall an onboarded user sees once their premium trial or subscription
//  has ended without renewing. It replaces the app (HomeView swaps it in when
//  `SubscriptionStore.showsLapsedWall`), so there is no close button: the way
//  through is to resubscribe or restore.
//
//  Leads with an Apple win-back offer when RevenueCat says this user is
//  eligible for one on the yearly product (iOS 18+, configured in App Store
//  Connect). Everyone else sees the regular yearly price. A trialist who never
//  paid is ineligible under Apple's win-back rules, so expect them on the
//  regular price.
//

import SwiftUI
import StoreKit
import RevenueCat

struct LapsedPaywallView: View {

    @EnvironmentObject var subscriptionStore: SubscriptionStore

    @State private var winBackOffer: WinBackOffer?
    /// True once the win-back lookup for the current product has answered, so
    /// the price never flips from full to discounted under the user's thumb.
    @State private var offerResolved = false
    @State private var isPurchasing = false
    @State private var errorMessage: String?
    @State private var showPrivacyPolicy = false
    @State private var hasTrackedImpression = false
    /// The yearly product could not be loaded after retrying. The wall then
    /// offers Try again instead of a spinner that never ends.
    @State private var productLoadFailed = false
    @State private var shownAt = Date()

    private static let paywallName = "lapsed_wall_v1"

    private var product: Product? { subscriptionStore.currentOfferedPremium }

    var body: some View {
        ZStack {
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
        }
        .task(id: product?.id) { await resolveOffer() }
        .task { await loadProduct() }
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

            Text(winBackOffer != nil ? "Welcome back. We saved you a gift." : "Welcome back")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Text(subscriptionStore.lapsedFromTrial
                 ? "Your free week has ended. Keep speaking life over every area of your day."
                 : "Your membership has ended. Pick up right where you left off.")
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
            benefitRow(icon: "flame.fill", title: "Your streak and plan", detail: "Everything you built is still here, waiting for you.")
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
            if let product, offerResolved {
                priceBlock(for: product)
            } else if productLoadFailed {
                VStack(spacing: 6) {
                    Text("We couldn't reach the App Store.")
                        .font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                    Button("Try again") { Task { await loadProduct() } }
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
                        Text(winBackOffer != nil ? "Claim my offer" : "Continue")
                            .font(.system(size: 17, weight: .bold)).foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity).padding(.vertical, 17)
                .background(RoundedRectangle(cornerRadius: 30).fill(LinearGradient(colors: [Constants.DAMidBlue, Constants.DAMidBlue.opacity(0.85)], startPoint: .leading, endPoint: .trailing)))
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isPurchasing || product == nil || !offerResolved)
            .opacity(isPurchasing || product == nil || !offerResolved ? 0.7 : 1.0)

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

    /// The amount billed is the most prominent price on screen (App Review
    /// 3.1.2): the offer price when there is one, with the renewal price under it.
    @ViewBuilder
    private func priceBlock(for product: Product) -> some View {
        let renewal = "\(product.displayPrice)/year"
        if let discount = winBackOffer?.discount {
            VStack(spacing: 4) {
                Text(offerHeadline(discount))
                    .font(.system(size: 20, weight: .bold)).foregroundColor(.white)
                Text("then \(renewal)")
                    .font(.system(size: 14)).foregroundColor(.white.opacity(0.65))
            }
            .multilineTextAlignment(.center)
        } else {
            Text(renewal)
                .font(.system(size: 20, weight: .bold)).foregroundColor(.white)
        }
    }

    // MARK: - Offer copy

    private func offerHeadline(_ discount: StoreProductDiscount) -> String {
        switch discount.paymentMode {
        case .freeTrial:
            return "Free for \(duration(discount.subscriptionPeriod, times: discount.numberOfPeriods))"
        case .payUpFront:
            return "\(discount.localizedPriceString) for \(duration(discount.subscriptionPeriod, times: discount.numberOfPeriods))"
        case .payAsYouGo:
            return "\(discount.localizedPriceString)/\(unitName(discount.subscriptionPeriod.unit, plural: false)) for \(duration(discount.subscriptionPeriod, times: discount.numberOfPeriods))"
        @unknown default:
            return discount.localizedPriceString
        }
    }

    private func duration(_ period: RevenueCat.SubscriptionPeriod, times: Int) -> String {
        let count = period.value * max(times, 1)
        if count == 1 { return "your first \(unitName(period.unit, plural: false))" }
        return "\(count) \(unitName(period.unit, plural: true))"
    }

    private func unitName(_ unit: RevenueCat.SubscriptionPeriod.Unit, plural: Bool) -> String {
        let name: String
        switch unit {
        case .day: name = "day"
        case .week: name = "week"
        case .month: name = "month"
        case .year: name = "year"
        @unknown default: name = "period"
        }
        return plural ? name + "s" : name
    }

    // MARK: - Actions

    /// Loads the yearly product, retrying a few times so a slow or briefly
    /// offline launch does not leave the wall without a price. The products
    /// request swallows its own errors, so a still-nil product is the signal.
    private func loadProduct() async {
        productLoadFailed = false
        for attempt in 0..<3 {
            if product != nil { return }
            if attempt > 0 { try? await Task.sleep(nanoseconds: 3_000_000_000) }
            await subscriptionStore.requestProducts()
        }
        if product == nil {
            productLoadFailed = true
            trackImpressionOnce()
            AnalyticsService.shared.track("lapsed_paywall_product_unavailable", parameters: analyticsParams)
        }
    }

    private func resolveOffer() async {
        guard let product else { return }
        offerResolved = false
        winBackOffer = await RevenueCatManager.shared.eligibleWinBackOffer(for: product)
        offerResolved = true
        trackImpressionOnce()
    }

    private func trackImpressionOnce() {
        guard !hasTrackedImpression else { return }
        hasTrackedImpression = true
        shownAt = Date()
        AnalyticsService.shared.track("lapsed_paywall_shown", parameters: analyticsParams)
    }

    private var analyticsParams: [String: Any] {
        [
            "paywall_name": Self.paywallName,
            "lapsed_from_trial": subscriptionStore.lapsedFromTrial,
            "win_back_available": winBackOffer != nil,
            "product_id": product?.id ?? "none"
        ]
    }

    private func purchase() {
        guard let product, !isPurchasing else { return }
        isPurchasing = true
        Task {
            do {
                let outcome = try await subscriptionStore.purchaseOutcome(
                    product,
                    paywallName: Self.paywallName,
                    winBackOffer: winBackOffer
                )
                await MainActor.run {
                    isPurchasing = false
                    switch outcome {
                    case .purchased:
                        var params = analyticsParams
                        params["seconds_on_paywall"] = Int(Date().timeIntervalSince(shownAt))
                        AnalyticsService.shared.track("lapsed_paywall_converted", parameters: params)
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
                AnalyticsService.shared.track("lapsed_paywall_restore", parameters: ["restored": restored])
                if !restored { errorMessage = "No active subscription found to restore." }
            }
        }
    }
}
