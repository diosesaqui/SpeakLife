//
//  DailyDeclarationBurstView.swift
//  SpeakLife
//
//  Daily burst feature for morning declarations - Enhanced Version
//

import SwiftUI

/// Which door the burst was opened through.
///
/// A campaign owns its own daily task and nothing else. The seven lines on that
/// task are the campaign's material for that day, and swapping them for whatever
/// category the user happens to be browsing would break the week it is building.
/// A burst the user opens for themselves is not that task, so it follows the
/// category they picked.
enum BurstSource: String {
    /// The Daily Burst row on the Today checklist — the campaign's own task.
    case dailyTask = "daily_task"
    /// The "Burst" tile in Jump Back In, or any other user-initiated opening.
    case quickAction = "quick_action"
}

struct DailyDeclarationBurstView: View {

    /// Defaults to the campaign's task, so any entry point that does not say
    /// otherwise keeps the behaviour it had before this existed.
    var source: BurstSource = .dailyTask
    @EnvironmentObject var viewModel: DeclarationViewModel
    @EnvironmentObject var themeViewModel: ThemeViewModel
    @EnvironmentObject var timerViewModel: TimerViewModel
    @EnvironmentObject var streakViewModel: EnhancedStreakViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    /// Honoured the way `LandingView` already honours it. The burst is the
    /// heaviest screen in the app — `SpeakingPowerEffect` alone runs seven
    /// `repeatForever` animations across roughly thirty layers — and someone who
    /// has asked the system for less movement should not be handed all of it.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @StateObject private var burstTracker = BurstCompletionTracker.shared
    @State private var currentDeclarationIndex = 0
    @State private var showCompletionView = false
    @State private var startTime = Date()
    /// True once the intro has been dismissed and there is a line on screen to
    /// speak. Gates the ambient power effect, which should not run over the
    /// intro, the action slat, or the completion screen.
    @State private var burstActive = false
    /// How many of the seven were held all the way to a surge. Reported with the
    /// completion so the new interaction can be measured, not guessed at.
    @State private var surgeCount = 0
    @State private var isTransitioning = false
    @State private var showSpiritualGraph = false
    /// The composed burst: the lines, where they came from, and the theme.
    /// Nil until `BurstSessionBuilder` has run, which is also the loading state.
    ///
    /// One value rather than several parallel `@State`s, so the declarations and
    /// the theme cannot drift apart. The theme in particular was previously
    /// re-derived at the end of the burst by asking `EnforcementService` a second
    /// time, which could answer differently than the composition did.
    @State private var session: BurstSession?
    @State private var showIntroScreen = true
    @State private var introPulse: CGFloat = 1

    // The eighth slat: one corresponding action, mapped to the theme the seven
    // declarations were actually about.
    @State private var showActionSlide = false
    @State private var faithAction: FaithAction?
    /// This session's yes, not today's. Multiple bursts a day are supported, so
    /// reading the store here would checkmark an earlier burst's commitment on a
    /// screen where the user just tapped "Not today".
    @State private var committedAction: FaithAction?

    private var morningDeclarations: [BurstDeclaration] { session?.declarations ?? [] }
    private var burstTheme: DeclarationCategory { session?.theme ?? .faith }
    
    // Animation states for completion screen
    @State private var checkmarkScale: CGFloat = 0.0
    @State private var checkmarkRotation: Double = 0.0
    @State private var starOpacity: Double = 0.0
    @State private var confettiOpacity: Double = 0.0
    @State private var statsScale: CGFloat = 0.0
    @State private var shareButtonOpacity: Double = 0.0
    
    // Configuration for burst session
    private let burstDeclarationCount = 7
    private let favoriteWeight = 2  // Favorites appear 3x more likely
    private let customWeight = 3    // Custom declarations 2x more likely
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Solid base — prevents the underlying view from bleeding through
                // on iPad where fullScreenCover presentations can be transparent.
                Color.black.ignoresSafeArea()

                themeBackground
                
