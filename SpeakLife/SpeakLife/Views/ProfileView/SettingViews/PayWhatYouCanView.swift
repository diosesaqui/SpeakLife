//
//  PayWhatYouCanView.swift
//  SpeakLife
//
//  A "pay what you can afford" paywall that lists every active IAP product
//  so users can subscribe at a price that works for them. Also satisfies
//  App Store Review guideline 3.1.1 — all active IAP products must be
//  accessible from within the app.
//

import SwiftUI
import StoreKit
import FirebaseAnalytics

struct PayWhatYouCanView: View {

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var declarationStore: DeclarationViewModel
    @EnvironmentObject var subscriptionStore: SubscriptionStore

    @State private var selectedProduct: Product?
    @State private var isShowingError = false
    @State private var errorMessage = ""

    var callback: (() -> Void)?

    // All active products sorted cheapest → most expensive.
    // Exclude the devotional one-time product — it's unrelated to this screen.
    private var allProducts: [Product] {
        let subs     = subscriptionStore.subscriptions
        let nonCons  = subscriptionStore.nonConsumables.filter { $0.id != "Devotionals30SL" }
        return (subs + nonCons).sorted { $0.price < $1.price }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    headerView
                    productsSection
                    ctaSection
                    footerLinks
                    Spacer().frame(height: 24)
                }
            }

            if declarationStore.isPurchasing {
                RotatingLoadingImageView()
            }
        }
        .onAppear {
            selectedProduct = allProducts.first
            Analytics.logEvent("pay_what_you_can_viewed", parameters: nil)
        }
        .alert("Purchase Error", isPresented: $isShowingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 14) {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            Image(systemName: "heart.fill")
                .font(.system(size: 48))
                .foregroundColor(Color(red: 0.95, green: 0.35, blue: 0.5))

            Text("Pay What You Can")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Text("Every plan unlocks all of SpeakLife Premium.\nChoose whatever fits your budget — God sees the heart.")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.70))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 28)
        }
    }

    // MARK: - Products list

    private var productsSection: some View {
        VStack(spacing: 10) {
            ForEach(allProducts, id: \.id) { product in
                productRow(product)
            }
        }
        .padding(.horizontal, 20)
    }

    private func productRow(_ product: Product) -> some View {
        let isSelected = selectedProduct?.id == product.id

        return Button(action: { selectedProduct = product }) {
            HStack(spacing: 14) {
                // Radio-style selector
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? Color.yellow : Color.gray.opacity(0.6), lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(Color.yellow)
                            .frame(width: 12, height: 12)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(productLabel(product))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    Text(productSubtitle(product))
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.55))
                }

                Spacer()

                Text(product.displayPrice)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(isSelected ? Color.yellow : .white.opacity(0.9))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.yellow.opacity(0.07) : Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.yellow : Color.gray.opacity(0.25), lineWidth: isSelected ? 1.5 : 0.5)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - CTA

    private var ctaSection: some View {
        VStack(spacing: 8) {
            Button(action: makePurchase) {
                Text(selectedProduct != nil
                     ? "Continue with \(selectedProduct!.displayPrice)"
                     : "Select a Plan")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(selectedProduct != nil ? Color.yellow : Color.gray)
                    .cornerRadius(28)
                    .padding(.horizontal, 20)
            }
            .disabled(selectedProduct == nil)

            if let product = selectedProduct {
                Text(product.costDescription)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.45))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }
        }
    }

    // MARK: - Footer

    private var footerLinks: some View {
        HStack(spacing: 20) {
            Button("Restore Purchases", action: restore)
                .font(.caption)
                .underline()
                .foregroundColor(.blue)

            Link("Terms & Conditions",
                 destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                .font(.caption)
                .underline()
                .foregroundColor(.blue)
        }
    }

    // MARK: - Label helpers

    private func productLabel(_ product: Product) -> String {
        if product.id == lifetimeID { return "Lifetime Access" }
        guard let sub = product.subscription else { return product.displayName }
        switch sub.subscriptionPeriod.unit {
        case .week:  return "Weekly"
        case .month: return "Monthly"
        case .year:  return "Yearly"
        default:     return product.displayName
        }
    }

    private func productSubtitle(_ product: Product) -> String {
        if product.id == lifetimeID { return "One-time payment — yours forever" }
        guard let sub = product.subscription else { return "" }
        switch sub.subscriptionPeriod.unit {
        case .week:  return "Billed weekly, cancel anytime"
        case .month: return "Billed monthly, cancel anytime"
        case .year:
            if sub.introductoryOffer != nil {
                return "Includes free trial, billed yearly, cancel anytime"
            }
            return "Billed annually, cancel anytime"
        default: return "Cancel anytime"
        }
    }

    // MARK: - Actions

    private func makePurchase() {
        guard let product = selectedProduct else { return }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        Analytics.logEvent("pay_what_you_can_tapped", parameters: [
            "product_id": product.id,
            "price": NSDecimalNumber(decimal: product.price).doubleValue
        ])
        Task {
            await MainActor.run { declarationStore.isPurchasing = true }
            defer {
                Task {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    await MainActor.run { declarationStore.isPurchasing = false }
                }
            }
            do {
                if try await subscriptionStore.purchase(product, paywallName: "PayWhatYouCan") {
                    callback?()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isShowingError = true
                }
            }
        }
    }

    private func restore() {
        Task {
            await MainActor.run { declarationStore.isPurchasing = true }
            await subscriptionStore.restore()
            await MainActor.run { declarationStore.isPurchasing = false }
        }
    }
}

// MARK: - Preview

struct PayWhatYouCanView_Previews: PreviewProvider {
    static var previews: some View {
        PayWhatYouCanView()
            .environmentObject(SubscriptionStore())
            .environmentObject(DeclarationViewModel())
    }
}
