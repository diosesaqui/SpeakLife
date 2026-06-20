//
//  PersonalizedFeedSection.swift
//  SpeakLife
//
//  AI-powered personalized content feed for the home screen
//

import SwiftUI

struct PersonalizedFeedSection: View {
    @StateObject private var recommendationEngine = RecommendationEngine.shared
    @StateObject private var categorizationService = ContentCategorizationService.shared
    @EnvironmentObject var declarationStore: DeclarationViewModel
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @Environment(\.presentationMode) var presentationMode
    
    @State private var personalizedCategories: [PersonalizedCategory] = []
    @State private var todayRecommendations: [Declaration] = []
    @State private var isLoading = true
    @State private var showPremiumUpgrade = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text("For You Today")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("AI-curated for your spiritual journey")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                if !subscriptionStore.isAIEnabled {
                    Button("✨ Premium") {
                        showPremiumUpgrade = true
                    }
                    .font(.caption)
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, 6)
                    .background(DS.Gradient.gold)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.25), lineWidth: 1)
                    )
                    .shadow(color: DS.Palette.gold.opacity(0.45), radius: 8, x: 0, y: 3)
                    .buttonStyle(.dsPressable(feel: .tapSolid))
                }
            }
            .padding(.horizontal)
            
            if isLoading {
                LoadingStateView()
            } else {
                // AI-generated personal categories
                if !personalizedCategories.isEmpty {
                    PersonalCategoriesScrollView(categories: personalizedCategories)
                }
                
                // Today's AI recommendations
                if !todayRecommendations.isEmpty {
                    TodayRecommendationsSection(recommendations: todayRecommendations)
                }
                
                // AI insights section
                AIInsightsSection()
            }
        }
        .padding(.vertical)
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .padding(.horizontal)
        .task {
            await loadPersonalizedContent()
        }
        .sheet(isPresented: $showPremiumUpgrade) {
            PremiumUpgradeView()
        }
    }
    
    private func getAvailableDeclarations() async -> [Declaration] {
        // Access all declarations from the declaration store
        return declarationStore.allAvailableDeclarations
    }
    
    private func loadPersonalizedContent() async {
        if subscriptionStore.isAIEnabled {
            do {
                // Full AI features for premium users
                async let categories = recommendationEngine.createPersonalizedCategories()
                
                // Pass real declarations to the AI engine
                let availableDeclarations = await getAvailableDeclarations()
                async let recommendations = recommendationEngine.generatePersonalizedFeed(from: availableDeclarations)
                
                let (loadedCategories, loadedRecommendations) = await (categories, recommendations)
                
                updateUI(categories: loadedCategories, recommendations: loadedRecommendations)
            }
        } else {
            // Limited AI features for free users
            let limitedRecommendations = await generateLimitedRecommendations()
            
            updateUI(categories: [], recommendations: Array(limitedRecommendations.prefix(2)))
        }
    }
    
    @MainActor
    private func updateUI(categories: [PersonalizedCategory], recommendations: [Declaration]) {
        self.personalizedCategories = categories
        self.todayRecommendations = recommendations
        self.isLoading = false
        
        // Track AI section view
        EnhancedAnalyticsService.shared.trackContextualUsage(
            timeOfDay: Calendar.current.component(.hour, from: Date()),
            dayOfWeek: Calendar.current.component(.weekday, from: Date()),
            sessionType: "ai_personalized_feed",
            duration: 0
        )
    }
    
    private func generateLimitedRecommendations() async -> [Declaration] {
        // For free users, provide basic personalized recommendations
        let userBehavior = EnhancedAnalyticsService.shared.userBehaviorProfile
        let topCategory = userBehavior.topCategories.max(by: { $0.value < $1.value })?.key ?? "faith"
        
        // Return declarations from user's most engaged category
        return declarationStore.declarations.filter { declaration in
            declaration.category.rawValue == topCategory
        }.prefix(3).map { $0 }
    }
}

// MARK: - Supporting Views

struct PersonalCategoriesScrollView: View {
    let categories: [PersonalizedCategory]
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text("Your Spiritual Focus Areas")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.sm) {
                    ForEach(categories) { category in
                        PersonalCategoryCard(category: category)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct PersonalCategoryCard: View {
    let category: PersonalizedCategory
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack {
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(category.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .lineLimit(2)
                    
                    Text(category.userReasonExplanation)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(isExpanded ? nil : 2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
                
                // Confidence indicator
                ConfidenceIndicator(confidence: category.confidence)
            }
            
            HStack {
                ForEach(category.spiritualFocus.prefix(3), id: \.rawValue) { focus in
                    Text(focus.rawValue.capitalized)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.2))
                        .foregroundColor(.white)
                        .cornerRadius(4)
                }
                
                Spacer()
                
                Text("\(category.contentIds.count) items")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(DS.Spacing.sm)
        .frame(width: 200)
        .frame(minHeight: 100)
        .dsGlass(cornerRadius: DS.Radius.md)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.3)) {
                isExpanded.toggle()
            }
        }
    }
}

