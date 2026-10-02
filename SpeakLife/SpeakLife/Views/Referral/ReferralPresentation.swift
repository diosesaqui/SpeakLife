//
//  ReferralPresentation.swift
//  SpeakLife
//
//  When the referral page appears on its own, and what waits for it.
//  Spec §9.1, D5; tests FE-ENT-01 to 09, FE-ORD-*.
//
//  The ORDER of post-onboarding screens is decided by
//  `PostOnboardingPresenter` in Core, not by whichever modifier happens to fire
//  first. This type only asks it and carries the answer to the screen.
//

import SwiftUI
import SpeakLifeCore

@MainActor
final class ReferralPresentation: ObservableObject {

    static let shared = ReferralPresentation()

    /// Drives the automatic full-screen cover on Home. Set once, after
    /// onboarding, never on top of it.
    @Published var autoEntry: ReferralEntry?

    /// True while ANY referral page is on screen, whatever opened it. The
    /// welcome offer reads this and waits (FE-ORD-04): never two covers at once.
    @Published private(set) var isOpen = false

    private var openPages = 0

    /// Set synchronously when the post-onboarding page is owed, BEFORE Home
    /// mounts. Home's onAppear reads it to hold back its own paywall sheet:
    /// that sheet would otherwise go up in the 0.8s before the cover and
    /// swallow it, and a fullScreenCover dismissal re-runs Home's onAppear,
    /// which would put the paywall straight back over someone who just said
    /// "Not now".
    private(set) var offeredThisSession = false

    private init() {}

    func pageAppeared() {
        openPages += 1
        isOpen = true
    }

    func pageDisappeared() {
        openPages = max(0, openPages - 1)
        isOpen = openPages > 0
    }

    // MARK: - After onboarding

    /// What follows onboarding, from the inputs `finishOnboarding()` has.
    ///
    /// Pure apart from reading the key-value store, so it is tested with an
    /// in-memory store. A pending Stand invite goes first and the referral page
    /// is skipped this time WITHOUT being marked shown, so it is still owed
    /// from Profile (FE-ENT-05, FE-ORD-01).
    static func postOnboardingStep(config: ReferralConfig,
                                   isDebugReplay: Bool,
                                   converted: Bool,
                                   hasFullAccess: Bool,
                                   hasPendingStandCode: Bool,
                                   store: ReferralKeyValueStore) -> PostOnboardingStep {
        let input = ReferralEligibilityInput(
            flagEnabled: config.enabled,
            isDebugReplay: isDebugReplay,
            converted: converted,
            hasFullAccess: hasFullAccess,
            autoShownBefore: store.bool(forKey: ReferralKeys.autoShown),
            hasPendingStandCode: hasPendingStandCode,
            snapshot: ReferralSnapshotCache.load(from: store)
        )
        return PostOnboardingPresenter.next(
            hasPendingStandCode: hasPendingStandCode,
            referralEligible: ReferralEligibility.shouldAutoShow(input))
    }

    /// Presents the page over Home if `postOnboardingStep` said so. The
    /// once-ever flag is written at the moment of the decision, not on
    /// dismissal, so a kill during the cover cannot earn a second showing.
    func presentAfterOnboardingIfOwed(_ step: PostOnboardingStep,
                                      store: ReferralKeyValueStore = UserDefaultsReferralStore.shared) {
        guard case .referral = step else { return }
        store.set(true, forKey: ReferralKeys.autoShown)
        offeredThisSession = true
        // After `isOnboarded` flips and Home has mounted. A cover raised in the
        // same pass as the branch swap is dropped by SwiftUI.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.autoEntry = .postOnboarding
        }
    }
}

/// Attach to Home. The automatic page as a full-screen cover (spec §9.1).
@MainActor
struct ReferralAutoPresentationModifier: ViewModifier {

    @ObservedObject var subscriptionStore: SubscriptionStore
    @ObservedObject private var presentation = ReferralPresentation.shared

    func body(content: Content) -> some View {
        content
            .fullScreenCover(item: $presentation.autoEntry) { entry in
                ReferralPageView(entry: entry, subscriptionStore: subscriptionStore)
            }
    }
}

extension View {
    @MainActor
    func referralAutoPresentation(subscriptionStore: SubscriptionStore) -> some View {
        modifier(ReferralAutoPresentationModifier(subscriptionStore: subscriptionStore))
    }
}
