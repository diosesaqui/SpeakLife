//
//  ModernDailyChecklistView.swift
//  SpeakLife
//
//  Modern, clean daily checklist with clear TODAY emphasis
//

import SwiftUI
import FirebaseAnalytics
import CoreData

struct ModernDailyChecklistView: View {
    @ObservedObject var viewModel: EnhancedStreakViewModel
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @EnvironmentObject var devotionalViewModel: DevotionalViewModel
    @EnvironmentObject var audioDeclarationViewModel: AudioDeclarationViewModel
    @EnvironmentObject var tabViewModel: TabViewModel
    @EnvironmentObject var themeViewModel: ThemeViewModel
    @EnvironmentObject var declarationStore: DeclarationViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isIPad: Bool { horizontalSizeClass == .regular }
    @State private var showInfoSheet = false
    @State private var showDevotional = false
    @State private var showBibleChat = false
    @State private var showJournal = false
    @State private var completedTasks = Set<String>()
    @State private var animateProgress = false
    @State private var celebrationScale: CGFloat = 1.0
    @State private var showCelebration = false
    var onClose: (() -> Void)? = nil
    /// True when shown as the root "Today" tab (no modal chrome / close button).
    var isHomeTab: Bool = false

    // MARK: - Task Navigation

    private func handleTaskNavigation(_ task: DailyTask) {
        switch task.navigationDestination {
        case .audioTab:
            // Just open the Audio tab and let the user choose what to play —
            // no forced filter, no autoplay.
            if let onClose = onClose { onClose() } else { dismiss() }
            tabViewModel.goToAudio()
        case .devotional:
            showDevotional = true
        case .bibleChat:
            showBibleChat = true
        case .journal:
            showJournal = true
        case .burst:
            openBurst()
        case .none:
            viewModel.completeTask(taskId: task.id)
        }
    }

