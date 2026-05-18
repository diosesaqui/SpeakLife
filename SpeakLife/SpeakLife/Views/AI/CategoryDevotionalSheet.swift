//
//  CategoryDevotionalSheet.swift
//  SpeakLife
//
//  Lets the user pick a topical category and generates a fresh devotional
//  on-device in the same shape as the editorial devotionals in
//  devotionals.json. Renders the result using the existing DevotionalView
//  styling so it feels identical to the curated daily devotional.
//

import SwiftUI
import FirebaseAnalytics

struct CategoryDevotionalSheet: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var subscriptionStore: SubscriptionStore

    @State private var selectedCategory: GeneratedDevotionalCategory?
    @State private var title: String = ""
    @State private var body_: String = ""
    @State private var scriptureLine: String = ""
    @State private var generating: Bool = false
    @State private var errorMessage: String?

    private let generator: OnDeviceDevotionalGeneratorProtocol

    init(generator: OnDeviceDevotionalGeneratorProtocol = OnDeviceDevotionalGenerator()) {
        self.generator = generator
    }

    private var hasResult: Bool { !title.isEmpty || !body_.isEmpty }

    var body: some View {
        ZStack {
            background

            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    handleBar

                    if generator.isAvailable == false {
                        unavailableNotice
                    } else if hasResult || generating {
                        resultView
                    } else {
                        picker
                    }

                    if let err = errorMessage {
                        Text(err)
                            .font(Font.custom("AppleSDGothicNeo-Regular", size: 13, relativeTo: .caption))
                            .foregroundColor(Color(hex: "F87171"))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 140)
            }

            VStack {
                Spacer()
                if generator.isAvailable {
                    actionButton
                        .padding(.horizontal, 24)
                        .padding(.bottom, 28)
                }
            }
        }
    }

    // MARK: - Subviews

    private var background: some View {
        ZStack {
            Image(subscriptionStore.backgroundImage)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            Color.black.opacity(0.55)
                .ignoresSafeArea()
        }
    }

    private var handleBar: some View {
        Capsule()
            .fill(Color.white.opacity(0.25))
            .frame(width: 40, height: 4)
            .padding(.top, 12)
    }

    private var picker: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Text("New Devotional")
                    .font(Font.custom("AppleSDGothicNeo-Bold", size: 24, relativeTo: .title))
                    .foregroundColor(.white)
                Text("Pick a category. Apple Intelligence writes one tailored to you, in the SpeakLife voice.")
                    .font(Font.custom("AppleSDGothicNeo-Regular", size: 14, relativeTo: .footnote))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(GeneratedDevotionalCategory.allCases) { cat in
                    categoryCell(cat)
                }
            }
        }
        .padding(.top, 4)
    }

    private func categoryCell(_ cat: GeneratedDevotionalCategory) -> some View {
        let isSelected = selectedCategory == cat
        return Button {
            withAnimation(.easeOut(duration: 0.15)) { selectedCategory = cat }
        } label: {
            VStack(spacing: 6) {
                Text(cat.emoji).font(.system(size: 28))
                Text(cat.label)
                    .font(Font.custom("AppleSDGothicNeo-Bold", size: 14, relativeTo: .body))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isSelected ? Color(hex: "7C3AED").opacity(0.4) : Color.white.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color(hex: "A78BFA") : Color.white.opacity(0.15),
                            lineWidth: isSelected ? 1.5 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private var resultView: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let cat = selectedCategory {
                HStack(spacing: 6) {
                    Text(cat.emoji)
                    Text(cat.label.uppercased())
                        .font(Font.custom("AppleSDGothicNeo-Bold", size: 12, relativeTo: .caption))
                        .foregroundColor(Color(hex: "A78BFA"))
                        .tracking(1.5)
                }
            }

            Text(title.isEmpty ? "Writing your devotional…" : title)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)

            if !scriptureLine.isEmpty {
                Text(scriptureLine)
                    .font(.system(size: 16, weight: .semibold))
                    .italic()
                    .foregroundColor(.white.opacity(0.9))
            }

            if !body_.isEmpty {
                Text(body_)
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.85))
                    .lineSpacing(5)
            } else if generating {
                HStack(spacing: 8) {
                    ProgressView().tint(.white)
                    Text("Drawing from the well…")
                        .font(Font.custom("AppleSDGothicNeo-Regular", size: 14, relativeTo: .footnote))
                        .foregroundColor(.white.opacity(0.65))
                }
                .padding(.top, 4)
            }
        }
        .padding(.top, 4)
    }

    private var unavailableNotice: some View {
        VStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 28))
                .foregroundColor(.white.opacity(0.7))
            Text("On-device devotionals need iOS 26 with Apple Intelligence enabled.")
                .font(Font.custom("AppleSDGothicNeo-Regular", size: 14, relativeTo: .footnote))
                .foregroundColor(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
            Button("Close") { dismiss() }
                .foregroundColor(Color(hex: "A78BFA"))
                .padding(.top, 8)
        }
        .padding(.vertical, 40)
    }

    @ViewBuilder
    private var actionButton: some View {
        if hasResult {
            HStack(spacing: 12) {
                Button {
                    resetForNewGeneration()
                } label: {
                    Text("Pick another")
                        .font(Font.custom("AppleSDGothicNeo-Bold", size: 16, relativeTo: .body))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.white.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.white.opacity(0.25), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                Button {
                    Analytics.logEvent("ai_devotional_done",
                                       parameters: ["category": selectedCategory?.rawValue ?? "unknown"])
                    dismiss()
                } label: {
                    Text("Amen")
                        .font(Font.custom("AppleSDGothicNeo-Bold", size: 16, relativeTo: .body))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color(hex: "7C3AED"))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
        } else {
            Button {
                Task { await runGenerate() }
            } label: {
                Group {
                    if generating {
                        ProgressView().tint(.white)
                    } else {
                        Text("Generate Devotional")
                            .font(Font.custom("AppleSDGothicNeo-Bold", size: 16, relativeTo: .body))
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(selectedCategory != nil ? Color(hex: "7C3AED") : Color.gray.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(selectedCategory == nil || generating)
        }
    }

    // MARK: - Actions

    private func resetForNewGeneration() {
        title = ""
        body_ = ""
        scriptureLine = ""
        errorMessage = nil
        selectedCategory = nil
    }

    @MainActor
    private func runGenerate() async {
        guard let cat = selectedCategory else { return }
        errorMessage = nil
        generating = true
        title = ""
        body_ = ""
        scriptureLine = ""
        Analytics.logEvent("ai_devotional_start", parameters: ["category": cat.rawValue])

        do {
            for try await partial in generator.stream(category: cat) {
                title = partial.title
                scriptureLine = partial.books
                body_ = partial.devotionalText
            }
            Analytics.logEvent("ai_devotional_success", parameters: ["category": cat.rawValue])
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? "Couldn't generate a devotional right now."
            Analytics.logEvent("ai_devotional_error",
                               parameters: ["category": cat.rawValue, "reason": "\(error)"])
        }
        generating = false
    }
}
