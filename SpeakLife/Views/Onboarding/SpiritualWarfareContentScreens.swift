//
//  SpiritualWarfareContentScreens.swift
//  SpeakLife
//
//  Custom content screens for spiritual warfare onboarding
//

import SwiftUI

// MARK: - Visual Info Card (Non-clickable)
struct VisualInfoCard: View {
    let text: String
    let icon: String?
    let color: Color
    let isHighlighted: Bool
    
    init(text: String, icon: String? = nil, color: Color = .white.opacity(0.1), isHighlighted: Bool = false) {
        self.text = text
        self.icon = icon
        self.color = color
        self.isHighlighted = isHighlighted
    }
    
    var body: some View {
        HStack(spacing: 12) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(isHighlighted ? .white : .white.opacity(0.7))
                    .frame(width: 24)
            }
            
            Text(text)
                .font(.system(size: 16, weight: isHighlighted ? .semibold : .regular))
                .foregroundColor(isHighlighted ? .white : .white.opacity(0.85))
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isHighlighted ? color.opacity(0.2) : Color.clear)
        )
    }
}

// MARK: - Battle Stats Screen (Custom for intro)
struct BattleStatsScreen: View {
    let size: CGSize
    let onContinue: () -> Void
    @State private var contentOpacity = 0.0
    @State private var statsVisible = [false, false, false, false]
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    
    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                // Progress indicator
                HStack {
                    Spacer()
                    ProgressDots(current: 1, total: 10)
                        .padding(.top, proxy.safeAreaInsets.top + 10)
                        .padding(.trailing, 20)
                }
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 30) {
                        Spacer().frame(height: 20)
                        
                        // Title
                        VStack(spacing: 8) {
                            Text("Your mind is under attack")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .opacity(contentOpacity)
                            
                            Text("Every. Single. Day.")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                                .opacity(contentOpacity)
                        }
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                        
                        // Battle Statistics (as visual elements, not buttons)
                        VStack(spacing: 0) {
                            // Stat 1
                            if statsVisible[0] {
                                StatisticView(
                                    number: "60,000+",
                                    label: "thoughts attack daily",
                                    color: .red
                                )
                                .transition(.scale.combined(with: .opacity))
                            }
                            
                            // Stat 2
                            if statsVisible[1] {
                                StatisticView(
                                    number: "80%",
                                    label: "are negative by default",
                                    color: .orange
                                )
                                .transition(.scale.combined(with: .opacity))
                            }
                            
                            // Stat 3
                            if statsVisible[2] {
                                StatisticView(
                                    number: "90%",
                                    label: "repeat from yesterday",
                                    color: .purple
                                )
                                .transition(.scale.combined(with: .opacity))
                            }
                            
                            // Enemy awareness
                            if statsVisible[3] {
                                VStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(.yellow)
                                    Text("The enemy knows this pattern")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.white)
                                        .multilineTextAlignment(.center)
                                }
                                .padding(.vertical, 20)
                                .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .padding(.horizontal, 30)
                        
                        Spacer(minLength: 100)
                    }
                }
                
                // Continue button
                ShimmerButton(
                    colors: [.red, .orange],
                    buttonTitle: "Show me how to fight back →",
                    action: onContinue
                )
                .frame(width: size.width * 0.85, height: 54)
                .padding(.bottom, proxy.safeAreaInsets.bottom + 30)
                .opacity(statsVisible[3] ? 1 : 0.3)
                .disabled(!statsVisible[3])
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .background(
                ZStack {
                    Image(subscriptionStore.onboardingBGImage)
                        .resizable()
                        .scaledToFill()
                        .edgesIgnoringSafeArea(.all)
                    Color.black.opacity(0.4)
                        .edgesIgnoringSafeArea(.all)
                }
            )
        }
        .onAppear {
            animateContent()
        }
    }
    
    private func animateContent() {
        withAnimation(.easeIn(duration: 0.6)) {
            contentOpacity = 1.0
        }
        
        // Stagger the statistics appearance
        for i in 0..<4 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.5 + 0.8) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    statsVisible[i] = true
                }
            }
        }
    }
}

// MARK: - Statistic View Component
struct StatisticView: View {
    let number: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(number)
                .font(.system(size: 48, weight: .black, design: .rounded))
                .foregroundColor(color)
            
            Text(label)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 20)
    }
}

