//
//  EnhancedStreakViewModel.swift
//  SpeakLife
//
//  Enhanced streak view model with daily checklist functionality
//

import SwiftUI
import Combine
import Firebase

final class EnhancedStreakViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var todayChecklist: DailyChecklist
    @Published var streakStats: StreakStats
    @Published var showCompletionCelebration = false
    @Published var celebrationData: CompletionCelebration?
    @Published var showFireAnimation = false
    @Published var badgeManager: BadgeManager
    @Published var showBadgeUnlock = false
    @Published var showFirstTaskConfetti = false
    
    // MARK: - Private Properties
    private let userDefaults = UserDefaults.standard
    private let checklistKey = "dailyChecklist"
    private let streakStatsKey = "streakStats"
    private let hasAutoCompletedFirstTaskKey = "hasAutoCompletedFirstTask"
    
    // MARK: - Initialization
    init() {
        self.todayChecklist = Self.createTodayChecklist()
        self.streakStats = StreakStats()
        self.badgeManager = BadgeManager()
        
        loadData()  // This now handles checkStreakValidity internally when needed
        checkForNewBadges()
        
        // Schedule evening notification for today with current progress
        scheduleEveningCheckIn()
        
        // Listen for app becoming active to check for new day
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Public Methods
    func autoCompleteFirstTaskIfDemoCompleted(hasCompletedDemo: Bool) {
        // Check if we've already auto-completed once globally
        let hasAlreadyAutoCompleted = userDefaults.bool(forKey: hasAutoCompletedFirstTaskKey)
        guard !hasAlreadyAutoCompleted else { return }
        
        // Only auto-complete if demo was completed and no tasks have been completed yet
        guard hasCompletedDemo,
              !todayChecklist.tasks.isEmpty,
              todayChecklist.completedTasksCount == 0,
              let firstTask = todayChecklist.tasks.first,
              !firstTask.isCompleted else { return }
        
        // Mark that we've auto-completed so it won't happen again
        userDefaults.set(true, forKey: hasAutoCompletedFirstTaskKey)
        
        // Auto-complete the first task with animation delay for UX
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                self.completeTaskWithCelebration(taskId: firstTask.id)
            }
        }
    }
    
    private func completeTaskWithCelebration(taskId: String) {
        // Complete the task with special celebration for first completion
        completeTask(taskId: taskId)
        
        // Show confetti animation for first task completion
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.showFirstTaskConfetti = true
            
            // Hide confetti after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation(.easeOut(duration: 0.5)) {
                    self.showFirstTaskConfetti = false
                }
            }
        }
    }
    
    func completeTask(taskId: String) {
        guard let taskIndex = todayChecklist.tasks.firstIndex(where: { $0.id == taskId }),
              !todayChecklist.tasks[taskIndex].isCompleted else { return }
        
        let task = todayChecklist.tasks[taskIndex]
        
        // Enhanced analytics with progressive task data
        Analytics.logEvent("complete_task", parameters: [
            "task_id": taskId,
            "task_category": task.category.rawValue,
            "task_type": task.type.rawValue,
            "task_difficulty": task.difficulty.rawValue,
            "streak_day": streakStats.currentStreak,
            "current_phase": todayChecklist.currentPhase.rawValue,
            "estimated_minutes": task.estimatedMinutes,
            "is_newly_unlocked": task.isNewlyUnlocked
        ])
        
        todayChecklist.tasks[taskIndex].isCompleted = true
        todayChecklist.tasks[taskIndex].completedAt = Date()
        
        // Check if all tasks are now completed
        if todayChecklist.isCompleted && todayChecklist.completedAt == nil {
            completeDay()
        }
        
        saveData()
        checkForNewBadges()
        
        // Update evening notification based on current progress
        scheduleEveningCheckIn()
    }
    
    func uncompleteTask(taskId: String) {
        guard let taskIndex = todayChecklist.tasks.firstIndex(where: { $0.id == taskId }),
              todayChecklist.tasks[taskIndex].isCompleted else { return }
        
        todayChecklist.tasks[taskIndex].isCompleted = false
        todayChecklist.tasks[taskIndex].completedAt = nil
        
        // If day was completed but now a task is unchecked, mark day as incomplete
        if todayChecklist.completedAt != nil {
            todayChecklist.completedAt = nil
        }
        
        saveData()
    }
    
    func resetDay() {
        let currentStreak = max(1, streakStats.currentStreak)
        todayChecklist = createProgressiveChecklist(for: currentStreak)
        saveData()
    }
    
    // MARK: - Progressive Task System
    func updateTasksForNewStreak() {
        let currentStreak = streakStats.currentStreak
        let previousStreak = currentStreak - 1
        
        // Check if we've entered a new phase
        let currentPhase = ProgressionPhase.getPhase(for: currentStreak)
        let previousPhase = ProgressionPhase.getPhase(for: previousStreak)
        
        // Analytics for phase progression
        if currentPhase != previousPhase {
            Analytics.logEvent("phase_progression", parameters: [
                "previous_phase": previousPhase.rawValue,
                "new_phase": currentPhase.rawValue,
                "streak_day": currentStreak
            ])
        }
        
        // Get newly unlocked tasks
        let newTasks = TaskLibrary.getNewlyUnlockedTasks(currentStreak: currentStreak, previousStreak: previousStreak)
        
        if !newTasks.isEmpty {
            todayChecklist.newTasksUnlocked = newTasks.map { $0.id }
            
            // Analytics for new task unlocks
            for newTask in newTasks {
                Analytics.logEvent("task_unlocked", parameters: [
                    "task_id": newTask.id,
                    "task_category": newTask.category.rawValue,
                    "task_type": newTask.type.rawValue,
                    "task_difficulty": newTask.difficulty.rawValue,
                    "unlock_streak_day": currentStreak,
                    "current_phase": currentPhase.rawValue
                ])
            }
            
            // Mark new tasks as newly unlocked for UI celebration
            for newTask in newTasks {
                if let index = todayChecklist.tasks.firstIndex(where: { $0.id == newTask.id }) {
                    todayChecklist.tasks[index].isNewlyUnlocked = true
                }
            }
        }
        
        // Update current phase
        todayChecklist.currentPhase = currentPhase
        
        // Generate new task list for today based on current streak
        let updatedTasks = TaskLibrary.getCoreTasksForStreak(currentStreak)
        
        // Preserve completion status for existing tasks
        let existingCompletions = Dictionary(uniqueKeysWithValues: todayChecklist.tasks.map { ($0.id, $0.isCompleted) })
        
        todayChecklist.tasks = updatedTasks.map { task in
            var updatedTask = task
            if let wasCompleted = existingCompletions[task.id] {
                updatedTask.isCompleted = wasCompleted
                if wasCompleted {
                    updatedTask.completedAt = Date()
                }
            }
            return updatedTask
        }
        
        saveData()
    }
    
    private func createProgressiveChecklist(for streakDay: Int) -> DailyChecklist {
        let today = Calendar.current.startOfDay(for: Date())
        let phase = ProgressionPhase.getPhase(for: streakDay)
        let tasks = TaskLibrary.getCoreTasksForStreak(streakDay)
        
        return DailyChecklist(
            date: today,
            tasks: tasks,
            currentPhase: phase
        )
    }
    
    func getUpcomingUnlocks(for streakDay: Int) -> [DailyTask] {
        let nextFewDays = (streakDay + 1)...(streakDay + 10)
        var upcomingTasks: [DailyTask] = []
        
        for day in nextFewDays {
            let newTasks = TaskLibrary.getNewlyUnlockedTasks(currentStreak: day, previousStreak: day - 1)
            upcomingTasks.append(contentsOf: newTasks)
            if upcomingTasks.count >= 3 { break } // Limit to next 3 unlocks
        }
        
        return upcomingTasks
    }
    
    // MARK: - Private Methods
    private func completeDay() {
        let today = Date()
        todayChecklist.completedAt = today
        
        let previousStreak = streakStats.currentStreak
        let wasNewRecord = streakStats.currentStreak >= streakStats.longestStreak
        streakStats.updateStreak(for: today)
        
        // Update tasks for new streak milestone
        updateTasksForNewStreak()
        
        // Capture the current streak after update for celebration
        let currentStreakNumber = streakStats.currentStreak
        let isNewRecord = wasNewRecord && currentStreakNumber > streakStats.longestStreak
        
        print("🔥 CELEBRATION DEBUG: Creating celebration with streak number: \(currentStreakNumber)")
        print("🔥 CELEBRATION DEBUG: Is new record: \(isNewRecord)")
        print("🔥 CELEBRATION DEBUG: Previous streak was: \(previousStreak)")
        
        // Create celebration data
        celebrationData = CompletionCelebration(
            streakNumber: currentStreakNumber,
            isNewRecord: isNewRecord,
            motivationalMessage: CompletionCelebration.generateMessage(
                for: currentStreakNumber,
                isRecord: isNewRecord
            ),
            shareImage: generateShareImage()
        )
        
        // Show fire animation first, then celebration, then badges
        showFireAnimation = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.showFireAnimation = false
            self.showCompletionCelebration = true
        }
        
        saveData()
        
        // Check for badges AFTER completing the day to ensure proper timing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.checkForNewBadges()
        }
        
        // Schedule personalized notifications for tomorrow
        schedulePersonalizedNotifications()
    }
    
    private func checkStreakValidity() {
        streakStats.checkStreakValidity()
        saveData()
    }
    
    @objc private func appDidBecomeActive() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let checklistDate = calendar.startOfDay(for: todayChecklist.date)
        
        if today != checklistDate {
            // New day, create fresh checklist with progressive tasks
            checkStreakValidity()
            let currentStreak = max(1, streakStats.currentStreak)
            todayChecklist = createProgressiveChecklist(for: currentStreak)
            saveData()
            checkForNewBadges()
            
            // Schedule evening notification for the new day with current progress
            scheduleEveningCheckIn()
        }
    }
    
    private static func createTodayChecklist() -> DailyChecklist {
        let today = Calendar.current.startOfDay(for: Date())
        // Start with day 1 for new users
        let initialTasks = TaskLibrary.getCoreTasksForStreak(1)
        return DailyChecklist(
            date: today,
            tasks: initialTasks,
            currentPhase: .foundation
        )
    }
    
    // MARK: - Data Persistence
    private func saveData() {
        // Save checklist
        if let checklistData = try? JSONEncoder().encode(todayChecklist) {
            userDefaults.set(checklistData, forKey: checklistKey)
        }
        
        // Save streak stats
        if let statsData = try? JSONEncoder().encode(streakStats) {
            userDefaults.set(statsData, forKey: streakStatsKey)
        }
        
        // Also save current streak as simple integer for notifications to use
        userDefaults.set(streakStats.currentStreak, forKey: "currentStreak")
    }
    
    private func loadData() {
        // Load streak stats first (needed for creating new checklist)
        if let statsData = userDefaults.data(forKey: streakStatsKey),
           let stats = try? JSONDecoder().decode(StreakStats.self, from: statsData) {
            streakStats = stats
        }
        
        // Load checklist
        if let checklistData = userDefaults.data(forKey: checklistKey),
           let checklist = try? JSONDecoder().decode(DailyChecklist.self, from: checklistData) {
            
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let checklistDate = calendar.startOfDay(for: checklist.date)
            
            if today == checklistDate {
                // Same day - use saved checklist with completion status
                todayChecklist = checklist
            } else {
                // Different day - create fresh checklist for new day
                checkStreakValidity()
                let currentStreak = max(1, streakStats.currentStreak)
                todayChecklist = createProgressiveChecklist(for: currentStreak)
                saveData()
            }
        } else {
            // No saved checklist - create fresh one based on current streak
            let currentStreak = max(1, streakStats.currentStreak)
            todayChecklist = createProgressiveChecklist(for: currentStreak)
            saveData()
        }
    }
    
    // MARK: - Premium Share Image Generation
    func generateShareImage() -> UIImage? {
        // Instagram Stories optimal dimensions (exactly 9:16 ratio)
        let size = CGSize(width: 1080, height: 1920)
        
        print("🎨 Starting share image generation: \(size)")
        
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        defer { 
            UIGraphicsEndImageContext()
        }
        
        guard let context = UIGraphicsGetCurrentContext() else { 
            print("❌ Failed to get graphics context")
            return nil 
        }
        
        // Create breathtaking cinematic gradient background
        let colors = [
            UIColor(red: 0.02, green: 0.0, blue: 0.15, alpha: 1),   // Ultra deep midnight
            UIColor(red: 0.15, green: 0.02, blue: 0.35, alpha: 1),  // Rich royal purple
            UIColor(red: 0.35, green: 0.05, blue: 0.55, alpha: 1),  // Electric purple
            UIColor(red: 0.55, green: 0.15, blue: 0.75, alpha: 1),  // Brilliant violet
            UIColor(red: 0.45, green: 0.25, blue: 0.85, alpha: 1),  // Luminous purple
            UIColor(red: 0.25, green: 0.08, blue: 0.65, alpha: 1),  // Deep amethyst
            UIColor(red: 0.08, green: 0.02, blue: 0.35, alpha: 1),  // Rich darkness
            UIColor(red: 0.02, green: 0.0, blue: 0.15, alpha: 1)    // Return to midnight
        ]
        
        // Ultra-premium multi-stop gradient with perfect cinematic transitions
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                colors: colors.map { $0.cgColor } as CFArray,
                                locations: [0.0, 0.15, 0.3, 0.45, 0.6, 0.75, 0.9, 1.0])!
        
        // Draw main gradient
        context.drawLinearGradient(gradient,
                                 start: CGPoint(x: 0, y: 0),
                                 end: CGPoint(x: size.width, y: size.height),
                                 options: [])
        
        // Add radial overlay for depth and drama
        let radialGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                       colors: [
                                           UIColor.clear.cgColor,
                                           UIColor(red: 0.1, green: 0.02, blue: 0.3, alpha: 0.4).cgColor,
                                           UIColor(red: 0.0, green: 0.0, blue: 0.1, alpha: 0.7).cgColor
                                       ] as CFArray,
                                       locations: [0.0, 0.6, 1.0])!
        
        context.drawRadialGradient(radialGradient,
                                 startCenter: CGPoint(x: size.width * 0.5, y: size.height * 0.3),
                                 startRadius: 0,
                                 endCenter: CGPoint(x: size.width * 0.5, y: size.height * 0.3),
                                 endRadius: size.width * 0.8,
                                 options: [])
        
        // Add subtle texture overlay for premium feel
        addPremiumTextureOverlay(to: context, in: size)
        
        // Add floating orbs/particles in background
        addFloatingOrbs(to: context, in: size)
        
        // Add cinematic light rays
        addLightRays(to: context, in: size)
        
        // Add stellar particle field
        addStellarParticles(to: context, in: size)
        
        // Typography setup
        let textColor = UIColor.white
        
        // Create stunning visual hierarchy
        
        // 1. Top section - App branding
        drawTopBranding(in: context, size: size, textColor: textColor)
        
        // 2. Center hero - Fire animation style
        drawCenterHero(in: context, size: size, textColor: textColor)
        
        // 3. Achievement section
        drawAchievementSection(in: context, size: size, textColor: textColor)
        
        // 4. Bottom section - App logo and branding
        drawBottomBranding(in: context, size: size, textColor: textColor)
        
        let finalImage = UIGraphicsGetImageFromCurrentImageContext()
        
        if let image = finalImage {
            print("✅ Share image generated successfully: \(image.size)")
        } else {
            print("❌ Failed to generate share image")
        }
        
        return finalImage
    }
    
    // MARK: - Share Image Drawing Methods
    
    private func addFloatingOrbs(to context: CGContext, in size: CGSize) {
        // Add subtle floating orbs in background
        let orbPositions = [
            CGPoint(x: size.width * 0.15, y: size.height * 0.2),
            CGPoint(x: size.width * 0.85, y: size.height * 0.3),
            CGPoint(x: size.width * 0.25, y: size.height * 0.7),
            CGPoint(x: size.width * 0.75, y: size.height * 0.8),
            CGPoint(x: size.width * 0.1, y: size.height * 0.5),
            CGPoint(x: size.width * 0.9, y: size.height * 0.6)
        ]
        
        for (index, position) in orbPositions.enumerated() {
            let radius = CGFloat(20 + index * 5)
            let alpha = 0.1 - Double(index) * 0.015
            
            context.setFillColor(UIColor.white.withAlphaComponent(alpha).cgColor)
            context.fillEllipse(in: CGRect(
                x: position.x - radius,
                y: position.y - radius,
                width: radius * 2,
                height: radius * 2
            ))
        }
    }
    
    private func drawTopBranding(in context: CGContext, size: CGSize, textColor: UIColor) {
        // Premium app name with enhanced styling
        let appName = "SPEAKLIFE"
        let appNameAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 48, weight: .black),
            .foregroundColor: textColor,
            .kern: 3.0  // Enhanced letter spacing for luxury feel
        ]
        
        let appNameSize = appName.size(withAttributes: appNameAttributes)
        let appNameRect = CGRect(
            x: (size.width - appNameSize.width) / 2,
            y: size.height * 0.06,
            width: appNameSize.width,
            height: appNameSize.height
        )
        
        // Add golden glow for premium feel
        context.setShadow(offset: CGSize.zero, blur: 12, color: UIColor.systemYellow.withAlphaComponent(0.4).cgColor)
        appName.draw(in: appNameRect, withAttributes: appNameAttributes)
        context.setShadow(offset: CGSize.zero, blur: 0, color: nil)
        
        // Elegant tagline with premium styling
        let tagline = "SPEAK IT • BELIEVE IT • RECEIVE IT"
        let taglineAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 18, weight: .semibold),
            .foregroundColor: UIColor.systemYellow.withAlphaComponent(0.95),
            .kern: 1.5  // Letter spacing for elegance
        ]
        
        let taglineSize = tagline.size(withAttributes: taglineAttributes)
        let taglineRect = CGRect(
            x: (size.width - taglineSize.width) / 2,
            y: appNameRect.maxY + 20,  // More space from app name
            width: taglineSize.width,
            height: taglineSize.height
        )
        
        // Add subtle glow to tagline
        context.setShadow(offset: CGSize.zero, blur: 6, color: UIColor.systemYellow.withAlphaComponent(0.5).cgColor)
        tagline.draw(in: taglineRect, withAttributes: taglineAttributes)
        context.setShadow(offset: CGSize.zero, blur: 0, color: nil)
    }
    
    private func drawCenterHero(in context: CGContext, size: CGSize, textColor: UIColor) {
        let centerY = size.height * 0.42
        
        // Draw enhanced flame shapes as background
        drawPremiumFlameShapes(in: context, centerX: size.width / 2, centerY: centerY)
        
        // COLOSSAL streak number with cinematic glow effects
        let streakText = "\(streakStats.currentStreak)"
        let streakAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 200, weight: .black),  // MASSIVE!
            .foregroundColor: textColor,
            .kern: 5.0  // Dramatic letter spacing
        ]
        
        let streakSize = streakText.size(withAttributes: streakAttributes)
        let streakRect = CGRect(
            x: (size.width - streakSize.width) / 2,
            y: centerY - streakSize.height / 2,
            width: streakSize.width,
            height: streakSize.height
        )
        
        // EPIC six-layer glow effect for absolutely mind-blowing impact
        context.setShadow(offset: CGSize.zero, blur: 40, color: UIColor.systemYellow.withAlphaComponent(0.9).cgColor)
        streakText.draw(in: streakRect, withAttributes: streakAttributes)
        
        context.setShadow(offset: CGSize.zero, blur: 30, color: UIColor.systemOrange.withAlphaComponent(0.8).cgColor)
        streakText.draw(in: streakRect, withAttributes: streakAttributes)
        
        context.setShadow(offset: CGSize.zero, blur: 20, color: UIColor.systemRed.withAlphaComponent(0.7).cgColor)
        streakText.draw(in: streakRect, withAttributes: streakAttributes)
        
        context.setShadow(offset: CGSize.zero, blur: 12, color: UIColor.white.withAlphaComponent(0.9).cgColor)
        streakText.draw(in: streakRect, withAttributes: streakAttributes)
        
        context.setShadow(offset: CGSize.zero, blur: 6, color: UIColor.systemPink.withAlphaComponent(0.5).cgColor)
        streakText.draw(in: streakRect, withAttributes: streakAttributes)
        
        context.setShadow(offset: CGSize.zero, blur: 2, color: UIColor.systemPurple.withAlphaComponent(0.4).cgColor)
        streakText.draw(in: streakRect, withAttributes: streakAttributes)
        
        context.setShadow(offset: CGSize.zero, blur: 0, color: nil)
        
        // Dramatic "DAYS" text with premium styling
        let daysText = "DAYS OF SPEAKING LIFE!"
        let daysAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 40, weight: .black),  // Even bigger for impact
            .foregroundColor: UIColor.white,
            .kern: 2.5  // Enhanced letter spacing
        ]
        
        let daysSize = daysText.size(withAttributes: daysAttributes)
        let daysRect = CGRect(
            x: (size.width - daysSize.width) / 2,
            y: streakRect.maxY + 32,  // More spacing
            width: daysSize.width,
            height: daysSize.height
        )
        
        // Add premium multi-layer glow to days text
        context.setShadow(offset: CGSize.zero, blur: 15, color: UIColor.systemYellow.withAlphaComponent(0.8).cgColor)
        daysText.draw(in: daysRect, withAttributes: daysAttributes)
        
        context.setShadow(offset: CGSize.zero, blur: 8, color: UIColor.systemOrange.withAlphaComponent(0.6).cgColor)
        daysText.draw(in: daysRect, withAttributes: daysAttributes)
        
        context.setShadow(offset: CGSize.zero, blur: 0, color: nil)
    }
    
    private func drawFlameShapes(in context: CGContext, centerX: CGFloat, centerY: CGFloat) {
        // Draw multiple flame layers for depth
        let flameColors = [
            UIColor.red.withAlphaComponent(0.3),
            UIColor.orange.withAlphaComponent(0.25),
            UIColor.yellow.withAlphaComponent(0.2)
        ]
        
        for (index, color) in flameColors.enumerated() {
            let width = CGFloat(150 + index * 30)
            let height = CGFloat(200 + index * 40)
            
            context.setFillColor(color.cgColor)
            
            // Create flame path
            let flamePath = UIBezierPath()
            flamePath.move(to: CGPoint(x: centerX, y: centerY + height/2))
            
            // Left side
            flamePath.addCurve(
                to: CGPoint(x: centerX - width/2, y: centerY),
                controlPoint1: CGPoint(x: centerX - width/3, y: centerY + height/3),
                controlPoint2: CGPoint(x: centerX - width/2, y: centerY + height/6)
            )
            
            // Top
            flamePath.addCurve(
                to: CGPoint(x: centerX, y: centerY - height/2),
                controlPoint1: CGPoint(x: centerX - width/3, y: centerY - height/3),
                controlPoint2: CGPoint(x: centerX - width/6, y: centerY - height/2)
            )
            
            // Right side
            flamePath.addCurve(
                to: CGPoint(x: centerX + width/2, y: centerY),
                controlPoint1: CGPoint(x: centerX + width/6, y: centerY - height/2),
                controlPoint2: CGPoint(x: centerX + width/3, y: centerY - height/3)
            )
            
            // Close path
            flamePath.addCurve(
                to: CGPoint(x: centerX, y: centerY + height/2),
                controlPoint1: CGPoint(x: centerX + width/2, y: centerY + height/6),
                controlPoint2: CGPoint(x: centerX + width/3, y: centerY + height/3)
            )
            
            context.addPath(flamePath.cgPath)
            context.fillPath()
        }
    }
    
    private func drawAchievementSection(in context: CGContext, size: CGSize, textColor: UIColor) {
        let achievementY = size.height * 0.68
        
        // Premium achievement badge with enhanced styling
        let milestone = getMilestone(for: streakStats.currentStreak)
        if !milestone.isEmpty {
            let badgeText = "🏆 \(milestone.uppercased()) UNLOCKED!"
            let badgeAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 32, weight: .black),
                .foregroundColor: UIColor.white,
                .kern: 2.0  // Letter spacing for premium feel
            ]
            
            let badgeSize = badgeText.size(withAttributes: badgeAttributes)
            let badgeRect = CGRect(
                x: (size.width - badgeSize.width) / 2,
                y: achievementY,
                width: badgeSize.width,
                height: badgeSize.height
            )
            
            // Add dramatic multi-layer glow to badge
            context.setShadow(offset: CGSize.zero, blur: 18, color: UIColor.systemYellow.withAlphaComponent(0.9).cgColor)
            badgeText.draw(in: badgeRect, withAttributes: badgeAttributes)
            
            context.setShadow(offset: CGSize.zero, blur: 10, color: UIColor.systemOrange.withAlphaComponent(0.7).cgColor)
            badgeText.draw(in: badgeRect, withAttributes: badgeAttributes)
            
            context.setShadow(offset: CGSize.zero, blur: 4, color: UIColor.white.withAlphaComponent(0.8).cgColor)
            badgeText.draw(in: badgeRect, withAttributes: badgeAttributes)
            
            context.setShadow(offset: CGSize.zero, blur: 0, color: nil)
        }
        
        // Powerful motivational message with premium styling
        let message = getMotivationalMessage()
        let messageAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 26, weight: .semibold),
            .foregroundColor: textColor,
            .kern: 0.8  // Subtle letter spacing for readability
        ]
        
        // Enhanced multi-line text handling with premium spacing
        let maxWidth = size.width * 0.88  // Slightly wider for better use of space
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineSpacing = 12  // Enhanced line spacing for elegance
        
        let messageAttributesWithStyle: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 26, weight: .semibold),
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle,
            .kern: 0.8  // Consistent letter spacing
        ]
        
        let messageRect = CGRect(
            x: (size.width - maxWidth) / 2,
            y: achievementY + 60,  // Better spacing
            width: maxWidth,
            height: 120  // More height for text
        )
        
        // Add elegant glow to message
        context.setShadow(offset: CGSize.zero, blur: 8, color: UIColor.white.withAlphaComponent(0.4).cgColor)
        message.draw(in: messageRect, withAttributes: messageAttributesWithStyle)
        
        context.setShadow(offset: CGSize.zero, blur: 3, color: UIColor.systemYellow.withAlphaComponent(0.2).cgColor)
        message.draw(in: messageRect, withAttributes: messageAttributesWithStyle)
        
        context.setShadow(offset: CGSize.zero, blur: 0, color: nil)
    }
    
    private func drawBottomBranding(in context: CGContext, size: CGSize, textColor: UIColor) {
        // Try to load and draw app icon
        let logoImageNames = ["appIconDisplay", "speaklifeicon", "AppIcon"]
        var foundImage: UIImage?
        
        for imageName in logoImageNames {
            if let image = UIImage(named: imageName) {
                foundImage = image
                print("✅ Found logo image '\(imageName)' with size: \(image.size)")
                break
            } else {
                print("❌ Could not find logo image: \(imageName)")
            }
        }
        
        let logoY = size.height * 0.78  // Moved higher to prevent overlap with bottom text
        
        if let appIcon = foundImage {
            let logoSize: CGFloat = 250  // Made even bigger
            let logoRect = CGRect(
                x: (size.width - logoSize) / 2,
                y: logoY,
                width: logoSize,
                height: logoSize
            )
            
            // Draw premium circular background
            drawPremiumLogoBackground(in: context, rect: logoRect)
            
            // Create proper circular mask and draw icon correctly
            context.saveGState()
            
            // Create circular clipping path with smaller inset for better fit
            let iconRect = logoRect.insetBy(dx: 8, dy: 8)
            context.addEllipse(in: iconRect)
            context.clip()
            
            print("✅ Drawing app icon in circular mask at rect: \(iconRect)")
            
            // Use UIImage.draw() only - it handles orientation correctly
            // CGImage can cause upside-down issues, so avoid it
            appIcon.draw(in: iconRect)
            
            context.restoreGState()
            print("✅ Circular masked icon drawing completed")
            
        } else {
            // Enhanced fallback text logo with matching size
            let logoSize: CGFloat = 140  // Match the icon size
            let logoRect = CGRect(
                x: (size.width - logoSize) / 2,
                y: logoY,
                width: logoSize,
                height: logoSize
            )
            
            // Draw premium background
            drawPremiumLogoBackground(in: context, rect: logoRect)
            
            // Draw "SL" text centered in circle
            let logoText = "SL"
            let logoAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 56, weight: .black),  // Bigger font
                .foregroundColor: textColor
            ]
            
            let textSize = logoText.size(withAttributes: logoAttributes)
            let textRect = CGRect(
                x: logoRect.midX - textSize.width / 2,
                y: logoRect.midY - textSize.height / 2,
                width: textSize.width,
                height: textSize.height
            )
            logoText.draw(in: textRect, withAttributes: logoAttributes)
            print("✅ Fallback 'SL' text logo drawn")
        }
        
        // Premium call-to-action with dramatic styling
        let bottomText = "SHARE YOUR VICTORY!"
        let bottomAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 26, weight: .black),
            .foregroundColor: UIColor.white,
            .kern: 2.0  // Letter spacing for premium feel
        ]
        
        let bottomSize = bottomText.size(withAttributes: bottomAttributes)
        let bottomRect = CGRect(
            x: (size.width - bottomSize.width) / 2,
            y: logoY + 160,  // Better spacing from logo
            width: bottomSize.width,
            height: bottomSize.height
        )
        
        // Add dramatic multi-layer glow to call-to-action
        context.setShadow(offset: CGSize.zero, blur: 20, color: UIColor.systemYellow.withAlphaComponent(0.8).cgColor)
        bottomText.draw(in: bottomRect, withAttributes: bottomAttributes)
        
        context.setShadow(offset: CGSize.zero, blur: 12, color: UIColor.systemOrange.withAlphaComponent(0.6).cgColor)
        bottomText.draw(in: bottomRect, withAttributes: bottomAttributes)
        
        context.setShadow(offset: CGSize.zero, blur: 6, color: UIColor.white.withAlphaComponent(0.9).cgColor)
        bottomText.draw(in: bottomRect, withAttributes: bottomAttributes)
        
        context.setShadow(offset: CGSize.zero, blur: 0, color: nil)
    }
    
    private func drawPremiumLogoBackground(in context: CGContext, rect: CGRect) {
        print("✅ Drawing ultra-premium logo background at rect: \(rect)")
        
        // Draw MASSIVE outer glow for cinematic effect
        context.setShadow(offset: CGSize.zero, blur: 50, color: UIColor.white.withAlphaComponent(0.6).cgColor)
        
        // Draw radial gradient background for depth
        let logoGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                    colors: [
                                        UIColor.white.withAlphaComponent(0.98).cgColor,
                                        UIColor.white.withAlphaComponent(0.85).cgColor,
                                        UIColor.white.withAlphaComponent(0.95).cgColor
                                    ] as CFArray,
                                    locations: [0.0, 0.7, 1.0])!
        
        context.saveGState()
        context.addEllipse(in: rect)
        context.clip()
        context.drawRadialGradient(logoGradient,
                                 startCenter: CGPoint(x: rect.midX, y: rect.midY),
                                 startRadius: 0,
                                 endCenter: CGPoint(x: rect.midX, y: rect.midY),
                                 endRadius: rect.width / 2,
                                 options: [])
        context.restoreGState()
        
        // Clear shadow for next operations
        context.setShadow(offset: CGSize.zero, blur: 0, color: nil)
        
        // Draw multiple elegant borders with varying opacity
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.8).cgColor)
        context.setLineWidth(3)
        context.strokeEllipse(in: rect.insetBy(dx: 2, dy: 2))
        
        context.setStrokeColor(UIColor.systemYellow.withAlphaComponent(0.4).cgColor)
        context.setLineWidth(1)
        context.strokeEllipse(in: rect.insetBy(dx: 5, dy: 5))
        
        print("✅ Ultra-premium background drawn successfully")
    }
    
    // MARK: - Premium Helper Methods
    
    private func addPremiumTextureOverlay(to context: CGContext, in size: CGSize) {
        // Add cinematic noise texture and light particles
        for _ in 0..<200 {  // Double the particles
            let x = CGFloat.random(in: 0...size.width)
            let y = CGFloat.random(in: 0...size.height)
            let alpha = Double.random(in: 0.02...0.08)
            let particleSize = CGFloat.random(in: 1...4)
            
            context.setFillColor(UIColor.white.withAlphaComponent(alpha).cgColor)
            context.fillEllipse(in: CGRect(x: x, y: y, width: particleSize, height: particleSize))
        }
        
        // Add brilliant light streaks
        for _ in 0..<15 {
            let startX = CGFloat.random(in: 0...size.width)
            let startY = CGFloat.random(in: 0...size.height)
            let endX = startX + CGFloat.random(in: -100...100)
            let endY = startY + CGFloat.random(in: -100...100)
            
            context.setStrokeColor(UIColor.white.withAlphaComponent(0.03).cgColor)
            context.setLineWidth(1)
            context.move(to: CGPoint(x: startX, y: startY))
            context.addLine(to: CGPoint(x: endX, y: endY))
            context.strokePath()
        }
    }
    
    private func addStellarParticles(to context: CGContext, in size: CGSize) {
        // Add brilliant star-like particles throughout the image
        for _ in 0..<50 {
            let x = CGFloat.random(in: 0...size.width)
            let y = CGFloat.random(in: 0...size.height)
            let starSize = CGFloat.random(in: 2...6)
            let alpha = Double.random(in: 0.3...0.9)
            
            // Draw cross-shaped star
            context.setStrokeColor(UIColor.white.withAlphaComponent(alpha).cgColor)
            context.setLineWidth(1)
            
            // Horizontal line
            context.move(to: CGPoint(x: x - starSize, y: y))
            context.addLine(to: CGPoint(x: x + starSize, y: y))
            context.strokePath()
            
            // Vertical line
            context.move(to: CGPoint(x: x, y: y - starSize))
            context.addLine(to: CGPoint(x: x, y: y + starSize))
            context.strokePath()
            
            // Center dot
            context.setFillColor(UIColor.white.withAlphaComponent(alpha).cgColor)
            context.fillEllipse(in: CGRect(x: x - 1, y: y - 1, width: 2, height: 2))
        }
        
        // Add brilliant golden stars
        for _ in 0..<25 {
            let x = CGFloat.random(in: 0...size.width)
            let y = CGFloat.random(in: 0...size.height)
            let starSize = CGFloat.random(in: 3...8)
            let alpha = Double.random(in: 0.4...0.8)
            
            context.setStrokeColor(UIColor.systemYellow.withAlphaComponent(alpha).cgColor)
            context.setLineWidth(1.5)
            
            // Four-pointed star
            context.move(to: CGPoint(x: x - starSize, y: y))
            context.addLine(to: CGPoint(x: x + starSize, y: y))
            context.strokePath()
            
            context.move(to: CGPoint(x: x, y: y - starSize))
            context.addLine(to: CGPoint(x: x, y: y + starSize))
            context.strokePath()
            
            // Diagonal lines for 8-pointed star
            context.move(to: CGPoint(x: x - starSize * 0.7, y: y - starSize * 0.7))
            context.addLine(to: CGPoint(x: x + starSize * 0.7, y: y + starSize * 0.7))
            context.strokePath()
            
            context.move(to: CGPoint(x: x - starSize * 0.7, y: y + starSize * 0.7))
            context.addLine(to: CGPoint(x: x + starSize * 0.7, y: y - starSize * 0.7))
            context.strokePath()
        }
    }
    
    private func addLightRays(to context: CGContext, in size: CGSize) {
        // Add dramatic cinematic light rays emanating from center
        let centerX = size.width / 2
        let centerY = size.height * 0.42  // Same as streak number position
        
        for i in 0..<12 {
            let angle = Double(i) * .pi / 6  // 12 rays, 30 degrees apart
            let rayLength = size.width * 0.8
            
            let endX = centerX + cos(angle) * rayLength
            let endY = centerY + sin(angle) * rayLength
            
            // Create gradient for each ray
            let rayGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                       colors: [
                                           UIColor.white.withAlphaComponent(0.15).cgColor,
                                           UIColor.systemYellow.withAlphaComponent(0.08).cgColor,
                                           UIColor.clear.cgColor
                                       ] as CFArray,
                                       locations: [0.0, 0.3, 1.0])!
            
            context.saveGState()
            
            // Create ray path
            let rayPath = UIBezierPath()
            rayPath.move(to: CGPoint(x: centerX, y: centerY))
            rayPath.addLine(to: CGPoint(x: centerX + cos(angle + 0.05) * rayLength, y: centerY + sin(angle + 0.05) * rayLength))
            rayPath.addLine(to: CGPoint(x: endX, y: endY))
            rayPath.addLine(to: CGPoint(x: centerX + cos(angle - 0.05) * rayLength, y: centerY + sin(angle - 0.05) * rayLength))
            rayPath.close()
            
            context.addPath(rayPath.cgPath)
            context.clip()
            
            context.drawLinearGradient(rayGradient,
                                     start: CGPoint(x: centerX, y: centerY),
                                     end: CGPoint(x: endX, y: endY),
                                     options: [])
            
            context.restoreGState()
        }
    }
    
    private func drawPremiumFlameShapes(in context: CGContext, centerX: CGFloat, centerY: CGFloat) {
        // EPIC flame shapes with cinematic gradients
        let flameConfigs = [
            (width: 180, height: 240, colors: [UIColor.systemRed, UIColor.systemOrange, UIColor.systemYellow], alpha: 0.5),
            (width: 220, height: 280, colors: [UIColor.systemOrange, UIColor.systemYellow, UIColor.white], alpha: 0.4),
            (width: 260, height: 320, colors: [UIColor.systemYellow, UIColor.white, UIColor.systemYellow], alpha: 0.35),
            (width: 300, height: 360, colors: [UIColor.white, UIColor.systemYellow, UIColor.systemOrange], alpha: 0.3),
            (width: 340, height: 400, colors: [UIColor.systemYellow, UIColor.white, UIColor.systemPink], alpha: 0.25),
            (width: 380, height: 440, colors: [UIColor.white, UIColor.systemPink, UIColor.systemPurple], alpha: 0.2)
        ]
        
        for (index, config) in flameConfigs.enumerated() {
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                    colors: config.colors.map { $0.withAlphaComponent(config.alpha).cgColor } as CFArray,
                                    locations: [0.0, 0.5, 1.0])!
            
            let flamePath = createFlameShape(centerX: centerX, centerY: centerY, width: config.width, height: config.height)
            
            context.saveGState()
            context.addPath(flamePath)
            context.clip()
            context.drawLinearGradient(gradient,
                                     start: CGPoint(x: centerX, y: centerY + CGFloat(config.height)/2),
                                     end: CGPoint(x: centerX, y: centerY - CGFloat(config.height)/2),
                                     options: [])
            context.restoreGState()
        }
    }
    
    private func createFlameShape(centerX: CGFloat, centerY: CGFloat, width: Int, height: Int) -> CGPath {
        let path = UIBezierPath()
        let w = CGFloat(width)
        let h = CGFloat(height)
        
        // Start at bottom center
        path.move(to: CGPoint(x: centerX, y: centerY + h/2))
        
        // Left side curves
        path.addCurve(
            to: CGPoint(x: centerX - w/2, y: centerY),
            controlPoint1: CGPoint(x: centerX - w/3, y: centerY + h/3),
            controlPoint2: CGPoint(x: centerX - w/2, y: centerY + h/6)
        )
        
        // Top curve
        path.addCurve(
            to: CGPoint(x: centerX, y: centerY - h/2),
            controlPoint1: CGPoint(x: centerX - w/3, y: centerY - h/3),
            controlPoint2: CGPoint(x: centerX - w/6, y: centerY - h/2)
        )
        
        // Right side curves
        path.addCurve(
            to: CGPoint(x: centerX + w/2, y: centerY),
            controlPoint1: CGPoint(x: centerX + w/6, y: centerY - h/2),
            controlPoint2: CGPoint(x: centerX + w/3, y: centerY - h/3)
        )
        
        // Bottom right curve
        path.addCurve(
            to: CGPoint(x: centerX, y: centerY + h/2),
            controlPoint1: CGPoint(x: centerX + w/2, y: centerY + h/6),
            controlPoint2: CGPoint(x: centerX + w/3, y: centerY + h/3)
        )
        
        path.close()
        return path.cgPath
    }
    
    private func getMilestone(for streak: Int) -> String {
        switch streak {
        case 7...13: return "Faith Builder"
        case 14...29: return "Word Warrior"
        case 30...49: return "Faith Overcomer"
        case 50...99: return "Kingdom Heir"
        case 100...199: return "Covenant Keeper"
        case 200...364: return "Spiritual Giant"
        case 365...: return "Destiny Carrier"
        default: return ""
        }
    }
    
    private func getMotivationalMessage() -> String {
        let messages = [
            "Every word you speak has the power to transform your reality!",
            "You are rewriting your story with words of LIFE!",
            "Your consistency is building an unstoppable future!",
            "Speaking life daily - this is how legends are made!",
            "Your words are creating the life you were meant to live!"
        ]
        
        // Use streak number to pick consistent message
        let index = streakStats.currentStreak % messages.count
        return messages[index]
    }
    
    // MARK: - Badge System Integration
    
    private func checkForNewBadges() {
        // Only use metrics we can actually track accurately
        let userStats = UserStats(
            affirmationsSpoken: 0, // Not tracking yet
            versesRead: 0, // Not tracking yet
            socialShares: 0, // Not tracking yet
            favoritesAdded: 0, // Not tracking yet
            categoriesCompleted: Set<String>() // Not tracking yet
        )
        
        let previousBadgeCount = badgeManager.unlockedBadgeCount
        badgeManager.checkForNewBadges(streakStats: streakStats, userStats: userStats)
        
        // Only show badge unlock if a NEW badge was unlocked this check
        if let newBadge = badgeManager.recentlyUnlocked,
           badgeManager.unlockedBadgeCount > previousBadgeCount {
            
            print("🏆 NEW BADGE UNLOCKED: \(newBadge.title) for \(newBadge.requirement.description)")
            
            // Show badge unlock after main celebrations if they're showing, otherwise immediately
            let delay: Double = (showFireAnimation || showCompletionCelebration) ? 6.0 : 1.0
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                if !self.showFireAnimation && !self.showCompletionCelebration {
                    self.showBadgeUnlock = true
                } else {
                    // Wait a bit more if celebrations are still showing
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        self.showBadgeUnlock = true
                    }
                }
            }
        }
    }
    
    func dismissBadgeUnlock() {
        showBadgeUnlock = false
        badgeManager.clearRecentlyUnlocked()
    }
    
    // MARK: - Notification Scheduling
    
    private func schedulePersonalizedNotifications() {
        let completedActivities = todayChecklist.tasks.filter { $0.isCompleted }.map { $0.title }
        let remainingActivities = todayChecklist.tasks.filter { !$0.isCompleted }.map { $0.title }
        let userName = getUserName()
        
        // Schedule evening celebration notification for today
        NotificationManager.shared.schedulePersonalizedChecklistNotification(
            isEvening: true,
            userName: userName,
            currentStreak: streakStats.currentStreak,
            completedActivities: completedActivities,
            remainingActivities: remainingActivities,
            totalActivities: todayChecklist.tasks.count
        )
        
        // Schedule morning motivation notification for tomorrow
        NotificationManager.shared.schedulePersonalizedChecklistNotification(
            isEvening: false,
            userName: userName,
            currentStreak: streakStats.currentStreak,
            completedActivities: [],
            remainingActivities: [],
            totalActivities: 0 // Not used for morning notifications
        )
    }
    
    func scheduleEveningCheckIn() {
        // Called during the day to schedule evening reminder based on current progress
        let completedActivities = todayChecklist.tasks.filter { $0.isCompleted }.map { $0.title }
        let remainingActivities = todayChecklist.tasks.filter { !$0.isCompleted }.map { $0.title }
        let userName = getUserName()
        
        // Cancel the fallback evening notification since we're providing a personalized one
        NotificationManager.shared.notificationCenter.removePendingNotificationRequests(withIdentifiers: ["FallbackEveningNotification"])
        
        NotificationManager.shared.schedulePersonalizedChecklistNotification(
            isEvening: true,
            userName: userName,
            currentStreak: streakStats.currentStreak,
            completedActivities: completedActivities,
            remainingActivities: remainingActivities,
            totalActivities: todayChecklist.tasks.count
        )
    }
    
    private func getUserName() -> String {
        // Try to get user name from user defaults first
        // Fallback to "Friend" if no name is available
        if let name = userDefaults.string(forKey: "userName"), !name.isEmpty {
            return name
        } else {
            return "Friend"
        }
    }
}

// MARK: - Legacy Compatibility
extension EnhancedStreakViewModel {
    // Bridge to existing StreakViewModel interface
    var currentStreak: Int { streakStats.currentStreak }
    var longestStreak: Int { streakStats.longestStreak }
    var totalDaysCompleted: Int { streakStats.totalDaysCompleted }
    var hasCurrentStreak: Bool { streakStats.currentStreak > 0 }
    
    var titleText: String {
        let streak = streakStats.currentStreak
        return streak == 1 ? "\(streak) day" : "\(streak) days"
    }
    
    var subTitleText: String {
        let longest = streakStats.longestStreak
        return longest == 1 ? "\(longest) day" : "\(longest) days"
    }
    
    var subTitleDetailText: String {
        let total = streakStats.totalDaysCompleted
        return total == 1 ? "\(total) day" : "\(total) days"
    }
}
