//
//  NewOnboardingScreens.swift
//  SpeakLife
//
//  Created with Apple Design Standards
//

import SwiftUI
import FirebaseAnalytics

// MARK: - Screen 1: Scripture Anchor
struct ScriptureAnchorScreen: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    let size: CGSize
    let onContinue: () -> Void
    @State private var isContentVisible = false
    @State private var isButtonVisible = false
    
    var body: some View {
        ZStack {
            // Background
            backgroundView
            
            // Content
            VStack(spacing: 0) {
                Spacer()
                
                // Main Quote
                VStack(spacing: 20) {
                    Text("\"My people are destroyed for lack of knowledge.\"")
                        .font(.system(size: 28, weight: .bold, design: .serif))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)
                        .lineSpacing(6)
                        .padding(.horizontal, 24)
                        .minimumScaleFactor(0.8)
                        .opacity(isContentVisible ? 1 : 0)
                        .offset(y: isContentVisible ? 0 : 20)
                    
                    // Scripture Reference
                    Text("Hosea 4:6")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                        .opacity(isContentVisible ? 1 : 0)
                        .offset(y: isContentVisible ? 0 : 20)
                        .animation(.easeOut(duration: 0.8).delay(0.2), value: isContentVisible)
                }
                
                Spacer()
                    .frame(minHeight: 40, maxHeight: 60)
                
                // Sub-points
                VStack(spacing: 12) {
                    Text("Not lack of faith.")
                        .font(.system(size: 19, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.95))
                    
                    Text("Not lack of prayer.")
                        .font(.system(size: 19, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.95))
                    
                    Text("Lack of knowing how to respond.")
                        .font(.system(size: 19, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 24)
                .opacity(isContentVisible ? 1 : 0)
                .offset(y: isContentVisible ? 0 : 30)
                .animation(.easeOut(duration: 0.8).delay(0.4), value: isContentVisible)
                
                Spacer()
                
                // Continue Button
                continueButton
                    .padding(.horizontal, 24)
                    .padding(.bottom, 50)
                    .opacity(isButtonVisible ? 1 : 0)
                    .offset(y: isButtonVisible ? 0 : 20)
            }
            .frame(width: size.width, height: size.height)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                isContentVisible = true
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.8)) {
                isButtonVisible = true
            }
        }
    }
    
    var backgroundView: some View {
        ZStack {
            Image(subscriptionStore.onboardingBGImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                .clipped()
                .ignoresSafeArea()
            
            // Gradient overlay for better text readability
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.7),
                    Color.black.opacity(0.4),
                    Color.black.opacity(0.5)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .ignoresSafeArea()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .edgesIgnoringSafeArea(.all)
    }
    
    var continueButton: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onContinue()
        }) {
            HStack(spacing: 8) {
                Text("Continue")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                Image(systemName: "arrow.right")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                Capsule()
                    .fill(Color.white)
            )
        }
    }
}

