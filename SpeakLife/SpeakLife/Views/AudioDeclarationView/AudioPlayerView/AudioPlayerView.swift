//
//  AudioPlayerView.swift
//  SpeakLife
//
//  Created by Riccardo Washington on 11/20/24.
//

import SwiftUI


/// Keeps a proportionally-derived dimension inside sane bounds, so percentages scale the
/// layout without letting any element get too cramped on a small phone or oversized on
/// an iPad.
private func clamp(_ value: CGFloat, _ lower: CGFloat, _ upper: CGFloat) -> CGFloat {
    min(max(value, lower), upper)
}


struct AudioPlayerView: View {
    @ObservedObject var viewModel: AudioPlayerViewModel
    @EnvironmentObject var timerViewModel: TimerViewModel

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var isPlayingPulse = false

    var body: some View {
        GeometryReader { proxy in
            let metrics = Metrics(size: proxy.size, sizeClass: horizontalSizeClass)

            ZStack {
                // Background Blur
                if let uiImage = UIImage(named: viewModel.imageUrl) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .blur(radius: 60)
                        .overlay(Color.black.opacity(0.4))
                        .ignoresSafeArea()
                }

                // ScrollView ensures nothing is clipped on smaller/constrained sheets
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: metrics.stackSpacing) {
                        // Sheet grabber
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.3))
                            .frame(width: metrics.grabberWidth, height: 4)
                            .padding(.top, DS.Spacing.xs)

