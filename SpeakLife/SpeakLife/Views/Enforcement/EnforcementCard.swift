//
//  EnforcementCard.swift
//  SpeakLife
//
//  The Enforcement's home on the Today tab. Four states: locked (non-premium),
//  invitation, active, and nothing at all when the user isn't yet eligible.
//
//  Tone note: this card is an invitation, never an obligation. No badge dot, no
//  unread count, no red. A user with a 200-day streak should never feel they've
//  fallen behind on something that didn't exist yesterday.
//
//  Structure note: a campaign is NOT a second thing to do. `DailyDeclarationBurstView`
//  hands the whole Burst to the active campaign, and `complete_daily_burst` is
//  what advances a day — so this card is a lens on the Burst, not a parallel
//  track. It used to read as its own system (its own seven-dot rail competing
//  with the week strip, audio as the loudest button) and users reasonably
//  concluded that playing the audio was how you completed a day. Hence: speaking
//  the Burst is the primary CTA, audio is secondary, and there is no second
//  progress rail — the day count in the eyebrow carries it.
//
//  That same lens is why the active card has three CTA states, not one. Because
//  the Burst — not this card — banks the day, there are two situations where
//  nothing here can move the campaign forward: today's day is already banked, or
//  today's Burst was spoken before the campaign existed (a campaign started after
//  the Burst can't bank a day, since `completeTask` early-returns on a task that
//  is already checked off). A gold "Speak today's Burst" in either case is a lie:
//  it looks like the way forward and advances nothing. So both resolve to a
//  resting, non-interactive row that says what is already true and when the next
//  day opens.
//

import SwiftUI

struct EnforcementCard: View {
    @ObservedObject var service: EnforcementService

    let isPremium: Bool
    let totalDaysCompleted: Int
    /// Whether today's Daily Burst is already checked off on the checklist.
    ///
    /// The card can't work this out on its own — the Burst lives on the
    /// checklist, not in `EnforcementService` — and it changes what the CTA can
    /// honestly offer, so the caller (which holds today's checklist) answers it.
    var burstCompletedToday: Bool = false

    /// Premium user picked a theme.
    let onStart: (Enforcement) -> Void
    /// Active user tapped into today's audio.
    let onOpenAudio: (EnforcementDay) -> Void
    /// Active user tapped the primary CTA — speaking the Burst is the action
    /// that actually advances the campaign, so it is the button on the card.
    let onOpenBurst: () -> Void
    /// Non-premium user tapped anywhere on the locked card.
    let onLockedTap: () -> Void
    /// Active user chose to drop this campaign and pick a different one.
    let onSwitch: () -> Void
    /// User described what they're walking through. The caller matches it to
    /// categories and assembles the week, calling back with whether a campaign
    /// actually started so the card can keep their text on a failure.
    let onDescribe: (String, @escaping (Bool) -> Void) -> Void

    /// Confirms before dropping a campaign — the days already spoken are lost,
    /// and it sits next to the audio button, so a mis-tap must not wipe progress.
    @State private var confirmingSwitch = false
    /// What the user typed. Local so a slow match never blocks the field.
    @State private var situation = ""
    @State private var isMatching = false
    @State private var matchFailed = false
    /// Set when what they typed is too thin to build a week from. Cleared as
    /// soon as they start editing, so the message never outlives the input.
    @State private var inputError: String?

    var body: some View {
        if service.isEligible(totalDaysCompleted: totalDaysCompleted) {
            Group {
                if let enforcement = service.activeEnforcement, let day = service.activeDay {
                    activeCard(enforcement: enforcement, day: day)
                } else if isPremium {
                    invitationCard
                } else {
                    lockedCard
                }
            }
            .padding(DS.Spacing.md)
            .dsGlass(cornerRadius: DS.Radius.lg, strokeOpacity: 0.16, elevation: DS.Elevation.medium)
        }
    }

    // MARK: - Active

    @ViewBuilder
    private func activeCard(enforcement: Enforcement, day: EnforcementDay) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            eyebrow("DAY \(service.progress.currentDay) OF \(Enforcement.length) · \(enforcement.title.uppercased())")
                .accessibilityLabel("Day \(service.progress.currentDay) of \(Enforcement.length), \(enforcement.title)")