    /// Reuse the feed's fully-wired burst cover: surface the Speak tab, then ask
    /// it to present the burst. Works whether the checklist is the root tab or a
    /// sheet (dismiss is a no-op at a tab root).
    private func openBurst() {
        if let onClose = onClose { onClose() } else { dismiss() }
        tabViewModel.goToDeclarations()
        // Delay lets the feed tab mount and subscribe before we post (first
        // launch may not have instantiated it yet).
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            NotificationCenter.default.post(name: Notification.Name("ShowDailyDeclarationBurst"), object: nil)
        }
    }

    /// Surface the user's Personal Declaration via the feed's existing card flow
    /// (it loads from the repository and presents on this flag change).
    private func openPersonalDeclaration() {
        if let onClose = onClose { onClose() } else { dismiss() }
        tabViewModel.goToDeclarations()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            appState.scrollToPersonalDeclaration = true
        }
    }

    private func getUserTopCategories() -> [String] {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: "userSelectedCategories"),
           let categories = try? JSONDecoder().decode([String].self, from: data) {
            return Array(categories.prefix(2))
        }
        if let single = defaults.string(forKey: "selectedCategory") { return [single] }
        return []
    }

    /// Matches the declaration feed's themed backdrop (including a user-chosen
    /// custom image) so the checklist reflects the theme the user picked. A dark
    /// scrim keeps the white text and cards legible on lighter themes.
    private var themeBackground: some View {
        ZStack {
            if themeViewModel.showUserSelectedImage, let image = themeViewModel.selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(themeViewModel.selectedTheme.backgroundImageString)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            }
            LinearGradient(
                colors: [Color.black.opacity(0.45), Color.black.opacity(0.65)],
                startPoint: .top, endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }

    /// A single declaration for the user's selected (onboarding) category that
    /// stays stable for the whole calendar day. Reads the already-loaded
    /// declarations; returns nil until they load, so the card appears reactively
    /// once `declarationStore` publishes.
    private var declarationOfTheDay: Declaration? {
        let all = declarationStore.allAvailableDeclarations
        guard !all.isEmpty else { return nil }
        let category = declarationStore.selectedCategory
        var pool = all.filter { $0.category == category && $0.contentType == .affirmation }
        if pool.isEmpty { pool = all.filter { $0.contentType == .affirmation } }
        guard !pool.isEmpty else { return nil }
        let day = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        return pool[day % pool.count]
    }

    /// Time-aware, personalized greeting (Calm / Haven style). Falls back to a
    /// plain greeting when no name was captured during onboarding.
    private var greeting: String {
        let base: String
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12:  base = "Good morning"
        case 12..<17: base = "Good afternoon"
        default:      base = "Good evening"
        }
        let name = UserDefaults.standard.string(forKey: "userName") ?? ""
        return name.isEmpty ? base : "\(base), \(name)"
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
                // MARK: Header — greeting, streak, and week-at-a-glance
                VStack(spacing: 16) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(greeting)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)

                            Text(Date().formatted(.dateTime.weekday(.wide).month().day()))
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.6))
                        }

                        Spacer()

                        if viewModel.streakStats.currentStreak > 0 {
                            HStack(spacing: 5) {
                                Text("🔥").font(.system(size: 15))
                                Text("\(viewModel.streakStats.currentStreak)")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(.orange)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(Color.orange.opacity(0.15)))
                            .accessibilityLabel("\(viewModel.streakStats.currentStreak) day streak")
                        }

                        // Close button only when presented modally — the root
                        // "Today" tab has nothing to dismiss to.
                        if !isHomeTab {
                            Button(action: {
                                if let onClose = onClose {
                                    onClose()
                                } else {
                                    dismiss()
                                }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.white.opacity(0.4))
                            }
                            .padding(.leading, 4)
                        }
                    }

                    // Week-at-a-glance streak strip (the marquee return-driver)
                    WeekStreakStrip(currentStreak: viewModel.streakStats.currentStreak)

                    // Progress-aware nudge toward securing today's streak
                    Text(motivationalText)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.85))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)
                
                // Scrollable content with cleaner layout
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        // Declaration of the Day — themed to the user's category
                        if let declaration = declarationOfTheDay {
                            DeclarationOfTheDayCard(declaration: declaration) {
                                AnalyticsService.shared.track("declaration_of_the_day_tapped", parameters: [
                                    "category": declaration.category.rawValue
                                ])
                                if let onClose = onClose { onClose() } else { dismiss() }
                                tabViewModel.goToDeclarations()
                            }
                            .padding(.horizontal, 20)
                        }

                        // Today's Tasks Section
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
                            onNavigate: { task in handleTaskNavigation(task) },
                            onAllComplete: { dismiss() }
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
                        
                        // Quick access — the four core daily destinations, always
                        // reachable regardless of which tasks are unlocked today.
                        VStack(spacing: 10) {
                            HStack {
                                Text("JUMP BACK IN")
                                    .font(.system(size: 10, weight: .bold)).tracking(1.5)
                                    .foregroundColor(.white.opacity(0.35))
                                Spacer()
                            }
                            HStack(spacing: 10) {
                                QuickActionTile(icon: "bolt.fill", label: "Burst",
                                                tint: Color(hex: "#7C3AED"), action: openBurst)
                                if appState.hasPersonalDeclaration {
                                    QuickActionTile(icon: "hands.sparkles.fill", label: "My Word",
                                                    tint: Color(hex: "#CA8A04")) { openPersonalDeclaration() }
                                }
                                QuickActionTile(icon: "book.fill", label: "Devotional",
                                                tint: Color(hex: "#0EA5E9")) { showDevotional = true }
                                QuickActionTile(icon: "bubble.left.and.text.bubble.right.fill", label: "Ask Bible",
                                                tint: Color(hex: "#059669")) { showBibleChat = true }
                                QuickActionTile(icon: "pencil.and.scribble", label: "Journal",
                                                tint: Color(hex: "#B45309")) { showJournal = true }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)

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
        .background(themeBackground)
        .sheet(isPresented: $showInfoSheet) {
            DailyChecklistInfoSheet()
        }
        .sheet(isPresented: $showDevotional) {
            DevotionalView(viewModel: devotionalViewModel)
        }
        .sheet(isPresented: $showBibleChat) {
            // The conversational Bible Chat (not the topic picker). Inject the
            // env objects explicitly since SwiftUI doesn't reliably propagate
            // them across the sheet hop.
            BibleChatConversationView()
                .environmentObject(subscriptionStore)
                .environmentObject(appState)
                .environmentObject(declarationStore)
        }
        .sheet(isPresented: $showJournal) {
            JournalEntrySheet(category: getUserTopCategories().first)
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
            // Routed through AnalyticsService so the home/checklist surface shows
            // up in PostHog retention + funnels, not Firebase alone.
            AnalyticsService.shared.track("home_checklist_viewed", parameters: [
                "current_streak": viewModel.streakStats.currentStreak,
                "completed_tasks": viewModel.todayChecklist.completedTasksCount,
                "total_tasks": viewModel.todayChecklist.tasks.count,
                "is_streak_earned": viewModel.todayChecklist.isStreakEarned
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

// MARK: - Optimized Task Row (Super Responsive)
struct OptimizedTaskRow: View {
    let task: DailyTask
    let onToggle: (String) -> Void
    @State private var isPressed = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Ultra-responsive checkbox - maximum tap area
            ZStack {
                // Maximum invisible tap area
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 80, height: 80)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.easeOut(duration: 0.1)) {
                            isPressed = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.easeOut(duration: 0.1)) {
                                isPressed = false
                            }
                        }
                        onToggle(task.id)
                    }
                
                // Visual checkbox
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
            
            // Task content (read-only, not tappable to avoid conflicts)
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

// MARK: - Declaration of the Day

struct DeclarationOfTheDayCard: View {
    let declaration: Declaration
    let onTap: () -> Void

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onTap()
        }) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("DECLARATION OF THE DAY")
                        .font(.system(size: 10, weight: .bold)).tracking(1.5)
                        .foregroundColor(.white.opacity(0.6))
                    Spacer()
                    Image(systemName: "quote.bubble.fill")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
                Text(declaration.text)
                    .font(.system(size: 18, weight: .semibold, design: .serif))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                if let book = declaration.book, !book.isEmpty {
                    Text(book)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.65))
                }
                HStack {
                    Spacer()
                    Text("Speak it →")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(LinearGradient(
                        colors: [Color.white.opacity(0.12), Color.white.opacity(0.05)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.12), lineWidth: 1))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Quick Access Tile

struct QuickActionTile: View {
    let icon: String
    let label: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            VStack(spacing: 8) {
                ZStack {
                    Circle().fill(tint.opacity(0.22)).frame(width: 46, height: 46)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.05)))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Journal Entry Sheet
//
// Lightweight, self-contained journaling surface saved via JournalRepository.
// The prompt is seeded from the user's onboarding category so the reflection
// connects to what brought them to SpeakLife.

private struct ClearTextEditorBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.scrollContentBackground(.hidden)
        } else {
            content
        }
    }
}

