//
//  StormPaywallView.swift
//  SpeakLife
//
//  The storm arm's paywall, and everything that hangs off it: the objection
//  screen that replaces the blanket $39 welcome offer, and the first minutes
//  after a trial starts.
//
//  The one rule this screen is built around: nobody reads "free" and then meets
//  a full charge on Apple's sheet. Trial eligibility is checked BEFORE anything
//  renders, and an ineligible account never sees a timeline or the word free.
//
//  Layout (390×844): top bar · hero · trial timeline · three benefits, then a
//  footer pinned to the bottom with the price, the button and the reassurance
//  line. Everything that decides the sale is above the fold; the review card,
//  the reminder toggle and the legal links sit below it.
//

import SwiftUI
import StoreKit
import UserNotifications
import UIKit

enum StormPaywallOutcome {
    case purchased
    case closed
}

struct StormPaywallView: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore

    let storm: Storm
    /// "onboarding", "free_limit", "settings", "triggered", ...
    let placement: String
    let onFinish: (StormPaywallOutcome) -> Void

    private enum Phase: Hashable {
        case paywall
        case objection(trigger: String)
        case priceOffer
        case oneMoreDeclaration
        case oneMoreDone
        case reassurance
        case success
        case secondDeclaration
        case morningConfirm
        case saveAccount
    }

    @State private var phase: Phase = .paywall
    /// The objection screen is offered once per paywall run. A second cancel
    /// closes rather than looping the user through it again.
    @State private var objectionShown = false
    @State private var purchasedWithTrial = false

    private var paywallName: String { "storm_v1_\(placement)" }

    var body: some View {
        ZStack {
            StormBackground()
            content
                .transition(.opacity)
                .id(phase)
        }
        .environment(\.colorScheme, .dark)
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .animation(.easeInOut(duration: 0.3), value: phase)
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .paywall:
            StormPaywallMain(
                storm: storm,
                placement: placement,
                paywallName: paywallName,
                onPurchased: handlePurchased,
                onCancelledOnSheet: { routeToObjection(trigger: "sheet_cancel") },
                onClose: { routeToObjection(trigger: "close") }
            )
        case .objection(let trigger):
            StormObjectionScreen(trigger: trigger, discountAvailable: StormPriceOffer.isAvailable(subscriptionStore)) { reason in
                handleObjection(reason)
            } onClose: {
                onFinish(.closed)
            }
        case .priceOffer:
            StormPriceOfferScreen(
                paywallName: "storm_v1_price_offer",
                onPurchased: handlePurchased,
                onDecline: { onFinish(.closed) }
            )
        case .oneMoreDeclaration:
            StormSpeakScreen(
                line: storm.planDays[1],
                eyebrow: "ONE MORE, ON US",
                title: "Here's Day 2 of your plan",
                backup: StormSpeakBackup(config: subscriptionStore.stormSpeakBackup)
            ) { outcome in
                AnalyticsService.shared.track("objection_extra_declaration", parameters: [
                    "outcome": "\(outcome)", "storm": storm.rawValue
                ])
                phase = .oneMoreDone
            }
        case .oneMoreDone:
            StormOneMoreDoneScreen(storm: storm) {
                phase = .paywall
            } onDecline: {
                onFinish(.closed)
            }
        case .reassurance:
            StormReassuranceScreen(
                storm: storm,
                paywallName: "storm_v1_reassurance",
                onPurchased: handlePurchased,
                onCancelledOnSheet: { onFinish(.closed) },
                onDecline: { onFinish(.closed) }
            )
        case .success:
            StormSuccessScreen(isTrial: purchasedWithTrial) {
                phase = .secondDeclaration
            }
        case .secondDeclaration:
            StormSpeakScreen(
                line: storm.secondDeclaration,
                eyebrow: "YOUR FIRST WIN AS A MEMBER",
                title: "Speak it again, stronger",
                backup: StormSpeakBackup(config: subscriptionStore.stormSpeakBackup)
            ) { outcome in
                AnalyticsService.shared.track("second_declaration_spoken", parameters: [
                    "outcome": "\(outcome)", "storm": storm.rawValue, "placement": placement
                ])
                phase = .morningConfirm
            }
        case .morningConfirm:
            StormMorningConfirmScreen(storm: storm) {
                if AppleSignInService.shared.isSignedIn {
                    onFinish(.purchased)
                } else {
                    phase = .saveAccount
                }
            }
        case .saveAccount:
            StormSaveAccountScreen {
                onFinish(.purchased)
            }
        }
    }

    // MARK: Routing

    private func routeToObjection(trigger: String) {
        // Only the onboarding paywall asks. A paywall the user opened from the
        // app, or the free-layer limit, closes when closed.
        guard placement == "onboarding", !objectionShown else {
            onFinish(.closed)
            return
        }
        objectionShown = true
        AnalyticsService.shared.track("objection_shown", parameters: [
            "trigger": trigger, "storm": storm.rawValue
        ])
        phase = .objection(trigger: trigger)
    }

    private func handleObjection(_ reason: StormObjection) {
        AnalyticsService.shared.track("objection_selected", parameters: [
            "reason": reason.rawValue, "storm": storm.rawValue
        ])
        switch reason {
        case .price:
            phase = StormPriceOffer.isAvailable(subscriptionStore) ? .priceOffer : .reassurance
        case .notSure:
            phase = .oneMoreDeclaration
        case .worried:
            phase = .reassurance
        case .justLooking:
            onFinish(.closed)
        }
    }

    private func handlePurchased(isTrial: Bool) {
        purchasedWithTrial = isTrial
        StormPlan.start(storm: storm, isTrial: isTrial,
                        enforcementEnabled: subscriptionStore.enforcementEnabled,
                        pushesEnabled: subscriptionStore.stormTrialPushes)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        phase = .success
    }
}