struct TodayRecommendationsSection: View {
    let recommendations: [Declaration]
    @EnvironmentObject var declarationStore: DeclarationViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text("Recommended for Your Journey")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal)
            
            ForEach(recommendations.prefix(3)) { declaration in
                RecommendedDeclarationRow(
                    declaration: declaration,
                    onTap: {
                        
                        // Navigate to the specific declaration by loading its category first
                        navigateToDeclaration(declaration)
                        
                        // Track AI recommendation acceptance
                        EnhancedAnalyticsService.shared.trackRecommendationInteraction(
                            recommendationId: declaration.id,
                            accepted: true,
                            reason: "ai_personalized_feed",
                            confidence: 0.8
                        )
                    }
                )
            }
        }
    }
    
    private func navigateToDeclaration(_ declaration: Declaration) {
        
        // Haptic feedback for selection
        Juice.play(.tapSolid)
        
        // Try multiple dismissal approaches since CategoryChooserView can be presented in different ways
        DispatchQueue.main.async {
            // First approach: Use declarationStore to trigger selection and navigation
            self.declarationStore.choose(declaration.category) { success in
                DispatchQueue.main.async {
                    if success {
                        // Find and select the specific declaration
                        if let index = self.declarationStore.declarations.firstIndex(where: { $0.id == declaration.id }) {
                            self.declarationStore.selectedTab = index
                            print("✅ Found declaration at index \(index)")
                        } else {
                            // Fallback: set the declaration text directly
                            self.declarationStore.setDeclaration(declaration.text, category: declaration.category.rawValue)
                            print("✅ Set declaration directly as fallback")
                        }
                    } else {
                        // Warning: 
                        print("⚠️ Failed to load category, using fallback")
                        self.declarationStore.setDeclaration(declaration.text, category: declaration.category.rawValue)
                    }
                    
                    // Try different dismissal methods
                    
                    // Method 1: presentationMode
                    self.presentationMode.wrappedValue.dismiss()
                    
                    // Method 2: Try to dismiss via notification (for different presentation styles)
                    NotificationCenter.default.post(name: NSNotification.Name("DismissCategoryChooser"), object: nil)
                    
                    print("✅ Completed AI recommendation navigation")
                }
            }
        }
    }
}

struct RecommendedDeclarationRow: View {
    let declaration: Declaration
    let onTap: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack {
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(declaration.text)
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                Button(action: {}) {
                    Image(systemName: "arrow.right.circle.fill")
                        .foregroundColor(.white.opacity(0.8))
                        .font(.title3)
                }
                .disabled(true) // Visual only since parent has tap gesture
            }
            
            // Category tags
            HStack {
                ForEach(declaration.mlCategories.prefix(2), id: \.rawValue) { category in
                    Text(category.rawValue.capitalized)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.2))
                        .foregroundColor(.white)
                        .cornerRadius(4)
                }
                
                Spacer()
                
                Text("AI Match: 85%")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(DS.Spacing.sm)
        .background(Color.white.opacity(isPressed ? 0.2 : 0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .cornerRadius(8)
        .padding(.horizontal)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onTapGesture {
            
            // Visual feedback
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = false
                }
                
                // Call the action
                onTap()
            }
        }
    }
}

struct AIInsightsSection: View {
    @State private var insights: [PersonalInsight] = []
    
    var body: some View {
        if !insights.isEmpty {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text("Spiritual Insights")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal)
                
                ForEach(insights.indices, id: \.self) { index in
                    AIInsightCard(insight: insights[index])
                }
            }
            .task {
                insights = EnhancedAnalyticsService.shared.getPersonalizedInsights()
            }
        }
    }
}

struct AIInsightCard: View {
    let insight: PersonalInsight
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(insight.contextualMessage)
                .font(.subheadline)
                .foregroundColor(.white)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            
            if let suggestion = insight.applicationSuggestion {
                Text("💭 \(suggestion)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            HStack {
                Text(insight.connectionToJourney)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                
                Spacer()
                
                ConfidenceIndicator(confidence: insight.confidence)
            }
        }
        .padding(10)
        .dsGlass(cornerRadius: DS.Radius.sm)
        .padding(.horizontal)
    }
}

struct ConfidenceIndicator: View {
    let confidence: Double
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5) { index in
                Circle()
                    .fill(confidence > Double(index) * 0.2 ? Color.white : Color.white.opacity(0.3))
                    .frame(width: 4, height: 4)
            }
        }
    }
}

struct LoadingStateView: View {
    var body: some View {
        VStack(spacing: DS.Spacing.sm) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(0.8)
            
            Text("Personalizing your spiritual journey...")
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .lineLimit(nil)
        }
        .frame(height: 100)
        .frame(maxWidth: .infinity)
    }
}

struct PremiumUpgradeView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Text("✨ Unlock AI-Powered Spirituality")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                AIFeatureRow(icon: "🎯", title: "Personalized Categories", description: "AI creates unique spiritual focus areas just for you")
                AIFeatureRow(icon: "🧠", title: "Smart Recommendations", description: "Content that matches your spiritual season and growth")
                AIFeatureRow(icon: "⏰", title: "Optimal Timing", description: "Notifications sent at your most receptive moments")
                AIFeatureRow(icon: "💡", title: "Personal Insights", description: "AI-powered spiritual guidance for your journey")
            }
            
            Button("Upgrade to Premium") {
                // Handle premium upgrade
                dismiss()
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(DS.Gradient.brand)
            .cornerRadius(12)
            .buttonStyle(.dsPressable(feel: .tapSolid))
            
            Button("Maybe Later") {
                dismiss()
            }
            .foregroundColor(.secondary)
        }
        .padding()
    }
}

struct AIFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            Text(icon)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
    }
}
