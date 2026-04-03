//
//  DemoExperienceView.swift
//  SpeakLife
//
//  Demo experience to show value before subscription
//

import SwiftUI
import FirebaseAnalytics

struct DemoExperienceView: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var viewModel: DeclarationViewModel
    
    let size: CGSize
    let callBack: (() -> Void)
    
    @State private var currentDeclaration = "Jesus already paid the price for my wholeness, protection and abundance. I receive it by faith."
    @State private var hasSpoken = false
    @State private var showCelebration = false
    @State private var streakCount = 1
    @State private var buttonPressed = false
    @State private var buttonScale: CGFloat = 1.0
    @State private var pulseAnimation = false
    @State private var showSuccessGlow = false
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                gradient: Gradient(colors: [Color(red: 0.1, green: 0.1, blue: 0.3), Color(red: 0.2, green: 0.2, blue: 0.5)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            if showCelebration {
                ConfettiView()
                    .ignoresSafeArea()
            }
            
            VStack(spacing: 20) {
                Spacer().frame(height: 40)
                
                // Header
                VStack(spacing: 8) {
                    Text("Your First Declaration")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text("Speak This Out Loud")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .white.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                
                Spacer()
                
                // Declaration Card
                VStack(spacing: 20) {
                    Image(systemName: "quote.opening")
                        .font(.system(size: 30))
                        .foregroundColor(.white.opacity(0.5))
                    
                    Text(currentDeclaration)
                        .font(.system(size: 24, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(8)
                        .padding(.horizontal, 20)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Image(systemName: "quote.closing")
                        .font(.system(size: 30))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.vertical, 40)
                .frame(width: size.width * 0.85)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
                
                Spacer()
                
                // CTA Section
                VStack(spacing: 16) {
                    if !hasSpoken {
                        Button(action: {
                            // Haptic feedback
                            let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
                            impactFeedback.impactOccurred()
                            
                            // Button press animation
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                buttonPressed = true
                                buttonScale = 0.95
                            }
                            
                            // Success animation sequence
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                    buttonScale = 1.0
                                    hasSpoken = true
                                    showSuccessGlow = true
                                }
                            }
                            
                            // Confetti and celebration
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                withAnimation(.easeInOut(duration: 0.5)) {
                                    showCelebration = true
                                }
                                
                                // Start pulsing animation
                                pulseAnimation = true
                                
                                // Mark demo as completed
                                appState.hasCompletedDemo = true
                                Analytics.logEvent("demo_declaration_spoken", parameters: nil)
                            }
                            
                            // Auto advance after celebration
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                                callBack()
                            }
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: buttonPressed ? "checkmark.circle.fill" : "mic.fill")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                                    .scaleEffect(buttonPressed ? 1.2 : 1.0)
                                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: buttonPressed)
                                
                                Text(buttonPressed ? "Perfect!" : "I Spoke It Out Loud!")
                                    .font(.system(size: 18, weight: .bold))
                            }
                            .padding()
                            .frame(width: size.width * 0.8, height: 56)
                            .background(
                                ZStack {
                                    // Main gradient
                                    LinearGradient(
                                        gradient: Gradient(colors: buttonPressed ? [.green, .blue] : [.blue, .purple]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                    
                                    // Success glow overlay
                                    if showSuccessGlow {
                                        LinearGradient(
                                            gradient: Gradient(colors: [.white.opacity(0.3), .clear]),
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                        .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: showSuccessGlow)
                                    }
                                }
                            )
                            .foregroundColor(.white)
                            .cornerRadius(30)
                            .scaleEffect(buttonScale)
                            .shadow(
                                color: (buttonPressed ? Color.green : .blue).opacity(0.4),
                                radius: showSuccessGlow ? 15 : 8,
                                x: 0, 
                                y: 4
                            )
                            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: buttonScale)
                            .animation(.easeInOut(duration: 0.3), value: buttonPressed)
                        }
                        
                        Text("Tap when you've declared it aloud")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    } else {
                        VStack(spacing: 16) {
                            // Success message with pulsing flames
                            HStack(spacing: 8) {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.orange)
                                    .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulseAnimation)
                                
                                Text("Amazing! You just started your streak!")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                    .scaleEffect(pulseAnimation ? 1.02 : 1.0)
                                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulseAnimation)
                                
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.orange)
                                    .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true).delay(0.2), value: pulseAnimation)
                            }
                            
                            // Animated streak counter
                            VStack(spacing: 8) {
                                Text("🔥")
                                    .font(.system(size: 32))
                                    .scaleEffect(pulseAnimation ? 1.15 : 1.0)
                                    .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: pulseAnimation)
                                
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 20)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.orange.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                                    )
                                    .scaleEffect(pulseAnimation ? 1.02 : 1.0)
                                    .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: pulseAnimation)
                            )
                            
                            Text("Studies show 21 days creates lasting change")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.bottom, 40)
            }
        }
    }
}
