//
//  GuardMotion.swift
//  SpeakLife
//
//  The look, the motion and the feel the Take It Captive drill shares.
//
//  Three rules hold across every screen:
//
//  1. Nothing pops in. Text arrives the way light comes into focus: blurred,
//     a few points low, then sharp and in place on one soft spring.
//  2. Every visible beat has a matching haptic, shaped to what is on screen.
//     The seize is a pull and a snap. The spoken line is a swell that follows
//     the gold across the words. The +1 is a bloom with sparks after it.
//  3. Reduce Motion is honoured everywhere. Blur, travel, sweeps and sparks
//     drop out and only the fades remain. Haptics stay, since they are not
//     motion.
//

import SwiftUI
import CoreHaptics
import UIKit

// MARK: - Style

/// Type, colour and timing every screen in the drill shares.
///
/// Two tiers of quiet text, not five: `secondary` for a line someone should
/// read, `tertiary` for chrome such as close buttons and the quieter links.
/// Scripture is always set in the serif, so a verse never reads as interface
/// copy.
enum GuardStyle {
    static let gold = Color(hex: "#F5B742")
    /// Warm off-white for scripture. Pure white is harsh on navy at reading size.
    static let scriptureInk = Color(hex: "#F3EEE4")
    static let secondary = Color.white.opacity(0.62)
    static let tertiary = Color.white.opacity(0.40)

    static func scripture(_ size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .serif).italic()
    }

    /// A verse reference, uppercased and spaced like a seal under its line.
    static let reference: Font = .system(size: 12, weight: .semibold)
    static let referenceTracking: CGFloat = 1.8

    static let eyebrow: Font = .system(size: 11, weight: .bold)
    static let eyebrowTracking: CGFloat = 2.6

    /// The house spring. Settles fast with a whisper of overshoot.
    static let spring = Animation.spring(duration: 0.6, bounce: 0.18)
    /// For things that should feel caught, like a button lighting up.
    static let lively = Animation.spring(duration: 0.5, bounce: 0.4)
    /// The Reduce Motion stand-in: a plain fade, no travel.
    static let fade = Animation.easeOut(duration: 0.3)
}

// MARK: - Reveal

/// Brings a view in out of focus: blurred, slightly low and slightly small,
/// then sharp and settled on one spring. Under Reduce Motion it only fades.
struct GuardReveal: ViewModifier {
    let shown: Bool
    var delay: Double = 0
    var distance: CGFloat = 10

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let still = shown || reduceMotion
        content
            .opacity(shown ? 1 : 0)
            .blur(radius: still ? 0 : 10)
            .offset(y: still ? 0 : distance)
            .scaleEffect(still ? 1 : 0.97)
            .animation((reduceMotion ? GuardStyle.fade : GuardStyle.spring).delay(delay),
                       value: shown)
    }
}

extension View {
    func guardReveal(_ shown: Bool, delay: Double = 0, distance: CGFloat = 10) -> some View {
        modifier(GuardReveal(shown: shown, delay: delay, distance: distance))
    }

    /// A band of light swept across the view, masked to its own shape so only
    /// the letters (or the button) catch it. Drive `progress` from 0 to 1.
    func goldSweep(_ progress: CGFloat, tint: Color = GuardStyle.gold) -> some View {
        modifier(GoldSweep(progress: progress, tint: tint))
    }
}

/// A short gold rule that draws outward from its centre.
struct GuardRule: View {
    var shown: Bool = true
    var delay: Double = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Capsule()
            .fill(LinearGradient(colors: [GuardStyle.gold.opacity(0.1),
                                          GuardStyle.gold.opacity(0.85),
                                          GuardStyle.gold.opacity(0.1)],
                                 startPoint: .leading, endPoint: .trailing))
            .frame(width: 36, height: 1.5)
            .scaleEffect(x: shown || reduceMotion ? 1 : 0.05, y: 1)
            .opacity(shown ? 1 : 0)
            .animation((reduceMotion ? GuardStyle.fade : GuardStyle.spring).delay(delay),
                       value: shown)
            .accessibilityHidden(true)
    }
}

// MARK: - Word by word

/// A line that arrives one word at a time, each word coming into focus a beat
/// after the last. Used for the verse on the Taken Captive screen, where the
/// words are the moment and deserve to be read as they land.
struct WordByWordText: View {
    let text: String
    let font: Font
    let color: Color
    let shown: Bool
    var delay: Double = 0
    var stagger: Double = 0.05
    var lineSpacing: CGFloat = 5
    var wordSpacing: CGFloat = 4.5

    var body: some View {
        let words = text.split(separator: " ").map(String.init)
        CenteredFlowLayout(wordSpacing: wordSpacing, lineSpacing: lineSpacing) {
            ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                Text(word)
                    .font(font)
                    .foregroundColor(color)
                    .fixedSize()
                    .guardReveal(shown, delay: delay + Double(index) * stagger, distance: 6)
            }
        }
        // VoiceOver reads the line once, whole, rather than word by word.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }
}

