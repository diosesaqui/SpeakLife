//
//  HighConversionPaywallView.swift
//  SpeakLife
//
//  Data-driven paywall - Remote Config flag: useHighConversionPaywall
//  Fixes: 70% abandon rate, missing price anchor, weak social proof
//  Copy is the "Pray like Jesus — speak to every storm" positioning
//  (unconditional; supersedes the old personalized-headline stack, retired
//  variants high_conversion_v1 / _succinct_v1 / _clean_v1 / _clean_dark_v1).
//  Tracks paywallVariant on all events:
//    - "high_conversion_storm_v1"            (classic dark layout)
//    - "high_conversion_storm_clean_v1"      (light minimal layout via
//      Remote Config flag useCleanPaywallVariant: headline + illustration +
//      two plan cards + Continue)
//    - "high_conversion_storm_clean_dark_v1" (clean layout skinned with the
//      classic dark gradient/colors, via useCleanPaywallDarkTheme on top of
//      useCleanPaywallVariant)
//

import SwiftUI
import StoreKit

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
    /// Per-product intro-offer eligibility (product id → eligible), checked
    /// against Apple per user. Keyed per product because eligibility is asked
    /// of whichever plan is selected (annual / monthly / weekly), and a single
    /// global bit checked only against the annual product mislabels the others.
    @State private var trialEligibility: [String: Bool] = [:]

    // MARK: - Welcome Offer State (decline path)
    // One recovery screen shown when an onboarding user dismisses this paywall
    // without buying. Exactly one step deep (Apple 5.6): once it resolves we
    // run the original callback/dismiss path and never show another offer.
    @State private var showWelcomeOffer = false
    @State private var welcomeOfferResolved = false
    /// Once-ever persistence: flips true the moment the offer is presented and
    /// never resets, so the user sees the welcome offer at most once for life.
    @AppStorage("welcomeOfferShown") private var welcomeOfferShown = false

    // MARK: - Post-Purchase Mission State
    // Brief mission/thank-you state shown after a successful purchase from the
    // onboarding paywall (main CTA or welcome offer) BEFORE the original
    // success path runs. Reframes the subscription as mission (the Bible Chat
    // pattern). Settings / feature-gate purchases keep the immediate dismiss —
    // those users are mid-task.
    private enum MissionResolution { case mainPurchase, welcomeOfferPurchase }
    @State private var showMissionScreen = false
    /// Exactly-once guard: the CTA tap and the 6-second auto-advance can race.
    @State private var missionContinued = false
    @State private var missionShownAt = Date()
    @State private var missionResolution: MissionResolution = .mainPurchase

    var callback: (() -> Void)?
    /// Where this paywall is being shown from. Drives the `source` property on
    /// paywall analytics events ('onboarding' | 'settings' | 'feature_gate').
    /// Default of 'settings' matches the dominant non-onboarding callsites
    /// (PremiumView, OptimizedSubscriptionView from HomeView).
    var source: String = "settings"

    /// When true at the callsite, the paywall *may* render hard (no close button).
    /// Actual hardness is gated by Remote Config `showPayWhatYouCanLink` (the
    /// soft-onboarding-paywall switch): hard only takes effect when that soft
    /// switch is OFF. When it's ON, the paywall keeps its close button and the
    /// one-time welcome-offer discount on dismiss. The visible "pay what you
    /// can" link is now a separate switch (`showPayWhatYouCanCTA`) and no longer
    /// affects hardness or the welcome offer.
    var isHardPaywall: Bool = false

    /// Effective hard-paywall state. Caller opts in via `isHardPaywall`, but the
    /// soft-onboarding-paywall Remote Config flag must also be OFF for the wall
    /// to actually render hard.
    private var effectiveIsHardPaywall: Bool {
        isHardPaywall && !subscriptionStore.showPayWhatYouCanLink
    }

    /// Variant string sent to Firebase Analytics on every paywall event. The
    /// "storm" segment marks the repositioned copy's release point so the
    /// rollout reads as a before/after against the retired variant names.
    private var paywallVariant: String {
        if isCleanVariant {
            return isCleanDarkTheme ? "high_conversion_storm_clean_dark_v1" : "high_conversion_storm_clean_v1"
        }
        return "high_conversion_storm_v1"
    }

    /// Clean minimal layout A/B (Remote Config: useCleanPaywallVariant). Swaps
    /// the whole layout, so it wins over the succinct-props flag. Latched on
    /// first appear so a Remote Config activation while the paywall is on
    /// screen can't swap the layout mid-decision — which would also desync
    /// impression vs conversion variant attribution in the A/B readout.
    @State private var lockedCleanVariant: Bool?
    private var isCleanVariant: Bool {
        lockedCleanVariant ?? subscriptionStore.useCleanPaywallVariant
    }

    /// Dark skin for the clean layout (Remote Config: useCleanPaywallDarkTheme,
    /// only meaningful when the clean layout is on): same minimal format,
    /// themed with the high-conversion paywall's dark gradient + colors so the
    /// paywall keeps visual continuity with the dark onboarding flows. Latched
    /// alongside the layout for the same attribution reason.
    @State private var lockedCleanDarkTheme: Bool?
    private var isCleanDarkTheme: Bool {
        isCleanVariant && (lockedCleanDarkTheme ?? subscriptionStore.useCleanPaywallDarkTheme)
    }

    /// Storm value props: scannable one-line format, written through the
    /// "speak to the storm" positioning. Lead with the mechanism (the exact
    /// Word, spoken), then speed, coverage, audio, chat, and social proof.
    private static let stormValueProps: [(icon: String, title: String)] = [
        ("wind", "The exact Word for your exact storm"),
        ("timer", "Peace in under 60 seconds"),
        ("megaphone.fill", "Declarations over your health, home, and mind"),
        ("headphones", "God's Word in your ears morning and night"),
        ("bubble.left.and.bubble.right.fill", "Ask the Bible anything"),
        ("person.2.fill", "\(SocialProof.believersCount) believers speaking life daily")
    ]

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

    /// Storm copy resolution: one uniform headline, with the subhead carrying
    /// the personalization. The fresh-personal-declaration moment (they spoke
    /// their own declaration aloud seconds ago) keeps its continuity framing;
    /// the survey goal word (peace / healing / identity / …) names the promise
    /// when we have it.
    private var resolvedHeadline: String {
        hasFreshPersonalDeclaration
            ? "You just spoke to your storm."
            : "Pray like Jesus. Speak to your storm."
    }
    private var resolvedSubheadline: String {
        if hasFreshPersonalDeclaration {
            return "Jesus stilled a sea with three words. Keep speaking yours every morning until it obeys."
        }
        if let burden = burdenStyleLabel {
            return "Your \(burden) declarations, in your mouth every morning, until the storm obeys."
        }
        return "He stilled a sea with three words. SpeakLife puts the exact Word for your storm in your mouth every morning."
    }
    enum PlanType: String {
        case annual = "annual"
        case monthly = "monthly"
        case weekly = "weekly"
    }

    // MARK: - Prices
    // All amounts come straight from StoreKit (driven by the product IDs set in
    // Remote Config / App Store Connect). No hardcoded prices — if a product
    // hasn't loaded we show a neutral placeholder, never a fake amount.
    private let pricePlaceholder = "—"
    private var annualPrice: String { subscriptionStore.currentOfferedPremium?.displayPrice ?? pricePlaceholder }
    private var monthlyPrice: String { subscriptionStore.currentOfferedPremiumMonthly?.displayPrice ?? pricePlaceholder }
    private var annualPerMonth: String {
        guard let p = subscriptionStore.currentOfferedPremium else { return pricePlaceholder }
        return perMonthString(yearlyProduct: p) ?? pricePlaceholder
    }
    /// % saved on annual vs paying the non-annual plan (weekly×52 or monthly×12)
    /// for a year. nil if not computable.
    private var annualSavingsPercent: Int? {
        guard let annual = subscriptionStore.currentOfferedPremium,
              let a = Double(annual.price.description) else { return nil }
        let comparisonYearly: Double? = showWeeklyPlan
            ? subscriptionStore.currentOfferedWeekly.flatMap { Double($0.price.description) }.map { $0 * 52 }
            : subscriptionStore.currentOfferedPremiumMonthly.flatMap { Double($0.price.description) }.map { $0 * 12 }
        guard let yearly = comparisonYearly, yearly > 0 else { return nil }
        let pct = Int(((yearly - a) / yearly * 100).rounded())
        return pct > 0 ? pct : nil
    }
    /// Per-week equivalent of the annual price (clean variant's right-hand
    /// price on the Annual card). StoreKit price ÷ 52, product's own locale.
    private var annualPerWeek: String {
        guard let p = subscriptionStore.currentOfferedPremium,
              let s = localizedPrice(p.price / 52, in: p) else { return pricePlaceholder }
        return s
    }
    /// What a full year actually costs on the non-annual plan (weekly×52 or
    /// monthly×12). This is the clean variant's strikethrough anchor on the
    /// Annual card and the honesty subline on the non-annual card — a real
    /// derived cost, never an invented anchor price.
    private var nonAnnualYearlyEquivalent: String? {
        if showWeeklyPlan, let w = subscriptionStore.currentOfferedWeekly {
            return localizedPrice(w.price * 52, in: w)
        }
        if let m = subscriptionStore.currentOfferedPremiumMonthly {
            return localizedPrice(m.price * 12, in: m)
        }
        return nil
    }

    // Non-annual plan follows the useWeeklyPlan flag (Weekly vs Monthly), but
    // only honors Weekly when that product actually loaded from StoreKit —
    // otherwise it shows Monthly. This is what prevents displaying a price for a
    // product the store never returned (the source of the phantom "$4.99").
    private var showWeeklyPlan: Bool {
        subscriptionStore.useWeeklyPlan && subscriptionStore.currentOfferedWeekly != nil
    }
    private var nonAnnualTitle: String { showWeeklyPlan ? "Weekly" : "Monthly" }
    private var nonAnnualSub: String { showWeeklyPlan ? "per week" : "per month" }
    /// Plan identity of the non-annual card, so analytics report "weekly" (not
    /// "monthly") when the useWeeklyPlan flag is on.
    private var nonAnnualPlan: PlanType { showWeeklyPlan ? .weekly : .monthly }
    private var nonAnnualPrice: String {
        showWeeklyPlan
            ? (subscriptionStore.currentOfferedWeekly?.displayPrice ?? pricePlaceholder)
            : monthlyPrice
    }

    private var selectedProduct: Product? {
        switch selectedPlan {
        case .annual:  return subscriptionStore.currentOfferedPremium
        case .weekly:  return subscriptionStore.currentOfferedWeekly
        case .monthly: return subscriptionStore.currentOfferedPremiumMonthly
        }
    }

    // MARK: - Trial Eligibility / Intro Offer
    /// Days in the introductory free-trial offer for the given product, read
    /// from the loaded StoreKit Product (never hardcoded). nil when this user
    /// isn't eligible for an intro offer on THIS product (per-product check
    /// done in refreshTrialEligibility) or when the product has no free-trial
    /// intro offer configured. Unknown/not-yet-checked products default to
    /// false, so trial copy never overpromises while eligibility loads.
    private func trialDays(for product: Product?) -> Int? {
        guard let product else { return nil }
        return introTrialDays(for: product, isEligible: trialEligibility[product.id] ?? false)
    }
    /// Trial length for the currently selected plan, nil when not trial-eligible.
    private var selectedPlanTrialDays: Int? { trialDays(for: selectedProduct) }
    /// Stable fingerprint of the three offered product ids; onChange watches it
    /// so eligibility re-runs when products finish loading after first render.
    private var offeredProductIDs: String {
        [
            subscriptionStore.currentOfferedPremium?.id,
            subscriptionStore.currentOfferedPremiumMonthly?.id,
            subscriptionStore.currentOfferedWeekly?.id
        ].map { $0 ?? "" }.joined(separator: "|")
    }
    // MARK: - Body
    var body: some View {
        ZStack {
            // The clean variant is light unless its dark theme is on; the
            // mission and welcome screens keep the dark gradient regardless.
            Group {
                if isCleanVariant && !isCleanDarkTheme && !showMissionScreen && !showWelcomeOffer {
                    cleanBackground
                } else {
                    backgroundGradient
                }
            }
            .ignoresSafeArea()

            if showMissionScreen {
                // Post-purchase mission screen. Same state-swap pattern as the
                // welcome offer below; takes precedence over both because it
                // only ever appears after a successful purchase.
                PostPurchaseMissionView(onContinue: continueMission)
                    .transition(.opacity)
            } else if showWelcomeOffer {
                // Decline-path recovery screen. State-swap (not a modal): this
                // paywall is embedded as a step inside the onboarding flows,
                // so swapping content in place is safer than layering a
                // fullScreenCover on a non-presented view.
                WelcomeOfferView(
                    variant: paywallVariant,
                    segment: segmentParam,
                    onResolve: resolveWelcomeOffer,
                    onPurchaseSuccess: { presentMissionScreen(.welcomeOfferPurchase) }
                )
                .transition(.opacity)
            } else {
                if isCleanVariant {
                    cleanVariantLayout
                } else {
                    VStack(spacing: 0) {
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 0) {
                                headerSection
                                starsOnlyBanner.padding(.top, 20)
                                benefitsSection.padding(.top, 20)
                                comparisonSection.padding(.top, 28)
                                featuredTestimonial.padding(.top, DS.Spacing.lg)
                                remainingTestimonialsSection.padding(.top, DS.Spacing.lg)
                                Spacer(minLength: 20)
                            }
                        }
                        stickyBottomSection
                    }
                }

                if showCloseButton && !effectiveIsHardPaywall { closeButton }
            }

            // Shared purchase spinner — covers both the paywall and the
            // welcome offer (the offer routes purchases through the same
            // declarationStore.isPurchasing flag).
            if declarationStore.isPurchasing { RotatingLoadingImageView() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(edges: .bottom)
        .onAppear(perform: onAppear)
        // Products can finish loading after onAppear (Remote Config + StoreKit
        // race the paywall presentation). Re-check eligibility whenever any of
        // the three offered product ids changes.
        .onChange(of: offeredProductIDs) { _ in
            Task { await refreshTrialEligibility() }
        }
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
            VStack(spacing: DS.Spacing.xs) {
                Image("appIconDisplay")
                    .resizable().frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.2), lineWidth: 1))
                Text(resolvedHeadline)
                    .font(.system(size: 22, weight: .bold)).foregroundColor(.white)
                    .multilineTextAlignment(.center).padding(.horizontal, DS.Spacing.lg)
                Text(resolvedSubheadline)
                    .font(.system(size: 14)).foregroundColor(.white.opacity(0.75))
                    .multilineTextAlignment(.center).padding(.horizontal, DS.Spacing.xl)
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

    // MARK: - Benefits (storm value props)
    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(0..<Self.stormValueProps.count, id: \.self) { i in
                HCSuccinctBenefitRow(icon: Self.stormValueProps[i].icon, title: Self.stormValueProps[i].title)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
    }

    // MARK: - Comparison Grid (SpeakLife vs. Other apps)
    // Two-column feature grid that reframes the decision from "is this worth it?"
    // to "why pay the same or more elsewhere for less?". Always shown on the
    // high-conversion paywall.
    //
    // Deliberately generic ("Other apps") rather than naming competitors: the
    // paywall ships through App Review and can't be hot-fixed, so a named claim
    // that goes stale becomes a false-advertising exposure on a surface we can't
    // quickly correct. Named, specific comparisons live on owned surfaces (ads,
    // landing pages) instead. The `.some` state keeps the journal row honest —
    // a few competitors do offer journaling.
    private enum OthersMark { case no, some, yes }
    private static let comparisonRows: [(feature: String, others: OthersMark)] = [
        ("Spoken declarations",  .no),
        ("Guided audio",         .no),
        ("AI Bible chat",        .yes),   // both have it — check on both columns
        ("Faith journal",        .some),
        ("Personalized to you",  .no)
    ]
    private static let comparisonColumnWidth: CGFloat = 92

    private var comparisonSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Why pay more for less?")
                .font(.system(size: 17, weight: .bold)).foregroundColor(.white)
                .padding(.bottom, DS.Spacing.md)

            comparisonHeaderRow
                .padding(.bottom, 6)
            Divider().background(Color.white.opacity(0.12))

            ForEach(Array(Self.comparisonRows.enumerated()), id: \.offset) { index, row in
                comparisonRow(feature: row.feature, others: row.others)
                if index < Self.comparisonRows.count - 1 {
                    Divider().background(Color.white.opacity(0.08))
                }
            }

            Text("Everything in one app — just \(annualPerMonth)/mo. Other apps charge up to $30/mo for less.")
                .font(.system(size: 12)).foregroundColor(.white.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.12), lineWidth: 1))
        )
        .padding(.horizontal, DS.Spacing.lg)
    }

    private var comparisonHeaderRow: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            Text("SpeakLife")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Constants.DAMidBlue)
                .frame(width: Self.comparisonColumnWidth)
            Text("Other apps")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
                .frame(width: Self.comparisonColumnWidth)
        }
    }

    private func comparisonRow(feature: String, others: OthersMark) -> some View {
        HStack(spacing: 0) {
            Text(feature)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundColor(.white.opacity(0.88))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.green)
                .frame(width: Self.comparisonColumnWidth)
            othersCell(others)
                .frame(width: Self.comparisonColumnWidth)
        }
        .padding(.vertical, 11)
    }

    @ViewBuilder
    private func othersCell(_ mark: OthersMark) -> some View {
        switch mark {
        case .no:
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.22))
        case .some:
            Text("Some")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.4))
        case .yes:
            // Feature both apps have. Still a check, but muted so SpeakLife's
            // green "win" rows stay the visual focus.
            Image(systemName: "checkmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white.opacity(0.55))
        }
    }

    // MARK: - Featured Testimonial (above the fold, anxiety-first)
    private var featuredTestimonial: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
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
        .padding(.horizontal, DS.Spacing.lg)
    }

    // MARK: - Remaining Testimonials
    private var remainingTestimonialsSection: some View {
        VStack(spacing: DS.Spacing.sm) {
            testimonialCard(
                quote: "I've tried journaling, therapy, everything. Nothing rewired my thinking like speaking God's Word daily. This app is different.",
                author: "DeShawn R.", stars: 5
            )
            testimonialCard(
                quote: "I was skeptical but this is the real deal. My mind literally works differently now. Worth every penny.",
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
        .padding(.horizontal, DS.Spacing.lg)
    }

    private func testimonialCard(quote: String, author: String, stars: Int) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
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
        .padding(DS.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06)))
    }

    // MARK: - Sticky Bottom
    private var stickyBottomSection: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [.clear, Color(red:0.07,green:0.10,blue:0.22).opacity(0.97)], startPoint: .top, endPoint: .bottom)
                .frame(height: 20)
            VStack(spacing: 18) {
                planSelectorSection
                trialCallout
               // closingLine
                ctaButton
                trialReassuranceLine
                generosityLine
                payWhatYouCanCTA
                bottomLinks
            }
            .padding(.horizontal, 20).padding(.vertical, DS.Spacing.md).padding(.bottom, DS.Spacing.xs)
            .background(Color(red:0.07,green:0.10,blue:0.22).opacity(0.97))
        }
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Plan Selector
    private var planSelectorSection: some View {
        GeometryReader { geo in
            let cardWidth = (geo.size.width - 10) / 2
            HStack(spacing: 10) {
                planCard(plan: nonAnnualPlan, topLabel: nil, title: nonAnnualTitle, price: nonAnnualPrice, sub: nonAnnualSub)
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
            AnalyticsService.shared.track("paywall_plan_switched", parameters: ["plan": plan.rawValue, "variant": paywallVariant, "segment": segmentParam])
        }) {
            ZStack(alignment: .top) {
                VStack(spacing: 4) {
                    if topLabel != nil { Spacer().frame(height: DS.Spacing.sm) }
                    Text(title).font(.system(size: 13, weight: .semibold)).foregroundColor(isSelected ? .white : .white.opacity(0.55))
                    Text(price).font(.system(size: 22, weight: .bold)).foregroundColor(isSelected ? .white : .white.opacity(0.45))
                    Text(sub).font(.system(size: 10)).foregroundColor(isSelected ? .white.opacity(0.7) : .white.opacity(0.3)).multilineTextAlignment(.center)
                }
                .padding(.vertical, 14).padding(.horizontal, DS.Spacing.xs)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? Constants.DAMidBlue.opacity(0.25) : Color.white.opacity(0.05))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(isSelected ? Constants.DAMidBlue : Color.white.opacity(0.15), lineWidth: isSelected ? 2 : 1))
                )
                if let label = topLabel {
                    Text(label).font(.system(size: 9, weight: .bold)).foregroundColor(.white)
                        .padding(.horizontal, DS.Spacing.xs).padding(.vertical, 3)
                        .background(Capsule().fill(Color.green))
                        .offset(y: -10)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Trial Callout (clarity-first: addresses the autocharge fear).
    // Day count is read from the selected plan's real StoreKit intro offer —
    // never hardcoded — and only shown when this user is actually eligible.
    private var trialCallout: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill").foregroundColor(.green).font(.system(size: 14))
            Text(trialCalloutText)
                .font(.system(size: 13, weight: .semibold)).foregroundColor(.white.opacity(0.92))
        }
    }

    private var trialCalloutText: String {
        if let days = selectedPlanTrialDays {
            return "Free for \(days) days. Cancel before day \(days) to pay nothing."
        }
        return "Start today. Cancel anytime in Settings."
    }

    // MARK: - Closing Line
    private var closingLine: some View {
        Text("God prepared the treasure chest.\nSpeakLife helps you open it — every single day.")
            .font(.system(size: 14, weight: .regular, design: .rounded))
            .foregroundColor(.white.opacity(0.7))
            .multilineTextAlignment(.center)
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.vertical, DS.Spacing.sm)
    }

    // MARK: - CTA
    // Free-anchored short CTA: the real StoreKit day count makes "free"
    // concrete ("Try 7 Days Free"); the non-trial fallback is a plain
    // "Continue" (the consistently winning minimal CTA). Shared by both
    // layouts' buttons.
    private var ctaText: String {
        if let days = selectedPlanTrialDays {
            return "Try \(days) Days Free"
        }
        return "Continue"
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

    // MARK: - Reassurance Stack (under CTA, trial-eligible only)
    // Repeats the no-payment-now promise right at the moment of commitment.
    // Billed price in the plan cards stays the most conspicuous price element
    // (Apple 3.1.2) — this line carries no price at all.
    @ViewBuilder
    private var trialReassuranceLine: some View {
        if selectedPlanTrialDays != nil {
            HStack(spacing: 5) {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.7))
                Text("No payment due now · Cancel anytime in Settings")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }

    // MARK: - Generosity Line (mission framing above the pay-what-you-can link)
    // TRUTHFULNESS: defensible because the pay-what-you-can program exists —
    // full-price subscribers effectively subsidize it. Never escalate this to
    // a literal one-for-one donated subscription claim ("gives SpeakLife free
    // to someone"); no such program exists.
    private var generosityLine: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "heart.fill")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.6))
                .padding(.top, 2)
            Text("Your subscription helps keep SpeakLife within reach for believers who can't afford full price.")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DS.Spacing.sm)
    }

    // MARK: - Pay What You Can (secondary CTA, intentionally subordinate to main CTA)
    // Gated by its own Remote Config flag (showPayWhatYouCanCTA), independent of
    // the soft/hard wall and the welcome-offer discount. Default OFF, so the link
    // is hidden until Remote Config turns it on.
    @ViewBuilder
    private var payWhatYouCanCTA: some View {
        if subscriptionStore.showPayWhatYouCanCTA {
            Button(action: {
                AnalyticsService.shared.track("paywall_pay_what_you_can_tapped", parameters: [
                    "variant": paywallVariant,
                    "segment": segmentParam
                ])
                showPayWhatYouCan = true
            }) {
                Text("Can't afford full price? Pay what you can →")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isCleanVariant ? cleanSubInk : .white.opacity(0.7))
                    .padding(.vertical, 4)
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel(Text("Pay what you can option"))
        }
    }

    // MARK: - Bottom Links
    private var bottomLinks: some View {
        HStack(spacing: DS.Spacing.lg) {
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
                    // paywall_dismissed fires at the moment of dismissal —
                    // before the welcome offer (if any) is shown — so funnel
                    // numbers stay comparable to the pre-offer baseline.
                    AnalyticsService.shared.track("paywall_dismissed", parameters: [
                        "variant": paywallVariant,
                        "plan_viewed": selectedPlan.rawValue,
                        "seconds_on_paywall": Int(Date().timeIntervalSince(timeOnPaywall)),
                        "segment": segmentParam
                    ])
                    if canShowWelcomeOffer {
                        welcomeOfferShown = true
                        withAnimation(.easeInOut(duration: 0.3)) { showWelcomeOffer = true }
                    } else {
                        callback?(); dismiss()
                    }
                }) {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 28))
                        .foregroundColor(isCleanVariant && !isCleanDarkTheme ? Color.gray.opacity(0.45) : .white.opacity(0.6))
                        .background(Circle().fill(isCleanVariant && !isCleanDarkTheme ? Color.black.opacity(0.05) : Color.black.opacity(0.2)))
                }
                .padding(.top, 56).padding(.trailing, 20)
            }
            Spacer()
        }
        .transition(.opacity)
    }

    // MARK: - Clean Variant Layout (high_conversion_clean_v1 / _dark_v1)
    // Minimal format modeled on top-converting meditation-app paywalls:
    // wordmark → headline → illustration → Annual (anchored) vs non-annual plan
    // cards → Continue → legal links. Shares every handler with the classic
    // layout (makePurchase, restore, close, welcome offer, mission screen), so
    // only the presentation differs — analytics stay joinable via paywallVariant.
    //
    // The palette is theme-aware: light (white page, navy ink) by default, or
    // the high-conversion paywall's dark gradient + white ink when
    // useCleanPaywallDarkTheme is on — everything below reads these four
    // colors, so the whole layout reskins from this one spot.

    private var cleanBackground: Color { Color(red: 0.99, green: 0.99, blue: 1.0) }
    private var cleanInk: Color {
        isCleanDarkTheme ? .white : Color(red: 0.10, green: 0.12, blue: 0.18)
    }
    private var cleanSubInk: Color {
        isCleanDarkTheme ? .white.opacity(0.65) : Color(red: 0.44, green: 0.47, blue: 0.54)
    }
    private var cleanStroke: Color {
        isCleanDarkTheme ? .white.opacity(0.18) : Color(red: 0.87, green: 0.89, blue: 0.93)
    }
    /// Plan-card fill, mirroring the classic dark layout's card treatment when
    /// the dark theme is on (translucent white card, stronger selected tint).
    private func cleanCardFill(isSelected: Bool) -> Color {
        if isCleanDarkTheme {
            return isSelected ? Constants.DAMidBlue.opacity(0.22) : Color.white.opacity(0.06)
        }
        return isSelected ? Constants.DAMidBlue.opacity(0.06) : Color.white
    }

    private var cleanVariantLayout: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    cleanWordmark.padding(.top, 16)
                    cleanPageDots.padding(.top, 14)
                    Text(resolvedHeadline)
                        .font(.system(size: 27, weight: .bold))
                        .foregroundColor(cleanInk)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28).padding(.top, 14)
                    Text(resolvedSubheadline)
                        .font(.system(size: 15))
                        .foregroundColor(cleanSubInk)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 32).padding(.top, 6)
                    cleanIllustrationCard.padding(.top, 18)
                    Spacer(minLength: 16)
                }
            }
            cleanBottomSection
        }
    }

    private var cleanWordmark: some View {
        (Text("Speak").foregroundColor(cleanInk) + Text("Life").foregroundColor(Constants.DAMidBlue))
            .font(.system(size: 18, weight: .bold, design: .rounded))
    }

    // Decorative progress dots matching the reference format (paywall reads as
    // the current step of a short flow).
    private var cleanPageDots: some View {
        HStack(spacing: 6) {
            Capsule().fill(cleanInk.opacity(0.7)).frame(width: 18, height: 5)
            Circle().fill(cleanInk.opacity(0.22)).frame(width: 5, height: 5)
            Circle().fill(cleanInk.opacity(0.22)).frame(width: 5, height: 5)
        }
    }

    private var cleanIllustrationCard: some View {
        Image("cleanPaywallHero")
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(maxWidth: .infinity)
            .frame(height: 230)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(cleanStroke, lineWidth: 1))
            .padding(.horizontal, 24)
    }

    private var cleanBottomSection: some View {
        VStack(spacing: 12) {
            cleanPlanCard(
                plan: .annual,
                title: "Annual",
                rightPrice: annualPerWeek,
                rightUnit: "/week",
                // Anchor only shown when annual is genuinely cheaper than a
                // year of the non-annual plan (same guard as the SAVE badge).
                struck: annualSavingsPercent != nil ? nonAnnualYearlyEquivalent : nil,
                subline: "\(annualPrice) per year",
                badge: "MOST POPULAR"
            )
            .padding(.top, 10) // room for the badge overhang
            cleanPlanCard(
                plan: nonAnnualPlan,
                title: nonAnnualTitle,
                rightPrice: nonAnnualPrice,
                rightUnit: showWeeklyPlan ? "/week" : "/month",
                struck: nil,
                subline: cleanNonAnnualSubline,
                badge: nil
            )
            cleanTrialLine
            cleanContinueButton
            // Same Remote Config-gated link as the dark layout, so enabling
            // showPayWhatYouCanCTA reaches both A/B arms.
            payWhatYouCanCTA
            cleanBottomLinks
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
        // Outer view ignores the bottom safe area, so this must clear the
        // home indicator (34pt) on its own.
        .padding(.bottom, 34)
    }

    private var cleanNonAnnualSubline: String {
        let cadence = showWeeklyPlan ? "weekly" : "monthly"
        guard let yearly = nonAnnualYearlyEquivalent else { return "Billed \(cadence)." }
        return "\(yearly) /year if billed \(cadence)."
    }

    private func cleanPlanCard(plan: PlanType, title: String, rightPrice: String, rightUnit: String, struck: String?, subline: String, badge: String?) -> some View {
        let isSelected = selectedPlan == plan
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) { selectedPlan = plan }
            AnalyticsService.shared.track("paywall_plan_switched", parameters: ["plan": plan.rawValue, "variant": paywallVariant, "segment": segmentParam])
        }) {
            ZStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 18))
                            .foregroundColor(isSelected ? Constants.DAMidBlue : cleanStroke)
                        Text(title)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(cleanInk)
                        Spacer()
                        (Text(rightPrice).font(.system(size: 16, weight: .semibold))
                            + Text(" \(rightUnit)").font(.system(size: 13, weight: .medium)))
                            .foregroundColor(cleanInk)
                    }
                    HStack(spacing: 5) {
                        if let struck {
                            Text(struck)
                                .font(.system(size: 13))
                                .foregroundColor(cleanSubInk.opacity(0.8))
                                .strikethrough(true, color: cleanSubInk.opacity(0.8))
                        }
                        Text(subline)
                            .font(.system(size: 13))
                            .foregroundColor(cleanSubInk)
                    }
                    .padding(.leading, 26)
                }
                .padding(.horizontal, 14).padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(cleanCardFill(isSelected: isSelected))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(isSelected ? Constants.DAMidBlue : cleanStroke, lineWidth: isSelected ? 1.5 : 1))
                )
                if let badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.5)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Capsule().fill(Constants.DAMidBlue))
                        .offset(y: -11)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    // Same autocharge-fear reassurance as the dark layout's trial callout —
    // real per-plan eligibility, real StoreKit day count, never hardcoded.
    @ViewBuilder
    private var cleanTrialLine: some View {
        if selectedPlanTrialDays != nil {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Constants.DAMidBlue).font(.system(size: 13))
                Text(trialCalloutText)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundColor(cleanSubInk)
            }
        }
    }

    private var cleanContinueButton: some View {
        Button(action: makePurchase) {
            Group {
                if declarationStore.isPurchasing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text(ctaText)
                        .font(.system(size: 17, weight: .bold)).foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity).padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(LinearGradient(colors: [Constants.DAMidBlue, Constants.DAMidBlue.opacity(0.85)], startPoint: .leading, endPoint: .trailing))
            )
        }
        .disabled(declarationStore.isPurchasing)
        .opacity(declarationStore.isPurchasing ? 0.7 : 1.0)
        .buttonStyle(PlainButtonStyle())
    }

    private var cleanBottomLinks: some View {
        HStack(spacing: DS.Spacing.lg) {
            Button("Restore Purchases", action: restore)
            Link("Terms", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
            Button("Privacy") { showPrivacyPolicy = true }
        }
        .font(.system(size: 12)).foregroundColor(cleanSubInk)
    }

    // MARK: - Welcome Offer Gate
    /// True when dismissing this paywall should show the one-time welcome
    /// offer instead of immediately advancing onboarding. All must hold:
    /// onboarding source, never shown before (persisted once-ever flag), soft
    /// paywall (hard mode has no close button, but gate it anyway), AND the
    /// Remote Config `discountID` product actually loaded from StoreKit as an
    /// annual SKU priced below the regular annual. The product checks are the
    /// same anti-phantom-price stance as the plan cards: if the discount
    /// product is unset, unloaded, not annual, or not actually cheaper, the
    /// offer never shows at all.
    private var canShowWelcomeOffer: Bool {
        guard source == "onboarding",
              !welcomeOfferShown,
              !effectiveIsHardPaywall,
              let discount = subscriptionStore.currentOfferedDiscount,
              let regular = subscriptionStore.currentOfferedPremium,
              discount.subscription?.subscriptionPeriod.unit == .year,
              let discountValue = Double(discount.price.description),
              let regularValue = Double(regular.price.description),
              discountValue < regularValue else { return false }
        return true
    }

    /// Runs the original dismissal path (advance onboarding + dismiss) exactly
    /// once after the welcome offer resolves, whether by purchase success or
    /// "No thanks, continue". Guarded so a purchase completion racing a
    /// decline tap can't fire the onboarding callback twice.
    private func resolveWelcomeOffer() {
        guard !welcomeOfferResolved else { return }
        welcomeOfferResolved = true
        callback?()
        dismiss()
    }

    // MARK: - Post-Purchase Mission Screen Routing
    /// Swaps in the mission screen after a successful purchase, remembering
    /// which success path to run when it continues. Callers clear the purchase
    /// spinner (declarationStore.isPurchasing) before invoking this, so the
    /// spinner never overlaps the mission screen. Auto-advances after 6
    /// seconds so the user is never trapped here.
    private func presentMissionScreen(_ resolution: MissionResolution) {
        missionResolution = resolution
        missionShownAt = Date()
        AnalyticsService.shared.track("post_purchase_mission_shown", parameters: [
            "variant": paywallVariant,
            "source": source
        ])
        withAnimation(.easeInOut(duration: 0.3)) { showMissionScreen = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) { continueMission() }
    }

    /// Runs the original purchase success path exactly once, whether triggered
    /// by the mission CTA tap or the 6-second auto-advance (both can fire).
    /// The welcome-offer path goes through resolveWelcomeOffer, preserving its
    /// own exactly-once guard.
    private func continueMission() {
        guard !missionContinued else { return }
        missionContinued = true
        AnalyticsService.shared.track("post_purchase_mission_continue", parameters: [
            "seconds_on_screen": Int(Date().timeIntervalSince(missionShownAt))
        ])
        switch missionResolution {
        case .mainPurchase:
            callback?()
            dismiss()
        case .welcomeOfferPurchase:
            resolveWelcomeOffer()
        }
    }

    // MARK: - Lifecycle
    private func onAppear() {
        // Latch the layout variant and theme BEFORE the impression events
        // below fire, so every event this session reports the variant shown.
        if lockedCleanVariant == nil {
            lockedCleanVariant = subscriptionStore.useCleanPaywallVariant
        }
        if lockedCleanDarkTheme == nil {
            lockedCleanDarkTheme = subscriptionStore.useCleanPaywallDarkTheme
        }
        timeOnPaywall = Date()
        selectedPlan = .annual
        // Check actual trial eligibility from Apple (re-run via onChange when
        // products finish loading after the paywall is already on screen).
        Task { await refreshTrialEligibility() }
        AnalyticsService.shared.trackPaywallImpression(paywallId: paywallVariant, metadata: [
            "variant": paywallVariant,
            "user_category": preferencesTracker.primaryCategory.rawValue,
            "initial_plan": "annual",
            "segment": segmentParam
        ])
        AnalyticsService.shared.track("paywall_shown", parameters: [
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

    /// Asks Apple, per product, whether THIS user is eligible for the intro
    /// offer on every plan this paywall can sell (annual + monthly + weekly,
    /// whichever loaded). Latest write wins, which is race-safe enough here:
    /// eligibility for a given product id never changes mid-session.
    private func refreshTrialEligibility() async {
        let products = [
            subscriptionStore.currentOfferedPremium,
            subscriptionStore.currentOfferedPremiumMonthly,
            subscriptionStore.currentOfferedWeekly
        ].compactMap { $0 }
        var eligibility: [String: Bool] = [:]
        for product in products {
            eligibility[product.id] = await product.subscription?.isEligibleForIntroOffer ?? false
        }
        let resolved = eligibility
        await MainActor.run {
            trialEligibility.merge(resolved) { _, new in new }
        }
    }

    // MARK: - Purchase
    private func makePurchase() {
        guard let product = selectedProduct else {
            errorMessage = "Please select a subscription option."
            isShowingError = true
            return
        }
        Juice.play(.tapSolid)
        AnalyticsService.shared.track("paywall_cta_tapped", parameters: [
            "variant": paywallVariant,
            "plan": selectedPlan.rawValue,
            "user_category": preferencesTracker.primaryCategory.rawValue,
            "product_id": product.id,
            "segment": segmentParam
        ])
        AnalyticsService.shared.track("paywall_subscribe_tapped", parameters: [
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
                    // NOTE: trial_started is fired by SubscriptionStore.purchase —
                    // the single source of truth, correctly gated on the purchased
                    // product's intro offer + this user's eligibility. Firing it
                    // here too double-counted trials (and misfired for plans
                    // without an intro offer, since the old gate only checked the
                    // annual product).
                    await MainActor.run {
                        // Spinner clears before the mission screen swaps in.
                        declarationStore.isPurchasing = false
                        if source == "onboarding" {
                            // Onboarding buyers see the mission screen first;
                            // its continue path runs callback?() + dismiss().
                            presentMissionScreen(.mainPurchase)
                        } else {
                            // Settings / feature-gate buyers are mid-task —
                            // keep the immediate dismiss.
                            callback?(); dismiss()
                        }
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

    // MARK: - Restore
    private func restore() {
        Task {
            await MainActor.run { declarationStore.isPurchasing = true }
            let restored = await subscriptionStore.restore()
            await MainActor.run {
                declarationStore.isPurchasing = false
                errorMessage = restored ? "Purchases restored" : "No purchases found to restore."
                isShowingError = true
            }
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

// MARK: - Shared Intro-Offer Helper
/// Days in the introductory free-trial offer for the given product, read from
/// the loaded StoreKit Product (never hardcoded). nil when the user isn't
/// eligible for an intro offer (per-user check done by callers) or when the
/// product has no free-trial intro offer configured. Shared by the main
/// paywall and the decline-path WelcomeOfferView so trial copy can never
/// disagree between the two screens.
fileprivate func introTrialDays(for product: Product?, isEligible: Bool) -> Int? {
    guard isEligible,
          let offer = product?.subscription?.introductoryOffer,
          offer.paymentMode == .freeTrial else { return nil }
    switch offer.period.unit {
    case .day:   return offer.period.value
    case .week:  return offer.period.value * 7
    case .month: return offer.period.value * 30
    case .year:  return offer.period.value * 365
    @unknown default: return nil
    }
}

// MARK: - Shared Currency Helper
/// Formats an arbitrary derived amount (price ÷ 52, price × 12, …) with the
/// product's own storefront format style, so the currency symbol and locale
/// always match the product's real displayPrice — never a hardcoded "$" and
/// never the device locale's default currency.
fileprivate func localizedPrice(_ amount: Decimal, in product: Product) -> String? {
    amount.formatted(product.priceFormatStyle)
}

// MARK: - Shared Per-Month Price Helper
/// Per-month equivalent of a yearly product's price, formatted in the
/// product's own locale and currency (never a hardcoded "$"). Shared by the
/// main paywall and WelcomeOfferView. nil if formatting fails.
fileprivate func perMonthString(yearlyProduct: Product) -> String? {
    localizedPrice(yearlyProduct.price / 12, in: yearlyProduct)
}

// MARK: - Welcome Offer (decline-path recovery screen)
/// Shown at most once ever (UserDefaults `welcomeOfferShown`) when an
/// onboarding user dismisses the soft paywall without buying, and only when
/// the Remote Config discount annual product actually loaded from StoreKit at
/// a price below the regular annual (gate: HighConversionPaywallView
/// .canShowWelcomeOffer — the anti-phantom-price guard). Exactly one step
/// deep per Apple Guideline 5.6: purchase and "No thanks" both resolve to the
/// original callback/dismiss path and no further offers follow. No countdown
/// timer or fake urgency — the framing line states plainly that it's a
/// one-time offer. All prices come straight from StoreKit.
struct WelcomeOfferView: View {
    @EnvironmentObject var declarationStore: DeclarationViewModel
    @EnvironmentObject var subscriptionStore: SubscriptionStore

    /// Paywall variant string, forwarded so offer analytics join cleanly with
    /// the paywall events that preceded them.
    let variant: String
    /// Onboarding segment, forwarded for the same reason.
    let segment: String
    /// Runs the original paywall dismissal path (onboarding callback +
    /// dismiss). The parent guards it so it can only ever fire once. Fired on
    /// decline ("No thanks, continue").
    let onResolve: () -> Void
    /// Fired on purchase success instead of onResolve, so the parent can show
    /// the post-purchase mission screen first. The mission screen's continue
    /// path then calls the same guarded resolve, preserving exactly-once
    /// semantics for the onboarding callback.
    let onPurchaseSuccess: () -> Void

    @State private var isShowingError = false
    @State private var errorMessage = ""
    @State private var showPrivacyPolicy = false
    @State private var isEligibleForTrial = false
    @State private var timeOnOffer = Date()

    // MARK: Products / Prices (all from StoreKit, never hardcoded)
    private let pricePlaceholder = "—"
    private var discountProduct: Product? { subscriptionStore.currentOfferedDiscount }
    private var regularProduct: Product? { subscriptionStore.currentOfferedPremium }
    private var discountPrice: String { discountProduct?.displayPrice ?? pricePlaceholder }
    private var regularPrice: String { regularProduct?.displayPrice ?? pricePlaceholder }
    private var discountPerMonth: String {
        guard let p = discountProduct else { return pricePlaceholder }
        return perMonthString(yearlyProduct: p) ?? pricePlaceholder
    }
    /// % saved vs the regular annual, computed from the real StoreKit prices.
    private var savingsPercent: Int? {
        guard let d = discountProduct.flatMap({ Double($0.price.description) }),
              let r = regularProduct.flatMap({ Double($0.price.description) }),
              r > 0, d < r else { return nil }
        return Int(((r - d) / r * 100).rounded())
    }
    /// Trial length of the discount product, nil when this user isn't eligible
    /// or the SKU has no free-trial intro offer.
    private var offerTrialDays: Int? {
        introTrialDays(for: discountProduct, isEligible: isEligibleForTrial)
    }
    private var ctaText: String {
        offerTrialDays != nil ? "Start Free Trial" : "Claim My Welcome Offer"
    }

    // MARK: Body
    var body: some View {
        ZStack {
            backgroundGradient.ignoresSafeArea()
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        header
                        offerCard.padding(.top, 28)
                        honestyLine.padding(.top, 18)
                        if let days = offerTrialDays {
                            trialLine(days: days).padding(.top, 14)
                        }
                        Spacer(minLength: 20)
                    }
                }
                bottomSection
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear(perform: onAppear)
        .alert("", isPresented: $isShowingError) {
            Button("OK", role: .cancel) { }
        } message: { Text(errorMessage) }
        .sheet(isPresented: $showPrivacyPolicy) { PrivacyPolicyView() }
    }

    // MARK: Chrome
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [Color(red:0.07,green:0.10,blue:0.22), Color(red:0.12,green:0.07,blue:0.20), Color(red:0.04,green:0.04,blue:0.12)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    private var header: some View {
        VStack(spacing: DS.Spacing.sm) {
            Image("appIconDisplay")
                .resizable().frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.2), lineWidth: 1))
            Text("BEFORE YOU GO")
                .font(.system(size: 12, weight: .bold))
                .tracking(2)
                .foregroundColor(Constants.DAMidBlue)
            Text("Speak life over your battle\nfor less.")
                .font(.system(size: 26, weight: .bold)).foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.lg)
        }
        .padding(.top, 56)
    }

    // MARK: Offer Card
    // The billed annual price is deliberately the most conspicuous price
    // element on the screen (Apple 3.1.2); the per-month equivalent is small
    // and clearly labeled as billed annually.
    private var offerCard: some View {
        VStack(spacing: 6) {
            if let pct = savingsPercent {
                Text("SAVE \(pct)%")
                    .font(.system(size: 11, weight: .bold)).foregroundColor(.white)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Capsule().fill(Color.green))
            }
            Text("was \(regularPrice)")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
                .strikethrough(true, color: .white.opacity(0.5))
                .padding(.top, 10)
            Text("\(discountPrice)/year")
                .font(.system(size: 36, weight: .bold)).foregroundColor(.white)
            Text("\(discountPerMonth) per month, billed annually")
                .font(.system(size: 13)).foregroundColor(.white.opacity(0.6))
        }
        .padding(.vertical, 22).padding(.horizontal, 18)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Constants.DAMidBlue.opacity(0.6), lineWidth: 1))
        )
        .padding(.horizontal, DS.Spacing.lg)
    }

    // MARK: Honest Framing (no fake urgency, no countdown)
    private var honestyLine: some View {
        Text("A one time welcome offer for new believers in the app. No pressure, no tricks.")
            .font(.system(size: 13)).foregroundColor(.white.opacity(0.65))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 36)
    }

    private func trialLine(days: Int) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill").foregroundColor(.green).font(.system(size: 14))
            Text("Free for \(days) days. Cancel before day \(days) to pay nothing.")
                .font(.system(size: 13, weight: .semibold)).foregroundColor(.white.opacity(0.92))
        }
    }

    // MARK: Bottom (CTA + decline + links)
    private var bottomSection: some View {
        VStack(spacing: 14) {
            ctaButton
            noThanksButton
            bottomLinks
        }
        .padding(.horizontal, 20).padding(.top, DS.Spacing.xs).padding(.bottom, DS.Spacing.lg)
    }

    private var ctaButton: some View {
        Button(action: claimOffer) {
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

    private var noThanksButton: some View {
        Button(action: declineOffer) {
            Text("No thanks, continue")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
                .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(declarationStore.isPurchasing)
    }

    private var bottomLinks: some View {
        HStack(spacing: DS.Spacing.lg) {
            Button("Restore", action: restore)
            Link("Terms", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
            Button("Privacy") { showPrivacyPolicy = true }
        }
        .font(.system(size: 12)).foregroundColor(.white.opacity(0.4))
    }

    // MARK: Lifecycle
    private func onAppear() {
        timeOnOffer = Date()
        // Per-user trial eligibility for the DISCOUNT product specifically —
        // it can differ from the main annual (same subscription group, but the
        // check is per user, not per product configuration).
        Task {
            let eligible = await subscriptionStore.currentOfferedDiscount?.subscription?.isEligibleForIntroOffer ?? false
            await MainActor.run { isEligibleForTrial = eligible }
        }
        AnalyticsService.shared.track("welcome_offer_shown", parameters: [
            "variant": variant,
            "segment": segment
        ])
    }

    // MARK: Purchase
    // On success SubscriptionStore.purchase fires trial_started /
    // subscription_started / premiumSucceeded itself — do NOT duplicate them
    // here (same single-source-of-truth rule as the main paywall CTA).
    private func claimOffer() {
        guard let product = discountProduct else {
            errorMessage = "This offer is unavailable right now. Please try again."
            isShowingError = true
            return
        }
        Juice.play(.tapSolid)
        AnalyticsService.shared.track("welcome_offer_cta_tapped", parameters: [
            "product_id": product.id
        ])
        Task {
            await MainActor.run { declarationStore.isPurchasing = true }
            do {
                let purchased = try await subscriptionStore.purchase(product, paywallName: "welcome_offer_v1")
                await MainActor.run {
                    declarationStore.isPurchasing = false
                    // Spinner cleared above; the parent swaps in the mission
                    // screen, whose continue path runs the guarded resolve.
                    if purchased { onPurchaseSuccess() }
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

    // MARK: Decline
    private func declineOffer() {
        AnalyticsService.shared.track("welcome_offer_dismissed", parameters: [
            "seconds_on_offer": Int(Date().timeIntervalSince(timeOnOffer))
        ])
        onResolve()
    }

    // MARK: Restore
    private func restore() {
        Task {
            await MainActor.run { declarationStore.isPurchasing = true }
            let restored = await subscriptionStore.restore()
            await MainActor.run {
                declarationStore.isPurchasing = false
                errorMessage = restored ? "Purchases restored" : "No purchases found to restore."
                isShowingError = true
            }
        }
    }
}

// MARK: - Post-Purchase Mission Screen
/// Brief, reverent thank-you state shown after a successful purchase from the
/// onboarding paywall (main CTA or welcome offer), BEFORE the original success
/// callback runs. Reframes the subscription as mission: paying members keep
/// the pay-what-you-can program viable. No confetti. TRUTHFULNESS: same
/// constraint as the paywall generosity line — never claim a one-for-one
/// donated subscription; no such program exists. Restore success and
/// settings / feature-gate purchases never route here. The parent auto-fires
/// onContinue after 6 seconds (exactly-once guarded) so nobody is trapped.
private struct PostPurchaseMissionView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: DS.Spacing.md) {
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(Constants.DAMidBlue)
                Text("WELCOME TO SPEAKLIFE")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(2)
                    .foregroundColor(Constants.DAMidBlue)
                Text("Your plan is ready.")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                Text("You just did more than subscribe. Members like you keep SpeakLife within reach for believers walking through their hardest season. Now let's take some ground.")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 36)
            Spacer()
            Button(action: onContinue) {
                Text("Start Speaking Life →")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(RoundedRectangle(cornerRadius: 30).fill(LinearGradient(colors: [Constants.DAMidBlue, Constants.DAMidBlue.opacity(0.85)], startPoint: .leading, endPoint: .trailing)))
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }
}
