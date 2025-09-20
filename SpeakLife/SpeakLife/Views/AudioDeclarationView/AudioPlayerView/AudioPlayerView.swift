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
                
                VStack(spacing: 24) {
                    // Sheet grabber
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 40, height: 4)
                        .padding(.top, 8)
                    
                    Spacer()
                        .frame(height: proxy.size.height * 0.02)
                    
                    // Cover Image
                    Image(viewModel.imageUrl)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: viewModel.isPlaying ? proxy.size.width * 0.9 : proxy.size.width * 0.7, height: viewModel.isPlaying ? proxy.size.width * 0.9 : proxy.size.width * 0.7)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(radius: 12)
                        //.scaleEffect(viewModel.isPlaying ? 1.0 : 0.75)
                    
                    Spacer()
                        .frame(height: proxy.size.height * 0.02)
                    
                    // Title & Subtitle
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
                    
                    VStack(spacing: 16) {
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
                        HStack(spacing: 50) {
                            Button(action: {
                                let newTime = max(viewModel.currentTime - 15, 0)
                                viewModel.seek(to: newTime)
                            }) {
                                Image(systemName: "gobackward.15")
                                    .font(.title)
                                    .foregroundColor(.white)
                            }
                            
                            Button(action: {
                                withAnimation(.easeOut(duration: 0.15)) {
                                    isPlayingPulse = false
                                }

                                // Slight bounce effect on tap
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) {
                                    viewModel.togglePlayPause()
                                }

                                // Restart pulse if still playing
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
                            
                            Button(action: {
                                let newTime = min(viewModel.currentTime + 30, viewModel.duration)
                                viewModel.seek(to: newTime)
                            }) {
                                Image(systemName: "goforward.30")
                                    .font(.title)
                                    .foregroundColor(.white)
                            }
//                            Button(action: {
//                                viewModel.repeatTrack()
//                            }) {
//                                Image(systemName: "repeat")
//                                    .font(.title)
//                                    .foregroundColor(viewModel.onRepeat ? Constants.DAMidBlue : .white.opacity(0.8))
//                            }
                        }
                        .padding(.top)
                        
                      
                      //  .padding(.top, 10)
                       // Spacer(minLength: 40)
                    }
                }
                .padding()
                //                .padding(.horizontal)
                //                .padding(.bottom, 30)
                //  }
                
            }
        }
        .onAppear {
            viewModel.changePlaybackSpeed(to: 1.0)
            timerViewModel.loadRemainingTime()
        }
        .onReceive(viewModel.$isPlaying) { isPlaying in
            withAnimation(Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                isPlayingPulse = isPlaying
            }
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
