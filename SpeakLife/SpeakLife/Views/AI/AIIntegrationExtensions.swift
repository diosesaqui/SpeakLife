//
//  AIIntegrationExtensions.swift
//  SpeakLife
//
//  Extensions to integrate AI into existing views seamlessly
//

import SwiftUI

// MARK: - HomeView AI Integration

extension View {
    func withAIPersonalizedFeed() -> some View {
        VStack(spacing: 0) {
            // AI Personalized Feed Section at top
            PersonalizedFeedSection()
            
            // Original content below
            self
        }
    }
}

// MARK: - DeclarationContentView AI Enhancement

extension View {
    func withAIEnhancements(for declaration: Declaration) -> some View {
        VStack(spacing: DS.Spacing.md) {
            // Original content
            self
            
            // AI enhancements below
            AIEnhancedDeclarationView(declaration: declaration)
        }
    }
}

// MARK: - NotificationManager AI Integration

extension NotificationManager {
    
    /// Enhanced notification registration with AI
    func registerAINotifications(
        count: Int = 3,
        startTime: Int = 7,
        endTime: Int = 21,
        categories: Set<DeclarationCategory>? = nil,
        callback: (() -> Void)? = nil
    ) {
        Task {
            // Use AI notifications for premium users
            await AINotificationService.shared.schedulePersonalizedNotifications(
                count: count,
                timeRange: startTime...endTime
            )
            
            DispatchQueue.main.async {
                callback?()
            }
        }
    }
}

// MARK: - DeclarationViewModel AI Integration

extension DeclarationViewModel {
    
    /// Track declaration interaction with AI
    func trackAIInteraction(for declaration: Declaration, action: MLUserAction) {
        AIIntelligenceService.shared.trackUserInteraction(
            declaration: declaration,
            action: action,
            context: [
                "current_tab": selectedTab,
                "session_time": Date().timeIntervalSince1970
            ]
        )
    }
    
    /// Get AI recommendations for current declaration
    func getAIRecommendations(for declaration: Declaration) async -> [Declaration] {
        return await RecommendationEngine.shared.getRelatedContent(for: declaration)
    }
}

// MARK: - Search Enhancement

struct AIEnhancedSearchView: View {
    @State private var searchText = ""
    @State private var aiSuggestions: [SearchSuggestion] = []
    @State private var isSearching = false
    
    let onSearchResult: ([Declaration]) -> Void
    
    var body: some View {
        VStack {
            // Search bar
            SearchBar(text: $searchText, isSearching: $isSearching)
                .onChange(of: searchText) { newValue in
                    if !newValue.isEmpty {
                        Task {
                            aiSuggestions = await AIIntelligenceService.shared.enhanceSearch(newValue)
                        }
                    } else {
                        aiSuggestions = []
                    }
                }
            
            // AI search suggestions
            if !aiSuggestions.isEmpty {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text("AI Suggestions")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    ForEach(aiSuggestions) { suggestion in
                        Button(suggestion.displayText) {
                            performAISearch(suggestion)
                        }
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.05))
                .cornerRadius(12)
            }
        }
    }
    
    private func performAISearch(_ suggestion: SearchSuggestion) {
        // Perform search based on AI suggestion
        // This would query your declaration database
        Task {
            let results = await searchDeclarations(for: suggestion.refinedQuery)
            onSearchResult(results)
        }
    }
    
    private func searchDeclarations(for query: String) async -> [Declaration] {
        // Placeholder - would implement actual search
        return []
    }
}

struct SearchBar: UIViewRepresentable {
    @Binding var text: String
    @Binding var isSearching: Bool
    
    func makeUIView(context: Context) -> UISearchBar {
        let searchBar = UISearchBar()
        searchBar.delegate = context.coordinator
        searchBar.placeholder = "Search declarations..."
        searchBar.searchBarStyle = .minimal
        return searchBar
    }
    
    func updateUIView(_ uiView: UISearchBar, context: Context) {
        uiView.text = text
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UISearchBarDelegate {
        let parent: SearchBar
        
        init(_ parent: SearchBar) {
            self.parent = parent
        }
        
        func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
            parent.text = searchText
        }
        
        func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
            parent.isSearching = true
        }
        
        func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
            parent.isSearching = false
        }
    }
}

// MARK: - Journal AI Integration

struct AIJournalAnalysisView: View {
    @State private var journalText = ""
    @State private var aiRecommendations: [Declaration] = []
    @State private var aiInsight: PersonalInsight?
    @State private var isAnalyzing = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("AI Journal Analysis")
                .font(.headline)
            
            TextEditor(text: $journalText)
                .frame(minHeight: 100)
                .padding(DS.Spacing.xs)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .onChange(of: journalText) { newText in
                    if newText.count > 50 {
                        analyzeJournalEntry(newText)
                    }
                }
            
