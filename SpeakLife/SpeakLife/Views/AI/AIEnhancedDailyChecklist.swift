//
//  AIEnhancedDailyChecklist.swift
//  SpeakLife
//
//  AI-powered daily spiritual tasks and checklist enhancements
//

import SwiftUI

struct AIEnhancedDailyChecklist: View {
    @ObservedObject var viewModel: EnhancedStreakViewModel
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @StateObject private var aiTaskGenerator = AITaskGenerator()
    
    @State private var personalizedTasks: [SpiritualTask] = []
    @State private var aiInsights: [PersonalInsight] = []
    @State private var showAISection = false
    @State private var isLoadingAI = false
    
    var onClose: (() -> Void)? = nil
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header with progress circle - existing from DailyChecklistView
                headerSection
                    .dsAppear(0)

                ScrollView {
                    VStack(spacing: DS.Spacing.md) {
                        // Existing checklist items
                        existingChecklistSection
                            .dsAppear(0.06)

                        // AI-enhanced sections
                        if subscriptionStore.isAIEnabled {
                            if showAISection {
                                aiPersonalizedTasksSection
                                    .dsAppear(0.12)
                                aiInsightsSection
                                    .dsAppear(0.18)
                            }
                        } else if subscriptionStore.isPremium {
                            aiFeaturePrompt
                                .dsAppear(0.12)
                        } else {
                            aiUpgradePrompt
                                .dsAppear(0.12)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .onAppear {
            loadAIEnhancements()
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                HStack(spacing: DS.Spacing.xs) {
                    Text(viewModel.todayChecklist.currentPhase.emoji)
                        .font(.system(size: 16))
                    Text(viewModel.todayChecklist.currentPhase.displayName)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    if subscriptionStore.isPremium && !personalizedTasks.isEmpty {
                        Text("+ AI")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.3))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                
                let totalTasks = viewModel.todayChecklist.tasks.count + personalizedTasks.count
                let completedTasks = viewModel.todayChecklist.completedTasksCount + personalizedTasks.filter { $0.isCompleted }.count
                
                Text("\(completedTasks)/\(totalTasks) completed • Enhanced by AI")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                    
                Text(viewModel.todayChecklist.currentPhase.description)
                    .font(.caption2)
                    .foregroundColor(viewModel.todayChecklist.currentPhase.color)
            }
            
            Spacer()
            
            // Close button
            if let onClose = onClose {
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.trailing, DS.Spacing.xs)
            }
        }
        .padding()
        .background(Color.black.opacity(0.3))
    }
    
    // MARK: - Existing Checklist Section
    
    private var existingChecklistSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Today's Spiritual Checklist")
                .font(.headline)
                .foregroundColor(.white)
            