// MARK: - Victory Position Screen (Custom)
struct VictoryPositionScreen: View {
    let size: CGSize
    let onContinue: () -> Void
    @State private var contentOpacity = 0.0
    @State private var showVictoryElements = [false, false, false, false, false]
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    
    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                // Progress indicator
                HStack {
                    Spacer()
                    ProgressDots(current: 6, total: 10)
                        .padding(.top, proxy.safeAreaInsets.top + 10)
                        .padding(.trailing, 20)
                }
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 30) {
                        Spacer().frame(height: 20)
                        
                        // Title
                        VStack(spacing: 12) {
                            Text("THE GAME CHANGER")
                                .font(.system(size: 20, weight: .black))
                                .foregroundColor(.yellow)
                                .opacity(contentOpacity)
                            
                            Text("You're not fighting FOR victory...")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                                .opacity(contentOpacity)
                        }
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                        
                        // Victory Elements (non-clickable visual presentation)
                        VStack(spacing: 20) {
                            if showVictoryElements[0] {
                                VictoryStatement(
                                    icon: "cross.fill",
                                    text: "Jesus already won",
                                    color: .yellow
                                )
                            }
                            
                            if showVictoryElements[1] {
                                VictoryStatement(
                                    icon: "shield.slash.fill",
                                    text: "The enemy is defeated",
                                    color: .green
                                )
                            }
                            
                            if showVictoryElements[2] {
                                Text("You fight FROM victory")
                                    .font(.system(size: 28, weight: .black, design: .rounded))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(LinearGradient(
                                                colors: [.purple, .blue],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ).opacity(0.3))
                                    )
                                    .scaleEffect(1.05)
                            }
                            
                            if showVictoryElements[3] {
                                VictoryStatement(
                                    icon: "flame.fill",
                                    text: "You have authority",
                                    color: .orange
                                )
                            }
                            
                            if showVictoryElements[4] {
                                VictoryStatement(
                                    icon: "hands.sparkles.fill",
                                    text: "Greater is He in you",
                                    color: .blue
                                )
                            }
                        }
                        .padding(.horizontal, 30)
                        
                        Spacer(minLength: 100)
                    }
                }
                
                // Continue button
                ShimmerButton(
                    colors: [.purple, .blue],
                    buttonTitle: "I claim this victory →",
                    action: onContinue
                )
                .frame(width: size.width * 0.85, height: 54)
                .padding(.bottom, proxy.safeAreaInsets.bottom + 30)
                .opacity(showVictoryElements[4] ? 1 : 0.3)
                .disabled(!showVictoryElements[4])
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .background(
                ZStack {
                    Image(subscriptionStore.onboardingBGImage)
                        .resizable()
                        .scaledToFill()
                        .edgesIgnoringSafeArea(.all)
                    Color.black.opacity(0.4)
                        .edgesIgnoringSafeArea(.all)
                }
            )
        }
        .onAppear {
            animateContent()
        }
    }
    
    private func animateContent() {
        withAnimation(.easeIn(duration: 0.6)) {
            contentOpacity = 1.0
        }
        
        // Stagger the victory elements
        for i in 0..<5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.4 + 0.8) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                    showVictoryElements[i] = true
                }
            }
        }
    }
}

// MARK: - Victory Statement Component
struct VictoryStatement: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(color)
                .frame(width: 30)
            
            Text(text)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
            
            Spacer()
        }
        .padding(.horizontal, 5)
        .transition(.move(edge: .leading).combined(with: .opacity))
    }
}

// MARK: - Two Paths Visual Screen
struct TwoPathsScreen: View {
    let size: CGSize
    let onContinue: () -> Void
    @State private var contentOpacity = 0.0
    @State private var selectedPath: Int? = nil
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    
    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                // Progress indicator
                HStack {
                    Spacer()
                    ProgressDots(current: 7, total: 10)
                        .padding(.top, proxy.safeAreaInsets.top + 10)
                        .padding(.trailing, 20)
                }
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 30) {
                        Spacer().frame(height: 20)
                        
                        // Title
                        VStack(spacing: 8) {
                            Text("Two Paths. Every Morning.")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text("Which will you choose today?")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                        .opacity(contentOpacity)
                        
                        // Two Paths Visualization
                        HStack(spacing: 20) {
                            // Path 1 - Destructive
                            PathCard(
                                title: "Path 1",
                                subtitle: "React",
                                items: [
                                    "Wake anxious",
                                    "Spiral in worry",
                                    "Feel defeated"
                                ],
                                color: .red,
                                isSelected: selectedPath == 1,
                                action: { selectedPath = 1 }
                            )
                            
                            // Path 2 - Victory
                            PathCard(
                                title: "Path 2",
                                subtitle: "Respond",
                                items: [
                                    "Declare promises",
                                    "Walk in authority",
                                    "Live in victory"
                                ],
                                color: .green,
                                isSelected: selectedPath == 2,
                                action: { selectedPath = 2 }
                            )
                        }
                        .padding(.horizontal, 20)
                        .opacity(contentOpacity)
                        
                        Spacer(minLength: 100)
                    }
                }
                
                // Continue button
                ShimmerButton(
                    colors: selectedPath == 2 ? [.green, .blue] : [.gray, .gray],
                    buttonTitle: selectedPath == 2 ? "I choose Path 2 →" : "Choose your path",
                    action: onContinue
                )
                .frame(width: size.width * 0.85, height: 54)
                .padding(.bottom, proxy.safeAreaInsets.bottom + 30)
                .opacity(selectedPath == 2 ? 1 : 0.5)
                .disabled(selectedPath != 2)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .background(
                ZStack {
                    Image(subscriptionStore.onboardingBGImage)
                        .resizable()
                        .scaledToFill()
                        .edgesIgnoringSafeArea(.all)
                    Color.black.opacity(0.4)
                        .edgesIgnoringSafeArea(.all)
                }
            )
        }
        .onAppear {
            withAnimation(.easeIn(duration: 0.8)) {
                contentOpacity = 1.0
            }
        }
    }
}

// MARK: - Path Card Component
struct PathCard: View {
    let title: String
    let subtitle: String
    let items: [String]
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                
                Text(subtitle)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(color)
                
                Divider()
                    .background(color.opacity(0.3))
                
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(items, id: \.self) { item in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(color.opacity(0.6))
                                .frame(width: 6, height: 6)
                            Text(item)
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, minHeight: 200)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? color.opacity(0.2) : Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? color : Color.white.opacity(0.1), lineWidth: 2)
                    )
            )
        }
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
    }
}