struct JournalEntrySheet: View {
    let category: String?
    @Environment(\.dismiss) private var dismiss
    @State private var text: String = ""
    @FocusState private var focused: Bool

    private var prompt: String { JournalEntrySheet.prompt(for: category) }

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.1, green: 0.15, blue: 0.3), Color(red: 0.02, green: 0.07, blue: 0.15)],
                    startPoint: .top, endPoint: .bottom
                ).ignoresSafeArea()

                VStack(alignment: .leading, spacing: 16) {
                    Text(prompt)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.top, 8)

                    ZStack(alignment: .topLeading) {
                        if text.isEmpty {
                            Text("Write freely. No one sees this but you and God.")
                                .font(.system(size: 15))
                                .foregroundColor(.white.opacity(0.35))
                                .padding(.top, 10)
                                .padding(.leading, 6)
                        }
                        TextEditor(text: $text)
                            .focused($focused)
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                            .modifier(ClearTextEditorBackground())
                            .frame(maxHeight: .infinity)
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.06)))
                }
                .padding(20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Journal").font(.system(size: 18, weight: .bold)).foregroundColor(.white)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }.foregroundColor(.white.opacity(0.7))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { focused = true }
        }
    }

    private func save() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { dismiss(); return }
        let context = PersistenceController.shared.container.viewContext
        let entry = JournalEntry(context: context)
        entry.text = trimmed
        entry.category = category
        Task {
            do {
                try await JournalRepository(context: context).create(entry)
                AnalyticsService.shared.track("journal_entry_saved", parameters: [
                    "category": category ?? "none",
                    "char_count": trimmed.count,
                    "source": "checklist"
                ])
            } catch {
                // Don't leave an orphaned inserted object that a later viewContext
                // save could flush; discard it.
                context.perform { context.delete(entry) }
            }
        }
        PremiumHaptics.affirmationCompleted()
        dismiss()
    }

    /// Category-seeded reflection prompt (onboarding-driven).
    private static func prompt(for category: String?) -> String {
        switch category?.lowercased() {
        case "anxiety":               return "Where do you need God's peace today?"
        case "healing", "innerhealing": return "Where are you inviting God to heal you?"
        case "wealth":                return "Where are you trusting God to provide?"
        case "love":                  return "Where do you need to receive or give God's love?"
        case "faith":                 return "Where is God asking you to trust Him more?"
        case "warfare":               return "What battle are you handing to God today?"
        case "identity":              return "What truth about who you are in Christ do you need to remember?"
        case "hope":                  return "Where do you need fresh hope today?"
        case "wisdom":                return "What decision needs God's wisdom right now?"
        case "destiny":               return "What is God stirring you toward?"
        default:                      return "What is God showing you today?"
        }
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
