//
//  YearInReviewEntryPoints.swift
//  SpeakLife
//
//  Every way into the Year in Review, and the one place that presents it.
//
//  It used to auto-show once and could never be reopened, so anyone who
//  tapped away, or wanted to share later, lost it for the year. Now the
//  launch takeover, the Today card, the Profile row and the December push all
//  ask `YearInReviewCoordinator` to open it, and HomeView's single
//  fullScreenCover shows whatever the coordinator holds.
//

import Combine
import SwiftUI

// MARK: - Coordinator

/// Holds the recap that should be on screen, and the stats that decide
/// whether the entry points show. Only touched from the main thread.
final class YearInReviewCoordinator: ObservableObject {

    static let shared = YearInReviewCoordinator()

    struct Presentation: Identifiable {
        let stats: YearInReviewStats
        let source: YearInReviewSource
        /// Premium status at open time. Fixed for the whole showing so a
        /// late RevenueCat answer cannot insert the Strength slide under the
        /// page the user is on.
        let includesPremiumExtras: Bool
        var id: Int { stats.year }
    }

    /// The recap HomeView is presenting, or nil.
    @Published var presentation: Presentation?

    /// This window's stats while the Today card and Profile row should show,
    /// else nil. Refreshed by HomeView on appear and on every foreground.
    @Published private(set) var entryStats: YearInReviewStats?

    /// A tapped recap push, waiting until nothing else is on screen.
    @Published private(set) var pendingPush = false

    private var burstSubscription: AnyCancellable?

    private init() {
        // A Daily Burst finished mid-session (perhaps the user's first this
        // year) changes the numbers and can make the entry points appear.
        burstSubscription = BurstCompletionTracker.shared.$completions
            .dropFirst()
            // @Published emits before the new value is stored; hopping to the
            // next main-queue turn lets `build` read the updated history.
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh() }
    }

    /// Rebuilds the entry-point stats for today. Cheap: one pass over the
    /// Daily Burst history.
    func refresh(now: Date = Date(), calendar: Calendar = YearInReviewStats.gregorian) {
        guard let year = YearInReviewStats.recapYear(for: now, calendar: calendar) else {
            if entryStats != nil { entryStats = nil }
            return
        }
        let stats = YearInReviewStats.build(for: year, asOf: now, calendar: calendar)
        entryStats = YearInReviewEligibility.showsEntryPoint(recapYear: year, daysActive: stats.daysActive)
            ? stats : nil
    }

    /// Opens the recap. Returns false when the window is shut, there is
    /// nothing to show for this source, or a recap is already up.
    @discardableResult
    func open(source: YearInReviewSource, isPremium: Bool, now: Date = Date()) -> Bool {
        guard presentation == nil else { return false }
        refresh(now: now)
        guard let stats = entryStats,
              YearInReviewEligibility.canOpen(source: source,
                                              recapYear: stats.year,
                                              daysActive: stats.daysActive) else { return false }
        presentation = Presentation(stats: stats, source: source, includesPremiumExtras: isPremium)
        return true
    }

    func requestFromPush() { pendingPush = true }
    func clearPendingPush() { pendingPush = false }

    // MARK: Seen flag

    /// Whether the recap for `year` has actually been on screen.
    static func hasBeenSeen(year: Int) -> Bool {
        UserDefaults.standard.bool(forKey: YearInReviewEligibility.seenKey(for: year))
    }

    /// Set from the recap's own `onAppear`, never before, so a presentation
    /// that is blocked or dropped does not burn the year's auto-launch.
    static func markSeen(year: Int) {
        UserDefaults.standard.set(true, forKey: YearInReviewEligibility.seenKey(for: year))
    }
}

// MARK: - Today card

/// The card at the top of the Today tab during the window. Renders nothing
/// outside it.
struct YearInReviewTodayCard: View {
    @ObservedObject private var coordinator = YearInReviewCoordinator.shared
    @EnvironmentObject private var subscriptionStore: SubscriptionStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shimmer = false

