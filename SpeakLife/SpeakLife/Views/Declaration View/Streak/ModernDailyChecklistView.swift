//
//  ModernDailyChecklistView.swift
//  SpeakLife
//
//  Modern, clean daily checklist with clear TODAY emphasis
//

import SwiftUI
import FirebaseAnalytics

struct ModernDailyChecklistView: View {
    @ObservedObject var viewModel: EnhancedStreakViewModel
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @State private var showInfoSheet = false
    @State private var completedTasks = Set<String>()
    @State private var animateProgress = false
    @State private var celebrationScale: CGFloat = 1.0
    var onClose: (() -> Void)? = nil
    
    private var motivationalText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let completed = viewModel.todayChecklist.completedTasksCount
        let total = viewModel.todayChecklist.tasks.count
        
        if completed == total {
            return "Amazing! All tasks completed! 🎉"
        } else if completed > 0 {
            return "Great progress! Keep going! 💪"
        } else {
            switch hour {
            case 5..<12: return "Start your day strong! 🌅"
            case 12..<17: return "Keep the momentum going! 💪"
            case 17..<21: return "Finish today strong! 🌟"
            default: return "End your day with purpose! 🙏"
            }
        }
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Modern header with TODAY emphasis
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Today's Tasks")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            HStack(spacing: 6) {
                                Text(Date().formatted(.dateTime.weekday(.wide).month().day()))
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.7))
                                
                                if viewModel.streakStats.currentStreak > 0 {
                                    Text("•")
                                        .foregroundColor(.white.opacity(0.5))
                                    HStack(spacing: 4) {
                                        Text("🔥")
                                        Text("\(viewModel.streakStats.currentStreak) day streak")
                                            .font(.subheadline)
                                            .foregroundColor(.orange)
                                    }
                                }
                            }
                        }
                        
                        Spacer()
                        
                        // Task counter instead of percentage
                        VStack(spacing: 4) {
                            Text("\(viewModel.todayChecklist.completedTasksCount)")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .scaleEffect(celebrationScale)
                            Text("of \(viewModel.todayChecklist.tasks.count)")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.1))
                        )
                        
                        // Close button (if needed)
                        if let onClose = onClose {
                            Button(action: onClose) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                    }
                    
                    // Motivational text
                    Text(motivationalText)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Clean progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.1))
                                .frame(height: 8)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: viewModel.todayChecklist.isCompleted ? 
                                            [.green, .green.opacity(0.8)] : 
                                            [.blue, .blue.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * viewModel.todayChecklist.completionProgress, height: 8)
                                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: viewModel.todayChecklist.completionProgress)
                        }
                    }
                    .frame(height: 8)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)
                
                // Scrollable content with cleaner layout
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        // Today's Tasks Section
                        LazyVStack(spacing: 10) {
                            ForEach(Array(viewModel.todayChecklist.tasks.enumerated()), id: \.element.id) { index, task in
                                ModernTaskRow(
                                    task: task,
                                    onToggle: { taskId in
                                        print("🔄 Task toggle called for: \(taskId), isCompleted: \(task.isCompleted)")
                                        
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            if task.isCompleted {
                                                viewModel.uncompleteTask(taskId: taskId)
                                                completedTasks.remove(taskId)
                                                print("✅ Task uncompleted: \(taskId)")
                                            } else {
                                                viewModel.completeTask(taskId: taskId)
                                                completedTasks.insert(taskId)
                                                print("✅ Task completed: \(taskId)")
                                                
                                                // Haptic feedback
                                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                                
                                                // Celebration animation
                                                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                                    celebrationScale = 1.2
                                                }
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                                        celebrationScale = 1.0
                                                    }
                                                }
                                            }
                                        }
                                    }
                                )
                                .zIndex(Double(viewModel.todayChecklist.tasks.count - index)) // Ensure proper layering
                                .allowsHitTesting(true) // Explicitly allow hit testing
                                .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Minimal Coming Soon section (only show next unlock)
                        let upcomingTasks = viewModel.getUpcomingUnlocks(for: viewModel.streakStats.currentStreak)
                        if let nextTask = upcomingTasks.first {
                            VStack(spacing: 8) {
                                HStack {
                                    Image(systemName: "sparkles")
                                        .font(.caption)
                                        .foregroundColor(.yellow)
                                    Text("Unlock tomorrow")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.white.opacity(0.6))
                                    Spacer()
                                }
                                
                                HStack(spacing: 12) {
                                    Image(systemName: nextTask.icon)
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.4))
                                        .frame(width: 24, height: 24)
                                        .background(
                                            Circle()
                                                .fill(Color.white.opacity(0.05))
                                        )
                                    
                                    Text(nextTask.title)
                                        .font(.footnote)
                                        .foregroundColor(.white.opacity(0.5))
                                    
                                    Spacer()
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.white.opacity(0.03))
                                )
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                        }
                        
                        // Bottom spacing for last task accessibility
                        Color.clear.frame(height: 80)
                    }
                    .padding(.top, 8)
                }
            }
            .clipped() // Prevent overflow issues
            
            // Confetti for completion
            if viewModel.todayChecklist.isCompleted {
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
                        endPoint: .bottom
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .sheet(isPresented: $showInfoSheet) {
            DailyChecklistInfoSheet()
        }
        .onAppear {
            Analytics.logEvent("daily_checklist_viewed", parameters: [
                "current_streak": viewModel.streakStats.currentStreak,
                "completed_tasks": viewModel.todayChecklist.completedTasksCount,
                "total_tasks": viewModel.todayChecklist.tasks.count
            ])
        }
    }
}

