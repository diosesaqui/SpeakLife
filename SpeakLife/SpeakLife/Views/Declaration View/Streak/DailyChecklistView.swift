//
//  DailyChecklistView.swift
//  SpeakLife
//
//  Daily checklist UI for enhanced streak feature
//

import SwiftUI

struct DailyChecklistView: View {
    @ObservedObject var viewModel: EnhancedStreakViewModel
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @State private var showInfoSheet = false
    @State private var showFirstTaskConfetti = false
    var onClose: (() -> Void)? = nil
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
            // Header with progress circle - fixed at top
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(viewModel.todayChecklist.currentPhase.emoji)
                            .font(.system(size: 16))
                        Text(viewModel.todayChecklist.currentPhase.displayName)
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    
                    Text("\(viewModel.todayChecklist.completedTasksCount)/\(viewModel.todayChecklist.tasks.count) completed • \(viewModel.todayChecklist.estimatedTotalMinutes)min total")
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
                    .padding(.trailing, 8)
                }
                
                // Progress Circle
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 6)
                        .frame(width: 60, height: 60)
                    
                    Circle()
                        .trim(from: 0, to: viewModel.todayChecklist.completionProgress)
                        .stroke(Color.white, lineWidth: 6)
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.5), value: viewModel.todayChecklist.completionProgress)
                    
                    if viewModel.todayChecklist.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.title2)
                            .foregroundColor(.white)
                            .fontWeight(.bold)
                    } else {
                        Text("\(Int(viewModel.todayChecklist.completionProgress * 100))%")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                }
                .onTapGesture {
                    showInfoSheet = true
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            // Scrollable content
            ScrollView {
                VStack(spacing: 16) {
                    // Progress Journey Info
//                    ProgressJourneyInfo()
//                        .padding(.horizontal, 20)
                    
                    // Task List
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.todayChecklist.tasks) { task in
                            DailyTaskRow(
                                task: task,
                                onToggle: { taskId in
                                    if task.isCompleted {
                                        viewModel.uncompleteTask(taskId: taskId)
                                    } else {
                                        viewModel.completeTask(taskId: taskId)
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Upcoming Unlocks Preview
                    let upcomingTasks = viewModel.getUpcomingUnlocks(for: viewModel.streakStats.currentStreak)
                    if !upcomingTasks.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "lock")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.6))
                                Text("Coming Soon")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.8))
                                Spacer()
                            }
                            
                            LazyVStack(spacing: 8) {
                                ForEach(Array(upcomingTasks.prefix(2)), id: \.id) { task in
                                    UpcomingTaskPreview(task: task, currentStreakDay: viewModel.streakStats.currentStreak)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    // Bottom spacing
                    Color.clear.frame(height: 20)
                }
                .padding(.top, 8)
            }
            }
            
            // Modern celebration animation for first task completion
            if showFirstTaskConfetti || viewModel.showFirstTaskConfetti {
                ModernCelebrationView(accentColor: .green)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.1, green: 0.15, blue: 0.3), Color(red: 0.02, green: 0.07, blue: 0.15)],
                        startPoint: .top,
                        endPoint: .bottom)
                    )
                    
                  //  Gradients().speakLifeCYOCell)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .sheet(isPresented: $showInfoSheet) {
            DailyChecklistInfoSheet()
        }
        .onAppear {
            // Auto-complete first task if demo was completed (will only happen once ever)
            viewModel.autoCompleteFirstTaskIfDemoCompleted(hasCompletedDemo: appState.hasCompletedDemo)
        }
    }
}

struct DailyTaskRow: View {
    let task: DailyTask
    let onToggle: (String) -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            TaskCheckbox(task: task, onToggle: onToggle)
            TaskIcon(task: task)
            TaskContent(task: task)
            Spacer()
            TaskCompletionIndicator(task: task)
        }
        .taskRowBackground(isCompleted: task.isCompleted)
    }
}

// MARK: - Task Components (Single Responsibility)