            if isAnalyzing {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("AI is analyzing your heart...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if let insight = aiInsight {
                PersonalInsightCard(insight: insight)
            }
            
            if !aiRecommendations.isEmpty {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text("Declarations for Your Heart Today")
                        .font(.headline)
                    
                    ForEach(aiRecommendations.prefix(3)) { declaration in
                        JournalRecommendationRow(declaration: declaration)
                    }
                }
            }
        }
        .padding()
    }
    
    private func analyzeJournalEntry(_ text: String) {
        isAnalyzing = true
        
        Task {
            // Get AI recommendations based on journal content
            async let recommendations = AIIntelligenceService.shared.analyzeJournalEntry(text)
            async let insight = AIIntelligenceService.shared.generateSpiritualInsight(for: text)
            
            let (recs, ins) = await (recommendations, insight)
            
            DispatchQueue.main.async {
                self.aiRecommendations = recs
                self.aiInsight = ins
                self.isAnalyzing = false
            }
        }
    }
}

struct JournalRecommendationRow: View {
    let declaration: Declaration
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(declaration.text.prefix(80) + "...")
                    .font(.subheadline)
                    .lineLimit(2)
                
                Text("AI Match: Perfect for your current heart")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            
            Spacer()
            
            Button("Use") {
                // Add to favorites or navigate to declaration
            }
            .font(.caption)
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, 6)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .padding(DS.Spacing.xs)
        .background(Color.blue.opacity(0.05))
        .cornerRadius(8)
    }
}

// MARK: - Widget AI Integration

struct AIWidgetContentProvider {
    static func getPersonalizedWidgetContent() async -> (title: String, content: String, reason: String) {
        let recommendations = await RecommendationEngine.shared.generatePersonalizedFeed()
        
        if let topRecommendation = recommendations.first {
            return (
                title: "Your Spiritual Moment",
                content: String(topRecommendation.text.prefix(100)),
                reason: "AI-selected for your journey"
            )
        } else {
            return (
                title: "Daily Declaration",
                content: "You are loved, chosen, and blessed by God",
                reason: "Daily encouragement"
            )
        }
    }
}

// MARK: - Crisis Support Integration

struct AICrisisSupportView: View {
    @State private var crisisDescription = ""
    @State private var showingSupport = false
    @State private var supportContent: [Declaration] = []
    
    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            Text("🤗 Need Immediate Support?")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Describe what you're facing, and AI will provide immediate spiritual support")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            TextEditor(text: $crisisDescription)
                .frame(height: 80)
                .padding(DS.Spacing.xs)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            
            Button("Get Immediate Support") {
                provideCrisisSupport()
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.red)
            .cornerRadius(12)
            .disabled(crisisDescription.isEmpty)
            
            if showingSupport {
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    Text("✨ God's Strength for You Right Now")
                        .font(.headline)
                        .foregroundColor(.green)
                    
                    ForEach(supportContent) { declaration in
                        CrisisSupportRow(declaration: declaration)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding()
    }
    
    private func provideCrisisSupport() {
        AIIntelligenceService.shared.provideCrisisSupport(crisisDescription)
        
        withAnimation(.easeInOut(duration: 0.5)) {
            showingSupport = true
        }
        
        // This would be replaced with actual crisis support content
        supportContent = [
            Declaration(text: "God is with you in this storm. His strength is made perfect in your weakness.", category: .strength),
            Declaration(text: "You are not alone. The Lord your God is with you wherever you go.", category: .protection),
            Declaration(text: "This too shall pass. God's love for you never changes.", category: .peace)
        ]
    }
}

struct CrisisSupportRow: View {
    let declaration: Declaration
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(declaration.text)
                .font(.subheadline)
                .foregroundColor(.primary)

            HStack {
                Text("Immediate comfort")
                    .font(.caption)
                    .padding(.horizontal, DS.Spacing.xs)
                    .padding(.vertical, DS.Spacing.xxs)
                    .background(Color.green.opacity(0.2))
                    .foregroundColor(.green)
                    .cornerRadius(4)
                
                Spacer()
                
                Button("Save") {
                    // Save to favorites
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
        }
        .padding(DS.Spacing.sm)
        .background(Color.green.opacity(0.05))
        .cornerRadius(8)
    }
}

// MARK: - Settings AI Integration

struct AISettingsView: View {
    @StateObject private var aiService = AIIntelligenceService.shared
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("AI Personalization")
                .font(.title2)
                .fontWeight(.bold)
            
            // AI Status
            HStack {
                Circle()
                    .fill(aiService.isAIReady ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                
                Text(aiService.aiStatusText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            if subscriptionStore.isPremium {
                // AI Performance Stats
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text("AI Performance")
                        .font(.headline)
                    
                    Text(aiService.performanceDetails)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding()
                .background(Color.blue.opacity(0.05))
                .cornerRadius(8)
                
                // AI Controls
                VStack(spacing: DS.Spacing.sm) {
                    Button("Retrain AI Models") {
                        Task {
                            await aiService.triggerModelRetraining()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    
                    Button("Optimize Experience") {
                        Task {
                            await aiService.optimizeUserExperience()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            } else {
                Text("Upgrade to Premium for full AI personalization")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .padding()
    }
}