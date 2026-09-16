//
//  EmailCaptureScreen.swift
//  SpeakLife
//
//  The one place the app asks for an email address.
//
//  It sits pre-paywall, immediately after the review wall, in every onboarding
//  arm. Pre-paywall because the address is worth the most from the people who
//  DON'T subscribe: a user who declines the trial and leaves is unreachable
//  forever otherwise, and they are the majority. Asking after the paywall would
//  collect emails only from the users we can already reach.
//
//  Two deliberate choices, both of which protect the conversion rate this
//  screen sits in front of:
//
//  1. **Skippable, and the skip is visible.** A hard gate one screen before a
//     hard paywall stacks two walls in a row. The skip costs some addresses and
//     keeps the trial starts, which is the right way round.
//  2. **It never blocks on the network.** Tapping continue advances instantly;
//     EmailCaptureService sends behind the flow and retries on a later launch
//     if the send fails. No spinner, no error alert, no way for a bad
//     connection to cost a subscription.
//
//  Remote-gated by `emailCaptureEnabled`, the same way the rating ask is: if
//  the ask measurably hurts trial starts, it goes dark without a release.
//

import SwiftUI

struct EmailCaptureScreen: View {
    let size: CGSize
    /// Onboarding arm name for analytics ("product", "warfare", "quiz", ...).
    /// Also stamped on the Klaviyo profile so list segments line up with funnel
    /// segments.
    let flow: String
    /// The area the user picked earlier, for segmented sends. Optional: the
    /// arms that never ask pass nil.
    let burden: String?
    let onContinue: () -> Void

    @State private var email: String = ""
    @State private var showInvalid = false
    @FocusState private var fieldFocused: Bool

    private var trimmed: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSubmit: Bool {
        EmailCaptureService.isValidEmail(trimmed)
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: size.height * 0.12)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    header
                    field
                    reassurance
                }
                .padding(.horizontal, 28)
            }
            // Keep the CTA reachable when the keyboard is up on a small phone.
            .scrollDismissesKeyboard(.interactively)

            Spacer(minLength: DS.Spacing.md)

            VStack(spacing: DS.Spacing.sm) {
                ProductContinueButton(label: "Send it to me →", isEnabled: canSubmit) {
                    submit()
                }

                Button {
                    skip()
                } label: {
                    Text("Not right now")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(DS.Palette.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 32)
        }
        .environment(\.colorScheme, .dark)
        .onAppear {
            AnalyticsService.shared.track("email_capture_shown", parameters: ["flow": flow])
        }
    }

    // MARK: - Pieces

    private var header: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            // Not "one last thing" — the paywall is still ahead, and a promise
            // this screen cannot keep is a bad note to ask on.
            Text("ONE MORE THING")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.3)
                .foregroundColor(DS.Palette.gold.opacity(0.9))

            Text("Where should we send your declarations?")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(DS.Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            // Deliberately says nothing about "your plan": the identity and quiz
            // arms have no plan reveal, and this one screen runs in all six.
            Text("A word to speak over your life each morning. Straight to your inbox, free.")
                .font(DS.Typography.body)
                .foregroundColor(DS.Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
        .dsAppear(0)
    }

    private var field: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            TextField("", text: $email, prompt: Text("you@email.com")
                .foregroundColor(DS.Palette.textSecondary.opacity(0.6)))
                .textInputAutocapitalization(.never)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()
                .submitLabel(.go)
                .focused($fieldFocused)
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundColor(DS.Palette.textPrimary)
                .padding(DS.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                        .fill(DS.Palette.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                                .stroke(showInvalid ? Color.red.opacity(0.7) : DS.Palette.hairline,
                                        lineWidth: 1)
                        )
                )
                .onSubmit { if canSubmit { submit() } }
                // Clear the error the moment they start fixing it, rather than
                // leaving a red box up while they type a valid address.
                .onChange(of: email) { _, _ in if showInvalid { showInvalid = false } }

            if showInvalid {
                Text("That address doesn't look right. Mind checking it?")
                    .font(.system(size: 13))
                    .foregroundColor(.red.opacity(0.9))
            }
        }
        .dsAppear(0.08)
    }

    private var reassurance: some View {
        HStack(alignment: .top, spacing: DS.Spacing.xs) {
            Image(systemName: "lock.fill")
                .font(.system(size: 11))
                .foregroundColor(DS.Palette.textSecondary.opacity(0.8))
                .padding(.top, 2)
            // Says what they are agreeing to, plainly. This is the consent the
            // address is subscribed under, so it is a promise, not decoration:
            // no selling, and one tap to stop.
            Text("We'll never sell or share your email. Unsubscribe any time in one tap.")
                .font(.system(size: 12))
                .foregroundColor(DS.Palette.textSecondary.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
        .dsAppear(0.16)
    }

    // MARK: - Actions

    private func submit() {
        guard canSubmit else {
            showInvalid = true
            return
        }
        fieldFocused = false
        Juice.play(.tapLight)

        EmailCaptureService.shared.submit(
            email: trimmed,
            source: "onboarding",
            variant: flow,
            burden: burden
        )
        AnalyticsService.shared.track("email_capture_submitted", parameters: ["flow": flow])

        // Advance on the same tap. The send is already running behind us.
        onContinue()
    }

    private func skip() {
        fieldFocused = false
        AnalyticsService.shared.track("email_capture_skipped", parameters: ["flow": flow])
        onContinue()
    }
}

// MARK: - Flow gate

extension SubscriptionStore {
    /// Whether onboarding should jump over the email step.
    ///
    /// Every arm asks the same two questions here, so they ask them in one
    /// place: is the ask switched on, and do we already have an address? The
    /// second matters more than it looks — a debug replay, a reinstall restored
    /// from backup, or any future re-run of onboarding must not ask a user
    /// again for something they already gave us.
    ///
    /// The step stays in each flow's step list either way and is skipped in
    /// `advance()`, exactly as the rating ask is, so the analytics step indices
    /// never shift under a remote flag.
    var shouldSkipEmailCapture: Bool {
        !emailCaptureEnabled || EmailCaptureService.shared.hasCapturedEmail
    }
}

// MARK: - Preview

struct EmailCaptureScreen_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            EmailCaptureScreen(
                size: UIScreen.main.bounds.size,
                flow: "preview",
                burden: nil,
                onContinue: {}
            )
        }
    }
}
