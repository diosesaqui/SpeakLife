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
//  Three ways forward, all of them ending at the same place:
//
//    · Tap the button.        The old path, unchanged in cost.
//    · Swipe the card away.   The line is a card in a deck of seven, so the
//                             burst has a shape the thumb can feel.
//    · Hold the button.       The ring fills while the user speaks the line out
//                             loud, haptics tick underneath, the card ignites,
//                             and it advances itself on a surge.
//
//  The hold is a reward, never a gate. Releasing early still advances, so no one
//  who taps their way through loses a streak, and the ritual is there for anyone
//  who wants it.
//

import SwiftUI

// MARK: - Advance method

/// How the user got off a declaration. Reported so the surge can be measured
/// against the tap rather than assumed to be used.
enum BurstAdvanceMethod: String {
    /// Pressed and released the button.
    case tap
    /// Threw the card off the screen.
    case swipe
    /// Held the button through a full charge while speaking.
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

    @State private var drag: CGSize = .zero
    @State private var cardOpacity: Double = 1
    @State private var pastThreshold = false
    @State private var isCharging = false
    /// Bumped on every surge so the flare re-runs from the top, and cleared on
    /// advance so it does not replay itself over the card that follows.
    @State private var surgeFlareID = 0

    private let ember = Color(red: 1.0, green: 0.34, blue: 0.13)

    private var current: BurstDeclaration? {
        declarations.indices.contains(index) ? declarations[index] : nil
    }

    private var isLast: Bool { index >= declarations.count - 1 }

    /// Wide enough that a read of the line never becomes a flick.
    private var swipeThreshold: CGFloat { max(88, size.width * 0.24) }

    private var cardWidth: CGFloat { min(size.width * 0.88, 460) }

    /// Every card is the same size. A deck whose top card resizes with the
    /// length of the line does not read as a deck, and the ghosts behind it
    /// would have nothing stable to sit against.
    private var cardHeight: CGFloat { min(max(size.height * 0.40, 300), 430) }

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
        .onChange(of: isTransitioning) { _, transitioning in
            // A charge interrupted by the card leaving would otherwise leave the
            // aura lit with nothing charging it.
            if transitioning { isCharging = false }
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
                .contentTransition(.numericText())
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
        .scaleEffect(isCharging ? 1.14 : 1.0)
        .animation(.easeInOut(duration: 0.9), value: isCharging)
        .allowsHitTesting(false)
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

            Text(declaration.verse)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.62))
                .modifier(SpeakReveal(delay: 0.45))

            Spacer(minLength: DS.Spacing.sm)

            releaseHint
        }
        .padding(.vertical, DS.Spacing.lg)
        .padding(.horizontal, DS.Spacing.lg)
        .frame(width: cardWidth, height: cardHeight)
        .background(cardSurface)
        .overlay(surgeFlare)
        .scaleEffect(cardScale)
        .rotationEffect(.degrees(Double(drag.width) / 26))
        .offset(x: drag.width, y: drag.height * 0.22)
        .opacity(cardOpacity * dragFade)
        .gesture(dragGesture)
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

    /// Appears only once the card is far enough to leave, so the gesture teaches
    /// itself the first time a thumb wanders.
    private var releaseHint: some View {
        Text(pastThreshold ? "Release" : "Swipe or hold to speak it")
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .kerning(0.6)
            .foregroundColor(pastThreshold ? DS.Palette.gold : .white.opacity(0.45))
            .animation(DS.Motion.quick, value: pastThreshold)
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
            BurstProgressRail(total: declarations.count, current: index)
                .frame(width: cardWidth)

            HoldToDeclareButton(
                title: isLast ? "Seal It" : "Speak It",
                width: min(size.width * 0.85, 460),
                isLocked: isTransitioning,
                isCharging: $isCharging,
                onRelease: { advance(.tap, exit: CGSize(width: 0, height: -70)) },
                onSurge: { surge() }
            )

            Text(isCharging ? "Keep speaking. Power is building." : "Hold the button while you speak it out loud")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isCharging ? DS.Palette.gold : .white.opacity(0.7))
                .multilineTextAlignment(.center)
                .animation(DS.Motion.quick, value: isCharging)
                .padding(.horizontal, DS.Spacing.lg)
        }
    }

    // MARK: - Gesture

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard !isTransitioning else { return }
                drag = value.translation

                let crossed = abs(value.translation.width) > swipeThreshold
                if crossed != pastThreshold {
                    pastThreshold = crossed
                    if crossed { Juice.play(.tapSolid) }
                }
            }
            .onEnded { value in
                guard !isTransitioning else { return }

                if abs(value.translation.width) > swipeThreshold {
                    let direction: CGFloat = value.translation.width > 0 ? 1 : -1
                    advance(.swipe, exit: CGSize(width: direction * size.width * 1.25,
                                                 height: value.translation.height))
                } else {
                    pastThreshold = false
                    withAnimation(DS.Motion.bouncy) { drag = .zero }
                }
            }
    }

    // MARK: - Derived visuals

    /// The card shrinks and dims as it is pulled aside, so a half-committed
    /// swipe reads as "not yet" without a word of copy.
    private var dragFade: Double {
        let distance = min(abs(Double(drag.width)), 400)
        return 1 - (distance / 400) * 0.45
    }

    private var cardScale: CGFloat {
        let pulled = min(abs(drag.width), 400) / 400
        return (isCharging ? 1.035 : 1.0) - pulled * 0.04
    }

    /// Long declarations step down a size rather than wrapping into a wall.
    private func declarationFontSize(for text: String) -> CGFloat {
        switch text.count {
        case ..<70:  return 28
        case ..<120: return 24
        default:     return 21
        }
    }

    // MARK: - Advancing

    private func surge() {
        guard !isTransitioning else { return }

        surgeFlareID += 1
        Juice.play(.celebrate)

        // Lets the flare read before the card leaves under it.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            advance(.surge, exit: CGSize(width: 0, height: -90))
        }
    }

    private func advance(_ method: BurstAdvanceMethod, exit: CGSize) {
        guard !isTransitioning else { return }
        isTransitioning = true
        onAdvance(method, index)

        // A tap already buzzed on press-down and a surge has its own celebration,
        // so only the swipe still needs a confirmation under the thumb.
        if method == .swipe { Juice.play(.tapLight) }

        withAnimation(.easeOut(duration: 0.24)) {
            drag = exit
            cardOpacity = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            pastThreshold = false

            guard !isLast else {
                isTransitioning = false
                onFinish(method)
                return
            }

            // No animation on the reset: the card is invisible and about to be
            // rebuilt by `.id(index)`, which replays the entrance from scratch.
            index += 1
            drag = .zero
            cardOpacity = 1
            surgeFlareID = 0
            isTransitioning = false
        }
    }
}