// MARK: - Screen 2: Reframe the Problem
struct ReframeProblemScreen: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    let size: CGSize
    let onContinue: () -> Void
    @State private var isContentVisible = false
    @State private var isButtonVisible = false
    
    var body: some View {
        ZStack {
            backgroundView
            
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 48) {
                    // Main Message
                    VStack(spacing: 16) {
                        Text("You don't lose because")
                            .font(.system(size: 28, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.95))
                        
                        Text("life is strong.")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .scaleEffect(isContentVisible ? 1 : 0.8)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: isContentVisible)
                    }
                    .multilineTextAlignment(.center)
                    .opacity(isContentVisible ? 1 : 0)
                    .offset(y: isContentVisible ? 0 : 30)
                    
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 60, height: 1)
                        .opacity(isContentVisible ? 1 : 0)
                        .scaleEffect(x: isContentVisible ? 1 : 0)
                        .animation(.easeOut(duration: 0.8).delay(0.4), value: isContentVisible)
                    
                    VStack(spacing: 16) {
                        Text("You lose because")
                            .font(.system(size: 28, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.95))
                        
                        Text("truth isn't spoken.")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .scaleEffect(isContentVisible ? 1 : 0.8)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.6), value: isContentVisible)
                    }
                    .multilineTextAlignment(.center)
                    .opacity(isContentVisible ? 1 : 0)
                    .offset(y: isContentVisible ? 0 : 30)
                    .animation(.easeOut(duration: 0.8).delay(0.4), value: isContentVisible)
                }
                .padding(.horizontal, 32)
                
                Spacer()
                    .frame(height: 80)
                
                // Scripture Context
                VStack(spacing: 12) {
                    Text("Jesus didn't tell us to endure mountains.")
                        .font(.system(size: 19, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))
                    
                    Text("He told us to talk to them.")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .opacity(isContentVisible ? 1 : 0)
                .offset(y: isContentVisible ? 0 : 30)
                .animation(.easeOut(duration: 0.8).delay(0.8), value: isContentVisible)
                
                Spacer()
                
                continueButton
                    .padding(.horizontal, 32)
                    .padding(.bottom, 50)
                    .opacity(isButtonVisible ? 1 : 0)
                    .offset(y: isButtonVisible ? 0 : 20)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                isContentVisible = true
            }
            withAnimation(.easeOut(duration: 0.6).delay(1.0)) {
                isButtonVisible = true
            }
        }
    }
    
    var backgroundView: some View {
        ZStack {
            Image(subscriptionStore.onboardingBGImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                .clipped()
                .ignoresSafeArea()
            
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.65),
                    Color.black.opacity(0.4),
                    Color.black.opacity(0.5)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .edgesIgnoringSafeArea(.all)
    }
    
    var continueButton: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onContinue()
        }) {
            Text("Show me")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    Capsule()
                        .fill(Color.white)
                )
        }
    }
}

// MARK: - Screen 3: The Jesus Method
struct JesusMethodScreen: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    let size: CGSize
    let onContinue: () -> Void
    @State private var isContentVisible = false
    @State private var stepsVisible = [false, false, false]
    
    var body: some View {
        ZStack {
            backgroundView
            
            VStack(spacing: 0) {
                Spacer()
                
                Text("Jesus gave a")
                    .font(.system(size: 26, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.95))
                    .opacity(isContentVisible ? 1 : 0)
                    .offset(y: isContentVisible ? 0 : 20)
                
                Text("clear instruction.")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .opacity(isContentVisible ? 1 : 0)
                    .offset(y: isContentVisible ? 0 : 20)
                    .animation(.easeOut(duration: 0.8).delay(0.2), value: isContentVisible)
                
                Spacer()
                    .frame(height: 80)
                
                // Three Steps
                VStack(spacing: 28) {
                    ForEach(0..<3) { index in
                        HStack(spacing: 20) {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.15))
                                    .frame(width: 48, height: 48)
                                
                                Text("\(index + 1)")
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            
                            Text(stepText(for: index))
                                .font(.system(size: 20, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 40)
                        .opacity(stepsVisible[index] ? 1 : 0)
                        .offset(x: stepsVisible[index] ? 0 : -30)
                    }
                }
                
                Spacer()
                    .frame(height: 60)
                
                // Footer
                VStack(spacing: 8) {
                    Text("This isn't metaphor.")
                        .font(.system(size: 18, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text("This is spiritual law.")
                        .font(.system(size: 19, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.95))
                }
                .opacity(isContentVisible ? 1 : 0)
                .animation(.easeOut(duration: 0.8).delay(1.5), value: isContentVisible)
                
                Spacer()
                
                continueButton
                    .padding(.horizontal, 32)
                    .padding(.bottom, 50)
                    .opacity(stepsVisible[2] ? 1 : 0)
                    .offset(y: stepsVisible[2] ? 0 : 20)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                isContentVisible = true
            }
            
            for index in 0..<3 {
                withAnimation(.easeOut(duration: 0.6).delay(Double(index) * 0.3 + 0.5)) {
                    stepsVisible[index] = true
                }
            }
        }
    }
    
    func stepText(for index: Int) -> String {
        switch index {
        case 0: return "Speak to the mountain"
        case 1: return "Believe what you say"
        case 2: return "Expect it to move"
        default: return ""
        }
    }
    
    var backgroundView: some View {
        ZStack {
            Image(subscriptionStore.onboardingBGImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                .clipped()
                .ignoresSafeArea()
            
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.7),
                    Color.black.opacity(0.4),
                    Color.black.opacity(0.5)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .edgesIgnoringSafeArea(.all)
    }
    
    var continueButton: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onContinue()
        }) {
            Text("I want this")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    Capsule()
                        .fill(Color.white)
                )
        }
    }
}

