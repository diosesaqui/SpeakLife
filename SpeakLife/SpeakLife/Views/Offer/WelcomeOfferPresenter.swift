//
//  WelcomeOfferPresenter.swift
//  SpeakLife
//
//  Owns WHEN the one-time welcome offer appears. The screen itself is
//  `WelcomeOfferView` in HighConversionPaywallView.swift and did not change.
//
//  THE MOVE THIS FILE EXISTS FOR
//
//  The offer used to intercept the X on the onboarding paywall: decline to
//  pay, get shown a cheaper price. That asks somebody to judge a price
//  minutes after install, before they have felt anything the app does — and
//  a discount is the one thing a person with no experience of the product has
//  no way to value. It also spent the single once-ever offer on the user's
//  least-informed moment.
//
//  It now fires after their first Daily Burst. They have spoken seven
//  declarations out loud and felt it, the app has done the thing it promised,
//  and the offer answers something they now actually want.
//
//  THE TWO RULES THIS ENFORCES
//
//   1. ONCE EVER. `welcomeOfferShown` is the same UserDefaults key the
//      paywall used, so anyone who already saw the offer on the old decline
//      path never sees it again. Set at presentation, never reset.
//
//   2. NEVER TO SOMEBODY WHO ALREADY HAS ACCESS. `hasFullAccess`, not
//      `isPremium` — a Stand Pass holder is inside a seven-day grant whose
//      own day-7 celebration is the paywall moment. Cutting into that with a
//      discount on day 1 sells against our own better offer. They stay
//      eligible for this one later, because the once-ever flag is only set
//      when the offer is actually shown.
//

import SwiftUI
import StoreKit

@MainActor
final class WelcomeOfferPresenter: ObservableObject {

    static let shared = WelcomeOfferPresenter()

    /// Drives the cover. The modifier below is the only thing that reads it.
    @Published var isPresented = false

    /// Set at presentation and never reset: at most one welcome offer per
    /// install, for life. Shared with the old onboarding path by key.
    private let shownKey = "welcomeOfferShown"

    /// Set when the first Daily Burst completes, and cleared only once the
    /// offer has actually been shown.
    ///
    /// Armed and shown are separate on purpose. StoreKit products load
    /// asynchronously at launch, so a user who finishes their first burst
    /// before `currentOfferedDiscount` arrives would otherwise burn their one
    /// chance on a check that could not have passed. Staying armed means the
    /// offer lands on the next burst instead of never.
    private let armedKey = "welcomeOfferArmed"

    private init() {}

    var hasBeenShown: Bool { UserDefaults.standard.bool(forKey: shownKey) }
    private var isArmed: Bool { UserDefaults.standard.bool(forKey: armedKey) }

    // MARK: - Trigger

    /// Arms the offer, from the user's SECOND Burst day onward.
    ///
    /// Day one belongs to `PersonalDeclarationPrompt`, which moved out of
    /// onboarding onto that same moment; two sheets on one tap is one too many.
    /// Deferring is not a cost here — somebody who came back for a second day
    /// is a stronger buy than somebody who just finished their first.
    ///
    /// Separate from `presentIfReady` so the arm survives a user who finishes
    /// the burst and then force-quits on the celebration screen.
    func armAfterBurst(dayCount: Int) {
        guard dayCount >= 2, !hasBeenShown else { return }
        UserDefaults.standard.set(true, forKey: armedKey)
    }

    /// Raises the offer if this user is armed and everything else lines up.
    /// Call once the burst's own cover has finished dismissing.
    func presentIfReady(subscriptionStore: SubscriptionStore) {
        // Never over the declaration prompt. It owns Burst day one and this
        // arms from day two, so they should not overlap — but if the prompt is
        // ever retimed, the offer yields rather than fighting it for a cover.
        guard !PersonalDeclarationPrompt.shared.isPendingOrShowing else { return }
        guard isArmed, isEligible(subscriptionStore) else { return }
        UserDefaults.standard.set(true, forKey: shownKey)
        UserDefaults.standard.set(false, forKey: armedKey)
        isPresented = true
    }

    /// True while an offer is waiting to be shown or is on screen.
    ///
    /// Read by `StandDiscovery.shouldPrompt` so the two day-one sheets cannot
    /// fight over the same moment.
    var isPendingOrShowing: Bool {
        isPresented || (isArmed && !hasBeenShown)
    }

    // MARK: - Eligibility

    /// The anti-phantom-price guard, carried over verbatim from the paywall's
    /// old `canShowWelcomeOffer`. If the discount product is unset, has not
    /// loaded, is not annual, or is not actually cheaper than the regular
    /// annual, there is no honest offer to make and none is made.
    private func isEligible(_ store: SubscriptionStore) -> Bool {
        guard !hasBeenShown,
              !store.hasFullAccess,
              let discount = store.currentOfferedDiscount,
              let regular = store.currentOfferedPremium,
              discount.subscription?.subscriptionPeriod.unit == .year,
              let discountValue = Double(discount.price.description),
              let regularValue = Double(regular.price.description),
              discountValue < regularValue else { return false }
        return true
    }

    func dismiss() {
        isPresented = false
    }
}

// MARK: - Presentation

/// Presents the offer over whichever screen launched the burst.
///
/// Attached to the two views that present `DailyDeclarationBurstView` rather
/// than to the app root: a `fullScreenCover` raised from an ancestor while a
/// descendant's cover is still on screen is dropped silently, and the burst's
/// own cover is mid-dismissal at exactly this moment.
struct WelcomeOfferModifier: ViewModifier {

    @ObservedObject private var presenter = WelcomeOfferPresenter.shared
    @EnvironmentObject private var subscriptionStore: SubscriptionStore
    @EnvironmentObject private var declarationStore: DeclarationViewModel

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $presenter.isPresented) {
                WelcomeOfferView(
                    variant: "post_first_burst",
                    segment: "post_first_burst",
                    onResolve: { presenter.dismiss() },
                    onPurchaseSuccess: { presenter.dismiss() }
                )
                .environmentObject(subscriptionStore)
                .environmentObject(declarationStore)
            }
    }
}

extension View {
    /// Attach wherever `DailyDeclarationBurstView` is presented from.
    func welcomeOffer() -> some View {
        modifier(WelcomeOfferModifier())
    }
}
