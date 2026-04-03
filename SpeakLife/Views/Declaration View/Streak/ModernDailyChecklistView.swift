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
    @EnvironmentObject var devotionalViewModel: DevotionalViewModel
    @EnvironmentObject var audioDeclarationViewModel: AudioDeclarationViewModel
    @EnvironmentObject var tabViewModel: TabViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isIPad: Bool { horizontalSizeClass == .regular }
    @State private var showInfoSheet = false
    @State private var showDevotional = false
    @State private var completedTasks = Set<String>()
    @State private var animateProgress = false
    @State private var celebrationScale: CGFloat = 1.0
    @State private var showCelebration = false
    var onClose: (() -> Void)? = nil

    // MARK: - Task Navigation

    /// Routes user to the correct in-app destination when they tap a checklist task row.
    private func handleTaskNavigation(_ task: DailyTask) {
        switch task.navigationDestination {

        case .audioTab:
            // 1. Compute the best audio recommendation based on onboarding categories
            let userCategories = getUserTopCategories()
            let availableFilterIds = audioDeclarationViewModel.dynamicFilters.map { $0.id }
            let recommendation = AudioRecommendationEngine.recommend(
                userCategories: userCategories,
                contentByFilter: audioDeclarationViewModel.contentByFilter,
                availableFilterIds: availableFilterIds
            )
            // 2. Pre-configure the audio tab
            audioDeclarationViewModel.setSelectedFilter(recommendation.filterId)
            audioDeclarationViewModel.checklistRecommendedEpisode = recommendation.episode
            // 3. Dismiss checklist sheet, then switch to audio tab
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                tabViewModel.goToAudio()
            }

        case .devotional:
            showDevotional = true

        case .burst:
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NotificationCenter.default.post(
                    name: Notification.Name("ShowDailyDeclarationBurst"),
                    object: nil
                )
            }

        case .none:
            // No navigation — treat as a simple toggle
            viewModel.completeTask(taskId: task.id)
        }
    }

    /// Reads the user's top 2 onboarding categories from UserDefaults.
    private func getUserTopCategories() -> [String] {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: "userSelectedCategories"),
           let categories = try? JSONDecoder().decode([String].self, from: data) {
            return Array(categories.prefix(2))
        }
        if let single = defaults.string(forKey: "selectedCategory") {
            return [single]
        }
        return []
    }
    
    private var motivationalText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let completed = viewModel.todayChecklist.completedTasksCount
        let total = viewModel.todayChecklist.tasks.count
        let streakEarned = viewModel.todayChecklist.isStreakEarned

        if completed == total {
            return "All tasks complete — you went above and beyond! 🎉"
        } else if streakEarned {
            return "Streak secured! 🔥 Bonus tasks below for extra growth."
        } else if completed > 0 {
            return "Great progress! Complete your Burst to lock in today's streak. 💪"
        } else {
            switch hour {
            case 5..<12: return "Start your day strong! Complete your Burst 🌅"
            case 12..<17: return "Don't forget your Burst — streak is on the line! 💪"
            case 17..<21: return "Complete your Burst before midnight to keep your streak 🔥"
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
                        
                        // Devotional button
                        Button(action: { showDevotional = true }) {
                            VStack(spacing: 4) {
                                Image(systemName: "book.pages.fill")
                                    .font(.title)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                Text("Devotional")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.1))
                            )
                        }
                        
                        // On iPad: always show close button (fullScreenCover has no swipe-to-dismiss)
                        // On iPhone: only show if an onClose callback was explicitly passed
                        if isIPad || onClose != nil {
                            Button(action: {
                                if let onClose = onClose {
                                    onClose()
                                } else {
                                    dismiss()
                                }
                            }) {
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
                        // ── Structured Day View ──
                        // Replaces the old LazyVStack of OptimizedTaskRows.
                        // Uses a modern sequential card-based layout:
                        //   • Progress ring at top
                        //   • Hero "Next Up" card for first incomplete task
                        //   • Dimmed upcoming tasks below
                        //   • Collapsed completed tasks at bottom
                        //   • Celebration screen when all done
                        StructuredDayView(
                            tasks: viewModel.todayChecklist.tasks,
                            streakCount: viewModel.streakStats.currentStreak,
                            onToggle: { taskId in
                                guard let task = viewModel.todayChecklist.tasks.first(where: { $0.id == taskId }) else { return }
                                if task.isCompleted {
                                    viewModel.uncompleteTask(taskId: taskId)
                                    completedTasks.remove(taskId)
                                } else {
                                    viewModel.completeTask(taskId: taskId)
                                    completedTasks.insert(taskId)
                                    withAnimation(.easeOut(duration: 0.1)) { celebrationScale = 1.15 }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        withAnimation(.easeOut(duration: 0.1)) { celebrationScale = 1.0 }
                                    }
                                }
                            },
                            onNavigate: { task in
                                handleTaskNavigation(task)
                            },
                            onAllComplete: {
                                dismiss()
                            }
                        )
                        .padding(.horizontal, 20)
                        
                        // Only show upcoming tasks if current list isn't completed
                        if !viewModel.todayChecklist.isCompleted {
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
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                            }
                        }
                        
                        // Bottom spacing for last task accessibility
                        Color.clear.frame(height: 80)
                    }
                    .padding(.top, 8)
                }
            }
            .clipped() // Prevent overflow issues
            
            // Modern celebration for full completion (temporary)
            if showCelebration {
                ModernCelebrationView(accentColor: .purple)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [Color(red: 0.1, green: 0.15, blue: 0.3), Color(red: 0.02, green: 0.07, blue: 0.15)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .sheet(isPresented: $showInfoSheet) {
            DailyChecklistInfoSheet()
        }
        .sheet(isPresented: $showDevotional) {
            DevotionalView(viewModel: devotionalViewModel)
        }
        // ── Streak celebrations & badges ──────────────────────────────────────
        // These fullScreenCovers were built in EnhancedStreakView but never wired
        // into the live checklist flow. Connecting them here so users actually see them.
        .fullScreenCover(isPresented: $viewModel.showFireAnimation) {
            FireStreakView(streakNumber: viewModel.streakStats.currentStreak)
                .onTapGesture {
                    viewModel.showFireAnimation = false
                }
        }
        .fullScreenCover(isPresented: $viewModel.showCompletionCelebration) {
            if let celebration = viewModel.celebrationData {
                CompletionCelebrationView(celebration: celebration)
            }
        }
        .fullScreenCover(isPresented: $viewModel.showBadgeUnlock) {
            if let badge = viewModel.badgeManager.recentlyUnlocked {
                BadgeUnlockView(badge: badge, isPresented: $viewModel.showBadgeUnlock)
                    .onDisappear { viewModel.dismissBadgeUnlock() }
            }
        }
        // ── Streak freeze used banner ─────────────────────────────────────────
        .overlay(alignment: .top) {
            if viewModel.showFreezeUsedMessage {
                HStack(spacing: 8) {
                    Text("🛡️")
                    Text("Streak freeze used — your streak is safe!")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(red: 0.2, green: 0.5, blue: 1.0).opacity(0.9))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                        withAnimation { viewModel.showFreezeUsedMessage = false }
                    }
                }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.showFreezeUsedMessage)
        .onAppear {
            Analytics.logEvent("daily_checklist_viewed", parameters: [
                "current_streak": viewModel.streakStats.currentStreak,
                "completed_tasks": viewModel.todayChecklist.completedTasksCount,
                "total_tasks": viewModel.todayChecklist.tasks.count
            ])
        }
        .onChange(of: viewModel.todayChecklist.isCompleted) { isCompleted in
            if isCompleted {
                // Show celebration immediately
                showCelebration = true
                
                // Hide celebration after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    withAnimation(.easeOut(duration: 0.8)) {
                        showCelebration = false
                    }
                }
            }
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

