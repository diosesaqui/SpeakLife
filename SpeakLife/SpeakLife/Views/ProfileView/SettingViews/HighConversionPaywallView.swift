//
//  HighConversionPaywallView.swift
//  SpeakLife
//
//  Data-driven paywall - Remote Config flag: useHighConversionPaywall
//  Fixes: 70% abandon rate, missing price anchor, weak social proof
//  Tracks paywallVariant on all events:
//    - "high_conversion_v1"          (benefit-based personalized props)
//    - "high_conversion_succinct_v1" (succinct feature-based props, A/B via
//      Remote Config flag useSuccinctPaywallValueProps)
//

import SwiftUI
import StoreKit
import FirebaseAnalytics

struct HighConversionPaywallView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var declarationStore: DeclarationViewModel
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @ObservedObject private var preferencesTracker = UserPreferencesTracker.shared

    @State private var selectedPlan: PlanType = .annual
    @State private var isShowingError = false
    @State private var errorMessage = ""
    @State private var showPrivacyPolicy = false
    @State private var showPayWhatYouCan = false
    @State private var showCloseButton = false
    @State private var timeOnPaywall: Date = Date()
    @State private var isEligibleForTrial = false

    var callback: (() -> Void)?
    /// Where this paywall is being shown from. Drives the `source` property on
    /// paywall analytics events ('onboarding' | 'settings' | 'feature_gate').
    /// Default of 'settings' matches the dominant non-onboarding callsites
    /// (PremiumView, OptimizedSubscriptionView from HomeView).
    var source: String = "settings"

    /// Variant string sent to Firebase Analytics on every paywall event so the
    /// A/B between benefit-based and feature-based copy can be compared.
    private var paywallVariant: String {
        subscriptionStore.useSuccinctPaywallValueProps ? "high_conversion_succinct_v1" : "high_conversion_v1"
    }

    /// Succinct feature-based value props (Variant B). Plain, scannable list.
    private static let succinctValueProps: [String] = [
        "Access to all declaration categories",
        "Access to all devotionals",
        "Access to all mind-renewing audios",
        "Unlimited Create-Your-Own declarations & private journal entries",
        "Access to all themes"
    ]
    private static let succinctIcons: [String] = [
        "quote.bubble.fill",
        "book.fill",
        "headphones",
        "square.and.pencil",
        "paintbrush.fill"
    ]

    private var surveyEngine: SurveyPersonalizationEngine {
        SurveyPersonalizationEngine(goalWordRaw: appState.surveyGoalWord)
    }

    /// Active quiz segment, if the user came through QuizOnboardingView (Treatment cohort).
    /// Takes priority over survey copy because it reflects the specific ad-matched framing.
    /// Returns nil for the `unsegmented` cohort so they fall through to the
    /// surveyEngine-personalized headline (driven by their burden choice), which
    /// is more specific than the generic "Speak life today" unsegmented copy.
    private var quizSegment: QuizSegment? {
        guard let seg = QuizSegment(rawValue: appState.onboardingSegment),
              seg != .unsegmented else { return nil }
        return seg
    }

    /// Segment-tagged analytics property. Empty string when the user came through
    /// the Control onboarding so paywall events stay backward-compatible.
    private var segmentParam: String {
        appState.onboardingSegment
    }

    /// Resolved copy: quiz segment first, survey goal word second, category-based fallback third.
    private var resolvedHeadline: String {
        if let segment = quizSegment { return segment.paywallHeadline }
        return surveyEngine.hasSurveyData ? surveyEngine.paywallCopy.headline : copy.headline
    }
    private var resolvedSubheadline: String {
        if let segment = quizSegment { return segment.paywallSubheadline }
        return surveyEngine.hasSurveyData ? surveyEngine.paywallCopy.subheadline : copy.subheadline
    }
    private var resolvedValueProps: [String] {
        surveyEngine.hasSurveyData ? surveyEngine.paywallCopy.valueProps.map { $0.title } : copy.valueProps
    }
    private var resolvedDescriptions: [String] {
        surveyEngine.hasSurveyData
            ? surveyEngine.paywallCopy.valueProps.map { $0.description }
            : [
                "Daily declarations rewire your mind until God's Word becomes your first response.",
                "Spoken truth is your greatest weapon. It is exactly how Jesus defeated every attack.",
                "Faith comes by hearing. Audio devotionals put Scripture in your ears morning and night.",
                "Know your identity in Christ so deeply that fear, doubt, and shame lose their grip."
              ]
    }
    private var resolvedChallengeName: String? {
        surveyEngine.hasSurveyData ? surveyEngine.paywallCopy.challengeName : nil
    }

    enum PlanType: String {
        case annual = "annual"
        case monthly = "monthly"
    }

    // MARK: - Prices
    private var annualPrice: String { subscriptionStore.currentOfferedPremium?.displayPrice ?? "$39.99" }
    private var monthlyPrice: String { subscriptionStore.currentOfferedPremiumMonthly?.displayPrice ?? "$9.99" }
    private var annualPerMonth: String {
        guard let p = subscriptionStore.currentOfferedPremium,
              let d = Double(p.price.description) else { return "$3.33" }
        return String(format: "$%.2f", d / 12.0)
    }
    private var selectedProduct: Product? {
        selectedPlan == .annual ? subscriptionStore.currentOfferedPremium : subscriptionStore.currentOfferedPremiumMonthly
    }
    private var copy: UserPreferencesTracker.PaywallCopy { preferencesTracker.getDynamicPaywallCopy() }

    // MARK: - Body
    var body: some View {
        ZStack {
            backgroundGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        headerSection
                        starsOnlyBanner.padding(.top, 20)
                        benefitsSection.padding(.top, 20)
                        featuredTestimonial.padding(.top, 24)
                        remainingTestimonialsSection.padding(.top, 24)
                        Spacer(minLength: 20)
                    }
                }
                stickyBottomSection
            }

            if declarationStore.isPurchasing { RotatingLoadingImageView() }
            if showCloseButton { closeButton }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(edges: .bottom)
        .onAppear(perform: onAppear)
        .alert("", isPresented: $isShowingError) {
            Button("OK", role: .cancel) { }
        } message: { Text(errorMessage) }
        .sheet(isPresented: $showPrivacyPolicy) { PrivacyPolicyView() }
        .sheet(isPresented: $showPayWhatYouCan) {
            PayWhatYouCanView(callback: callback)
                .environmentObject(subscriptionStore)
                .environmentObject(declarationStore)
        }
    }

    // MARK: - Background
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [Color(red:0.07,green:0.10,blue:0.22), Color(red:0.12,green:0.07,blue:0.20), Color(red:0.04,green:0.04,blue:0.12)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    // MARK: - Header
    private var headerSection: some View {
        ZStack(alignment: .bottom) {
            Image("starrySunrise")
                .resizable().aspectRatio(contentMode: .fill)
                .frame(height: 260).clipped()
            LinearGradient(colors: [.clear, Color(red:0.07,green:0.10,blue:0.22)], startPoint: .top, endPoint: .bottom)
                .frame(height: 120)
            VStack(spacing: 8) {
                Image("appIconDisplay")
                    .resizable().frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.2), lineWidth: 1))
                Text(resolvedHeadline)
                    .font(.system(size: 22, weight: .bold)).foregroundColor(.white)
                    .multilineTextAlignment(.center).padding(.horizontal, 24)
                Text(resolvedSubheadline)
                    .font(.system(size: 14)).foregroundColor(.white.opacity(0.75))
                    .multilineTextAlignment(.center).padding(.horizontal, 32)
            }
            .padding(.bottom, 20)
        }
    }

    // MARK: - Social Proof (stars only — headline already covers 100K stat)
    private var starsOnlyBanner: some View {
        HStack(spacing: 4) {
            HStack(spacing: 2) {
                ForEach(0..<5) { _ in Image(systemName: "star.fill").font(.system(size: 13)).foregroundColor(.yellow) }
            }
            Text("4.9 rating · App Store")
                .font(.system(size: 13, weight: .medium)).foregroundColor(.white.opacity(0.7))
        }
    }

    // MARK: - Benefits
    @ViewBuilder
    private var benefitsSection: some View {
        if subscriptionStore.useSuccinctPaywallValueProps {
            succinctBenefitsSection
        } else {
            personalizedBenefitsSection
        }
    }

    private var personalizedBenefitsSection: some View {
        let icons = ["quote.bubble.fill", "shield.fill", "eye.fill", "person.circle.fill"]
        let descs = Array(resolvedDescriptions.prefix(4))
        let props = Array(resolvedValueProps.prefix(4))
        return VStack(alignment: .leading, spacing: 16) {
            ForEach(0..<min(props.count, 4), id: \.self) { i in
                HCBenefitRow(icon: icons[i], title: props[i], description: i < descs.count ? descs[i] : "")
            }
        }
        .padding(.horizontal, 24)
    }

    private var succinctBenefitsSection: some View {
        let props = Self.succinctValueProps
        let icons = Self.succinctIcons
        return VStack(alignment: .leading, spacing: 14) {
            ForEach(0..<props.count, id: \.self) { i in
                HCSuccinctBenefitRow(icon: icons[i], title: props[i])
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Featured Testimonial (above the fold, anxiety-first)
    private var featuredTestimonial: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 2) {
                ForEach(0..<5) { _ in Image(systemName: "star.fill").font(.system(size: 12)).foregroundColor(.yellow) }
            }
            Text("\"My anxiety attacks stopped after 2 weeks. I speak these declarations every morning and it changed everything.\"")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
            Text("— Marcus T., App Store review")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.12), lineWidth: 1))
        )
        .padding(.horizontal, 24)
    }

    // MARK: - Remaining Testimonials
    private var remainingTestimonialsSection: some View {
        VStack(spacing: 12) {
            testimonialCard(
                quote: "I've tried journaling, therapy, everything. Nothing rewired my thinking like speaking God's Word daily. This app is different.",
                author: "DeShawn R.", stars: 5
            )
            testimonialCard(
                quote: "I was skeptical but this is the real deal. My mind literally works differently now. Best $4/month I spend.",
                author: "Priya K.", stars: 5
            )
            testimonialCard(
                quote: "I love this app. To feed on the promises of God regularly throughout the day is so uplifting and encouraging. It feeds my soul.",
                author: "Tina", stars: 5
            )
            testimonialCard(
                quote: "This app was created under the manifestation and direction of the Holy Spirit, bringing life through scripture and meditation to God's people.",
                author: "Crash L.", stars: 5
            )
        }
        .padding(.horizontal, 24)
    }

    private func testimonialCard(quote: String, author: String, stars: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 2) {
                ForEach(0..<stars) { _ in Image(systemName: "star.fill").font(.system(size: 10)).foregroundColor(.yellow) }
            }
            Text("\(quote)")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
            Text("— \(author)")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.45))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06)))
    }

    // MARK: - Sticky Bottom
    private var stickyBottomSection: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [.clear, Color(red:0.07,green:0.10,blue:0.22).opacity(0.97)], startPoint: .top, endPoint: .bottom)
                .frame(height: 20)
            VStack(spacing: 14) {
                planSelectorSection
                trialCallout
                closingLine
                ctaButton
                bottomLinks
            }
            .padding(.horizontal, 20).padding(.vertical, 16).padding(.bottom, 8)
            .background(Color(red:0.07,green:0.10,blue:0.22).opacity(0.97))
        }
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Plan Selector
    private var planSelectorSection: some View {
        GeometryReader { geo in
            let cardWidth = (geo.size.width - 10) / 2
            HStack(spacing: 10) {
                planCard(plan: .monthly, topLabel: nil, title: "Monthly", price: monthlyPrice, sub: "per month")
                    .frame(width: cardWidth)
                planCard(plan: .annual, topLabel: "BEST VALUE", title: "Annual", price: annualPrice, sub: "per month \(annualPerMonth)")
                    .frame(width: cardWidth)
            }
        }
        .frame(height: 90)
    }

    private func planCard(plan: PlanType, topLabel: String?, title: String, price: String, sub: String) -> some View {
        let isSelected = selectedPlan == plan
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) { selectedPlan = plan }
            Analytics.logEvent("paywall_plan_switched", parameters: ["plan": plan.rawValue, "variant": paywallVariant, "segment": segmentParam])
        }) {
            ZStack(alignment: .top) {
                VStack(spacing: 4) {
                    if topLabel != nil { Spacer().frame(height: 12) }
                    Text(title).font(.system(size: 13, weight: .semibold)).foregroundColor(isSelected ? .white : .white.opacity(0.55))
                    Text(price).font(.system(size: 22, weight: .bold)).foregroundColor(isSelected ? .white : .white.opacity(0.45))
                    Text(sub).font(.system(size: 10)).foregroundColor(isSelected ? .white.opacity(0.7) : .white.opacity(0.3)).multilineTextAlignment(.center)
                }
                .padding(.vertical, 14).padding(.horizontal, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? Constants.DAMidBlue.opacity(0.25) : Color.white.opacity(0.05))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(isSelected ? Constants.DAMidBlue : Color.white.opacity(0.15), lineWidth: isSelected ? 2 : 1))
                )
                if let label = topLabel {
                    Text(label).font(.system(size: 9, weight: .bold)).foregroundColor(.white)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(Color.green))
                        .offset(y: -10)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Trial Callout
    private var trialCallout: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill").foregroundColor(.green).font(.system(size: 14))
            Text(selectedPlan == .annual && isEligibleForTrial ? "3 days free - cancel anytime before trial ends" : "Start today - cancel anytime")
                .font(.system(size: 13, weight: .medium)).foregroundColor(.white.opacity(0.85))
        }
    }

    // MARK: - Closing Line
    private var closingLine: some View {
        Text("God prepared the treasure chest.\nSpeakLife helps you open it — every single day.")
            .font(.system(size: 14, weight: .regular, design: .rounded))
            .foregroundColor(.white.opacity(0.7))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
            .padding(.vertical, 12)
    }

    // MARK: - CTA
    private var ctaText: String {
        if selectedPlan == .monthly { return "Start Taking Ground →" }
        if isEligibleForTrial { return "Start Free Trial" }
        return "Start Taking Ground →"
    }

    private var ctaButton: some View {
        Button(action: makePurchase) {
            Group {
                if declarationStore.isPurchasing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text(ctaText).font(.system(size: 17, weight: .bold)).foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity).padding(.vertical, 17)
            .background(RoundedRectangle(cornerRadius: 30).fill(LinearGradient(colors: [Constants.DAMidBlue, Constants.DAMidBlue.opacity(0.85)], startPoint: .leading, endPoint: .trailing)))
        }
        .disabled(declarationStore.isPurchasing)
        .opacity(declarationStore.isPurchasing ? 0.7 : 1.0)
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Bottom Links
    private var bottomLinks: some View {
        VStack(spacing: 8) {
            HStack(spacing: 24) {
                Button("Restore", action: restore)
                Link("Terms", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                Button("Privacy") { showPrivacyPolicy = true }
            }
            .font(.system(size: 12)).foregroundColor(.white.opacity(0.4))

            if subscriptionStore.showPayWhatYouCanLink {
                Button(action: { showPayWhatYouCan = true }) {
                    Text("Can't afford it? Pay what you can →")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.35))
                        .underline()
                }
            }
        }
    }

    // MARK: - Close Button
    private var closeButton: some View {
        VStack {
            HStack {
                Spacer()
                Button(action: {
                    Analytics.logEvent("paywall_dismissed", parameters: [
                        "variant": paywallVariant,
                        "plan_viewed": selectedPlan.rawValue,
                        "seconds_on_paywall": Int(Date().timeIntervalSince(timeOnPaywall)),
                        "segment": segmentParam
                    ])
                    callback?(); dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 28))
                        .foregroundColor(.white.opacity(0.6)).background(Circle().fill(Color.black.opacity(0.2)))
                }
                .padding(.top, 56).padding(.trailing, 20)
            }
            Spacer()
        }
        .transition(.opacity)
    }

    // MARK: - Lifecycle
    private func onAppear() {
        timeOnPaywall = Date()
        selectedPlan = .annual
        // Check actual trial eligibility from Apple
        Task {
            let eligible = await subscriptionStore.currentOfferedPremium?.subscription?.isEligibleForIntroOffer ?? false
            await MainActor.run { isEligibleForTrial = eligible }
        }
        AnalyticsService.shared.trackPaywallImpression(paywallId: paywallVariant, metadata: [
            "variant": paywallVariant,
            "user_category": preferencesTracker.primaryCategory.rawValue,
            "initial_plan": "annual",
            "segment": segmentParam
        ])
        Analytics.logEvent("paywall_shown", parameters: [
            "segment": segmentParam,
            "source": source,
            "variant": paywallVariant
        ])
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            withAnimation(.easeIn(duration: 0.4)) { showCloseButton = true }
        }
    }

    // MARK: - Purchase
    private func makePurchase() {
        guard let product = selectedProduct else {
            errorMessage = "Please select a subscription option."
            isShowingError = true
            return
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        Analytics.logEvent("paywall_cta_tapped", parameters: [
            "variant": paywallVariant,
            "plan": selectedPlan.rawValue,
            "user_category": preferencesTracker.primaryCategory.rawValue,
            "product_id": product.id,
            "segment": segmentParam
        ])
        Analytics.logEvent("paywall_subscribe_tapped", parameters: [
            "segment": segmentParam,
            "plan": selectedPlan.rawValue,
            "variant": paywallVariant
        ])
        Task {
            await MainActor.run { declarationStore.isPurchasing = true }
            do {
                let purchased = try await subscriptionStore.purchase(product, paywallName: paywallVariant)
                if purchased {
                    let price = NSDecimalNumber(decimal: product.price).doubleValue
                    AnalyticsService.shared.trackPaywallConversion(
                        productId: product.id, paywallId: paywallVariant, price: price,
                        metadata: ["variant": paywallVariant, "plan": selectedPlan.rawValue,
                                   "user_category": preferencesTracker.primaryCategory.rawValue,
                                   "seconds_to_convert": Int(Date().timeIntervalSince(timeOnPaywall)),
                                   "segment": segmentParam]
                    )
                    if isEligibleForTrial {
                        AnalyticsService.shared.trackTrialStarted(productId: product.id, metadata: ["variant": paywallVariant, "segment": segmentParam])
                        Analytics.logEvent("trial_started", parameters: [
                            "segment": segmentParam,
                            "plan_id": selectedPlan.rawValue,
                            "paywall_variant": paywallVariant,
                            "product_id": product.id
                        ])
                    }
                    await MainActor.run { declarationStore.isPurchasing = false; callback?(); dismiss() }
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

    // MARK: - Restore
    private func restore() {
        Task {
            await MainActor.run { declarationStore.isPurchasing = true }
            await subscriptionStore.restore()
            await MainActor.run { declarationStore.isPurchasing = false; errorMessage = "Purchases restored"; isShowingError = true }
        }
    }
}

// MARK: - Benefit Row Component
private struct HCBenefitRow: View {
    let icon: String; let title: String; let description: String
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon).font(.system(size: 20, weight: .medium))
                .foregroundColor(Constants.DAMidBlue).frame(width: 26)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
                Text(description).font(.system(size: 12)).foregroundColor(.white.opacity(0.65)).fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
    }
}

// MARK: - Succinct Benefit Row (Variant B)
private struct HCSuccinctBenefitRow: View {
    let icon: String; let title: String
    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: icon).font(.system(size: 18, weight: .medium))
                .foregroundColor(Constants.DAMidBlue).frame(width: 26)
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
    }
}
