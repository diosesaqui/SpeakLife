//
//  DevotionalsTutorial.swift
//  SpeakLife
//
//  Created by Claude on 2025
//

import SwiftUI

struct DevotionalsTutorial: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    let size: CGSize
    let action: () -> Void
    
    @State private var showText = false
    @State private var currentStep = 0
    
    let devotionalSteps = [
        (title: "Creation Waits for You", verse: "Romans 8:19", preview: "For the creation waits in eager expectation..."),
        (title: "Walking in Faith", verse: "2 Corinthians 5:7", preview: "We live by faith, not by sight..."),
        (title: "God's Perfect Plan", verse: "Jeremiah 29:11", preview: "For I know the plans I have for you...")
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
                    Text("📖 Daily Devotionals")
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .shadow(color: .white.opacity(0.6), radius: 4, x: 0, y: 2)
                        .opacity(showText ? 1 : 0)
                        .offset(y: showText ? 0 : 20)
                        .animation(.easeOut(duration: 1).delay(0.1), value: showText)
                        .padding(.horizontal)
                    
                    Text("Dive deeper into God's Word")
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
                        .frame(width: min(size.width * 0.9, 350), height: 420)
                        .cornerRadius(20)
                        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                    
                    VStack(spacing: 20) {
                        // Progress dots
                        HStack(spacing: 8) {
                            ForEach(0..<3, id: \.self) { index in
                                Circle()
                                    .fill(currentStep >= index ? Color.blue : Color.white.opacity(0.3))
                                    .frame(width: 8, height: 8)
                                    .animation(.spring(), value: currentStep)
                            }
                        }
                        .padding(.top, 20)
                        
                        // Devotional Card Preview
                        VStack(spacing: 16) {
                            // Book icon
                            Image(systemName: "book.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.white)
                                .background(
                                    Circle()
                                        .fill(Color.blue.opacity(0.3))
                                        .frame(width: 80, height: 80)
                                )
                            
                            VStack(spacing: 8) {
                                Text(devotionalSteps[currentStep].title)
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                Text(devotionalSteps[currentStep].verse)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                                    .lineLimit(1)
                            }
                            
                            // Preview text
                            Text(devotionalSteps[currentStep].preview)
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.9))
                                .multilineTextAlignment(.center)
                                .lineLimit(3)
                                .fixedSize(horizontal: false, vertical: true)
                                .italic()
                        }
                        .padding(.horizontal, 20)
                        .animation(.spring(), value: currentStep)
                        
                        // Read Button
                        Button(action: {
                            withAnimation(.spring()) {
                                if currentStep < devotionalSteps.count - 1 {
                                    currentStep += 1
                                } else {
                                    // Auto-advance to next screen after completing all devotionals
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        action()
                                    }
                                }
                            }
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "arrow.right.circle")
                                    .font(.system(size: 18))
                                Text(currentStep < devotionalSteps.count - 1 ? "Explore" : "Continue")
                                    .font(.system(size: 18, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(width: 200, height: 50)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(25)
                            .shadow(color: Color.blue.opacity(0.4), radius: 12, x: 0, y: 6)
                        }
                        
                        Divider()
                            .background(Color.white.opacity(0.2))
                            .padding(.horizontal, 30)
                        
                        // Bottom message
                        VStack(spacing: 8) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.5))
                            
                            Text("New devotionals added daily")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                            
                            Text("Grow deeper in your faith journey")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                }
                .opacity(showText ? 1 : 0)
                .offset(y: showText ? 0 : 20)
                .animation(.easeOut(duration: 1).delay(0.5), value: showText)
                
                Spacer()
                
                // CTA Button
                ShimmerButton(
                    colors: [.blue],
                    buttonTitle: "Next →",
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
}