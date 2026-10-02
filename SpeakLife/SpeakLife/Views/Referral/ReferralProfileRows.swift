//
//  ReferralProfileRows.swift
//  SpeakLife
//
//  The two Profile rows. Spec §9.2; tests FE-ENT-10 to 14, FE-FLG-02.
//
//  Whether each row shows is `ReferralEligibility`'s call (Core, tested). The
//  inputs are gathered here because they live in UserDefaults and the stores.
//

import SwiftUI
import SpeakLifeCore

@MainActor
struct ReferralProfileRows: View {

    @ObservedObject var subscriptionStore: SubscriptionStore
    @ObservedObject var appState: AppState

    @State private var showPage = false
    @State private var showCodeEntry = false
    /// Bumped when either sheet closes, so the rows re-read the cache and the
    /// pending store, which are not observable.
    @State private var refresh = 0

    private var store: ReferralKeyValueStore { UserDefaultsReferralStore.shared }
    private var snapshot: ReferralSnapshot? { ReferralSnapshotCache.load(from: store) }

    /// "Get a year free", or "Redeem my free year" once it is earned. An earned
    /// reward stays reachable with the flag off (FE-FLG-02).
    private var showsYearFreeRow: Bool {
        _ = refresh
        return ReferralEligibility.showsProfileRow(
            flagEnabled: FeatureFlag.referralYearFreeEnabled,
            snapshot: snapshot,
            isPremium: subscriptionStore.isPremium,
            rewardRedeemed: store.bool(forKey: ReferralKeys.rewardRedeemed))
    }

    private var yearFreeTitle: String {
        switch snapshot?.status {
        case .unlocked?, .unlockedPendingCode?: return "Redeem my free year"
        default: return "Get a year free"
        }
    }

    /// "Have an invite code?" for 14 days after install, for somebody with no
    /// pending or completed claim. Hidden with the flag off like every other
    /// entry point, and never for an iCloud restore, which is not a new install.
    private var showsCodeEntryRow: Bool {
        _ = refresh
        guard FeatureFlag.referralYearFreeEnabled,
              !ReferralClaimCoordinator.shared.onboardingSkipped else { return false }
        let pending = ReferralCapture.sharedStore
        return ReferralEligibility.showsInviteCodeEntry(
            isOnboarded: appState.isOnboarded,
            firstLaunchAt: UserDefaults.standard.object(forKey: ReferralKeys.installDate) as? Date,
            now: Date(),
            hasPending: pending.pending != nil,
            isFinal: pending.isFinal)
    }

    var body: some View {
        if showsYearFreeRow {
            row(icon: "gift.fill", title: yearFreeTitle) {
                AnalyticsService.shared.trackUserAction("referral_row_tapped", category: "profile")
                showPage = true
            }
            .sheet(isPresented: $showPage, onDismiss: { refresh += 1 }) {
                ReferralPageView(entry: .profile, subscriptionStore: subscriptionStore)
            }
        }
        if showsCodeEntryRow {
            row(icon: "ticket.fill", title: "Have an invite code?") {
                showCodeEntry = true
            }
            .sheet(isPresented: $showCodeEntry, onDismiss: { refresh += 1 }) {
                InviteCodeEntryView()
            }
        }
    }

    private func row(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(Constants.DAMidBlue)
                Text(title)
                Spacer()
            }
        }
        .foregroundColor(.white)
    }
}