            ForEach(viewModel.todayChecklist.tasks) { task in
                ExistingTaskRow(task: task, viewModel: viewModel)
            }
        }
    }
    
    // MARK: - AI Personalized Tasks Section
    
    private var aiPersonalizedTasksSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.yellow)

                Text("Your Spiritual Focus Today")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                if isLoadingAI {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.7)
                }
            }
            
            if personalizedTasks.isEmpty && !isLoadingAI {
                EmptyAITasksView {
                    await generatePersonalizedTasks()
                }
            } else {
                ForEach(personalizedTasks) { task in
                    AITaskRow(task: task) { completedTask in
                        handleAITaskCompletion(completedTask)
                    }
                }
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(12)
    }
    
    // MARK: - AI Insights Section
    
    private var aiInsightsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)

                Text("AI Spiritual Insights")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("Personalized")
                    .font(.caption)
                    .padding(.horizontal, DS.Spacing.xs)
                    .padding(.vertical, DS.Spacing.xxs)
                    .background(Color.yellow.opacity(0.3))
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            
            ForEach(aiInsights.indices, id: \.self) { index in
                DailyInsightCard(insight: aiInsights[index])
            }
        }
        .padding()
        .background(Color.yellow.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - AI Feature Prompt
    
    private var aiFeaturePrompt: some View {
        VStack(spacing: DS.Spacing.sm) {
            HStack {
                Image(systemName: "brain")
                    .foregroundColor(.blue)
                
                Text("AI Features Available")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("Enable AI")
                    .font(.caption)
                    .padding(.horizontal, DS.Spacing.xs)
                    .padding(.vertical, DS.Spacing.xxs)
                    .background(Color.blue.opacity(0.3))
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            
            Text("Enable AI features in Settings to unlock personalized spiritual tasks, intelligent insights, and contextual recommendations.")
                .font(.body)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.leading)
        }
        .padding()
        .dsGlass(cornerRadius: DS.Radius.md)
    }

    // MARK: - AI Upgrade Prompt
    
    private var aiUpgradePrompt: some View {
        VStack(spacing: DS.Spacing.sm) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.orange)

                Text("AI-Powered Spiritual Growth")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("Premium")
                    .font(.caption)
                    .padding(.horizontal, DS.Spacing.xs)
                    .padding(.vertical, DS.Spacing.xxs)
                    .background(Color.orange.opacity(0.3))
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                AIChecklistFeatureRow(
                    icon: "target",
                    title: "Personalized Daily Tasks",
                    description: "AI creates spiritual tasks based on your journey"
                )
                
                AIChecklistFeatureRow(
                    icon: "lightbulb.fill",
                    title: "Smart Spiritual Insights",
                    description: "Daily guidance tailored to your growth pattern"
                )
                
                AIChecklistFeatureRow(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Growth Tracking",
                    description: "AI analyzes your progress and suggests next steps"
                )
            }
            
            Button("Unlock AI Features") {
                // Handle premium upgrade
            }
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.sm)
            .background(DS.Gradient.gold)
            .cornerRadius(10)
            .buttonStyle(.dsPressable(feel: .tapSolid))
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Helper Methods
    
    private func loadAIEnhancements() {
        guard subscriptionStore.isPremium else { return }
        
        Task {
            await generatePersonalizedTasks()
            await generateDailyInsights()
            
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.5)) {
                    self.showAISection = true
                }
            }
        }
    }
    
    private func generatePersonalizedTasks() async {
        isLoadingAI = true
        
        let tasks = await aiTaskGenerator.generatePersonalizedTasks(
            basedOn: EnhancedAnalyticsService.shared.userBehaviorProfile
        )
        
        DispatchQueue.main.async {
            self.personalizedTasks = tasks
            self.isLoadingAI = false
        }
    }
    
    private func generateDailyInsights() async {
        let insights = EnhancedAnalyticsService.shared.getPersonalizedInsights()
        
        DispatchQueue.main.async {
            self.aiInsights = insights
        }
    }
    
    private func handleAITaskCompletion(_ task: SpiritualTask) {
        // Update task completion status
        if let index = personalizedTasks.firstIndex(where: { $0.id == task.id }) {
            personalizedTasks[index] = SpiritualTask(
                title: task.title,
                description: task.description,
                aiGeneratedReason: task.aiGeneratedReason,
                estimatedMinutes: task.estimatedMinutes,
                priority: task.priority,
                spiritualFocus: task.spiritualFocus,
                relatedDeclarationIds: task.relatedDeclarationIds
            )
        }
        
        // Track AI task completion
        EnhancedAnalyticsService.shared.trackAITaskCompletion(
            taskId: task.id.uuidString,
            taskType: task.spiritualFocus.rawValue,
            completionRate: 1.0,
            userSatisfaction: 5 // Would be user-provided in real implementation
        )
        
        // Generate new task to replace completed one
        Task {
            let newTask = await aiTaskGenerator.generateReplacementTask(
                for: task,
                userBehavior: EnhancedAnalyticsService.shared.userBehaviorProfile
            )
            
            DispatchQueue.main.async {
                if let index = self.personalizedTasks.firstIndex(where: { $0.id == task.id }) {
                    self.personalizedTasks[index] = newTask
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct ExistingTaskRow: View {
    let task: DailyTask
    @ObservedObject var viewModel: EnhancedStreakViewModel
    
    var body: some View {
        HStack {
            Button(action: {
                // Toggle task completion - would integrate with existing logic
            }) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(task.isCompleted ? .green : .white.opacity(0.7))
            }
            
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(task.title)
                    .foregroundColor(.white)

                Text(task.description)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            Text("\(task.estimatedMinutes)m")
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal)
    }
}

struct AITaskRow: View {
    let task: SpiritualTask
    let onCompletion: (SpiritualTask) -> Void
    @State private var isCompleted = false
    
    var body: some View {
        HStack {
            Button(action: {
                withAnimation(DS.Motion.smooth) {
                    isCompleted.toggle()
                    if isCompleted {
                        onCompletion(task)
                    }
                }
            }) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isCompleted ? .green : .white.opacity(0.7))
            }
            
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                HStack {
                    Text(task.title)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Priority indicator
                    if task.priority == .high || task.priority == .urgent {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(task.priority == .urgent ? .red : .orange)
                            .font(.caption)
                    }
                }
                
                Text(task.aiGeneratedReason)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                
                // Spiritual focus tag
                HStack {
                    Text(task.spiritualFocus.displayName)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.3))
                        .foregroundColor(.white)
                        .cornerRadius(4)
                    
                    Spacer()
                    
                    Text("\(task.estimatedMinutes)m")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
        .padding(.horizontal)
        .strikethrough(isCompleted)
        .opacity(isCompleted ? 0.6 : 1.0)
    }
}

struct DailyInsightCard: View {
    let insight: PersonalInsight
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack {
                Text(insight.contextualMessage)
                    .font(.subheadline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: {
                    withAnimation(.easeInOut) {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.white.opacity(0.7))
                        .font(.caption)
                }
                .buttonStyle(.dsPressable(feel: .tapSolid))
            }
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    if let suggestion = insight.applicationSuggestion {
                        Text("💡 \(suggestion)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Text(insight.connectionToJourney)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(10)
        .dsGlass(cornerRadius: DS.Radius.sm)
    }
}

struct EmptyAITasksView: View {
    let onGenerate: () async -> Void
    
    var body: some View {
        VStack(spacing: DS.Spacing.sm) {
            Image(systemName: "sparkles")
                .font(.title)
                .foregroundColor(.yellow)
            
            Text("Generate Your Spiritual Tasks")
                .font(.subheadline)
                .foregroundColor(.white)
            
            Text("AI will create personalized tasks based on your spiritual journey")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
            
            Button("Generate Tasks") {
                Task {
                    await onGenerate()
                }
            }
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.xs)
            .background(Color.yellow.opacity(0.3))
            .cornerRadius(8)
        }
        .padding()
    }
}

struct AIChecklistFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: icon)
                .foregroundColor(.orange)
                .font(.title3)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Spacer()
        }
    }
}