            Text(day.anchorText)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)

            if !day.anchorBook.isEmpty {
                Text(day.anchorBook)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.55))
            }

            todayCTA
                .padding(.top, 2)

            HStack(spacing: DS.Spacing.xs) {
                // Demoted to a quiet row: it is worth having (it warms them up
                // before they speak) but it does not advance anything, so it
                // must not look like the thing to press.
                Button {
                    onOpenAudio(day)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text("\(day.audioTitle) · \(day.audioMinutes) min")
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(1)
                    }
                    .foregroundColor(.white.opacity(0.7))
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel("Play today's audio, \(day.audioTitle)")

                Spacer(minLength: 0)

                // The way out. Without this, picking the wrong theme locks the
                // user into it for seven days with no exit.
                Button {
                    confirmingSwitch = true
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.55))
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel("Switch to a different enforcement")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .confirmationDialog("Switch enforcement?",
                            isPresented: $confirmingSwitch, titleVisibility: .visible) {
            Button("Switch", role: .destructive, action: onSwitch)
            Button("Keep going", role: .cancel) { }
        } message: {
            Text("You're on day \(service.progressSnapshot.currentDay) of \(Enforcement.length). Switching starts a new one from day 1.")
        }
    }

    // MARK: - Today's CTA

    /// What today's row on an active campaign can honestly offer.
    private enum TodayCTAState {
        /// There is a day to bank and speaking the Burst banks it.
        case speak
        /// Today's day is already banked.
        case advanced
        /// The Burst was spoken before this campaign existed, so day 1 waits for
        /// tomorrow's Burst — today's is already checked off and re-speaking it
        /// cannot bank anything.
        case startsTomorrow
    }

    /// Order matters: a campaign that advanced today also has a completed Burst,
    /// and "day banked" is the truer, more encouraging thing to say about it.
    private var todayCTAState: TodayCTAState {
        if service.progress.hasAdvancedToday() { return .advanced }
        if burstCompletedToday { return .startsTomorrow }
        return .speak
    }

    /// The day that opens next. Once a day is banked `currentDay` has already
    /// rolled forward onto it, which is why the eyebrow reads one ahead too.
    private var nextDay: Int {
        service.progress.currentDay
    }

    /// The day they just spoke — the one behind `currentDay`. Never below 1: the
    /// campaign finishes and clears itself on day 7, so this state only ever sees
    /// a mid-campaign day.
    private var spokenDay: Int {
        max(nextDay - 1, 1)
    }

    @ViewBuilder
    private var todayCTA: some View {
        switch todayCTAState {
        case .speak:
            // The action that actually advances the day, named as such. This is
            // the whole answer to "how do I complete it?" — no explanation
            // needed when the button on the campaign is the one that moves it.
            Button(action: onOpenBurst) {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 15, weight: .bold))
                    Text("Speak today's Burst")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                }
                .foregroundColor(DS.Palette.deepBlue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Capsule().fill(DS.Gradient.gold))
            }
            .buttonStyle(.dsPressable(feel: .tapSolid))
            .accessibilityLabel("Speak today's Burst, day \(service.progress.currentDay) of \(Enforcement.length)")

        case .advanced:
            restingCTA(
                "Day \(spokenDay) spoken · Day \(nextDay) opens tomorrow",
                accessibilityLabel: "Day \(spokenDay) spoken. Day \(nextDay) of \(Enforcement.length) opens tomorrow."
            )

        case .startsTomorrow:
            VStack(spacing: 6) {
                restingCTA(
                    "Starts with tomorrow's Burst",
                    accessibilityLabel: "You already spoke today's Burst. This campaign starts with tomorrow's Burst."
                )
                // Says the why out loud. Without it the row reads as a delay
                // someone was handed for no reason.
                Text("You already spoke today's Burst.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .accessibilityHidden(true)
            }
        }
    }

    /// The done-for-today row. Deliberately not a Button: there is nothing here
    /// to press, and a pressable gold capsule that banks nothing is the bug this
    /// state exists to kill.
    private func restingCTA(_ title: String, accessibilityLabel: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 15, weight: .bold))
            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundColor(DS.Palette.gold.opacity(0.85))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Capsule().fill(Color.white.opacity(0.08)))
        .overlay(Capsule().stroke(DS.Palette.gold.opacity(0.30), lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    // The seven-dot day rail used to live here. Removed deliberately: the Today
    // header already carries a seven-item progress row (the week strip), and two
    // of them on one screen — tracking the same daily action with different
    // meanings — is what made a campaign read as a separate track to keep up
    // with. "DAY 3 OF 7" in the eyebrow says the same thing in less space.

    // MARK: - Invitation

    private var invitationCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            eyebrow("ENFORCE THE VICTORY")

            Text("What area of life do you need victory in?")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.95))
                .fixedSize(horizontal: false, vertical: true)

            // States the contract before they type. The feature already works
            // this way — DailyDeclarationBurstView hands the whole Burst to the
            // active campaign — it just never said so, so nothing connected what
            // someone typed here to the words that came out of their mouth.
            //
            // "Something you're believing for" is doing real work: plenty of
            // people open this in a good week with a vision rather than a storm,
            // and a question that only admits storms sends them away with
            // nothing. It's also the app's own language for this already —
            // the personal declaration feature counts "days of believing".
            Text("Name a fight, or something you're believing for. Your Daily Burst is built around it for seven days.")
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)

            // The real entry point. Four fixed themes can't know that this week
            // is different from last week; their own words can.
            situationField

            if let inputError {
                Text(inputError)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DS.Palette.gold.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if matchFailed {
                // No longer reachable by wording: EnforcementAssembler walks a
                // fallback chain, so every category the matcher can return
                // fills seven days. What's left is the declaration pool not
                // being loaded yet, which is not the speaker's fault to fix.
                Text("Couldn't reach your declarations just now. Try again, or pick a theme below.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DS.Palette.gold.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Demoted from a co-equal option. Presented level with the field,
            // the chips taught people to answer with a theme name — one word,
            // which is the least the curator can work with.
            Text("or start from a theme")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.4))
                .padding(.top, 2)

            // The theme matching their strongest onboarding signal leads, but
            // every theme stays one tap away — this is a suggestion, not a route.
            let recommended = service.recommendedEnforcement()
            themeChips { enforcement in
                Button { onStart(enforcement) } label: {
                    chipLabel(enforcement.themeName, locked: false,
                              highlighted: enforcement.id == recommended?.id)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Locked

    private var lockedCard: some View {
        Button(action: onLockedTap) {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(DS.Palette.gold.opacity(0.9))
                    eyebrow("ENFORCE THE VICTORY")
                }

                Text("Seven days standing on what Jesus already won.")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.92))
                    .fixedSize(horizontal: false, vertical: true)

                // Themes stay legible so the user can see exactly what's behind
                // the paywall before deciding.
                themeChips { enforcement in
                    chipLabel(enforcement.themeName, locked: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("Enforce the victory. Premium feature. Tap to learn more.")
    }

    private static let placeholderExamples = [
        "e.g. I'm under attack at work and I'm exhausted",
        "e.g. I'm believing God to start my own business"
    ]

    private static var placeholderExample: String {
        let day = Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
        return placeholderExamples[day % placeholderExamples.count]
    }

    /// The input that makes the week theirs.
    ///
    /// The placeholder is a worked example rather than another instruction: it
    /// shows the length that produces a good week, which is the one thing a
    /// question mark cannot communicate. Asked "what area of life do you need
    /// victory in?" with no example, people answer with an area — one or two
    /// words — and the curator has nothing to read.
    ///
    /// The example alternates between a fight and something they're believing
    /// for, so neither kind of week looks like the wrong answer. It turns over
    /// daily rather than randomly: a placeholder that changed mid-session would
    /// read as a glitch.
    private var situationField: some View {
        HStack(spacing: 8) {
            TextField(text: $situation, axis: .vertical) {
                Text(Self.placeholderExample)
                    .foregroundColor(.white.opacity(0.45))
            }
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1...3)
                .disabled(isMatching)
                .submitLabel(.go)
                .onSubmit(submitSituation)
                .onChange(of: situation) { _ in
                    if inputError != nil { inputError = nil }
                    if matchFailed { matchFailed = false }
                }

            Button(action: submitSituation) {
                if isMatching {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .frame(width: 30, height: 30)
                } else {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(canSubmit ? DS.Palette.gold : .white.opacity(0.25))
                }
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!canSubmit || isMatching)
            .accessibilityLabel("Build my week")
        }
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                .fill(Color.white.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
    }

    private var canSubmit: Bool {
        situation.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3
    }

    private func submitSituation() {
        let text = situation.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 3, !isMatching else { return }

        // Validated on submit, not by disabling the arrow. A greyed-out button
        // with no explanation is where this went wrong before: someone types the
        // name of a theme, nothing happens, and there is nothing to learn from.
        // Let the tap through and answer it.
        do {
            try DeclarationInputValidator.validate(text)
        } catch {
            AnalyticsService.shared.track("enforcement_input_rejected", parameters: [
                "reason": "\(error)", "length": text.count
            ])
            inputError = "A few more words. A sentence about the fight, or what you're believing for, gives you seven days that actually fit."
            return
        }

        inputError = nil
        isMatching = true
        matchFailed = false
        onDescribe(text) { started in
            isMatching = false
            if started {
                // The card flips to its active state; the field goes with it.
                situation = ""
            } else {
                // Keep what they wrote. Losing someone's description of a hard
                // week and showing nothing is the worst version of this failing.
                matchFailed = true
            }
        }
    }

    // MARK: - Shared pieces

    private func eyebrow(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .tracking(1.4)
            .foregroundColor(DS.Palette.gold.opacity(0.9))
            .lineLimit(1)
    }

    /// Wraps the catalog into two rows so four theme names never crowd.
    @ViewBuilder
    private func themeChips<Chip: View>(@ViewBuilder chip: @escaping (Enforcement) -> Chip) -> some View {
        let enforcements = service.catalog
        VStack(spacing: 8) {
            ForEach(Array(stride(from: 0, to: enforcements.count, by: 2)), id: \.self) { start in
                HStack(spacing: 8) {
                    ForEach(enforcements[start..<min(start + 2, enforcements.count)]) { enforcement in
                        chip(enforcement)
                    }
                }
            }
        }
    }

    private func chipLabel(_ title: String, locked: Bool, highlighted: Bool = false) -> some View {
        Text(title)
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundColor(locked ? .white.opacity(0.6) : .white)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                    .fill(Color.white.opacity(locked ? 0.07 : (highlighted ? 0.20 : 0.13)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                    .stroke(highlighted ? DS.Palette.gold.opacity(0.75)
                                        : Color.white.opacity(locked ? 0.12 : 0.22),
                            lineWidth: highlighted ? 1.5 : 1)
            )
    }
}
