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
    /// Opened from a stand room. Speaks the ROOM's campaign, on the speaker's
    /// own day in that room, so an invitee can speak with the person who asked
    /// them without switching the category their home screen is on or the
    /// campaign they are running for themselves.
    case stand = "stand"
}

struct DailyDeclarationBurstView: View {

    /// Defaults to the campaign's task, so any entry point that does not say
    /// otherwise keeps the behaviour it had before this existed.
    var source: BurstSource = .dailyTask
    /// The room's campaign and the day to speak in it. Read only when `source`
    /// is `.stand`.
    var standEnforcement: Enforcement? = nil
    var standDay: Int = 1
    @EnvironmentObject var viewModel: DeclarationViewModel
    @EnvironmentObject var themeViewModel: ThemeViewModel
    @EnvironmentObject var timerViewModel: TimerViewModel
    @EnvironmentObject var streakViewModel: EnhancedStreakViewModel
    /// Read only to decide whether the one-time welcome offer is owed on the
    /// way out. Already injected at both callsites, so nothing had to change
    /// to add it.
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    /// Honoured the way `LandingView` already honours it. The burst is the
    /// heaviest screen in the app — `SpeakingPowerEffect` alone runs seven
    /// `repeatForever` animations across roughly thirty layers — and someone who
    /// has asked the system for less movement should not be handed all of it.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @StateObject private var burstTracker = BurstCompletionTracker.shared
    /// The one path a burst is shared through: every line as a story card.
    /// Both the eighth slat and the completion screen use it, so they share
    /// one in-flight guard.
    @StateObject private var burstShare = BurstShareController()
    /// The finish screen's headline and line, picked once when it appears.
    @State private var victoryTitle = ""
    @State private var motivationLine = ""
    @State private var currentDeclarationIndex = 0
    @State private var showCompletionView = false
    /// Distinct days this user has completed a Burst, read once the completion
    /// is written. Paces the two post-Burst prompts.
    @State private var burstDayCount = 0
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

    /// Declaration or scripture — what the seven slats put in the user's mouth.
    ///
    /// `@AppStorage` rather than `@State`, because this is a preference and not a
    /// session choice: someone who prefers speaking the verse should not have to
    /// re-pick it every morning. Stored as a raw string so the enum can gain a
    /// case without stranding anyone on an unreadable default.
    @AppStorage("burstSpeakMode") private var speakModeRaw = BurstSpeakMode.declaration.rawValue

    /// Reads the stored preference, and writes it back through the same key so
    /// the intro screen and the stage are always looking at one value.
    private var speakMode: Binding<BurstSpeakMode> {
        Binding(
            get: { BurstSpeakMode.from(rawValue: speakModeRaw) },
            set: { speakModeRaw = $0.rawValue }
        )
    }

    /// "Mix in my own": a couple of slots go to favorites or the user's own
    /// declarations. Off by default, so a burst is the selected category or the
    /// campaign and nothing else. A preference rather than a session choice, for
    /// the same reason as the speak mode.
    @AppStorage("burstMixPersonal") private var mixPersonal = false

    private var personalDeclarations: [Declaration] {
        viewModel.createOwn.filter { $0.contentType == .affirmation }
    }

    /// Offered only when there is something to mix in and room to mix it. A
    /// one-line burst has no spare slot.
    private var canMixPersonal: Bool {
        burstDeclarationCount > 1 && !(viewModel.favorites.isEmpty && personalDeclarations.isEmpty)
    }

    /// True when at least one slat carries a verse, so the switch is worth
    /// offering. A burst made entirely of the user's own written declarations has
    /// nothing to switch to.
    private var scriptureAvailable: Bool { session?.scriptureAvailable ?? false }

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
    /// Seven, or one for a storm-arm member on the free layer: that one line
    /// is their declaration for the day.
    private var burstDeclarationCount: Int {
        StormFreeLayer.isActive(subscriptionStore) ? 1 : 7
    }
    
    /// Storm free layer: today's declaration is already spent.
    @State private var showStormFreeLimit = false

    var body: some View {
        burstBody
            .overlay {
                if showStormFreeLimit {
                    // Its close and its paywall both dismiss the Burst.
                    StormFreeLimitView()
                        .transition(.opacity)
                }
            }
    }

