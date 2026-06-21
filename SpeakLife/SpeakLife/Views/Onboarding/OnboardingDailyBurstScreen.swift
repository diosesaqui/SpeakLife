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
    
    @State private var currentPhase = 0  // 0: intro, 1: experience, 2: completion
    @State private var currentDeclarationIndex = 0
    @State private var showContent = false
    @State private var declarationOpacity = 0.0
    @State private var isTransitioning = false
    @State private var completionOpacity = 0.0
    
    // Apple-style animation states
    @State private var declarationYOffset: CGFloat = 20
    @State private var declarationBlur: CGFloat = 0
    @State private var categoryOpacity: CGFloat = 0
    @State private var verseOpacity: CGFloat = 0
    @State private var instructionOpacity: CGFloat = 0
    @State private var progressScale: CGFloat = 1.0
    
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    
    // Sample declarations for onboarding demo
    let sampleDeclarations: [(text: String, verse: String, category: String)] = [
        ("I am fearfully and wonderfully made.", "Psalm 139:14", "IDENTITY"),
        ("I can do all things through Christ who strengthens me.", "Philippians 4:13", "STRENGTH"),
        ("No weapon formed against me will prosper!", "Isaiah 54:17", "VICTORY")
    ]
    
    var body: some View {
        ZStack {
            backgroundView
                .frame(width: size.width, height: size.height)
            
            if currentPhase == 0 {
                // Introduction Screen
                introductionView
            } else if currentPhase == 1 {
                // Experience Screen
                experienceView
            } else {
                // Completion Screen
                completionView
            }
        }
        .frame(width: size.width)
        .onAppear {
            startAnimation()
        }
    }
    
    // MARK: - Introduction View
    
    private var introductionView: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 30) {
                // Lightning Bolt Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.9, green: 0.6, blue: 0.2).opacity(0.95), Color(red: 0.9, green: 0.6, blue: 0.2).opacity(0.55)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                        .shadow(color: Color(red: 0.9, green: 0.6, blue: 0.2).opacity(0.5), radius: 8, x: 0, y: 4)

                    Image(systemName: "bolt.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.white)
                }
                .opacity(declarationOpacity)
                .scaleEffect(declarationOpacity)
                
                VStack(spacing: 16) {
                    Text("Experience Your")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Daily Victory")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Every morning, speak these truths\nover your day in just 2 minutes")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                    
                    Button(action: {}) {
                        Text("Try it now!")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color(red: 0.9, green: 0.6, blue: 0.2))
                            .padding(.top, 4)
                    }
                    .disabled(true)
                }
                .opacity(declarationOpacity)
            }
            .padding(.horizontal, 30)
            
            Spacer()
            
            Button(action: startExperience) {
                HStack(spacing: 12) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 20))
                    Text("Start Daily Burst")
                        .font(.system(size: 18, weight: .semibold))
                }
                .foregroundColor(.black)
                .frame(width: size.width * 0.85, height: 56)
                .background(
                    Capsule()
                        .fill(.white)
                )
            }
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Experience View
    
    private var experienceView: some View {
        VStack(spacing: 0) {
            // Header with progress
            VStack(spacing: 12) {
                HStack {
                    Text("Daily Victory")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text("\(currentDeclarationIndex + 1)/\(sampleDeclarations.count)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.horizontal, 24)
                .padding(.top, size.height * 0.08)
                
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background track
                        Capsule()
                            .fill(Color.white.opacity(0.15))
                            .frame(height: 3)
                        
                        // Progress fill
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.95, green: 0.65, blue: 0.2),
                                        Color(red: 0.9, green: 0.5, blue: 0.1)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(
                                width: geometry.size.width * CGFloat(currentDeclarationIndex + 1) / CGFloat(sampleDeclarations.count),
                                height: 3
                            )
                            .scaleEffect(x: progressScale, y: 1, anchor: .leading)
                            .animation(
                                .interpolatingSpring(stiffness: 300, damping: 30),
                                value: currentDeclarationIndex
                            )
                            .animation(
                                .interpolatingSpring(stiffness: 400, damping: 35),
                                value: progressScale
                            )
                    }
                }
                .frame(height: 3)
                .padding(.horizontal, 24)
            }
            
            Spacer()
            
            // Declaration Content
            VStack(spacing: 24) {
                // Category label
                Text(sampleDeclarations[currentDeclarationIndex].category)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(red: 0.95, green: 0.65, blue: 0.2))
                    .tracking(2.5)
                    .opacity(categoryOpacity)
                    .offset(y: categoryOpacity == 0 ? 10 : 0)
                
                // Main declaration text
                Text(sampleDeclarations[currentDeclarationIndex].text)
                    .font(.system(size: 28, weight: .bold, design: .serif))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 24)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(declarationOpacity)
                    .offset(y: declarationYOffset)
                    .blur(radius: declarationBlur)
                
                // Bible verse
                Text(sampleDeclarations[currentDeclarationIndex].verse)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
                    .opacity(verseOpacity)
                    .offset(y: verseOpacity == 0 ? 5 : 0)
                
                // Instruction text
                Text("Speak this out loud with faith")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.top, 28)
                    .opacity(instructionOpacity)
            }
            .padding(.vertical, 20)
            
            Spacer()
            
            // Bottom Button
            Button(action: handleNextAction) {
                HStack {
                    if currentDeclarationIndex < sampleDeclarations.count - 1 {
                        Text("I Declare This")
                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .bold))
                    } else {
                        Text("Complete")
                        Text("✨")
                            .font(.system(size: 20))
                    }
                }
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: size.width * 0.85, height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 25)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.9, green: 0.6, blue: 0.2), Color.orange],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
            }
            .disabled(isTransitioning)
            .padding(.bottom, 50)
        }
    }
    
    // MARK: - Completion View
    
    private var completionView: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 30) {
                // Crown Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.95, green: 0.8, blue: 0.2).opacity(0.95), Color(red: 0.95, green: 0.8, blue: 0.2).opacity(0.55)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                        .shadow(color: Color(red: 0.95, green: 0.8, blue: 0.2).opacity(0.5), radius: 8, x: 0, y: 4)

                    Image(systemName: "crown.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                }
                .scaleEffect(completionOpacity)
                .opacity(completionOpacity)
                
                VStack(spacing: 20) {
                    HStack(spacing: 8) {
                        Text("Amazing!")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("🎉")
                            .font(.system(size: 32))
                    }
                    
                    Text("You just spoke life over your day!")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                    
                    Text("Do this every morning to transform\nyour mind and win your day")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                }
                .opacity(completionOpacity)
            }
            .padding(.horizontal, 30)
            
            Spacer()
            
            Button(action: onContinue) {
                HStack(spacing: 8) {
                    Text("Continue")
                        .font(.system(size: 18, weight: .semibold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundColor(.black)
                .frame(width: size.width * 0.85, height: 56)
                .background(
                    Capsule()
                        .fill(.white)
                )
            }
            .opacity(completionOpacity)
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Background
    
    private var backgroundView: some View {
        ZStack {
            Image(subscriptionStore.onboardingBGImage)
                .resizable()
                .scaledToFill()
                .frame(width: size.width, height: size.height)
   
                .opacity(0.8)
                .ignoresSafeArea()

            
            // Stars/particles effect
            GeometryReader { _ in
                ForEach(0..<15, id: \.self) { index in
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 2, height: 2)
                        .position(
                            x: CGFloat(50 + index * 45).truncatingRemainder(dividingBy: size.width),
                            y: CGFloat(30 + index * 25).truncatingRemainder(dividingBy: size.height * 0.5)
                        )
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func startAnimation() {
        withAnimation(.easeIn(duration: 0.8)) {
            showContent = true
            declarationOpacity = 1
        }
    }
    
    private func startExperience() {
        withAnimation(.easeInOut(duration: 0.4)) {
            declarationOpacity = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            currentPhase = 1
            resetAnimationStates()
            animateInDeclaration()
        }
        
        Analytics.logEvent("Onboarding_DailyBurst_Started", parameters: nil)
    }
    
    private func resetAnimationStates() {
        declarationOpacity = 0
        categoryOpacity = 0
        verseOpacity = 0
        instructionOpacity = 0
        declarationYOffset = 20
        declarationBlur = 3
    }
    
    private func animateInDeclaration() {
        // Main text appears first with subtle blur-to-focus effect
        withAnimation(.timingCurve(0.25, 0.1, 0.25, 1.0, duration: 0.7)) {
            declarationOpacity = 1
            declarationYOffset = 0
            declarationBlur = 0
        }
        
        // Category fades in from above
        withAnimation(.timingCurve(0.25, 0.1, 0.25, 1.0, duration: 0.5).delay(0.15)) {
            categoryOpacity = 1
        }
        
        // Verse reference slides up
        withAnimation(.timingCurve(0.25, 0.1, 0.25, 1.0, duration: 0.5).delay(0.3)) {
            verseOpacity = 1
        }
        
        // Instruction appears last
        withAnimation(.easeOut(duration: 0.6).delay(0.5)) {
            instructionOpacity = 1
        }
        
        // Progress bar subtle pulse
        withAnimation(.easeInOut(duration: 0.3).delay(0.2)) {
            progressScale = 1.05
        }
        withAnimation(.easeInOut(duration: 0.3).delay(0.5)) {
            progressScale = 1.0
        }
    }
    
    private func handleNextAction() {
        guard !isTransitioning else { return }
        
        if currentDeclarationIndex < sampleDeclarations.count - 1 {
            isTransitioning = true
            
            // Elegant fade out with upward drift
            animateOutDeclaration()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                currentDeclarationIndex += 1
                resetAnimationStates()
                
                // Smooth fade in with focus effect
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    animateInDeclaration()
                    isTransitioning = false
                }
            }
            
            Analytics.logEvent("Onboarding_DailyBurst_Declaration", parameters: [
                "index": currentDeclarationIndex + 1
            ])
        } else {
            isTransitioning = true
            animateToCompletion()
        }
    }
    
    private func animateOutDeclaration() {
        // Orchestrated fade out - each element disappears in sequence
        withAnimation(.timingCurve(0.4, 0.0, 0.6, 1.0, duration: 0.25)) {
            instructionOpacity = 0
        }
        
        withAnimation(.timingCurve(0.4, 0.0, 0.6, 1.0, duration: 0.3).delay(0.05)) {
            verseOpacity = 0
            declarationYOffset = -15
            declarationBlur = 2
        }
        
        withAnimation(.timingCurve(0.4, 0.0, 0.6, 1.0, duration: 0.35).delay(0.1)) {
            declarationOpacity = 0
            categoryOpacity = 0
        }
    }
    
    private func animateToCompletion() {
        // Grand exit for final declaration
        withAnimation(.timingCurve(0.4, 0.0, 0.2, 1.0, duration: 0.4)) {
            instructionOpacity = 0
            verseOpacity = 0
        }
        
        withAnimation(.timingCurve(0.4, 0.0, 0.2, 1.0, duration: 0.5).delay(0.1)) {
            declarationOpacity = 0
            declarationYOffset = -30
            declarationBlur = 5
            categoryOpacity = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            currentPhase = 2
            
            // Completion appears with elegant spring
            withAnimation(.interpolatingSpring(stiffness: 100, damping: 15).delay(0.1)) {
                completionOpacity = 1
            }
            
            Analytics.logEvent("Onboarding_DailyBurst_Completed", parameters: nil)
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
        .preferredColorScheme(.dark)
    }
}

