//
//  SecondTryPaywallView.swift
//  SpeakLife
//
//  Shown when user dismisses the main paywall for the first time.
//  Softer framing, monthly plan only, X on TOP-LEFT (different position
//  prevents users from mindlessly double-tapping through).
//
//  Tactics applied:
//  - Second-try offer shown immediately on first dismiss (Helium recommendation)
//  - X button repositioned to top-LEFT so users can't double-tap (Helium)
//  - Shorter, less committal copy — reduce perceived risk
//  - Monthly plan only (lower ask = lower barrier)
//  - Trust signals front and center
//

import SwiftUI
import StoreKit
import FirebaseAnalytics

struct SecondTryPaywallView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var declarationStore: DeclarationViewModel
    @EnvironmentObject var subscriptionStore: SubscriptionStore

    var onConvert: (() -> Void)?
    var onSkip: (() -> Void)?

    @State private var isShowingError = false
    @State private var errorMessage = ""
    @State private var showCloseButton = false
    @State private var entryTime = Date()
    @State private var ctaPulsing = false

    private let paywallVariant = "second_try_v1"

    private var monthlyPrice: String {
        subscriptionStore.currentOfferedPremiumMonthly?.displayPrice ?? "$9.99"
    }

    var body: some View {
        ZStack {
            background.ignoresSafeArea()

            VStack(spacing: 0) {
                scrollContent
                stickyBottom
            }

            if declarationStore.isPurchasing {
                RotatingLoadingImageView()
            }

            // X button — TOP LEFT (different from main paywall's top-right)
            if showCloseButton {
                closeButton
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .onAppear {
            entryTime = Date()
            Analytics.logEvent("second_try_paywall_shown", parameters: ["variant": paywallVariant])
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation(.easeIn(duration: 0.4)) { showCloseButton = true }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                ctaPulsing = true
            }
        }
        .alert("", isPresented: $isShowingError) {
            Button("OK", role: .cancel) {}
        } message: { Text(errorMessage) }
    }

    // MARK: - Background
    private var background: some View {
        LinearGradient(
            colors: [Color(red: 0.06, green: 0.08, blue: 0.20),
                     Color(red: 0.10, green: 0.06, blue: 0.18),
                     Color(red: 0.03, green: 0.03, blue: 0.10)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    // MARK: - Scroll Content
    private var scrollContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {
                VStack(spacing: 10) {
                    Text("Still thinking about it?")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    Text("Start month-to-month — no long commitment required.")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding(.top, 60)

                // Social proof — short and punchy
                VStack(spacing: 12) {
                    secondTryTestimonial(
                        quote: "I canceled after the trial and re-subscribed a week later. Best decision I made.",
                        author: "Jordan M."
                    )
                    secondTryTestimonial(
                        quote: "No pressure, no tricks. I've been here 2 years and it keeps getting better.",
                        author: "Kezia A."
                    )
                }
                .padding(.horizontal, 24)

                // What you get — short list
                whatYouGetSection

                Spacer(minLength: 20)
            }
        }
    }

    private var whatYouGetSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            secondTryBenefit(icon: "quote.bubble.fill", text: "500+ daily declarations across 6 categories")
            secondTryBenefit(icon: "headphones", text: "Audio devotionals for morning and night")
            secondTryBenefit(icon: "bell.fill", text: "Daily push reminders to speak God's Word")
            secondTryBenefit(icon: "xmark.circle", text: "Cancel from Settings anytime — no hoops")
        }
        .padding(.horizontal, 28)
    }

    private func secondTryBenefit(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Constants.DAMidBlue)
                .frame(width: 22)
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.8))
            Spacer()
        }
    }

    private func secondTryTestimonial(quote: String, author: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 2) {
                ForEach(0..<5) { _ in
                    Image(systemName: "star.fill").font(.system(size: 10)).foregroundColor(.yellow)
                }
            }
            Text("\"\(quote)\"")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
            Text("— \(author)")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.45))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.07)))
    }

    // MARK: - Sticky Bottom
    private var stickyBottom: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [.clear, Color(red: 0.06, green: 0.08, blue: 0.20).opacity(0.97)],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 20)

            VStack(spacing: 12) {
                // Price card — monthly only
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Monthly Plan")
                            .font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                        Text("Cancel anytime from Settings")
                            .font(.system(size: 12)).foregroundColor(.white.opacity(0.55))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(monthlyPrice)
                            .font(.system(size: 22, weight: .bold)).foregroundColor(.white)
                        Text("per month")
                            .font(.system(size: 11)).foregroundColor(.white.opacity(0.5))
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Constants.DAMidBlue.opacity(0.18))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Constants.DAMidBlue.opacity(0.5), lineWidth: 1.5))
                )

                // CTA
                Button(action: makePurchase) {
                    Group {
                        if declarationStore.isPurchasing {
                            ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Start Monthly Plan")
                                .font(.system(size: 17, weight: .bold)).foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(RoundedRectangle(cornerRadius: 30)
                        .fill(LinearGradient(colors: [Constants.DAMidBlue, Constants.DAMidBlue.opacity(0.85)],
                                             startPoint: .leading, endPoint: .trailing)))
                }
                .scaleEffect(ctaPulsing ? 1.015 : 1.0)
                .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: ctaPulsing)
                .disabled(declarationStore.isPurchasing)
                .buttonStyle(PlainButtonStyle())

                // Trust
                HStack(spacing: 16) {
                    Label("No commitment", systemImage: "lock.open.fill")
                    Label("Secured by Apple", systemImage: "checkmark.shield.fill")
                }
                .font(.system(size: 11)).foregroundColor(.white.opacity(0.4))
            }
            .padding(.horizontal, 20).padding(.vertical, 16).padding(.bottom, 8)
            .background(Color(red: 0.06, green: 0.08, blue: 0.20).opacity(0.97))
        }
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Close (TOP-LEFT — intentionally different from main paywall)
    private var closeButton: some View {
        VStack {
            HStack {
                Button(action: handleSkip) {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 28))
                        .foregroundColor(.white.opacity(0.55))
                        .background(Circle().fill(Color.black.opacity(0.2)))
                }
                .padding(.top, 56).padding(.leading, 20)
                Spacer()
            }
            Spacer()
        }
        .transition(.opacity)
    }

    // MARK: - Actions
    private func handleSkip() {
        Analytics.logEvent("second_try_dismissed", parameters: [
            "variant": paywallVariant,
            "seconds_on_paywall": Int(Date().timeIntervalSince(entryTime))
        ])
        dismiss()
        onSkip?()
    }

    private func makePurchase() {
        guard let product = subscriptionStore.currentOfferedPremiumMonthly else {
            errorMessage = "Please try again."
            isShowingError = true
            return
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        Analytics.logEvent("second_try_cta_tapped", parameters: [
            "variant": paywallVariant,
            "product_id": product.id
        ])
        Task {
            await MainActor.run { declarationStore.isPurchasing = true }
            do {
                let purchased = try await subscriptionStore.purchase(product, paywallName: paywallVariant)
                if purchased {
                    let price = NSDecimalNumber(decimal: product.price).doubleValue
                    AnalyticsService.shared.trackPaywallConversion(
                        productId: product.id, paywallId: paywallVariant, price: price,
                        metadata: ["variant": paywallVariant,
                                   "plan": "monthly",
                                   "seconds_to_convert": Int(Date().timeIntervalSince(entryTime))]
                    )
                    await MainActor.run {
                        declarationStore.isPurchasing = false
                        dismiss()
                        onConvert?()
                    }
                } else {
                    await MainActor.run { declarationStore.isPurchasing = false }
                }
            } catch {
                await MainActor.run {
                    declarationStore.isPurchasing = false
                    errorMessage = "Purchase failed. Please try again."
                    isShowingError = true
                }
            }
        }
    }
}
