//
//  CombinedPersonalizationScene.swift
//  SpeakLife
//
//  Merged onboarding scene combining hook + personalization
//

import SwiftUI

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
                        ProgressDots(current: 1, total: 5)
                            .padding(.top, proxy.safeAreaInsets.top + 10)
                            .padding(.trailing, 20)
                    }
                    .frame(width: proxy.size.width)
                    
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: proxy.size.height < 700 ? 15 : 25) {
                            Spacer().frame(height: proxy.size.height < 700 ? 10 : 20)
                            
                            // HOOK SECTION - Appears first
                            VStack(spacing: proxy.size.height < 700 ? 10 : 15) {
                                Text("What Brings You to SpeakLife?")
                                    .font(.system(size: proxy.size.height < 700 ? 26 : 30, weight: .bold, design: .rounded))
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.white)
                                    .shadow(radius: 3)
                                    .padding(.horizontal)
                                    .lineLimit(3)
                                    .minimumScaleFactor(0.65)
                                    .opacity(titleOpacity)
                                    .animation(.easeIn(duration: 0.8), value: titleOpacity)
                                
                                Text("Join 100,000+ believers who've found breakthrough")
                                    .font(.system(size: proxy.size.height < 700 ? 15 : 17, weight: .medium))
                                    .foregroundColor(.white.opacity(0.9))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 20)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.7)
                                    .opacity(titleOpacity)
                                    .animation(.easeIn(duration: 0.8).delay(0.3), value: titleOpacity)
                            }
                            
                            // PERSONALIZATION SECTION - Appears after delay
                            VStack(spacing: proxy.size.height < 700 ? 12 : 20) {
                                Divider()
                                    .background(Color.white.opacity(0.3))
                                    .frame(width: size.width * 0.3)
                                    .opacity(categoriesOpacity)
                                
//                                Text("What brings you here today?")
//                                    .font(.system(size: proxy.size.height < 700 ? 20 : 24, weight: .semibold))
//                                    .foregroundColor(.white)
//                                    .minimumScaleFactor(0.7)
//                                    .opacity(categoriesOpacity)
                                
                                Text("Select all that apply (you can change later)")
                                    .font(.system(size: proxy.size.height < 700 ? 13 : 14))
                                    .foregroundColor(.white.opacity(0.7))
                                    .minimumScaleFactor(0.8)
                                    .opacity(categoriesOpacity)
                                
                                // Simplified category grid - show only top categories
                                SimplifiedCategoryGrid(viewModel: viewModel, screenHeight: proxy.size.height)
                                    .frame(width: size.width * 0.9)
                                    .opacity(categoriesOpacity)
                                    .animation(.easeIn(duration: 0.6).delay(0.8), value: categoriesOpacity)
                            }
                            
                            Spacer(minLength: proxy.size.height < 700 ? 60 : 100)
                        }
                    }
                    
                    // CTA Button - Always visible at bottom
                    VStack(spacing: proxy.size.height < 700 ? 10 : 15) {
                        // Dynamic button text based on selection
                        ShimmerButton(
                            colors: [.blue, .purple],
                            buttonTitle: buttonTitle,
                            action: {
                                if viewModel.selectedExperiences.isEmpty {
                                    // If no selection, select default and continue
                                    viewModel.selectedExperiences = [.anxiety]
                                }
                                
                                // Track all selected categories for personalization
                                for category in viewModel.selectedExperiences {
                                    UserPreferencesTracker.shared.trackCategorySelection(category.rawValue)
                                }
                                
                                AnalyticsService.shared.track("CombinedOnboardingComplete", parameters: [
                                    "categories_selected": viewModel.selectedExperiences.count,
                                    "categories": viewModel.selectedExperiences.map { $0.rawValue }.joined(separator: ",")
                                ])
                                callBack()
                            }
                        )
                        .frame(width: size.width * 0.85, height: proxy.size.height < 700 ? 48 : 54)
                        
                        // Skip option (subtle)
                        Button("Skip for now") {
                            viewModel.selectedExperiences = [.general]
                            // Track general preference when skipping
                            UserPreferencesTracker.shared.trackCategorySelection("general")
                            callBack()
                        }
                        .font(.system(size: proxy.size.height < 700 ? 13 : 14))
                        .foregroundColor(.white.opacity(0.5))
                    }
                    .padding(.bottom, proxy.safeAreaInsets.bottom + (proxy.size.height < 700 ? 20 : 30))
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
            AnalyticsService.shared.track("CombinedPersonalizationShown")
        }
    }
    
    private var buttonTitle: String {
        if viewModel.selectedExperiences.isEmpty {
            return "Continue →"
        } else {
            return "Start My Transformation →"
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
    let screenHeight: CGFloat
    let impactLight = UIImpactFeedbackGenerator(style: .light)
    
    // Top 10 categories based on analytics data
    var topCategories: [DeclarationCategory] {
        let top10Categories: [DeclarationCategory] = [
            .faith,        // 144 users - most popular
            .anxiety,      // 140 users
            .joy,          // 118 users  
            .rest,         // 115 users
            .health,       // 113 users
            .confidence,   // 106 users
            .fear,         // 103 users
            .marriage,     // 60 users
            .love,         // 13 users
            .hope          // 11 users
        ]
        
        // Show all 10 categories regardless of screen size for better personalization
        return top10Categories
    }
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: screenHeight < 700 ? 6 : 8),
            GridItem(.flexible(), spacing: screenHeight < 700 ? 6 : 8)
        ], spacing: screenHeight < 700 ? 6 : 8) {
            ForEach(topCategories, id: \.self) { category in
                CategoryPill(
                    category: category,
                    isSelected: viewModel.selectedExperiences.contains(category),
                    isCompact: screenHeight < 700
                ) {
                    Juice.play(.tapLight)
                    viewModel.selectExperience(category)
                }
            }
        }
    }
}

struct CategoryPill: View {
    let category: DeclarationCategory
    let isSelected: Bool
    let isCompact: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: isCompact ? 4 : 6) {
                Image(systemName: category.iconName)
                    .font(.system(size: isCompact ? 16 : 18))
                    .frame(width: isCompact ? 18 : 20)
                
                Text(category.displayName)
                    .font(.system(size: isCompact ? 13 : 14, weight: .medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .minimumScaleFactor(0.65)
            }
            .padding(.horizontal, isCompact ? 10 : 12)
            .padding(.vertical, isCompact ? 10 : 12)
            .frame(maxWidth: .infinity, minHeight: isCompact ? 44 : 48)
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