/// The storm paywall presented from inside the app (a sheet, a tab), for a
/// storm-arm member. Dismisses itself when it finishes.
struct StormPaywallSheet: View {
    @Environment(\.dismiss) private var dismiss
    let placement: String
    let callback: (() -> Void)?

    var body: some View {
        StormPaywallView(storm: StormOnboarding.selectedStorm ?? .fear, placement: placement) { _ in
            callback?()
            dismiss()
        }
    }
}

/// What a free storm member sees when today's declaration is used. Day 1
/// gets a soft "see you tomorrow"; from day 2 the paywall leads.
struct StormFreeLimitView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showPaywall = StormFreeLayer.freeDay >= 2

    var body: some View {
        if showPaywall {
            StormPaywallSheet(placement: "free_limit_day_\(min(StormFreeLayer.freeDay, 7))", callback: nil)
        } else {
            ZStack {
                StormBackground()
                VStack(spacing: 0) {
                    Spacer()
                    VStack(spacing: 14) {
                        Image(systemName: "sunrise.fill")
                            .font(.system(size: 52))
                            .foregroundColor(StormStyle.gold)
                            .accessibilityHidden(true)
                        Text("That's today's declaration")
                            .font(.title.weight(.bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        Text("A new one is waiting for you tomorrow morning. Or unlock every declaration now.")
                            .font(.body)
                            .foregroundColor(StormStyle.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 28)
                    Spacer()
                    VStack(spacing: 8) {
                        StormPrimaryButton(title: "Unlock every declaration") { showPaywall = true }
                        StormTextButton(title: "See you tomorrow") { dismiss() }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 36)
                }
            }
            .environment(\.colorScheme, .dark)
        }
    }
}

// MARK: - Purchase model

/// Loads the annual product and this account's trial eligibility together, so
/// the screen never shows a price or the word "free" it then has to take back.
@MainActor
final class StormPurchaseModel: ObservableObject {
    enum LoadState: Equatable {
        case loading
        case ready
        case failed
    }

    @Published private(set) var state: LoadState = .loading
    @Published private(set) var product: Product?
    /// Days of free trial THIS account gets. 0 = not eligible, or no trial offer.
    @Published private(set) var trialDays = 0
    @Published var isPurchasing = false

    var isTrialEligible: Bool { trialDays > 0 }

    private var loadTask: Task<Void, Never>?

    func load(from store: SubscriptionStore, pick: @escaping (SubscriptionStore) -> Product?) {
        loadTask?.cancel()
        state = .loading
        loadTask = Task { [weak self] in
            // Products arrive asynchronously after launch; give them a bounded
            // window, then offer a retry rather than a blank screen.
            var candidate = pick(store)
            var waited = 0.0
            while candidate == nil, waited < 6 {
                try? await Task.sleep(nanoseconds: 300_000_000)
                waited += 0.3
                if Task.isCancelled { return }
                candidate = pick(store)
            }
            guard let self else { return }
            guard let product = candidate else {
                self.state = .failed
                AnalyticsService.shared.track("paywall_load_failed", parameters: ["paywall": "storm_v1"])
                return
            }
            var days = 0
            if let subscription = product.subscription,
               subscription.introductoryOffer?.paymentMode == .freeTrial,
               await subscription.isEligibleForIntroOffer {
                days = TrialExperienceService.introTrialDays(for: product) ?? 0
            }
            if Task.isCancelled { return }
            self.product = product
            self.trialDays = days
            self.state = .ready
        }
    }

    func retry(from store: SubscriptionStore, pick: @escaping (SubscriptionStore) -> Product?) {
        state = .loading
        Task {
            await store.requestProducts()
            load(from: store, pick: pick)
        }
    }

    var annualPrice: String { product?.displayPrice ?? "" }

    var monthlyEquivalent: String {
        guard let product else { return "" }
        return (product.price / 12).formatted(product.priceFormatStyle)
    }
}

// MARK: - Main paywall

private struct StormPaywallMain: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let storm: Storm
    let placement: String
    let paywallName: String
    let onPurchased: (Bool) -> Void
    let onCancelledOnSheet: () -> Void
    let onClose: () -> Void

    @StateObject private var model = StormPurchaseModel()
    @State private var remindMe = true
    @State private var notificationsDenied = false
    @State private var v = false
    @State private var pulse = false
    @State private var todayGlow = false
    @State private var alertMessage: String?
    @State private var showPrivacy = false
    @State private var viewedLogged = false

    private var ctaTitle: String {
        guard model.isTrialEligible else {
            return "Continue — \(model.annualPrice)/year"
        }
        if subscriptionStore.stormCtaCopy == "try_free" { return "Try it free" }
        return model.trialDays == 7 ? "Start my free week" : "Start my \(model.trialDays)-day free trial"
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView(showsIndicators: false) {
                VStack(spacing: 26) {
                    hero.stormAppear(v)
                    if model.state == .ready && model.isTrialEligible {
                        StormTrialTimeline(trialDays: model.trialDays, price: model.annualPrice, glowToday: todayGlow)
                            .stormAppear(v, delay: 0.15)
                    }
                    benefits.stormAppear(v, delay: 0.25)
                    belowFold
                }
                .padding(.horizontal, 22)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            footer.stormAppear(v, delay: 0.35)
        }
        .onAppear {
            v = true
            model.load(from: subscriptionStore) { $0.currentOfferedPremium }
            refreshNotificationStatus()
            startMotion()
        }
        .onChange(of: model.state) { _, state in
            if state == .ready { logViewed() }
        }
        .alert(alertMessage ?? "", isPresented: Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        }
        .sheet(isPresented: $showPrivacy) { PrivacyPolicyView() }
        .task { await pulseLoop() }
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack {
            Button {
                AnalyticsService.shared.track("paywall_closed", parameters: [
                    "placement": placement, "paywall": paywallName,
                    "trial_eligible": model.isTrialEligible
                ])
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Close")
            Spacer()
            Button("Restore", action: restore)
                .font(.body.weight(.medium))
                .foregroundColor(StormStyle.secondary)
                .frame(minHeight: 44)
        }
        .padding(.horizontal, 12)
        .padding(.top, 52)
    }

    // MARK: Hero

    private var hero: some View {
        VStack(spacing: 10) {
            StormGoldHeadline(text: config.paywallHeadline)
                .font(.title.weight(.bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text("7 mornings, 7 scriptures each, starting with \(storm.firstDeclaration.reference).")
                .font(.body)
                .foregroundColor(StormStyle.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity)
        .background(
            RadialGradient(colors: [StormStyle.gold.opacity(0.18), .clear],
                           center: .center, startRadius: 4, endRadius: 200)
        )
    }

    // MARK: Benefits

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 14) {
            // The benefit screen's promises, same order, each with its "when".
            ForEach(Array(config.paywallBenefits.enumerated()), id: \.offset) { _, benefit in
                benefitRow(benefit)
            }
            if subscriptionStore.stormAlsoIncluded {
                alsoIncluded.padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Supporting value under the storm promise, not competing with it.
    /// Remote Config `stormAlsoIncluded` turns it on for the with/without test.
    private var alsoIncluded: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Also included")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(StormStyle.gold)
            alsoRow("headphones", "Scripture audio for the nights your mind won't rest")
            alsoRow("bubble.left.and.text.bubble.right.fill", "Ask any Bible question and get answers rooted in verses")
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.06)))
    }

    private func alsoRow(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: symbol)
                .foregroundColor(StormStyle.secondary)
                .frame(width: 22)
                .accessibilityHidden(true)
            Text(text)
                .font(.callout)
                .foregroundColor(StormStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var config: ResolvedStormConfig { StormConfigStore.resolved(for: storm) }

    private func benefitRow(_ benefit: StormConfig.Benefit) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(StormStyle.gold)
                .accessibilityHidden(true)
            (Text(benefit.when.hasSuffix(":") ? benefit.when : benefit.when + ":").bold()
             + Text(" " + benefit.text))
                .font(.body)
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Below the fold

    private var belowFold: some View {
        VStack(spacing: 22) {
            StormReviewCard()
            if model.isTrialEligible {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(isOn: $remindMe) {
                        Text("Remind me 2 days before my trial ends")
                            .font(.body)
                            .foregroundColor(.white)
                    }
                    .tint(StormStyle.gold)
                    .onChange(of: remindMe) { _, on in
                        AnalyticsService.shared.track("trial_reminder_toggled", parameters: ["on": on])
                        if on { requestNotificationsIfNeeded() }
                    }
                    if remindMe && notificationsDenied {
                        Text("Notifications are off for SpeakLife. Turn them on in Settings so the reminder can reach you.")
                            .font(.callout)
                            .foregroundColor(StormStyle.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.06)))
            }
            HStack(spacing: 22) {
                Link("Terms", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                Button("Privacy") { showPrivacy = true }
                Button("Restore", action: restore)
            }
            .font(.callout)
            .foregroundColor(StormStyle.secondary)
        }
        .padding(.top, 8)
    }

    // MARK: Footer (pinned)

    private var footer: some View {
        VStack(spacing: 10) {
            priceLine
            if model.state == .failed {
                StormPrimaryButton(title: "Couldn't load pricing. Tap to retry.") {
                    model.retry(from: subscriptionStore) { $0.currentOfferedPremium }
                }
            } else {
                StormPrimaryButton(
                    title: model.state == .ready ? ctaTitle : " ",
                    isEnabled: model.state == .ready,
                    isLoading: model.isPurchasing
                ) { purchase() }
                .scaleEffect(pulse ? 1.03 : 1)
            }
            Text(model.isTrialEligible
                 ? "No payment due now · Cancel anytime · We'll remind you."
                 : "Cancel anytime in Settings.")
                .font(.subheadline)
                .foregroundColor(StormStyle.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(model.state == .ready ? 1 : 0)
        }
        .padding(.horizontal, 22)
        .padding(.top, 14)
        .padding(.bottom, 30)
        .background(
            StormStyle.navyDeep.opacity(0.96)
                .shadow(color: .black.opacity(0.35), radius: 12, y: -4)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    @ViewBuilder
    private var priceLine: some View {
        switch model.state {
        case .loading:
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.12))
                .frame(width: 230, height: 24)
                .accessibilityLabel("Loading price")
        case .failed:
            EmptyView()
        case .ready:
            VStack(spacing: 4) {
                if model.isTrialEligible {
                    Label("No payment due now", systemImage: "checkmark.shield.fill")
                        .font(.headline)
                        .foregroundColor(StormStyle.gold)
                    (Text("\(model.trialDays) days free, then ")
                     + Text("\(model.annualPrice)/year").font(.title3.weight(.bold))
                     + Text(" (\(model.monthlyEquivalent)/mo)"))
                        .font(.body)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                } else {
                    (Text("\(model.annualPrice)/year").font(.title3.weight(.bold))
                     + Text("  (\(model.monthlyEquivalent)/mo)"))
                        .font(.body)
                        .foregroundColor(.white)
                }
            }
        }
    }

    // MARK: Actions

    private func purchase() {
        guard let product = model.product, !model.isPurchasing else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        AnalyticsService.shared.track("paywall_cta_tapped", parameters: [
            "placement": placement, "paywall": paywallName, "product_id": product.id,
            "trial_eligible": model.isTrialEligible, "cta": ctaTitle
        ])
        model.isPurchasing = true
        let trialDays = model.trialDays
        let priceText = "\(model.annualPrice)/year"
        let wantsReminder = remindMe
        Task {
            defer { model.isPurchasing = false }
            do {
                let outcome = try await subscriptionStore.purchaseOutcome(product, paywallName: paywallName)
                switch outcome {
                case .purchased:
                    if trialDays > 0 && wantsReminder {
                        StormTrialReminder.schedule(trialStart: Date(), trialDays: trialDays, priceText: priceText)
                    }
                    onPurchased(trialDays > 0)
                case .cancelled:
                    onCancelledOnSheet()
                case .pending:
                    alertMessage = "Your purchase is waiting for approval. You'll have full access as soon as it's approved."
                case .notEntitled:
                    alertMessage = "Your purchase went through, but we couldn't unlock it yet. Tap Restore in a moment."
                }
            } catch {
                alertMessage = "Something went wrong with the App Store. Please try again."
            }
        }
    }

    private func restore() {
        Task {
            model.isPurchasing = true
            let restored = await subscriptionStore.restore()
            model.isPurchasing = false
            AnalyticsService.shared.track("paywall_restore", parameters: ["restored": restored, "paywall": paywallName])
            if restored {
                alertMessage = "Welcome back. Your membership is restored."
                onPurchased(false)
            } else {
                alertMessage = "We couldn't find a membership on this Apple ID to restore."
            }
        }
    }

    private func logViewed() {
        guard !viewedLogged, let product = model.product else { return }
        viewedLogged = true
        AnalyticsService.shared.track("paywall_viewed", parameters: [
            "placement": placement,
            "paywall": paywallName,
            "variant": subscriptionStore.onboardingVariantName,
            "storm": storm.rawValue,
            "product_id": product.id,
            "price": product.displayPrice,
            "trial_eligible": model.isTrialEligible,
            "trial_days": model.trialDays,
            "cta": ctaTitle,
            "also_included": subscriptionStore.stormAlsoIncluded,
            "storm_config": StormConfigStore.source
        ])
        // The cross-arm event every other paywall fires, so the existing
        // onboarding funnels count this one without a special case.
        AnalyticsService.shared.track("paywall_shown", parameters: [
            "source": placement,
            "variant": paywallName,
            "segment": UserDefaults.standard.string(forKey: "onboarding_segment") ?? "",
            "pain": storm.rawValue
        ])
    }

    private func refreshNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async { notificationsDenied = settings.authorizationStatus == .denied }
        }
    }

    private func requestNotificationsIfNeeded() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else {
                DispatchQueue.main.async { notificationsDenied = settings.authorizationStatus == .denied }
                return
            }
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
                AnalyticsService.shared.track("notification_permission", parameters: [
                    "granted": granted, "source": "storm_paywall_reminder", "placement": "paywall"
                ])
                DispatchQueue.main.async { notificationsDenied = !granted }
            }
        }
    }

    private func startMotion() {
        guard !reduceMotion else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeInOut(duration: 0.8)) { todayGlow = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation(.easeInOut(duration: 0.8)) { todayGlow = false }
            }
        }
    }

    /// A soft breath on the button every 3.5s, starting after 2s. Runs in the
    /// view's `.task`, so it stops the moment the paywall leaves the screen.
    private func pulseLoop() async {
        guard !reduceMotion else { return }
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        while !Task.isCancelled {
            if model.state == .ready && !model.isPurchasing {
                withAnimation(.easeInOut(duration: 0.35)) { pulse = true }
                try? await Task.sleep(nanoseconds: 350_000_000)
                withAnimation(.easeInOut(duration: 0.35)) { pulse = false }
            }
            try? await Task.sleep(nanoseconds: 3_500_000_000)
        }
    }
}

