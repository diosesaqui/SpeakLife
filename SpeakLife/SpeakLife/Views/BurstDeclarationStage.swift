//
//  BurstDeclarationStage.swift
//  SpeakLife
//
//  The speaking half of the Daily Burst.
//
//  The old screen was a caption and a "Next" button: the user read seven lines
//  and tapped seven times. Nothing about the interaction knew whether they had
//  actually opened their mouth. This one is built around the act of speaking.
//
//  Two ways forward, both costing the same:
//
//    · Tap the button.   The old path, unchanged.
//    · Hold the button.  The ring fills at the pace of this line while the user
//                        speaks it out loud, haptics ticking underneath. A full
//                        charge ignites the card. It then WAITS. The card leaves
//                        when the finger lifts, never before.
//
//  The hold is a reward, never a gate. Releasing early still advances, so nobody
//  who taps their way through loses a streak, and the ritual is there for anyone
//  who wants it.
//
//  Two rules were learned the hard way, from speaking a real burst out loud:
//
//    · The finger is the only thing that knows when the mouth is finished.
//      A timer that advances on its own will always cut someone off mid-sentence,
//      whatever number it is set to. So a completed charge never advances. It
//      lights up and holds until the user lets go.
//    · There is no swipe. It was here for tactility, but a flick is a skip lane:
//      it clears a declaration in a tenth of a second, without a word said, and
//      it fires by accident when a thumb rests on a line someone is still
//      reading. A screen about speaking should not ship a way to not speak.
//

import SwiftUI

// MARK: - Advance method

/// How the user got off a declaration. Reported so the hold can be measured
/// against the tap rather than assumed to be used.
enum BurstAdvanceMethod: String {
    /// Pressed and released without charging all the way.
    case tap
    /// Held through a full charge while speaking, then released.
    case surge
}

// MARK: - Stage

struct BurstDeclarationStage: View {

    let declarations: [BurstDeclaration]
    @Binding var index: Int
    /// Owned by the parent because the ambient power effect gates on it too.
    @Binding var isTransitioning: Bool
    let size: CGSize
    /// Fired the instant a declaration is left, before the index moves.
    let onAdvance: (BurstAdvanceMethod, Int) -> Void
    /// The seventh line has been spoken.
    let onFinish: (BurstAdvanceMethod) -> Void
    let onClose: () -> Void

    @State private var cardOpacity: Double = 1
    @State private var cardLift: CGFloat = 0
    @State private var isCharging = false
    /// The charge reached full and the card is lit, waiting for the finger.
    @State private var isSealed = false
    /// Mirrors the button's charge so the same progress can be drawn under the
    /// words. Driven by the same duration rather than plumbed per frame.
    @State private var spokenProgress: CGFloat = 0
    /// The slow swell of the aura at rest.
    @State private var breath: CGFloat = 1
    /// Bumped when a surge lands, so the rail segment it earned can flare.
    @State private var railLanding = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Bumped on every surge so the flare re-runs from the top, and cleared on
    /// advance so it does not replay itself over the card that follows.
    @State private var surgeFlareID = 0

    private let ember = Color(red: 1.0, green: 0.34, blue: 0.13)

    private var current: BurstDeclaration? {
        declarations.indices.contains(index) ? declarations[index] : nil
    }

    private var isLast: Bool { index >= declarations.count - 1 }

    private var cardWidth: CGFloat { min(size.width * 0.88, 460) }

    /// Every card is the same size. A deck whose top card resizes with the
    /// length of the line does not read as a deck, and the ghosts behind it
    /// would have nothing stable to sit against.
    private var cardHeight: CGFloat { min(max(size.height * 0.40, 300), 430) }

    /// How long this particular line takes to say out loud.
    ///
    /// A fixed duration is wrong for every line that is not the median one: the
    /// first build used 1.4s for all seven and cut people off mid-sentence. This
    /// paces the ring off the actual word count, at roughly the speed someone
    /// declares rather than reads, so the charge lands about when the mouth does.
    /// It only decides when the reward fires; the card still waits for the lift.
    private var chargeDuration: Double {
        let words = current?.text.split(separator: " ").count ?? 12
        return min(max(Double(words) / 2.6 + 0.7, 2.0), 7.5)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, 60)

            Spacer(minLength: DS.Spacing.md)

            deck

            Spacer(minLength: DS.Spacing.md)

