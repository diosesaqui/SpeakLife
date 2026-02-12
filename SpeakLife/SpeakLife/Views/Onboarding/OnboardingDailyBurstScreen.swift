//
//  OnboardingDailyBurstScreen.swift
//  SpeakLife
//
//  Daily burst onboarding experience screen
//

import SwiftUI
import FirebaseAnalytics

struct OnboardingDailyBurstScreen: View {
    let size: CGSize
    let onContinue: () -> Void
    
    @State private var currentPhase = 0
    @State private var showDeclaration = false
    @State private var declarationOpacity = 0.0
    @State private var pulseAnimation = false
    @State private var showBenefits = false
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    
    // Sample declaration for demo
    let sampleDeclaration = ("I am loved by God unconditionally", "Romans 8:38-39")
    
    let burstBenefits = [
        ("sunrise.fill", "Start your day aligned with truth"),
        ("bolt.circle.fill", "Build spiritual strength daily"),
        ("chart.line.uptrend.xyaxis", "Track your growth journey"),
        ("bell.badge.fill", "Morning reminder at 8 AM")
    ]
    
    var body: some View {
        ZStack {
            backgroundView
                .frame(width: size.width, height: size.height)
            
            VStack(spacing: 0) {
                if currentPhase == 0 {
                    // Introduction Phase
                    introductionPhase
                } else if currentPhase == 1 {
                    // Experience Phase
                    experiencePhase
                } else {
                    // Benefits Phase
                    benefitsPhase
                }
            }
        }
        .frame(width: size.width)
        .onAppear {
            startAnimation()
        }
    }
    
    // MARK: - Introduction Phase
    
