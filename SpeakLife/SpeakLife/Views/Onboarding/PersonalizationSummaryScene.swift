//
//  PersonalizationSummaryScene.swift
//  SpeakLife
//
//  Personalization summary screen to show value after category selection
//

import SwiftUI

struct PersonalizationSummaryScene: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @EnvironmentObject var appState: AppState
    
    let size: CGSize
    let selectedCategories: [DeclarationCategory]
    let callBack: (() -> Void)
    
    @State private var contentOpacity = 0.0
    @State private var checkmarksOpacity = 0.0
    @State private var buttonOpacity = 0.0
    
    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                // Progress dots at top
                HStack {
                    Spacer()
                    ProgressDots(current: 3, total: 5)
                        .padding(.top, proxy.safeAreaInsets.top + 10)
                        .padding(.trailing, 20)
                }
                .frame(width: proxy.size.width)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: proxy.size.height < 700 ? 20 : 30) {
                        Spacer().frame(height: proxy.size.height < 700 ? 20 : 40)
                        
                        // Header
                        VStack(spacing: proxy.size.height < 700 ? 12 : 16) {
                            Text("Your SpeakLife Journey Is Ready")
                                .font(.system(size: proxy.size.height < 700 ? 26 : 30, weight: .bold, design: .rounded))
                                .multilineTextAlignment(.center)
                                .foregroundColor(.white)
                                .shadow(radius: 3)
                                .opacity(contentOpacity)
                            
                            Text("Jesus is ready to walk you through:")
                                .font(.system(size: proxy.size.height < 700 ? 16 : 18, weight: .medium))
                                .multilineTextAlignment(.center)
                                .foregroundColor(.white.opacity(0.9))
                                .opacity(contentOpacity)
                        }
                        .padding(.horizontal, 30)
                        
                        // Selected categories display
                        VStack(spacing: proxy.size.height < 700 ? 8 : 12) {
                            ForEach(Array(selectedCategories.prefix(4)), id: \.self) { category in
                                HStack(spacing: 12) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(.green)
                                    
                                    Text(getCategoryDisplayText(category))
                                        .font(.system(size: proxy.size.height < 700 ? 15 : 16, weight: .medium))
                                        .foregroundColor(.white.opacity(0.9))
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 30)
                                .opacity(checkmarksOpacity)
                            }
                        }
                        
                        // Value proposition
                        VStack(spacing: proxy.size.height < 700 ? 16 : 20) {
                            Divider()
                                .background(Color.white.opacity(0.3))
                                .frame(width: size.width * 0.3)
                                .opacity(contentOpacity)
                            
                            Text("Your plan includes:")
                                .font(.system(size: proxy.size.height < 700 ? 18 : 20, weight: .semibold))
                                .foregroundColor(.white)
                                .opacity(contentOpacity)
                            
                            VStack(spacing: proxy.size.height < 700 ? 10 : 12) {
                                OnboardingFeatureRow(
                                    icon: "checkmark.circle.fill",
                                    text: "Personalized declarations",
                                    isCompact: proxy.size.height < 700
                                )
                                
                                OnboardingFeatureRow(
                                    icon: "checkmark.circle.fill",
                                    text: "Guided audio",
                                    isCompact: proxy.size.height < 700
                                )
                                
                                OnboardingFeatureRow(
                                    icon: "checkmark.circle.fill",
                                    text: "Breakthrough prayers",
                                    isCompact: proxy.size.height < 700
                                )
                                
                                OnboardingFeatureRow(
                                    icon: "checkmark.circle.fill",
                                    text: "Daily emotional resets",
                                    isCompact: proxy.size.height < 700
                                )
                            }
                            .opacity(checkmarksOpacity)
                        }
                        .padding(.horizontal, 30)
                        
                        Spacer().frame(height: proxy.size.height < 700 ? 80 : 120)
                    }
                }
                
                // Continue button
                VStack(spacing: proxy.size.height < 700 ? 10 : 15) {
                    ShimmerButton(
                        colors: [.blue, .purple],
                        buttonTitle: "Continue →",
                        action: {
                            AnalyticsService.shared.track("PersonalizationSummaryDone", parameters: [
                                "categories_count": selectedCategories.count,
                                "categories": selectedCategories.map { $0.rawValue }.joined(separator: ",")
                            ])
                            callBack()
                        }
                    )
                    .frame(width: size.width * 0.85, height: proxy.size.height < 700 ? 48 : 54)
                    .opacity(buttonOpacity)
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
            AnalyticsService.shared.track("PersonalizationSummaryShown")
        }
    }
    
    private func getCategoryDisplayText(_ category: DeclarationCategory) -> String {
        switch category {
        case .anxiety: return "Peace from worry"
        case .faith: return "Stronger faith"
        case .confidence: return "Renewed confidence"
        case .fear: return "Freedom from fear"
        case .health: return "Health and healing"
        case .joy: return "Joy and happiness"
        case .rest: return "Rest and peace"
        case .marriage: return "Marriage breakthrough"
        case .love: return "Love and relationships"
        case .hope: return "Hope and encouragement"
        default: return category.displayName
        }
    }
    
    private func animateContent() {
        withAnimation(.easeIn(duration: 0.8)) {
            contentOpacity = 1.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.easeIn(duration: 0.8)) {
                checkmarksOpacity = 1.0
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeIn(duration: 0.6)) {
                buttonOpacity = 1.0
            }
        }
    }
}

struct OnboardingFeatureRow: View {
    let icon: String
    let text: String
    let isCompact: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: isCompact ? 16 : 18))
                .foregroundColor(.green)
            
            Text(text)
                .font(.system(size: isCompact ? 14 : 15, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
            
            Spacer()
        }
        .padding(.horizontal, 20)
    }
}