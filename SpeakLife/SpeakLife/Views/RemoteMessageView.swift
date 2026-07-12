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

    /// Direct construction — used by the Community "Messages" tab, which
    /// reads past broadcasts from Firestore rather than a push payload.
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
    /// Amen. The owner dismisses this reader and surfaces the Community
    /// Messages tab so the user can discover every past broadcast. Left nil
    /// when the reader is opened FROM that Messages tab (they're already
    /// there).
    var onSeeAllMessages: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

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

                        // No .fixedSize here: combined with .lineSpacing it makes
                        // SwiftUI under-measure the text height and clip long
                        // messages. Inside a ScrollView the text is already given
                        // unbounded height, so it renders in full and scrolls.
                        Text(message.body)
                            .font(.system(size: 19, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.92))
                            .lineSpacing(7)
                            .multilineTextAlignment(.leading)
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
}

#Preview {
    RemoteMessageView(
        message: RemoteMessage(
            userInfo: [
                "messageTitle": "A Word For You Today",
                "messageBody": "I see you, and I am proud of how far you've come. The road has not been easy, but every step has been ordered. Keep going. Your breakthrough is closer than it appears, and the One who started a good work in you is faithful to complete it."
            ],
            fallbackTitle: "",
            fallbackBody: ""
        )!
    )
}
