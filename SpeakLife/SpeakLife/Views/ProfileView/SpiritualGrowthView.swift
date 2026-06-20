//
//  SpiritualGrowthView.swift
//  SpeakLife
//
//  Full-screen modal for displaying spiritual growth metrics
//

import SwiftUI
import FirebaseAnalytics

struct SpiritualGrowthView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var burstTracker = BurstCompletionTracker.shared
    @State private var selectedTab = 0
    @State private var showingInfo: Bool = false
    @State private var animateEntrance = false
    @State private var currentMotivationalQuote = ""
    
    var body: some View {
        ZStack {
            // Background gradient - SpeakLife signature dark gradient
            LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.1, blue: 0.2),
                    Color(red: 0.2, green: 0.1, blue: 0.3),
                    Color(red: 0.3, green: 0.2, blue: 0.4)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Subtle overlay for depth
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.2),
                    Color.clear,
                    Color.black.opacity(0.3)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Tab selector
                tabSelector
                    .padding(.top, 10)
                
                // Content
                ScrollView {
                    VStack(spacing: DS.Spacing.lg) {
                        if selectedTab == 0 {
                            overviewContent
                                .transition(.asymmetric(
                                    insertion: .move(edge: .leading).combined(with: .opacity),
                                    removal: .move(edge: .trailing).combined(with: .opacity)
                                ))
                        } else {
                            detailedMetricsContent
                                .transition(.asymmetric(
                                    insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)
                                ))
                        }
                    }
                    .padding()
                    .padding(.bottom, 50)
                }
            }
            .opacity(animateEntrance ? 1 : 0)
            .scaleEffect(animateEntrance ? 1 : 0.95)
        }
        .overlay {
            if showingInfo {
                ZStack {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(DS.Motion.smooth) {
                                showingInfo = false
                            }
                        }
                    
                    InfoSheetContent(isPresented: $showingInfo)
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .scale.combined(with: .opacity)
                        ))
                }
            }
        }
        .onAppear {
            // Set the quote once when view appears
            if currentMotivationalQuote.isEmpty {
                currentMotivationalQuote = getMotivationalQuote()
            }
            
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                animateEntrance = true
            }
            Analytics.logEvent("spiritual_growth_viewed", parameters: [
                "strength_level": burstTracker.strengthLevel.rawValue,
                "current_score": burstTracker.currentStrengthScore
            ])
        }
        .onChange(of: selectedTab) { _, _ in
            // Change quote when user switches tabs
            withAnimation(.easeInOut(duration: 0.3)) {
                currentMotivationalQuote = getMotivationalQuote()
            }
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Spiritual Growth")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Your journey to spiritual strength")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Spacer()
            
            // Info button
            Button {
                withAnimation(DS.Motion.smooth) {
                    showingInfo = true
                }
            } label: {
                Image(systemName: "info.circle")
                    .font(.system(size: 20))
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.trailing, 8)
            
            // Close button
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(.horizontal)
        .padding(.top, 20)
        .padding(.bottom, 10)
    }
    
    // MARK: - Tab Selector
    
    private var tabSelector: some View {
        HStack(spacing: 0) {
            TabSelectorButton(
                title: "Overview",
                icon: "chart.xyaxis.line",
                isSelected: selectedTab == 0
            ) {
                withAnimation(DS.Motion.smooth) {
                    selectedTab = 0
                }
            }
            
            TabSelectorButton(
                title: "Detailed Metrics",
                icon: "chart.bar.doc.horizontal",
                isSelected: selectedTab == 1
            ) {
                withAnimation(DS.Motion.smooth) {
                    selectedTab = 1
                }
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Overview Content
    
    private var overviewContent: some View {
        VStack(spacing: DS.Spacing.lg) {
            // Hero card with current status
            heroStatusCard
            
            // Main graph
            SpiritualStrengthGraph(tracker: burstTracker)
            
            // Achievement badges
            achievementSection
            
            // Motivational quote
            motivationalCard
        }
    }
    
    // MARK: - Detailed Metrics Content
    
    private var detailedMetricsContent: some View {
        VStack(spacing: 24) {
            // Detailed stats grid
            detailedStatsGrid
            
            // Progress indicators
            progressIndicators
            
            // History list
            recentActivityList
            
            // Milestones
            milestonesSection
        }
    }
    
    // MARK: - Hero Status Card
    
    private var heroStatusCard: some View {
        VStack(spacing: 20) {
            HStack(spacing: 24) {
                // Strength level visual
                ZStack {
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [burstTracker.strengthLevel.color.opacity(0.3), burstTracker.strengthLevel.color.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 6
                        )
                        .frame(width: 100, height: 100)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(burstTracker.currentStrengthScore) / 100)
                        .stroke(
                            LinearGradient(
                                colors: [burstTracker.strengthLevel.color, burstTracker.strengthLevel.color.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(-90))
                    
                    VStack(spacing: 4) {
                        Image(systemName: burstTracker.strengthLevel.icon)
                            .font(.system(size: 30))
                            .foregroundColor(burstTracker.strengthLevel.color)
                        
                        Text("\(burstTracker.currentStrengthScore)")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text(burstTracker.strengthLevel.rawValue)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(burstTracker.strengthLevel.color)
                    
                    Text("Spiritual Level")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                    
                    // Quick stats
                    HStack(spacing: 16) {
                        QuickStat(
                            icon: "flame.fill",
                            value: "\(burstTracker.getCompletionsForWeek().count)",
                            label: "This Week"
                        )
                        
                        QuickStat(
                            icon: "calendar",
                            value: "\(burstTracker.getUniqueDaysCount())",
                            label: "Total Days"
                        )
                    }
                }
                
                Spacer()
            }
            
            // Progress to next level
            if let nextLevel = getNextLevel() {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Progress to \(nextLevel.rawValue)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                        
                        Spacer()
                        
                        Text("\(nextLevel.minimumScore - burstTracker.currentStrengthScore) points")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    ProgressView(
                        value: Double(burstTracker.currentStrengthScore - burstTracker.strengthLevel.minimumScore),
                        total: Double(nextLevel.minimumScore - burstTracker.strengthLevel.minimumScore)
                    )
                    .progressViewStyle(LinearProgressViewStyle(tint: nextLevel.color))
                    .scaleEffect(x: 1, y: 2, anchor: .center)
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.15), Color(white: 0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.25), .white.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
    
    // MARK: - Achievement Section
    
    private var achievementSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Achievements")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    AchievementBadge(
                        icon: "star.fill",
                        title: "7 Day Warrior",
                        earned: burstTracker.getUniqueDaysCount() >= 7,
                        color: .yellow
                    )
                    
                    AchievementBadge(
                        icon: "flame.fill",
                        title: "21 Day Champion",
                        earned: burstTracker.getUniqueDaysCount() >= 21,
                        color: .orange
                    )
                    
                    AchievementBadge(
                        icon: "crown.fill",
                        title: "30 Day Conqueror",
                        earned: burstTracker.getUniqueDaysCount() >= 30,
                        color: .purple
                    )
                    
                    AchievementBadge(
                        icon: "bolt.circle.fill",
                        title: "50 Day Victor",
                        earned: burstTracker.getUniqueDaysCount() >= 50,
                        color: .blue
                    )
                    
                    AchievementBadge(
                        icon: "trophy.fill",
                        title: "100 Day Legend",
                        earned: burstTracker.getUniqueDaysCount() >= 100,
                        color: .gold
                    )
                }
            }
        }
    }
    
    // MARK: - Detailed Stats Grid
    
    private var detailedStatsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            DetailedStatCard(
                title: "Consistency Score",
                value: "\(Int(burstTracker.calculateMetrics().consistency * 100))%",
                subtitle: "Daily practice rate",
                icon: "calendar.badge.clock",
                color: .green
            )
            
            DetailedStatCard(
                title: "Weekly Average",
                value: "\(burstTracker.getCompletionsForWeek().count)/7",
                subtitle: "Days this week",
                icon: "star.fill",
                color: .orange
            )
            
            DetailedStatCard(
                title: "Total Sessions",
                value: "\(burstTracker.completions.count)",
                subtitle: "Burst completions",
                icon: "bolt.fill",
                color: .purple
            )
            
            DetailedStatCard(
                title: "Growth Trend",
                value: "+\(Int(burstTracker.calculateMetrics().growth * 100))%",
                subtitle: "Improvement rate",
                icon: "chart.line.uptrend.xyaxis",
                color: .blue
            )
        }
    }
    
    // MARK: - Progress Indicators
    
    private var progressIndicators: some View {
        VStack(spacing: 20) {
            ProgressIndicator(
                title: "Consistency",
                value: burstTracker.calculateMetrics().consistency,
                color: .green
            )
            
            ProgressIndicator(
                title: "Frequency",
                value: burstTracker.calculateMetrics().frequency,
                color: .orange
            )
            
            ProgressIndicator(
                title: "Dedication",
                value: burstTracker.calculateMetrics().dedication,
                color: .purple
            )
            
            ProgressIndicator(
                title: "Growth",
                value: burstTracker.calculateMetrics().growth,
                color: .blue
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
    }
    
    // MARK: - Recent Activity
    
    private var recentActivityList: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Activity")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
            
            VStack(spacing: 12) {
                ForEach(burstTracker.completions.suffix(5).reversed(), id: \.date) { completion in
                    ActivityRow(completion: completion)
                }
            }
        }
    }
    
    // MARK: - Milestones Section
    
    private var milestonesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Upcoming Milestones")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
            
            VStack(spacing: 12) {
                if burstTracker.getUniqueDaysCount() < 7 {
                    MilestoneRow(
                        milestone: "7 Day Warrior",
                        daysLeft: 7 - burstTracker.getUniqueDaysCount(),
                        icon: "star.fill",
                        color: .yellow
                    )
                }
                
                if burstTracker.getUniqueDaysCount() < 21 {
                    MilestoneRow(
                        milestone: "21 Day Champion",
                        daysLeft: 21 - burstTracker.getUniqueDaysCount(),
                        icon: "flame.fill",
                        color: .orange
                    )
                }
                
                if burstTracker.getUniqueDaysCount() < 30 {
                    MilestoneRow(
                        milestone: "30 Day Conqueror",
                        daysLeft: 30 - burstTracker.getUniqueDaysCount(),
                        icon: "crown.fill",
                        color: .purple
                    )
                }
            }
        }
    }
    
    // MARK: - Motivational Card
    
    private var motivationalCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "quote.opening")
                .font(.system(size: 24))
                .foregroundColor(.white.opacity(0.5))
            
            Text(currentMotivationalQuote.isEmpty ? getMotivationalQuote() : currentMotivationalQuote)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
            
            Text("- Keep Speaking Life -")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
                .padding(.top, 8)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                // Base gradient
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: .purple.opacity(0.4), location: 0),
                        .init(color: .orange.opacity(0.4), location: 0.5),
                        .init(color: .purple.opacity(0.4), location: 1)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                // Dark overlay for better text contrast
                Color.black.opacity(0.2)
            }
        )
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.2), .white.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
    
    // MARK: - Helper Methods
    
    private func getNextLevel() -> BurstCompletionTracker.StrengthLevel? {
        let allLevels = BurstCompletionTracker.StrengthLevel.allCases
        guard let currentIndex = allLevels.firstIndex(of: burstTracker.strengthLevel),
              currentIndex < allLevels.count - 1 else { return nil }
        return allLevels[currentIndex + 1]
    }
    
    private func getMotivationalQuote() -> String {
        let quotes = [
            "Your faith is growing stronger with every declaration!",
            "Each word you speak builds your spiritual fortress.",
            "Victory comes to those who persist in truth.",
            "Your spirit is being transformed day by day.",
            "Keep declaring, keep believing, keep growing!",
            "God's promises are being activated in your life!",
            "You're becoming unstoppable through His word.",
            "Every declaration shifts the atmosphere around you.",
            "Your breakthrough is one declaration away.",
            "Speaking life rewires your mind for victory.",
            "You're training your spirit to overcome.",
            "Heaven backs every word you speak in faith.",
            "Your consistency is crushing the enemy's plans.",
            "Declarations today become testimonies tomorrow.",
            "You're writing your victory story with every word.",
            "The power of life and death is in your tongue.",
            "Your words are seeds producing a harvest of blessing.",
            "You're stepping into divine alignment through declaration.",
            "Speaking God's truth dismantles every stronghold.",
            "Your spiritual muscles grow stronger with each repetition."
        ]
        return quotes.randomElement() ?? quotes[0]
    }
}