// MARK: - AI Task Generator

@MainActor
class AITaskGenerator: ObservableObject {
    
    func generatePersonalizedTasks(basedOn userBehavior: UserBehaviorFeatures) async -> [SpiritualTask] {
        var tasks: [SpiritualTask] = []
        
        // Generate tasks based on struggling areas
        for struggle in userBehavior.strugglingAreas.prefix(2) {
            let task = await createStruggleTask(struggle: struggle, userBehavior: userBehavior)
            tasks.append(task)
        }
        
        // Generate tasks based on growth areas
        for growthArea in userBehavior.growthAreas.prefix(1) {
            let task = await createGrowthTask(growthArea: growthArea, userBehavior: userBehavior)
            tasks.append(task)
        }
        
        // Generate task based on spiritual maturity
        let maturityTask = await createMaturityTask(userBehavior: userBehavior)
        tasks.append(maturityTask)
        
        return tasks
    }
    
    func generateReplacementTask(for completedTask: SpiritualTask, userBehavior: UserBehaviorFeatures) async -> SpiritualTask {
        // Generate a new task in the same spiritual focus area
        return await createAdvancedTask(
            spiritualFocus: completedTask.spiritualFocus,
            userBehavior: userBehavior
        )
    }
    
    private func createStruggleTask(struggle: String, userBehavior: UserBehaviorFeatures) async -> SpiritualTask {
        return SpiritualTask(
            title: "Breakthrough Prayer for \(struggle.capitalized)",
            description: "Speak declarations specifically targeting your \(struggle) challenge",
            aiGeneratedReason: "AI identified \(struggle) as your current focus area",
            estimatedMinutes: 5,
            priority: .high,
            spiritualFocus: .deliverance,
            relatedDeclarationIds: [] // Would be populated with relevant declarations
        )
    }
    