            footer
                .padding(.bottom, 44)
        }
        .onChange(of: isCharging) { _, charging in
            if charging {
                spokenProgress = 0
                withAnimation(.linear(duration: chargeDuration)) { spokenProgress = 1 }
            } else {
                withAnimation(.easeOut(duration: 0.25)) { spokenProgress = 0 }
            }
        }
        .onChange(of: isTransitioning) { _, transitioning in
            // A charge interrupted by the card leaving would otherwise leave the
            // aura lit with nothing charging it.
            if transitioning {
                isCharging = false
                isSealed = false
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.white.opacity(0.6))
            }
            .buttonStyle(.dsPressable(feel: .tapSolid))

            Spacer()

            Text("Daily Victory")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)

            Spacer()

            counterRing
        }
    }

    private var counterRing: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: 3)

            Circle()
                .trim(from: 0, to: CGFloat(index + 1) / CGFloat(max(declarations.count, 1)))
                .stroke(DS.Gradient.ember, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: ember.opacity(0.6), radius: 4)
                .animation(DS.Motion.smooth, value: index)

            Text("\(index + 1)")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(width: 40, height: 40)
    }

    // MARK: - Deck

    private var deck: some View {
        ZStack {
            ghost(depth: 2)
            ghost(depth: 1)

            if let current {
                card(current)
                    .id(index)
            }
        }
        .frame(width: cardWidth, height: cardHeight)
        // A background rather than a sibling: it is sized to the deck and then
        // allowed to overspill, so the glow never widens the layout.
        .background(aura)
        .padding(.bottom, 28)
    }

    /// The heat behind the card. Idles at a low glow and swells while charging,
    /// so the screen brightens under the user's own thumb.
    private var aura: some View {
        RadialGradient(
            colors: [Color(hex: "#FFB347").opacity(0.55), Color.clear],
            center: .center,
            startRadius: 10,
            endRadius: 260
        )
        .frame(width: cardWidth * 1.6, height: cardHeight * 1.6)
        .blur(radius: 26)
        // Opacity and scale, never the gradient's own stops: SwiftUI does not
        // interpolate a gradient's colours, so animating those would pop.
        .opacity(isCharging ? 1.0 : 0.36)
        // Breathing, not idling. At rest the glow swells on a four-second cycle,
        // which is roughly a calm breath, so the screen paces the user before
        // they speak instead of just sitting there.
        .scaleEffect(isCharging ? 1.14 : breath)
        .animation(.easeInOut(duration: 0.9), value: isCharging)
        .allowsHitTesting(false)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                breath = 1.06
            }
        }
    }

    /// A stub of the next card peeking out beneath, so seven declarations look
    /// like seven things rather than one thing repeated.
    @ViewBuilder
    private func ghost(depth: Int) -> some View {
        if index + depth < declarations.count {
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .frame(width: cardWidth, height: cardHeight)
                .scaleEffect(1 - CGFloat(depth) * 0.05)
                .offset(y: CGFloat(depth) * 14)
                .opacity(depth == 1 ? 0.55 : 0.28)
                .animation(DS.Motion.smooth, value: index)
                .allowsHitTesting(false)
        }
    }

    private func card(_ declaration: BurstDeclaration) -> some View {
        VStack(spacing: DS.Spacing.md) {
            categoryChip(declaration.categoryLabel)

            Spacer(minLength: DS.Spacing.sm)

            Text(declaration.text)
                .font(.system(size: declarationFontSize(for: declaration.text),
                              weight: .bold, design: .serif))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.65)
                .modifier(SpeakReveal(delay: 0.10))

            // The charge, under the line being spoken.
            //
            // The button's own fill is at the bottom of the screen, under the
            // thumb and outside the reader's focus — the eyes are up here on the
            // words. Same duration, same clock, drawn where someone is actually
            // looking.
            Capsule()
                .fill(DS.Gradient.gold)
                .frame(height: 3)
                .frame(maxWidth: .infinity)
                .scaleEffect(x: spokenProgress, anchor: .leading)
                .opacity(isCharging ? 1 : 0)
                .shadow(color: DS.Palette.gold.opacity(0.6), radius: 4)
                .padding(.horizontal, DS.Spacing.sm)
                .animation(.easeOut(duration: 0.2), value: isCharging)

            Text(declaration.verse)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.62))
                .modifier(SpeakReveal(delay: 0.45))

            Spacer(minLength: DS.Spacing.sm)
        }
        .padding(.vertical, DS.Spacing.lg)
        .padding(.horizontal, DS.Spacing.lg)
        .frame(width: cardWidth, height: cardHeight)
        .background(cardSurface)
        .overlay(surgeFlare)
        .scaleEffect(isCharging ? 1.035 : 1.0)
        .animation(.easeInOut(duration: 0.35), value: isCharging)
        .offset(y: cardLift)
        .opacity(cardOpacity)
        .dsAppear(0, rise: 22)
    }

    private var cardSurface: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .fill(.ultraThinMaterial)

            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .fill(Color.white.opacity(0.06))

            // Two strokes cross-faded, for the same reason as the aura: a
            // gradient cannot be animated from one set of colours to another.
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.22), Color.white.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
                .opacity(isCharging ? 0 : 1)

            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [DS.Palette.gold.opacity(0.95), ember.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .opacity(isCharging ? 1 : 0)
        }
        .shadow(color: DS.Palette.gold.opacity(isCharging ? 0.45 : 0),
                radius: isCharging ? 26 : 18, x: 0, y: 10)
        .shadow(color: Color.black.opacity(0.35), radius: 18, x: 0, y: 10)
        .animation(.easeInOut(duration: 0.35), value: isCharging)
    }

    private func categoryChip(_ label: String) -> some View {
        Text(label.uppercased())
            .font(.system(size: 13, weight: .semibold))
            .kerning(1.2)
            .foregroundColor(.white)
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.xs)
            .background(Capsule().fill(DS.Gradient.ember))
            .modifier(SpeakReveal(delay: 0))
    }

    private var surgeFlare: some View {
        Group {
            if surgeFlareID > 0 {
                SurgeFlare()
                    .id(surgeFlareID)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: DS.Spacing.md) {
            BurstProgressRail(total: declarations.count, current: index, landing: railLanding)
                .frame(width: cardWidth)

            HoldToDeclareButton(
                title: buttonTitle,
                width: min(size.width * 0.85, 460),
                chargeDuration: chargeDuration,
                isLocked: isTransitioning,
                isCharging: $isCharging,
                isSealed: $isSealed,
                onSealed: { seal() },
                onRelease: { didSeal in
                    advance(didSeal ? .surge : .tap)
                }
            )

            Text(hint)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isCharging ? DS.Palette.gold : .white.opacity(0.7))
                .multilineTextAlignment(.center)
                .animation(DS.Motion.quick, value: hint)
                .padding(.horizontal, DS.Spacing.lg)
        }
    }

    private var buttonTitle: String {
        if isSealed { return isLast ? "Sealed" : "Amen" }
        return isLast ? "Seal It" : "Speak It"
    }

    /// The hint's whole job is teaching that the lift is what advances, since
    /// that is the one part of this interaction nobody expects.
    private var hint: String {
        if isSealed { return "Let go when you're done." }
        if isCharging { return "Keep speaking. Take as long as you need." }
        return "Hold the button while you speak it out loud"
    }

    // MARK: - Derived visuals

    /// Long declarations step down a size rather than wrapping into a wall.
    private func declarationFontSize(for text: String) -> CGFloat {
        switch text.count {
        case ..<70:  return 28
        case ..<120: return 24
        default:     return 21
        }
    }

    // MARK: - Advancing

    /// The charge completed. Light the card and stop there: the finger decides
    /// when this line is over, not the clock.
    private func seal() {
        guard !isTransitioning else { return }

        surgeFlareID += 1
        // The flare goes outward — power released, which is the language of this
        // whole screen — and the rail segment it earned flares a beat later. The
        // line was spoken, and it landed somewhere.
        railLanding += 1
        Juice.play(.celebrate)
    }

    private func advance(_ method: BurstAdvanceMethod) {
        guard !isTransitioning else { return }
        isTransitioning = true
        onAdvance(method, index)

        withAnimation(.easeOut(duration: 0.24)) {
            cardLift = -70
            cardOpacity = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            guard !isLast else {
                isTransitioning = false
                onFinish(method)
                return
            }

            // No animation on the reset: the card is invisible and about to be
            // rebuilt by `.id(index)`, which replays the entrance from scratch.
            index += 1
            cardLift = 0
            cardOpacity = 1
            surgeFlareID = 0
            isTransitioning = false
        }
    }
}

