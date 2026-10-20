//
//  MonthlyToAnnualOfferView.swift
//  SpeakLife
//
//  Offers a paying monthly subscriber the yearly plan, priced per month next
//  to what they pay now. Monthly churns about a third of subscribers every
//  cycle and "it's too expensive" is the top stated cancel reason; yearly
//  costs roughly a third as much per month, so the answer to "too expensive"
//  is the better plan, not a percentage off.
//
//  Two entry points: a sheet a few days before the monthly renewal
//  (HomeView, Remote Config `monthlyAnnualOffer`), and the lead card in the
//  cancel flow's offer step (CancelInterventionView).
//

import SwiftUI
import StoreKit

/// A monthly subscriber's plan next to the yearly one, with the per-month math.
struct MonthlyToAnnualOffer {
    let monthly: Product
    let annual: Product

    var annualPerMonth: Decimal { annual.price / 12 }

    var annualPerMonthText: String {
        annualPerMonth.formatted(annual.priceFormatStyle)
    }

    /// How much less per month yearly costs than staying monthly, rounded down
    /// so the screen never overstates it.
    var savingsPercent: Int {
        guard monthly.price > 0 else { return 0 }
        let ratio = NSDecimalNumber(decimal: annualPerMonth / monthly.price).doubleValue
        return max(0, Int(((1 - ratio) * 100).rounded(.down)))
    }

    var analytics: [String: Any] {
        ["monthly_product_id": monthly.id,
         "annual_product_id": annual.id,
         "savings_pct": savingsPercent]
    }
}

/// The price comparison and switch button, shared by the pre-renewal sheet
/// and the cancel flow.
struct MonthlyToAnnualCard: View {
    let offer: MonthlyToAnnualOffer
    let isPurchasing: Bool
    let onSwitch: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Yearly")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                if offer.savingsPercent > 0 {
                    Text("\(offer.savingsPercent)% less")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Constants.DAMidBlue)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Constants.DAMidBlue.opacity(0.18)))
                }
                Spacer()
            }

            // The billed price stays the most prominent price (App Review 3.1.2);
            // the per-month figure explains it.
            VStack(alignment: .leading, spacing: 4) {
                Text("\(offer.annual.displayPrice) a year")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                Text("about \(offer.annualPerMonthText)/month, instead of \(offer.monthly.displayPrice)/month now")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: onSwitch) {
                HStack(spacing: 8) {
                    if isPurchasing {
                        ProgressView().tint(.white).scaleEffect(0.85)
                    }
                    Text(isPurchasing ? "Processing..." : "Switch to yearly")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 28).fill(Constants.DAMidBlue))
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isPurchasing)
        }
        .padding(DS.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.07))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Constants.DAMidBlue.opacity(0.5), lineWidth: 1))
        )
    }
}

/// The pre-renewal sheet.
struct MonthlyToAnnualOfferView: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    let onClose: () -> Void

    @State private var isPurchasing = false
    @State private var errorMessage: String?
    @State private var tracked = false

    private static let paywallName = "monthly_to_annual_pre_renewal"

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.07, green: 0.10, blue: 0.22), Color(red: 0.04, green: 0.04, blue: 0.12)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            if let offer = subscriptionStore.monthlyToAnnualOffer {
                content(offer)
                    .onAppear { trackShown(offer) }
            } else {
                // The plan changed under the sheet (the switch went through,
                // or the subscription lapsed). Nothing left to offer.
                Color.clear.onAppear(perform: onClose)
            }
        }
    }

    private func content(_ offer: MonthlyToAnnualOffer) -> some View {
        VStack(spacing: 24) {
            Spacer(minLength: 12)

            VStack(spacing: 10) {
                Text(headline)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                Text("Same declarations, same audio, same streak. Yearly costs about \(offer.annualPerMonthText) a month.")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 8)

            MonthlyToAnnualCard(offer: offer, isPurchasing: isPurchasing) {
                Task { await switchPlan(offer) }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 13))
                    .foregroundColor(.red.opacity(0.85))
                    .multilineTextAlignment(.center)
            }

            Text("Apple shows when the yearly plan starts before you confirm. Cancel anytime in Settings.")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.45))
                .multilineTextAlignment(.center)

            Spacer()

            Button(action: {
                AnalyticsService.shared.track("monthly_annual_offer_dismissed", parameters: offer.analytics.merging(
                    ["source": "pre_renewal"], uniquingKeysWith: { $1 }))
                onClose()
            }) {
                Text("Keep monthly")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.vertical, 12)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }

    private var headline: String {
        guard let endsAt = subscriptionStore.premiumPeriodEndsAt else {
            return "Pay less for the same SpeakLife"
        }
        let days = max(1, Int(ceil(endsAt.timeIntervalSinceNow / 86_400)))
        let when = days == 1 ? "tomorrow" : "in \(days) days"
        return subscriptionStore.premiumWillRenew
            ? "Your month renews \(when)"
            : "Your plan ends \(when)"
    }

    private func trackShown(_ offer: MonthlyToAnnualOffer) {
        guard !tracked else { return }
        tracked = true
        var params = offer.analytics
        params["source"] = "pre_renewal"
        params["will_renew"] = subscriptionStore.premiumWillRenew
        if let endsAt = subscriptionStore.premiumPeriodEndsAt {
            params["days_to_period_end"] = max(0, Int(endsAt.timeIntervalSinceNow / 86_400))
        }
        AnalyticsService.shared.track("monthly_annual_offer_shown", parameters: params)
    }

    @MainActor
    private func switchPlan(_ offer: MonthlyToAnnualOffer) async {
        isPurchasing = true
        errorMessage = nil
        var params = offer.analytics
        params["source"] = "pre_renewal"
        do {
            let outcome = try await subscriptionStore.purchaseOutcome(offer.annual, paywallName: Self.paywallName)
            isPurchasing = false
            switch outcome {
            case .purchased:
                AnalyticsService.shared.track("monthly_annual_offer_purchased", parameters: params)
                onClose()
            case .pending:
                errorMessage = "Your switch is waiting for approval."
            case .notEntitled:
                errorMessage = "The switch went through but didn't show up yet. Try Restore in Settings."
            case .cancelled:
                break
            }
        } catch {
            isPurchasing = false
            errorMessage = "The switch didn't go through. Please try again."
            params["error"] = String(describing: error)
            AnalyticsService.shared.track("monthly_annual_offer_failed", parameters: params)
        }
    }
}