/// The config headline with its storm name in gold: the words between "Your"
/// and "plan" ("Your **Health storm** plan is ready."), or after "plan for"
/// ("Your plan for **your family** is ready."). All white if neither fits.
private struct StormGoldHeadline: View {
    let text: String

    private var highlightRange: Range<String.Index>? {
        if let r = text.range(of: #"(?<=plan for ).+(?= is ready)"#, options: .regularExpression) { return r }
        return text.range(of: #"(?<=^Your ).+?(?=( storm)? plan)"#, options: .regularExpression)
    }

    var body: some View {
        if let range = highlightRange {
            (Text(String(text[..<range.lowerBound]))
             + Text(String(text[range])).foregroundColor(StormStyle.gold)
             + Text(String(text[range.upperBound...])))
        } else {
            Text(text)
        }
    }
}

// MARK: - Trial timeline

struct StormTrialTimeline: View {
    let trialDays: Int
    let price: String
    var glowToday = false

    private var reminderDay: Int { max(trialDays - 2, 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            node(icon: "lock.open.fill", title: "Today", detail: "Full access. Start speaking.", highlighted: true, isLast: false)
            node(icon: "bell.fill", title: "Day \(reminderDay)", detail: "We'll remind you before your trial ends.", highlighted: false, isLast: false)
            node(icon: "creditcard.fill", title: "Day \(trialDays)", detail: "\(price)/year begins. Cancel anytime before.", highlighted: false, isLast: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func node(icon: String, title: String, detail: String, highlighted: Bool, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(highlighted ? StormStyle.gold : Color.white.opacity(0.12))
                        .frame(width: 40, height: 40)
                        .shadow(color: StormStyle.gold.opacity(highlighted && glowToday ? 0.9 : 0), radius: 14)
                    Image(systemName: icon)
                        .font(.body.weight(.semibold))
                        .foregroundColor(highlighted ? StormStyle.navy : StormStyle.secondary)
                }
                if !isLast {
                    Rectangle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 2)
                        .frame(minHeight: 18)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(highlighted ? StormStyle.gold : .white)
                Text(detail)
                    .font(.body)
                    .foregroundColor(StormStyle.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 8)
            .padding(.bottom, isLast ? 0 : 10)
        }
    }
}

// MARK: - Review card

private struct StormReviewCard: View {
    /// A real, verbatim App Store review (TestimonialWallView keeps the set).
    /// This one is chosen because it is about the free week itself.
    private var review: WallReview {
        TestimonialWallView.reviews.first { $0.author == "Heather L Compton" } ?? TestimonialWallView.reviews[0]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 4) {
                ForEach(0..<5, id: \.self) { _ in
                    Image(systemName: "star.fill").foregroundColor(StormStyle.gold)
                }
                Text("4.9 on the App Store")
                    .font(.callout.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.leading, 6)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Rated 4.9 out of 5 on the App Store")
            Text("\u{201C}\(review.quote)\u{201D}")
                .font(.body)
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
            Text(review.author)
                .font(.callout)
                .foregroundColor(StormStyle.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.06)))
    }
}

// MARK: - Objection

enum StormObjection: String, CaseIterable, Identifiable {
    case price
    case notSure = "not_sure"
    case worried = "worried_charged"
    case justLooking = "just_looking"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .price:       return "The price"
        case .notSure:     return "Not sure I'll use it"
        case .worried:     return "Worried I'll be charged"
        case .justLooking: return "Just looking"
        }
    }
}

