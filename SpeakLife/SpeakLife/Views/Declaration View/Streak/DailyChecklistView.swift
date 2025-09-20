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
                    ProgressJourneyInfo()
                        .padding(.horizontal, 20)
                    
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
            
            // Confetti animation for first task completion
            if showFirstTaskConfetti || viewModel.showFirstTaskConfetti {
                ConfettiView()
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
    @State private var bounceScale: CGFloat = 1.0
    
    var body: some View {
        HStack(spacing: 16) {
            // Checkbox
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    bounceScale = 0.8
                }
                
                onToggle(task.id)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        bounceScale = 1.0
                    }
                }
            }) {
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
            .buttonStyle(PlainButtonStyle())
            
            // Task Icon with Category Color
            Image(systemName: task.icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(task.category.color.opacity(0.3))
                )
                .overlay(
                    Circle()
                        .stroke(task.category.color.opacity(0.6), lineWidth: 1)
                )
            
            // Task Details
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 8) {
                    Text(task.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .strikethrough(task.isCompleted)
                    
                    if task.isNewlyUnlocked {
                        Text("NEW!")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.yellow)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.yellow.opacity(0.2))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.yellow.opacity(0.6), lineWidth: 1)
                            )
                    }
                    
                    Spacer()
                }
                
                Text(task.description)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(3)
                
                // Task metadata - clean and focused
                HStack(spacing: 10) {
                    // Category badge
                    HStack(spacing: 4) {
                        Text(task.category.emoji)
                            .font(.system(size: 10))
                        Text(task.category.displayName)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(task.category.color)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(task.category.color.opacity(0.15))
                    )
                    
                    // Estimated time
                    HStack(spacing: 3) {
                        Image(systemName: "clock")
                            .font(.system(size: 9))
                        Text("\(task.estimatedMinutes)m")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.6))
                    
                    Spacer()
                }
            }
            
            Spacer()
            
            // Completion indicator
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
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(task.isCompleted ? 0.1 : 0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(task.isCompleted ? 0.3 : 0.1), lineWidth: 1)
        )
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