// MARK: - Modern Task Row
struct ModernTaskRow: View {
    let task: DailyTask
    let onToggle: (String) -> Void
    @State private var checkmarkScale: CGFloat = 1.0
    @State private var bounceScale: CGFloat = 1.0
    
    var body: some View {
        Button(action: {
            print("📝 ModernTaskRow button tapped for task: \(task.title)")
            
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                checkmarkScale = 0.8
                bounceScale = 0.95
            }
            
            onToggle(task.id)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    checkmarkScale = 1.0
                    bounceScale = 1.0
                }
            }
        }) {
            HStack(spacing: 16) {
                // Large, satisfying checkbox
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(task.isCompleted ? Color.green : Color.clear)
                        .frame(width: 40, height: 40)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(task.isCompleted ? Color.green : Color.white.opacity(0.6), lineWidth: 2)
                        )
                    
                    if task.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .scaleEffect(checkmarkScale)
                    }
                }
            
                // Task content
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(task.title)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .strikethrough(task.isCompleted)
                            .multilineTextAlignment(.leading)
                        
                        Spacer()
                        
                        // Time badge
                        Text("\(task.estimatedMinutes)m")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.1))
                            )
                    }
                    
                    Text(task.description)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    // Simple category badge
                    HStack(spacing: 4) {
                        Text(task.category.emoji)
                            .font(.caption)
                        Text(task.category.displayName)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(task.category.color)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(task.category.color.opacity(0.15))
                    )
                }
                
                // Completion indicator
                if task.isCompleted {
                    VStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                        
                        if let completedAt = task.completedAt {
                            Text(DateFormatter.timeFormatter.string(from: completedAt))
                                .font(.system(size: 9))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(bounceScale)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(task.isCompleted ? Color.white.opacity(0.08) : Color.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(task.isCompleted ? Color.green.opacity(0.3) : Color.white.opacity(0.1), lineWidth: 1)
        )
        .contentShape(Rectangle()) // Ensure entire area is tappable
    }
}

#if DEBUG
struct ModernDailyChecklistView_Previews: PreviewProvider {
    static var previews: some View {
        ModernDailyChecklistView(viewModel: EnhancedStreakViewModel())
            .background(Color.black)
    }
}
#endif