private struct StormObjectionScreen: View {
    let trigger: String
    let discountAvailable: Bool
    let onPick: (StormObjection) -> Void
    let onClose: () -> Void
    @State private var v = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.title3.weight(.semibold))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Close")
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 52)
            Spacer()
            VStack(spacing: 12) {
                Text("What's holding you back?")
                    .font(.title.weight(.bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                Text("Tell us, and we'll answer it honestly.")
                    .font(.body)
                    .foregroundColor(StormStyle.secondary)
            }
            .padding(.horizontal, 24)
            .stormAppear(v)
            VStack(spacing: 10) {
                ForEach(StormObjection.allCases) { reason in
                    Button { onPick(reason) } label: {
                        HStack {
                            Text(reason.label)
                                .font(.body.weight(.semibold))
                                .foregroundColor(.white)
                            Spacer()
                            Image(systemName: "chevron.right").foregroundColor(StormStyle.secondary)
                        }
                        .padding(.horizontal, 18)
                        .frame(minHeight: 58)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.08)))
                    }
                    .buttonStyle(.dsPressable(feel: .tapLight))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 26)
            .stormAppear(v, delay: 0.1)
            Spacer()
            Spacer()
        }
        .onAppear { v = true }
    }
}

/// The discount, shown only to someone who named the price, only once per install.
enum StormPriceOffer {
    private static let shownKey = "storm_price_offer_shown"

