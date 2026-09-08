//
//  LiftView.swift
//  SpeakLife
//
//  The front door: where do you need Him lifted high today?
//
//  This replaces the ASK screen, and the replacement is the single biggest
//  usability change in the feature. That screen opened on a blank text field and
//  the question "What are you up against right now?", which required the user to
//  articulate the worst thing in their head before the app would give them
//  anything. Two failures fell out of that:
//
//  - At 7am nothing is queued. The blank field produced a bounce, which the old
//    screen answered with a secondary "nothing specific" link — a fallback doing
//    the job of a front door.
//  - At 2am, in a real storm, naming it is the hardest thing a person can do,
//    and it was the toll gate in front of the one line they needed to say.
//
//  Magnifying needs no input at all. You can always exalt God, with nothing on
//  your mind or everything on it. So the default cost of entry is ONE TAP on the
//  part of life you want Him lifted over — and even that is optional.
//
//  Three doors, and none of them is a lesser choice:
//
//  1. **A domain chip.** One tap. Names the ground, never the enemy — "My body",
//     not "my diagnosis"; "My provision", not "my debt". This is CLAUDE.md rule
//     12 applied to an input control.
//  2. **Storm mode.** Nothing asked at all. Straight to a name of God and a line
//     to say, unmetered and never behind a paywall. See `MagnifyService.stormEntry`.
//  3. **The written route**, kept because naming a specific thing genuinely does
//     produce a better-matched declaration for it. It is now optional, secondary,
//     and fully on device — `ThoughtClassifier.classify` reaches the whole
//     reviewed library synchronously with no network call, so there is no
//     spinner, no round trip, and nothing to disclose about where the words go.
//     What the user types is used to pick the DECLARATION and is never displayed
//     back, never stored, and never attached to an analytics event.
//
//  Crisis routing runs before anything else on the written route — before
//  matching, before the quota check, before the paywall. Someone who types that
//  they want to end their life gets a person, not a rep and not an upsell.
//

import SwiftUI

struct LiftView: View {

    /// Remaining free written entries, or nil when this one is unmetered — which
    /// is the case for the day's own rep. Magnifying is the daily task, so
    /// metering it would put the whole pillar behind the paywall.
    let remaining: Int?
    let classifier: ThoughtClassifier
    /// A domain was tapped. Nil means "nothing specific" — let the rotation pick.
    let onDomain: (MagnifyDomain?) -> Void
    /// They named something. The app answers it with a declaration matched to
    /// what they wrote, under the same name of God the bank chose.
    let onNamed: (_ domain: MagnifyDomain, _ declaration: MatchedDeclaration) -> Void
    /// Right now it's a lot. No questions.
    let onStorm: () -> Void
    /// Out of free written entries on an extra rep.
    let onNeedsPremium: () -> Void
    let onClose: () -> Void

    /// What the written route hands back: only the parts of a match that are
    /// allowed to move. The name of God and the exaltation stay as the bank
    /// wrote them — see `MagnifyEntry.answering(_:)`.
    struct MatchedDeclaration {
        let declaration: String
        let verseText: String
        let book: String
        let category: String
    }

    @State private var writing = false
    @State private var text = ""
    @State private var showReachOut = false
    @FocusState private var focused: Bool

    private let field = Color(hex: "#1A264D")
    private let deepField = Color(hex: "#0F1730")
    private let gold = Color(hex: "#F5B742")

    private let columns = [GridItem(.flexible(), spacing: 10),
                           GridItem(.flexible(), spacing: 10),
                           GridItem(.flexible(), spacing: 10)]

