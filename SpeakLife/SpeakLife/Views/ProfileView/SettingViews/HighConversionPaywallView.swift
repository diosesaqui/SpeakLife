//
//  HighConversionPaywallView.swift
//  SpeakLife
//
//  Data-driven paywall - Remote Config flag: useHighConversionPaywall
//  Fixes: 70% abandon rate, missing price anchor, weak social proof
//  Tracks paywallVariant on all events:
//    - "high_conversion_v1"          (benefit-based personalized props)
//    - "high_conversion_succinct_v1" (succinct outcome-based props, A/B via
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

    /// When true at the callsite, the paywall *may* render hard (no close button).
    /// Actual hardness is gated by Remote Config `showPayWhatYouCanLink`: hard
    /// only takes effect when the pay-what-you-can escape valve is also OFF.
    /// Flipping `showPayWhatYouCanLink` to true in Remote Config restores both
    /// the link and the close button as a single kill-switch.
    var isHardPaywall: Bool = false

    /// Effective hard-paywall state. Caller opts in via `isHardPaywall`, but
    /// the Remote Config flag must also gate the escape valve off.
    private var effectiveIsHardPaywall: Bool {
        isHardPaywall && !subscriptionStore.showPayWhatYouCanLink
    }

    /// Variant string sent to Firebase Analytics on every paywall event so the
    /// A/B between benefit-based and feature-based copy can be compared.
    private var paywallVariant: String {
        subscriptionStore.useSuccinctPaywallValueProps ? "high_conversion_succinct_v1" : "high_conversion_v1"
    }

    /// Short, scannable value props. Title-only, 3–5 words each — readable in a
    /// glance. The longer two-line descriptions were too much to read. The
    /// personalized headline/subhead above still adapts to the user.
    private static let succinctValueProps: [String] = [
        "Quiet anxious thoughts",
        "Renew your mind daily",
        "Sleep in God's peace",
        "Speak over your battles",
        "Walk in your identity"
    ]
    private static let succinctIcons: [String] = [
        "quote.bubble.fill",
        "book.fill",
        "headphones",
        "megaphone.fill",
        "crown.fill"
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

    /// True when the user just completed PersonalDeclaration in the onboarding
    /// flow. This is the warmest emotional anchor in the funnel — they literally
    /// spoke their own declaration aloud seconds ago. We reference that moment
    /// in the paywall headline + subhead for max continuity.
    private var hasFreshPersonalDeclaration: Bool {
        if let belief = preferencesTracker.personalDeclarationBelief, !belief.isEmpty {
            return true
        }
        return false
    }

    /// Burden goal word (peace / healing / identity / etc.) — drives the
    /// continuity subhead for personal-declaration users so the promise is
    /// specific to what they actually need, not generic.
    private var burdenStyleLabel: String? {
        guard let goalWord = SurveyGoalWord(rawValue: appState.surveyGoalWord) else { return nil }
        return goalWord.styleLabel.lowercased()
    }

    /// Resolved copy priority:
    /// 1. PersonalDeclaration continuity — emotionally warmest moment, names the promise
    /// 2. Quiz segment — ad-match
    /// 3. Survey engine — goal word personalization
    /// 4. Category fallback
    private var resolvedHeadline: String {
        if hasFreshPersonalDeclaration {
            return "Speak it daily until it comes to pass."
        }
        if let segment = quizSegment { return segment.paywallHeadline }
        return surveyEngine.hasSurveyData ? surveyEngine.paywallCopy.headline : copy.headline
    }
    private var resolvedSubheadline: String {
        if hasFreshPersonalDeclaration {
            if let burden = burdenStyleLabel {
                return "Your \(burden) declaration — in your mouth every morning. Until you possess it."
            }
            return "Your declaration — in your mouth every morning. Until you possess it."
        }
        if let segment = quizSegment { return segment.paywallSubheadline }
        return surveyEngine.hasSurveyData ? surveyEngine.paywallCopy.subheadline : copy.subheadline
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
    /// % saved on annual vs paying monthly for a year. nil if not computable.
    private var annualSavingsPercent: Int? {
        guard let annual = subscriptionStore.currentOfferedPremium,
              let monthly = subscriptionStore.currentOfferedPremiumMonthly,
              let a = Double(annual.price.description),
              let m = Double(monthly.price.description), m > 0 else { return nil }
        let yearlyIfMonthly = m * 12
        guard yearlyIfMonthly > 0 else { return nil }
        let pct = Int(((yearlyIfMonthly - a) / yearlyIfMonthly * 100).rounded())
        return pct > 0 ? pct : nil
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
            if showCloseButton && !effectiveIsHardPaywall { closeButton }
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
    // Always render the short, scannable props. (The longer personalized list
    // was too much to read; the headline above still carries personalization.)
    private var benefitsSection: some View {
        succinctBenefitsSection
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
                payWhatYouCanCTA
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
                planCard(plan: .annual, topLabel: annualSavingsPercent.map { "SAVE \($0)%" } ?? "BEST VALUE", title: "Annual", price: annualPrice, sub: "per month \(annualPerMonth)")
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

    // MARK: - Trial Callout (clarity-first: addresses the autocharge fear without
    // making any claims we can't keep — Apple's pre-trial-end notification is
    // inconsistent across users/regions/notification-settings, so we don't promise it).
    private var trialCallout: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill").foregroundColor(.green).font(.system(size: 14))
            Text(selectedPlan == .annual && isEligibleForTrial
                 ? "Free for 3 days. Cancel by day 3 to pay nothing."
                 : "Start today. Cancel anytime in Settings.")
                .font(.system(size: 13, weight: .semibold)).foregroundColor(.white.opacity(0.92))
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

    // MARK: - Pay What You Can (secondary CTA, intentionally subordinate to main CTA)
    @ViewBuilder
    private var payWhatYouCanCTA: some View {
        if subscriptionStore.showPayWhatYouCanLink {
            Button(action: {
                Analytics.logEvent("paywall_pay_what_you_can_tapped", parameters: [
                    "variant": paywallVariant,
                    "segment": segmentParam
                ])
                showPayWhatYouCan = true
            }) {
                Text("Can't afford full price? Pay what you can →")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.vertical, 4)
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel(Text("Pay what you can option"))
        }
    }

    // MARK: - Bottom Links
    private var bottomLinks: some View {
        HStack(spacing: 24) {
            Button("Restore", action: restore)
            Link("Terms", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
            Button("Privacy") { showPrivacyPolicy = true }
        }
        .font(.system(size: 12)).foregroundColor(.white.opacity(0.4))
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
        if !effectiveIsHardPaywall {
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                withAnimation(.easeIn(duration: 0.4)) { showCloseButton = true }
            }
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

// MARK: - Succinct Benefit Row
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
