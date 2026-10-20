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
        "SpeakLifeGift100",
        "SpeakLifeGift500"
    ]
}

struct GiveView: View {

    @EnvironmentObject var subscriptionStore: SubscriptionStore

    @State private var gifts: [Product] = []
    @State private var lifetime: Product?
    @State private var isLoading = true
    @State private var purchasingID: String?
    @State private var thankYou: GiftThankYou?
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
                            footer: Text("Your gift helps SpeakLife grow, keeps it running, and keeps it free for people who cannot pay. Give as often as you like.")) {
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
        .fullScreenCover(item: $thankYou) { item in
            GiftThankYouView(item: item)
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
                    thankYou = GiftThankYou(kind: .gift(product.displayPrice))
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
                    thankYou = GiftThankYou(kind: .lifetime)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Thank-you screen

/// What was just bought. Identifiable so it can drive `fullScreenCover(item:)`.
struct GiftThankYou: Identifiable {
    enum Kind {
        case gift(String)   // display price, e.g. "$9.99"
        case lifetime
    }
    let id = UUID()
    let kind: Kind
}

/// Full-screen thank-you shown after a gift or Lifetime purchase: a glowing
/// heart that blooms in with ripples, hearts drifting up, and the message
/// arriving line by line.
struct GiftThankYouView: View {

    let item: GiftThankYou

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var heartIn = false
    @State private var ripple = false
    @State private var pulse = false
    @State private var step = 0          // 1 title, 2 message, 3 verse, 4 button
    @State private var startDate = Date()

    private let rose = Color(red: 0.98, green: 0.42, blue: 0.62)
    private let gold = Color(red: 1.0, green: 0.82, blue: 0.45)

    private var title: String {
        switch item.kind {
        case .gift: return "Thank You"
        case .lifetime: return "Welcome Home"
        }
    }

    private var message: String {
        switch item.kind {
        case .gift(let price):
            return "Your \(price) gift puts God's Word in the hands of someone who could not afford it."
        case .lifetime:
            return "SpeakLife is yours for life, and your support keeps it free for someone who cannot pay."
        }
    }

    var body: some View {
        ZStack {
            background

            if !reduceMotion {
                risingHearts
            }

            VStack(spacing: DS.Spacing.lg) {
                Spacer()

                heart
                    .padding(.bottom, DS.Spacing.md)

                Text(title)
                    .font(.system(size: 38, weight: .bold, design: .serif))
                    .foregroundColor(.white)
                    .modifier(Arrive(visible: step >= 1))

                Text(message)
                    .font(.system(size: 17))
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, DS.Spacing.xl)
                    .modifier(Arrive(visible: step >= 2))

                verse
                    .modifier(Arrive(visible: step >= 3))

                Spacer()

                Button {
                    Juice.play(.tapSolid)
                    dismiss()
                } label: {
                    Text("Amen")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.md)
                        .background(
                            Capsule().fill(LinearGradient(colors: [gold, rose],
                                                          startPoint: .leading,
                                                          endPoint: .trailing))
                        )
                        .shadow(color: rose.opacity(0.5), radius: 16, y: 6)
                }
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.bottom, DS.Spacing.xl)
                .modifier(Arrive(visible: step >= 4))
            }
        }
        .onAppear(perform: play)
        .statusBarHidden()
    }

    // MARK: Pieces

    private var background: some View {
        ZStack {
            Color.black
            RadialGradient(colors: [Color(red: 0.42, green: 0.16, blue: 0.48),
                                    Color(red: 0.12, green: 0.05, blue: 0.22),
                                    .black],
                           center: .center,
                           startRadius: 10,
                           endRadius: pulse ? 520 : 420)
                .animation(reduceMotion ? nil : .easeInOut(duration: 3).repeatForever(autoreverses: true),
                           value: pulse)
        }
        .ignoresSafeArea()
    }

    private var heart: some View {
        ZStack {
            // Ripples that spread out once as the heart lands.
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .stroke(rose.opacity(0.5), lineWidth: 2)
                    .frame(width: 120, height: 120)
                    .scaleEffect(ripple ? 2.6 : 0.6)
                    .opacity(ripple ? 0 : 0.8)
                    .animation(.easeOut(duration: 1.6).delay(Double(i) * 0.25), value: ripple)
            }

            // Soft glow behind the heart.
            Circle()
                .fill(rose.opacity(0.35))
                .frame(width: 150, height: 150)
                .blur(radius: 40)
                .scaleEffect(pulse ? 1.15 : 0.9)

            Image(systemName: "heart.fill")
                .font(.system(size: 96))
                .foregroundStyle(LinearGradient(colors: [gold, rose],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing))
                .shadow(color: rose.opacity(0.8), radius: 24)
                .scaleEffect(heartIn ? (pulse ? 1.06 : 1.0) : 0.2)
                .opacity(heartIn ? 1 : 0)
        }
        .frame(height: 200)
    }

    private var verse: some View {
        VStack(spacing: DS.Spacing.xs) {
            Text("\u{201C}Give, and it will be given to you. A good measure, pressed down, shaken together and running over, will be poured into your lap.\u{201D}")
                .font(.system(size: 15, weight: .medium, design: .serif))
                .italic()
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
            Text("Luke 6:38")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(gold)
        }
        .padding(DS.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .fill(Color.white.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.md)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1))
        )
        .padding(.horizontal, DS.Spacing.lg)
    }

    /// Small hearts drifting up the screen on a loop, driven by the clock so
    /// they never stutter or reset when the view re-renders.
    private var risingHearts: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSince(startDate)
                ZStack {
                    ForEach(0..<18, id: \.self) { i in
                        floatingHeart(index: i, time: t, in: geo.size)
                    }
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func floatingHeart(index: Int, time: TimeInterval, in size: CGSize) -> some View {
        let seed = Double(index)
        let secondsPerTrip = 5.0 + (seed * 7).truncatingRemainder(dividingBy: 4)
        let progress = ((time + seed * 0.9) / secondsPerTrip).truncatingRemainder(dividingBy: 1)
        let column = (seed * 0.137 + 0.05).truncatingRemainder(dividingBy: 0.9) + 0.05
        let sway = sin((time + seed) * 1.3) * 14
        let pointSize = 10 + (seed * 3).truncatingRemainder(dividingBy: 14)
        let x = Double(size.width) * column + sway
        let y = Double(size.height) * (1.05 - progress * 1.15)

        return Image(systemName: "heart.fill")
            .font(.system(size: CGFloat(pointSize)))
            .foregroundColor(index.isMultiple(of: 3) ? gold : rose)
            .opacity(sin(progress * .pi) * 0.55)
            .position(x: CGFloat(x), y: CGFloat(y))
    }

    // MARK: Sequence

    private func play() {
        startDate = Date()
        Juice.play(.celebrate)
        withAnimation(.spring(response: 0.6, dampingFraction: 0.55)) { heartIn = true }
        ripple = true
        if !reduceMotion {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true).delay(0.6)) {
                pulse = true
            }
        }
        for (index, delay) in [0.5, 0.9, 1.4, 2.0].enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.easeOut(duration: 0.6)) { step = index + 1 }
            }
        }
    }
}

/// Fades a line in while it rises a little into place.
private struct Arrive: ViewModifier {
    let visible: Bool
    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : 16)
    }
}
