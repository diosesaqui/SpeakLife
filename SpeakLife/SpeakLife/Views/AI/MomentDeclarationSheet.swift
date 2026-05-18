//
//  MomentDeclarationSheet.swift
//  SpeakLife
//
//  "Declaration of the Moment" — a sheet that generates a fresh, personal
//  declaration on-device from the user's input. Two launch modes:
//
//  1. Standalone — user opens the sheet, types or speaks what they're going
//     through, taps Generate. Used as an on-demand mid-day feature.
//
//  2. Auto-generate from text — caller passes `autoStartInput` (e.g. the
//     text the user just posted to the Warrior Room) and the sheet
//     immediately streams a personalized declaration tied to that post.
//
//  Streaming is preferred when available so the declaration types itself
//  out in front of the user, matching the "emotional peak" beats described
//  in PERSONAL_DECLARATION_SPEC.md.
//

import SwiftUI
import FirebaseAnalytics

struct MomentDeclarationSheet: View {

    /// When non-nil, generation kicks off automatically using this text and
    /// the text input is hidden. Used by the Warrior Room post-submit flow.
    let autoStartInput: String?

    /// Optional source label for analytics — "warrior_room_post",
    /// "declaration_of_the_moment", etc.
    let source: String

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var subscriptionStore: SubscriptionStore

    @State private var userInput: String = ""
    @State private var generating: Bool = false
    @State private var declarationText: String = ""
    @State private var verseText: String = ""
    @State private var verseReference: String = ""
    @State private var errorMessage: String?

    private let generator: OnDeviceDeclarationGeneratorProtocol