// MARK: - Supporting Views

struct TabSelectorButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                    Text(title)
                        .font(.system(size: 15, weight: isSelected ? .bold : .semibold))
                }
                .foregroundColor(isSelected ? .white : .white.opacity(0.75))
                
                Rectangle()
                    .fill(isSelected ? Color.orange : Color.clear)
                    .frame(height: 3)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct QuickStat: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.orange)
                Text(value)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
        }
    }
}

struct AchievementBadge: View {
    let icon: String
    let title: String
    let earned: Bool
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(earned ? color.opacity(0.2) : Color.gray.opacity(0.1))
                    .frame(width: 60, height: 60)
                
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundColor(earned ? color : .gray.opacity(0.5))
            }
            
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(earned ? .white : .white.opacity(0.4))
                .multilineTextAlignment(.center)
                .frame(width: 80)
        }
        .opacity(earned ? 1 : 0.5)
    }
}

struct DetailedStatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct ProgressIndicator: View {
    let title: String
    let value: Double
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(Int(value * 100))%")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(color)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.6)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * value, height: 8)
                }
            }
            .frame(height: 8)
        }
    }
}

struct ActivityRow: View {
    let completion: BurstCompletion
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        return formatter
    }
    
    var body: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(.green)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Daily Burst Completed")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                
                Text(dateFormatter.string(from: completion.completedAt))
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(completion.spiritualStrengthScore)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.orange)
                
                Text("Score")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
    }
}

