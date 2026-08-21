//
//  EscapeHatchView.swift
//  SpeakLife
//
//  The opening question: what are you up against right now?
//
//  This used to be the escape hatch — a quiet link under a thought the app had
//  guessed at. It is now the front door. Being handed someone else's guess at
//  your struggle is a weaker moment than naming your own, and a thought you did
//  not recognise is one you cannot reject with any conviction. So the app asks
//  first, and only serves from the bank when they have nothing specific.
//
//  Three things are true of this screen and must stay true:
//
//  1. **The privacy line tells the truth about where the words go.** When the
//     key is configured the words go to Claude, which writes a counter for the
//     actual thought, and the line says so — for every user, not only premium.
//     Without a key the match runs on device and nothing is sent. It is keyed
//     off the same call the classifier branches on — see `privacyLine` and
//     `ThoughtClassifier.sendsThoughtOffDevice`. These two must never disagree.
//     Either way the sentence is never stored, never synced, and never attached
//     to an analytics event; only the matched terrain ships.
//  2. **Crisis routing runs before anything else.** Before matching, before the
//     network call, before the quota check, before the paywall. Someone who
//     types that they want to end their life gets a person, not a drill, not a
//     round trip and not an upsell.
//  3. **There is no error state.** Every failure of the written path falls back
//     to the reviewed library, and a sentence the library cannot place falls
//     back to the bank. Someone who just typed a real thought must never be
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
    /// The written path is a network call, so the button has to say it is
    /// working. A gold button that does nothing for two seconds is the exact
    /// dead-feeling this screen has already been fixed for once.
    @State private var isWriting = false
    @FocusState private var focused: Bool

    /// Whether the words are about to leave the device.
    ///
    /// Asked of the classifier rather than decided here: the API key arrives
    /// from Remote Config and can be empty, in which case everyone silently
    /// runs the on-device path — and nobody may be told their words were sent
    /// when they were not.
    private var sendsOffDevice: Bool {
        classifier.sendsThoughtOffDevice
    }

    /// Says where the words go, in the moment before someone commits them.
    private var privacyLine: String {
        sendsOffDevice
            ? "Say it the way it actually sounds. It's used once to write your word back, and never saved."
            : "Say it the way it actually sounds. It stays on this phone."
    }

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

    /// A named thought is two words, seven letters, and one word of real length
    /// that carries meaning on its own.
    ///
    /// The carrying-word test is the one doing the work: "i feel like i want to"
    /// clears both counts and still names nothing, and no length rule catches
    /// that. The counts only exist to stop a two-letter fragment.
    ///
    /// Seven, not nine. Nine locked out the shortest real thoughts there are —
    /// "I'm ugly", "I'm sick", "I'm broke", "I'm alone" — and every one of those
    /// hits a keyword rule and would have come back with a high-confidence
    /// match. A bar that rejects the bluntest way someone says the truest thing
    /// is worse than the stub it was raised to catch.
    ///
    /// Nothing here is diagnostic and nothing is stored. It only decides when
    /// the button lights.
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
        guard words.count >= 2, letters >= 7 else { return false }
        return words.contains { !stubWords.contains($0) && $0.count >= 3 }
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

                // Five words, and every one of them is load-bearing.
                //
                // This question was narrowed once, on purpose, to thoughts
                // about YOURSELF and YOUR FUTURE, and the note here said why:
                // anything broader "invited thoughts about other people and
                // circumstances the drill has no answer for". That was true of
                // the drill that existed then — forty-five bank lines across
                // nine terrains. It is not true of this one, which answers a
                // biopsy, a mortgage and a daughter who stopped calling out of
                // the whole reviewed library, and rebukes the thing by name. So
                // the fence came down, because it had started turning away the
                // exact sentences the app is now best at.
                //
                // "Up against" does three things at once. It costs nothing to
                // answer — no self-diagnosis, no measuring your own thought
                // against your standing in Christ before you are allowed to
                // type, which is a two-step task at 2am and was the old
                // question's real failure. It takes a thought or a circumstance
                // equally, and the engine behind it no longer cares which. And
                // it puts the thing OUTSIDE them: something is against them,
                // which is the frame rule 2 in `TakeItCaptive.swift` insists on
                // — never "your thought", never anything that indicts them —
                // and it is the same thing the rebuke is about to speak to.
                //
                // "Right now", not "today". The four-year thing is welcome here.
                Text("What are you up against right now?")
                    // Bigger than the sixteen-word question it replaced, which
                    // could not afford the size. Six words can carry it, and a
                    // question this short should land like one.
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    // The keyboard is up the whole time this screen is on
                    // screen. It shrinks rather than pushing the field off a
                    // small phone at large type sizes.
                    .minimumScaleFactor(0.75)
                    .fixedSize(horizontal: false, vertical: true)

                Text(privacyLine)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.45))
                    .fixedSize(horizontal: false, vertical: true)

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
                // words reads as the app waiting for the rest, which is what it
                // is doing — and it is phrased that way rather than as them
                // getting it wrong. The bar is low enough that almost everything
                // under it really is a fragment, but "write the whole sentence"
                // would be a false accusation the one time it isn't.
                if !entry.isEmpty, !canSubmit, !showReachOut {
                    Text("A few more words, and we'll hand you the one that answers it.")
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
                    Button {
                        Task { await submit() }
                    } label: {
                        HStack(spacing: 8) {
                            if isWriting {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(Color(hex: "#1A264D"))
                            }
                            Text(isWriting ? "Writing your word" : "Take it captive")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(canSubmit ? Color(hex: "#1A264D") : .white.opacity(0.4))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Capsule().fill(submitFill))
                    }
                    .buttonStyle(.dsPressable(feel: .tapSolid))
                    .disabled(!canSubmit || isWriting)

                    // The answer to the blank field. Deliberately a real option
                    // rather than a hidden fallback: some mornings nothing is
                    // loud, and the drill still works — that was the whole
                    // premise of the bank. It just no longer goes first.
                    //
                    // Gated on `!canSubmit`, which is exactly when the button
                    // above it is dead — so this screen always has at least one
                    // live way forward. Gating it on an empty field instead left
                    // a half-typed entry with a disabled CTA and no other door,
                    // which is the same dead end this whole change is fixing.
                    //
                    // It still goes away the moment the entry is real. Sitting
                    // under a finished sentence with the CTA lit, "Nothing
                    // specific" reads as the app's verdict on what was just
                    // written rather than as the other door, and that is
                    // precisely how it was read.
                    if !canSubmit {
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

    @MainActor
    private func submit() async {
        let entry = self.entry
        guard canSubmit, !isWriting else { return }
        focused = false

        // Safety runs first and unconditionally — ahead of the quota check and
        // ahead of any network call, so someone out of entries still reaches
        // this rather than a paywall, and someone in crisis is screened on
        // device before their words could be sent anywhere.
        //
        // Screened here rather than relying on the async classifier's own check
        // so the reach-out card appears immediately, with no spinner and no
        // round trip in front of it, and no scan of the declaration library
        // either — `screensForCrisis` is the screen and nothing else.
        if classifier.screensForCrisis(entry) {
            AnalyticsService.shared.track("guard_escape_hatch_screened",
                                          parameters: ["verdict": "reach_out"])
            withAnimation(DS.Motion.smooth) { showReachOut = true }
            return
        }

        if let remaining, remaining <= 0 {
            onNeedsPremium()
            return
        }

        isWriting = sendsOffDevice
        let classification = await classifier.answer(entry)
        isWriting = false

        // Never a silent return. `answer` can only return `.reachOut` (handled
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
