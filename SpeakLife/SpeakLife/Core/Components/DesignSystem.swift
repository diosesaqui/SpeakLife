//
//  DesignSystem.swift
//  SpeakLife
//
//  A small, additive design-token foundation + matched multisensory "juice".
//
//  Goal: give the app one source of truth for spacing, shape, depth, motion,
//  color and type, plus a single place where a tap's *feel* (haptic + motion)
//  is defined together so feedback always lands in harmony.
//
//  This file is intentionally isolated. It introduces new tokens and helpers
//  without modifying any existing view, so adopting it is opt-in, screen by
//  screen. Existing code keeps using `Constants`; new and refreshed surfaces
//  can move to `DS`.
//

import SwiftUI
import UIKit

// MARK: - Design Tokens

/// `DS` is the namespace for SpeakLife's design tokens. Reach for these instead
/// of hard-coded numbers so spacing, radius, depth and motion stay consistent
/// as the app grows.
enum DS {

    // MARK: Spacing — an 8pt rhythm

    /// Spacing scale. Use these for padding, stack spacing and insets so the
    /// whole app breathes on the same grid.
    enum Spacing {
        /// 4pt — hairline gaps between tightly related elements.
        static let xxs: CGFloat = 4
        /// 8pt — default gap between related elements.
        static let xs: CGFloat = 8
        /// 12pt — comfortable inner padding.
        static let sm: CGFloat = 12
        /// 16pt — standard content padding.
        static let md: CGFloat = 16
        /// 24pt — separation between distinct groups.
        static let lg: CGFloat = 24
        /// 32pt — section spacing.
        static let xl: CGFloat = 32
        /// 48pt — large, intentional breathing room.
        static let xxl: CGFloat = 48
    }

    // MARK: Radius

    /// Corner-radius scale.
    enum Radius {
        static let sm: CGFloat = 10
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        /// Fully rounded — for pills and circular controls.
        static let pill: CGFloat = 999
    }

    // MARK: Elevation — depth through soft shadow

    enum Elevation {
        /// A shadow token: pre-tuned so depth reads consistently everywhere.
        struct Shadow {
            let color: Color
            let radius: CGFloat
            let x: CGFloat
            let y: CGFloat
        }

        /// Resting cards and tiles.
        static let low = Shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 3)
        /// Raised surfaces and sheets.
        static let medium = Shadow(color: .black.opacity(0.18), radius: 18, x: 0, y: 8)
        /// Focused / pressed-forward elements and modals.
        static let high = Shadow(color: .black.opacity(0.24), radius: 30, x: 0, y: 14)
    }

    // MARK: Motion — named springs so animation feels like one hand

    /// Motion tokens. Naming the curves keeps timing coherent: the same gesture
    /// always moves with the same personality across the app.
    enum Motion {
        /// Snappy response for taps and toggles.
        static let quick = Animation.spring(response: 0.30, dampingFraction: 0.72, blendDuration: 0)
        /// Smooth, settled transitions between states.
        static let smooth = Animation.spring(response: 0.45, dampingFraction: 0.85, blendDuration: 0)
        /// Playful overshoot for celebratory moments.
        static let bouncy = Animation.spring(response: 0.40, dampingFraction: 0.55, blendDuration: 0)
        /// Slow, calming motion for prayer / meditation surfaces.
        static let gentle = Animation.easeInOut(duration: 0.8)
    }

    // MARK: Palette — semantic colors layered over the existing brand colors

    /// Semantic color roles. These alias the established brand colors in
    /// `Constants` so callers describe *intent* ("accent", "onAccent") rather
    /// than a specific RGB value, and a future re-theme touches one place.
    enum Palette {
        /// Primary interactive accent.
        static let accent = Constants.navBlue
        /// Deep brand background.
        static let deepBlue = Constants.SLBlue
        /// Reward / streak / premium highlight.
        static let gold = Constants.gold
        /// Affirmative state (success, completion).
        static let affirm = Constants.specialRateColor

        /// Primary text on dark brand surfaces.
        static let textPrimary = Color.white
        /// Secondary / supporting text on dark surfaces.
        static let textSecondary = Color.white.opacity(0.72)

        /// Translucent surface for cards over imagery.
        static let surface = Color.white.opacity(0.10)
        /// Hairline stroke for separating translucent surfaces.
        static let hairline = Color.white.opacity(0.16)
    }

    // MARK: Typography

    /// Type ramp. Built on the app's display face with a system fallback for
    /// numerals and body copy.
    enum Typography {
        static let display = Font.custom("AppleSDGothicNeo-Regular", size: 34)
        static let title = Font.custom("AppleSDGothicNeo-Regular", size: 26)
        static let headline = Font.system(size: 20, weight: .semibold, design: .rounded)
        static let body = Font.system(size: 17, weight: .regular)
        static let callout = Font.system(size: 15, weight: .medium)
        static let caption = Font.system(size: 13, weight: .regular)
    }
}

