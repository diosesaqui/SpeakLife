//
//  GiveView.swift
//  SpeakLife
//
//  "Give to SpeakLife" screen, opened from the Profile tab. Lists the
//  purchases someone can make to support the app, and works for people
//  who already subscribe.
//
//  A subscriber cannot give through a subscription: buying another plan in
//  the same group only switches their plan. So giving runs on consumable
//  gift products, which can be bought any number of times. They unlock
//  nothing. Lifetime is listed too for anyone who does not own it yet.
//
//  Gift products must exist in App Store Connect (type: Consumable) with the
//  ids in `GiftProduct.ids`. Any id that does not load is simply left out,
//  so the screen ships safely before they are created.
//
//  Apple only lets approved nonprofits collect donations, so this screen
//  says "gift" and "support", never "donate".
//

import SwiftUI
import StoreKit
import RevenueCat

enum GiftProduct {
    /// Consumable gift ids, cheapest first. Create these in App Store Connect.
    static let ids = [
        "SpeakLifeGift5",
        "SpeakLifeGift10",
        "SpeakLifeGift25",
        "SpeakLifeGift50",
        "SpeakLifeGift100"
    ]
}

struct GiveView: View {

    @EnvironmentObject var subscriptionStore: SubscriptionStore

    @State private var gifts: [Product] = []
    @State private var lifetime: Product?
    @State private var isLoading = true
    @State private var purchasingID: String?
    @State private var showThankYou = false
    @State private var errorMessage: String?

    private var ownsLifetime: Bool {
        subscriptionStore.purchasedNonConsumables.contains { $0.id == lifetimeID }
    }

    private var hasActiveSubscription: Bool {
        !subscriptionStore.purchasedSubscriptions.isEmpty
    }

    var body: some View {
        List {
            Section {
                header
            }
            .listRowBackground(Color.clear)

            if isLoading {
                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }
            } else {
                if !gifts.isEmpty {
                    Section(header: Text("One-time gift").font(.caption),
                            footer: Text("A gift unlocks nothing new. It keeps SpeakLife free for people who cannot pay, and you can give as often as you like.")) {
                        ForEach(gifts, id: \.id) { product in
                            row(title: product.displayName,
                                subtitle: product.description,
                                product: product,
                                icon: "heart.fill") {
                                buyGift(product)
                            }
                        }
                    }
                }

                if let lifetime, !ownsLifetime {
                    Section(header: Text("Lifetime").font(.caption),
                            footer: lifetimeFooter) {
                        row(title: "Lifetime Access",
                            subtitle: "One payment, yours forever",
                            product: lifetime,
                            icon: "crown.fill") {
                            buyLifetime(lifetime)
                        }
                    }
                }

                if gifts.isEmpty && (lifetime == nil || ownsLifetime) {
                    Section {
                        Text("Gifts are not available right now. Thank you for wanting to give.")
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("Give to SpeakLife")
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.colorScheme, .dark)
        .task { await load() }
        .onAppear {
            AnalyticsService.shared.track("give_viewed", parameters: ["is_premium": subscriptionStore.isPremium])
        }
        .alert("Thank you", isPresented: $showThankYou) {
            Button("Amen", role: .cancel) {}
        } message: {
            Text("Your gift keeps God's Word in the hands of people who could not afford it.")
        }
        .alert("Purchase Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Pieces

    private var header: some View {
        VStack(spacing: DS.Spacing.xs) {
            Image(systemName: "heart.circle.fill")
                .font(.system(size: 44))
                .foregroundColor(Constants.DAMidBlue)
            Text("Sow into SpeakLife")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
            Text("Every gift puts daily declarations in front of someone who needs them.")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.xs)
    }

    @ViewBuilder
    private var lifetimeFooter: some View {
        if hasActiveSubscription {
            Text("You already subscribe. If you buy Lifetime, cancel your subscription in iPhone Settings so you are not billed for both.")
        } else {
            Text("Unlocks all of SpeakLife Premium for good.")
        }
    }

    private func row(title: String,
                     subtitle: String,
                     product: Product,
                     icon: String,
                     action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: icon)
                    .foregroundColor(Constants.DAMidBlue)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundColor(.white)
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.55))
                    }
                }
                Spacer()
                if purchasingID == product.id {
                    ProgressView()
                } else {
                    Text(product.displayPrice)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
            }
        }
        .disabled(purchasingID != nil)
    }

    // MARK: - Loading

    private func load() async {
        let loaded = await subscriptionStore.products(for: GiftProduct.ids + [lifetimeID]) ?? []
        gifts = loaded.filter { $0.type == .consumable }.sorted { $0.price < $1.price }
        lifetime = loaded.first { $0.id == lifetimeID }
        isLoading = false
    }

    // MARK: - Purchases

    /// Gifts go straight through RevenueCat, not SubscriptionStore.purchase,
    /// so they never fire the subscribe/trial conversion events.
    private func buyGift(_ product: Product) {
        Juice.play(.tapLight)
        let params: [String: Any] = [
            "product_id": product.id,
            "price": NSDecimalNumber(decimal: product.price).doubleValue,
            "is_premium": subscriptionStore.isPremium
        ]
        AnalyticsService.shared.track("gift_tapped", parameters: params)
        purchasingID = product.id
        Task { @MainActor in
            defer { purchasingID = nil }
            do {
                let result = try await RevenueCatManager.shared.purchase(storeProduct: product)
                if result.userCancelled {
                    AnalyticsService.shared.track("gift_cancelled", parameters: params)
                } else {
                    AnalyticsService.shared.track("gift_purchased", parameters: params)
                    showThankYou = true
                }
            } catch let error as RevenueCat.ErrorCode where error == .purchaseCancelledError {
                AnalyticsService.shared.track("gift_cancelled", parameters: params)
            } catch {
                var failed = params
                failed["error"] = String(describing: error)
                AnalyticsService.shared.track("gift_failed", parameters: failed)
                errorMessage = error.localizedDescription
            }
        }
    }

    /// Lifetime is a real premium purchase, so it takes the normal path and
    /// its conversion analytics.
    private func buyLifetime(_ product: Product) {
        Juice.play(.tapLight)
        purchasingID = product.id
        Task { @MainActor in
            defer { purchasingID = nil }
            do {
                if try await subscriptionStore.purchase(product, paywallName: "Give") {
                    showThankYou = true
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