// MARK: - Screen 4: Self-Diagnosis
struct SelfDiagnosisScreen: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    let size: CGSize
    let onContinue: () -> Void
    @State private var selectedOption: String = ""
    @State private var isContentVisible = false
    @State private var optionsVisible = false
    
    let options = [
        ("worry", "Worry and hope it changes"),
        ("pray", "Pray silently but stay anxious"),
        ("endure", "Try to endure it"),
        ("speak", "Speak God's Word with confidence")
    ]
    
    var body: some View {
        ZStack {
            backgroundView
            
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 8) {
                    Text("When a \"mountain\"")
                        .font(.system(size: 26, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.95))
                    
                    Text("shows up in your life...")
                        .font(.system(size: 26, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.95))
                    
                    Text("what do you usually do?")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .opacity(isContentVisible ? 1 : 0)
                .offset(y: isContentVisible ? 0 : 20)
                
                Spacer()
                    .frame(height: 60)
                
                // Options
                VStack(spacing: 16) {
                    ForEach(options, id: \.0) { option in
                        DiagnosisOptionCard(
                            text: option.1,
                            isSelected: selectedOption == option.0,
                            onTap: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    selectedOption = option.0
                                }
                                if option.0 == "speak" {
                                    Analytics.logEvent("self_diagnosis_correct", parameters: nil)
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    onContinue()
                                }
                            }
                        )
                        .opacity(optionsVisible ? 1 : 0)
                        .offset(y: optionsVisible ? 0 : 20)
                        .animation(.easeOut(duration: 0.5).delay(Double(options.firstIndex(where: { $0.0 == option.0 }) ?? 0) * 0.1), value: optionsVisible)
                    }
                }
                .padding(.horizontal, 32)
                
                Spacer()
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                isContentVisible = true
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.5)) {
                optionsVisible = true
            }
        }
    }
    
    var backgroundView: some View {
        ZStack {
            Image(subscriptionStore.onboardingBGImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                .clipped()
                .ignoresSafeArea()
            
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.7),
                    Color.black.opacity(0.4),
                    Color.black.opacity(0.5)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .edgesIgnoringSafeArea(.all)
    }
}

struct DiagnosisOptionCard: View {
    let text: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(text)
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundColor(isSelected ? .black : .white)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(Color.green)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color.white : Color.white.opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// Custom button style for better press feedback
//struct ScaleButtonStyle: ButtonStyle {
//    func makeBody(configuration: Configuration) -> some View {
//        configuration.label
//            .scaleEffect(configuration.isPressed ? 0.97 : 1)
//            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
//    }
//}

// MARK: - Continue with remaining screens...
// (Truth Gap, Application, Micro-Commitment, Position SpeakLife)

// Screen 5: Truth Gap
struct TruthGapScreen: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    let size: CGSize
    let onContinue: () -> Void
    @State private var isContentVisible = false
    @State private var isButtonVisible = false
    
