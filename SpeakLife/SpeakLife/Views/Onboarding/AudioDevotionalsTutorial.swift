//
//  AudioDevotionalsTutorial.swift
//  SpeakLife
//
//  Created by Claude on 2025
//

import SwiftUI
import AVKit

struct AudioDevotionalsTutorial: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    let size: CGSize
    let action: () -> Void
    
    @State var showText = false
    @State var currentSermonIndex = 0
    @State var autoScrollTimer: Timer?
    
    let sermons = [
        (title: "A Sound Mind", duration: "4m", category: "Peace"),
        (title: "Close Every Door", duration: "3m", category: "Protection"),
        (title: "Bold as a Lion", duration: "5m", category: "Courage"),
        (title: "Walking in Victory", duration: "4m", category: "Faith"),
        (title: "Divine Favor", duration: "3m", category: "Blessing"),
        (title: "Unshakeable Faith", duration: "5m", category: "Strength")
    ]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                backgroundView(geometry: geometry)
                contentView(geometry: geometry)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            showText = true
            startAutoScroll()
        }
        .onDisappear {
            autoScrollTimer?.invalidate()
        }
    }
    
    // MARK: - Background Components
    
    private func backgroundView(geometry: GeometryProxy) -> some View {
        ZStack {
            Image(subscriptionStore.onboardingBGImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
                .brightness(0.05)
            
            Color.black.opacity(0.4)
        }
    }
    
    // MARK: - Main Content
    
    private func contentView(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 70)
            headerSection
            Spacer().frame(height: 40)
            mainContentCard(geometry: geometry)
            Spacer()
            ctaButton(geometry: geometry)
            Spacer().frame(height: max(geometry.safeAreaInsets.bottom + 20, 40))
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Text("🎧 Audio Sermons")
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .shadow(color: .white.opacity(0.6), radius: 4, x: 0, y: 2)
                .opacity(showText ? 1 : 0)
                .offset(y: showText ? 0 : 20)
                .animation(.easeOut(duration: 1).delay(0.1), value: showText)
                .padding(.horizontal)
            
            Text("Renew your mind in 5 minutes daily")
                .font(Font.custom("AppleSDGothicNeo-Regular", size: 18, relativeTo: .body))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .opacity(showText ? 1 : 0)
                .offset(y: showText ? 0 : 20)
                .animation(.easeOut(duration: 1).delay(0.3), value: showText)
        }
    }
    
    private func mainContentCard(geometry: GeometryProxy) -> some View {
        ZStack {
            BlurView(style: .dark)
                .frame(width: min(geometry.size.width - 40, 350), height: 420)
                .cornerRadius(20)
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
            
            VStack(spacing: 12) {
                brainIconSection
                sermonListSection
                    .padding(.horizontal)
                dividerSection
                transformationMessageSection
            }
        }
        .opacity(showText ? 1 : 0)
        .offset(y: showText ? 0 : 20)
        .animation(.easeOut(duration: 1).delay(0.5), value: showText)
    }
    
    private var brainIconSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.95), Color.blue.opacity(0.55)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                    .shadow(color: Color.blue.opacity(0.5), radius: 8, x: 0, y: 4)

                Image(systemName: "brain.head.profile")
                    .font(.system(size: 30))
                    .foregroundColor(.white)
                
                audioWavesAnimation
            }
            
            Text("Bite-sized wisdom for busy believers")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .padding(.top, 12)
    }
    
    private var audioWavesAnimation: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.blue.opacity(0.8))
                    .frame(width: 2, height: CGFloat.random(in: 8...16))
                    .animation(
                        .easeInOut(duration: 0.8)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.2),
                        value: showText
                    )
            }
        }
        .offset(x: -40, y: 0)
    }
    
    private var sermonListSection: some View {
        VStack(spacing: 12) {
            Text("Available Sermons")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(DS.Palette.gold.opacity(0.9))
            
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { index in
                        sermonRow(at: index)
                    }
                }
                .padding(.horizontal, 4)
            }
            .frame(height: 140)
            .clipped()
        }
    }
    
    private func sermonRow(at index: Int) -> some View {
        let sermonIndex = (currentSermonIndex + index) % sermons.count
        let sermon = sermons[sermonIndex]
        
        return HStack(spacing: 10) {
            playIconView(isActive: index == 0)
            sermonInfoView(sermon: sermon, isActive: index == 0)
            Spacer()
            if index == 0 { newBadgeView }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(index == 0 ? Color.white.opacity(0.12) : Color.clear)
        )
        .animation(.easeInOut, value: currentSermonIndex)
    }
    
    private func playIconView(isActive: Bool) -> some View {
        Circle()
            .fill(Color.blue.opacity(isActive ? 1.0 : 0.4))
            .frame(width: 18, height: 18)
            .overlay(
                Image(systemName: "play.fill")
                    .font(.system(size: 7))
                    .foregroundColor(.white)
                    .offset(x: 0.5)
            )
    }
    
    private func sermonInfoView(sermon: (title: String, duration: String, category: String), isActive: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(sermon.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(isActive ? .white : .white.opacity(0.8))
                .lineLimit(1)
                .fixedSize(horizontal: false, vertical: true)
            
            HStack(spacing: 4) {
                Text(sermon.duration)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
                
                Text("•")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
                
                Text(sermon.category)
                    .font(.system(size: 10))
                    .foregroundColor(.blue.opacity(0.9))
            }
        }
    }
    
    private var newBadgeView: some View {
        Text("NEW")
            .font(.system(size: 8, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 3)
            .padding(.vertical, 1)
            .background(
                RoundedRectangle(cornerRadius: 2)
                    .fill(DS.Gradient.gold)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
            )
            .shadow(color: DS.Palette.gold.opacity(0.45), radius: 8, x: 0, y: 3)
    }
    
    private var dividerSection: some View {
        Divider()
            .background(Color.white.opacity(0.2))
            .padding(.horizontal, 30)
    }
    
    private var transformationMessageSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Text("Anxiety")
                    .strikethrough()
                    .foregroundColor(.red.opacity(0.7))
                
                Image(systemName: "arrow.right")
                    .foregroundColor(.white.opacity(0.5))
                
                Text("Peace")
                    .foregroundColor(.green)
            }
            .font(.system(size: 14, weight: .medium))
            
            Text("\"Be transformed by the renewing of your mind\"")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.8))
                .italic()
                .multilineTextAlignment(.center)
            
            Text("Romans 12:2")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(.bottom, 12)
    }
    
    private func ctaButton(geometry: GeometryProxy) -> some View {
        ShimmerButton(colors: [.blue], buttonTitle: "Continue →", action: action)
            .frame(width: min(geometry.size.width - 40, 340), height: 50)
            .opacity(showText ? 1 : 0)
            .animation(.easeOut(duration: 1).delay(0.7), value: showText)
    }
    
    private func startAutoScroll() {
        autoScrollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.5)) {
                currentSermonIndex = (currentSermonIndex + 1) % sermons.count
            }
        }
    }
}
