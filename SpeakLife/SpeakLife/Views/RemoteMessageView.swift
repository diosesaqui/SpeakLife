//
//  RemoteMessageView.swift
//  SpeakLife
//
//  A standalone screen for displaying a personalized message that was delivered
//  via a remote (Firebase) push notification. Unlike declaration notifications
//  — which open the home feed — these messages can be longer than a banner can
//  show, so tapping the notification pops this screen with the full text.
//

import SwiftUI

/// Lightweight payload for an in-app message delivered through a push notification.
///
/// Built from the FCM `userInfo` dictionary when `deepLink == "message"`. The
/// banner shows a short title/body; the full (potentially long) message is carried
/// in the optional `messageTitle` / `messageBody` data keys and falls back to the
/// banner's own title/body when those keys are absent.
struct RemoteMessage: Identifiable {
    let id = UUID()
    let title: String
    let body: String

    /// Direct construction — used by the Inbox tab, which reads past
    /// broadcasts from Firestore rather than a push payload.
    init(title: String, body: String) {
        self.title = title
        self.body = body
    }

    /// Builds a message from a notification's `userInfo`.
    ///
    /// - Returns: `nil` when there is no displayable body text, so callers can
    ///   safely skip presentation rather than show an empty screen.
    init?(userInfo: [AnyHashable: Any], fallbackTitle: String, fallbackBody: String) {
        let explicitTitle = (userInfo["messageTitle"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let explicitBody = (userInfo["messageBody"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let resolvedBody = (explicitBody?.isEmpty == false)
            ? explicitBody!
            : fallbackBody.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !resolvedBody.isEmpty else { return nil }

        let resolvedTitle = (explicitTitle?.isEmpty == false)
            ? explicitTitle!
            : fallbackTitle.trimmingCharacters(in: .whitespacesAndNewlines)

        self.title = resolvedTitle
        self.body = resolvedBody
    }
}

/// Full-screen reader for a `RemoteMessage`. Presented as a sheet so it floats
/// above whatever tab the user was on without disturbing the home feed.
struct RemoteMessageView: View {

    let message: RemoteMessage

    /// When set, a secondary "See All SpeakLife Messages" CTA appears under
    /// Amen. The owner dismisses this reader and surfaces the Inbox so the
    /// user can discover every past broadcast. Left nil when the reader is
    /// opened FROM the Inbox (they're already there).
    var onSeeAllMessages: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    /// Paragraphs, recovered from a body that often arrives as one flat run
    /// (see MessageBodyFormatter). Computed once per message rather than per
    /// layout pass, since the sentence scan is not free and the text never
    /// changes while the sheet is open.
    private let blocks: [MessageBodyFormatter.Block]

    init(message: RemoteMessage, onSeeAllMessages: (() -> Void)? = nil) {
        self.message = message
        self.onSeeAllMessages = onSeeAllMessages
        self.blocks = MessageBodyFormatter.blocks(from: message.body)
    }

    var body: some View {
        ZStack {
            Gradients().speakLifeFrostyCell
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Close affordance in the top-right.
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .accessibilityLabel("Close")
                    .buttonStyle(.dsPressable(feel: .tapSolid))
                }
                .padding(.horizontal, 20)
                .padding(.top, DS.Spacing.md)

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if !message.title.isEmpty {
                            Text(message.title)
                                .font(DS.Typography.title)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.leading)
                        }

                        // One Text per paragraph, so the spacing between them is
                        // real layout rather than a blank line the sender had to
                        // remember to type. No .fixedSize on any of them:
                        // combined with .lineSpacing it makes SwiftUI
                        // under-measure the text height and clip long messages.
                        // Inside a ScrollView the text already has unbounded
                        // height, so it renders in full and scrolls.
                        VStack(alignment: .leading, spacing: 18) {
                            ForEach(blocks) { block in
                                switch block.kind {
                                case .prose:
                                    paragraph(block.text)
                                case .scripture:
                                    scripture(block.text)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 28)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
                .dsAppear(0.06)

                VStack(spacing: 12) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Amen")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(Color(hex: "#0B0F1A"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(DS.Gradient.gold)
                            )
                    }
                    .buttonStyle(.dsPressable(feel: .tapSolid))

                    if let onSeeAllMessages {
                        Button {
                            onSeeAllMessages()
                        } label: {
                            Text("See All SpeakLife Messages")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.92))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color.white.opacity(0.10))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(Color.white.opacity(0.22), lineWidth: 1)
                                        )
                                )
                        }
                        .buttonStyle(.dsPressable(feel: .tapLight))
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 28)
                .dsAppear(0.12)
            }
        }
    }

    // MARK: - Paragraph styles

    private func paragraph(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 19, weight: .regular, design: .rounded))
            .foregroundColor(.white.opacity(0.92))
            .lineSpacing(7)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// A quoted verse, set apart from the copy around it by a gold rule so the
    /// eye can find the scripture in a long message at a glance.
    private func scripture(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Capsule()
                .fill(DS.Palette.gold.opacity(0.75))
                .frame(width: 3)

            Text(text)
                .font(.system(size: 18, weight: .regular, design: .rounded))
                .italic()
                .foregroundColor(.white.opacity(0.88))
                .lineSpacing(6)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        // No .fixedSize: the rule is a flexible shape, so the row already
        // takes its height from the text beside it, and forcing an ideal
        // height back onto text with .lineSpacing is what clipped long
        // messages before.
    }
}

// A body sent as one flat run — the shape most broadcasts actually arrive in.
// It should read as paragraphs here, with the two verses set apart.
#Preview {
    RemoteMessageView(
        message: RemoteMessage(
            userInfo: [
                "messageTitle": "THIS IS THE DAY ☀️",
                "messageBody": "\"This is the day that the Lord has made; let us rejoice and be glad in it.\" (Ps 118:24) Not tomorrow. Not the one you're still replaying. This one. Yesterday is finished business. Whether it was a win or a wound, it's out of your reach now. And tomorrow isn't yours yet. Today is the only ground you actually stand on, and God already made it. That's why His mercies are \"new every morning.\" (Lam 3:23) Fresh mercy for fresh ground. You don't have to drag yesterday's failure into a day God just built for you. So take this one. Move from hope, not from dread. Move from peace, not from pressure. One day is all any of us gets at a time. This is yours. Make it count. ☀️"
            ],
            fallbackTitle: "",
            fallbackBody: ""
        )!
    )
}
