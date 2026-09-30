//
//  StormSky.swift
//  SpeakLife
//
//  The storm arm's living background. The sky is the progress bar: it opens as a storm (clouds, rain, lightning) and
//  clears screen by screen toward dawn. The big break comes right after the
//  first declaration is spoken, and while she holds to speak the rain and
//  lightning die away under her words, the way the wind died at Mark 4:39.
//
//  Everything is drawn in SwiftUI, no assets. Reduce Motion gets the same sky
//  held still: clouds and dawn, no falling rain, no flashes.
//

import SwiftUI

struct StormSky: View, Animatable {
    /// 0 is full storm, 1 is clear dawn.
    var clearing: Double
    /// 0 is the storm as `clearing` leaves it; 1 silences rain and lightning.
    var stillness: Double

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(clearing, stillness) }
        set { clearing = newValue.first; stillness = newValue.second }
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// How much weather is left: rain density and lightning strength.
    private var weather: Double { max(0, 1 - clearing) * max(0, 1 - stillness) }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { context in
            let t = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            ZStack {
                base
                dawn
                clouds(t: t)
                if !reduceMotion && weather > 0.01 {
                    rain(t: t)
                    lightning(t: t)
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    // MARK: Layers

    /// Storm slate underneath, the brand navy fading in over it as it clears.
    private var base: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "#0A0F1F"), Color(hex: "#151C33")],
                           startPoint: .top, endPoint: .bottom)
            LinearGradient(colors: [StormStyle.navy, StormStyle.navyDeep],
                           startPoint: .top, endPoint: .bottom)
                .opacity(clearing)
        }
    }

    /// A low sun rising behind the buttons. Kept warm but faint so white text
    /// and the gold button keep their contrast.
    private var dawn: some View {
        GeometryReader { geo in
            RadialGradient(
                colors: [StormStyle.gold.opacity(0.42), Color(hex: "#E8764A").opacity(0.18), .clear],
                center: UnitPoint(x: 0.5, y: 1.12 - 0.12 * clearing),
                startRadius: 8,
                endRadius: geo.size.height * (0.35 + 0.35 * clearing)
            )
            .opacity(clearing)
        }
    }

    /// Heavy cloud banks along the top that drift, then thin out and lift.
    private func clouds(t: Double) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let lift = clearing * 120
            ZStack {
                ForEach(0..<5, id: \.self) { i in
                    let d = Double(i)
                    Ellipse()
                        .fill(Color(hex: i.isMultiple(of: 2) ? "#2A3350" : "#1E2640"))
                        .frame(width: w * (0.9 + 0.12 * d), height: 150 + 22 * d)
                        .blur(radius: 34)
                        .offset(
                            x: CGFloat(sin(t * (0.05 + 0.012 * d) + d * 1.7)) * 46 + CGFloat(d - 2) * w * 0.22,
                            y: CGFloat(-40 + 26 * d) - lift
                        )
                }
            }
            .frame(width: w, height: geo.size.height, alignment: .top)
            .opacity(0.95 * (1 - clearing))
        }
    }

    /// Slanted streaks. Each drop's lane, speed and phase come from its index,
    /// so the rain is stable frame to frame with no stored state.
    private func rain(t: Double) -> some View {
        Canvas { ctx, size in
            let drops = Int(110 * weather)
            guard drops > 0 else { return }
            for i in 0..<drops {
                let seed = Double(i)
                let lane = fract(sin(seed * 12.9898) * 43758.5453)
                let speed = 520 + 260 * fract(sin(seed * 78.233) * 12345.678)
                let phase = fract(sin(seed * 3.17) * 9_871.31)
                let length = 14 + 16 * phase
                let span = Double(size.height) + 60
                let y = (phase * span + t * speed).truncatingRemainder(dividingBy: span) - 30
                let x = lane * Double(size.width + 60) - 30 - y * 0.12
                var path = Path()
                path.move(to: CGPoint(x: x, y: y))
                path.addLine(to: CGPoint(x: x - length * 0.12, y: y + length))
                ctx.stroke(path, with: .color(.white.opacity(0.10 + 0.10 * phase)), lineWidth: 1)
            }
        }
        .opacity(min(1, weather * 1.4))
    }

    /// A double flicker every ~7s, strongest at the top of the sky.
    private func lightning(t: Double) -> some View {
        let cycle = t.truncatingRemainder(dividingBy: 7.3)
        let flash: Double
        switch cycle {
        case 0..<0.07:     flash = 1
        case 0.07..<0.16:  flash = 0.25
        case 0.16..<0.22:  flash = 0.7
        case 0.22..<0.5:   flash = 0.7 * (1 - (cycle - 0.22) / 0.28)
        default:           flash = 0
        }
        return LinearGradient(colors: [Color.white.opacity(0.22), .clear],
                              startPoint: .top, endPoint: .center)
            .opacity(flash * weather)
    }

    private func fract(_ x: Double) -> Double { x - x.rounded(.down) }
}

extension StormStep {
    /// How far the sky has cleared on this screen. Heavy storm through the
    /// questions, then the break the moment the first declaration is spoken.
    var skyClearing: Double {
        switch self {
        case .welcome:     return 0
        case .storm:       return 0.04
        case .posture:     return 0.08
        case .mechanism:   return 0.12
        case .speak:       return 0.16
        case .feeling:     return 0.55
        case .promise:     return 0.65
        case .morningTime: return 0.74
        case .reminder:    return 0.82
        case .plan:        return 0.9
        case .rating:      return 0.95
        case .paywall:     return 1
        }
    }
}

#if DEBUG
#Preview("Storm") { StormSky(clearing: 0, stillness: 0) }
#Preview("Breaking") { StormSky(clearing: 0.55, stillness: 1) }
#Preview("Dawn") { StormSky(clearing: 0.9, stillness: 1) }
#endif