// MARK: - Juice: matched haptic + motion

/// `Juice` is the single place that defines how an interaction *feels*. Each
/// `Feel` pairs a haptic with a recommended motion token so visual and tactile
/// feedback are designed together rather than drifting apart over time.
///
/// Haptics route through `PremiumHaptics`, which already respects the user's
/// "haptics enabled" setting, so this stays a good citizen of existing prefs.
enum Juice {

    /// A catalogue of interaction "feels" used across the core loop.
    enum Feel {
        /// A light, incidental tap (selection, minor toggle).
        case tapLight
        /// A solid, deliberate tap (primary button, card open).
        case tapSolid
        /// Adding something to favorites — a warm heartbeat.
        case favorite
        /// Removing a favorite — a soft, quiet acknowledgement.
        case unfavorite
        /// A task or affirmation completed.
        case success
        /// A milestone worth celebrating (streaks, goals).
        case celebrate
        /// A gentle "not yet / try again" — a soft warning, never punishing.
        case warning

        /// The motion token that visually matches this feel. Pair it with the
        /// animation driving the same interaction so they move as one.
        var motion: Animation {
            switch self {
            case .tapLight, .unfavorite:
                return DS.Motion.quick
            case .tapSolid, .favorite:
                return DS.Motion.smooth
            case .success:
                return DS.Motion.smooth
            case .celebrate:
                return DS.Motion.bouncy
            case .warning:
                return DS.Motion.quick
            }
        }
    }

    /// Fire the haptic for a given feel. Call this at the moment of the
    /// interaction, and drive the accompanying visual change with `feel.motion`.
    static func play(_ feel: Feel) {
        switch feel {
        case .tapLight:
            PremiumHaptics.safeLight()
        case .tapSolid:
            PremiumHaptics.safeMedium()
        case .favorite:
            PremiumHaptics.safeHeartbeat()
        case .unfavorite:
            PremiumHaptics.safeLight()
        case .success:
            PremiumHaptics.safeSuccessSequence()
        case .celebrate:
            PremiumHaptics.safeCelebrationBurst()
        case .warning:
            PremiumHaptics.safeWarning()
        }
    }
}

// MARK: - View conveniences

extension View {

    /// Apply a design-system elevation shadow.
    func dsShadow(_ shadow: DS.Elevation.Shadow) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }

    /// Wrap content in a standard translucent card: padded, rounded, softly
    /// stroked and elevated. The default building block for content tiles.
    func dsCard(
        padding: CGFloat = DS.Spacing.md,
        radius: CGFloat = DS.Radius.md,
        elevation: DS.Elevation.Shadow = DS.Elevation.low
    ) -> some View {
        self
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(DS.Palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(DS.Palette.hairline, lineWidth: 1)
            )
            .dsShadow(elevation)
    }

    /// Frosted-glass surface: a translucent material panel with a soft top-lit
    /// hairline and continuous-corner clipping. The signature "bolder" surface —
    /// content floats above the themed backdrop with real depth.
    func dsGlass(
        cornerRadius: CGFloat = DS.Radius.lg,
        strokeOpacity: Double = 0.18,
        elevation: DS.Elevation.Shadow = DS.Elevation.medium
    ) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(strokeOpacity), Color.white.opacity(strokeOpacity * 0.3)],
                            startPoint: .top, endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .dsShadow(elevation)
    }
}

// MARK: - Gradients (the "bolder" accent surfaces)