    private var introductionPhase: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 30) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.9, green: 0.7, blue: 0.3).opacity(0.2))
                        .frame(width: 100, height: 100)
                        .scaleEffect(pulseAnimation ? 1.2 : 1)
                        .animation(
                            Animation.easeInOut(duration: 1.5)
                                .repeatForever(autoreverses: true),
                            value: pulseAnimation
                        )
                    
                    Image(systemName: "sunrise.fill")
                        .font(.system(size: 50))
                        .foregroundColor(Color(red: 0.9, green: 0.7, blue: 0.3))
                }
                
                VStack(spacing: 16) {
                    Text("Daily Declaration Burst")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Your morning victory routine")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text("Start each day declaring God's truth\nover your life in just 2 minutes")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                }
            }
            .padding(.horizontal, 30)
            .opacity(declarationOpacity)
            
            Spacer()
            
            Button(action: nextPhase) {
                Text("Experience It Now")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: size.width * 0.85, height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 0.9, green: 0.7, blue: 0.3), Color.yellow],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
            }
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Experience Phase
    
    private var experiencePhase: some View {
        VStack(spacing: 0) {
            // Mock burst header
            HStack {
                Text("Morning Victory")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 3)
                        .frame(width: 40, height: 40)
                    
                    Circle()
                        .trim(from: 0, to: 0.14)
                        .stroke(
                            LinearGradient(
                                colors: [Color(red: 0.9, green: 0.7, blue: 0.3), Color.yellow],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .frame(width: 40, height: 40)
                        .rotationEffect(.degrees(-90))
                    
                    Text("1")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 30)
            .padding(.top, size.height * 0.1)
            .opacity(showDeclaration ? 1 : 0)
            
            Spacer()
            
            // Declaration Content
            VStack(spacing: 30) {
                Image(systemName: "hands.and.sparkles.fill")
                    .font(.system(size: 60))
                    .foregroundColor(Color(red: 0.9, green: 0.7, blue: 0.3))
                    .opacity(showDeclaration ? 1 : 0)
                    .scaleEffect(showDeclaration ? 1 : 0.5)
                
                VStack(spacing: 20) {
                    Text(sampleDeclaration.0)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                    
                    Text(sampleDeclaration.1)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.6))
                }
                .opacity(showDeclaration ? 1 : 0)
                
                Text("Speak this aloud now")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(red: 0.9, green: 0.7, blue: 0.3))
                    .opacity(showDeclaration ? 1 : 0)
            }
            
            Spacer()
            
            VStack(spacing: 16) {
                HStack(spacing: 8) {
                    ForEach(0..<7, id: \.self) { index in
                        Circle()
                            .fill(index == 0 ? Color(red: 0.9, green: 0.7, blue: 0.3) : Color.white.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
                
                Button(action: nextPhase) {
                    Text("Continue →")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(width: size.width * 0.85, height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .fill(Color(red: 0.9, green: 0.7, blue: 0.3))
                        )
                }
            }
            .padding(.bottom, 40)
            .opacity(showDeclaration ? 1 : 0)
        }
    }
    
    // MARK: - Benefits Phase
    
    private var benefitsPhase: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: size.height * 0.15)
            
            VStack(spacing: 24) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
                    .opacity(showBenefits ? 1 : 0)
                    .scaleEffect(showBenefits ? 1 : 0.5)
                
                Text("Perfect! You just declared victory")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .opacity(showBenefits ? 1 : 0)
                
                Text("Do this every morning to:")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.8))
                    .opacity(showBenefits ? 1 : 0)
            }
            .padding(.horizontal, 30)
            
            Spacer().frame(height: 30)
            
            // Benefits List
            VStack(spacing: 20) {
                ForEach(Array(burstBenefits.enumerated()), id: \.offset) { index, benefit in
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color(red: 0.9, green: 0.7, blue: 0.3).opacity(0.2))
                                .frame(width: 44, height: 44)
                            
                            Image(systemName: benefit.0)
                                .font(.system(size: 20))
                                .foregroundColor(Color(red: 0.9, green: 0.7, blue: 0.3))
                        }
                        
                        Text(benefit.1)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                        
                        Spacer()
                    }
                    .padding(.horizontal, 40)
                    .opacity(showBenefits ? 1 : 0)
                    .offset(x: showBenefits ? 0 : -50)
                    .animation(
                        .spring(response: 0.4, dampingFraction: 0.8)
                            .delay(Double(index) * 0.1),
                        value: showBenefits
                    )
                }
            }
            
            Spacer()
            
            VStack(spacing: 16) {
                Text("Your spiritual strength journey starts here")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
                    .opacity(showBenefits ? 1 : 0)
                
                Button(action: onContinue) {
                    Text("I'm Ready to Build Strength →")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: size.width * 0.85, height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(red: 0.9, green: 0.7, blue: 0.3), Color.yellow],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                }
                .opacity(showBenefits ? 1 : 0.3)
                .disabled(!showBenefits)
            }
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Background
    
    private var backgroundView: some View {
        ZStack {
            Image(subscriptionStore.onboardingBGImage)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            
            LinearGradient(
                colors: [
                    Color.black.opacity(0.3),
                    Color.black.opacity(0.5)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }
    
    // MARK: - Actions
    
    private func startAnimation() {
        withAnimation(.easeIn(duration: 0.6)) {
            declarationOpacity = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            pulseAnimation = true
        }
    }
    
    private func nextPhase() {
        if currentPhase == 0 {
            withAnimation(.easeInOut(duration: 0.5)) {
                declarationOpacity = 0
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                currentPhase = 1
                withAnimation(.spring()) {
                    showDeclaration = true
                }
            }
            
            Analytics.logEvent("Onboarding_DailyBurst_Experienced", parameters: nil)
        } else if currentPhase == 1 {
            withAnimation(.easeOut(duration: 0.3)) {
                showDeclaration = false
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                currentPhase = 2
                withAnimation(.spring()) {
                    showBenefits = true
                }
            }
        }
    }
}

// MARK: - Preview

struct OnboardingDailyBurstScreen_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingDailyBurstScreen(
            size: CGSize(width: 390, height: 844),
            onContinue: {}
        )
        .environmentObject(SubscriptionStore())
    }
}