    var body: some View {
        ZStack {
            LinearGradient(colors: [field, deepField], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            RadialGradient(colors: [gold.opacity(0.13), .clear],
                           center: .top, startRadius: 10, endRadius: 380)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                header
                if writing { writingBody } else { pickerBody }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .preferredColorScheme(.dark)
        .animation(DS.Motion.smooth, value: writing)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("MAGNIFY THE LORD")
                .font(.system(size: 11, weight: .bold))
                .tracking(2.6)
                .foregroundColor(gold.opacity(0.75))
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.32))
                    .frame(width: 32, height: 32)
            }
            .accessibilityLabel("Close")
        }
    }

    // MARK: - Picker

    private var pickerBody: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Spacer(minLength: 0)

            // Seven words. "Lifted high" rather than "magnified" because the
            // gesture has to be obvious before the vocabulary is — rule 15 beats
            // consistency of terminology every time.
            Text("Where do you need Him lifted high?")
                .font(.system(size: 27, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .minimumScaleFactor(0.75)
                .fixedSize(horizontal: false, vertical: true)

            Text("One tap. Nothing to explain.")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.5))

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(MagnifyDomain.allCases) { domain in
                    domainChip(domain)
                }
            }
            .padding(.top, 2)

            // Never a hidden fallback. Some mornings nothing is loud and the rep
            // still works — that was always true, it just used to be buried
            // under a text field the user had to fail at first.
            Button {
                PremiumHaptics.safeLight()
                AnalyticsService.shared.track("magnify_domain_skipped")
                onDomain(nil)
            } label: {
                Text("Surprise me. Show me who He is today.")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.62))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(
                        Capsule().stroke(Color.white.opacity(0.20), lineWidth: 1)
                    )
            }
            .buttonStyle(.dsPressable(feel: .tapSolid))

            Spacer(minLength: 0)

            stormBand

            Button {
                writing = true
                focused = true
                AnalyticsService.shared.track("magnify_written_route_opened")
            } label: {
                Text("Something specific? Name it.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.42))
                    .underline()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
        }
    }

    private func domainChip(_ domain: MagnifyDomain) -> some View {
        Button {
            PremiumHaptics.safeLight()
            AnalyticsService.shared.track("magnify_domain_chosen",
                                          parameters: ["domain": domain.rawValue])
            onDomain(domain)
        } label: {
            VStack(spacing: 7) {
                Image(systemName: domain.icon)
                    .font(.system(size: 19, weight: .medium))
                    .foregroundColor(gold.opacity(0.92))
                Text(domain.chipTitle)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.92))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .fill(Color.white.opacity(0.07))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .stroke(Color.white.opacity(0.11), lineWidth: 1)
            )
        }
        .buttonStyle(.dsPressable(feel: .tapSolid))
        .accessibilityLabel("Magnify God over \(domain.chipTitle)")
    }

    /// The answer to "even when life's storms are crazy".
    ///
    /// Deliberately on the FIRST screen rather than behind a menu, and
    /// deliberately not styled as an emergency — a red panic button would make
    /// reaching for it a confession of failure, which is the last thing someone
    /// in a hard week needs from a worship feature. It reads as the other door,
    /// because that is what it is.
    private var stormBand: some View {
        Button {
            PremiumHaptics.safeMedium()
            AnalyticsService.shared.track("magnify_storm_entered",
                                          parameters: ["entry": "lift_screen"])
            onStorm()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "cloud.bolt.rain")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(gold)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Right now it's a lot")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Skip the questions. He's bigger than this.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white.opacity(0.35))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .fill(gold.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .stroke(gold.opacity(0.30), lineWidth: 1)
            )
        }
        .buttonStyle(.dsPressable(feel: .tapSolid))
    }

    // MARK: - Written route

    private var writingBody: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Spacer(minLength: 0)

            Text("What's on you right now?")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .minimumScaleFactor(0.75)
                .fixedSize(horizontal: false, vertical: true)

            // Always true, and true for every user. `classify` is synchronous and
            // on device — it never reaches the network, so unlike the screen this
            // replaced there is no configured-key branch and no second wording.
            Text("Say it however it actually sounds. It stays on this phone, and it's only used to pick the word you'll speak.")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.45))
                .fixedSize(horizontal: false, vertical: true)

            TextEditor(text: $text)
                .focused($focused)
                .font(.system(size: 17, weight: .regular))
                .foregroundColor(.white)
                .scrollContentBackground(.hidden)
                .frame(height: 110)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )

            if !entry.isEmpty, !canSubmit, !showReachOut {
                Text("A few more words, and we'll hand you the word that answers it.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.42))
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
            }

            if showReachOut { reachOutNotice }

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
                    Text("Lift Him over this")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(canSubmit ? Color(hex: "#1A264D") : .white.opacity(0.4))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Capsule().fill(submitFill))
                }
                .buttonStyle(.dsPressable(feel: .tapSolid))
                .disabled(!canSubmit)
            }

            Button {
                focused = false
                showReachOut = false
                writing = false
            } label: {
                Text("Back")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.45))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
        }
        .animation(DS.Motion.quick, value: canSubmit)
    }

    /// Not a rep state. Someone said they want to end their life, and the honest
    /// answer is a person. Same copy and same address as the campaign card and
    /// the personal-declaration flow, from `SituationScreen`, so the app cannot
    /// say two different things in the worst moment it has.
    private var reachOutNotice: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(SituationScreen.reachOutHeadline)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(reachOutAttributed)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
                .tint(gold)
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
        var value = AttributedString(SituationScreen.reachOutMessage)
        if let range = value.range(of: SituationScreen.supportEmail),
           let url = URL(string: "mailto:\(SituationScreen.supportEmail)") {
            value[range].link = url
            value[range].underlineStyle = .single
        }
        return value
    }

    // MARK: - Submit

    private func submit() {
        guard canSubmit else { return }
        focused = false

        // Safety runs first and unconditionally — ahead of the quota check and
        // ahead of matching, so someone out of entries still reaches this rather
        // than a paywall.
        if classifier.screensForCrisis(entry) {
            AnalyticsService.shared.track("magnify_written_screened",
                                          parameters: ["verdict": "reach_out"])
            withAnimation(DS.Motion.smooth) { showReachOut = true }
            return
        }

        if let remaining, remaining <= 0 {
            onNeedsPremium()
            return
        }

        // Synchronous and on device. The classifier reads both keyword tables and
        // reaches the whole reviewed library, which is how someone four years
        // into infertility lands on the twenty-five FERTILITY declarations rather
        // than a general word about being complete in Christ.
        let classification = classifier.classify(entry)

        // Never a silent return. `classify` can only return `.reachOut` (handled
        // above) or `.matched`, but a bare `guard … else { return }` would mean a
        // dead button if that ever stops being true — and the person on the other
        // side of it has just typed the thing they are carrying. The last resort
        // is a reviewed identity line, so even the impossible branch hands them a
        // word.
        let matched: IncomingThought
        let legacyCategory: ThoughtCategory
        if case .matched(let category, let thought, _) = classification {
            legacyCategory = category
            matched = thought
        } else {
            legacyCategory = .inadequacy
            matched = ThoughtClassifier.lastResort
        }

        let domain = MagnifyDomain.fromLegacyRawValue(legacyCategory.rawValue) ?? .identity

        // Domain only. The sentence itself never appears in an event payload —
        // that is the whole promise of this screen.
        AnalyticsService.shared.track("magnify_written_used",
                                      parameters: ["domain": domain.rawValue])

        onNamed(domain, MatchedDeclaration(
            declaration: matched.counterDeclaration,
            verseText: matched.verseText,
            book: matched.book,
            category: matched.declarationCategory
        ))
    }

    // MARK: - Entry validation

    private var entry: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSubmit: Bool {
        Self.namesSomething(entry)
    }

    /// Lifted out of the modifier chain — a ternary between two `AnyShapeStyle`
    /// wrappers inside a `.fill` inside a `.background` is the kind of nesting
    /// that costs the type checker real time, and this feature's predecessor
    /// failed an archive on that class of expression.
    private var submitFill: AnyShapeStyle {
        canSubmit
            ? AnyShapeStyle(DS.Gradient.gold)
            : AnyShapeStyle(Color.white.opacity(0.10))
    }

    /// Two words, seven letters, and one word of real length that carries meaning
    /// on its own.
    ///
    /// The carrying-word test is the one doing the work: "i feel like i want to"
    /// clears both counts and still names nothing, and no length rule catches
    /// that. The counts only exist to stop a two-letter fragment.
    ///
    /// Seven, not nine. Nine locked out the shortest real sentences there are —
    /// "I'm sick", "I'm broke", "I'm alone" — and a bar that rejects the bluntest
    /// way someone says the truest thing is worse than the stub it was raised to
    /// catch. Nothing here is diagnostic and nothing is stored; it only decides
    /// when the button lights.
    static func namesSomething(_ entry: String) -> Bool {
        // iOS substitutes a curly apostrophe as you type, so both forms have to
        // survive tokenising or "I'm drowning" splits into "i" and "m drowning"
        // and the stub list stops recognising anything.
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
}