extension DS {
    /// Brand gradients for hero surfaces, accents, and reward moments. Built on
    /// the existing brand colors so they read as SpeakLife, just richer.
    enum Gradient {
        /// Warm reward gradient for streaks, milestones, premium highlights.
        static let gold = LinearGradient(
            colors: [Color(hex: "#FFD76A"), DS.Palette.gold, Color(hex: "#E09600")],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        /// Fiery streak gradient.
        static let ember = LinearGradient(
            colors: [Color(hex: "#FF9D2E"), Color(hex: "#FF3D2E")],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        /// Deep brand gradient for primary surfaces and CTAs.
        static let brand = LinearGradient(
            colors: [DS.Palette.accent, DS.Palette.deepBlue],
            startPoint: .top, endPoint: .bottom
        )
        /// Subtle top-to-bottom darkening wash to seat content over imagery.
        static let scrim = LinearGradient(
            colors: [Color.black.opacity(0.0), Color.black.opacity(0.35)],
            startPoint: .top, endPoint: .bottom
        )
    }
}

/// A button style that gives every press the same well-tuned feel: a subtle
/// scale-down on press driven by the design-system motion, plus a matched
/// haptic fired the instant the finger lands. Use it for primary controls so
/// "tappable" feels identical app-wide.
struct DSPressable: ButtonStyle {
    /// The interaction feel this button should express. Defaults to a solid tap.
    var feel: Juice.Feel = .tapSolid
    /// How far the button scales down while pressed.
    var pressedScale: CGFloat = 0.96
    /// When `false`, the style provides only the visual press feedback and
    /// leaves the haptic to the caller. Use this for controls whose action
    /// handler already fires a semantically richer haptic (e.g. favorite vs.
    /// unfavorite) so the buzz isn't doubled.
    var haptics: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(feel.motion, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed && haptics {
                    Juice.play(feel)
                }
            }
    }
}

extension ButtonStyle where Self == DSPressable {
    /// Shorthand: `.buttonStyle(.dsPressable())`.
    static func dsPressable(
        feel: Juice.Feel = .tapSolid,
        pressedScale: CGFloat = 0.96,
        haptics: Bool = true
    ) -> DSPressable {
        DSPressable(feel: feel, pressedScale: pressedScale, haptics: haptics)
    }
}

// MARK: - DSProgressRing: a hero progress indicator

/// A gradient progress ring with a count in the center, animated on appear and
/// whenever progress changes. The "look here" focal point for habit/streak
/// surfaces. Defaults to the gold reward gradient.
struct DSProgressRing: View {
    let completed: Int
    let total: Int
    var size: CGFloat = 72
    var lineWidth: CGFloat = 9
    var gradient: LinearGradient = DS.Gradient.gold
    var glow: Color = DS.Palette.gold

    @State private var animatedProgress: CGFloat = 0

    private var progress: CGFloat {
        guard total > 0 else { return 0 }
        return min(1, CGFloat(completed) / CGFloat(total))
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.14), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: glow.opacity(0.5), radius: 6)
            VStack(spacing: 0) {
                Text("\(completed)")
                    .font(.system(size: size * 0.34, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("of \(total)")
                    .font(.system(size: size * 0.16, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(DS.Motion.smooth.delay(0.15)) { animatedProgress = progress }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(DS.Motion.smooth) { animatedProgress = newValue }
        }
    }
}

<<<<<<< HEAD
// MARK: - DSAppear: a safe, reusable entrance animation

/// Fades and lifts content into place on first appearance. Layout-safe — it
/// only animates `opacity` and a small `offset`, never the view's footprint —
/// so it can't cause truncation or reflow. Stagger sibling elements with an
/// increasing `delay` for a premium cascade.
struct DSAppear: ViewModifier {
    var delay: Double = 0
    var rise: CGFloat = 12
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : rise)
            .onAppear {
                withAnimation(DS.Motion.smooth.delay(delay)) { shown = true }
            }
    }
}

extension View {
    /// Fade + lift entrance. `delay` staggers a cascade across siblings.
    func dsAppear(_ delay: Double = 0, rise: CGFloat = 12) -> some View {
        modifier(DSAppear(delay: delay, rise: rise))
    }

    /// Apply a semantic type style from `DS.Typography`. Keeps callers
    /// describing intent ("headline") rather than a raw size/weight, so the
    /// ramp stays consistent and a future re-scale touches one place.
    func dsType(_ font: Font) -> some View {
        self.font(font)
    }
}

=======
>>>>>>> origin/main
// MARK: - Demo / Preview

/// A self-contained demo of the design system applied to a declaration card,
/// including a favorite control wired with matched haptic + motion. This exists
/// to make the slice reviewable in Xcode without touching any live screen.
private struct DesignSystemDemoCard: View {
    @State private var isFavorite = false

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("DECLARATION")
                .font(DS.Typography.caption)
                .tracking(2)
                .foregroundColor(DS.Palette.textSecondary)

            Text("I am rooted in God's love. Nothing can shake what He has sealed in me.")
                .font(DS.Typography.headline)
                .foregroundColor(DS.Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: DS.Spacing.md) {
                Button {
                    isFavorite.toggle()
                    Juice.play(isFavorite ? .favorite : .unfavorite)
                } label: {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(isFavorite ? DS.Palette.gold : DS.Palette.textSecondary)
                        .scaleEffect(isFavorite ? 1.15 : 1.0)
                        .animation(Juice.Feel.favorite.motion, value: isFavorite)
                }
                .buttonStyle(.dsPressable(feel: .tapLight))

                Spacer()

                Button("Amen") {
                    Juice.play(.success)
                }
                .font(DS.Typography.callout)
                .foregroundColor(DS.Palette.deepBlue)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.xs)
                .background(
                    Capsule().fill(DS.Palette.gold)
                )
                .buttonStyle(.dsPressable(feel: .success))
            }
        }
        .dsCard(padding: DS.Spacing.lg, radius: DS.Radius.lg, elevation: DS.Elevation.medium)
        .padding(DS.Spacing.lg)
        .background(DS.Palette.deepBlue.ignoresSafeArea())
    }
}

#Preview {
    DesignSystemDemoCard()
}