    var body: some View {
        if let stats = coordinator.entryStats {
            Button {
                coordinator.open(source: .todayCard, isPremium: subscriptionStore.isPremium)
            } label: {
                card(stats)
            }
            .buttonStyle(.dsPressable(feel: .tapSolid))
            .accessibilityLabel(stats.entryTitle + ". See your year of standing.")
        }
    }

    private func card(_ stats: YearInReviewStats) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "crown.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(YearInReviewPalette.heroGold)
                .frame(width: 46, height: 46)
                .background(Circle().fill(YearInReviewPalette.glow.opacity(0.14)))
                .overlay(Circle().strokeBorder(YearInReviewPalette.label.opacity(0.35), lineWidth: 1))

            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: stats.entryTitle.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(2.5)
                    .foregroundStyle(YearInReviewPalette.label)
                Text("See your year of standing")
                    .font(.system(size: 18, weight: .semibold, design: .serif))
                    .foregroundStyle(.white)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, 14)
        .background(
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.06, green: 0.06, blue: 0.20), Color(red: 0.20, green: 0.11, blue: 0.34)],
                    startPoint: .leading, endPoint: .trailing
                )
                RadialGradient(
                    colors: [YearInReviewPalette.glow.opacity(0.30), .clear],
                    center: .trailing, startRadius: 0, endRadius: 180
                )
            }
        )
        .overlay(shimmerLayer)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .strokeBorder(
                    LinearGradient(colors: [YearInReviewPalette.label.opacity(0.6), YearInReviewPalette.label.opacity(0.15)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1
                )
        )
        .dsShadow(DS.Elevation.low)
        .onAppear {
            guard !reduceMotion, !shimmer else { return }
            withAnimation(.easeInOut(duration: 2.6).delay(0.8).repeatForever(autoreverses: false)) {
                shimmer = true
            }
        }
        // A tab switch tears down the repeating animation but keeps
        // `shimmer` true, which would leave the band parked off-card. Reset
        // it without animation so the next appear starts the sweep again.
        .onDisappear {
            var reset = Transaction()
            reset.disablesAnimations = true
            withTransaction(reset) { shimmer = false }
        }
    }

    /// A slow band of light that sweeps across now and then.
    private var shimmerLayer: some View {
        GeometryReader { geo in
            LinearGradient(colors: [.clear, .white.opacity(0.14), .clear],
                           startPoint: .leading, endPoint: .trailing)
                .frame(width: geo.size.width * 0.45)
                .rotationEffect(.degrees(12))
                .offset(x: shimmer ? geo.size.width * 1.2 : -geo.size.width * 0.6)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Profile row

/// A Profile row into the recap during the window. Renders nothing outside it.
struct YearInReviewProfileSection: View {
    @ObservedObject private var coordinator = YearInReviewCoordinator.shared
    @EnvironmentObject private var subscriptionStore: SubscriptionStore

    var body: some View {
        if let stats = coordinator.entryStats {
            Section {
                Button {
                    coordinator.open(source: .profile, isPremium: subscriptionStore.isPremium)
                } label: {
                    HStack {
                        Image(systemName: "crown.fill")
                            .foregroundColor(DS.Palette.gold)
                        Text(verbatim: stats.entryTitle)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.45))
                    }
                }
                .foregroundColor(.white)
            }
        }
    }
}

private extension YearInReviewStats {
    /// "Your 2026 so far" in December, "Your 2026 in SpeakLife" in January.
    var entryTitle: String {
        isInProgress ? "Your \(year) so far" : "Your \(year) in SpeakLife"
    }
}

#if DEBUG
#Preview("Today card") {
    YearInReviewTodayCard()
        .padding(20)
        .background(Color.black)
        .environmentObject(SubscriptionStore())
        .onAppear { YearInReviewCoordinator.shared.refresh() }
}
#endif
