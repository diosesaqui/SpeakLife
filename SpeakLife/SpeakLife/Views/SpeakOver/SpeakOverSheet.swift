//
//  SpeakOverSheet.swift
//  SpeakLife
//
//  The sending half of "Speak it over someone". Opened from "Send to someone"
//  in the declaration share menu, and from "Send one back" on a received gift.
//
//  One screen, one action: the card they will get, two first names, Send. The
//  sender's name is remembered, because the second send should be one tap.
//

import SwiftUI
import UIKit

struct SpeakOverSheet: View {

    /// Where the send started. Decides which event it reports.
    enum Origin: String {
        case feed
        case sentBack = "sent_back"
    }

    let declaration: Declaration
    let background: UIImage?
    let origin: Origin

    @Environment(\.dismiss) private var dismiss
    @AppStorage("speakOverSenderName") private var senderName = ""
    @State private var recipientName: String
    @State private var card: UIImage?
    @State private var share: ShareItems?
    @FocusState private var focusedField: Field?

    private enum Field { case sender, recipient }

    /// Boxed so `.sheet(item:)` can present it.
    private struct ShareItems: Identifiable {
        let id = UUID()
        let items: [Any]
    }

    private static let gold = Color(red: 0.945, green: 0.824, blue: 0.604)   // card gold
    private static let navy = Color(hex: "#1A264D")