    init(autoStartInput: String? = nil,
         source: String = "declaration_of_the_moment",
         generator: OnDeviceDeclarationGeneratorProtocol = OnDeviceDeclarationGenerator()) {
        self.autoStartInput = autoStartInput
        self.source = source
        self.generator = generator
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    handleBar
                    header

                    if autoStartInput == nil {
                        inputField
                    }

                    if generator.isAvailable == false {
                        unavailableNotice
                    } else if generating || !declarationText.isEmpty {
                        generatedCard
                    }

                    if let err = errorMessage {
                        Text(err)
                            .font(Font.custom("AppleSDGothicNeo-Regular", size: 13, relativeTo: .caption))
                            .foregroundColor(Color(hex: "F87171"))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
            }
            .scrollDismissesKeyboard(.interactively)

            actionButton
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
                .padding(.top, 12)
        }
        .background(background)
        .onAppear {
            if let prefill = autoStartInput, !prefill.isEmpty {
                userInput = prefill
                Task { await runGenerate() }
            }
        }
    }

    /// Resigns first responder app-wide. Used when Generate fires so the
    /// keyboard doesn't sit on top of the streaming result.
    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
    }

    // MARK: - Subviews

    private var background: some View {
        ZStack {
            Image(subscriptionStore.onboardingBGImage)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            Color.black.opacity(0.62)
                .ignoresSafeArea()
        }
    }

    private var handleBar: some View {
        Capsule()
            .fill(Color.white.opacity(0.25))
            .frame(width: 40, height: 4)
            .padding(.top, 12)
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text(autoStartInput == nil
                 ? "Declaration of the Moment"
                 : "Your Personal Declaration")
                .font(Font.custom("AppleSDGothicNeo-Bold", size: 22, relativeTo: .title2))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            Text(autoStartInput == nil
                 ? "Speak life into what you're walking through right now."
                 : "Generated from what you just shared. Speak it daily.")
                .font(Font.custom("AppleSDGothicNeo-Regular", size: 13, relativeTo: .caption))
                .foregroundColor(.white.opacity(0.65))
                .italic()
                .multilineTextAlignment(.center)
        }
        .padding(.top, 4)
    }

    private var inputField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What are you facing right now?")
                .font(Font.custom("AppleSDGothicNeo-Regular", size: 13, relativeTo: .caption))
                .foregroundColor(.white.opacity(0.55))
            ZStack(alignment: .topLeading) {
                if userInput.isEmpty {
                    Text("Healing, finances, fear, my marriage…")
                        .font(Font.custom("AppleSDGothicNeo-Regular", size: 15, relativeTo: .body))
                        .foregroundColor(.white.opacity(0.35))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                }
                TextEditor(text: $userInput)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 90, maxHeight: 140)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .foregroundColor(.white)
                    .font(Font.custom("AppleSDGothicNeo-Regular", size: 15, relativeTo: .body))
            }
            .background(Color.white.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private var unavailableNotice: some View {
        VStack(spacing: 10) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 28))
                .foregroundColor(.white.opacity(0.7))
            Text("AI generation isn't ready right now. Check your connection and try again in a moment.")
                .font(Font.custom("AppleSDGothicNeo-Regular", size: 14, relativeTo: .footnote))
                .foregroundColor(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
        }
        .padding(.vertical, 24)
    }

    private var generatedCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !declarationText.isEmpty {
                Text(declarationText)
                    .font(Font.custom("AppleSDGothicNeo-Bold", size: 20, relativeTo: .title3))
                    .foregroundColor(.white)
                    .lineSpacing(4)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            } else if generating {
                HStack(spacing: 10) {
                    ProgressView().tint(.white)
                    Text("Drawing this together…")
                        .font(Font.custom("AppleSDGothicNeo-Regular", size: 14, relativeTo: .footnote))
                        .foregroundColor(.white.opacity(0.65))
                }
                .padding(.vertical, 8)
            }

            if !verseText.isEmpty {
                Divider()
                    .background(Color.white.opacity(0.18))
                VStack(alignment: .leading, spacing: 6) {
                    Text(verseText)
                        .font(Font.custom("AppleSDGothicNeo-Regular", size: 15, relativeTo: .body))
                        .italic()
                        .foregroundColor(.white.opacity(0.9))
                        .lineSpacing(3)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                    if !verseReference.isEmpty {
                        Text(verseReference)
                            .font(Font.custom("AppleSDGothicNeo-Bold", size: 13, relativeTo: .caption))
                            .foregroundColor(Color(hex: "A78BFA"))
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    @ViewBuilder
    private var actionButton: some View {
        if declarationText.isEmpty {
            Button {
                Task { await runGenerate() }
            } label: {
                actionLabel(title: "Generate", enabled: canGenerate)
            }
            .disabled(!canGenerate || generating)
        } else {
            Button {
                Analytics.logEvent("moment_declaration_done", parameters: ["source": source])
                dismiss()
            } label: {
                actionLabel(title: "Amen", enabled: true)
            }
        }
    }

    private func actionLabel(title: String, enabled: Bool) -> some View {
        Group {
            if generating {
                ProgressView().tint(.white)
            } else {
                Text(title)
                    .font(Font.custom("AppleSDGothicNeo-Bold", size: 16, relativeTo: .body))
                    .foregroundColor(.white)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .background(enabled ? Color(hex: "7C3AED") : Color.gray.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var canGenerate: Bool {
        guard generator.isAvailable else { return false }
        let trimmed = userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= 8
    }

    // MARK: - Generation

    @MainActor
    private func runGenerate() async {
        guard generator.isAvailable else {
            errorMessage = "AI generation isn't ready yet. Try again in a moment."
            return
        }
        let trimmed = userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 8 else {
            errorMessage = "Add a few more words about what you're facing."
            return
        }

        dismissKeyboard()
        errorMessage = nil
        declarationText = ""
        verseText = ""
        verseReference = ""
        generating = true
        Analytics.logEvent("moment_declaration_start", parameters: ["source": source])

        do {
            for try await partial in generator.stream(from: trimmed) {
                declarationText = partial.declarationText
                verseText = partial.verseText
                verseReference = partial.verseReference
            }
            Analytics.logEvent("moment_declaration_success", parameters: ["source": source])
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? "Couldn't generate a declaration right now."
            Analytics.logEvent("moment_declaration_error",
                               parameters: ["source": source, "reason": "\(error)"])
        }
        generating = false
    }
}