// MARK: - Optimized Task Row (Deep-Link Aware)
struct OptimizedTaskRow: View {
    let task: DailyTask
    let onToggle: (String) -> Void
    /// Called when the user taps the row body (not the checkbox). Use for navigation.
    let onNavigate: (DailyTask) -> Void
    @State private var isPressed = false

    /// True when this task has a destination to navigate to.
    private var isNavigable: Bool {
        task.navigationDestination != .none
    }

    var body: some View {
        HStack(spacing: 16) {
            // ── Checkbox ── (tap = toggle only)
            ZStack {
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 80, height: 80)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.easeOut(duration: 0.1)) { isPressed = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.easeOut(duration: 0.1)) { isPressed = false }
                        }
                        onToggle(task.id)
                    }

                RoundedRectangle(cornerRadius: 12)
                    .fill(task.isCompleted ? Color.green : Color.clear)
                    .frame(width: 44, height: 44)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(task.isCompleted ? Color.green : Color.white.opacity(0.6), lineWidth: 2)
                    )
                    .scaleEffect(isPressed ? 0.9 : 1.0)

                if task.isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                }
            }

            // ── Task content ── (tap = navigate if destination exists, else toggle)
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onNavigate(task)
            }) {
                HStack {
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
                                .background(Capsule().fill(Color.white.opacity(0.1)))
                        }

                        Text(task.description)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        HStack(spacing: 6) {
                            // Category badge
                            HStack(spacing: 4) {
                                Text(task.category.emoji).font(.caption)
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

                            // "Tap to open" affordance for navigable tasks
                            if isNavigable && !task.isCompleted {
                                HStack(spacing: 3) {
                                    Image(systemName: "arrow.right.circle")
                                        .font(.caption2)
                                    Text("Open")
                                        .font(.caption2)
                                }
                                .foregroundColor(.white.opacity(0.45))
                            }
                        }
                    }

                    // Completion star
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
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(task.isCompleted ? Color.white.opacity(0.08) : Color.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(task.isCompleted ? Color.green.opacity(0.3) : Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Instant Response Button Style
struct InstantResponseButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeOut(duration: 0.05), value: configuration.isPressed)
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
