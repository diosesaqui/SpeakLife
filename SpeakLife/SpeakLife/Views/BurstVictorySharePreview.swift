//
//  BurstVictorySharePreview.swift
//  SpeakLife
//
//  The step between finishing a burst and posting about it.
//
//  A burst is seven lines, and only one of them can be the poster. Picking that
//  one for the user is a coin flip: the line that wrecked them is not
//  necessarily the first one, and it is not the one an algorithm would choose.
//  So the sheet shows the card they are about to send, and lets them swipe
//  through the lines they actually spoke until they find the one they want
//  their friends to read.
//
//  Seeing the card before it goes out matters for a second reason. A share
//  sheet that fires straight into the system tray asks someone to post
//  something sight-unseen, and most people back out. Showing the artifact first
//  is what turns "share" from a button into a decision they already made.
//

import SwiftUI
import UIKit

/// A composed set of cards, ready to present.
///
/// Identifiable so the sheet can be driven by `.sheet(item:)` rather than a
/// boolean beside an array: there is then no state in which the sheet is open
/// and the cards are missing.
struct BurstShareDeck: Identifiable {
    let id = UUID()
    let cards: [BurstShareCard]

    /// Nil when there is nothing worth showing, which the caller reads as
    /// "do not open the sheet".
    init?(cards: [BurstShareCard]) {
        guard !cards.isEmpty else { return nil }
        self.cards = cards
    }
}

struct BurstVictorySharePreview: View {

    /// One card per line spoken. Never empty — the caller composes a single
    /// streak-only card when a burst somehow produced no lines.
    let cards: [BurstShareCard]

    @Environment(\.dismiss) private var dismiss

    @State private var selection = 0
    @State private var shareItem: BurstShareItem?
    @State private var savedConfirmation = false
    /// Rendered cards, keyed by card. Saving and then sharing the same card is
    /// a common pair, and rasterising 1080x1920 twice for it is a hitch on the
    /// main thread for nothing.
    @State private var renderCache: [UUID: UIImage] = [:]

    /// Static because `UIImageWriteToSavedPhotosAlbum` does not retain its
    /// target: an `ImageSaver` held by this struct can be gone by the time the
    /// system calls back, and the save fails silently or worse. One long-lived
    /// instance sidesteps the whole question.
    private static let imageSaver = ImageSaver()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "0A0716"), Color(hex: "17102E"), Color(hex: "0A0716")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                carousel

                if cards.count > 1 {
                    pageDots
                        .padding(.top, DS.Spacing.md)
                }

                Spacer(minLength: DS.Spacing.md)

                actions
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.bottom, DS.Spacing.lg)
            }

            if savedConfirmation {
                savedToast
            }
        }
        .preferredColorScheme(.dark)
        .sheet(item: $shareItem) { item in
            ShareSheet(activityItems: item.activityItems)
        }
        .onAppear {
            AnalyticsService.shared.track("burst_share_preview_shown", parameters: [
                "card_count": cards.count
            ])
        }
    }

    // MARK: Header

    private var header: some View {
        ZStack {
            VStack(spacing: 4) {
                Text("Share Your Victory")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                Text(cards.count > 1 ? "Swipe to pick the line you want to post" : "Ready to post")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.55))
            }

            HStack {
                Spacer()
                Button {
                    Juice.play(.tapLight)
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Color.white.opacity(0.10)))
                }
            }
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.top, DS.Spacing.lg)
        .padding(.bottom, DS.Spacing.md)
    }

    // MARK: Carousel

    /// The cards are laid out at their true 1080x1920 and scaled down to fit,
    /// so what is on screen is the rendered file rather than a re-implementation
    /// of it. There is no second layout to keep in step.
    private var carousel: some View {
        GeometryReader { geo in
            let scale = min(
                geo.size.width * 0.86 / BurstVictoryShareCard.size.width,
                geo.size.height / BurstVictoryShareCard.size.height
            )

            TabView(selection: $selection) {
                ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                    BurstVictoryShareCard(card: card)
                        .scaleEffect(scale)
                        .frame(
                            width: BurstVictoryShareCard.size.width * scale,
                            height: BurstVictoryShareCard.size.height * scale
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .shadow(color: .black.opacity(0.55), radius: 24, x: 0, y: 12)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
    }

    private var pageDots: some View {
        HStack(spacing: 7) {
            ForEach(cards.indices, id: \.self) { index in
                Capsule()
                    .fill(index == selection ? DS.Palette.gold : Color.white.opacity(0.25))
                    .frame(width: index == selection ? 20 : 7, height: 7)
                    .animation(DS.Motion.quick, value: selection)
            }
        }
    }

    // MARK: Actions

    private var actions: some View {
        VStack(spacing: DS.Spacing.sm) {
            Button(action: share) {
                HStack(spacing: 10) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 17, weight: .bold))
                    Text("Share")
                        .font(.system(size: 17, weight: .bold))
                }
                .foregroundColor(Color(hex: "1A1030"))
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Capsule().fill(DS.Gradient.gold))
                .shadow(color: DS.Palette.gold.opacity(0.35), radius: 14, x: 0, y: 6)
            }
            .buttonStyle(.dsPressable(feel: .tapSolid, haptics: false))

            Button(action: saveToPhotos) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.to.line")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Save to Photos")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.white.opacity(0.8))
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(Capsule().stroke(Color.white.opacity(0.22), lineWidth: 1))
            }
            .buttonStyle(.dsPressable(feel: .tapLight, haptics: false))
        }
    }

    private var savedToast: some View {
        VStack {
            Spacer()
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(DS.Palette.gold)
                Text("Saved to Photos")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(Capsule().fill(Color.black.opacity(0.85)))
            .padding(.bottom, 140)
        }
        .transition(.opacity)
        .allowsHitTesting(false)
    }

    // MARK: Behaviour

    private var currentCard: BurstShareCard? {
        cards.indices.contains(selection) ? cards[selection] : cards.first
    }

    @MainActor
    private func share() {
        guard let card = currentCard else { return }
        Juice.play(.tapSolid)

        // A failed render is not worth a dialog: send the words on their own
        // rather than leaving the button dead.
        shareItem = BurstShareItem(image: renderedImage(for: card), text: card.shareText)

        AnalyticsService.shared.track("burst_share_card_shared", parameters: [
            "streak": card.streak,
            "declarations": card.declarationsSpoken,
            "card_index": selection
        ])
    }

    @MainActor
    private func saveToPhotos() {
        guard let card = currentCard, let image = renderedImage(for: card) else { return }
        Juice.play(.tapLight)

        Self.imageSaver.writeToPhotoAlbum(image: image)

        withAnimation(DS.Motion.smooth) { savedConfirmation = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(DS.Motion.smooth) { savedConfirmation = false }
        }

        AnalyticsService.shared.track("burst_share_card_saved", parameters: [
            "streak": card.streak,
            "card_index": selection
        ])
    }

    @MainActor
    private func renderedImage(for card: BurstShareCard) -> UIImage? {
        if let cached = renderCache[card.id] { return cached }
        guard let image = BurstShareCardRenderer.image(for: card) else { return nil }
        renderCache[card.id] = image
        return image
    }
}

// MARK: - Share payload

/// Carries the rendered image and its caption to the system tray. `image` is
/// optional so a rendering failure still shares the words.
struct BurstShareItem: Identifiable {
    let id = UUID()
    let image: UIImage?
    let text: String

    var activityItems: [Any] {
        if let image { return [image, text] }
        return [text]
    }
}