    private func createGrowthTask(growthArea: String, userBehavior: UserBehaviorFeatures) async -> SpiritualTask {
        return SpiritualTask(
            title: "Strengthen Your \(growthArea.capitalized)",
            description: "Focus on declarations that build your \(growthArea) foundation",
            aiGeneratedReason: "Supporting your identified growth in \(growthArea)",
            estimatedMinutes: 7,
            priority: .medium,
            spiritualFocus: .faith,
            relatedDeclarationIds: []
        )
    }
    
    private func createMaturityTask(userBehavior: UserBehaviorFeatures) async -> SpiritualTask {
        switch userBehavior.spiritualMaturityLevel {
        case .newBeliever:
            return SpiritualTask(
                title: "Foundation Building",
                description: "Declare your identity in Christ",
                aiGeneratedReason: "Building your spiritual foundation",
                estimatedMinutes: 3,
                priority: .high,
                spiritualFocus: .identity,
                relatedDeclarationIds: []
            )
            
        case .growing:
            return SpiritualTask(
                title: "Wisdom Meditation",
                description: "Reflect on declarations of divine wisdom",
                aiGeneratedReason: "Advancing your spiritual understanding",
                estimatedMinutes: 8,
                priority: .medium,
                spiritualFocus: .wisdom,
                relatedDeclarationIds: []
            )
            
        case .mature:
            return SpiritualTask(
                title: "Deep Intercession",
                description: "Pray breakthrough declarations for others",
                aiGeneratedReason: "Exercising your mature spiritual authority",
                estimatedMinutes: 10,
                priority: .medium,
                spiritualFocus: .breakthrough,
                relatedDeclarationIds: []
            )
            
        case .leadership:
            return SpiritualTask(
                title: "Leadership Anointing",
                description: "Declare God's calling and authority over your leadership",
                aiGeneratedReason: "Strengthening your leadership calling",
                estimatedMinutes: 12,
                priority: .high,
                spiritualFocus: .purpose,
                relatedDeclarationIds: []
            )
        }
    }
    
    private func createAdvancedTask(spiritualFocus: SpiritualContentCategory, userBehavior: UserBehaviorFeatures) async -> SpiritualTask {
        return SpiritualTask(
            title: "Advanced \(spiritualFocus.displayName)",
            description: "Deeper exploration of \(spiritualFocus.displayName.lowercased()) through declaration",
            aiGeneratedReason: "Building on your completed \(spiritualFocus.displayName.lowercased()) work",
            estimatedMinutes: Int.random(in: 5...10),
            priority: .medium,
            spiritualFocus: spiritualFocus,
            relatedDeclarationIds: []
        )
    }
}

// MARK: - Placeholder Types (if not already defined)

struct DailyChecklistTask: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let estimatedMinutes: Int
    let isCompleted: Bool
}