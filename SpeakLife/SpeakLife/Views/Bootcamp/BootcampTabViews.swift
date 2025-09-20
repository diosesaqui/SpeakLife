//
//  BootcampTabViews.swift
//  SpeakLife
//
//  Tab content views for Spiritual Warrior Bootcamp
//

import SwiftUI

// MARK: - Overview Tab
struct BootcampOverviewTab: View {
    @ObservedObject var viewModel: BootcampViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Welcome Message
                if let progress = viewModel.userProgress {
                    WelcomeCard(progress: progress)
                }
                
                // Current Phase
                if let currentModule = viewModel.currentModule {
                    CurrentPhaseCard(module: currentModule)
                }
                
                // Quick Actions
                QuickActionsSection(viewModel: viewModel)
                
                // Recent Activity
                RecentActivitySection(viewModel: viewModel)
            }
            .padding()
        }
    }
}

// MARK: - Curriculum Tab
struct CurriculumTab: View {
    @ObservedObject var viewModel: BootcampViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let program = viewModel.currentProgram {
                    ForEach(program.modules) { module in
                        ModuleCard(module: module, viewModel: viewModel)
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Community Tab
struct CommunityTab: View {
    @ObservedObject var viewModel: BootcampViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Accountability Groups
                AccountabilityGroupsSection()
                
                // Discussion Forums
                DiscussionForumsSection()
                
                // Upcoming Live Sessions
                UpcomingSessionsSection()
            }
            .padding()
        }
    }
}

// MARK: - Progress Tab
struct ProgressTab: View {
    @ObservedObject var viewModel: BootcampViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if let progress = viewModel.userProgress {
                    // Overall Progress
                    OverallProgressCard(progress: progress)
                    
                    // Streak & Points
                    StatsCard(progress: progress)
                    
                    // Achievements
                    AchievementsSection(progress: progress)
                    
                    // Weekly Performance
                    WeeklyPerformanceChart(progress: progress)
                }
            }
            .padding()
        }
    }
}

// MARK: - Resources Tab
struct ResourcesTab: View {
    @ObservedObject var viewModel: BootcampViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Downloadable Resources
                ResourcesListSection(viewModel: viewModel)
                
                // Bonus Content
                BonusContentSection(viewModel: viewModel)
            }
            .padding()
        }
    }
}

// MARK: - Supporting Components

struct WelcomeCard: View {
    let progress: BootcampProgress
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Welcome back, Warrior!")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("Day \(progress.streakDays) of your journey")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
            
            HStack {
                Label("\(progress.totalPoints) points", systemImage: "star.fill")
                    .foregroundColor(.yellow)
                
                Spacer()
                
                Label("\(progress.streakDays) day streak", systemImage: "flame.fill")
                    .foregroundColor(.orange)
            }
            .font(.caption)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(LinearGradient(
                    colors: [Color.purple.opacity(0.3), Color.blue.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
        )
    }
}

struct CurrentPhaseCard: View {
    let module: BootcampModule
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: module.phase.icon)
                    .foregroundColor(module.phase.color)
                Text(module.phase.displayName)
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            Text(module.title)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Text(module.scripture)
                .font(.caption)
                .italic()
                .foregroundColor(.white.opacity(0.8))
            
            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(module.phase.color)
                        .frame(width: geometry.size.width * module.completionPercentage, height: 8)
                }
            }
            .frame(height: 8)
            
            Text("\(Int(module.completionPercentage * 100))% Complete")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.1))
        )
    }
}

struct QuickActionsSection: View {
    @ObservedObject var viewModel: BootcampViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
                .foregroundColor(.white)
            
            HStack(spacing: 12) {
                QuickActionButton(
                    icon: "play.circle.fill",
                    title: "Continue",
                    color: .green
                ) {
                    // Continue last lesson
                }
                
                QuickActionButton(
                    icon: "calendar",
                    title: "Schedule",
                    color: .blue
                ) {
                    // View schedule
                }
                
                QuickActionButton(
                    icon: "person.2.fill",
                    title: "Community",
                    color: .purple
                ) {
                    viewModel.selectedTab = .community
                }
            }
        }
    }
}

struct QuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                Text(title)
                    .font(.caption)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.3))
            )
        }
    }
}

struct RecentActivitySection: View {
    @ObservedObject var viewModel: BootcampViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Activity")
                .font(.headline)
                .foregroundColor(.white)
            
