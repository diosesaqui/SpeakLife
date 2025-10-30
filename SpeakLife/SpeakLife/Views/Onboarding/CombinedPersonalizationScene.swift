//
//  CombinedPersonalizationScene.swift
//  SpeakLife
//
//  Merged onboarding scene combining hook + personalization
//

import SwiftUI
import FirebaseAnalytics

struct CombinedPersonalizationScene: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @EnvironmentObject var appState: AppState
    
    let size: CGSize
    @ObservedObject var viewModel: ImprovementViewModel
    let callBack: (() -> Void)
    
    @State private var showCategories = false
    @State private var titleOpacity = 0.0
    @State private var categoriesOpacity = 0.0
    
    var body: some View {
        GeometryReader { proxy in
                
                VStack(spacing: 0) {
                    // Progress dots at top
                    HStack {
                        Spacer()
                        ProgressDots(current: 0, total: 3)
                            .padding(.top, 50)
                            .padding(.trailing, 20)
                    }
                    .frame(width: proxy.size.width)
                    
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 25) {
                            Spacer().frame(height: 20)
                            
                            // HOOK SECTION - Appears first
                            VStack(spacing: 15) {
                                Text("Struggling with Anxiety, Fear, or Doubt?")
                                    .font(.system(size: 30, weight: .bold, design: .rounded))
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.white)
                                    .shadow(radius: 3)
                                    .padding(.horizontal)
                                    .lineLimit(3)
                                    .minimumScaleFactor(0.8)
                                    .opacity(titleOpacity)
                                    .animation(.easeIn(duration: 0.8), value: titleOpacity)
                                
                                Text("Join 50,000+ believers who've found breakthrough")
                                    .font(.system(size: 17, weight: .medium))
                                    .foregroundColor(.white.opacity(0.9))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 20)
                                    .lineLimit(2)
                                    .opacity(titleOpacity)
                                    .animation(.easeIn(duration: 0.8).delay(0.3), value: titleOpacity)
                            }
                            
                            // PERSONALIZATION SECTION - Appears after delay
                            VStack(spacing: 20) {
                                Divider()
                                    .background(Color.white.opacity(0.3))
                                    .frame(width: size.width * 0.3)
                                    .opacity(categoriesOpacity)
                                
                                Text("What brings you here today?")
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundColor(.white)
                                    .opacity(categoriesOpacity)
                                
                                Text("Select all that apply (you can change later)")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.7))
                                    .opacity(categoriesOpacity)
                                
                                // Simplified category grid - show only top categories
                                SimplifiedCategoryGrid(viewModel: viewModel)
                                    .frame(width: size.width * 0.85)
                                    .opacity(categoriesOpacity)
                                    .animation(.easeIn(duration: 0.6).delay(0.8), value: categoriesOpacity)
                            }
                            
                            Spacer(minLength: 100)
                        }
                    }
                    
                    // CTA Button - Always visible at bottom
                    VStack(spacing: 15) {
                        // Dynamic button text based on selection
                        ShimmerButton(
                            colors: [.blue, .purple],
                            buttonTitle: buttonTitle,
                            action: {
                                if viewModel.selectedExperiences.isEmpty {
                                    // If no selection, select default and continue
                                    viewModel.selectedExperiences = [.anxiety]
                                }
                                Analytics.logEvent("CombinedOnboardingComplete", parameters: [
                                    "categories_selected": viewModel.selectedExperiences.count
                                ])
                                callBack()
                            }
                        )
                        .frame(width: size.width * 0.85, height: 54)
                        
                        // Skip option (subtle)
                        Button("Skip for now") {
                            viewModel.selectedExperiences = [.general]
                            callBack()
                        }
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.5))
                    }
                    .padding(.bottom, 40)
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
            Analytics.logEvent("CombinedPersonalizationShown", parameters: nil)
        }
    }
    
    private var buttonTitle: String {
        if viewModel.selectedExperiences.isEmpty {
            return "Continue →"
        } else if viewModel.selectedExperiences.count == 1 {
            return "Get My Breakthrough Plan →"
        } else {
            return "Get My \(viewModel.selectedExperiences.count) Breakthrough Plans →"
        }
    }
    
    private func animateContent() {
        withAnimation {
            titleOpacity = 1.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation {
                categoriesOpacity = 1.0
            }
        }
    }
}

