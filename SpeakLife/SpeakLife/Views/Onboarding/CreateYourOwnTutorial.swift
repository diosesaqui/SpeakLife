//
//  CreateYourOwnTutorial.swift
//  SpeakLife
//
//  Created by Claude on 2025
//

import SwiftUI

struct CreateYourOwnTutorial: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    let size: CGSize
    let action: () -> Void
    
    @State private var showText = false
    @State private var sampleText = ""
    @State private var showSuccess = false
    
    let exampleText = "I am blessed and highly favored"
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background matching existing onboarding
                Image(subscriptionStore.onboardingBGImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .brightness(0.05)
                
                Color.black.opacity(0.4)
                
                VStack(spacing: 0) {
                    // Top spacing
                    Spacer()
                        .frame(height: max(geometry.safeAreaInsets.top + 20, 50))
                    
                    // Header
                    VStack(spacing: 12) {
                        Text("🎨 Create Your Own")
                            .font(.system(size: 28, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .shadow(color: .white.opacity(0.6), radius: 4, x: 0, y: 2)
                            .opacity(showText ? 1 : 0)
                            .offset(y: showText ? 0 : 20)
                            .animation(.easeOut(duration: 1).delay(0.1), value: showText)
                        
                        Text("Personalize your faith declarations")
                            .font(Font.custom("AppleSDGothicNeo-Regular", size: 18, relativeTo: .body))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .opacity(showText ? 1 : 0)
                            .offset(y: showText ? 0 : 20)
                            .animation(.easeOut(duration: 1).delay(0.3), value: showText)
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer()
                        .frame(height: 30)
                    
                    // Main Content Card
                    VStack(spacing: 0) {
                        BlurView(style: .dark)
                            .frame(width: min(geometry.size.width - 40, 350), height: min(geometry.size.height * 0.55, 450))
                            .cornerRadius(20)
                            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                            .overlay(
                                VStack(spacing: 20) {
                                    // Content inside card
                                    VStack(spacing: 20) {
                                        Text("See how easy it is to create")
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundColor(.white)
                                            .padding(.top, 25)
                                        
                                        VStack(spacing: 16) {
                                            // Demo Label
                                            HStack {
                                                Text("DEMO PREVIEW")
                                                    .font(.system(size: 11, weight: .bold))
                                                    .foregroundColor(.purple.opacity(0.8))
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 3)
                                                    .background(Color.purple.opacity(0.2))
                                                    .cornerRadius(4)
                                                Spacer()
                                            }
                                            .padding(.horizontal, 20)
                                            
                                            // Text Input Preview Area
                                            VStack(spacing: 0) {
                                                ZStack {
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .fill(Color.white.opacity(0.1))
                                                        .frame(height: 98)
                                                        .overlay(
                                                            RoundedRectangle(cornerRadius: 12)
                                                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                                        )
                                                        .overlay(
                                                            // Subtle overlay to show it's not interactive
                                                            RoundedRectangle(cornerRadius: 12)
                                                                .fill(Color.purple.opacity(0.05))
                                                        )
                                                    
                                                    VStack(alignment: .leading, spacing: 0) {
                                                        HStack(alignment: .top) {
                                                            if sampleText.isEmpty {
                                                                Text("Type your affirmation here...")
                                                                    .foregroundColor(.white.opacity(0.4))
                                                                    .font(.system(size: 15))
                                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                                            } else {
                                                                Text(sampleText)
                                                                    .font(.system(size: 15, weight: .medium))
                                                                    .foregroundColor(.white)
                                                                    .animation(.easeIn(duration: 0.3), value: sampleText.count)
                                                                    .lineLimit(3)
                                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                                                    .multilineTextAlignment(.leading)
                                                            }
                                                        }
                                                        Spacer()
                                                    }
                                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                                    .padding(12)
                                                }
                                                .frame(maxWidth: .infinity)
                                                .clipped()
                                            }
                                            .padding(.horizontal, 20)
                                        }
                                        
                                        // Large Try It Button or Success
                                        if !showSuccess {
                                            VStack(spacing: 8) {
                                            
                                                Button(action: {
                                                    simulateTyping()
                                                }) {
                                                    HStack(spacing: 12) {
                                                        Image(systemName: "wand.and.rays")
                                                            .font(.system(size: 18))
                                                        Text("Try It Now")
                                                            .font(.system(size: 18, weight: .bold))
                                                    }
                                                    .foregroundColor(.white)
                                                    .frame(width: 220, height: 56)
                                                    .background(
                                                        LinearGradient(
                                                            gradient: Gradient(colors: [Color.purple, Color.purple.opacity(0.7)]),
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        )
                                                    )
                                                    .cornerRadius(28)
                                                    .shadow(color: Color.purple.opacity(0.5), radius: 15, x: 0, y: 8)
                                                }
                                                .scaleEffect(1.02)
                                            }
                                            Text("👆 Tap to see the magic happen")
                                                .font(.system(size: 13))
                                                .foregroundColor(.white.opacity(0.7))
                                        } else {
                                            VStack(spacing: 16) {
                                                Image(systemName: "sparkles")
                                                    .font(.system(size: 45))
                                                    .foregroundColor(.yellow)
                                                
                                                Text("Perfect! Your affirmation is saved")
                                                    .font(.system(size: 15, weight: .medium))
                                                    .foregroundColor(.green)
                                                    .multilineTextAlignment(.center)
                                                    .padding(.horizontal, 10)
                                            }
                                            .transition(.scale.combined(with: .opacity))
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    // Features List at bottom
                                    VStack(spacing: 10) {
                                        FeatureRowCYO(icon: "square.and.pencil", text: "Write custom affirmations")
                                        FeatureRowCYO(icon: "mic.fill", text: "Declare them daily")
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.bottom, 20)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            )
                            .opacity(showText ? 1 : 0)
                            .offset(y: showText ? 0 : 20)
                            .animation(.easeOut(duration: 1).delay(0.5), value: showText)
                    }
                    
                    Spacer()
                        .frame(minHeight: 20)
                    
                    // CTA Button
                    ShimmerButton(
                        colors: [.blue],
                        buttonTitle: showSuccess ? "Continue →" : "Next →",
                        action: action
                    )
                    .frame(width: min(geometry.size.width - 40, 340), height: 50)
                    .opacity(showText ? 1 : 0)
                    .animation(.easeOut(duration: 1).delay(0.7), value: showText)
                    
                    // Bottom spacing
                    Spacer()
                        .frame(height: max(geometry.safeAreaInsets.bottom + 20, 40))
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            showText = true
        }
    }
    
    private func simulateTyping() {
        let characters = Array(exampleText)
        sampleText = ""
        
        // Initial fade in before typing starts
        withAnimation(.easeIn(duration: 0.2)) {
            // This triggers the animation setup
        }
        
        for (index, character) in characters.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.06) {
                withAnimation(.easeOut(duration: 0.1)) {
                    sampleText.append(character)
                }
                
                // Show success when typing is complete
                if index == characters.count - 1 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            showSuccess = true
                        }
                    }
                }
            }
        }
    }
}

struct FeatureRowCYO: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 20)
            
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.8))
            
            Spacer()
        }
    }
}