/// Lays words out in centred lines, wrapping at the width it is offered.
struct CenteredFlowLayout: Layout {
    var wordSpacing: CGFloat
    var lineSpacing: CGFloat

    private struct Line {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let lines = breakLines(within: proposal.width ?? .infinity, subviews: subviews)
        let widest = lines.map(\.width).max() ?? 0
        let height = lines.map(\.height).reduce(0, +)
            + lineSpacing * CGFloat(max(lines.count - 1, 0))
        return CGSize(width: widest, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize,
                       subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        // A hair of slack so rounding never pushes a word onto a line of its own.
        for line in breakLines(within: bounds.width + 0.5, subviews: subviews) {
            var x = bounds.minX + (bounds.width - line.width) / 2
            for index in line.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y + (line.height - size.height) / 2),
                                      proposal: ProposedViewSize(size))
                x += size.width + wordSpacing
            }
            y += line.height + lineSpacing
        }
    }

    private func breakLines(within maxWidth: CGFloat, subviews: Subviews) -> [Line] {
        var lines = [Line()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let current = lines[lines.count - 1]
            let needed = current.indices.isEmpty ? size.width : current.width + wordSpacing + size.width
            if needed > maxWidth, !current.indices.isEmpty {
                lines.append(Line(indices: [index], width: size.width, height: size.height))
            } else {
                lines[lines.count - 1].indices.append(index)
                lines[lines.count - 1].width = needed
                lines[lines.count - 1].height = max(current.height, size.height)
            }
        }
        return lines
    }
}

// MARK: - Sweep

struct GoldSweep: ViewModifier {
    let progress: CGFloat
    let tint: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.overlay {
            if !reduceMotion {
                GeometryReader { geo in
                    LinearGradient(colors: [.clear, tint.opacity(0.9), .white.opacity(0.85),
                                            tint.opacity(0.9), .clear],
                                   startPoint: .leading, endPoint: .trailing)
                        .frame(width: geo.size.width * 0.42, height: geo.size.height * 1.8)
                        .rotationEffect(.degrees(16))
                        .offset(x: geo.size.width * (progress * 1.8 - 0.7),
                                y: -geo.size.height * 0.4)
                }
                .mask { content }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        }
    }
}

// MARK: - Celebration