    static func isAvailable(_ store: SubscriptionStore) -> Bool {
        guard !UserDefaults.standard.bool(forKey: shownKey),
              let discount = store.currentOfferedDiscount,
              let regular = store.currentOfferedPremium,
              discount.subscription?.subscriptionPeriod.unit == .year,
              discount.price < regular.price else { return false }
        return true
    }

    static func markShown() {
        UserDefaults.standard.set(true, forKey: shownKey)
        // One discount per person across the app: the post-Burst welcome offer
        // reads the same key and stands down.
        UserDefaults.standard.set(true, forKey: "welcomeOfferShown")
    }
}

private struct StormPriceOfferScreen: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    let paywallName: String
    let onPurchased: (Bool) -> Void
    let onDecline: () -> Void

    @StateObject private var model = StormPurchaseModel()
    @State private var alertMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 16) {
                Text("A one-time price, just for you")
                    .font(.title.weight(.bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                if model.state == .ready, let regular = subscriptionStore.currentOfferedPremium {
                    (Text(model.annualPrice + "/year").foregroundColor(StormStyle.gold).font(.largeTitle.weight(.bold)))
                        .multilineTextAlignment(.center)
                    Text("instead of \(regular.displayPrice)/year. This offer won't be shown again.")
                        .font(.body)
                        .foregroundColor(StormStyle.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    if model.isTrialEligible {
                        StormTrialTimeline(trialDays: model.trialDays, price: model.annualPrice)
                            .padding(.top, 8)
                    }
                } else {
                    ProgressView().tint(.white)
                }
            }
            .padding(.horizontal, 24)
            Spacer()
            VStack(spacing: 8) {
                StormPrimaryButton(
                    title: model.isTrialEligible ? "Start my free week" : "Claim \(model.annualPrice)/year",
                    isEnabled: model.state == .ready,
                    isLoading: model.isPurchasing
                ) { purchase() }
                Text(model.isTrialEligible ? "No payment due now · Cancel anytime in Settings." : "Cancel anytime in Settings.")
                    .font(.subheadline)
                    .foregroundColor(StormStyle.secondary)
                StormTextButton(title: "No thanks", action: onDecline)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 30)
        }
        .onAppear {
            StormPriceOffer.markShown()
            model.load(from: subscriptionStore) { $0.currentOfferedDiscount }
            AnalyticsService.shared.track("objection_price_offer_shown", parameters: [
                "product_id": subscriptionStore.currentOfferedDiscount?.id ?? "none"
            ])
        }
        .alert(alertMessage ?? "", isPresented: Binding(
            get: { alertMessage != nil }, set: { if !$0 { alertMessage = nil } }
        )) { Button("OK", role: .cancel) {} }
    }

    private func purchase() {
        guard let product = model.product, !model.isPurchasing else { return }
        model.isPurchasing = true
        let trialDays = model.trialDays
        let priceText = "\(model.annualPrice)/year"
        Task {
            defer { model.isPurchasing = false }
            do {
                switch try await subscriptionStore.purchaseOutcome(product, paywallName: paywallName) {
                case .purchased:
                    if trialDays > 0 {
                        StormTrialReminder.schedule(trialStart: Date(), trialDays: trialDays, priceText: priceText)
                    }
                    onPurchased(trialDays > 0)
                case .cancelled:
                    onDecline()
                case .pending:
                    alertMessage = "Your purchase is waiting for approval."
                case .notEntitled:
                    alertMessage = "Your purchase went through, but we couldn't unlock it yet. Tap Restore in a moment."
                }
            } catch {
                alertMessage = "Something went wrong with the App Store. Please try again."
            }
        }
    }
}

