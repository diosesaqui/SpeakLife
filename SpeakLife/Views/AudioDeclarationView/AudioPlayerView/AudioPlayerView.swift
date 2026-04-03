//
//  AudioPlayerView.swift
//  SpeakLife
//
//  Created by Riccardo Washington on 11/20/24.
//

import SwiftUI



struct AudioPlayerView: View {
    @ObservedObject var viewModel: AudioPlayerViewModel
    @EnvironmentObject var timerViewModel: TimerViewModel

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var isPlayingPulse = false

    var body: some View {
        GeometryReader { proxy in
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
                    VStack(spacing: 20) {
                        // Sheet grabber
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 40, height: 4)
                            .padding(.top, 8)

                        if horizontalSizeClass == .regular {
                            // ─── iPad layout: image + controls side-by-side in landscape,
                            //     or image capped + scrollable in portrait sheet
                            iPadLayout(proxy: proxy)
                        } else {
                            // ─── iPhone layout (original, unchanged)
                            iPhoneLayout(proxy: proxy)
                        }
                    }
                    .padding()
                    // Ensure content is always at least as tall as the container so it
                    // centres when there's plenty of room, but scrolls when it's tight.
                    .frame(minHeight: proxy.size.height)
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

    // MARK: - iPhone Layout (portrait-focused, original feel)

    @ViewBuilder
    private func iPhoneLayout(proxy: GeometryProxy) -> some View {
        let coverSize = coverImageSize(proxy: proxy, fraction: 0.70)

        VStack(spacing: 20) {
            coverArt(size: coverSize)

            trackInfo

            playerControls(proxy: proxy)
        }
    }

    // MARK: - iPad Layout (adapts to both portrait sheet and landscape full-screen)

    @ViewBuilder
    private func iPadLayout(proxy: GeometryProxy) -> some View {
        let isLandscape = proxy.size.width > proxy.size.height

        if isLandscape {
            // Side-by-side: art on left, controls on right
            HStack(alignment: .center, spacing: 40) {
                let coverSize = min(proxy.size.height * 0.55, proxy.size.width * 0.38)
                coverArt(size: coverSize)
                    .frame(maxWidth: .infinity)

                VStack(spacing: 20) {
                    trackInfo
                    playerControls(proxy: proxy)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 24)
        } else {
            // Portrait sheet: cap image so controls always stay visible
            let coverSize = coverImageSize(proxy: proxy, fraction: 0.50)

            VStack(spacing: 20) {
                coverArt(size: coverSize)
                trackInfo
                playerControls(proxy: proxy)
            }
        }
    }

    // MARK: - Shared Sub-views

    /// Calculates a square cover image size capped to both width and height budgets.
    private func coverImageSize(proxy: GeometryProxy, fraction: CGFloat) -> CGFloat {
        // Never let the art exceed `fraction` of width OR 38% of available height,
        // so controls always have room below.
        let byWidth  = proxy.size.width * fraction
        let byHeight = proxy.size.height * 0.38
        return min(byWidth, byHeight)
    }

    @ViewBuilder
    private func coverArt(size: CGFloat) -> some View {
        Image(viewModel.imageUrl)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: size, height: size)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
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
        }
    }

    @ViewBuilder
    private func playerControls(proxy: GeometryProxy) -> some View {
        VStack(spacing: 16) {
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
                    Spacer()
                    Text(formatTime(viewModel.duration))
                }
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
                .padding(.horizontal)
            } else {
                Text("Loading...")
                    .foregroundColor(.white)
                    .font(.subheadline)
            }

            // Playback buttons
            HStack(spacing: 40) {
                // Repeat
                Button(action: { viewModel.repeatTrack() }) {
                    Image(systemName: "repeat")
                        .font(.title2)
                        .foregroundColor(viewModel.onRepeat ? .yellow : .white)
                        .opacity(viewModel.onRepeat ? 1.0 : 0.6)
                }

                // Skip back 15s
                Button(action: {
                    viewModel.seek(to: max(viewModel.currentTime - 15, 0))
                }) {
                    Image(systemName: "gobackward.15")
                        .font(.title)
                        .foregroundColor(.white)
                }

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
                            .frame(width: 80, height: 80)
                            .scaleEffect(isPlayingPulse ? 1.08 : 1.0)
                            .shadow(color: .white.opacity(0.25), radius: 10, x: 0, y: 4)

                        Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(.white)
                            .scaleEffect(isPlayingPulse ? 1.1 : 1.0)
                            .transition(.scale.combined(with: .opacity))
                            .animation(.easeInOut(duration: 0.2), value: viewModel.isPlaying)
                    }
                }

                // Skip forward 30s
                Button(action: {
                    viewModel.seek(to: min(viewModel.currentTime + 30, viewModel.duration))
                }) {
                    Image(systemName: "goforward.30")
                        .font(.title)
                        .foregroundColor(.white)
                }

                // Speed toggle — cycles 1× → 1.5× → 2× → 1×
                Button(action: {
                    let next: Float
                    switch viewModel.playbackSpeed {
                    case 1.0:  next = 1.5
                    case 1.5:  next = 2.0
                    default:   next = 1.0
                    }
                    viewModel.changePlaybackSpeed(to: next)
                }) {
                    Text(playbackSpeedLabel)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.white.opacity(0.2)))
                        .frame(minWidth: 44)
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
    }

    // Returns a short label for the current playback speed
    private var playbackSpeedLabel: String {
        switch viewModel.playbackSpeed {
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
        HStack(spacing: 12) {
            ZStack {
                Image(viewModel.imageUrl)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 4)
        .padding(.horizontal)
        .padding(.bottom, 8)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