                if showIntroScreen {
                    introScreenView(geometry: geometry)
                } else if showActionSlide, let action = faithAction {
                    BurstFaithActionView(
                        theme: burstTheme,
                        action: action,
                        onCommit: { commitToAction(action) },
                        onSkip: { skipAction(action) }
                    )
                } else if !showCompletionView {
                    // Power-release effect: active while declaration is fully visible
                    // and the user is actively speaking it (not mid-transition)
                    // The message still shows; the ray/ring/particle field does
                    // not. That keeps the meaning and drops the motion.
                    if !reduceMotion {
                        SpeakingPowerEffect(
                            isActive: burstActive && !isTransitioning,
                            message: "God's power flows when you speak"
                        )
                    }

                    burstContentView(geometry: geometry)
                } else {
                    completionView(geometry: geometry)
                }
            }
            .ignoresSafeArea()
        }
        .preferredColorScheme(.dark)
        .onAppear {
            loadDynamicDeclarations()
        }
        .fullScreenCover(isPresented: $streakViewModel.showBadgeUnlock) {
            if let badge = streakViewModel.badgeManager.recentlyUnlocked {
                BadgeUnlockView(badge: badge, isPresented: $streakViewModel.showBadgeUnlock)
                    .onDisappear { streakViewModel.dismissBadgeUnlock() }
            }
        }
    }
    
    /// The theme the user actually chose, matching the declaration feed and the
    /// checklist this screen is opened from.
    ///
    /// This previously drew `subscriptionStore.onboardingBGImage`, which is the
    /// onboarding backdrop: a fixed image that never changes when someone picks a
    /// new theme, so the burst was the one screen that ignored the theme chooser.
    /// `ThemeViewModel` is an `ObservableObject` injected at both presentation
    /// sites, and `selectedTheme` is `@Published`, so reading it here means a
    /// theme chosen while the burst is open repaints it live.
    ///
    /// The scrim is the checklist's, not the feed's. The burst lays white serif
    /// text and gold accents straight over the image with no card behind them on
    /// the intro, action and completion screens, so a light theme would wash them
    /// out; and since the burst is launched from the checklist, sharing its
    /// backdrop keeps the two screens continuous across the cover.
    ///
    /// The `GeometryReader` is the point of this, and it took two tries to get
    /// right. A fill needs a frame to fill *into*, and that frame has to be the
    /// whole screen:
    ///
    ///   · Framing to the enclosing `geometry.size` used the safe-area size, so
    ///     the image was clipped short of the home indicator and the black base
    ///     showed through along the bottom.
    ///   · Removing the frame and the clip altogether fixed the gap and broke the
    ///     scale. `.aspectRatio(contentMode: .fill)` with nothing to fill into
    ///     reports a size larger than what it was offered, the ZStack grows to
    ///     that, and the image renders blown far past its natural size.
    ///
    /// `.ignoresSafeArea()` sits on the `GeometryReader` itself, so `proxy.size`
    /// is the real screen including both safe areas. Filling that and clipping to
    /// it gives an image at the right scale that still reaches every edge.
    private var themeBackground: some View {
        GeometryReader { proxy in
            ZStack {
                themeImage
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()

                LinearGradient(
                    colors: [Color.black.opacity(0.45), Color.black.opacity(0.65)],
                    startPoint: .top, endPoint: .bottom
                )
            }
        }
        .ignoresSafeArea()
    }

    /// The chosen theme's artwork, or the user's own photo when they have set one.
    ///
    /// Split out so `.resizable().scaledToFill()` is applied inside each branch —
    /// those are `Image` methods, and the branches erase to `some View` — while
    /// the frame and the clip that bound the fill are applied once, outside.
    @ViewBuilder
    private var themeImage: some View {
        if themeViewModel.showUserSelectedImage, let image = themeViewModel.selectedImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            Image(themeViewModel.selectedTheme.backgroundImageString)
                .resizable()
                .scaledToFill()
        }
    }

    // MARK: - Composition

    /// Hands the builder everything it needs and keeps the result.
    ///
    /// The policy — campaign ownership, weighting, dedup, fallback, and the
    /// theme — lives in `BurstSessionBuilder`, where it is testable without a
    /// view. This reads the singletons the builder deliberately does not.
    private func loadDynamicDeclarations() {
        let service = EnforcementService.shared

        // The campaign only owns the burst it is actually responsible for. Opened
        // from Jump Back In this is the user's own burst, so the campaign is left
        // out of the composition entirely and `selected` — the category they
        // chose — is what fills it.
        let campaignOwnsThisBurst = source == .dailyTask && service.isEnabled
        let activeEnforcement = campaignOwnsThisBurst ? service.activeEnforcement : nil

        let composed = BurstSessionBuilder(
            declarationCount: burstDeclarationCount,
            favoriteWeight: favoriteWeight,
            customWeight: customWeight
        ).build(
            enforcement: activeEnforcement,
            currentDay: service.progressSnapshot.currentDay,
            favorites: viewModel.favorites,
            custom: viewModel.createOwn.filter { $0.contentType == .affirmation },
            categoryPool: viewModel.declarations,
            selected: viewModel.selectedCategory,
            // The whole pool, not `viewModel.declarations` — that is the category
            // the user is browsing, which has nothing to do with the campaign they
            // are on. A campaign fills its six non-anchor slots from its own theme.
            fullPool: viewModel.allAvailableDeclarations
        )
        session = composed

        switch composed.origin {
        case .enforcement:
            print("📱 Daily Burst: speaking \(activeEnforcement?.title ?? ""), day \(service.progressSnapshot.currentDay)")
        case .pool, .fallback:
            print("📱 Daily Burst: \(composed.declarations.count) declarations, theme \(composed.theme.rawValue)")
        }
    }

    // MARK: - Intro Screen View
    
    private func introScreenView(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            // Close button
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.white.opacity(0.6))
                }
                .buttonStyle(.dsPressable(feel: .tapSolid))
                .padding(.leading, 20)
                .padding(.top, 60)
                Spacer()
            }
            
            Spacer()
            
            // Content
            VStack(spacing: 40) {
                // Icon with animated glow
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 1.0, green: 0.58, blue: 0.0).opacity(0.3), Color(red: 1.0, green: 0.34, blue: 0.13).opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                        .blur(radius: 20)
                        .scaleEffect(introPulse)

                    Circle()
                        .fill(DS.Gradient.ember)
                        .frame(width: 100, height: 100)
                        .shadow(color: Color(red: 1.0, green: 0.34, blue: 0.13).opacity(0.5), radius: 8, x: 0, y: 4)
                        .scaleEffect(2 - introPulse)

                    Image(systemName: "bolt.fill")
                        .font(.system(size: 50, weight: .bold))
                        .foregroundColor(.white)
                }
                .onAppear {
                    // The icon breathes rather than sits. A still hero on a screen
                    // whose whole promise is release reads as a screenshot.
                    guard !reduceMotion else { return }
                    withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                        introPulse = 1.12
                    }
                }
                
                VStack(spacing: DS.Spacing.md) {
                    Text("Daily Victory Burst")
                        .font(DS.Typography.title)
                        .foregroundColor(.white)

                    Text("Seven declarations out loud. This is how you release your faith.")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)

                    // Nobody expects the lift to be what advances, so it gets
                    // named here rather than discovered on the first line.
                    HStack(spacing: DS.Spacing.md) {
                        introHint(icon: "hand.tap.fill", text: "Hold to speak")
                        introHint(icon: "hand.raised.fill", text: "Let go when done")
                    }
                    .padding(.top, DS.Spacing.xs)
                }
            }
            .dsAppear(0)

            Spacer()

            // CTA Button
            Button(action: {
                // Haptic feedback
                Juice.play(.tapSolid)

                withAnimation(.easeInOut(duration: 0.5)) {
                    showIntroScreen = false
                }
                startBurst()
            }) {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 20, weight: .bold))
                    Text("Start Daily Burst")
                        .font(.system(size: 18, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(width: geometry.size.width * 0.85, height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 28)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 1.0, green: 0.58, blue: 0.0), Color(red: 1.0, green: 0.34, blue: 0.13)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
            }
            .buttonStyle(.dsPressable(feel: .tapSolid, haptics: false))
            .padding(.bottom, 60)
            .dsAppear(0.12)
        }
    }

    private func introHint(icon: String, text: String) -> some View {
        HStack(spacing: DS.Spacing.xxs) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
            Text(text)
                .font(.system(size: 14, weight: .medium))
        }
        .foregroundColor(.white.opacity(0.85))
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xs)
        .background(Capsule().fill(Color.white.opacity(0.12)))
    }

    // MARK: - Burst Content View

    /// The speaking screen is `BurstDeclarationStage`: a card deck and a button
    /// that charges while the user holds it and speaks. This view
    /// keeps only the loading state and the session-level bookkeeping, so the
    /// interaction lives in one file that can be reasoned about on its own.
    private func burstContentView(geometry: GeometryProxy) -> some View {
        Group {
            if session == nil {
                VStack(spacing: 20) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)

                    Text("Preparing your personalized declarations...")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                BurstDeclarationStage(
                    declarations: morningDeclarations,
                    index: $currentDeclarationIndex,
                    isTransitioning: $isTransitioning,
                    size: geometry.size,
                    onAdvance: recordAdvance,
                    onFinish: finishBurst,
                    onClose: { dismiss() }
                )
            }
        }
    }

    // MARK: - Completion View
    
    private func completionView(geometry: GeometryProxy) -> some View {
        ZStack {
            // Animated background particles
            ForEach(0..<(reduceMotion ? 0 : 20), id: \.self) { index in
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.yellow.opacity(0.6), Color.orange.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: CGFloat.random(in: 2...6))
                    .position(
                        x: CGFloat.random(in: 0...geometry.size.width),
                        y: CGFloat.random(in: 0...geometry.size.height)
                    )
                    .opacity(confettiOpacity)
                    .animation(
                        Animation.easeInOut(duration: 2)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.1),
                        value: confettiOpacity
                    )
            }
            
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 30) {
                    // Success Animation with multiple layers
                    ZStack {
                        // Outer pulsing ring
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [Color.yellow.opacity(0.3), Color.orange.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                            .frame(width: 160, height: 160)
                            .scaleEffect(checkmarkScale * 1.3)
                            .opacity(starOpacity)
                        
                        // Middle glow
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [Color.orange.opacity(0.5), Color.clear],
                                    center: .center,
                                    startRadius: 5,
                                    endRadius: 60
                                )
                            )
                            .frame(width: 140, height: 140)
                            .scaleEffect(checkmarkScale * 1.1)
                            .blur(radius: 10)
                        
                        // The seven declarations, closed into a ring.
                        //
                        // This was eight generic stars, which could have been any
                        // app's celebration. These are the same segments as the
                        // progress rail, one per line actually spoken, brought up
                        // from the bottom of the burst and set around the mark.
                        // The reward is made of the work rather than dropped on
                        // top of it.
                        ForEach(0..<max(morningDeclarations.count, 1), id: \.self) { index in
                            let count = max(morningDeclarations.count, 1)
                            let angle = (Double(index) / Double(count)) * 2 * .pi - .pi / 2

                            Capsule()
                                .fill(DS.Gradient.gold)
                                .frame(width: 5, height: 18)
                                .shadow(color: DS.Palette.gold.opacity(0.7), radius: 5)
                                .offset(
                                    x: cos(angle) * 78,
                                    y: sin(angle) * 78
                                )
                                // Each segment stands on end, pointing out from the
                                // mark like rays rather than lying flat.
                                .rotationEffect(.degrees(angle * 180 / .pi + 90))
                                .scaleEffect(starOpacity)
                                .opacity(starOpacity)
                        }
                        
                        // Main checkmark with gradient
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(red: 1.0, green: 0.8, blue: 0.2), Color(red: 1.0, green: 0.6, blue: 0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 100, height: 100)
                                .scaleEffect(checkmarkScale)
                                .shadow(color: .orange, radius: 20, x: 0, y: 5)
                            
                            Image(systemName: "checkmark")
                                .font(.system(size: 50, weight: .bold))
                                .foregroundColor(.white)
                                .scaleEffect(checkmarkScale)
                                .rotationEffect(.degrees(checkmarkRotation))
                        }
                    }
                    
                    // Dynamic title with gradient
                    Text(getVictoryMessage())
                        .font(.system(size: 34, weight: .black))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, Color(red: 1.0, green: 0.9, blue: 0.7)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .scaleEffect(checkmarkScale)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 2)
                    
                    VStack(spacing: 20) {
                        Text(getMotivationalMessage())
                            .font(.system(size: 19, weight: .medium))
                            .foregroundColor(.white.opacity(0.95))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                            .scaleEffect(statsScale)
                        
                        // Streak only — the one stat that actually matters
                        StatCard(
                            count: streakViewModel.displayStreak,
                            label: "Day Streak",
                            icon: "flame.fill",
                            scale: statsScale,
                            highlight: streakViewModel.displayStreak >= 7
                        )
                        .padding(.top, 8)
                        
                        // What they said yes to on the eighth slat. Shown so the
                        // commitment survives the celebration instead of being
                        // buried under it.
                        if let committedAction {
                            HStack(spacing: DS.Spacing.xs) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(DS.Palette.gold)

                                Text(committedAction.headline)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.9))
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.horizontal, DS.Spacing.md)
                            .padding(.vertical, DS.Spacing.sm)
                            .background(
                                Capsule().fill(Color.white.opacity(0.10))
                            )
                            .opacity(starOpacity)
                        }

                        // Milestone callout
                        if streakViewModel.displayStreak % 7 == 0 && streakViewModel.displayStreak > 0 {
                            Text("🎉 \(streakViewModel.displayStreak / 7) WEEK\(streakViewModel.displayStreak == 7 ? "" : "S") STRONG!")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.yellow)
                                .opacity(starOpacity)
                        }
                    }
                    .padding(.horizontal, 30)
                }
                
                Spacer()
                
                VStack(spacing: DS.Spacing.md) {
                    // Share Victory Button
                    Button(action: shareVictory) {
                        HStack(spacing: 10) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 17, weight: .semibold))
                            Text("Share Your Victory")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(width: geometry.size.width * 0.85, height: 50)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 25)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.purple.opacity(0.8), Color.blue.opacity(0.8)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                
                                RoundedRectangle(cornerRadius: 25)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            }
                        )
                        .shadow(color: .purple.opacity(0.3), radius: 10, x: 0, y: 5)
                    }
                    .scaleEffect(shareButtonOpacity)
                    .opacity(shareButtonOpacity)
                    
                    HStack(spacing: DS.Spacing.sm) {
                        Button(action: { showSpiritualGraph = true }) {
                            HStack {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .font(.system(size: 16))
                                Text("Growth")
                                    .font(.system(size: 15, weight: .medium))
                            }
                            .foregroundColor(Color(red: 0.9, green: 0.7, blue: 0.3))
                            .frame(width: geometry.size.width * 0.4, height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 22)
                                    .stroke(Color(red: 0.9, green: 0.7, blue: 0.3), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.dsPressable(feel: .tapSolid))

                        Button(action: completeBurst) {
                            Text("Continue")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: geometry.size.width * 0.4, height: 44)
                                .background(
                                    RoundedRectangle(cornerRadius: 22)
                                        .fill(
                                            LinearGradient(
                                                colors: [Color(red: 1.0, green: 0.58, blue: 0.0), Color(red: 1.0, green: 0.34, blue: 0.13)],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                )
                                .shadow(color: .orange.opacity(0.3), radius: 10, x: 0, y: 5)
                        }
                        .buttonStyle(.dsPressable(feel: .tapLight, haptics: false))
                    }
                }
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            triggerCompletionAnimations()
        }
        .sheet(isPresented: $showSpiritualGraph) {
            SpiritualStrengthGraph(tracker: burstTracker)
        }
    }
    
    // MARK: - Completion Helper Views
    
    private struct StatCard: View {
        let count: Int
        let label: String
        let icon: String
        let scale: CGFloat
        var highlight: Bool = false

        /// A slow swell on the badge so the streak keeps breathing while the
        /// screen is read, instead of landing once and going inert.
        @State private var pulse: CGFloat = 1
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(highlight ? DS.Gradient.ember : DS.Gradient.gold)
                        .frame(width: 60, height: 60)
                        .shadow(color: (highlight ? Color(red: 1.0, green: 0.34, blue: 0.13) : DS.Palette.gold).opacity(0.5), radius: 8, x: 0, y: 4)
                        .scaleEffect(pulse)

                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                }
                .onAppear {
                    guard !reduceMotion else { return }
                    withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                        pulse = 1.07
                    }
                }

                // Climbs to the streak rather than arriving at it. The size of
                // the number is the reward, so it gets a moment to be watched.
                CountUpText(value: count)

                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
            .scaleEffect(scale)
            .animation(
                .spring(response: 0.5, dampingFraction: 0.6)
                    .delay(0.1),
                value: scale
            )
        }
    }
    
    // MARK: - Completion Helpers
    
    private func getVictoryMessage() -> String {
        let messages = [
            "Victory Declared! 🔥",
            "Champion Status! 💪",
            "Warrior Mode ON! ⚡",
            "Faith Activated! 🙏",
            "Power Released! 🚀",
            "Kingdom Strength! 👑"
        ]
        
        if streakViewModel.displayStreak >= 30 {
            return "UNSTOPPABLE! 🌟"
        } else if streakViewModel.displayStreak >= 21 {
            return "LEGENDARY! 🏆"
        } else if streakViewModel.displayStreak >= 7 {
            return messages.randomElement() ?? "Victory Declared! 🔥"
        } else {
            return ["Victory Claimed!", "Day Conquered!", "Truth Spoken!"].randomElement() ?? "Victory!"
        }
    }
    
    private func getMotivationalMessage() -> String {
        let messages = [
            "You just armed yourself with heaven's ammunition!",
            "Your spirit is stronger than yesterday!",
            "You're building an unshakeable foundation!",
            "Today's battles are already won!",
            "You've activated divine power for your day!",
            "Your faith just leveled up!",
            "You're walking in supernatural authority!"
        ]
        
        if streakViewModel.displayStreak >= 7 {
            return "You're unstoppable! \(streakViewModel.displayStreak) days of declaring victory!"
        } else {
            return messages.randomElement() ?? "You've aligned your morning with God's truth!"
        }
    }
    
    private func triggerCompletionAnimations() {
        // Trigger haptic feedback
        Juice.play(.success)

        // Cascade animations
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            checkmarkScale = 1.0
        }
        
        // Single rotation animation for the checkmark
        withAnimation(.easeInOut(duration: 1.5)) {
            checkmarkRotation = 360
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                starOpacity = 1.0
                confettiOpacity = 1.0
            }

            // Medium haptic
            Juice.play(.tapSolid)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                statsScale = 1.0
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            // Light haptic
            Juice.play(.tapLight)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                shareButtonOpacity = 1.0
            }
        }
    }
    
    private func shareVictory() {
        // Haptic feedback
        Juice.play(.tapLight)

        let message = "I just completed my Daily Victory Burst on SpeakLife! 🔥\n\n✅ \(morningDeclarations.count) Declarations Spoken\n🔥 \(streakViewModel.displayStreak) Day Streak\n💪 \(burstTracker.currentStrengthScore)% Spiritual Strength\n\nJoin me in speaking life daily!"
        
        // Get the active window scene
        guard let windowScene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }) as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            print("Could not find root view controller for sharing")
            return
        }
        
        // Find the topmost view controller
        var topController = rootViewController
        while let presentedController = topController.presentedViewController {
            topController = presentedController
        }
        
        let activityVC = UIActivityViewController(
            activityItems: [message],
            applicationActivities: nil
        )
        
        // For iPad
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = topController.view
            popover.sourceRect = CGRect(x: topController.view.bounds.midX, y: topController.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        topController.present(activityVC, animated: true)
        
        AnalyticsService.shared.track("daily_burst_shared", parameters: [
            "streak": streakViewModel.displayStreak,
            "strength_score": burstTracker.currentStrengthScore
        ])
    }
    
    // MARK: - Actions
    
    private func startBurst() {
        AnalyticsService.shared.track("daily_burst_started", parameters: [
            "streak": streakViewModel.displayStreak,
            "source": source.rawValue
        ])
        withAnimation(.easeIn(duration: 0.4)) {
            burstActive = true
        }
    }

    /// One line spoken. Recorded per declaration so the hold-to-speak surge can
    /// be compared against a plain tap instead of assumed to be used.
    private func recordAdvance(_ method: BurstAdvanceMethod, at index: Int) {
        if method == .surge { surgeCount += 1 }

        AnalyticsService.shared.track("daily_burst_declaration_spoken", parameters: [
            "method": method.rawValue,
            "position": index + 1,
            "of": morningDeclarations.count
        ])
    }

    /// The seventh line is spoken. Everything that counts is written here, before
    /// the eighth slat is shown, so nothing downstream can cost the user the day.
    private func finishBurst(_ method: BurstAdvanceMethod) {
        Juice.play(.success)
        burstActive = false

        let timeSpent = Date().timeIntervalSince(startTime)
        burstTracker.recordBurstCompletion(
            declarationCount: morningDeclarations.count,
            timeSpent: timeSpent
        )

        // Automatically complete the daily burst task
        streakViewModel.completeTask(taskId: "complete_daily_burst")

        AnalyticsService.shared.track("daily_burst_completed", parameters: [
            "declarations_count": morningDeclarations.count,
            "time_spent": Int(timeSpent),
            "streak": streakViewModel.displayStreak,
            "surges": surgeCount,
            "final_method": method.rawValue,
            "source": source.rawValue
        ])

        presentActionSlide()
    }

    // MARK: - The Eighth Slat

    /// Resolves what this burst was about and asks for one action on it.
    private func presentActionSlide() {
        let theme = burstTheme
        let action = FaithActionCatalog.action(for: theme)
        faithAction = action

        AnalyticsService.shared.track("daily_burst_action_shown", parameters: [
            "theme": theme.rawValue,
            "action": action.headline
        ])

        withAnimation(DS.Motion.smooth) {
            showActionSlide = true
        }
    }

    private func commitToAction(_ action: FaithAction) {
        // Deliberately not `.success` — the completion screen fires that one a beat
        // later, and two success haptics back to back read as a glitch.
        Juice.play(.tapSolid)
        committedAction = action
        FaithActionCommitmentStore.shared.commit(to: action, theme: burstTheme)

        AnalyticsService.shared.track("daily_burst_action_committed", parameters: [
            "theme": burstTheme.rawValue,
            "action": action.headline
        ])

        advanceToCompletion()
    }

    private func skipAction(_ action: FaithAction) {
        Juice.play(.tapLight)

        AnalyticsService.shared.track("daily_burst_action_skipped", parameters: [
            "theme": burstTheme.rawValue,
            "action": action.headline
        ])

        advanceToCompletion()
    }

    private func advanceToCompletion() {
        // The badge popup is wired to ModernDailyChecklistView which isn't visible here.
        // Directly trigger it after a short delay so it appears on the completion screen.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if streakViewModel.badgeManager.recentlyUnlocked != nil, !streakViewModel.showBadgeUnlock {
                streakViewModel.showBadgeUnlock = true
            }
        }

        withAnimation(DS.Motion.smooth) {
            showActionSlide = false
            showCompletionView = true
        }
    }

    private func completeBurst() {
        // Haptic feedback on complete
        Juice.play(.tapLight)

        // The burst view has its own completion UI, so the streak view model's
        // celebration covers were never shown. Reset the flags so they don't
        // leak into the next session or block future badge checks.
        streakViewModel.showFireAnimation = false
        streakViewModel.showCompletionCelebration = false

        dismiss()
    }
}