                        if metrics.isRegularWidth {
                            // ─── iPad layout: image + controls side-by-side in landscape,
                            //     or image capped + scrollable in portrait sheet
                            iPadLayout(metrics: metrics)
                        } else {
                            // ─── iPhone layout
                            iPhoneLayout(metrics: metrics)
                        }
                    }
                    .padding(.horizontal, metrics.horizontalPadding)
                    .padding(.vertical, DS.Spacing.md)
                    // Pin the content to the viewport width. A vertical ScrollView never
                    // constrains its content's width, so a single oversized child would
                    // widen the whole stack — shoving every centred row right and
                    // clipping the overflow off the trailing edge.
                    // Height is a minimum so content centres when there's room and
                    // scrolls when it's tight.
                    .frame(width: proxy.size.width, height: proxy.size.height)
                }
            }
        }
        .onAppear {
            viewModel.changePlaybackSpeed(to: 1.0)
           // timerViewModel.loadRemainingTime()
        }
        .onReceive(viewModel.$isPlaying) { isPlaying in
            withAnimation(Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                isPlayingPulse = isPlaying
            }
        }
    }

    // MARK: - Layout Metrics

    /// Every dimension on this screen is derived from the container size rather than
    /// hard-coded points, so the layout scales from a 375pt iPhone SE up to an iPad
    /// without any single element outgrowing the width available to it.
    private struct Metrics {
        let size: CGSize
        let isRegularWidth: Bool

        init(size: CGSize, sizeClass: UserInterfaceSizeClass?) {
            self.size = size
            self.isRegularWidth = sizeClass == .regular
        }

        var isLandscape: Bool { size.width > size.height }

        /// 5% of the width, clamped so it stays sensible at both extremes.
        var horizontalPadding: CGFloat { clamp(size.width * 0.05, 16, 32) }

        /// Width left for content once the outer padding is removed.
        var contentWidth: CGFloat { max(size.width - horizontalPadding * 2, 0) }

        /// In iPad landscape the art and the controls split the row, so the controls
        /// get roughly half the content width — sizing them off the full screen width
        /// would overflow their column.
        var controlsWidth: CGFloat {
            guard isRegularWidth, isLandscape else { return contentWidth }
            return max((contentWidth - columnSpacing) / 2, 0)
        }

        var columnSpacing: CGFloat { clamp(size.width * 0.03, 20, 40) }
        var stackSpacing: CGFloat { clamp(size.height * 0.024, 12, 24) }
        var grabberWidth: CGFloat { clamp(size.width * 0.11, 36, 56) }

        /// Square cover art, capped against both the width and height budgets so the
        /// controls below always keep their room.
        func coverSize(widthFraction: CGFloat) -> CGFloat {
            min(contentWidth * widthFraction, size.height * 0.38)
        }

        // ─── Transport controls, all proportional to the row that holds them.
        var playButtonDiameter: CGFloat { clamp(controlsWidth * 0.23, 60, 88) }
        var playGlyphSize: CGFloat { playButtonDiameter * 0.375 }
        var skipGlyphSize: CGFloat { clamp(controlsWidth * 0.085, 22, 32) }
        var repeatGlyphSize: CGFloat { clamp(controlsWidth * 0.07, 18, 26) }
        var speedPillWidth: CGFloat { clamp(controlsWidth * 0.15, 44, 60) }
        var speedPillHeight: CGFloat { clamp(speedPillWidth * 0.55, 24, 32) }
        var speedFontSize: CGFloat { clamp(speedPillWidth * 0.25, 12, 16) }

        /// Gaps flex between these bounds, so the row fills wide screens at its original
        /// 40pt rhythm and tightens on narrow ones instead of overflowing.
        var minControlGap: CGFloat { clamp(controlsWidth * 0.03, 8, 16) }
        var maxControlGap: CGFloat { clamp(controlsWidth * 0.11, 20, 40) }
    }

    // MARK: - iPhone Layout (portrait-focused, original feel)

    @ViewBuilder
    private func iPhoneLayout(metrics: Metrics) -> some View {
        VStack(spacing: metrics.stackSpacing) {
            coverArt(size: metrics.coverSize(widthFraction: 0.78))

            trackInfo

            playerControls(metrics: metrics)
        }
    }

    // MARK: - iPad Layout (adapts to both portrait sheet and landscape full-screen)

    @ViewBuilder
    private func iPadLayout(metrics: Metrics) -> some View {
        if metrics.isLandscape {
            // Side-by-side: art on left, controls on right
            HStack(alignment: .center, spacing: metrics.columnSpacing) {
                coverArt(size: min(metrics.size.height * 0.55, metrics.controlsWidth))
                    .frame(maxWidth: .infinity)

                VStack(spacing: metrics.stackSpacing) {
                    trackInfo
                    playerControls(metrics: metrics)
                }
                .frame(maxWidth: .infinity)
            }
        } else {
            // Portrait sheet: cap image so controls always stay visible
            VStack(spacing: metrics.stackSpacing) {
                coverArt(size: metrics.coverSize(widthFraction: 0.56))
                trackInfo
                playerControls(metrics: metrics)
            }
        }
    }

    // MARK: - Shared Sub-views

    @ViewBuilder
    private func coverArt(size: CGFloat) -> some View {
        Image(viewModel.imageUrl)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: size, height: size)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
            .shadow(radius: 12)
            .scaleEffect(viewModel.isPlaying ? 1.0 : 0.92)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.isPlaying)
    }

    private var trackInfo: some View {
        VStack(spacing: 6) {
            Text(viewModel.currentTrack)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Text(viewModel.subtitle)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.75))
                // Wraps to two lines on narrow screens — keep it centred like the title.
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private func playerControls(metrics: Metrics) -> some View {
        VStack(spacing: DS.Spacing.md) {
            // Progress slider
            if viewModel.duration > 0 {
                Slider(
                    value: $viewModel.currentTime,
                    in: 0...viewModel.duration,
                    onEditingChanged: { isEditing in
                        if !isEditing {
                            viewModel.seek(to: viewModel.currentTime)
                        }
                    }
                ).tint(.white)

                HStack {
                    Text(formatTime(viewModel.currentTime))
                    Spacer(minLength: DS.Spacing.xs)
                    Text(formatTime(viewModel.duration))
                }
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
                .monospacedDigit()
            } else {
                Text("Loading...")
                    .foregroundColor(.white)
                    .font(.subheadline)
            }

            // Playback buttons. Sizes and gaps are proportional to the row's own width,
            // so the five controls always fit instead of overflowing narrow screens.
            HStack(spacing: 0) {
                // Repeat
                Button(action: { viewModel.repeatTrack() }) {
                    Image(systemName: "repeat")
                        .font(.system(size: metrics.repeatGlyphSize))
                        .foregroundColor(viewModel.onRepeat ? .yellow : .white)
                        .opacity(viewModel.onRepeat ? 1.0 : 0.6)
                }

                controlGap(metrics)

                // Skip back 15s
                Button(action: {
                    viewModel.seek(to: max(viewModel.currentTime - 15, 0))
                }) {
                    Image(systemName: "gobackward.15")
                        .font(.system(size: metrics.skipGlyphSize))
                        .foregroundColor(.white)
                }

                controlGap(metrics)

                // Play / Pause
                Button(action: {
                    withAnimation(.easeOut(duration: 0.15)) { isPlayingPulse = false }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) {
                        viewModel.togglePlayPause()
                    }
                    if viewModel.isPlaying {
                        withAnimation(Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                            isPlayingPulse = true
                        }
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.1))
                            .frame(width: metrics.playButtonDiameter, height: metrics.playButtonDiameter)
                            .scaleEffect(isPlayingPulse ? 1.08 : 1.0)
                            .shadow(color: .white.opacity(0.25), radius: 10, x: 0, y: 4)

                        Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: metrics.playGlyphSize, weight: .bold))
                            .foregroundColor(.white)
                            .scaleEffect(isPlayingPulse ? 1.1 : 1.0)
                            .transition(.scale.combined(with: .opacity))
                            .animation(.easeInOut(duration: 0.2), value: viewModel.isPlaying)
                    }
                }

                controlGap(metrics)

                // Skip forward 30s
                Button(action: {
                    viewModel.seek(to: min(viewModel.currentTime + 30, viewModel.duration))
                }) {
                    Image(systemName: "goforward.30")
                        .font(.system(size: metrics.skipGlyphSize))
                        .foregroundColor(.white)
                }

                controlGap(metrics)

                // Speed toggle — cycles 0.75× → 1× → 1.5× → 2× → 0.75×
                Button(action: {
                    let next: Float
                    switch viewModel.playbackSpeed {
                    case 0.75: next = 1.0
                    case 1.0:  next = 1.5
                    case 1.5:  next = 2.0
                    case 2.0:  next = 0.75
                    default:   next = 1.0
                    }
                    viewModel.changePlaybackSpeed(to: next)
                }) {
                    Text(playbackSpeedLabel)
                        .font(.system(size: metrics.speedFontSize, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        // Fixed width so the row geometry doesn't shift when the label
                        // changes width (e.g. "1×" → "0.75×").
                        .frame(width: metrics.speedPillWidth, height: metrics.speedPillHeight)
                        .background(Capsule().fill(Color.white.opacity(0.2)))
                        // Keep a 44pt tap target without growing the capsule; the row's
                        // height is set by the play button, so this costs no layout.
                        .frame(height: 44)
                        .contentShape(Rectangle())
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, DS.Spacing.xxs)
            .padding(.bottom, DS.Spacing.lg)
        }
    }

    /// Flexible gap between transport controls: tightens on narrow screens and opens up
    /// to the original 40pt rhythm on wide ones, so the row fits without ever clipping.
    private func controlGap(_ metrics: Metrics) -> some View {
        Spacer(minLength: metrics.minControlGap)
            .frame(maxWidth: metrics.maxControlGap)
    }

    // Returns a short label for the current playback speed
    private var playbackSpeedLabel: String {
        switch viewModel.playbackSpeed {
        case 0.75: return "0.75×"
        case 1.5:  return "1.5×"
        case 2.0:  return "2×"
        default:   return "1×"
        }
    }

    private func formatTime(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%01d:%02d", minutes, seconds)
    }
}


