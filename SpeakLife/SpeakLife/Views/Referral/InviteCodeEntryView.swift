//
//  InviteCodeEntryView.swift
//  SpeakLife
//
//  "Have an invite code?" Spec §5 J5; tests FE-CAP-06, FE-CAP-07.
//
//  Branch matches a deferred install probabilistically, so some friends will
//  arrive with no link attached. They still have the code printed on the card
//  they were sent, and this is where they type it.
//
//  Validation, capture and the claim all live in `ReferralClaimCoordinator`.
//  This view only shows what it answered.
//

import SwiftUI
import SpeakLifeCore

struct InviteCodeEntryView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var isSubmitting = false
    @State private var result: InviteCodeEntryResult?
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                Gradients().speakLifeCYOCell.ignoresSafeArea()
                VStack(spacing: DS.Spacing.lg) {
                    Text("Enter the code your friend sent you.")
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundColor(DS.Palette.textPrimary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)

                    TextField("K7MQ-2XPA", text: $text)
                        .font(.system(.title2, design: .monospaced).weight(.bold))
                        .multilineTextAlignment(.center)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .focused($focused)
                        .padding(DS.Spacing.sm)
                        .background(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                            .fill(DS.Palette.surface))
                        .foregroundColor(DS.Palette.textPrimary)
                        .accessibilityLabel("Invite code")
                        .onChange(of: text) { _, _ in
                            // Editing clears an inline error so the button is
                            // never left looking broken (FE-CAP-07).
                            if result == .invalid { result = nil }
                        }

                    if let result {
                        resultText(result)
                    }

                    Button {
                        submit()
                    } label: {
                        HStack(spacing: DS.Spacing.xs) {
                            if isSubmitting { ProgressView().tint(.black) }
                            Text(isFinished ? "Done" : "Submit")
                        }
                        .font(.system(.headline, design: .rounded))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Capsule().fill(DS.Palette.gold))
                    }
                    .disabled(isSubmitting || text.trimmingCharacters(in: .whitespaces).isEmpty)

                    Spacer()
                }
                .padding(DS.Spacing.lg)
            }
            .navigationTitle("Have an invite code?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }.foregroundColor(DS.Palette.gold)
                }
            }
            .onAppear { focused = true }
        }
    }

    private var isFinished: Bool {
        switch result {
        case .submitted, .alreadyUsed: return true
        case .invalid, .notFound, .none: return false
        }
    }

    private func submit() {
        if isFinished {
            dismiss()
            return
        }
        isSubmitting = true
        Task { @MainActor in
            result = await ReferralClaimCoordinator.shared.submitTypedCode(text)
            isSubmitting = false
        }
    }

    /// Never an error about the server's verdict: whatever it decided, the
    /// friend has done their part (FE-CLM-08).
    @ViewBuilder
    private func resultText(_ result: InviteCodeEntryResult) -> some View {
        switch result {
        case .invalid:
            line("That code doesn't look right. It's 8 letters and numbers.", color: DS.Palette.gold)
        case .submitted(let outcome):
            if outcome == .transportError {
                line("Saved. We'll send it as soon as you're back online.", color: DS.Palette.textSecondary)
            } else {
                line("Thank you. You're all set.", color: DS.Palette.textSecondary)
            }
        case .alreadyUsed:
            line("This phone has already joined through an invite.", color: DS.Palette.textSecondary)
        case .notFound:
            line("We couldn't find that code. Check it with your friend and try again.", color: DS.Palette.gold)
        }
    }

    private func line(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.callout)
            .foregroundColor(color)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }
}
