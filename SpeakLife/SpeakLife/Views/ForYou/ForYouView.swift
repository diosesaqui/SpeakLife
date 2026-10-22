//
//  ForYouView.swift
//  SpeakLife
//
//  "Your Week": the ten declarations the server wrote on Sunday from the ones
//  the user favorited. Opened from the category chooser and from the Sunday
//  push. Free users see the first few and the rest behind the paywall.
//

import SwiftUI
import SpeakLifeCore

struct ForYouView: View {

    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var viewModel: DeclarationViewModel
    /// How the screen was opened, for analytics.
    let source: String

    private enum LoadState: Equatable {
        case loading
        case loaded(ForYouSet)
        case empty
        case failed
    }

    @State private var state: LoadState = .loading
    @State private var favorited: Set<String> = []
    @State private var presentPremiumView = false

    var body: some View {
        NavigationStack {
            ScrollView {
                content
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.bottom, DS.Spacing.xl)
            }
            .background(
                Image(subscriptionStore.onboardingBGImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .accessibilityLabel("Close")
                }
            }
        }
        .task { await load() }
        // Unlocking from here should show the rest without reopening.
        .onChange(of: subscriptionStore.isPremium) { _, isPremium in
            if isPremium { Task { await load() } }
        }
        .sheet(isPresented: $presentPremiumView) {
            PremiumView()
                .environmentObject(subscriptionStore)
        }
    }

    // MARK: - States

    @ViewBuilder
    private var content: some View {
        switch state {
        case .loading:
            ProgressView()
                .tint(.white)
                .frame(maxWidth: .infinity, minHeight: 300)
        case .empty:
            message(
                icon: "sparkles",
                title: "Your week is on its way",
                body: "Favorite at least three declarations this week. Every Sunday evening we write ten new ones from them, just for you."
            )
        case .failed:
            VStack(spacing: DS.Spacing.md) {
                message(
                    icon: "wifi.exclamationmark",
                    title: "Couldn't load your week",
                    body: "Check your connection and try again."
                )
                Button("Try again") { Task { await load() } }
                    .font(DS.Typography.callout)
                    .foregroundColor(.white)
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.sm)
                    .dsGlass(cornerRadius: DS.Radius.pill)
            }
        case .loaded(let set):
            loaded(set)
        }
    }

    private func message(icon: String, title: String, body: String) -> some View {
        VStack(spacing: DS.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 34, weight: .semibold))
                .foregroundColor(DS.Palette.gold)
            Text(title)
                .font(DS.Typography.headline)
                .foregroundColor(DS.Palette.textPrimary)
                .multilineTextAlignment(.center)
            Text(body)
                .font(DS.Typography.body)
                .foregroundColor(DS.Palette.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity)
        .dsGlass(cornerRadius: DS.Radius.md)
        .padding(.top, DS.Spacing.xl)
    }

    private func loaded(_ set: ForYouSet) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text("YOUR WEEK")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .tracking(1.5)
                    .foregroundColor(DS.Palette.gold)
                Text(set.title)
                    .font(DS.Typography.display)
                    .foregroundColor(DS.Palette.textPrimary)
                Text("Written from the declarations you saved. Speak them out loud this week.")
                    .font(DS.Typography.callout)
                    .foregroundColor(DS.Palette.textSecondary)
            }
            .padding(.top, DS.Spacing.sm)

            ForEach(set.declarations) { item in
                card(item)
            }

            if set.locked > 0 {
                lockedCard(count: set.locked)
            }
        }
    }

    private func card(_ item: ForYouDeclaration) -> some View {
        let isFavorite = favorited.contains(item.text)
        return VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(item.text)
                .font(DS.Typography.headline)
                .foregroundColor(DS.Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(item.bibleVerseText)
                .font(.system(size: 15, weight: .regular).italic())
                .foregroundColor(DS.Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Text(item.book)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(DS.Palette.gold)
                Spacer()
                Button {
                    toggleFavorite(item, isFavorite: !isFavorite)
                } label: {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(isFavorite ? .red : .white)
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel(isFavorite ? "Remove from favorites" : "Add to favorites")
            }
        }
        .padding(DS.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsGlass(cornerRadius: DS.Radius.md)
    }

    private func lockedCard(count: Int) -> some View {
        Button {
            AnalyticsService.shared.track("for_you_unlock_tapped", parameters: ["locked": count])
            presentPremiumView = true
        } label: {
            VStack(spacing: DS.Spacing.sm) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(DS.Palette.gold)
                Text("\(count) more declarations were written for you")
                    .font(DS.Typography.headline)
                    .foregroundColor(DS.Palette.textPrimary)
                    .multilineTextAlignment(.center)
                Text("Unlock Premium")
                    .font(DS.Typography.callout)
                    .foregroundColor(.black)
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(Capsule().fill(DS.Palette.gold))
            }
            .padding(DS.Spacing.lg)
            .frame(maxWidth: .infinity)
            .dsGlass(cornerRadius: DS.Radius.md)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Actions

    private func load() async {
        if case .loaded = state {} else { state = .loading }
        do {
            let response = try await ForYouService.shared.latestSet(isPremium: subscriptionStore.isPremium)
            guard let set = response.set else {
                state = .empty
                return
            }
            favorited = Set(set.declarations.map(\.text).filter { viewModel.isFavorite(text: $0) })
            state = .loaded(set)
            AnalyticsService.shared.track("for_you_viewed", parameters: [
                "week_id": set.weekId,
                "count": set.declarations.count,
                "locked": set.locked,
                "source": source,
            ])
        } catch ForYouError.disabled {
            dismiss()
        } catch {
            state = .failed
        }
    }

    private func toggleFavorite(_ item: ForYouDeclaration, isFavorite: Bool) {
        if isFavorite {
            favorited.insert(item.text)
        } else {
            favorited.remove(item.text)
        }
        viewModel.setFavorite(item.declaration, isFavorite: isFavorite)
        AnalyticsService.shared.track(isFavorite ? "for_you_favorited" : "for_you_unfavorited", parameters: [
            "category": item.category,
        ])
    }
}

// MARK: - Push routing

/// A For You push to open. In memory only, like `StandRoomRoute`.
struct ForYouRoute: Identifiable, Equatable {
    let weekId: String
    var id: String { weekId }
}

struct ForYouPresentationModifier: ViewModifier {
    @ObservedObject var appState: AppState
    @ObservedObject var subscriptionStore: SubscriptionStore
    let declarationStore: DeclarationViewModel

    func body(content: Content) -> some View {
        content
            .sheet(item: $appState.pendingForYou) { _ in
                ForYouView(viewModel: declarationStore, source: "push")
                    .environmentObject(subscriptionStore)
            }
    }
}

extension View {
    /// Attach once, at the root, next to `standPresentation`.
    func forYouPresentation(appState: AppState,
                            subscriptionStore: SubscriptionStore,
                            declarationStore: DeclarationViewModel) -> some View {
        modifier(ForYouPresentationModifier(appState: appState,
                                            subscriptionStore: subscriptionStore,
                                            declarationStore: declarationStore))
    }
}
