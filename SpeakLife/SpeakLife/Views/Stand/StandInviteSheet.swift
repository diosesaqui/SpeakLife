//
//  StandInviteSheet.swift
//  SpeakLife
//
//  The send. Spec §9 and §9.5.
//
//  Two things here are conversion, not decoration:
//
//   1. It shares an IMAGE, not a bare URL. A rendered card lands in a text
//      thread far harder than a link does, and `StreakShareCardRenderer` proves
//      the app can already draw one.
//   2. The human code rides in the message body underneath. Branch's deferred
//      matching is probabilistic, not guaranteed, so somebody who installs from
//      the App Store and does not get matched can still type eight characters.
//
//  It also says plainly, before the link exists, that everyone invited will see
//  the theme being stood for. A campaign theme can be a private thing.
//

import SwiftUI
import SpeakLifeCore

struct StandInviteSheet: View {

    let room: StandRoom

    @State private var code: String?
    @State private var shareImage: UIImage?
    @State private var isWorking = true
    @State private var errorText: String?
    @Environment(\.dismiss) private var dismiss

    private var link: String {
        "https://speaklife.app.link/stand/\(code ?? "")"
    }

    /// The message body. The link and the typed code both appear, because the
    /// two install paths need different things.
    private var shareText: String {
        """
        I'm speaking God's word over \(room.enforcement.theme.name.lowercased()) for 7 days. Stand with me.

        \(link)

        (or open SpeakLife and enter code \(formattedCode))
        """
    }

    private var formattedCode: String {
        guard let code, code.count == 8 else { return code ?? "" }
        let mid = code.index(code.startIndex, offsetBy: 4)
        return "\(code[code.startIndex..<mid])-\(code[mid...])"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Gradients().speakLifeCYOCell.ignoresSafeArea()
                VStack(spacing: DS.Spacing.lg) {
                    if isWorking {
                        ProgressView().tint(.white)
                    } else if let errorText {
                        failure(errorText)
                    } else {
                        ready
                    }
                }
                .padding(DS.Spacing.md)
            }
            .navigationTitle("Stand with me")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundColor(DS.Palette.gold)
                }
            }
        }
        .task { await prepare() }
    }

    // MARK: - States

    private var ready: some View {
        VStack(spacing: DS.Spacing.lg) {
            if let shareImage {
                Image(uiImage: shareImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 320)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
                    .shadow(color: DS.Elevation.medium.color,
                            radius: DS.Elevation.medium.radius,
                            x: DS.Elevation.medium.x, y: DS.Elevation.medium.y)
            }

            // Said before the link is sent, not after. The theme is visible to
            // everyone invited, and that can be a private thing.
            Text("Everyone you invite will see you're standing for \(room.enforcement.theme.name.lowercased()).")
                .font(DS.Typography.caption)
                .foregroundColor(DS.Palette.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            ShareLink(item: shareText,
                      preview: SharePreview("Stand with me", image: previewImage)) {
                Label("Send the invite", systemImage: "square.and.arrow.up")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(Capsule().fill(DS.Palette.gold))
            }
            .simultaneousGesture(TapGesture().onEnded {
                AnalyticsService.shared.track("stand_invite_shared", parameters: [
                    "room_id": room.id, "channel": "share_sheet",
                ])
            })

            codeRow
        }
    }

    private var codeRow: some View {
        VStack(spacing: DS.Spacing.xs) {
            Text("OR GIVE THEM THIS CODE")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.2)
                .foregroundColor(DS.Palette.textSecondary)

            Button {
                UIPasteboard.general.string = formattedCode
                PremiumHaptics.success()
            } label: {
                Text(formattedCode)
                    .font(.system(size: 26, weight: .bold, design: .monospaced))
                    .tracking(2)
                    .foregroundColor(DS.Palette.textPrimary)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(RoundedRectangle(cornerRadius: DS.Radius.md,
                                                 style: .continuous)
                        .fill(DS.Palette.surface))
            }
            .accessibilityLabel("Invite code \(formattedCode). Tap to copy.")

            Text("Expires in 14 days.")
                .font(.system(size: 11))
                .foregroundColor(DS.Palette.textSecondary.opacity(0.7))
        }
    }

    private func failure(_ message: String) -> some View {
        VStack(spacing: DS.Spacing.sm) {
            Text(message)
                .font(DS.Typography.body)
                .foregroundColor(DS.Palette.textPrimary)
                .multilineTextAlignment(.center)
            Button("Try again") {
                Task { await prepare() }
            }
            .foregroundColor(DS.Palette.gold)
        }
    }

    private var previewImage: Image {
        shareImage.map { Image(uiImage: $0) } ?? Image(systemName: "hands.and.sparkles")
    }

    // MARK: - Work

    private func prepare() async {
        isWorking = true
        errorText = nil
        do {
            // A fresh code per send, so revoking one does not kill the others.
            // The owner is capped at five live invites server-side.
            let fresh = try await StandService.shared.createInvite(roomId: room.id)
            code = fresh
            shareImage = StandInviteCardRenderer.render(
                theme: room.enforcement.theme.name,
                title: room.enforcement.displayTitle,
                code: formattedCode
            )
        } catch {
            errorText = (error as? StandError)?.errorDescription
                ?? error.localizedDescription
        }
        isWorking = false
    }
}