    private var burstBody: some View {
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
                        isPreparingShare: burstShare.isPreparing,
                        onSend: {
                            // Sending the promises on is the act of faith, so a
                            // completed send commits it and moves on. A cancel
                            // leaves the user here to send or skip.
                            sendBurst(surface: "burst_complete") { completed in
                                if completed { commitToAction(action) }
                            }
                        },
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

    /// Composes the burst once on appear, and spends the storm free layer's
    /// allowance for it.
    private func loadDynamicDeclarations() {
        composeSession()
        if burstDeclarationCount == 1 {
            // A free storm member's one declaration a day. Already spent
            // (in the feed, or an earlier Burst today): the limit screen
            // covers the Burst instead of handing out another line.
            if StormFreeLayer.hasAllowanceLeft {
                StormFreeLayer.recordUse()
            } else {
                showStormFreeLimit = true
                AnalyticsService.shared.track("storm_free_limit_hit", parameters: [
                    "free_day": StormFreeLayer.freeDay, "surface": "burst"
                ])
            }
        }
    }

    /// Hands the builder everything it needs and keeps the result.
    ///
    /// The policy — campaign ownership, the personal mix, dedup, fallback, and
    /// the theme — lives in `BurstSessionBuilder`, where it is testable without
    /// a view. This reads the singletons the builder deliberately does not.
    /// Separate from `loadDynamicDeclarations` so flipping "Mix in my own" on
    /// the intro can recompose without spending anything twice.
    private func composeSession() {
        let service = EnforcementService.shared

        // The campaign only owns the burst it is actually responsible for. Opened
        // from Jump Back In this is the user's own burst, so the campaign is left
        // out of the composition entirely and `selected` — the category they
        // chose — is what fills it.
        //
        // A stand burst is owned by the room's campaign instead, on the day the
        // speaker is on in that room. Nothing is selected or started locally:
        // the burst completes like any other, and `StandMirror` counts it.
        let campaignOwnsThisBurst = source == .dailyTask && service.isEnabled
        let activeEnforcement: Enforcement?
        let currentDay: Int
        if source == .stand, let standEnforcement {
            activeEnforcement = standEnforcement
            currentDay = standDay
        } else {
            activeEnforcement = campaignOwnsThisBurst ? service.activeEnforcement : nil
            currentDay = service.progressSnapshot.currentDay
        }

        let composed = BurstSessionBuilder(
            declarationCount: burstDeclarationCount
        ).build(
            enforcement: activeEnforcement,
            currentDay: currentDay,
            favorites: viewModel.favorites,
            custom: personalDeclarations,
            // The selected category, and only that. Favorites and the user's own
            // come in through `mixPersonal`, never by default.
            categoryPool: viewModel.declarations,
            selected: viewModel.selectedCategory,
            mixPersonal: mixPersonal && canMixPersonal,
            // The whole pool, not `viewModel.declarations` — that is the category
            // the user is browsing, which has nothing to do with the campaign they
            // are on. A campaign fills its six non-anchor slots from its own theme.
            fullPool: viewModel.allAvailableDeclarations
        )
        session = composed

        switch composed.origin {
        case .enforcement:
            print("📱 Daily Burst: speaking \(activeEnforcement?.title ?? ""), day \(currentDay)")
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

                    // The choice is offered here as well as inside the burst, so
                    // someone who wants the verse in their mouth picks it before
                    // the first card rather than discovering the switch on slat
                    // three. Same key, same control — one preference, two doors.
                    if scriptureAvailable {
                        VStack(spacing: DS.Spacing.xs) {
                            Text("What you'll speak")
                                .font(.system(size: 13, weight: .semibold))
                                .kerning(0.8)
                                .foregroundColor(.white.opacity(0.6))

                            BurstSpeakModeToggle(mode: speakMode.wrappedValue, onChange: chooseMode)
                        }
                        .padding(.top, DS.Spacing.sm)
                    }

                    if canMixPersonal {
                        mixPersonalToggle
                            .padding(.top, DS.Spacing.xs)
                    }
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

    /// Opt-in for a couple of favorites or the user's own lines. Off, the burst
    /// is only the selected category or the campaign.
    private var mixPersonalToggle: some View {
        Button(action: toggleMixPersonal) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: mixPersonal ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 15, weight: .semibold))
                Text("Mix in my own")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(mixPersonal ? .white : .white.opacity(0.7))
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xs)
            .background(
                Capsule()
                    .fill(mixPersonal ? Color.white.opacity(0.2) : Color.white.opacity(0.08))
                    .overlay(Capsule().stroke(Color.white.opacity(0.14), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Mix in my favorites and my own declarations")
        .accessibilityAddTraits(mixPersonal ? [.isButton, .isSelected] : [.isButton])
    }

    private func toggleMixPersonal() {
        Juice.play(.tapLight)
        withAnimation(DS.Motion.quick) { mixPersonal.toggle() }
        composeSession()
        AnalyticsService.shared.track("daily_burst_mix_changed", parameters: [
            "mix_personal": mixPersonal,
            "source": source.rawValue
        ])
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
                    speakMode: speakMode,
                    size: geometry.size,
                    onAdvance: recordAdvance,
                    onFinish: finishBurst,
                    onClose: { dismiss() },
                    onModeChange: recordModeChange
                )
            }
        }
    }