// MARK: - Hold to declare

/// The primary control.
///
/// Driven by a zero-distance `DragGesture` rather than `onLongPressGesture`,
/// because a long-press gesture *completes* at its minimum duration and stops
/// reporting: there is no way to tell when the finger actually came up. That is
/// precisely the signal this screen is built on, so the gesture that reports it
/// is the one used.
private struct HoldToDeclareButton: View {

    let title: String
    let width: CGFloat
    /// How long this line takes to speak. Set by the stage per declaration.
    let chargeDuration: Double
    /// True while the card is leaving.
    let isLocked: Bool
    @Binding var isCharging: Bool
    @Binding var isSealed: Bool
    /// The charge hit full. The card lights; nothing advances.
    let onSealed: () -> Void
    /// The finger came up. `true` when it had charged all the way first.
    let onRelease: (Bool) -> Void

    @State private var charge: CGFloat = 0
    @State private var isPressing = false
    @State private var pressScale: CGFloat = 1
    @State private var pending: [DispatchWorkItem] = []

    /// Roughly sixty beats a minute — a resting pulse.
    private let heartbeatInterval: Double = 1.0

    var body: some View {
        ZStack {
            Capsule().fill(DS.Gradient.ember)

            // The charge, drawn as the button filling with gold from the left.
            GeometryReader { proxy in
                Capsule()
                    .fill(DS.Gradient.gold)
                    .frame(width: proxy.size.width * charge)
                    .opacity(0.92)
            }
            .clipShape(Capsule())
            .allowsHitTesting(false)

            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: isSealed ? "flame.fill" : "bolt.fill")
                    .font(.system(size: 19, weight: .bold))
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
            }
            .foregroundColor(.white)
            .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 1)
        }
        .frame(width: width, height: 58)
        .shadow(color: Color(red: 1.0, green: 0.34, blue: 0.13).opacity(0.4),
                radius: isCharging ? 20 : 10, x: 0, y: 6)
        .scaleEffect(pressScale)
        .contentShape(Capsule())
        .gesture(
            // minimumDistance 0 so onChanged lands on touch-down; onEnded is the
            // real lift, which is the whole point.
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !isPressing else { return }
                    beginCharge()
                }
                .onEnded { _ in
                    guard isPressing else { return }
                    endCharge()
                }
        )
        .onChange(of: isLocked) { _, locked in
            // The card left under a finger that is still down. Put the button
            // back to rest now rather than waiting for a lift that may never be
            // delivered.
            if locked { reset() }
        }
        // A raw gesture carries none of a Button's semantics, so VoiceOver is
        // told what this is and what holding it does.
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(title)
        .accessibilityHint("Hold while you speak the declaration out loud, then let go.")
    }

    private func beginCharge() {
        guard !isLocked else { return }

        isPressing = true
        isCharging = true
        isSealed = false
        Juice.play(.tapLight)

        withAnimation(.easeOut(duration: 0.12)) { pressScale = 0.97 }
        withAnimation(.linear(duration: chargeDuration)) { charge = 1 }

        schedule()
    }

    private func endCharge() {
        let sealed = isSealed

        cancelPending()
        isPressing = false
        isCharging = false
        isSealed = false

        withAnimation(.easeOut(duration: 0.18)) { pressScale = 1 }
        withAnimation(.easeOut(duration: 0.22)) { charge = 0 }

        onRelease(sealed)
    }

    /// The rising pulse under the thumb while the line is spoken, and the
    /// completion at the end of it. All of it cancellable, because the finger
    /// can come up at any point.
    private func schedule() {
        cancelPending()

        var items: [DispatchWorkItem] = []

        // Two ticks at fixed fractions told the user how far along a progress bar
        // they were. A steady beat says something is alive under the thumb for as
        // long as they keep speaking — and since the charge is now paced off the
        // line's length, a fixed fraction landed at a different moment on every
        // declaration anyway.
        var beat = heartbeatInterval
        while beat < chargeDuration - 0.15 {
            let item = DispatchWorkItem { PremiumHaptics.safeHeartbeat() }
            DispatchQueue.main.asyncAfter(deadline: .now() + beat, execute: item)
            items.append(item)
            beat += heartbeatInterval
        }

        let full = DispatchWorkItem {
            isSealed = true
            onSealed()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + chargeDuration, execute: full)
        items.append(full)

        pending = items
    }

    private func cancelPending() {
        pending.forEach { $0.cancel() }
        pending = []
    }

    private func reset() {
        cancelPending()
        isPressing = false
        isCharging = false
        isSealed = false
        charge = 0
        pressScale = 1
    }
}

