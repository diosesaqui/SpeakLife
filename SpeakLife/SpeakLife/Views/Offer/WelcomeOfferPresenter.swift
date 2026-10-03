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

    /// Arms the offer from the user's FIRST Burst day.
    ///
    /// It does not necessarily SHOW on day one: `presentIfReady` yields to
    /// `PersonalDeclarationPrompt`, which owns that moment when it is owed.
    /// Arming early and yielding late is better than deferring to day two
    /// outright, because it splits on what is actually true of each user
    /// rather than on the calendar:
    ///
    ///  - Somebody owed the declaration ask gets that on day one, and the
    ///    offer on day two. They are also a returning user by then, which is a
    ///    stronger buy than a first-day finisher.
    ///  - Somebody NOT owed it (they already have a declaration, or they
    ///    onboarded before this moved) has nothing competing, so they get the
    ///    offer on day one, at the earliest honest moment.
    ///
    /// Neither user ever sees two covers on one tap, and nobody waits a day for
    /// no reason. The arm persists, so a yielded offer is never a lost one.
    ///
    /// Separate from `presentIfReady` so it also survives a user who finishes
    /// the burst and then force-quits on the celebration screen.
    func armAfterBurst(dayCount: Int) {
        guard dayCount >= 1, !hasBeenShown else { return }
        UserDefaults.standard.set(true, forKey: armedKey)
        isPendingThisBurst = true
    }

    /// Raises the offer if this user is armed and everything else lines up.
    /// Call once the burst's own cover has finished dismissing.
    func presentIfReady(subscriptionStore: SubscriptionStore) {
        // Whatever happens below, this Burst's window is over.
        defer { isPendingThisBurst = false }
        // Never over the declaration prompt.
        //
        // This is load-bearing, not defensive: both are armed on Burst day one
        // and `presentIfOwed` runs first in the same closure, so on a day where
        // the declaration is owed it is already presenting when we get here.
        // The offer stays armed and lands on the next Burst instead.
        guard !PersonalDeclarationPrompt.shared.isPendingOrShowing else { return }
        guard isArmed, isEligible(subscriptionStore) else { return }
        UserDefaults.standard.set(true, forKey: shownKey)
        UserDefaults.standard.set(false, forKey: armedKey)
        isPresented = true
    }

    /// True from the moment a Burst arms this until that Burst's presentation
    /// attempt has run, and while it is on screen.
    ///
    /// IN-MEMORY AND TRANSIENT ON PURPOSE. This read `isArmed && !hasBeenShown`
    /// first, which is persisted and only ever cleared when the offer actually
    /// SHOWS. A user who can never see one — already premium, or an install
    /// where the discount SKU never resolves — armed on their first Burst and
    /// stayed armed for life, so `StandDiscovery.shouldPrompt` yielded to an
    /// offer that was never coming and killed every Stand invite prompt
    /// permanently.
    private(set) var isPendingThisBurst = false

    var isPendingOrShowing: Bool { isPresented || isPendingThisBurst }

    // MARK: - Eligibility

    /// The anti-phantom-price guard, carried over verbatim from the paywall's
    /// old `canShowWelcomeOffer`. If the discount product is unset, has not
    /// loaded, is not annual, or is not actually cheaper than the regular
    /// annual, there is no honest offer to make and none is made.
    private func isEligible(_ store: SubscriptionStore) -> Bool {
        guard !hasBeenShown,
              !store.hasFullAccess,
              // The storm arm replaces this blanket offer with the objection
              // screen, which shows a discount only to someone who named price.
              !StormOnboarding.isMember,
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

    /// Passed in, NOT read from the environment.
    ///
    /// This is attached at the app root, ABOVE the `.environmentObject` calls,
    /// so it wraps the view those inject into and never sees them. Reading
    /// `@EnvironmentObject` here crashes at launch. `debugFlagPanel` and
    /// `standRedemption` sit two lines away carrying the same warning.
    @ObservedObject var subscriptionStore: SubscriptionStore
    @ObservedObject var declarationStore: DeclarationViewModel

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
    /// Attach once, at the app root. Takes its stores explicitly for the reason
    /// on `WelcomeOfferModifier.subscriptionStore`.
    func welcomeOffer(subscriptionStore: SubscriptionStore,
                      declarationStore: DeclarationViewModel) -> some View {
        modifier(WelcomeOfferModifier(subscriptionStore: subscriptionStore,
                                      declarationStore: declarationStore))
    }
}