private struct StormOneMoreDoneScreen: View {
    let storm: Storm
    let onBackToPaywall: () -> Void
    let onDecline: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 14) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 52))
                    .foregroundColor(StormStyle.gold)
                    .accessibilityHidden(true)
                Text("That's two mornings. Five more are waiting.")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Your \(storm.planName) plan brings you 7 scriptures every morning.")
                    .font(.body)
                    .foregroundColor(StormStyle.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 28)
            Spacer()
            VStack(spacing: 8) {
                StormPrimaryButton(title: "See my plan", action: onBackToPaywall)
                StormTextButton(title: "Maybe later", action: onDecline)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 36)
        }
    }
}

/// "Worried I'll be charged": the timeline and the reminder promise again,
/// with the button right under it.
private struct StormReassuranceScreen: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    let storm: Storm
    let paywallName: String
    let onPurchased: (Bool) -> Void
    let onCancelledOnSheet: () -> Void
    let onDecline: () -> Void

    @StateObject private var model = StormPurchaseModel()
    @State private var alertMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    Spacer().frame(height: 80)
                    Text(model.isTrialEligible ? "Here's exactly how it works" : "No surprises")
                        .font(.title.weight(.bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    if model.state == .ready {
                        if model.isTrialEligible {
                            StormTrialTimeline(trialDays: model.trialDays, price: model.annualPrice)
                            Text("Nothing is charged today. We send you a reminder two days before your trial ends, and you can cancel in Settings with two taps.")
                                .font(.body)
                                .foregroundColor(StormStyle.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            Text("This Apple ID has used its free trial, so the price shown on Apple's sheet is charged today: \(model.annualPrice)/year. You can cancel anytime in Settings.")
                                .font(.body)
                                .foregroundColor(StormStyle.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    } else {
                        ProgressView().tint(.white)
                    }
                }
                .padding(.horizontal, 24)
            }
            VStack(spacing: 8) {
                StormPrimaryButton(
                    title: model.isTrialEligible ? "Start my free week" : "Continue — \(model.annualPrice)/year",
                    isEnabled: model.state == .ready,
                    isLoading: model.isPurchasing
                ) { purchase() }
                StormTextButton(title: "Not now", action: onDecline)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 30)
        }
        .onAppear { model.load(from: subscriptionStore) { $0.currentOfferedPremium } }
        .alert(alertMessage ?? "", isPresented: Binding(
            get: { alertMessage != nil }, set: { if !$0 { alertMessage = nil } }
        )) { Button("OK", role: .cancel) {} }
    }

    private func purchase() {
        guard let product = model.product, !model.isPurchasing else { return }
        model.isPurchasing = true
        let trialDays = model.trialDays
        let priceText = "\(model.annualPrice)/year"
        Task {
            defer { model.isPurchasing = false }
            do {
                switch try await subscriptionStore.purchaseOutcome(product, paywallName: paywallName) {
                case .purchased:
                    if trialDays > 0 {
                        StormTrialReminder.schedule(trialStart: Date(), trialDays: trialDays, priceText: priceText)
                    }
                    onPurchased(trialDays > 0)
                case .cancelled:
                    onCancelledOnSheet()
                case .pending:
                    alertMessage = "Your purchase is waiting for approval."
                case .notEntitled:
                    alertMessage = "Your purchase went through, but we couldn't unlock it yet. Tap Restore in a moment."
                }
            } catch {
                alertMessage = "Something went wrong with the App Store. Please try again."
            }
        }
    }
}