// MARK: - Hold to declare

/// The primary control. A press advances on release; a press held through a full
/// charge fires a surge instead and advances itself.
private struct HoldToDeclareButton: View {

    let title: String
    let width: CGFloat
    /// True while the card is leaving. The button keeps taking touches so a
    /// gesture already under way completes normally, but nothing it reports gets
    /// acted on twice.
    let isLocked: Bool
    @Binding var isCharging: Bool
    let onRelease: () -> Void
    let onSurge: () -> Void

    @State private var charge: CGFloat = 0
    @State private var didSurge = false
    /// The charge *reached* full. `charge` itself is set to 1 the moment the
    /// press starts and only rendered gradually, so it cannot answer this.
    @State private var didReachFull = false
    @State private var pressScale: CGFloat = 1
    @State private var ticks: [DispatchWorkItem] = []

    /// Long enough to say a declaration over, short enough that nobody waits.
    private let chargeDuration: Double = 1.4

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
                Image(systemName: didReachFull ? "flame.fill" : "bolt.fill")
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
        .onLongPressGesture(minimumDuration: chargeDuration, maximumDistance: 60) {
            fireSurge()
        } onPressingChanged: { pressing in
            pressing ? beginCharge() : endCharge()
        }
        .onChange(of: isLocked) { _, locked in
            // The card left under a finger that is still down. Put the button
            // back to rest now rather than waiting for a lift that may be
            // delivered as a cancellation instead.
            if locked { reset() }
        }
    }

    private func beginCharge() {
        guard !isLocked else { return }
        didSurge = false
        didReachFull = false
        isCharging = true
        Juice.play(.tapLight)

        withAnimation(.easeOut(duration: 0.12)) { pressScale = 0.97 }
        withAnimation(.linear(duration: chargeDuration)) { charge = 1 }

        scheduleTicks()
    }

    private func endCharge() {
        cancelTicks()
        withAnimation(.easeOut(duration: 0.18)) { pressScale = 1 }

        // The surge already advanced the burst; the lift is just the finger
        // leaving a button that has done its job.
        guard !didSurge else {
            didReachFull = false
            charge = 0
            return
        }

        isCharging = false
        withAnimation(.easeOut(duration: 0.22)) { charge = 0 }
        onRelease()
    }

    private func fireSurge() {
        guard !isLocked else { return }
        didSurge = true
        didReachFull = true
        cancelTicks()
        // Stays charging on purpose: the card should still be lit while the
        // flare plays over it. The stage clears this when the card leaves.
        charge = 1
        onSurge()
    }

    private func reset() {
        cancelTicks()
        didSurge = false
        didReachFull = false
        isCharging = false
        charge = 0
        pressScale = 1
    }

    /// A rising pulse under the thumb while the line is being spoken.
    private func scheduleTicks() {
        cancelTicks()

        let beats: [(Double, Juice.Feel)] = [
            (chargeDuration * 0.35, .tapLight),
            (chargeDuration * 0.70, .tapSolid)
        ]

        ticks = beats.map { beat in
            let item = DispatchWorkItem { Juice.play(beat.1) }
            DispatchQueue.main.asyncAfter(deadline: .now() + beat.0, execute: item)
            return item
        }
    }

    private func cancelTicks() {
        ticks.forEach { $0.cancel() }
        ticks = []
    }
}

// MARK: - Progress rail

/// Seven segments that light as the burst is spoken. Replaces a row of dots that
/// read the same at slat one and slat six.
private struct BurstProgressRail: View {

    let total: Int
    let current: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<max(total, 1), id: \.self) { slot in
                Capsule()
                    .fill(fill(for: slot))
                    .frame(height: slot == current ? 7 : 4)
                    .frame(maxWidth: .infinity)
                    .shadow(color: slot <= current ? DS.Palette.gold.opacity(0.55) : .clear,
                            radius: slot == current ? 7 : 3)
            }
        }
        .animation(DS.Motion.smooth, value: current)
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
