//
//  EscapeHatchView.swift
//  SpeakLife
//
//  "Something else is on my mind" — the bridge from drill to live use.
//
//  This is where someone types the thought that is actually on them, so three
//  things are true of this screen and must stay true:
//
//  1. **The text never leaves the phone.** Classification runs on device (see
//     `ThoughtClassifier`), the raw sentence is never synced, never persisted,
//     and never attached to an analytics event. Only the matched category ships.
//  2. **Crisis routing runs before anything else.** Before matching, before the
//     quota check, before the paywall. Someone who types that they want to end
//     their life gets a person, not a drill and not an upsell.
//  3. **There is no error state.** A low-confidence match serves a general
//     identity declaration. Someone who just typed a real thought must never be
//     handed "we couldn't understand that" and left holding it.
//

import SwiftUI

struct EscapeHatchView: View {

    /// Serves the flow a thought to speak against.
    let onMatched: (ThoughtCategory, IncomingThought, ThoughtClassification.Confidence) -> Void
    let onBack: () -> Void
    /// Out of free entries. The flow shows the paywall.
    let onNeedsPremium: () -> Void
    /// Remaining free entries this month, or nil for unlimited.
    let remaining: Int?
    let classifier: ThoughtClassifier

    @State private var text = ""
    @State private var showReachOut = false
    @FocusState private var focused: Bool

    private var canSubmit: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "#1B1D22"), Color(hex: "#101216")],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white.opacity(0.4))
                            .frame(width: 32, height: 32)
                    }
                    .accessibilityLabel("Back")
                    Spacer()
                }

                Spacer(minLength: 0)

                // "The thought", never "your thought". It came at them; it is
                // not theirs and it does not indict them.
                Text("What's the loudest thought right now?")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Type it as it sounds. It stays on this phone.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.45))

                TextEditor(text: $text)
                    .focused($focused)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(.white)
                    .scrollContentBackground(.hidden)
                    .frame(height: 120)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )

                if showReachOut {
                    reachOutNotice
                }

                if let remaining, !showReachOut {
                    Text(remaining > 0
                         ? "\(remaining) left this month"
                         : "You've used this month's entries.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                }

                Spacer(minLength: 0)

                if !showReachOut {
                    Button(action: submit) {
                        Text("Take it captive")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(canSubmit ? Color(hex: "#1A264D") : .white.opacity(0.4))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                Capsule().fill(canSubmit
                                               ? AnyShapeStyle(DS.Gradient.gold)
                                               : AnyShapeStyle(Color.white.opacity(0.10)))
                            )
                    }
                    .buttonStyle(.dsPressable(feel: .tapSolid))
                    .disabled(!canSubmit)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .onAppear { focused = true }
    }

    // MARK: - Reach out

    /// Not a drill state. Someone said they want to end their life, and the
    /// honest answer is a person. Same copy and same address as the campaign
    /// card and the personal-declaration flow, from `SituationScreen`, so the
    /// app cannot say two different things in the worst moment it has.
    private var reachOutNotice: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(SituationScreen.reachOutHeadline)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(reachOutAttributed)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
                .tint(DS.Palette.gold)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
    }

    private var reachOutAttributed: AttributedString {
        var text = AttributedString(SituationScreen.reachOutMessage)
        if let range = text.range(of: SituationScreen.supportEmail),
           let url = URL(string: "mailto:\(SituationScreen.supportEmail)") {
            text[range].link = url
            text[range].underlineStyle = .single
        }
        return text
    }

    // MARK: - Submit

    private func submit() {
        let entry = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard entry.count >= 3 else { return }
        focused = false

        // Safety runs first and unconditionally — ahead of the quota check, so
        // a free user out of entries still reaches this rather than a paywall.
        let classification = classifier.classify(entry)
        if case .reachOut = classification {
            AnalyticsService.shared.track("guard_escape_hatch_screened",
                                          parameters: ["verdict": "reach_out"])
            withAnimation(DS.Motion.smooth) { showReachOut = true }
            return
        }

        if let remaining, remaining <= 0 {
            onNeedsPremium()
            return
        }

        guard case .matched(let category, let thought, let confidence) = classification else { return }
        // Category and confidence only. The sentence itself never appears in an
        // event payload — that is the whole promise of this screen.
        AnalyticsService.shared.track("guard_escape_hatch_used", parameters: [
            "category_matched": category.rawValue,
            "confidence": confidence.rawValue
        ])
        onMatched(category, thought, confidence)
    }
}