struct TaskCheckbox: View {
    let task: DailyTask
    let onToggle: (String) -> Void
    @State private var bounceScale: CGFloat = 1.0
    
    var body: some View {
        Button(action: handleToggle) {
            checkboxContent
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var checkboxContent: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(task.isCompleted ? Color.white : Color.clear)
                .frame(width: 28, height: 28)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white, lineWidth: 2)
                )
            
            if task.isCompleted {
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Constants.DAMidBlue)
            }
        }
        .scaleEffect(bounceScale)
    }
    
    private func handleToggle() {
        HapticManager.impact(.medium)
        animateToggle()
        onToggle(task.id)
    }
    
    private func animateToggle() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            bounceScale = 0.85
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                bounceScale = 1.0
            }
        }
    }
}

struct TaskIcon: View {
    let task: DailyTask
    
    var body: some View {
        Image(systemName: task.icon)
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.white)
            .frame(width: 32, height: 32)
            .background(iconBackground)
            .overlay(iconBorder)
    }
    
    private var iconBackground: some View {
        Circle()
            .fill(task.category.color.opacity(0.3))
    }
    
    private var iconBorder: some View {
        Circle()
            .stroke(task.category.color.opacity(0.6), lineWidth: 1)
    }
}

struct TaskContent: View {
    let task: DailyTask
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TaskTitle(task: task)
            TaskDescription(task: task)
            TaskMetadata(task: task)
        }
    }
}

struct TaskTitle: View {
    let task: DailyTask
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(task.title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .strikethrough(task.isCompleted)
            
            if task.isNewlyUnlocked {
                NewTaskBadge()
            }
            
            Spacer()
        }
    }
}

struct TaskDescription: View {
    let task: DailyTask
    
    var body: some View {
        Text(task.description)
            .font(.system(size: 14, weight: .regular))
            .foregroundColor(.white.opacity(0.8))
            .lineLimit(3)
    }
}

struct TaskMetadata: View {
    let task: DailyTask
    
    var body: some View {
        HStack(spacing: 10) {
            CategoryBadge(category: task.category)
            EstimatedTime(minutes: task.estimatedMinutes)
            Spacer()
        }
    }
}

struct NewTaskBadge: View {
    var body: some View {
        Text("NEW!")
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.yellow)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(badgeBackground)
            .overlay(badgeBorder)
    }
    
    private var badgeBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.yellow.opacity(0.2))
    }
    
    private var badgeBorder: some View {
        RoundedRectangle(cornerRadius: 8)
            .stroke(Color.yellow.opacity(0.6), lineWidth: 1)
    }
}

struct CategoryBadge: View {
    let category: TaskCategory
    
    var body: some View {
        HStack(spacing: 4) {
            Text(category.emoji)
                .font(.system(size: 10))
            Text(category.displayName)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(category.color)
                .lineLimit(1)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(category.color.opacity(0.15))
        )
    }
}

struct EstimatedTime: View {
    let minutes: Int
    
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "clock")
                .font(.system(size: 9))
            Text("\(minutes)m")
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundColor(.white.opacity(0.6))
    }
}

struct TaskCompletionIndicator: View {
    let task: DailyTask
    
    var body: some View {
        if task.isCompleted {
            VStack(spacing: 2) {
                Image(systemName: "star.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.yellow)
                
                if let completedAt = task.completedAt {
                    Text(DateFormatter.timeFormatter.string(from: completedAt))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
    }
}

// MARK: - Helper Extensions & Utilities

struct HapticManager {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        // Route through the design system's matched-feedback layer so this
        // wrapper respects the user's haptics setting and stays consistent
        // with the rest of the app. Callers keep the same API.
        switch style {
        case .light, .soft:
            Juice.play(.tapLight)
        case .medium, .heavy, .rigid:
            Juice.play(.tapSolid)
        @unknown default:
            Juice.play(.tapSolid)
        }
    }
}

struct TaskRowBackgroundModifier: ViewModifier {
    let isCompleted: Bool
    
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(backgroundFill)
            .overlay(backgroundStroke)
    }
    
    private var backgroundFill: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.white.opacity(isCompleted ? 0.1 : 0.05))
    }
    