// MARK: - After purchase

private struct StormSuccessScreen: View {
    let isTrial: Bool
    let onContinue: () -> Void
    @State private var v = false

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "sun.max.fill")
                .font(.system(size: 64))
                .foregroundColor(StormStyle.gold)
                .accessibilityHidden(true)
                .stormAppear(v)
            Text(isTrial ? "Your first week has begun" : "Welcome to SpeakLife")
                .font(.largeTitle.weight(.bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .stormAppear(v, delay: 0.1)
            Text("Let's speak your next declaration right now.")
                .font(.body)
                .foregroundColor(StormStyle.secondary)
                .stormAppear(v, delay: 0.2)
            Spacer()
        }
        .padding(.horizontal, 28)
        .onAppear {
            v = true
            AnalyticsService.shared.track("storm_purchase_success_shown", parameters: ["is_trial": isTrial])
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { onContinue() }
        }
    }
}

private struct StormMorningConfirmScreen: View {
    let storm: Storm
    let onContinue: () -> Void

    @State private var time: Date = {
        let t = StormOnboarding.morningTime ?? (7, 0)
        return Calendar.current.date(bySettingHour: t.hour, minute: t.minute, second: 0, of: Date()) ?? Date()
    }()
    @State private var editing = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 14) {
                Image(systemName: "alarm.fill")
                    .font(.system(size: 50))
                    .foregroundColor(StormStyle.gold)
                    .accessibilityHidden(true)
                Text("Tomorrow at \(time.formatted(date: .omitted, time: .shortened))")
                    .font(.title.weight(.bold))
                    .foregroundColor(.white)
                Text("Your Daily Burst: 7 scriptures for \(storm.domain), opening with \(storm.planDays[1].reference).")
                    .font(.body)
                    .foregroundColor(StormStyle.secondary)
                    .multilineTextAlignment(.center)
                if editing {
                    DatePicker("Morning time", selection: $time, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                }
            }
            .padding(.horizontal, 28)
            Spacer()
            VStack(spacing: 8) {
                StormPrimaryButton(title: "Perfect") { save() }
                if !editing {
                    StormTextButton(title: "Change time") { withAnimation { editing = true } }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 36)
        }
    }

    private func save() {
        let c = Calendar.current.dateComponents([.hour, .minute], from: time)
        StormOnboarding.morningMinutes = (c.hour ?? 7) * 60 + (c.minute ?? 0)
        // Re-schedules the morning push at this time, carrying the plan's line.
        DailyDeclarationReminderService.shared.setupDailyReminders()
        AnalyticsService.shared.track("storm_morning_time_confirmed", parameters: [
            "hour": c.hour ?? 7, "minute": c.minute ?? 0, "changed": editing
        ])
        onContinue()
    }
}