// MARK: - Progress rail

/// Seven segments that light as the burst is spoken. Replaces a row of dots that
/// read the same at slat one and slat six.
private struct BurstProgressRail: View {

    let total: Int
    let current: Int
    /// Bumped when a surge lands. The segment for the line just spoken flares, so
    /// a full hold is visibly recorded rather than only celebrated.
    var landing: Int = 0

    @State private var flash: CGFloat = 0

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<max(total, 1), id: \.self) { slot in
                let isCurrent = slot == current

                Capsule()
                    .fill(fill(for: slot))
                    .frame(height: isCurrent ? 7 + flash * 5 : 4)
                    .frame(maxWidth: .infinity)
                    .shadow(
                        color: slot <= current
                            ? DS.Palette.gold.opacity(0.55 + (isCurrent ? Double(flash) * 0.45 : 0))
                            : .clear,
                        radius: isCurrent ? 7 + flash * 10 : 3
                    )
            }
        }
        .animation(DS.Motion.smooth, value: current)
        .onChange(of: landing) { _, _ in
            // Up fast, down slow, so it reads as something arriving rather than a
            // blink.
            withAnimation(.easeOut(duration: 0.12)) { flash = 1 }
            withAnimation(.easeOut(duration: 0.65).delay(0.12)) { flash = 0 }
        }
    }

    private func fill(for slot: Int) -> AnyShapeStyle {
        slot <= current
            ? AnyShapeStyle(DS.Gradient.gold)
            : AnyShapeStyle(Color.white.opacity(0.22))
    }
}