    // MARK: - Completion View
    
    private func completionView(geometry: GeometryProxy) -> some View {
        // Small phones get a tighter celebration so the cards keep their size.
        let compact = geometry.size.height < 760

        return ZStack {
            // Animated background particles. Placed from the index, not
            // `random()`: this view redraws as each card arrives, and random
            // positions would make every particle jump on each redraw.
            ForEach(0..<(reduceMotion ? 0 : 20), id: \.self) { index in
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.yellow.opacity(0.6), Color.orange.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 2 + 4 * Self.particleNoise(index, salt: 3))
                    .position(
                        x: geometry.size.width * Self.particleNoise(index, salt: 1),
                        y: geometry.size.height * Self.particleNoise(index, salt: 2)
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
                // Scrolls so nothing clips on an iPhone SE or at large type.
                // The cards are the reason to stay on this screen, so the
                // celebration above them is kept compact.
                ScrollView(showsIndicators: false) {
                    VStack(spacing: compact ? DS.Spacing.md : DS.Spacing.lg) {
                        celebrationHeader(compact: compact)

                        if burstShare.expectedCount > 0 {
                            BurstCardsSection(
                                controller: burstShare,
                                width: geometry.size.width,
                                onSendAll: { sendBurst(surface: "burst_completion_screen") { _ in } }
                            )
                            .scaleEffect(shareButtonOpacity)
                            .opacity(shareButtonOpacity)
                        }
                    }
                    .padding(.top, compact ? 44 : 64)
                    .padding(.bottom, DS.Spacing.md)
                }

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

                    // Quieter than before: "Send these to a friend" is the one
                    // primary action on this screen now.
                    Button(action: completeBurst) {
                        Text("Continue")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: geometry.size.width * 0.4, height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 22)
                                    .fill(Color.white.opacity(0.14))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 22)
                                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.dsPressable(feel: .tapLight, haptics: false))
                }
                .padding(.top, DS.Spacing.xs)
                .padding(.bottom, compact ? 24 : 40)
            }
        }
        .onAppear {
            // Picked once: these draw at random, and this screen redraws as
            // each card arrives.
            victoryTitle = getVictoryMessage()
            motivationLine = getMotivationalMessage()
            triggerCompletionAnimations()
            // Normally started on the eighth slat; this covers any way here
            // that skipped it.
            prepareBurstCards()
        }
        .sheet(isPresented: $showSpiritualGraph) {
            SpiritualStrengthGraph(tracker: burstTracker)
        }
    }

    /// The celebration, sized down so the cards below it can lead.
    private func celebrationHeader(compact: Bool) -> some View {
        VStack(spacing: compact ? DS.Spacing.sm : DS.Spacing.md) {
            // Success mark with the seven declarations closed into a ring.
            //
            // The ring segments are the same as the progress rail, one per
            // line actually spoken, set around the mark. The reward is made of
            // the work rather than dropped on top of it.
            ZStack {
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

                ForEach(0..<max(morningDeclarations.count, 1), id: \.self) { index in
                    let count = max(morningDeclarations.count, 1)
                    let angle = (Double(index) / Double(count)) * 2 * .pi - .pi / 2

                    Capsule()
                        .fill(DS.Gradient.gold)
                        .frame(width: 5, height: 18)
                        .shadow(color: DS.Palette.gold.opacity(0.7), radius: 5)
                        .offset(x: cos(angle) * 78, y: sin(angle) * 78)
                        .rotationEffect(.degrees(angle * 180 / .pi + 90))
                        .scaleEffect(starOpacity)
                        .opacity(starOpacity)
                }

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
            // The mark is drawn at its old size and scaled as one piece, so
            // the ring geometry stays exactly as designed.
            .frame(width: 200, height: 200)
            .scaleEffect(compact ? 0.55 : 0.7)
            .frame(width: compact ? 110 : 140, height: compact ? 110 : 140)

            Text(victoryTitle)
                .font(.system(size: compact ? 26 : 30, weight: .black))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, Color(red: 1.0, green: 0.9, blue: 0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .multilineTextAlignment(.center)
                .scaleEffect(checkmarkScale)
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 2)

            if !motivationLine.isEmpty {
                Text(motivationLine)
                    .font(.system(size: compact ? 15 : 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, DS.Spacing.xl)
                    .scaleEffect(statsScale)
            }

            // The streak as one line instead of a tile, so the cards keep the room.
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(streakViewModel.displayStreak >= 7 ? DS.Gradient.ember : DS.Gradient.gold)
                CountUpText(value: streakViewModel.displayStreak,
                            font: .system(size: 17, weight: .black))
                Text("day streak")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
                if streakViewModel.displayStreak % 7 == 0 && streakViewModel.displayStreak > 0 {
                    Text("· \(streakViewModel.displayStreak / 7) week\(streakViewModel.displayStreak == 7 ? "" : "s") strong")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(DS.Palette.gold)
                }
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.xs)
            .background(Capsule().fill(Color.white.opacity(0.10)))
            .scaleEffect(statsScale)

            // What they said yes to on the eighth slat, so the commitment
            // survives the celebration instead of being buried under it.
            if let committedAction {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(DS.Palette.gold)

                    Text(committedAction.headline)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.xs)
                .background(Capsule().fill(Color.white.opacity(0.10)))
                .opacity(starOpacity)
                .padding(.horizontal, DS.Spacing.lg)
            }
        }
    }

    /// A stable 0...1 value per particle, so a redraw never moves them.
    private static func particleNoise(_ index: Int, salt: Double) -> CGFloat {
        let value = sin(Double(index) * 12.9898 + salt * 78.233) * 43758.5453
        return CGFloat(value - value.rounded(.down))
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
    
    /// Sends every line of this burst as a story card, in order, with an
    /// invitation and a tracked link. `completion` gets true only for a share
    /// the system reports as completed.
    private func sendBurst(surface: String, completion: @escaping (Bool) -> Void) {
        guard !burstShare.isPreparing, !morningDeclarations.isEmpty else { return }
        AnalyticsService.shared.track("share_prompt_tapped", parameters: [
            "surface": surface,
            "card_count": morningDeclarations.count
        ])
        prepareBurstCards()
        burstShare.shareAll(surface: surface, completion: completion)
    }

    /// Starts drawing this burst's cards. Only the first call renders, so the
    /// eighth slat, its send and the finish screen all reuse one set.
    private func prepareBurstCards() {
        guard !morningDeclarations.isEmpty else { return }
        burstShare.prepare(
            lines: morningDeclarations,
            theme: burstTheme,
            background: DeclarationStoryCard.background(for: themeViewModel)
        )
    }

    // MARK: - Actions
    
    /// The mode picked on the intro, before there is a card to speak.
    ///
    /// Separate from the stage's own handler because there is nothing to guard
    /// here — no charge is running and no card is leaving — and the event needs
    /// to say the choice was made up front rather than mid-burst.
    private func chooseMode(_ mode: BurstSpeakMode) {
        guard mode != speakMode.wrappedValue else { return }

        Juice.play(.tapLight)
        withAnimation(DS.Motion.quick) { speakMode.wrappedValue = mode }

        AnalyticsService.shared.track("daily_burst_mode_changed", parameters: [
            "mode": mode.rawValue,
            "where": "intro",
            "source": source.rawValue
        ])
    }

    /// The mode switched partway through the burst. `position` is the slat they
    /// were on, so a switch on slat one reads differently from a switch on six.
    private func recordModeChange(_ mode: BurstSpeakMode) {
        AnalyticsService.shared.track("daily_burst_mode_changed", parameters: [
            "mode": mode.rawValue,
            "where": "burst",
            "position": currentDeclarationIndex + 1,
            "source": source.rawValue
        ])
    }

    private func startBurst() {
        AnalyticsService.shared.track("daily_burst_started", parameters: [
            "streak": streakViewModel.displayStreak,
            "source": source.rawValue,
            "mode": speakMode.wrappedValue.rawValue,
            // How many of the seven can actually honour scripture mode. Without
            // it, a burst that silently fell back to declarations on five slats
            // would be indistinguishable from one that spoke seven verses.
            "scripture_slats": session?.scriptureCount ?? 0,
            "mix_personal": mixPersonal && canMixPersonal
        ])
        withAnimation(.easeIn(duration: 0.4)) {
            burstActive = true
        }
    }

    /// What the slat at `index` actually rendered as, after the fallback a slat
    /// with no verse behind it takes.
    private func spokenMode(at index: Int) -> BurstSpeakMode {
        guard morningDeclarations.indices.contains(index) else {
            return speakMode.wrappedValue
        }
        return morningDeclarations[index].resolvedMode(speakMode.wrappedValue)
    }

    /// One line spoken. Recorded per declaration so the hold-to-speak surge can
    /// be compared against a plain tap instead of assumed to be used.
    private func recordAdvance(_ method: BurstAdvanceMethod, at index: Int) {
        if method == .surge { surgeCount += 1 }

        AnalyticsService.shared.track("daily_burst_declaration_spoken", parameters: [
            "method": method.rawValue,
            "position": index + 1,
            "of": morningDeclarations.count,
            // The mode the slat actually rendered in, not the one selected: a
            // slat with no verse behind it falls back to its declaration, and
            // reporting the selection would count that as a verse spoken.
            "mode": spokenMode(at: index).rawValue
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

        // Distinct Burst DAYS, not completions: two bursts in one afternoon is
        // still day one, and the prompts below are paced by day.
        burstDayCount = burstTracker.getUniqueDaysCount()

        // Arms only. Both prompts are raised on the way out, in completeBurst.
        //
        // Both arm HERE, before completeTask below, because completeTask is
        // what makes EnforcementCard evaluate the Stand invite prompt — and
        // that prompt has to be able to see that one of these is coming.
        WelcomeOfferPresenter.shared.armAfterBurst(dayCount: burstDayCount)
        PersonalDeclarationPrompt.shared.armForBurst(dayCount: burstDayCount)

        // Automatically complete the daily burst task
        streakViewModel.completeTask(taskId: "complete_daily_burst")

        AnalyticsService.shared.track("daily_burst_completed", parameters: [
            "declarations_count": morningDeclarations.count,
            "time_spent": Int(timeSpent),
            "streak": streakViewModel.displayStreak,
            "surges": surgeCount,
            "final_method": method.rawValue,
            "source": source.rawValue,
            "mode": speakMode.wrappedValue.rawValue
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
        // The eighth slat leads with the send, so this is the burst's share
        // prompt being shown.
        AnalyticsService.shared.track("share_prompt_shown", parameters: [
            "surface": "burst_complete",
            "card_count": morningDeclarations.count
        ])

        withAnimation(DS.Motion.smooth) {
            showActionSlide = true
        }

        // Drawn while the eighth slat is read, so the send and the finish
        // screen's carousel usually find the cards already done.
        prepareBurstCards()
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

        // The post-Burst prompts, at most one of them.
        //
        // After `dismiss()`, and on a delay, for a concrete reason: both covers
        // belong to whichever view presented this Burst, and a fullScreenCover
        // raised from an ancestor while a descendant's cover is still on screen
        // is dropped silently. This one is mid-dismissal right now. The wait is
        // the dismissal animation, nothing more.
        //
        // ORDER MATTERS. The declaration ask goes first and the offer yields
        // to it, so a user owed the declaration gets that on day one and the
        // offer on their next Burst, while a user who already has one gets the
        // offer straight away. Never both on one tap.
        //
        // Not from a stand. That Burst sits on a sheet over the root, so a root
        // cover raised now would be dropped behind it, and both presenters
        // write their once-ever flag before presenting. They stay armed and
        // land after the next Burst opened from home instead.
        guard source != .stand else { return }
        let store = subscriptionStore
        let days = burstDayCount
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            PersonalDeclarationPrompt.shared.presentIfOwed(burstDayCount: days)
            WelcomeOfferPresenter.shared.presentIfReady(subscriptionStore: store)
        }
    }
}