struct MilestoneRow: View {
    let milestone: String
    let daysLeft: Int
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(milestone)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                
                Text("\(daysLeft) days to go")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            Image(systemName: "arrow.right.circle")
                .font(.system(size: 20))
                .foregroundColor(.white.opacity(0.3))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
    }
}

struct InfoSheetContent: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom header with close button
            HStack {
                Text("How It Works")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: {
                    withAnimation(DS.Motion.smooth) {
                        isPresented = false
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding()
            .background(Color.black.opacity(0.5))
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("How Spiritual Growth Works")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    InfoSection(
                        title: "Your Strength Score",
                        description: "Your spiritual strength score (0-100) is calculated based on four key factors:",
                        points: [
                            "Consistency - How many days in a row you practice",
                            "Frequency - How often you complete daily bursts",
                            "Dedication - Time spent in declaration",
                            "Growth - Your improvement trend over time"
                        ]
                    )
                    
                    InfoSection(
                        title: "Strength Levels",
                        description: "Progress through five levels of spiritual strength:",
                        points: [
                            "Warrior (0-19) - Building foundation",
                            "Champion (20-39) - Gaining momentum",
                            "Conqueror (40-59) - Overcoming challenges",
                            "Victorious (60-79) - Walking in victory",
                            "Unstoppable (80-100) - Maximum spiritual power"
                        ]
                    )
                    
                    InfoSection(
                        title: "Daily Burst Impact",
                        description: "Each daily burst session contributes to your growth:",
                        points: [
                            "Complete declarations daily for consistency bonus",
                            "Longer sessions increase dedication score",
                            "Regular practice builds spiritual momentum",
                            "Track your progress with visual charts"
                        ]
                    )
                    
                    Text("Keep speaking life daily to see your spiritual strength soar!")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.top)
                }
                .padding()
                .padding(.bottom, 50)
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(white: 0.1))
            )
        }
        .frame(maxWidth: UIScreen.main.bounds.width * 0.9, maxHeight: UIScreen.main.bounds.height * 0.8)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(white: 0.15))
                .shadow(color: .black.opacity(0.5), radius: 20)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