    var body: some View {
        ZStack {
            backgroundView
            
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 50) {
                    VStack(spacing: 12) {
                        Text("Most believers pray.")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .opacity(isContentVisible ? 1 : 0)
                            .offset(y: isContentVisible ? 0 : 20)
                        
                        Text("Few speak with authority.")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .opacity(isContentVisible ? 1 : 0)
                            .offset(y: isContentVisible ? 0 : 20)
                            .animation(.easeOut(duration: 0.8).delay(0.3), value: isContentVisible)
                    }
                    
                    VStack(spacing: 16) {
                        Text("Prayer asks.")
                            .font(.system(size: 24, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.8))
                        
                        Text("Authority commands.")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .opacity(isContentVisible ? 1 : 0)
                    .offset(y: isContentVisible ? 0 : 30)
                    .animation(.easeOut(duration: 0.8).delay(0.6), value: isContentVisible)
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                
                Spacer()
                
                continueButton
                    .padding(.horizontal, 32)
                    .padding(.bottom, 50)
                    .opacity(isButtonVisible ? 1 : 0)
                    .offset(y: isButtonVisible ? 0 : 20)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                isContentVisible = true
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.8)) {
                isButtonVisible = true
            }
        }
    }
    
    var backgroundView: some View {
        ZStack {
            Image(subscriptionStore.onboardingBGImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                .clipped()
                .ignoresSafeArea()
            
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.7),
                    Color.black.opacity(0.45),
                    Color.black.opacity(0.5)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .edgesIgnoringSafeArea(.all)
    }
    
    var continueButton: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onContinue()
        }) {
            Text("Teach me how")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    Capsule()
                        .fill(Color.white)
                )
        }
    }
}

// Screen 6: Application
struct ApplicationScreen: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    let size: CGSize
    let onContinue: () -> Void
    @State private var isContentVisible = false
    @State private var isQuoteVisible = false
    
    var body: some View {
        ZStack {
            backgroundView
            
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 40) {
                    Text("Jesus didn't say\n\"talk to God about the mountain.\"")
                        .font(.system(size: 28, weight: .medium, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white.opacity(0.95))
                        .lineSpacing(4)
                        .padding(.horizontal, 32)
                        .opacity(isContentVisible ? 1 : 0)
                        .offset(y: isContentVisible ? 0 : 20)
                    
                    VStack(spacing: 20) {
                        Text("He said:")
                            .font(.system(size: 22, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.8))
                        
                        Text("\"Speak to the mountain.\"")
                            .font(.system(size: 34, weight: .bold, design: .serif))
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.white.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                            )
                            .scaleEffect(isQuoteVisible ? 1 : 0.8)
                            .opacity(isQuoteVisible ? 1 : 0)
                    }
                    
                    Text("What you speak first\ndetermines what stays.")
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)
                        .lineSpacing(4)
                        .padding(.horizontal, 40)
                        .opacity(isContentVisible ? 1 : 0)
                        .offset(y: isContentVisible ? 0 : 30)
                        .animation(.easeOut(duration: 0.8).delay(0.8), value: isContentVisible)
                }
                
                Spacer()
                
                continueButton
                    .padding(.horizontal, 32)
                    .padding(.bottom, 50)
                    .opacity(isQuoteVisible ? 1 : 0)
                    .offset(y: isQuoteVisible ? 0 : 20)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                isContentVisible = true
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4)) {
                isQuoteVisible = true
            }
        }
    }
    
    var backgroundView: some View {
        ZStack {
            Image(subscriptionStore.onboardingBGImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                .clipped()
                .ignoresSafeArea()
            
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.65),
                    Color.black.opacity(0.4),
                    Color.black.opacity(0.5)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .edgesIgnoringSafeArea(.all)
    }
    
    var continueButton: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onContinue()
        }) {
            Text("That changes everything")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    Capsule()
                        .fill(Color.white)
                )
        }
    }
}