/// Gold sparks thrown out from the centre once, then gone. Paired with a
/// ripple ring. Both are invisible until fired and leave nothing behind.
struct GoldBurst: View {
    /// Set true to arm (sparks gathered at the centre), then `fired` true on
    /// the next beat to throw them.
    let armed: Bool
    let fired: Bool
    var radius: CGFloat = 96
    var count: Int = 12

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if !reduceMotion {
            ZStack {
                // The ripple: one ring, then a fainter second.
                ForEach(0..<2, id: \.self) { ring in
                    Circle()
                        .stroke(GuardStyle.gold.opacity(ring == 0 ? 0.7 : 0.4),
                                lineWidth: ring == 0 ? 2 : 1.2)
                        .frame(width: 84, height: 84)
                        .scaleEffect(fired ? 2.6 : 0.6)
                        .opacity(fired ? 0 : (armed ? 1 : 0))
                        .animation(.easeOut(duration: 1.0).delay(Double(ring) * 0.14), value: fired)
                }

                ForEach(0..<count, id: \.self) { index in
                    let jitter: Double = index.isMultiple(of: 2) ? 0.12 : -0.08
                    let angle: Double = Double(index) / Double(count) * 2 * Double.pi + jitter
                    let spread: CGFloat = index % 3 == 0 ? 0.72 : 1.0
                    let reach: CGFloat = radius * spread
                    let travel: CGFloat = fired ? reach : reach * 0.2
                    let size: CGFloat = index.isMultiple(of: 2) ? 5 : 3.5
                    Circle()
                        .fill(index % 4 == 0 ? Color.white : GuardStyle.gold)
                        .frame(width: size, height: size)
                        .offset(x: CGFloat(cos(angle)) * travel,
                                y: CGFloat(sin(angle)) * travel)
                        .scaleEffect(fired ? 0.3 : 1)
                        .opacity(fired ? 0 : (armed ? 1 : 0))
                        .animation(.easeOut(duration: 0.85), value: fired)
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}

// MARK: - Haptics

/// Haptics shaped to each moment of the drill, played on Core Haptics.
///
/// The app's stock impacts are single taps. These are short compositions that
/// follow what the eye sees: a rising pull into a snap, a swell that tracks the
/// gold sweep, a bloom that fades with the glow. On hardware without Core
/// Haptics, each falls back to the nearest stock impact. All of them respect
/// the app's haptics setting.
final class GuardHaptics {

    static let shared = GuardHaptics()

    private var engine: CHHapticEngine?
    private var holdPlayer: CHHapticAdvancedPatternPlayer?
    private let supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics

    private init() {}

    /// Same switch `PremiumHaptics` reads. Unset means on.
    private var enabled: Bool {
        UserDefaults.standard.object(forKey: "hapticsEnabled") as? Bool ?? true
    }

    /// Spins the engine up ahead of the first beat so it never lands late.
    func prepare() {
        guard enabled else { return }
        _ = runningEngine()
    }

    // MARK: Moments

    /// The CTA lights up: a soft double click, like something seating home.
    func ready() {
        play([tap(0, 0.55, 0.35), tap(0.07, 0.3, 0.65)]) { PremiumHaptics.light() }
    }

    /// The thought is seized: a short rising pull, a hard snap, then a falling
    /// rumble as the card drops away.
    func seize() {
        play([hum(0, 0.14, 0.7, 0.25),
              tap(0.14, 1.0, 0.85),
              hum(0.16, 0.26, 0.45, 0.1)],
             curves: [ramp(0, [(0, 0.15), (0.14, 1.0)]),
                      ramp(0.16, [(0, 1.0), (0.26, 0.0)])]) { PremiumHaptics.heavy() }
    }

    /// The verse lands. Barely there, the way the words come into focus.
    func verse() {
        play([tap(0, 0.38, 0.12)]) { PremiumHaptics.light() }
    }

    /// The line is confirmed spoken: a swell that rises and falls with the gold
    /// crossing the words, finished by a firm success tap.
    func spoken(sweep duration: TimeInterval = 0.9) {
        play([hum(0, duration, 0.6, 0.3),
              tap(duration + 0.02, 0.95, 0.55),
              tap(duration + 0.12, 0.5, 0.35)],
             curves: [ramp(0, [(0, 0.1), (duration * 0.5, 1.0), (duration, 0.15)])]) {
            PremiumHaptics.success()
        }
    }

    /// One crisp tick, for the count rolling over.
    func tick() {
        play([tap(0, 0.6, 0.95)]) { PremiumHaptics.light() }
    }

    /// The +1: a full bloom that fades with the glow, then three sparks.
    func celebrate() {
        play([tap(0, 1.0, 0.55),
              hum(0.02, 0.6, 0.7, 0.15),
              tap(0.18, 0.5, 0.85),
              tap(0.30, 0.38, 0.9),
              tap(0.40, 0.26, 0.95)],
             curves: [ramp(0.02, [(0, 1.0), (0.6, 0.0)])]) { PremiumHaptics.success() }
    }

    /// Press-and-hold: a tension that builds under the thumb for as long as
    /// the bar fills. `cancelHold()` lets go of it.
    func beginHold(duration: TimeInterval) {
        guard enabled else { return }
        guard let engine = runningEngine() else { PremiumHaptics.light(); return }
        do {
            let pattern = try CHHapticPattern(
                events: [hum(0, duration, 1.0, 0.2)],
                parameterCurves: [ramp(0, [(0, 0.12), (duration, 0.9)])])
            let player = try engine.makeAdvancedPlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
            holdPlayer = player
        } catch {
            PremiumHaptics.light()
        }
    }

    func cancelHold() {
        try? holdPlayer?.stop(atTime: CHHapticTimeImmediate)
        holdPlayer = nil
    }

    // MARK: Engine

    private func runningEngine() -> CHHapticEngine? {
        guard supportsHaptics else { return nil }
        if engine == nil {
            guard let fresh = try? CHHapticEngine() else { return nil }
            fresh.isAutoShutdownEnabled = true
            fresh.playsHapticsOnly = true
            // The system can reset the engine (a call, the app backgrounding).
            // Start it again so the next beat still lands.
            fresh.resetHandler = { [weak fresh] in try? fresh?.start() }
            engine = fresh
        }
        do {
            try engine?.start()
        } catch {
            engine = nil
        }
        return engine
    }

    private func play(_ events: [CHHapticEvent],
                      curves: [CHHapticParameterCurve] = [],
                      fallback: () -> Void) {
        guard enabled else { return }
        guard let engine = runningEngine() else { fallback(); return }
        do {
            let pattern = try CHHapticPattern(events: events, parameterCurves: curves)
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            fallback()
        }
    }

    // MARK: Building blocks

    private func tap(_ time: TimeInterval, _ intensity: Float, _ sharpness: Float) -> CHHapticEvent {
        CHHapticEvent(eventType: .hapticTransient,
                      parameters: [CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                                   CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)],
                      relativeTime: time)
    }

    private func hum(_ time: TimeInterval, _ duration: TimeInterval,
                     _ intensity: Float, _ sharpness: Float) -> CHHapticEvent {
        CHHapticEvent(eventType: .hapticContinuous,
                      parameters: [CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                                   CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)],
                      relativeTime: time,
                      duration: duration)
    }

    /// An intensity envelope. Points are (time from `start`, multiplier 0...1).
    private func ramp(_ start: TimeInterval, _ points: [(TimeInterval, Float)]) -> CHHapticParameterCurve {
        CHHapticParameterCurve(
            parameterID: .hapticIntensityControl,
            controlPoints: points.map { CHHapticParameterCurve.ControlPoint(relativeTime: $0.0, value: $0.1) },
            relativeTime: start)
    }
}