    init(declaration: Declaration, background: UIImage?,
         recipientName: String? = nil, origin: Origin = .feed) {
        self.declaration = declaration
        self.background = background
        self.origin = origin
        _recipientName = State(initialValue: recipientName ?? "")
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Self.navy, Color(hex: "#0F1730")],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: DS.Spacing.lg) {
                    header
                        .padding(.top, DS.Spacing.xl)
                    cardPreview
                    fields
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.lg)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .safeAreaInset(edge: .bottom) { sendButton }
        .environment(\.colorScheme, .dark)
        .presentationDragIndicator(.visible)
        .onAppear {
            AnalyticsService.shared.track("speak_over_sheet_opened", parameters: [
                "origin": origin.rawValue
            ])
            renderCardSoon()
        }
        .sheet(item: $share) { share in
            SpeakOverActivityView(items: share.items) { activityType, completed in
                handleShareFinished(activityType: activityType, completed: completed)
            }
            .presentationDetents([.medium, .large])
            .ignoresSafeArea()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: DS.Spacing.xs) {
            Text("SPEAK IT OVER SOMEONE")
                .font(.system(size: 11, weight: .bold))
                .tracking(2.6)
                .foregroundColor(Self.gold)
            Text(SpeakOverCopy.sendTitle)
                .font(.system(size: 24, weight: .semibold, design: .serif))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text("They get this card and a link that opens it in SpeakLife.")
                .font(DS.Typography.callout)
                .foregroundColor(DS.Palette.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Card

    private var cardPreview: some View {
        ZStack {
            if let card {
                Image(uiImage: card)
                    .resizable()
                    .scaledToFit()
                    .transition(.opacity)
            } else {
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                ProgressView()
                    .tint(.white.opacity(0.6))
            }
        }
        // The card is 9:16; 320 tall keeps the fields above the keyboard.
        .frame(width: 180, height: 320)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .stroke(DS.Palette.hairline, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.35), radius: 18, y: 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(declaration.text)
    }

    /// Rendered a beat after the sheet appears: a 1080x1920 render on the
    /// first frame stutters the sheet's slide-up.
    @MainActor
    private func renderCardSoon() {
        guard card == nil else { return }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            let rendered = DeclarationStoryCard.render(declaration: declaration, background: background)
            withAnimation(DS.Motion.smooth) { card = rendered }
        }
    }

    // MARK: - Names

    private var fields: some View {
        VStack(spacing: DS.Spacing.sm) {
            nameField(title: "Your first name", placeholder: "So they know it's you",
                      text: $senderName, field: .sender)
            nameField(title: "Their first name", placeholder: "Optional",
                      text: $recipientName, field: .recipient)
        }
    }

    private func nameField(title: String, placeholder: String,
                           text: Binding<String>, field: Field) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(DS.Palette.textSecondary)
            TextField("", text: text, prompt: Text(placeholder).foregroundColor(.white.opacity(0.35)))
                .font(DS.Typography.body)
                .foregroundColor(.white)
                .textContentType(field == .sender ? UITextContentType.givenName : nil)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(field == .sender ? .next : .done)
                .focused($focusedField, equals: field)
                .onSubmit {
                    focusedField = field == .sender ? .recipient : nil
                }
                // Capped as they type, so what they see is what is sent.
                .onChange(of: text.wrappedValue) { _, newValue in
                    if newValue.count > SpeakOverLink.maxNameLength {
                        text.wrappedValue = String(newValue.prefix(SpeakOverLink.maxNameLength))
                    }
                }
                .padding(.horizontal, DS.Spacing.md)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                        .fill(DS.Palette.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                        .stroke(focusedField == field ? Self.gold.opacity(0.7) : DS.Palette.hairline,
                                lineWidth: 1)
                )
        }
    }

    // MARK: - Send

    private var sendButton: some View {
        Button {
            send()
        } label: {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 15, weight: .bold))
                Text("Send it")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
            }
            .foregroundColor(Self.navy)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Capsule().fill(DS.Gradient.gold))
            .shadow(color: DS.Palette.gold.opacity(0.35), radius: 14, y: 6)
        }
        .buttonStyle(.dsPressable(feel: .tapSolid))
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.top, DS.Spacing.sm)
        .padding(.bottom, DS.Spacing.xs)
        .background(
            LinearGradient(colors: [Color(hex: "#0F1730").opacity(0), Color(hex: "#0F1730")],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
    }

    private var cleanSender: String? { SpeakOverLink.clean(senderName, limit: SpeakOverLink.maxNameLength) }
    private var cleanRecipient: String? { SpeakOverLink.clean(recipientName, limit: SpeakOverLink.maxNameLength) }

    @MainActor
    private func send() {
        focusedField = nil
        // Saved cleaned, so the remembered name is the one that was sent.
        senderName = cleanSender ?? ""

        let link = SpeakOverLink.url(
            text: declaration.text,
            book: declaration.book,
            from: cleanSender,
            to: cleanRecipient,
            campaign: origin == .sentBack ? Origin.sentBack.rawValue : declaration.category.rawValue
        )
        // The link only rides along to messaging apps (ReferralShareText),
        // which is where this send belongs.
        let text = ReferralShareText(SpeakOverCopy.shareText(to: cleanRecipient), link: link)
        var items: [Any] = []
        // No card (the render failed) still sends the words and the link.
        if let card { items.append(card) }
        items.append(text)
        share = ShareItems(items: items)
    }

    @MainActor
    private func handleShareFinished(activityType: UIActivity.ActivityType?, completed: Bool) {
        share = nil
        guard completed else { return }

        AnalyticsService.shared.track(
            origin == .sentBack ? "speak_over_sent_back" : "speak_over_sent",
            parameters: [
                "method": activityType?.rawValue ?? "unknown",
                "category": declaration.category.rawValue,
                "has_sender_name": cleanSender != nil,
                "has_recipient_name": cleanRecipient != nil,
                "is_jesus_voice": declaration.book?.caseInsensitiveCompare("Jesus") == .orderedSame
            ]
        )
        Juice.play(.success)
        // Let the share sheet finish sliding away before this one follows.
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 450_000_000)
            dismiss()
        }
    }
}

// MARK: - Share sheet

/// `UIActivityViewController` with its completion surfaced, so a send is only
/// counted when one actually happened. The app's `ShareSheet` has no callback.
struct SpeakOverActivityView: UIViewControllerRepresentable {
    let items: [Any]
    let onFinish: (UIActivity.ActivityType?, Bool) -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = { activityType, completed, _, _ in
            DispatchQueue.main.async {
                onFinish(activityType, completed)
            }
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview("Send") {
    Color.black
        .sheet(isPresented: .constant(true)) {
            SpeakOverSheet(
                declaration: Declaration(
                    text: "By His wounds I am healed, and strength rises in this body every morning.",
                    book: "Isaiah 53:5",
                    bibleVerseText: "But he was pierced for our transgressions... and by his wounds we are healed.",
                    category: .health
                ),
                background: nil
            )
        }
}

#Preview("Send back, Jesus voice") {
    Color.black
        .sheet(isPresented: .constant(true)) {
            SpeakOverSheet(
                declaration: Declaration(
                    text: "I took your sickness to the cross, and your body is healed.",
                    book: "Jesus"
                ),
                background: nil,
                recipientName: "Maria",
                origin: .sentBack
            )
        }
}