            // Placeholder for recent activities
            ForEach(0..<3, id: \.self) { _ in
                HStack {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Completed lesson")
                            .font(.subheadline)
                            .foregroundColor(.white)
                        Text("2 hours ago")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 8)
            }
        }
    }
}

struct ModuleCard: View {
    let module: BootcampModule
    @ObservedObject var viewModel: BootcampViewModel
    
    var body: some View {
        Button(action: {
            viewModel.navigationPath.append(BootcampDestination.module(module))
        }) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Week \(module.weekNumber)")
                        .font(.caption)
                        .foregroundColor(module.phase.color)
                    
                    Spacer()
                    
                    if module.isUnlocked {
                        Image(systemName: "lock.open.fill")
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                
                Text(module.title)
                    .font(.headline)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                
                Text(module.description)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(2)
                
                // Lesson count
                HStack {
                    Image(systemName: "book.closed")
                    Text("\(module.lessons.count) lessons")
                    
                    Spacer()
                    
                    if module.completionPercentage > 0 {
                        Text("\(Int(module.completionPercentage * 100))%")
                            .foregroundColor(module.phase.color)
                    }
                }
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(module.isUnlocked ? Color.white.opacity(0.1) : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(module.phase.color.opacity(0.3), lineWidth: 1)
            )
        }
        .disabled(!module.isUnlocked)
    }
}

// Placeholder sections for other components
struct AccountabilityGroupsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Accountability Groups")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Connect with fellow warriors")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.1))
        )
    }
}

struct DiscussionForumsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Discussion Forums")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Share insights and testimonies")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.1))
        )
    }
}

struct UpcomingSessionsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Upcoming Live Sessions")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Join weekly Q&A and prayer")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.1))
        )
    }
}

struct OverallProgressCard: View {
    let progress: BootcampProgress
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Overall Progress")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("\(Int(progress.overallProgress * 100))% Complete")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.1))
        )
    }
}

struct StatsCard: View {
    let progress: BootcampProgress
    
    var body: some View {
        HStack {
            StatItem(title: "Points", value: "\(progress.totalPoints)", icon: "star.fill", color: .yellow)
            Spacer()
            StatItem(title: "Streak", value: "\(progress.streakDays)", icon: "flame.fill", color: .orange)
            Spacer()
            StatItem(title: "Lessons", value: "\(progress.completedLessons.count)", icon: "checkmark.circle.fill", color: .green)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.1))
        )
    }
}

struct StatItem: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
    }
}

struct AchievementsSection: View {
    let progress: BootcampProgress
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Achievements")
                .font(.headline)
                .foregroundColor(.white)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(0..<5, id: \.self) { _ in
                        Circle()
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 60, height: 60)
                            .overlay(
                                Image(systemName: "medal.fill")
                                    .foregroundColor(.white.opacity(0.5))
                            )
                    }
                }
            }
        }
    }
}

struct WeeklyPerformanceChart: View {
    let progress: BootcampProgress
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weekly Performance")
                .font(.headline)
                .foregroundColor(.white)
            
            // Placeholder chart
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.1))
                .frame(height: 150)
                .overlay(
                    Text("Performance Chart")
                        .foregroundColor(.white.opacity(0.5))
                )
        }
    }
}

struct ResourcesListSection: View {
    @ObservedObject var viewModel: BootcampViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Study Materials")
                .font(.headline)
                .foregroundColor(.white)
            
            // Placeholder resources
            ForEach(0..<3, id: \.self) { _ in
                HStack {
                    Image(systemName: "doc.fill")
                        .foregroundColor(.white.opacity(0.6))
                    Text("Resource Document")
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "arrow.down.circle")
                        .foregroundColor(.blue)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.05))
                )
            }
        }
    }
}

struct BonusContentSection: View {
    @ObservedObject var viewModel: BootcampViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Bonus Content")
                .font(.headline)
                .foregroundColor(.white)
            
            if let program = viewModel.currentProgram {
                ForEach(program.bonusContent) { bonus in
                    HStack {
                        Image(systemName: bonus.isUnlocked ? "lock.open.fill" : "lock.fill")
                            .foregroundColor(bonus.isUnlocked ? .green : .white.opacity(0.5))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(bonus.title)
                                .font(.subheadline)
                                .foregroundColor(.white)
                            Text(bonus.description)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.05))
                    )
                }
            }
        }
    }
}