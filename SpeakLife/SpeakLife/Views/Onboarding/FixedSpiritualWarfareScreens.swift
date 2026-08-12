//
//  FixedSpiritualWarfareScreens.swift  
//  SpeakLife
//
//  PROPERLY WORKING screens without layout issues
//

import SwiftUI

// MARK: - Simple, Working Battle Intro Screen
struct FixedBattleIntroScreen: View {
    let size: CGSize
    let onContinue: () -> Void
    @State private var phase = 0
    @State private var contentOpacity = 0.0
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    
    var body: some View {
        ZStack {
            // Background
            Image(subscriptionStore.onboardingBGImage)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .overlay(Color.black.opacity(0.4))
            
            VStack(spacing: 0) {
                // Progress dots - SIMPLE positioning
                HStack {
                    Spacer()
                    ProgressDots(current: 1, total: 5)
                }
                .padding(.top, 50)
                .padding(.trailing, 20)
                
                Spacer()
                
                // Content that FITS on screen
                VStack(spacing: 20) {
                    if phase == 0 {
                        VStack(spacing: 12) {
                            Text("Your mind is under attack")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                            
                            Text("60,000 thoughts. Every day.")
                                .font(.system(size: 17))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    } else if phase == 1 {
                        VStack(spacing: 15) {
                            Text("The enemy whispers lies")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                            
                            VStack(spacing: 6) {
                                Text("\"You're not enough\"")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white.opacity(0.85))
                                Text("\"God forgot about you\"")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white.opacity(0.85))
                                Text("\"Nothing will change\"")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white.opacity(0.85))
                            }
                        }
                    } else {
                        VStack(spacing: 15) {
                            Text("When you agree,\\nthey become reality")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                            
                            Text("That's how he steals your peace, joy, and victory")
                                .font(.system(size: 15))
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                    }
                }
                .padding(.horizontal, 30)
                .opacity(contentOpacity)
                
                Spacer()
                
                // Button - SIMPLE positioning
                Button(action: nextPhase) {
                    Text(phase < 2 ? "Continue →" : "How do I stop this? →")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: size.width * 0.85, height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .fill(DS.Gradient.brand)
                        )
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            withAnimation(.easeIn(duration: 0.8)) {
                contentOpacity = 1
            }
        }
    }
    
    private func nextPhase() {
        if phase < 2 {
            withAnimation(.easeInOut(duration: 0.5)) {
                contentOpacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                phase += 1
                withAnimation(.easeIn(duration: 0.5)) {
                    contentOpacity = 1
                }
            }
        } else {
            onContinue()
        }
    }
}

// MARK: - Simple Victory Solution Screen
struct FixedVictorySolutionScreen: View {
    let size: CGSize
    let selectedThoughts: Set<String>
    let onContinue: () -> Void
    @State private var showSolution = false
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    
    var body: some View {
        ZStack {
            // Background
            Image(subscriptionStore.onboardingBGImage)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .overlay(Color.black.opacity(0.3))
            
            VStack(spacing: 0) {
                // Progress - SIMPLE
                HStack {
                    Spacer()
                    ProgressDots(current: 4, total: 5)
                }
                .padding(.top, 50)
                .padding(.trailing, 20)
                
                Spacer()
                
                // Content that FITS
                VStack(spacing: 20) {
                    if !showSolution {
                        VStack(spacing: 20) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 40))
                                .foregroundColor(Color(red: 0.9, green: 0.7, blue: 0.3))
                            
                            Text("THE TRUTH")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(DS.Palette.gold.opacity(0.9))
                                .tracking(2)
                            
                            Text("Jesus already\\ndefeated those lies")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                            
                            Text("You fight FROM victory,\\nnot FOR victory")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.85))
                                .multilineTextAlignment(.center)
                        }
                    } else {
                        VStack(spacing: 20) {
                            Text("Your weapon:")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.8))
                            
                            Text("\"Be transformed by the\\nrenewing of your mind\"")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                            
                            Text("Romans 12:2")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.7))
                            
                            Text("SpeakLife trains you to\\nreplace lies with God's truth")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.9))
                                .multilineTextAlignment(.center)
                        }
                    }
                }
                .padding(.horizontal, 30)
                
                Spacer()
                
                // Button - SIMPLE
                Button(action: {
                    if !showSolution {
                        withAnimation(.easeInOut(duration: 0.6)) {
                            showSolution = true
                        }
                    } else {
                        onContinue()
                    }
                }) {
                    Text(showSolution ? "Show me how →" : "How do I use this victory? →")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: size.width * 0.85, height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .fill(DS.Gradient.gold)
                        )
                }
                .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - Update the main flow to use fixed screens
extension StreamlinedSpiritualWarfareFlow {
    func useFixedBattleIntro(size: CGSize, onContinue: @escaping () -> Void) -> some View {
        FixedBattleIntroScreen(size: size, onContinue: onContinue)
    }
    
    func useFixedVictorySolution(size: CGSize, selectedThoughts: Set<String>, onContinue: @escaping () -> Void) -> some View {
        FixedVictorySolutionScreen(size: size, selectedThoughts: selectedThoughts, onContinue: onContinue)
    }
}