// Screen 7: Micro-Commitment
struct MicroCommitmentScreen: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    let size: CGSize
    let onContinue: () -> Void
    @State private var selectedOption: String = ""
    @State private var isContentVisible = false
    @State private var optionsVisible = false
    
    let commitmentOptions = [
        ("ready", "Yes — I'm ready", "commitment_ready"),
        ("learn", "I want to learn", "commitment_learn"),
        ("never", "I've never been taught this", "commitment_never_taught")
    ]
    
    var body: some View {
        ZStack {
            backgroundView
            
            VStack(spacing: 0) {
                Spacer()
                
                Text("Are you willing to start\nresponding the way\nJesus taught?")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .opacity(isContentVisible ? 1 : 0)
                    .offset(y: isContentVisible ? 0 : 20)
                
                Spacer()
                    .frame(height: 80)
                
                VStack(spacing: 16) {
                    ForEach(commitmentOptions, id: \.0) { option in
                        CommitmentOptionCard(
                            text: option.1,
                            isSelected: selectedOption == option.0,
                            onTap: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    selectedOption = option.0
                                }
                                Analytics.logEvent(option.2, parameters: nil)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    onContinue()
                                }
                            }
                        )
                        .opacity(optionsVisible ? 1 : 0)
                        .offset(y: optionsVisible ? 0 : 20)
                        .animation(.easeOut(duration: 0.5).delay(Double(commitmentOptions.firstIndex(where: { $0.0 == option.0 }) ?? 0) * 0.1), value: optionsVisible)
                    }
                }
                .padding(.horizontal, 32)
                
                Spacer()
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                isContentVisible = true
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.5)) {
                optionsVisible = true
            }
        }
    }
    
    var backgroundView: some View {
        ZStack {
            Image(subscriptionStore.onboardingBGImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                .clipped()
                .ignoresSafeArea()
            
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.7),
                    Color.black.opacity(0.4),
                    Color.black.opacity(0.5)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .edgesIgnoringSafeArea(.all)
    }
}

struct CommitmentOptionCard: View {
    let text: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(text)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(isSelected ? .black : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.white : Color.white.opacity(0.15))
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// Screen 8: Position SpeakLife
struct PositionSpeakLifeScreen: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    let size: CGSize
    let onContinue: () -> Void
    @State private var isLogoVisible = false
    @State private var isContentVisible = false
    @State private var isButtonVisible = false
    
    var body: some View {
        ZStack {
            backgroundView
            
            VStack(spacing: 0) {
                Spacer()
                
                // App Icon
                Image("appIconDisplay")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120, height: 120)
                    .cornerRadius(26)
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                    .scaleEffect(isLogoVisible ? 1 : 0.5)
                    .opacity(isLogoVisible ? 1 : 0)
                
                Spacer()
                    .frame(height: 50)
                
                VStack(spacing: 40) {
                    Text("SpeakLife trains\nyour response.")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .foregroundColor(.white)
                        .opacity(isContentVisible ? 1 : 0)
                        .offset(y: isContentVisible ? 0 : 20)
                    
                    Text("Daily audio declarations\nrooted in Scripture to help you\nspeak truth, believe boldly,\nand expect results.")
                        .font(.system(size: 19, weight: .medium, design: .rounded))
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.horizontal, 40)
                        .opacity(isContentVisible ? 1 : 0)
                        .offset(y: isContentVisible ? 0 : 20)
                        .animation(.easeOut(duration: 0.8).delay(0.3), value: isContentVisible)
                    
                    Text("Faith isn't silent.")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                        .italic()
                        .opacity(isContentVisible ? 1 : 0)
                        .animation(.easeOut(duration: 0.8).delay(0.6), value: isContentVisible)
                }
                
                Spacer()
                
                continueButton
                    .padding(.horizontal, 32)
                    .padding(.bottom, 50)
                    .opacity(isButtonVisible ? 1 : 0)
                    .offset(y: isButtonVisible ? 0 : 20)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                isLogoVisible = true
            }
            withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
                isContentVisible = true
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.8)) {
                isButtonVisible = true
            }
        }
    }
    
    var backgroundView: some View {
        ZStack {
            Image(subscriptionStore.onboardingBGImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                .clipped()
                .ignoresSafeArea()
            
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.6),
                    Color.black.opacity(0.3),
                    Color.black.opacity(0.4)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .edgesIgnoringSafeArea(.all)
    }
    
    var continueButton: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onContinue()
        }) {
            Text("Show me how")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    Capsule()
                        .fill(Color.white)
                )
        }
    }
}