    private var backgroundStroke: some View {
        RoundedRectangle(cornerRadius: 12)
            .stroke(Color.white.opacity(isCompleted ? 0.3 : 0.1), lineWidth: 1)
    }
}

extension View {
    func taskRowBackground(isCompleted: Bool) -> some View {
        modifier(TaskRowBackgroundModifier(isCompleted: isCompleted))
    }
}


struct DailyChecklistInfoSheet: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ZStack {
                Gradients().speakLifeCYOCell
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Daily Spiritual Practice")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text("Complete your daily checklist to maintain your streak and grow spiritually stronger each day.")
                                .font(.body)
                                .foregroundColor(.white.opacity(0.9))
                        }
                        
                        VStack(alignment: .leading, spacing: 16) {
                            TaskInfoRow(
                                icon: "speaker.wave.3.fill",
                                title: "Speak a Favorited Affirmation",
                                description: "Declare God's truth out loud. Your words have power to transform your reality."
                            )
                            
                            TaskInfoRow(
                                icon: "square.and.arrow.up.fill",
                                title: "Share an Affirmation",
                                description: "Spread hope and encouragement. Share God's promises with someone today."
                            )
                            
                            TaskInfoRow(
                                icon: "book.fill",
                                title: "Read Daily Devotional",
                                description: "Feed your spirit with God's Word. Let His truth renew your mind."
                            )
                            
                            TaskInfoRow(
                                icon: "headphones",
                                title: "Listen to Audio Affirmation",
                                description: "Let faith come by hearing. Absorb God's promises through your ears."
                            )
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Streak Benefits")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            
                            Text("• Build spiritual discipline and consistency\n• Transform your mindset through daily practice\n• Unlock achievement badges and milestones\n• Share your progress and inspire others")
                                .font(.body)
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                    .padding(20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(.white)
            )
        }
        .navigationViewStyle(.stack)
    }
}

struct TaskInfoRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.2))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Spacer()
        }
    }
}

struct ProgressJourneyInfo: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "map")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
                Text("Your Spiritual Journey")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
            }
            
            HStack {
                JourneyPhaseItem(
                    emoji: "🌱",
                    label: "Foundation",
                    color: .blue
                )
                
                Spacer()
                
                Image(systemName: "arrow.right")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
                
                Spacer()
                
                JourneyPhaseItem(
                    emoji: "🌿",
                    label: "Growth",
                    color: .green
                )
                
                Spacer()
                
                Image(systemName: "arrow.right")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
                
                Spacer()
                
                JourneyPhaseItem(
                    emoji: "🌟",
                    label: "Impact",
                    color: .orange
                )
                
                Spacer()
                
                Image(systemName: "arrow.right")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
                
                Spacer()
                
                JourneyPhaseItem(
                    emoji: "👑",
                    label: "Mastery",
                    color: .purple
                )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.05))
        )
    }
}

struct JourneyPhaseItem: View {
    let emoji: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 1) {
            Text(emoji)
                .font(.system(size: 10))
            Text(label)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(color.opacity(0.8))
                .lineLimit(1)
        }
    }
}

struct UpcomingTaskPreview: View {
    let task: DailyTask
    let currentStreakDay: Int
    
    private var unlockMessage: String {
        let daysUntilUnlock = task.minimumStreakDay - currentStreakDay
        if daysUntilUnlock <= 0 {
            return "Available"
        } else if daysUntilUnlock == 1 {
            return "Tomorrow"
        } else {
            return "In \(daysUntilUnlock) days"
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Locked icon
            Image(systemName: "lock.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.4))
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.1))
                )
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(task.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text(unlockMessage)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.1))
                        )
                }
                
                Text(task.description)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.5))
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Extensions
extension DateFormatter {
    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
}
