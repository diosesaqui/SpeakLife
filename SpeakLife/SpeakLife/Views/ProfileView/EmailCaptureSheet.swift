//
//  EmailCaptureSheet.swift
//  SpeakLife
//
//  The email ask everywhere OUTSIDE onboarding: the Profile row, and once
//  after a purchase. Onboarding has its own full-screen step
//  (`EmailCaptureScreen`) built to sit inside a paged flow; this is the sheet
//  version, and both post to the same `EmailCaptureService`.
//
//  It replaces `EmailCaptureView`, removed with the rest of the subsystem in
//  commit c605131f. The copy and the `source` strings are carried over
//  deliberately — "ios_app_profile", "settings" and "post_purchase" are what
//  the existing Klaviyo profiles are already segmented by, and inventing new
//  ones would split a year of segments in half.
//
//  What is NOT carried over is the old view's spinner-and-wait: it disabled the
//  button, showed a ProgressView, and waited on Klaviyo before telling the user
//  anything. The service now queues to disk and retries, so the confirmation is
//  immediate and honest — the address IS saved at that point, whatever the
//  network does next.
//

import SwiftUI

struct EmailCaptureSheet: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @Environment(\.dismiss) private var dismiss

    /// Where the ask happened. Kept as the legacy vocabulary.
    var source: String = "ios_app_profile"

    @State private var email: String = ""
    @State private var showInvalid = false
    @State private var didSubmit = false
    @FocusState private var fieldFocused: Bool

    /// Tag a subscriber's capture as `post_purchase` regardless of where they
    /// tapped it, exactly as the old view did. A paying user who joins from the
    /// Profile row is still a post-purchase subscriber for segmentation.
    private var resolvedSource: String {
        subscriptionStore.isPremium ? "post_purchase" : source
    }

    private var trimmed: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSubmit: Bool { EmailCaptureService.isValidEmail(trimmed) }

    private var isUpdating: Bool { !appState.email.isEmpty }

    var body: some View {
        NavigationStack {
            Group {
                if didSubmit { confirmation } else { form }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            // Prefill so "Update Email" is an edit, not a retype.
            email = appState.email
            AnalyticsService.shared.track("email_capture_shown", parameters: [
                "flow": resolvedSource
            ])
        }
        .onDisappear {
            // Spend the one post-purchase ask whether or not they submitted,
            // mirroring the removed view. Without this it would return on every
            // launch for anyone who dismissed it once.
            if resolvedSource == "post_purchase" {
                EmailCaptureService.shared.markPostPurchaseAskShown()
            }
        }
    }

    // MARK: - Form

    private var form: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text(isUpdating ? "Update your email" : "Join Our Weekly Emails")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, DS.Spacing.lg)

            Text("Weekly encouragement, Scripture insights, and a word to speak over your life. Free.")
                .font(.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            TextField("you@email.com", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.go)
                .focused($fieldFocused)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                                .stroke(showInvalid ? Color.red.opacity(0.7) : Color.clear,
                                        lineWidth: 1)
                        )
                )
                .onSubmit { submit() }
                .onChange(of: email) { _, _ in if showInvalid { showInvalid = false } }

            if showInvalid {
                Text("That address doesn't look right. Mind checking it?")
                    .font(.footnote)
                    .foregroundColor(.red)
            }

            Button(action: submit) {
                Text(isUpdating ? "Save" : "Subscribe")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        Capsule().fill(canSubmit ? Color.accentColor : Color.gray.opacity(0.35))
                    )
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            .disabled(!canSubmit)

            // The consent line the address is subscribed under. It is a
            // promise, not decoration.
            Label("We'll never sell or share your email. Unsubscribe any time in one tap.",
                  systemImage: "lock.fill")
                .font(.caption)
                .foregroundColor(.secondary)
                .labelStyle(.titleAndIcon)

            Spacer()
        }
    }

    // MARK: - Confirmation

    private var confirmation: some View {
        VStack(spacing: DS.Spacing.md) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 52))
                .foregroundColor(.green)
            Text("You're in.")
                .font(.system(size: 24, weight: .bold, design: .rounded))
            Text(appState.email)
                .font(.footnote)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .transition(.opacity)
    }

    // MARK: - Actions

    private func submit() {
        guard canSubmit else {
            showInvalid = true
            return
        }
        fieldFocused = false
        Juice.play(.tapLight)

        EmailCaptureService.shared.submit(email: trimmed, source: resolvedSource)
        // The service writes the address to the same UserDefaults key
        // `appState.email` is bound to, so the row behind this sheet updates
        // itself. Set it here too so the confirmation below has it immediately
        // rather than a frame later.
        appState.email = trimmed.lowercased()

        AnalyticsService.shared.track("email_capture_submitted", parameters: [
            "flow": resolvedSource
        ])

        withAnimation(DS.Motion.smooth) { didSubmit = true }
        // Long enough to read the confirmation, short enough not to trap them.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { dismiss() }
    }
}

// MARK: - Preview

struct EmailCaptureSheet_Previews: PreviewProvider {
    static var previews: some View {
        EmailCaptureSheet(source: "settings")
            .environmentObject(AppState())
            .environmentObject(SubscriptionStore())
    }
}
