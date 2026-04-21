//
//  AIEnhancedDeclarationView.swift
//  SpeakLife
//
//  AI enhancements for declaration content view
//

import SwiftUI

struct AIEnhancedDeclarationView: View {
    let declaration: Declaration
    @StateObject private var recommendationEngine = RecommendationEngine.shared
    @StateObject private var categorizationService = ContentCategorizationService.shared
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    
    @State private var personalInsight: PersonalInsight?
    @State private var relatedDeclarations: [Declaration] = []
    @State private var aiCategories: ContentCategories?
    @State private var showAIFeatures = false
    
    var body: some View {
        VStack(spacing: 16) {
            if subscriptionStore.isPremium && showAIFeatures {
                // AI-powered sections for premium users
                if let insight = personalInsight {
                    PersonalInsightCard(insight: insight)
                        .transition(.opacity.combined(with: .scale))
                }
                
                if let categories = aiCategories {
                    AICategoriesView(categories: categories)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                
                if !relatedDeclarations.isEmpty {
                    RelatedDeclarationsSection(declarations: relatedDeclarations)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            } else if !subscriptionStore.isPremium {
                // Teaser for free users
                AIFeaturesTeaser()
            }
        }
        .onAppear {
            loadAIEnhancements()
        }
        .onChange(of: declaration.id) { _ in
            resetAndLoadAIEnhancements()
        }
    }
    
    private func loadAIEnhancements() {
        guard subscriptionStore.isPremium else { return }
        
        Task {
            async let insight = recommendationEngine.generatePersonalInsight(for: declaration)
            async let related = recommendationEngine.getRelatedContent(for: declaration)
            async let categories = categorizationService.categorizeContent(declaration.text)
            
            let (loadedInsight, loadedRelated, loadedCategories) = await (insight, related, categories)
            
            DispatchQueue.main.async {
                self.personalInsight = loadedInsight
                self.relatedDeclarations = loadedRelated
                self.aiCategories = loadedCategories
                
                withAnimation(.easeInOut(duration: 0.5)) {
                    self.showAIFeatures = true
                }
            }
        }
        
        // Track AI content interaction
        EnhancedAnalyticsService.shared.trackContentResonance(
            contentId: declaration.id,
            declaration: declaration,
            action: .viewed,
            engagementScore: 0.5
        )
    }
    
    private func resetAndLoadAIEnhancements() {
        withAnimation(.easeOut(duration: 0.3)) {
            showAIFeatures = false
            personalInsight = nil
            relatedDeclarations = []
            aiCategories = nil
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            loadAIEnhancements()
        }
    }
}

// MARK: - Supporting Views

struct PersonalInsightCard: View {
    let insight: PersonalInsight
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                
                Text("Personal Application")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: { 
                    withAnimation(.spring()) {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
            }
            
            Text(insight.contextualMessage)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    if let suggestion = insight.applicationSuggestion {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "hand.point.right.fill")
                                .foregroundColor(.blue)
                                .font(.caption)
                            
                            Text("Try this: \(suggestion)")
                                .font(.callout)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let scripture = insight.supportingScripture {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "book.fill")
                                .foregroundColor(.purple)
                                .font(.caption)
                            
                            Text(scripture)
                                .font(.callout)
                                .italic()
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack {
                        Text(insight.connectionToJourney)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("AI Confidence: \(Int(insight.confidence * 100))%")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal)
    }
}

struct AICategoriesView: View {
    let categories: ContentCategories
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "tag.fill")
                    .foregroundColor(.blue)
                
                Text("AI Analysis")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(Int(categories.confidence * 100))% confident")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                // Spiritual categories
                ForEach(categories.spiritual, id: \.rawValue) { category in
                    CategoryTag(
                        text: category.displayName,
                        color: .blue,
                        icon: "heart.fill"
                    )
                }
                
                // Emotional tone
                CategoryTag(
                    text: categories.emotional.rawValue.capitalized,
                    color: .purple,
                    icon: "theatermasks.fill"
                )
                
                // Maturity level
                CategoryTag(
                    text: categories.maturity.displayName,
                    color: .green,
                    icon: "figure.walk"
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.05))
        )
        .padding(.horizontal)
    }
}

struct CategoryTag: View {
    let text: String
    let color: Color
    let icon: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            
            Text(text)
                .font(.caption)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.2))
        .foregroundColor(color)
        .cornerRadius(8)
    }
}

struct RelatedDeclarationsSection: View {
    let declarations: [Declaration]
    @EnvironmentObject var declarationStore: DeclarationViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "arrow.triangle.branch")
                    .foregroundColor(.green)
                
                Text("Perfect to Follow With")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("AI suggests")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(declarations) { related in
                        RelatedDeclarationCard(declaration: related)
                            .onTapGesture {
                                navigateToDeclaration(related)
                            }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private func navigateToDeclaration(_ declaration: Declaration) {
        if let index = declarationStore.declarations.firstIndex(where: { $0.id == declaration.id }) {
            declarationStore.selectedTab = index
        }
        
        // Track related content selection
        EnhancedAnalyticsService.shared.trackRecommendationInteraction(
            recommendationId: declaration.id,
            accepted: true,
            reason: "ai_related_content",
            confidence: 0.8
        )
    }
}

struct RelatedDeclarationCard: View {
    let declaration: Declaration
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(declaration.text.prefix(80) + "...")
                .font(.subheadline)
                .foregroundColor(.primary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
            
            HStack {
                ForEach(declaration.mlCategories.prefix(2), id: \.rawValue) { category in
                    Text(category.rawValue.capitalized)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                }
                
                Spacer()
            }
            
            HStack {
                Text("Builds on current theme")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .frame(width: 180, height: 120)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(UIColor.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
    }
}

struct AIFeaturesTeaser: View {
    @State private var showUpgrade = false
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.orange)
                
                Text("AI Insights Available")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("Premium")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.2))
                    .foregroundColor(.orange)
                    .cornerRadius(8)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                    Text("Personal spiritual application")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Image(systemName: "tag.fill")
                        .foregroundColor(.blue)
                    Text("AI content analysis & categorization")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Image(systemName: "arrow.triangle.branch")
                        .foregroundColor(.green)
                    Text("Smart content recommendations")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Button("Unlock AI Features") {
                showUpgrade = true
            }
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.orange)
            .cornerRadius(10)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal)
        .sheet(isPresented: $showUpgrade) {
            PremiumUpgradeView()
        }
    }
}