// MARK: - Surge flare

/// The card igniting: a gold ring thrown outward and a fast bloom behind it.
private struct SurgeFlare: View {

    @State private var ringScale: CGFloat = 0.94
    @State private var ringOpacity: Double = 0.95
    @State private var bloom: Double = 0.6

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .fill(DS.Palette.gold.opacity(0.35))
                .blur(radius: 18)
                // Opacity as a modifier, not baked into the fill colour: a
                // colour swapped inside a shape style does not interpolate.
                .opacity(bloom)

            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .stroke(DS.Gradient.gold, lineWidth: 3)
                .scaleEffect(ringScale)
                .opacity(ringOpacity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.55)) {
                ringScale = 1.28
                ringOpacity = 0
            }
            withAnimation(.easeOut(duration: 0.45)) {
                bloom = 0
            }
        }
    }
}

// MARK: - Speak reveal

/// Sweeps the text into view on a soft diagonal edge, at the pace of a spoken
/// line rather than a screen transition. The eye arrives at the last word about
/// when the mouth does.
struct SpeakReveal: ViewModifier {

    var delay: Double = 0
    var duration: Double = 0.75

    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .mask(
                GeometryReader { proxy in
                    LinearGradient(
                        stops: [
                            .init(color: .white, location: 0.0),
                            .init(color: .white, location: 0.5),
                            .init(color: .clear, location: 0.72)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: proxy.size.width * 2, height: proxy.size.height * 2)
                    .offset(
                        x: shown ? 0 : -proxy.size.width * 1.45,
                        y: shown ? 0 : -proxy.size.height * 1.45
                    )
                }
            )
            .opacity(shown ? 1 : 0)
            .onAppear {
                withAnimation(.easeOut(duration: duration).delay(delay)) { shown = true }
            }
    }
}

// MARK: - Count up

/// A number that climbs to its value instead of arriving already there. Used for
/// the streak on the completion screen, where the whole point is the size of it.
struct CountUpText: View {

    let value: Int
    var duration: Double = 0.9
    var font: Font = .system(size: 28, weight: .black)

    @State private var shown = 0

    var body: some View {
        Text("\(shown)")
            .font(font)
            .foregroundColor(.white)
            .monospacedDigit()
            .contentTransition(.numericText())
            .onAppear { climb() }
            .onChange(of: value) { _, _ in climb() }
    }

    private func climb() {
        guard value > 0 else {
            shown = 0
            return
        }

        // Caps the number of steps so a 300-day streak does not schedule 300
        // timers to say the same thing a 30-day streak says in 30.
        let steps = min(value, 24)
        let interval = duration / Double(steps)

        shown = 0
        for step in 1...steps {
            let target = Int((Double(value) * Double(step) / Double(steps)).rounded())
            DispatchQueue.main.asyncAfter(deadline: .now() + interval * Double(step)) {
                withAnimation(.easeOut(duration: interval)) { shown = target }
            }
        }
    }
}
