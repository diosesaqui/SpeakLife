//
//  AffirmationsTutorial.swift
//  SpeakLife
//
//  Created by Claude on 2025
//

import SwiftUI

struct AffirmationsTutorial: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    let size: CGSize
    let action: () -> Void
    
    @State private var currentAffirmation = 0
    @State private var showCheckmark = false
    @State private var declaredCount = 0
    @State private var showText = false
    
    let affirmations = [
        "I am blessed and highly favored",
        "I walk in divine health and strength", 
        "God's peace guards my heart and mind"
    ]
    
    var body: some View {
        ZStack {
            // Background matching existing onboarding
            Image(subscriptionStore.onboardingBGImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .edgesIgnoringSafeArea(.all)
                .brightness(0.05)
            
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                Spacer().frame(height: 30)
                
                // Header
                VStack(spacing: 16) {
                    Text("✨ Daily Affirmations")
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .shadow(color: .white.opacity(0.6), radius: 4, x: 0, y: 2)
                        .opacity(showText ? 1 : 0)
                        .offset(y: showText ? 0 : 20)
                        .animation(.easeOut(duration: 1).delay(0.1), value: showText)
                        .padding(.horizontal)
                    
                    Text("Speak life with powerful declarations")
                        .font(Font.custom("AppleSDGothicNeo-Regular", size: 18, relativeTo: .body))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .opacity(showText ? 1 : 0)
                        .offset(y: showText ? 0 : 20)
                        .animation(.easeOut(duration: 1).delay(0.3), value: showText)
                        .padding(.horizontal)
                }
                
                Spacer().frame(height: 40)
                
                // Main Content Card
                ZStack {
                    BlurView(style: .dark)
                        .frame(width: min(size.width * 0.9, 350), height: 400)
                        .cornerRadius(20)
                        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                    
                    VStack(spacing: 25) {
                        // Progress dots
                        HStack(spacing: 10) {
                            ForEach(0..<3, id: \.self) { index in
                                Circle()
                                    .fill(declaredCount > index ? Color.green : Color.white.opacity(0.3))
                                    .frame(width: 10, height: 10)
                                    .animation(.spring(), value: declaredCount)
                            }
                        }
                        .padding(.top, 20)
                        
                        VStack(spacing: 12) {
                            Text("Declare out loud:")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(DS.Palette.gold.opacity(0.9))
                            
                            Text(affirmations[currentAffirmation])
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                                .fixedSize(horizontal: false, vertical: true)
                                .lineLimit(3)
                                .minimumScaleFactor(0.8)
                                .animation(.spring(), value: currentAffirmation)
                        }
                        
                        // Declare Button or Checkmark
                        ZStack {
                            if showCheckmark {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(.green)
                                    .transition(.scale.combined(with: .opacity))
                            } else {
                                Button(action: declareAffirmation) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "mic.fill")
                                            .font(.system(size: 20))
                                        Text("I Declare")
                                            .font(.system(size: 20, weight: .semibold))
                                    }
                                    .foregroundColor(.white)
                                    .frame(width: 200, height: 60)
                                    .background(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.orange, Color.orange.opacity(0.8)]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(30)
                                    .shadow(color: Color.orange.opacity(0.4), radius: 12, x: 0, y: 6)
                                }
                            }
                        }
                        .frame(height: 60)
                        
                        Divider()
                            .background(Color.white.opacity(0.2))
                            .padding(.horizontal, 30)
                        
                        // Scripture
                        VStack(spacing: 8) {
                            Image(systemName: "book.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.5))
                            
                            Text("Death and life are in the power of the tongue")
                                .font(Font.custom("AppleSDGothicNeo-Regular", size: 14, relativeTo: .body))
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                            
                            Text("Proverbs 18:21")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                }
                .opacity(showText ? 1 : 0)
                .offset(y: showText ? 0 : 20)
                .animation(.easeOut(duration: 1).delay(0.5), value: showText)
                
                Spacer()
                
                // CTA Button
                ShimmerButton(
                    colors: [.blue],
                    buttonTitle: declaredCount == 3 ? "Continue →" : "Next →",
                    action: action
                )
                .frame(width: min(size.width * 0.9, 340), height: 50)
                .opacity(showText ? 1 : 0)
                .animation(.easeOut(duration: 1).delay(0.7), value: showText)
                
                Spacer().frame(height: size.height * 0.07)
            }
        }
        .onAppear {
            showText = true
        }
    }
    
    private func declareAffirmation() {
        withAnimation(.spring()) {
            showCheckmark = true
            declaredCount += 1
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation {
                showCheckmark = false
                if currentAffirmation < affirmations.count - 1 {
                    currentAffirmation += 1
                }
            }
        }
    }
}