struct InfoSection: View {
    let title: String
    let description: String
    let points: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.orange)
            
            Text(description)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.9))
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(points, id: \.self) { point in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .foregroundColor(.orange)
                        Text(point)
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
    }
}

// MARK: - Spiritual Strength Graph
struct SpiritualStrengthGraph: View {
    let tracker: BurstCompletionTracker
    @State private var animateGraph = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title and level
            HStack {
                Image(systemName: "bolt.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Color(red: 1.0, green: 0.7, blue: 0.0))
                
                Text("Spiritual Strength")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text(tracker.strengthLevel.rawValue)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(tracker.strengthLevel.color)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(tracker.strengthLevel.color.opacity(0.2))
                    )
            }
            
            // 7-Day Journey title
            Text("7-Day Strength Journey")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
            
            Text("Your spiritual power grows daily")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.6))
            
            // Graph
            GeometryReader { geometry in
                ZStack(alignment: .bottom) {
                    // Background grid
                    VStack(spacing: 0) {
                        ForEach([100, 75, 50, 25, 0], id: \.self) { value in
                            HStack {
                                Text("\(value)")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.3))
                                    .frame(width: 25, alignment: .trailing)
                                
                                Rectangle()
                                    .fill(value == 75 ? Color.green.opacity(0.3) : Color.white.opacity(0.1))
                                    .frame(height: 1)
                                    .overlay(
                                        value == 75 ? 
                                        Text("Goal")
                                            .font(.system(size: 10))
                                            .foregroundColor(.green)
                                            .padding(.horizontal, 4)
                                            .background(Color.black)
                                            .offset(x: geometry.size.width - 80)
                                        : nil
                                    )
                            }
                            .frame(height: geometry.size.height / 5)
                        }
                    }
                    
                    // Bars
                    HStack(alignment: .bottom, spacing: geometry.size.width * 0.02) {
                        ForEach(tracker.weeklyData) { data in
                            VStack(spacing: 4) {
                                // Flame icon for completed days
                                if data.completed {
                                    Image(systemName: "flame.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(.orange)
                                        .scaleEffect(animateGraph ? 1 : 0)
                                        .animation(
                                            .spring(response: 0.5, dampingFraction: 0.6)
                                            .delay(Double(tracker.weeklyData.firstIndex(where: { $0.id == data.id }) ?? 0) * 0.1),
                                            value: animateGraph
                                        )
                                }
                                
                                // Bar
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                data.completed ? Color.orange : Color.gray.opacity(0.3),
                                                data.completed ? Color.pink : Color.gray.opacity(0.2)
                                            ]),
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .frame(height: max(10, min(geometry.size.height * 0.95, geometry.size.height * CGFloat(data.score) / 100)))
                                    .scaleEffect(x: 1, y: animateGraph ? 1 : 0, anchor: .bottom)
                                    .animation(
                                        .spring(response: 0.5, dampingFraction: 0.6)
                                        .delay(Double(tracker.weeklyData.firstIndex(where: { $0.id == data.id }) ?? 0) * 0.1),
                                        value: animateGraph
                                    )
                                
                                // Day label
                                Text(data.dayLabel)
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.leading, 30)
                }
            }
            .frame(height: 200)
            
            // Stats row
            HStack(spacing: 20) {
                StatItem(
                    icon: "calendar.badge.checkmark",
                    value: "\(Int(tracker.calculateMetrics().consistency * 100))%",
                    label: "Consistency",
                    color: .green
                )
                
                StatItem(
                    icon: "star.fill",
                    value: "\(tracker.getCompletionsForWeek().count)/7",
                    label: "This Week",
                    color: .orange
                )
                
                StatItem(
                    icon: "bolt.fill",
                    value: "\(tracker.completions.count)",
                    label: "Total Power",
                    color: .purple
                )
            }
            .padding(.top, 8)
        }
        .padding()
        .background(
            ZStack {
                // Dark background to ensure contrast
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(red: 0.1, green: 0.1, blue: 0.15))
                
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [Color.black.opacity(0.4), Color.black.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.2), Color.white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
        )
        .environment(\.colorScheme, .dark)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5)) {
                animateGraph = true
            }
        }
    }
}

struct StatItem: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(color)
                Text(value)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Color Extension
extension Color {
    static let gold = Color(red: 1.0, green: 0.84, blue: 0)
}

// MARK: - Preview
struct SpiritualGrowthView_Previews: PreviewProvider {
    static var previews: some View {
        SpiritualGrowthView()
    }
}