// Simplified category selection - only show most popular
struct SimplifiedCategoryGrid: View {
    @ObservedObject var viewModel: ImprovementViewModel
    let impactLight = UIImpactFeedbackGenerator(style: .light)
    
    // Top categories based on user data
    let topCategories: [DeclarationCategory] = [
        .anxiety,
        .fear,
        .faith,
        .health,
        .marriage,
        .joy,
        .rest,
        .confidence
    ]
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ], spacing: 10) {
            ForEach(topCategories, id: \.self) { category in
                CategoryPill(
                    category: category,
                    isSelected: viewModel.selectedExperiences.contains(category)
                ) {
                    impactLight.impactOccurred()
                    viewModel.selectExperience(category)
                }
            }
        }
    }
}

struct CategoryPill: View {
    let category: DeclarationCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: category.iconName)
                    .font(.system(size: 18))
                    .frame(width: 20)
                
                Text(category.displayName)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(isSelected ? Color.blue : Color.white.opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 25)
                            .stroke(isSelected ? Color.blue : Color.white.opacity(0.3), lineWidth: 1)
                    )
            )
            .foregroundColor(isSelected ? .white : .white.opacity(0.9))
        }
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
    }
}


struct ProgressDots: View {
    let current: Int
    let total: Int
    
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { index in
                Circle()
                    .fill(index <= current ? Color.white : Color.white.opacity(0.3))
                    .frame(width: 6, height: 6)
            }
        }
    }
}

// Extension for icon mapping
extension DeclarationCategory {
    var iconName: String {
        switch self {
        case .anxiety: return "brain.head.profile"
        case .fear: return "shield.slash"
        case .faith: return "hands.sparkles"
        case .health: return "heart.circle"
        case .marriage: return "heart.fill"
        case .joy: return "face.smiling"
        case .rest: return "moon.fill"
        case .confidence: return "person.fill.checkmark"
        case .hope: return "sun.max.fill"
        case .wealth: return "dollarsign.circle"
        case .wisdom: return "lightbulb.fill"
        case .grace: return "sparkles"
        case .addiction: return "arrow.uturn.forward"
        case .godsprotection: return "shield.fill"
        case .hardtimes: return "cloud.rain"
        case .parenting: return "figure.2"
        case .identity: return "person.circle"
        case .general: return "star.fill"
        case .praise: return "hands.clap.fill"
        case .love: return "heart.circle.fill"
        case .gratitude: return "gift.fill"
        case .warfare: return "shield.lefthalf.filled"
        case .miracles: return "sparkle"
        case .favor: return "star.circle.fill"
        case .work: return "briefcase.fill"
        case .friendship: return "person.2.fill"
        default: return "star.fill"
        }
    }
    
    var displayName: String {
        switch self {
        case .anxiety: return "Anxiety & Worry"
        case .fear: return "Fear & Doubt"
        case .faith: return "Strengthen Faith"
        case .health: return "Health & Healing"
        case .marriage: return "Marriage"
        case .joy: return "Joy & Happiness"
        case .rest: return "Rest & Peace"
        case .confidence: return "Confidence"
        case .hope: return "Hope"
        case .wealth: return "Financial Breakthrough"
        case .wisdom: return "Wisdom"
        case .grace: return "God's Grace"
        case .addiction: return "Breaking Addiction"
        case .godsprotection: return "God's Protection"
        case .hardtimes: return "Hard Times"
        case .parenting: return "Parenting"
        case .identity: return "Identity in Christ"
        case .general: return "General"
        case .praise: return "Praise & Worship"
        case .love: return "Love"
        case .gratitude: return "Gratitude"
        case .warfare: return "Spiritual Warfare"
        case .miracles: return "Miracles"
        case .favor: return "God's Favor"
        case .work: return "Work & Career"
        case .friendship: return "Relationships"
        case .innerHealing: return "Inner Healing"
        case .spiritualGrowth: return "Spiritual Growth"
        default: return self.rawValue.capitalized
        }
    }
}