/// Ask for Apple sign-in only now, after purchase, framed around what it keeps.
private struct StormSaveAccountScreen: View {
    @ObservedObject private var appleSignIn = AppleSignInService.shared
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 14) {
                Image(systemName: "icloud.and.arrow.up.fill")
                    .font(.system(size: 50))
                    .foregroundColor(StormStyle.gold)
                    .accessibilityHidden(true)
                Text("Save your declarations")
                    .font(.title.weight(.bold))
                    .foregroundColor(.white)
                Text("Sign in with Apple so your plan, streak and declarations follow you to a new phone.")
                    .font(.body)
                    .foregroundColor(StormStyle.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                if let error = appleSignIn.errorMessage {
                    Text(error).font(.callout).foregroundColor(.white)
                }
            }
            .padding(.horizontal, 28)
            Spacer()
            VStack(spacing: 8) {
                StormPrimaryButton(title: "Sign in with Apple", isLoading: appleSignIn.isLoading) {
                    AnalyticsService.shared.track("storm_save_account_tapped")
                    appleSignIn.signIn()
                }
                StormTextButton(title: "Not now") {
                    AnalyticsService.shared.track("storm_save_account_skipped")
                    onDone()
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 36)
        }
        .onChange(of: appleSignIn.isSignedIn) { _, signedIn in
            if signedIn { onDone() }
        }
    }
}

// MARK: - Plan start

enum StormPlan {
    /// Starts the seven-day plan the onboarding previewed: records the start
    /// date (the morning push reads the day's line from it), and starts the
    /// in-app Enforcement week with exactly those lines so the app and the
    /// preview never disagree.
    static func start(storm: Storm, isTrial: Bool, enforcementEnabled: Bool, pushesEnabled: Bool) {
        guard StormOnboarding.planStartedOn == nil else { return }
        StormOnboarding.selectedStorm = storm
        StormOnboarding.planStartedOn = Date()
        if enforcementEnabled, EnforcementService.shared.activeEnforcement == nil {
            EnforcementService.shared.startCurated(
                storm.planDays.map { $0.declaration(in: storm.category) },
                primary: storm.category,
                isPremium: true
            )
        }
        DailyDeclarationReminderService.shared.setupDailyReminders()
        if isTrial && pushesEnabled { StormTrialPushes.schedule(storm: storm, trialStart: Date()) }
        AnalyticsService.shared.track("storm_plan_started", parameters: ["storm": storm.rawValue, "is_trial": isTrial])
    }
}
