//
//  EscapeHatchView.swift
//  SpeakLife
//
//  The opening question: what thought have you been carrying that doesn't line
//  up with God's word?
//
//  This used to be the escape hatch — a quiet link under a thought the app had
//  guessed at. It is now the front door. Being handed someone else's guess at
//  your struggle is a weaker moment than naming your own, and a thought you did
//  not recognise is one you cannot reject with any conviction. So the app asks
//  first, and only serves from the bank when they have nothing specific.
//
//  Three things are true of this screen and must stay true:
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

struct AskForThoughtView: View {

    /// Remaining free entries, or nil when this one is unmetered — which is the
    /// case for the day's rep. Naming your own thought IS the daily task now, so
    /// metering it would put the whole feature behind the paywall.
    let remaining: Int?
    let classifier: ThoughtClassifier
    /// Serves the flow the user's own words plus the matched counter.
    let onNamed: (_ typed: String, _ matched: IncomingThought) -> Void
    /// Nothing specific today — fall back to the bank. This is the answer to the
    /// blank-field bounce, and it must never feel like a lesser choice.
    let onNothingSpecific: () -> Void
    /// Out of free extra reps. The flow shows the paywall.
    let onNeedsPremium: () -> Void
    let onClose: () -> Void

    @State private var text = ""
    @State private var showReachOut = false
    @FocusState private var focused: Bool

    private var entry: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Whether what is in the field is a thought, or the first two words of one.
    ///
    /// The bar used to be three characters, which lit the button on "I am". Four
    /// characters that name nothing, match no keyword, and route straight to the
    /// low-confidence fallback — so someone who half-typed a sentence got handed
    /// a generic identity declaration and no sign that the app had missed what
    /// they were actually carrying. The button now waits for a real sentence.
    private var canSubmit: Bool {
        Self.namesAThought(entry)
    }

    /// A named thought is at least two words, nine letters, and one word that
    /// carries meaning on its own.
    ///
    /// The word list is the reason the third test exists: "i feel like i want
    /// to" clears both counts and still names nothing. Nothing in it is
    /// diagnostic and nothing is stored — it only decides when the button lights.
    static func namesAThought(_ entry: String) -> Bool {
        // iOS substitutes a curly apostrophe as you type, so both forms have to
        // survive tokenising or "I'm worthless" splits into "i" and "m
        // worthless" and the stub list stops recognising anything.
        let normalized: String = entry.lowercased().replacingOccurrences(of: "\u{2019}", with: "'")
        var words: [String] = []
        var letters: Int = 0
        for piece in normalized.split(whereSeparator: { !$0.isLetter && $0 != "'" }) {
            let word = String(piece)
            words.append(word)
            letters += word.count
        }
        guard words.count >= 2, letters >= 9 else { return false }
        return words.contains { !stubWords.contains($0) }
    }

    /// Function words. An entry made only of these is a half-typed sentence.
    private static let stubWords: Set<String> = [
        "i", "im", "i'm", "ive", "i've", "me", "my", "mine", "myself",
        "a", "an", "the", "it", "its", "it's", "this", "that", "there",
        "is", "am", "are", "was", "were", "be", "been", "being",
        "do", "does", "did", "have", "has", "had", "get", "got", "getting",
        "can", "can't", "cant", "will", "would", "should", "could", "might",
        "feel", "feeling", "feels", "think", "thinking", "want", "wanted",
        "like", "just", "really", "very", "so", "and", "but", "or", "not",
        "no", "of", "to", "in", "on", "for", "with", "about", "at", "as",
        "keep", "keeps", "always", "never", "all", "too", "much", "some",
        "what", "why", "how", "when", "know", "kind", "sort"
    ]

    /// Lifted out of the modifier chain — a ternary between two `AnyShapeStyle`
    /// wrappers inside a `.fill` inside a `.background` is the kind of nesting
    /// that costs the type checker real time, and this feature already failed an
    /// archive on that class of expression.
    private var submitFill: AnyShapeStyle {
        canSubmit
            ? AnyShapeStyle(DS.Gradient.gold)
            : AnyShapeStyle(Color.white.opacity(0.10))
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "#1B1D22"), Color(hex: "#101216")],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                HStack {
                    Text("TAKE IT CAPTIVE")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(2.6)
                        .foregroundColor(.white.opacity(0.38))
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white.opacity(0.32))
                            .frame(width: 32, height: 32)
                    }
                    .accessibilityLabel("Close")
                }

                Spacer(minLength: 0)

                // "The thought", never "your thought". It came at them; it is
                // not theirs and it does not indict them. The question names
                // what makes a thought worth rejecting — that it disagrees with
                // what God said — rather than asking them to diagnose it.
                Text("What thought have you been carrying that doesn't line up with God's word?")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Write it the way it actually sounds. It stays on this phone.")
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

                // Only once they have started, and never before. A hint on an
                // empty field reads as a rule to clear; a hint under two typed
                // words reads as the app waiting for the rest of the sentence,
                // which is exactly what it is doing.
                if !entry.isEmpty, !canSubmit, !showReachOut {
                    Text("Write the whole sentence so we can hand you the right word for it.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.42))
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity)
                }

                if showReachOut {
                    reachOutNotice
                }

                if let remaining, !showReachOut {
                    Text(remaining > 0
                         ? "\(remaining) more this month"
                         : "You've used this month's extra entries.")
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
                            .background(Capsule().fill(submitFill))
                    }
                    .buttonStyle(.dsPressable(feel: .tapSolid))
                    .disabled(!canSubmit)

                    // The answer to the blank field. Deliberately a real option
                    // rather than a hidden fallback: some mornings nothing is
                    // loud, and the drill still works — that was the whole
                    // premise of the bank. It just no longer goes first.
                    //
                    // It disappears the moment they start typing. Left on screen
                    // under a field with words in it, "Nothing specific" reads as
                    // the app's verdict on what they just wrote rather than as
                    // the other door, and that is precisely how it was read.
                    if entry.isEmpty {
                        Button {
                            focused = false
                            AnalyticsService.shared.track("guard_nothing_specific_tapped")
                            onNothingSpecific()
                        } label: {
                            Text("Can't name one? Give me one to work with.")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.5))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                        .transition(.opacity)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .animation(DS.Motion.quick, value: canSubmit)
            .animation(DS.Motion.quick, value: entry.isEmpty)
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
        let entry = self.entry
        guard canSubmit else { return }
        focused = false

        // Safety runs first and unconditionally — ahead of the quota check, so
        // someone out of entries still reaches this rather than a paywall.
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

        // Never a silent return. `classify` can only answer `.reachOut` (handled
        // above) or `.matched`, but a `guard … else { return }` here would mean
        // the button doing nothing at all if that ever stops being true — and a
        // dead button is the one outcome this screen cannot afford, because the
        // person on the other side of it has just typed the thing they are
        // carrying. The last resort is a reviewed identity line, so even the
        // impossible branch hands them a word.
        let resolved: (ThoughtCategory, IncomingThought, ThoughtClassification.Confidence)
        if case .matched(let matchedCategory, let matchedThought, let matchedConfidence) = classification {
            resolved = (matchedCategory, matchedThought, matchedConfidence)
        } else {
            resolved = (.inadequacy, ThoughtClassifier.lastResort, .low)
        }
        let (category, matched, confidence) = resolved

        // Category and confidence only. The sentence itself never appears in an
        // event payload — that is the whole promise of this screen.
        AnalyticsService.shared.track("guard_escape_hatch_used", parameters: [
            "category_matched": category.rawValue,
            "confidence": confidence.rawValue
        ])
        onNamed(entry, matched)
    }
}