struct PersistentAudioBar: View {
    @ObservedObject var viewModel: AudioPlayerViewModel
    @State private var isTapped = false
    @State private var animatePulse = false

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            ZStack {
                Image(viewModel.imageUrl)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                    .shadow(radius: 4)

                if viewModel.isPlaying {
                    Circle()
                        .stroke(Color.blue.opacity(0.4), lineWidth: 2)
                        .frame(width: 58, height: 58)
                        .scaleEffect(animatePulse ? 1.15 : 1)
                        .opacity(animatePulse ? 0.6 : 0)
                        .animation(.easeOut(duration: 1).repeatForever(autoreverses: true), value: animatePulse)
                        .onAppear { animatePulse = true }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.currentTrack)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(viewModel.subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: {
                viewModel.togglePlayPause()
            }) {
                Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title3)
                    .foregroundColor(.white)
                    .scaleEffect(isTapped ? 0.9 : 1.0)
            }
            .buttonStyle(PlainButtonStyle())
            .onTapGesture {
                isTapped = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isTapped = false
                }
            }

            Button(action: {
                viewModel.resetPlayer()
                viewModel.isBarVisible = false
            }) {
                Image(systemName: "xmark")
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(.vertical, DS.Spacing.xs)
        .padding(.horizontal, DS.Spacing.md)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
        )
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 4)
        .padding(.horizontal)
        .padding(.bottom, 8)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
