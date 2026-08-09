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
    @EnvironmentObject var timerViewModel: TimerViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isIPad: Bool { horizontalSizeClass == .regular }
    @State private var showInfoSheet = false
    @State private var showDevotional = false
    @State private var showBibleChat = false
    @State private var showInbox = false
    /// Drives the red badge on the Inbox tile. A shared singleton rather than
    /// @StateObject — it outlives this view and is read from a background
    /// refresh, so the view observes it instead of owning it.
    @ObservedObject private var inboxUnread = InboxUnreadTracker.shared
    /// Same reasoning as `inboxUnread`: the Enforcement outlives this view and is
    /// advanced from the burst, so the view observes the shared service rather
    /// than owning it.
    @ObservedObject private var enforcementService = EnforcementService.shared
    @State private var showJournal = false
    @State private var showWarriorRoom = false
    @State private var showCreateYourOwn = false
    @State private var showBible = false
    @State private var showPrayers = false
    @State private var showLoveLetter = false
    @State private var completedTasks = Set<String>()
    @State private var animateProgress = false
    @State private var celebrationScale: CGFloat = 1.0
    @State private var showCelebration = false
    /// Everything the user is currently believing God for, oldest first. A
    /// premium user can be carrying several at once.
    @State private var activeDeclarations: [PersonalDeclaration] = []
    /// The one the Today feed puts in front of them: the first they haven't
    /// spoken yet today, falling back to the first if they've spoken them all.
    private var personalDeclaration: PersonalDeclaration? {
        activeDeclarations.first(where: { !$0.spokenToday }) ?? activeDeclarations.first
    }
    /// Computed once per body pass instead of once per tile subview.
    private var declarationsLeftToday: Int {
        activeDeclarations.filter { !$0.spokenToday }.count
    }
    /// The link under the declaration tile: a way into the full list, and for
    /// single-declaration users the nudge that they can carry more than one.
    private var seeAllDeclarationsLabel: String {
        activeDeclarations.count > 1
            ? "See all \(activeDeclarations.count)"
            : "Believing for something else too?"
    }
    // Modal presentations surfaced directly on the Today tab (instead of routing
    // the user over to the Speak feed and presenting there).
    @State private var showDailyBurst = false
    @State private var showPersonalDeclarationCard = false
    @State private var showMyDeclarations = false
    @State private var showPremium = false
    @State private var showBreakthroughFlow = false
    /// Pinned when the user taps "It Came to Pass" — the computed
    /// `personalDeclaration` can move to another burden once this one is closed
    /// out, so the celebration holds onto the exact declaration it's for.
    @State private var breakthroughDeclaration: PersonalDeclaration?
    @State private var showNewDeclarationSheet = false
    @State private var warriorRoomTestimonyPrefill: WarriorRoomTestimonyPrefill?
    var onClose: (() -> Void)? = nil
    /// True when shown as the root "Today" tab (no modal chrome / close button).
    var isHomeTab: Bool = false

    // MARK: - Task Navigation

    private func handleTaskNavigation(_ task: DailyTask) {
        switch task.navigationDestination {
        case .audioTab:
            // Foundation week (days 1-7): the task names one exact episode —
            // deep-link straight to it so the user lands on today's audio.
            if let recommendedAudioId = task.recommendedAudioId {
                audioDeclarationViewModel.pendingChecklistDeepLink =
                    .init(audioId: recommendedAudioId, requestedAt: Date())
            }
            // Day 8+: just open the Audio tab and let the user choose what to
            // play — no forced filter, no autoplay.
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

    /// Present the daily burst right here on the Today tab instead of routing
    /// the user over to the Speak feed.
    private func openBurst() {
        showDailyBurst = true
    }

    /// Present the user's Personal Declaration right here on the Today tab
    /// instead of routing over to the Speak feed. One declaration goes straight
    /// to its card; several open the list so they can work through them.
    private func openPersonalDeclaration() {
        if activeDeclarations.count > 1 {
            showMyDeclarations = true
        } else {
            showPersonalDeclarationCard = true
        }
    }

    private func reloadPersonalDeclarations() async {
        let active = await DIContainer.shared.personalDeclarationRepository.loadActive()
        await MainActor.run {
            activeDeclarations = active
            appState.hasPersonalDeclaration = !active.isEmpty
        }
    }

    private func getUserTopCategories() -> [String] {
        UserSelectedCategories.top()
    }

    /// True when the Enforcement card is on screen with a running campaign, so
    /// it is already carrying today's Burst CTA.
    ///
    /// Mirrors the card's own render condition exactly — same Remote Config
    /// flag, same active-campaign check — because the two must never disagree.
    /// If the checklist demoted the Burst while the card wasn't there, the
    /// day's most important action would have no loud entry point at all.
    ///
    /// Whenever the Burst is still outstanding and a campaign is running, the
    /// card is in its `.speak` state, so the gold CTA is present to take over.
    private var campaignOwnsBurst: Bool {
        subscriptionStore.enforcementEnabled && enforcementService.activeEnforcement != nil
    }

    /// Whether today's Daily Burst is already checked off.
    ///
    /// The Enforcement card needs this and can't see it: a campaign begun after
    /// the Burst was spoken has nothing to advance today, because `completeTask`
    /// early-returns on an already-completed task. Read off the task itself
    /// rather than `isStreakEarned`, which answers a different question and is
    /// free to stop meaning "the Burst is done".
    private var isBurstCompletedToday: Bool {
        viewModel.todayChecklist.tasks
            .first(where: { $0.id == "complete_daily_burst" })?.isCompleted ?? false
    }

    /// Turns "my marriage is falling apart and I can't sleep" into a seven-day
    /// week built from the reviewed declaration pool.
    ///
    /// `match` is the Claude call (with a local keyword fallback baked in, so a
    /// dead network still produces a category). `matchAll` is a purely local
    /// keyword scan, so the secondary themes cost nothing extra.
    private func startMatchedEnforcement(from text: String,
                                         completion: @escaping (Bool) -> Void) {
        Task {
            let matcher = DIContainer.shared.declarationMatcher
            let primary = await matcher.match(input: text).category
            let secondaries = matcher.matchAll(input: text)
                .filter { $0 != primary }
                .filter { EnforcementAssembler.isCampaignable($0) }

            let pool = await MainActor.run { declarationStore.allAvailableDeclarations }
            let topSecondaries = Array(secondaries.prefix(2))

            // Let Claude choose the seven from the reviewed pool, reading their
            // actual sentence rather than a keyword bucket. It returns indexes,
            // never text, so nothing unreviewed can slip in. Any failure falls
            // through to keyword assembly, which always produces a real week.
            let candidates = await MainActor.run {
                enforcementService.curationCandidates(primary: primary,
                                                      secondaries: topSecondaries,
                                                      pool: pool)
            }
            let curated = await EnforcementCurator.curate(situation: text,
                                                          candidates: candidates)

            await MainActor.run {
                let started: Enforcement?
                if let curated {
                    started = enforcementService.startCurated(curated, primary: primary,
                                                              isPremium: subscriptionStore.isPremium)
                } else {
                    started = enforcementService.startMatched(
                        primary: primary,
                        secondaries: topSecondaries,
                        pool: pool,
                        isPremium: subscriptionStore.isPremium
                    )
                }
                if let started {
                    AnalyticsService.shared.track("enforcement_started", parameters: [
                        "theme": started.theme,
                        "source": curated != nil ? "curated" : "matched",
                        "secondaries": topSecondaries.map(\.rawValue).joined(separator: ",")
                    ])
                }
                completion(started != nil)
            }
        }
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
            return "All ground taken today. 🎉 You went above and beyond."
        } else if streakEarned {
            return "Today's ground is yours. 🔥 Bonus below for extra growth."
        } else if completed > 0 {
            return "Great start. Speak your declarations and take more ground 💪"
        } else {
            switch hour {
            case 5..<12:  return "Speak today's declarations and take more ground 🌅"
            case 12..<17: return "Speak today's declarations and take more ground 🔥"
            case 17..<21: return "Speak today's declarations and take more ground 🔥"
            default:      return "Speak today's declarations and take more ground 🙏"
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
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 2)

                            Text(Date().formatted(.dateTime.weekday(.wide).month().day()))
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.6))
                                .tracking(0.5)
                        }

                        Spacer()

                        if viewModel.streakStats.currentStreak > 0 {
                            HStack(spacing: 5) {
                                Text("🔥").font(.system(size: 15))
                                Text("\(viewModel.streakStats.currentStreak)")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, DS.Spacing.sm)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(DS.Gradient.ember))
                            .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1))
                            .shadow(color: Color.orange.opacity(0.45), radius: 8, x: 0, y: 3)
                            .accessibilityLabel("\(viewModel.streakStats.currentStreak) day streak")
                        }

                        // Crown upgrade chip — non-subscribers only. Mirrors the
                        // Speak feed's crown button so the paywall stays one tap
                        // away now that Today owns the home tab.
                        if !subscriptionStore.isPremium {
                            Button(action: {
                                showPremium = true
                                AnalyticsService.shared.track(Event.tryPremiumTapped, parameters: ["source": "today_tab"])
                            }) {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(DS.Palette.gold)
                                    .frame(width: 34, height: 34)
                                    .background(Circle().fill(Color.white.opacity(0.12)))
                                    .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
                            }
                            .accessibilityLabel("Upgrade to Premium")
                            .padding(.leading, 4)
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
                    WeekStreakStrip(
                        currentStreak: viewModel.streakStats.currentStreak,
                        lastCompletedDate: viewModel.streakStats.lastCompletedDate
                    )

                    // Hero progress panel: the day's focal point. A gradient ring
                    // paired with the progress-aware nudge, floated on glass.
                    HStack(spacing: DS.Spacing.md) {
                        DSProgressRing(
                            completed: viewModel.todayChecklist.completedTasksCount,
                            total: viewModel.todayChecklist.tasks.count
                        )
                        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                            Text("TODAY'S PROGRESS")
                                .font(.system(size: 11, weight: .bold))
                                .tracking(1.4)
                                .foregroundColor(DS.Palette.gold.opacity(0.9))
                            Text(motivationalText)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(DS.Spacing.md)
                    .dsGlass(cornerRadius: DS.Radius.lg, strokeOpacity: 0.16, elevation: DS.Elevation.medium)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)
                .dsAppear(0)

                // Scrollable content with cleaner layout
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        // The active campaign sits above today's tasks: it's the
                        // reason the user came back, so it leads. Renders nothing
                        // until the user clears the foundation week.
                        if subscriptionStore.enforcementEnabled {
                            EnforcementCard(
                                service: enforcementService,
                                isPremium: subscriptionStore.isPremium,
                                totalDaysCompleted: viewModel.totalDaysCompleted,
                                burstCompletedToday: isBurstCompletedToday,
                                onStart: { enforcement in
                                    guard enforcementService.startEnforcement(id: enforcement.id,
                                                                  isPremium: subscriptionStore.isPremium) else { return }
                                    AnalyticsService.shared.track("enforcement_started",
                                                                  parameters: ["theme": enforcement.theme])
                                },
                                onOpenAudio: { day in
                                    audioDeclarationViewModel.pendingChecklistDeepLink =
                                        .init(audioId: day.audioId, requestedAt: Date())
                                    if let onClose = onClose { onClose() } else { dismiss() }
                                    tabViewModel.goToAudio()
                                },
                                onOpenBurst: {
                                    AnalyticsService.shared.track("enforcement_burst_opened", parameters: [
                                        "day": enforcementService.progressSnapshot.currentDay
                                    ])
                                    openBurst()
                                },
                                onLockedTap: {
                                    AnalyticsService.shared.track("enforcement_locked_tapped")
                                    AnalyticsService.shared.trackPaywallImpression(paywallId: "enforcement_card")
                                    showPremium = true
                                },
                                onSwitch: {
                                    let snapshot = enforcementService.progressSnapshot
                                    AnalyticsService.shared.track("enforcement_abandoned", parameters: [
                                        "enforcement_id": snapshot.activeEnforcementId ?? "unknown",
                                        "last_day": snapshot.currentDay
                                    ])
                                    enforcementService.abandon()
                                },
                                onDescribe: { text, completion in
                                    startMatchedEnforcement(from: text, completion: completion)
                                }
                            )
                            .padding(.horizontal, 20)
                            .dsAppear(0.04)
                        }

                        // Today's Tasks Section
                        StructuredDayView(
                            tasks: viewModel.todayChecklist.tasks,
                            streakCount: viewModel.streakStats.currentStreak,
                            burstOwnedByCampaign: campaignOwnsBurst,
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
                            onAllComplete: {
                                // "Done" on the day-complete celebration. As the
                                // root Today tab there's nothing to dismiss, so send
                                // the user into the declaration feed to keep going.
                                // When opened modally, honor the real dismissal.
                                if isHomeTab {
                                    tabViewModel.goToDeclarations()
                                } else if let onClose = onClose {
                                    onClose()
                                } else {
                                    dismiss()
                                }
                            }
                        )
                        .padding(.horizontal, 20)
                        .dsAppear(0.08)

                        // Personal Declaration — the one thing the user is
                        // believing God for. Above the quick-action grid, not
                        // below it: everything above this point is something to
                        // DO, and the grid is a set of doorways. This card has a
                        // "Speak it" mic on it, so it belongs with the actions.
                        // It is also the only card on Today made of the user's
                        // own words, which outranks a shortcut to the Bible.
                        if appState.hasPersonalDeclaration, let declaration = personalDeclaration {
                            VStack(spacing: 8) {
                                PersonalDeclarationFeedTile(
                                    declaration: declaration,
                                    totalCount: activeDeclarations.count,
                                    remainingToday: declarationsLeftToday
                                ) {
                                    openPersonalDeclaration()
                                }

                                // Doubles as the way in to the full list and the
                                // nudge that they can be believing for more than
                                // one thing at a time.
                                Button {
                                    Juice.play(.tapLight)
                                    showMyDeclarations = true
                                } label: {
                                    Text(seeAllDeclarationsLabel)
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .foregroundColor(.white.opacity(0.5))
                                }
                                .buttonStyle(.dsPressable(feel: .tapLight, haptics: false))
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                            .dsAppear(0.12)
                        }

                        // Quick access — the four core daily destinations, always
                        // reachable regardless of which tasks are unlocked today.
                        // Sits below the actions above: these are doorways, not
                        // today's work.
                        VStack(spacing: 10) {
                            HStack {
                                Text("JUMP BACK IN")
                                    .font(.system(size: 11, weight: .bold))
                                    .tracking(1.4)
                                    .foregroundColor(DS.Palette.gold.opacity(0.9))
                                Spacer()
                            }
                            // Two rows of three so each tile keeps room to
                            // breathe (five-in-a-row crowded the labels).
                            HStack(spacing: 10) {
                                QuickActionTile(icon: "bolt.fill", label: "Burst",
                                                tint: Color(hex: "#7C3AED"), action: openBurst)
                                QuickActionTile(icon: "book.fill", label: "Devotional",
                                                tint: Color(hex: "#0EA5E9")) { showDevotional = true }
                                // Bible Chat owns its own tab, so this slot goes
                                // to the Inbox instead — broadcast messages had
                                // no surface of their own until now.
                                QuickActionTile(icon: "envelope.fill", label: "Inbox",
                                                tint: Color(hex: "#059669"),
                                                badgeCount: inboxUnread.unreadCount) { showInbox = true }
                            }
                            HStack(spacing: 10) {
                                QuickActionTile(icon: "pencil.and.scribble", label: "Journal",
                                                tint: Color(hex: "#B45309")) { showJournal = true }
                                QuickActionTile(icon: "wand.and.stars", label: "Create Own",
                                                tint: Color(hex: "#D97706")) { showCreateYourOwn = true }
                                QuickActionTile(icon: "hands.and.sparkles.fill", label: "Community",
                                                tint: Color(hex: "#EC4899")) { showWarriorRoom = true }
                            }
                            HStack(spacing: 10) {
                                QuickActionTile(icon: "book.closed.fill", label: "Bible",
                                                tint: Color(hex: "#4F46E5")) { showBible = true }
                                QuickActionTile(icon: "hands.sparkles.fill", label: "Prayers",
                                                tint: Color(hex: "#14B8A6")) { showPrayers = true }
                                QuickActionTile(icon: "heart.fill", label: "Love Letter",
                                                tint: Color(hex: "#F43F5E")) { showLoveLetter = true }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .dsAppear(0.16)

                        // Unlock tomorrow — a closing "come back tomorrow" teaser.
                        // Kept at the end so it caps the feed as a retention hook
                        // rather than interrupting the actionable sections above.
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
                                .padding(.top, 20)
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
        .background(themeBackground)
        .sheet(isPresented: $showInfoSheet) {
            DailyChecklistInfoSheet()
        }
        // Paywall from the header crown chip. Env objects injected explicitly
        // since SwiftUI doesn't reliably propagate them across the sheet hop.
        .sheet(isPresented: $showPremium) {
            PremiumView()
                .environmentObject(subscriptionStore)
                .environmentObject(appState)
                .environmentObject(declarationStore)
        }
        .sheet(isPresented: $showDevotional) {
            DevotionalView(viewModel: devotionalViewModel)
        }
        // Day 7. Presented full-screen so the win gets the whole screen, and so
        // the next-Enforcement offer isn't one swipe from being dismissed by accident.
        //
        // Bound with `item:` rather than `isPresented:` + `if let`. With the
        // latter, clearing `justCompleted` before flipping the bool renders the
        // cover with no content — a blank full-screen sheet the user cannot
        // dismiss. Here the nil assignment IS the dismissal, so the two can't
        // disagree, and the campaign that finished is non-optional inside.
        .fullScreenCover(item: $enforcementService.justCompleted) { completed in
            EnforcementCompletionView(
                completed: completed,
                nextOptions: enforcementService.catalog.filter { $0.id != completed.id },
                isPremium: subscriptionStore.isPremium,
                onStartNext: { enforcement in
                    guard enforcementService.startEnforcement(id: enforcement.id,
                                                  isPremium: subscriptionStore.isPremium) else { return }
                    AnalyticsService.shared.track("enforcement_started",
                                                  parameters: ["theme": enforcement.theme, "source": "completion"])
                    enforcementService.justCompleted = nil
                },
                onDone: { enforcementService.justCompleted = nil }
            )
        }
        .sheet(isPresented: $showBibleChat) {
            // The conversational Bible Chat (not the topic picker). Still reached
            // from a daily task's .bibleChat destination even though the quick
            // action now points at the Inbox. Inject the env objects explicitly
            // since SwiftUI doesn't reliably propagate them across the sheet hop.
            BibleChatConversationView()
                .environmentObject(subscriptionStore)
                .environmentObject(appState)
                .environmentObject(declarationStore)
        }
        // Inbox — every message SpeakLife has broadcast. subscriptionStore
        // injected explicitly since SwiftUI doesn't reliably propagate env
        // objects across the sheet hop.
        .sheet(isPresented: $showInbox) {
            SpeakLifeInboxView()
                .environmentObject(subscriptionStore)
        }
        .sheet(isPresented: $showJournal) {
            JournalEntrySheet(category: getUserTopCategories().first)
        }
        // Warrior Room — the community prayer wall, surfaced from Today as a
        // quick-access tile. subscriptionStore injected explicitly since SwiftUI
        // doesn't reliably propagate env objects across the sheet hop.
        .sheet(isPresented: $showWarriorRoom) {
            PrayerWallView()
                .environmentObject(subscriptionStore)
        }
        // Create Your Own — the full affirmations + journal builder. Opens on
        // its Affirmations tab by default. Env objects injected explicitly since
        // SwiftUI doesn't reliably propagate them across the sheet hop.
        .sheet(isPresented: $showCreateYourOwn) {
            CreateYourOwnView()
                .environmentObject(subscriptionStore)
                .environmentObject(appState)
                .environmentObject(declarationStore)
        }
        // Bible reader, Prayers, and Father's Love Letter — quick-access tiles.
        // Presented as sheets so iPhone gets swipe-to-dismiss (these views
        // otherwise relied on a NavigationLink back button).
        .sheet(isPresented: $showBible) {
            BibleView()
                .environmentObject(subscriptionStore)
                .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showPrayers) {
            WarriorView()
        }
        .sheet(isPresented: $showLoveLetter) {
            AbbasLoveView()
        }
        // Daily burst — presented modally on Today. Env objects injected
        // explicitly since SwiftUI doesn't reliably propagate them across the
        // cover hop. (viewModel is the EnhancedStreakViewModel the burst wants.)
        .fullScreenCover(isPresented: $showDailyBurst) {
            DailyDeclarationBurstView()
                .environmentObject(declarationStore)
                .environmentObject(themeViewModel)
                .environmentObject(timerViewModel)
                .environmentObject(viewModel)
                .environmentObject(subscriptionStore)
        }
        // Personal Declaration card — presented modally on Today. onBreakthrough
        // dismisses this card, then surfaces the breakthrough flow (attached to
        // the root below so it survives this sheet's dismissal).
        .sheet(isPresented: $showPersonalDeclarationCard, onDismiss: {
            // Speaking it updates the per-declaration counters, so re-read to
            // refresh the tile's day count and spoken-today state.
            Task { await reloadPersonalDeclarations() }
        }) {
            if let declaration = personalDeclaration {
                PersonalDeclarationCard(
                    declaration: declaration,
                    onBreakthrough: {
                        breakthroughDeclaration = declaration
                        showPersonalDeclarationCard = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showBreakthroughFlow = true
                        }
                    }
                )
            }
        }
        // The full list of everything they're believing for.
        .sheet(isPresented: $showMyDeclarations, onDismiss: {
            Task { await reloadPersonalDeclarations() }
        }) {
            MyDeclarationsView()
                .environmentObject(appState)
                .environmentObject(subscriptionStore)
        }
        .fullScreenCover(isPresented: $showBreakthroughFlow, onDismiss: {
            breakthroughDeclaration = nil
            Task { await reloadPersonalDeclarations() }
        }) {
            if let d = breakthroughDeclaration {
                BreakthroughFlowView(
                    declaration: d,
                    onDismiss: { showBreakthroughFlow = false },
                    onSetNew: {
                        showBreakthroughFlow = false
                        showNewDeclarationSheet = true
                    },
                    onShareToWarriorRoom: { prefill in
                        warriorRoomTestimonyPrefill = WarriorRoomTestimonyPrefill(text: prefill)
                    }
                )
                .environmentObject(appState)
            }
        }
        .sheet(item: $warriorRoomTestimonyPrefill) { prefill in
            WarriorRoomTestimonyComposer(
                initialText: prefill.text,
                initialIsTestimony: true
            )
            .environmentObject(subscriptionStore)
        }
        // Set-a-new-declaration onboarding (reached from the breakthrough flow).
        .fullScreenCover(isPresented: $showNewDeclarationSheet) {
            GeometryReader { geo in
                PersonalDeclarationOnboardingView(
                    viewModel: DIContainer.shared.makePersonalDeclarationViewModel(),
                    size: geo.size,
                    flow: "app"
                ) { newDeclaration in
                    if newDeclaration != nil {
                        appState.hasPersonalDeclaration = true
                    }
                    showNewDeclarationSheet = false
                    Task { await reloadPersonalDeclarations() }
                }
                .environmentObject(appState)
            }
            .ignoresSafeArea()
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
            // Load what they're believing for, for the bottom-of-feed tile.
            if appState.hasPersonalDeclaration {
                Task { await reloadPersonalDeclarations() }
            }
            // Start watching the broadcast counter that drives the Inbox
            // tile's badge. Idempotent, and the listener keeps the badge live
            // from then on — no polling, nothing to refresh on foreground.
            inboxUnread.start()
            // Fires only when the card is an actual OFFER — eligible with nothing
            // running. Firing it for an active campaign too would inflate the
            // denominator every day of every campaign and make start-rate look
            // permanently broken. Read start-rate as a ratio against this, never
            // as a raw count: the release-day backlog spikes it, then settles.
            if subscriptionStore.enforcementEnabled,
               !enforcementService.progress.isActive,
               enforcementService.isEligible(totalDaysCompleted: viewModel.totalDaysCompleted) {
                AnalyticsService.shared.track("enforcement_offered", parameters: [
                    "is_premium": subscriptionStore.isPremium
                ])
            }
        }
        .onChange(of: viewModel.todayChecklist.isCompleted) { isCompleted in
            if isCompleted {
                // Skip when the final completion arrived via iCloud sync —
                // the device that earned it already celebrated.
                guard !viewModel.consumeRemoteCompletionFlag() else { return }

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
                        Juice.play(.tapLight)
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

// MARK: - Quick Access Tile

struct QuickActionTile: View {
    let icon: String
    let label: String
    let tint: Color
    /// Unread count shown as a red badge on the icon. 0 hides it.
    var badgeCount: Int = 0
    let action: () -> Void

    var body: some View {
        Button(action: {
            Juice.play(.tapLight)
            action()
        }) {
            VStack(spacing: DS.Spacing.xs) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [tint.opacity(0.95), tint.opacity(0.55)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 52)
                        .shadow(color: tint.opacity(0.5), radius: 8, x: 0, y: 4)
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                }
                .overlay(alignment: .topTrailing) {
                    if badgeCount > 0 {
                        unreadBadge
                            .offset(x: 5, y: -3)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: badgeCount)
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.sm)
            .dsGlass(cornerRadius: DS.Radius.md, strokeOpacity: 0.12, elevation: DS.Elevation.low)
        }
        .buttonStyle(.dsPressable(feel: .tapLight, haptics: false))
    }

    /// Caps at 9+ so a long absence can't stretch the pill across the icon.
    private var unreadBadge: some View {
        Text(badgeCount > 9 ? "9+" : "\(badgeCount)")
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 5)
            .frame(minWidth: 19, minHeight: 19)
            .background(
                Capsule()
                    .fill(Color(hex: "#EF4444"))
                    .shadow(color: Color.black.opacity(0.35), radius: 3, x: 0, y: 1)
            )
            // Ring in the card's own dark backdrop so the badge reads as
            // lifted off the icon rather than painted onto it.
            .overlay(
                Capsule().stroke(Color.black.opacity(0.45), lineWidth: 1.5)
            )
            .accessibilityLabel("\(badgeCount) unread")
    }
}

// MARK: - Personal Declaration Feed Tile
//
// A full-width tile in the Today feed that keeps the actual declaration text
// and day count visible so the user is reminded — every day — of the one thing
// they're believing God for. Tapping it opens the full speak-it card.

struct PersonalDeclarationFeedTile: View {
    let declaration: PersonalDeclaration
    /// How many things the user is believing for in total.
    var totalCount: Int = 1
    /// How many of those they still haven't spoken today.
    var remainingToday: Int = 1
    let onTap: () -> Void

    private let gold = Color(red: 1, green: 0.82, blue: 0.28)

    private var headerLabel: String {
        totalCount > 1 ? "WHAT I'M BELIEVING FOR" : "YOUR DECLARATION"
    }

    /// With several burdens on the altar, "3 left today" is the number that
    /// actually moves them; with one, the day count carries more weight.
    private var trailingLabel: String {
        guard totalCount > 1 else { return "Day \(declaration.dayCount) of believing" }
        return remainingToday == 0
            ? "All \(totalCount) spoken today"
            : "\(remainingToday) of \(totalCount) left today"
    }

    var body: some View {
        Button(action: {
            Juice.play(.tapLight)
            onTap()
        }) {
            VStack(alignment: .leading, spacing: 12) {
                // Header — label + progress
                HStack(spacing: 6) {
                    Text("🙌").font(.system(size: 13))
                    Text(headerLabel)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(1.2)
                        .foregroundColor(gold)
                    Spacer()
                    Text(trailingLabel)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                }

                // Declaration text
                Text(declaration.declarationText)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                    .lineSpacing(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Footer — verse reference + speak affordance
                HStack(spacing: 6) {
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 11))
                        .foregroundColor(gold.opacity(0.8))
                    Text(declaration.verseReference)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.55))
                    Spacer()
                    HStack(spacing: 5) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Speak it")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(gold)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(gold.opacity(0.25), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.dsPressable(feel: .tapLight, haptics: false))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Your personal declaration, day \(declaration.dayCount). \(trailingLabel). \(declaration.declarationText)")
        .accessibilityHint("Opens your declaration to speak it")
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
    @State private var showSaveConfirmation = false
    @StateObject private var voiceManager = VoiceInputManager()
    @State private var voiceTask: Task<Void, Never>?
    @FocusState private var focused: Bool

    private var prompt: String { JournalEntrySheet.prompt(for: category) }

    var body: some View {
        ZStack {
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

                    // Voice dictation: speak the entry instead of typing.
                    voiceControls
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
        .onChange(of: voiceManager.voiceInputState) { state in
            // Recognition is final-only (no partial results), so the transcript
            // is ready once the recorder finishes transcribing.
            if state == .completed { appendTranscription(voiceManager.transcribedText) }
        }
        .onDisappear {
            // Cancel a pending permission request so it can't call
            // startListening() after the sheet is gone (which would leave an
            // orphan recording + audio session running for the full timeout).
            voiceTask?.cancel()
            voiceManager.stopListening()
        }

            // Saved confirmation animation, matching the Create Your Own flow.
            if showSaveConfirmation {
                SaveConfirmationView(contentType: .journal) {
                    dismiss()
                }
                .transition(.scale.combined(with: .opacity))
                .zIndex(1)
            }
        }
    }

    // MARK: - Voice dictation

    private var isTranscribing: Bool {
        voiceManager.voiceInputState == .processing || voiceManager.voiceInputState == .transcribing
    }

    @ViewBuilder
    private var voiceControls: some View {
        HStack(spacing: 12) {
            Button(action: toggleVoice) {
                Image(systemName: voiceManager.isListening ? "stop.fill" : "mic.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(isTranscribing ? .white.opacity(0.4) : .white.opacity(0.95))
                    .frame(width: 52, height: 52)
                    .background(
                        Circle().fill(voiceManager.isListening
                                      ? AnyShapeStyle(Color.red)
                                      : AnyShapeStyle(.ultraThinMaterial))
                    )
                    .overlay(
                        Circle().stroke(Color.white.opacity(voiceManager.isListening ? 0 : 0.18), lineWidth: 1)
                    )
            }
            .disabled(isTranscribing)

            if voiceManager.isListening {
                Text("Listening… tap to stop")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            } else if isTranscribing {
                Text("Transcribing…")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            } else if let error = voiceManager.errorMessage {
                Text(error)
                    .font(.system(size: 13))
                    .foregroundColor(.red.opacity(0.9))
                    .lineLimit(2)
            } else {
                Text("Tap to speak your entry")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.45))
            }

            Spacer()
        }
    }

    private func toggleVoice() {
        if voiceManager.isListening {
            voiceManager.stopListening()
            return
        }
        focused = false
        if voiceManager.hasPermissions {
            voiceManager.startListening()
        } else {
            voiceTask = Task {
                let granted = await voiceManager.requestPermissions()
                // Bail if the sheet was dismissed while the permission prompt
                // was up — otherwise we'd start recording on a gone view.
                if Task.isCancelled { return }
                if granted {
                    voiceManager.startListening()
                } else {
                    voiceManager.errorMessage = "Microphone access is off. Enable it in Settings to dictate."
                }
            }
        }
    }

    /// Append a finished transcription to the entry, then clear it so the same
    /// text isn't merged twice on the next state change.
    private func appendTranscription(_ transcription: String) {
        let trimmed = transcription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            text = trimmed
        } else {
            let separator = text.hasSuffix(" ") || text.hasSuffix("\n") ? "" : " "
            text += separator + trimmed
        }
        voiceManager.clearTranscription()
    }

    private func save() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { dismiss(); return }
        let context = PersistenceController.shared.container.viewContext
        let entry = JournalEntry(context: context)
        entry.text = trimmed
        // Persist as `myOwn` so the entry shows up in Profile > Create Your Own,
        // which filters journals on category == .myOwn. The onboarding `category`
        // is only used to seed the prompt and analytics, not to tag storage.
        entry.category = DeclarationCategory.myOwn.rawValue
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
                // save could flush; discard it. performAndWait is the synchronous
                // variant (the async perform overload would need `await` here).
                context.performAndWait { context.delete(entry) }
            }
        }
        PremiumHaptics.affirmationCompleted()
        focused = false
        // Show the saved animation; it dismisses the sheet when it completes.
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            showSaveConfirmation = true
        }
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
