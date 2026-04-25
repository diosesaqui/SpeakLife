//
//  NotificationManager.swift
//  Dios Es Aqui
//
//  Created by Riccardo Washington on 2/20/22.
//

import UserNotifications
import Foundation
import BackgroundTasks

let resyncNotification = NSNotification.Name("NotificationsDone")
let notificationNavigate = NSNotification.Name("NavigateToContent")
let declarationsContentUpdated = NSNotification.Name("DeclarationsContentUpdated")

final class NotificationManager: NSObject {
    
    static let shared = NotificationManager()
    
    var lastScheduledNotificationDate: Date? {
        get {
            UserDefaults.standard.object(forKey: "lastScheduledNotificationDate") as? Date
        } set {
            guard let newValue = newValue else {
                UserDefaults.standard.removeObject(forKey: "lastScheduledNotificationDate")
                return
            }
            UserDefaults.standard.set(newValue, forKey: "lastScheduledNotificationDate")
            scheduleBatchRefresh(batchEndsAt: newValue)
        }
    }
    
    func notificationCategories() -> Set<DeclarationCategory> {
        [DeclarationCategory.destiny, .gratitude, .faith, .identity, .grace, .joy, .rest]
    }
    
    
    private override init() {}
    
    private let notificationProcessor = NotificationProcessor(service: LocalAPIClient())
    
    let notificationCenter = UNUserNotificationCenter.current()
    
    
    func registerNotifications(count: Int,
                               startTime: Int,
                               endTime: Int,
                               categories: Set<DeclarationCategory>? = nil,
                               callback: (() -> Void)? = nil) {
        let actualCount = max(5, count) // Ensure minimum of 1 notification
        
        // Log notification scheduling for verification
        
        removeNotifications()
        
        // Check if AI features are enabled for enhanced notifications
        // Note: This would need access to SubscriptionStore instance in a real implementation
        // For now, we'll add a simple check here that can be expanded later
//        if shouldUseAINotifications() {
//            registerAIEnhancedNotifications(count: count, startTime: startTime, endTime: endTime, categories: categories, callback: callback)
//            return
//        }
        
        // Use original notification system
        if let categories = categories {
            let notifications = getNotificationData(for: actualCount, categories: categories)
            // callback if data is less than count RWRW
            prepareNotifications(declarations: notifications,  startTime: startTime, endTime: endTime, count: actualCount) {
                callback?()
            }
        } else {
            let notifications = getNotificationData(for: actualCount, categories: notificationCategories())
            prepareNotifications(declarations: notifications,  startTime: startTime, endTime: endTime, count: actualCount) {
                callback?()
            }
        }
        // Removed: morningAffirmationReminder() — used UUID identifiers so it stacked
        //          infinitely and fired multiple 8am notifications on the same user.
        //          Content is now covered by PersonalizedMorningNotification below.
        // Removed: nightlyAffirmationReminder() — same UUID stacking issue.
        //          Replaced by PersonalizedEveningNotification + streak_at_risk.

        // Schedule checklist notifications (PersonalizedMorningNotification at 8am
        // + FallbackEveningNotification removed — see scheduleFallbackEveningNotification)
        scheduleChecklistNotifications()
    }
    

    /// Called when remote declaration content updates (version bump). Reschedules
    /// notifications immediately using the user's current saved preferences so
    /// pending notifications reflect the new content without waiting for the
    /// next natural resync cycle (~24 h).
    func rescheduleFromUserDefaults() {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: "notificationEnabled") else { return }

        let count     = defaults.integer(forKey: "notificationCount")
        let startTime = defaults.integer(forKey: "startTimeIndex")
        let endTime   = defaults.integer(forKey: "endTimeIndex")
        let catString = defaults.string(forKey: "selectedNotificationCategories") ?? ""
        let parsed    = Set(catString.components(separatedBy: ",").compactMap { DeclarationCategory($0) })
        var categories: Set<DeclarationCategory> = parsed.isEmpty
            ? [.destiny, .gratitude, .faith, .identity, .grace, .joy, .rest]
            : parsed
        if categories.count <= 1 {
            categories.insert(.destiny)
            categories.insert(.love)
        }

        registerNotifications(
            count: max(count, 5),
            startTime: startTime,
            endTime: endTime,
            categories: categories
        )
    }

    func checkForLowReminders() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            if requests.isEmpty {
                // Likely wiped on reboot or uninstall
                DispatchQueue.main.async {
                    self.scheduleReminder(
                        title: "⚠️ Reminders ending!",
                        body: "Tap to schedule more reminders.",
                        date: Date().addingTimeInterval(10),
                        id: "reschedule_prompt"
                    )
                }
            }
        }
    }
    
    func scheduleReminder(title: String, body: String, date: Date, id: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date), repeats: false)

        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
    
    func scheduleTrialEndingReminder(subscriptionDate: Date) {
        setupNotificationCategory()
            let notificationCenter = UNUserNotificationCenter.current()
            
            // Calculate the fire date (5 days after subscription)
            let fireDate = Calendar.current.date(byAdding: .day, value: 5, to: subscriptionDate) ?? Date()
            let content = UNMutableNotificationContent()
            content.title = "Your Trial is Ending Soon"
            content.body = "Your 7-day trial ends in 2 days. If you don’t cancel, your subscription will renew automatically."
            content.sound = .default
            
            // Create a trigger based on the calculated fire date
            let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
            
            // Create and add the request
            let request = UNNotificationRequest(identifier: "TrialEndingReminder", content: content, trigger: trigger)
            notificationCenter.add(request) { error in
                if let error = error {
                    print("Error scheduling notification: \(error.localizedDescription)")
                }
            }
        }
    
    func setupNotificationCategory() {
        let manageAction = UNNotificationAction(
            identifier: "MANAGE_SUBSCRIPTION",
            title: "Manage Subscription",
            options: [.foreground] // Opens the app when tapped
        )
        
        let category = UNNotificationCategory(
            identifier: "TRIAL_ENDING_CATEGORY",
            actions: [manageAction],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }
    
    func prepareDailyStreakNotification(with name: String = "Friend", streak: Int, hasCurrentStreak: Bool) {
        let noStreakBody: [String] = ["Don’t forget to speak life today! God’s promises are waiting for you. ✨",
                                   "Have you spoken God’s promises yet? Take a moment to activate them now. 🙏",
                                   "A quick reminder: Speak life today and unlock God’s blessings over your day. 🌟",
                                   "Your day isn’t complete without declaring God’s promises. Speak life now! 🗣️",
                                   "Missed speaking life today? It’s not too late to declare God’s truth over your life. ⏳",
                                   "Take a moment to speak God’s promises—there’s still time to activate His power today. ⏰",
                                   "Don’t let today pass without speaking life. God’s promises are ready to be activated! 💬",
                                   "A gentle nudge—have you declared God’s promises today? Speak life now! 🌱",
                                   "Haven’t spoken life today? Your words can still activate God’s promises. 🕊️",
                                   "Reminder: Speak life and let God’s promises guide the rest of your day. ✨",
                                   ]
        
        let hasStreakBody: [String] = [
            "Well done! You spoke life today and activated God’s promises. Keep it going! 🎉",
            "Great job! Your words are bringing God’s promises to life. Keep the streak alive! 🔥",
            "You did it! God’s promises are at work because you spoke life today. 🙌",
            "Streak on fire! 🔥 Keep declaring God’s truth and watch the blessings flow.",
            "Consistency is key! You’re unlocking God’s promises one day at a time. ✨",
            "Another day, another victory! Keep speaking life and activating God’s power. 🎯",
            "Congratulations! You’ve made today count by declaring God’s promises. Keep shining! 🌟",
            "Your streak is going strong! Keep speaking life and watch God’s promises unfold. 💫",
            "Amazing! You’re on a roll—keep declaring God’s truth and blessings. 🗣️",
            "Way to go! Your commitment to speaking life is making a difference. 🙏",
            "You’re unstoppable! Keep activating God’s promises daily. 🚀",
            "Another day of speaking life—your streak is growing, and so are the blessings! 🌱",
            "Great consistency! Keep declaring God’s promises and see the rewards. 🌈",
            "You’re on the right path! Keep up the great work and watch God’s promises be fulfilled. 🌟",
            "Streak maintained! 🎉 Your faithfulness in speaking life is powerful. Keep it up!",
        ]
        
        let body: String
        
        if hasCurrentStreak {
            body = "Hey \(name),\(hasStreakBody.randomElement()!)"
        } else {
            body = "Hey \(name),\(noStreakBody.randomElement()!)"
        }
        
        let content = UNMutableNotificationContent()
        content.title = "SpeakLife"
        content.body = body
        content.sound = UNNotificationSound.default
        
        var dateComponents = DateComponents()
        dateComponents.calendar = Calendar.autoupdatingCurrent
        dateComponents.timeZone = TimeZone.autoupdatingCurrent
        dateComponents.hour = 20
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents, repeats: true)
        let id = "StreakReminder"
        
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
       
        notificationCenter.add(request) { (error) in
            if error != nil {
                //  TODO: - handle error
            }
        }
    }
    
    func getNotificationData(for count: Int,
                                     categories: Set<DeclarationCategory>?)  ->  [NotificationProcessor.NotificationData] {
        var notificationData: [NotificationProcessor.NotificationData] = []
        
        if let categories = categories {
            notificationProcessor.getNotificationData(count: count, categories: Array(categories)) { data in
                notificationData = data
            }
        } else {
            notificationProcessor.getNotificationData(count: count, categories: nil) { data in
                notificationData = data
            }
        }
        
        return notificationData
    }
    
    
    
    private func prepareNotifications(declarations: [NotificationProcessor.NotificationData],
                                      startTime: Int,
                                      endTime: Int,
                                      count: Int,
                                      callback: (() -> Void)? = nil) {

        let hourMinute = distributeTimes(startTime: startTime, endTime: endTime, count: count)

        guard hourMinute.count > 1 else { callback?(); return }
        guard declarations.count >= count else { callback?(); return }

        // Schedule notifications across the next N days so they survive without
        // the app being opened daily. iOS allows up to 64 pending notifications;
        // daysAhead * count must stay well under that limit.
        let daysAhead = 10 // 10 days × 5 notifications = 50 (safely under the 64-notification OS limit)
        let now = Date()
        let calendar = Calendar.autoupdatingCurrent

        for day in 0..<daysAhead {
            for (idx, declaration) in declarations.enumerated() {
                // For variety, cycle through all available declarations across days
                let declarationIndex = (idx + day * count) % declarations.count
                let decl = declarations[declarationIndex]

                var body = decl.body
                if decl.book.count > 1 {
                    body += " ~ " + decl.book
                }

                // Calculate the exact fire date for this day + time slot
                let baseDate = calendar.date(byAdding: .day, value: day, to: now)!
                let targetDate = calendar.date(bySettingHour: hourMinute[idx].hour,
                                               minute: hourMinute[idx].minute,
                                               second: 0,
                                               of: baseDate)!

                // Skip slots that have already passed (only relevant for day 0)
                guard targetDate > now else { continue }

                let content = UNMutableNotificationContent()
                content.title = "SpeakLife"
                content.body = body
                content.sound = UNNotificationSound.default
                content.userInfo = ["category": decl.category]

                let finalComponents = calendar.dateComponents(
                    [.year, .month, .day, .hour, .minute], from: targetDate)
                let trigger = UNCalendarNotificationTrigger(
                    dateMatching: finalComponents, repeats: false)

                let request = UNNotificationRequest(
                    identifier: UUID().uuidString, content: content, trigger: trigger)
                notificationCenter.add(request) { error in
                    if let error = error {
                        print("❌ Failed to schedule notification (day \(day), slot \(idx)): \(error.localizedDescription)")
                    }
                }
            }
        }

        // Record the schedule date so the app knows when to refresh (in ~10 days)
        let refreshDate = calendar.date(byAdding: .day, value: daysAhead - 1, to: now)
        lastScheduledNotificationDate = refreshDate
        callback?()
    }
    
    /// Submits a BGAppRefreshTask to fire when the notification batch is 4 days
    /// from running out. iOS will wake the app in the background, call
    /// `updateNotificationContent`, which runs `UpdateNotificationsOperation`
    /// → `registerNotifications` → schedules a fresh 10-day batch.
    /// This means users get continuous notifications even without opening the app.
    private func scheduleBatchRefresh(batchEndsAt endDate: Date) {
        // Aim to refresh when 4 days of notifications remain (buffer for iOS delays)
        let refreshBuffer: TimeInterval = 4 * 24 * 60 * 60
        let refreshDate = endDate.addingTimeInterval(-refreshBuffer)

        // If refresh date is already past (e.g. small batch), fire as soon as possible
        let fireDate = max(refreshDate, Date(timeIntervalSinceNow: 60))

        let request = BGAppRefreshTaskRequest(identifier: "com.speaklife.updateNotificationContent")
        request.earliestBeginDate = fireDate

        do {
            try BGTaskScheduler.shared.submit(request)
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            print("✅ BGAppRefreshTask scheduled for \(formatter.string(from: fireDate))")
        } catch {
            print("⚠️ Could not schedule notification batch refresh: \(error.localizedDescription)")
        }
    }
    
    private func morningAffirmationReminder() {
        let id = UUID().uuidString
        let bodyArray: [String] = [
            "💕 Good morning, beloved! You are God's cherished child. Today, speak from the intimacy of knowing you are deeply loved and completely accepted.",
            "🌅 Rise and shine, beautiful one! Your Father delights in you. Today, declare His love over your life because this is who you are—His treasured daughter/son.",
            "👑 You are ROYALTY by birth, not by behavior! Today, speak life because you carry the DNA of heaven. You belong to the King of Kings!",
            "💎 Precious child of the Most High! Your identity is secure in His love. Today's declarations flow from intimacy, not striving. You are His beloved.",
            "🌟 You are the apple of His eye! Today, speak truth because you know who you are in Him. Your words matter because YOU matter to God.",
            "💕 Good morning, chosen one! You don't earn His love—you receive it. Today, declare His goodness because you're secure in His affection.",
            "🦋 You are beautifully and wonderfully made! Today, speak life because you understand your worth comes from being His child, not your circumstances.",
            "🌺 Sweet child of promise! Your Father sings over you with joy. Today's words come from a place of rest in His perfect love for you.",
            "✨ You are His masterpiece! Today, declare His promises because you know you're not an accident—you're His intentional creation, deeply loved.",
            "💖 Beloved, you are chosen before the foundation of the world! Today, speak from the security of knowing you belong to Him completely.",
            "🕊️ You are His peace-filled child! Today's declarations come from the quiet confidence of knowing Daddy's got you covered in every situation.",
            "🌸 Beautiful one, you are engraved on His palms! Today, speak life because you're convinced of His unwavering love and commitment to you.",
            "💝 You are the joy of His heart! Today, declare His truth because you rest in the reality that nothing can separate you from His love.",
            "👶 Sweet child, you are safe in His arms! Today's words flow from the intimacy of knowing you can trust your heavenly Father completely.",
            "🌈 You are His covenant child! Today, speak His promises because you understand you're not working FOR His love—you're working FROM it.",
            "💕 Precious one, you are His dwelling place! Today, declare life because His Spirit in you confirms you belong to the family of God.",
            "🌟 You are His bright morning star! Today's declarations come from knowing your identity is settled—you are His beloved, forever and always.",
            "🦋 You are being transformed by His love! Today, speak truth because you're not trying to become worthy—you already are in His eyes.",
            "💎 You are His precious treasure! Today's words matter because they flow from the heart of one who knows she/he is deeply cherished by God.",
            "🌺 You are blooming in His garden! Today, declare His goodness because you're rooted in the soil of His unconditional, never-ending love.",
            "✨ You shine with His glory! Today, speak life because you understand you're not just forgiven—you're beloved, accepted, and celebrated by Him.",
            "💖 You are His heart's desire! Today's declarations come from the confidence of knowing your Father's heart beats with love for you.",
            "🕊️ You rest in His perfect peace! Today, speak His truth because you know you're not alone—you're held in the everlasting arms of Love.",
            "🌸 You are His fragrant offering! Today, declare His promises because your life is a sweet aroma to the One who calls you His own.",
            "💝 You are wrapped in His love! Today's words flow from the intimacy of knowing you can approach His throne with confidence—you belong there.",
            "👶 You are His delight! Today, speak life because you understand your worth isn't in what you do—it's in whose you are.",
            "🌈 You are His living promise! Today, declare His faithfulness because you know His covenant with you is unshakeable and everlasting.",
            "💕 You are held in His heart! Today's declarations matter because they come from one who knows they are completely loved and fully known.",
            "🌟 You reflect His beauty! Today, speak truth because you're secure in knowing you don't have to perform—you get to partner with Him in love.",
            "🦋 You are His new creation! Today, declare His goodness because you know your past doesn't define you—His love for you does.",
            "💎 You are priceless to Him! Today's words carry weight because they flow from a heart that knows it belongs to the God of all comfort.",
            "🌺 You blossom in His presence! Today, speak life because you understand intimacy with God is your source, not your circumstances.",
            "✨ You carry His light! Today, declare His truth because you know you're not trying to get His attention—you already have it completely.",
            "💖 You are His beloved! Today's declarations flow from the deep knowing that you are pursued, chosen, and treasured by the King of Heaven.",
            "🕊️ You rest in His faithfulness! Today, speak His promises because you know His love for you is not based on your performance but His character.",
            "🌸 You are His beautiful bride! Today, declare life because you understand you're in a love relationship with the Creator of the universe.",
            "💝 You are His inheritance! Today's words matter because they come from one who knows they are co-heirs with Christ, fully accepted and loved.",
            "👶 You are safe in His love! Today, speak truth because you know your Father's heart is always turned toward you with tender affection.",
            "🌈 You are His faithful promise! Today, declare His goodness because you rest in knowing His covenant love will never leave or forsake you.",
            "💕 You wake up loved! Today's declarations flow from the beautiful reality that you are God's beloved child, chosen and cherished beyond measure."
        ]
        let body = bodyArray.randomElement()// Localize
        
        let content = UNMutableNotificationContent()
        content.title = "SpeakLife"
        content.body = body ?? "💕 Good morning, beloved child! Today, speak from the heart of one who knows they are deeply loved by their heavenly Father."
        content.sound = UNNotificationSound.default
        
        var dateComponents = DateComponents()
        dateComponents.calendar = Calendar.autoupdatingCurrent
        dateComponents.timeZone = TimeZone.autoupdatingCurrent
        dateComponents.hour = 8
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents, repeats: false)
        
        
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        notificationCenter.add(request) { (error) in
            if error != nil {
                //  TODO: - handle error
            }
        }
    }
    
    private func nightlyAffirmationReminder() {
        let id = UUID().uuidString
        let bodyArray: [String] = [
            "🌙 You are God's MASTERPIECE, created in Christ Jesus. Even as you sleep, that identity remains unshakeable!",
            "✨ You are the RIGHTEOUSNESS of God in Christ. Not trying to become—you already ARE. Rest in that finished work!",
            "👑 You are ROYALTY—a child of the Most High King. Your bloodline determines your identity, not your circumstances!",
            "💫 You are SEATED in heavenly places with Christ. Your position is secure, far above every problem!",
            "🌟 You are God's BELOVED, in whom He is well pleased. His love for you isn't based on performance!",
            "🔥 You are a NEW CREATION—the old has gone, the new has come. Your past doesn't define you anymore!",
            "🛡️ You are MORE than a conqueror through Christ. Victory isn't something you achieve—it's who you ARE!",
            "⚡ You are the TEMPLE of the Holy Spirit. The same power that raised Jesus lives in YOU!",
            "🌙 You are COMPLETE in Christ, lacking nothing. Everything you need is already within you!",
            "✨ You are God's AMBASSADOR on earth. You carry heaven's authority wherever you go!",
            "👑 You are CHOSEN, not by accident but by design. God handpicked you before the foundation of the world!",
            "💫 You are a CO-HEIR with Christ. Everything that belongs to Him belongs to you too!",
            "🌟 You are ACCEPTED in the Beloved. You don't need to earn God's approval—you already have it!",
            "🔥 You are TRANSFORMED by the renewing of your mind. You think heaven's thoughts!",
            "🛡️ You are God's WORKMANSHIP, His poetry in motion. You're a divine masterpiece!",
            "⚡ You are BLESSED with every spiritual blessing in heavenly places. The blessing isn't coming—it's here!",
            "🌙 You are HIDDEN with Christ in God. Your true identity is secure in Him!",
            "✨ You are the LIGHT of the world. Darkness flees from who you are!",
            "👑 You are a ROYAL PRIESTHOOD, a holy nation. You were born to rule and reign!",
            "💫 You are FEARFULLY and wonderfully made. God doesn't make mistakes—you're perfectly designed!",
            "🌟 You are God's DWELLING PLACE. He doesn't just visit—He lives in you permanently!",
            "🔥 You are ANOINTED for such a time as this. Your identity carries divine purpose!",
            "🛡️ You are REDEEMED and forgiven. Your identity isn't stained by mistakes!",
            "⚡ You are a PARTAKER of the divine nature. God's DNA is in you!",
            "🌙 You are PRECIOUS in God's sight. Your value isn't negotiable—it's fixed in heaven!",
            "✨ You are an OVERCOMER by the blood of the Lamb. Victory flows through your spiritual veins!",
            "👑 You are God's INHERITANCE. He rejoices over you as His prized possession!",
            "💫 You are SANCTIFIED and set apart. You're not common—you're consecrated!",
            "🌟 You are EMPOWERED by the Spirit. Weakness isn't your identity—divine strength is!",
            "🔥 You are TRANSFORMED from glory to glory. Your identity is constantly upgrading!",
            "🛡️ You are ESTABLISHED, anointed, and sealed by God. Your identity has heaven's seal!",
            "⚡ You are a CITIZEN of heaven. Earth is temporary—your true nationality is eternal!",
            "🌙 You are God's POEM, written to display His glory. Every detail of you is intentional!",
            "✨ You are JUSTIFIED freely by His grace. In God's courtroom, you're declared 'NOT GUILTY!'",
            "👑 You are ADOPTED into God's family. You have full rights as a son or daughter!",
            "💫 You are EQUIPPED for every good work. Your identity includes divine capability!",
            "🌟 You are LOVED with an everlasting love. God's feelings about you never change!",
            "🔥 You are SEALED with the Holy Spirit of promise. Your identity is tamper-proof!",
            "🛡️ You are FREE indeed. Your identity isn't bound by any chain!",
            "⚡ You are God's SPECIAL TREASURE. Out of all creation, you're uniquely valued!",
            "🌙 Rest tonight knowing this: You are EXACTLY who God says you are. Nothing can change that!"
        ]
        
        let body =  bodyArray.randomElement()// Localize
        
        let content = UNMutableNotificationContent()
        content.title = "SpeakLife"
        content.body = body ?? "💜 We conquered another day! Lets end the day with gratitude and speaking life into tomorrow."
        content.sound = UNNotificationSound.default
        
        var dateComponents = DateComponents()
        dateComponents.calendar = Calendar.autoupdatingCurrent
        dateComponents.timeZone = TimeZone.autoupdatingCurrent
        dateComponents.hour = 21
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents, repeats: false)
        
        
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        notificationCenter.add(request) { (error) in
            if error != nil {
                //  TODO: - handle error
            }
        }
    }
    
    private func devotionalAffirmationReminder() {
        let id = UUID().uuidString
        let body = "Your Daily Devotion is Ready! 🪑 Take a moment to sit with Jesus!" // Localize
        
        let content = UNMutableNotificationContent()
        content.title = "SpeakLife"
        content.body = body
        content.sound = UNNotificationSound.default
        
        var dateComponents = DateComponents()
        dateComponents.calendar = Calendar.autoupdatingCurrent
        dateComponents.timeZone = TimeZone.autoupdatingCurrent
        dateComponents.hour = 8
        dateComponents.minute = 30
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents, repeats: true)
        
        
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        notificationCenter.add(request) { (error) in
            if error != nil {
                //  TODO: - handle error
            }
        }
    }
    private func prayersAffirmationReminder() {
        let id = UUID().uuidString
        let body = "Time to move mountains 🏔️, come pray along to start your day!" // Localize
        
        let content = UNMutableNotificationContent()
        content.title = "SpeakLife"
        content.body = body
        content.sound = UNNotificationSound.default
        
        var dateComponents = DateComponents()
        dateComponents.calendar = Calendar.autoupdatingCurrent
        dateComponents.timeZone = TimeZone.autoupdatingCurrent
        dateComponents.hour = 8
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents, repeats: true)
        
        
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        notificationCenter.add(request) { (error) in
            if error != nil {
                //  TODO: - handle error
            }
        }
    }
    
    func newAffirmationReminder() {
        let id = UUID().uuidString
        let body = "New Affirmations 🚨" // Localize
        
        let content = UNMutableNotificationContent()
        content.title = "SpeakLife"
        content.body = body
        content.sound = UNNotificationSound.default
        content.badge = 1
        
        let nextTriggerDate = Calendar.current.date(byAdding: .minute, value: 10, to: Date())!
        let comps = Calendar.current.dateComponents([.year, .month, .day, .minute], from: nextTriggerDate)
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: comps, repeats: false)
        
        
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        notificationCenter.add(request) { (error) in
            if error != nil {
                //  TODO: - handle error
            }
        }
    }
    
    private func thanksgivingReminder() {
        let id = UUID().uuidString
        let body = "Let gratitude fill your heart and overflow with thankfulness. May His grace and love surround you and yours today and always. 🍂🦃" // Localize
        
        let content = UNMutableNotificationContent()
        content.title = "Happy Thanksgiving from SpeakLife!"
        content.body = body
        content.sound = UNNotificationSound.default
        
        var dateComponents = DateComponents()
        dateComponents.calendar = Calendar.autoupdatingCurrent
        dateComponents.timeZone = TimeZone.autoupdatingCurrent
        dateComponents.hour = 10
        dateComponents.day = 27
        dateComponents.month = 11
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents, repeats: false)
        
        
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        notificationCenter.add(request) { (error) in
            if error != nil {
                //  TODO: - handle error
            }
        }
    }
    
    private func christmasReminder() {
        let id = UUID().uuidString
        let body = "✝️ Jesus is the heart of this festive season. Let's embrace His love and teachings as we celebrate. Merry Christmas!" // Localize
        
        let content = UNMutableNotificationContent()
        content.title = "Celebrate the True Meaning of Christmas"
        content.body = body
        content.sound = UNNotificationSound.default
        
        var dateComponents = DateComponents()
        dateComponents.calendar = Calendar.autoupdatingCurrent
        dateComponents.timeZone = TimeZone.autoupdatingCurrent
        dateComponents.hour = 9
        dateComponents.day = 25
        dateComponents.month = 12
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents, repeats: false)
        
        
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        notificationCenter.add(request) { (error) in
            if error != nil {
                //  TODO: - handle error
            }
        }
    }
    
    private func newYearsReminder() {
        let id = UUID().uuidString
        let body = "🥳 As we step into the New Year, let's prioritize our walk with Jesus. May His teachings guide our choices and bring blessings in every aspect of our lives. Happy New Year!" // Localize
        
        let content = UNMutableNotificationContent()
        content.title = "Start the New Year with Jesus"
        content.body = body
        content.sound = UNNotificationSound.default
        
        var dateComponents = DateComponents()
        dateComponents.calendar = Calendar.autoupdatingCurrent
        dateComponents.timeZone = TimeZone.autoupdatingCurrent
        dateComponents.day = 1
        dateComponents.month = 1
        dateComponents.hour = 9
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents, repeats: false)
        
        
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        notificationCenter.add(request) { (error) in
            if error != nil {
                //  TODO: - handle error
            }
        }
    }
    
    private func getArrayDates(from dates: [Date], startTimeIndex: Int, endTimeIndex: Int) -> [Date] {
        
        var newArrayDate: [Date] = []
        
        if endTimeIndex <= startTimeIndex {
            let startToEndOfDay = dates.suffix(from: startTimeIndex)
            let endToStart = dates.prefix(through: endTimeIndex)
            newArrayDate.append(contentsOf: startToEndOfDay)
            newArrayDate.append(contentsOf: endToStart)
            return newArrayDate
        }
        
        var tick = 0
        for date in dates {
            if tick >= startTimeIndex && tick <= endTimeIndex  {
                newArrayDate.append(date)
            }
            tick += 1
        }
        return newArrayDate
    }
    
    func getHourMinute(startTime: Int, endTime: Int, count: Int) -> [(hour: Int, minute: Int)] {
        let dates = TimeSlots.getDateTimeSlots()
        let calendar = Calendar.autoupdatingCurrent
        
        let newArrayDates = getArrayDates(from: dates, startTimeIndex: startTime, endTimeIndex: endTime)
        
        var returnTimes: [(hour: Int, minute: Int)] = []
        var tempCount = 0
        
        while tempCount < count && tempCount < newArrayDates.count {
            let hour = calendar.component(.hour, from: newArrayDates[tempCount])
            let minute = calendar.component(.minute, from: newArrayDates[tempCount])
            let newTime = (hour: hour, minute: minute)
            returnTimes.append(newTime)
            tempCount += 1
        }
        
        let stopIndex = tempCount - 1
        
        
        while tempCount < count {
            let hour = calendar.component(.hour, from: newArrayDates[stopIndex])
            let minute = calendar.component(.minute, from: newArrayDates[stopIndex])
            let newTime = (hour: hour, minute: minute)
            returnTimes.append(newTime)
            tempCount += 1
            
        }
        
        return returnTimes
    }
    
    private func createDate(hour: Int, minute: Int) -> Date? {
        // Use the current date as the base
        let currentDate = Date()
        let calendar = Calendar.autoupdatingCurrent

        // Set the specific hour and minute
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: currentDate)
    }
    
    func distributeTimes(startTime: Int, endTime: Int, count: Int) -> [(hour: Int, minute: Int)] {
        let dates = TimeSlots.getDateTimeSlots()
        let calendar = Calendar.autoupdatingCurrent
        let newArrayDates = getArrayDates(from: dates, startTimeIndex: startTime, endTimeIndex: endTime)
        let startTimeHour = calendar.component(.hour, from: newArrayDates[0])
        let startTimeMinute = calendar.component(.minute, from: newArrayDates[0])
        
        let endTimeHour = calendar.component(.hour, from: newArrayDates.last!)
        let endTimeMinute = calendar.component(.minute, from: newArrayDates.last!)
                                                 
        let startTime = createDate(hour: startTimeHour, minute: startTimeMinute)!
        let endTime = createDate(hour: endTimeHour, minute: endTimeMinute)!
        
        
        guard count > 0, startTime < endTime else {
            return [] // Return an empty array if count is zero or if start time is after end time
        }

        var result: [(hour: Int, minute: Int)] = []

        // Calculate total duration in seconds
        let totalSeconds = Int(endTime.timeIntervalSince(startTime))
        
        // Calculate interval in seconds
        let interval = totalSeconds / count

        // Generate times
        for i in 0..<count {
            if let time = Calendar.current.date(byAdding: .second, value: i * interval, to: startTime) {
                let hour = Calendar.current.component(.hour, from: time)
                let minute = Calendar.current.component(.minute, from: time)
                result.append((hour, minute))
            }
        }

        return result
    }
    
    func notificationsPending(completion: @escaping(Bool, Int?) -> Void) {
        notificationCenter.getPendingNotificationRequests { requests in
            if requests.count > 0 {
                completion(true, requests.count)
                return
            } else {
                completion(false, nil)
                return
            }
        }
    }
    
    private func removeNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
    }
    
    private func verifyNotificationsScheduled() {
        notificationCenter.getPendingNotificationRequests { requests in
            print("\n📊 NOTIFICATION VERIFICATION REPORT")
            print("=====================================")
            print("Total pending: \(requests.count) notifications")
            
            if requests.count == 0 {
                // Warning: 
                print("⚠️ WARNING: No notifications were scheduled!")
            } else {
                print("✅ SUCCESS: Notifications are properly scheduled")
                
                // Check authorization status
                self.notificationCenter.getNotificationSettings { settings in
                    switch settings.authorizationStatus {
                    case .authorized:
                        print("✅ Permissions: Authorized")
                    case .provisional:
                        // Warning: 
                        print("⚠️ Permissions: Provisional (may not show all alerts)")
                    case .denied:
                        print("❌ Permissions: DENIED - User must enable in Settings")
                    case .notDetermined:
                        print("❓ Permissions: Not determined - Need to request")
                    @unknown default:
                        print("❓ Permissions: Unknown status")
                    }
                    
                    print("   Alert: \(settings.alertSetting == .enabled ? "✅" : "❌")")
                    print("   Sound: \(settings.soundSetting == .enabled ? "✅" : "❌")")
                    print("   Badge: \(settings.badgeSetting == .enabled ? "✅" : "❌")")
                }
                
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm"
                formatter.timeZone = TimeZone.autoupdatingCurrent
                
                // Show all scheduled notifications with full date info
                print("\n📅 Scheduled Notifications:")
                for (index, request) in requests.prefix(15).enumerated() {
                    if let trigger = request.trigger as? UNCalendarNotificationTrigger {
                        let components = trigger.dateComponents
                        
                        var dateStr = ""
                        if let year = components.year,
                           let month = components.month,
                           let day = components.day,
                           let hour = components.hour,
                           let minute = components.minute {
                            dateStr = "\(year)-\(String(format: "%02d", month))-\(String(format: "%02d", day)) \(String(format: "%02d:%02d", hour, minute))"
                        } else if let hour = components.hour,
                                  let minute = components.minute {
                            dateStr = "Daily at \(String(format: "%02d:%02d", hour, minute))"
                        }
                        
                        print("\n  \(index + 1). \(dateStr)")
                        print("      Body: \(request.content.body.prefix(50))...")
                        print("      Repeats: \(trigger.repeats)")
                        
                        // Check if notification date is in the past
                        if let nextTriggerDate = trigger.nextTriggerDate() {
                            let timeUntil = nextTriggerDate.timeIntervalSince(Date())
                            if timeUntil < 0 {
                                // Warning: 
                                print("      ⚠️ WARNING: Next trigger is in the PAST!")
                                print("      Was supposed to fire: \(formatter.string(from: nextTriggerDate))")
                            } else {
                                let hours = Int(timeUntil / 3600)
                                let minutes = Int((timeUntil.truncatingRemainder(dividingBy: 3600)) / 60)
                                print("      ⏰ Will fire: \(formatter.string(from: nextTriggerDate)) (in \(hours)h \(minutes)m)")
                            }
                        }
                    }
                }
                
                if requests.count > 15 {
                    print("\n  ... and \(requests.count - 15) more notifications")
                }
                
                print("\n=====================================\n")
            }
        }
    }
    
    // MARK: - Checklist Notifications
    
    func scheduleChecklistNotifications() {
        scheduleDailyPersonalizedNotifications()
        // FallbackEveningNotification removed — replaced by streak_at_risk (9pm)
        // and streak_crushed_it (8:30pm) from LifecycleNotificationService
        notificationCenter.removePendingNotificationRequests(withIdentifiers: ["FallbackEveningNotification"])
    }
    
    // Schedule a fallback evening notification that repeats for days when app isn't opened
    func scheduleFallbackEveningNotification() {
        let id = "FallbackEveningNotification"
        
        // Get saved info for personalization
        let userDefaults = UserDefaults.standard
        let userName = userDefaults.string(forKey: "userName") ?? "Friend"
        
        let content = UNMutableNotificationContent()
        content.title = "SpeakLife"
        content.body = "🌙 Hey \(userName)! Don't forget to check your spiritual progress today. Every step counts!"
        content.sound = UNNotificationSound.default
        
        var dateComponents = DateComponents()
        dateComponents.calendar = Calendar.autoupdatingCurrent
        dateComponents.timeZone = TimeZone.autoupdatingCurrent
        dateComponents.hour = 19  // 7 PM
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        
        notificationCenter.add(request) { error in
            if let error = error {
                print("Error scheduling fallback evening notification: \(error)")
            }
        }
    }
    
    // Daily personalized morning notification removed — only user-configured
    // declaration reminders + streak-at-risk (9pm) fire on a daily basis.
    func scheduleDailyPersonalizedNotifications() {
        // Cancel any previously scheduled morning notification
        notificationCenter.removePendingNotificationRequests(
            withIdentifiers: ["PersonalizedMorningNotification"]
        )
    }
    
    // MARK: - Dynamic Checklist Notifications
    
    func schedulePersonalizedChecklistNotification(
        isEvening: Bool,
        userName: String = "Friend",
        currentStreak: Int,
        completedActivities: [String],
        remainingActivities: [String],
        totalActivities: Int
    ) {
        let id = isEvening ? "PersonalizedEveningNotification" : "PersonalizedMorningNotification"
        
        // Cancel existing personalized notification
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [id])
        
        // Don't schedule evening notification if all tasks are already completed
        // This prevents unnecessary "congrats" notifications when user already knows they're done
        if isEvening && remainingActivities.isEmpty && completedActivities.count == totalActivities {
            // All tasks completed - skip evening notification as user is already aware
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "SpeakLife"
        content.sound = UNNotificationSound.default
        
        if isEvening {
            content.body = createEveningNotificationMessage(
                userName: userName,
                currentStreak: currentStreak,
                completedActivities: completedActivities,
                remainingActivities: remainingActivities,
                totalActivities: totalActivities
            )
        } else {
            content.body = createMorningNotificationMessage(
                userName: userName,
                currentStreak: currentStreak
            )
        }
        
        var dateComponents = DateComponents()
        dateComponents.calendar = Calendar.autoupdatingCurrent
        dateComponents.timeZone = TimeZone.autoupdatingCurrent
        dateComponents.hour = isEvening ? 19 : 8
        dateComponents.minute = 0
        
        // Morning notifications can repeat daily, but evening notifications need fresh content each day
        let repeats = !isEvening
        
        if isEvening {
            // For evening, schedule for today at 7 PM
            let now = Date()
            let calendar = Calendar.current
            let currentHour = calendar.component(.hour, from: now)
            let currentMinute = calendar.component(.minute, from: now)
            
            // If it's already close to 7 PM (within 30 minutes), delay by 30 minutes to allow more time for completion
            if currentHour == 18 && currentMinute >= 30 {
                // Schedule for 7:30 PM instead to give more time for task completion
                dateComponents.hour = 19
                dateComponents.minute = 30
            }
            
            if currentHour < 19 || (currentHour == 19 && currentMinute < 30) {
                // Schedule for today at 7 PM (or 7:30 PM) with specific date
                let todayComponents = calendar.dateComponents([.year, .month, .day], from: now)
                dateComponents.year = todayComponents.year
                dateComponents.month = todayComponents.month
                dateComponents.day = todayComponents.day
            } else {
                // Already past notification time, don't schedule for today
                return
            }
        }
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: repeats)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        
        notificationCenter.add(request) { error in
            if let error = error {
                print("Error scheduling personalized checklist notification: \(error)")
            }
        }
    }
    
    private func createMorningNotificationMessage(userName: String, currentStreak: Int) -> String {
        let templates = [
            "🌅 Good morning \(userName)! Day \(currentStreak + 1) awaits - continue your amazing streak!",
            "⚡ Rise and shine \(userName)! Ready to make day \(currentStreak + 1) count?",
            "🔥 Morning warrior \(userName)! Your \(currentStreak + 1)-day journey with God begins now!",
            "👑 \(userName), you're on fire! Day \(currentStreak + 1) of your spiritual journey starts now!",
            "🌟 Hey \(userName)! Let's make day \(currentStreak + 1) your best spiritual day yet!"
        ]
        
        return templates.randomElement() ?? "🌅 Good morning \(userName)! Time to continue your spiritual journey!"
    }
    
    private func createEveningNotificationMessage(
        userName: String,
        currentStreak: Int,
        completedActivities: [String],
        remainingActivities: [String],
        totalActivities: Int
    ) -> String {
        
        let completedCount = completedActivities.count
        let progress = "(\(completedCount)/\(totalActivities))"
        
        if remainingActivities.isEmpty {
            // All completed - celebration messages
            let celebrationTemplates = [
                "🎉 Amazing \(userName)! You completed all \(totalActivities) activities today. Day \(currentStreak) strong!",
                "✨ Perfect day \(userName)! \(totalActivities)/\(totalActivities) activities completed! 🔥",
                "👑 Incredible \(userName)! You crushed all your spiritual goals today!",
                "🌟 Outstanding \(userName)! Another perfect day in your \(currentStreak)-day streak!",
                "🙌 Phenomenal \(userName)! All \(totalActivities) activities completed - you're unstoppable!"
            ]
            return celebrationTemplates.randomElement() ?? "🎉 Amazing work today \(userName)!"
            
        } else if completedCount > 0 {
            // Partially completed - encouraging messages
            let remaining = remainingActivities.prefix(2).joined(separator: ", ")
            let partialTemplates = [
                "💪 Great progress \(userName)! \(progress) Just \(remaining) left to complete your perfect day!",
                "🔥 So close \(userName)! You've got \(remaining) remaining - finish strong!",
                "⚡ Nice work \(userName)! \(progress) Only \(remaining) left for a complete day!",
                "🌟 Keep going \(userName)! Just \(remaining) away from perfection \(progress)!"
            ]
            return partialTemplates.randomElement() ?? "💪 Keep going \(userName)! You're almost there!"
            
        } else {
            // Nothing completed - gentle encouragement
            let encouragementTemplates = [
                "🕊️ Hey \(userName), there's still time! Spend a few moments with God before the day ends.",
                "💛 \(userName), no pressure - even 5 minutes with God can transform your day!",
                "🌙 It's okay \(userName)! God's grace is new every morning. Try one quick activity?",
                "✨ \(userName), God's not keeping score - but you might feel amazing after just one activity!",
                "🙏 \(userName), even a brief moment with God counts. Your heart matters to Him!"
            ]
            return encouragementTemplates.randomElement() ?? "🕊️ There's still time \(userName)! A few moments with God can make all the difference."
        }
    }
    
    // MARK: - AI Enhanced Notifications
    
    private func shouldUseAINotifications() -> Bool {
        // For now, return false until we can properly access SubscriptionStore
        // This can be updated when the notification system gets refactored
        return false
    }
    
    private func registerAIEnhancedNotifications(count: Int,
                                               startTime: Int,
                                               endTime: Int,
                                               categories: Set<DeclarationCategory>? = nil,
                                               callback: (() -> Void)? = nil) {
        Task {
            do {
                // Get AI-optimized notification times
                let optimalTimes = await RecommendationEngine.shared.getOptimalNotificationTimes()
                
                // Get AI-recommended contextual content
                let contextualDeclarations = await RecommendationEngine.shared.getContextualDeclarations()
                
                // Use AI-selected content if available, otherwise fall back to categories
                let notifications: [NotificationProcessor.NotificationData]
                if !contextualDeclarations.isEmpty {
                    // Convert AI declarations to notification data
                    notifications = contextualDeclarations.prefix(count).map { declaration in
                        NotificationProcessor.NotificationData(book: declaration.category.rawValue, body: declaration.text, category: declaration.category.rawValue)
                    }
                } else if let categories = categories {
                    notifications = getNotificationData(for: count, categories: categories)
                } else {
                    notifications = getNotificationData(for: count, categories: notificationCategories())
                }
                
                await MainActor.run {
                    // Use AI-optimized timing if available, otherwise use user preferences
                    if !optimalTimes.isEmpty {
                        self.prepareAINotifications(declarations: notifications, optimalTimes: optimalTimes, count: count) {
                            callback?()
                        }
                    } else {
                        // Fall back to regular timing
                        self.prepareNotifications(declarations: notifications, startTime: startTime, endTime: endTime, count: count) {
                            callback?()
                        }
                    }
                }
                
            } catch {
                print("❌ AI notification setup failed, falling back to standard: \(error)")
             //    Fall back to standard notification system
                await MainActor.run {
                    if let categories = categories {
                        let notifications = self.getNotificationData(for: count, categories: categories)
                        self.prepareNotifications(declarations: notifications, startTime: startTime, endTime: endTime, count: count) {
                            callback?()
                        }
                    }
                }
            }
        }
    }
    
    private func prepareAINotifications(declarations: [NotificationProcessor.NotificationData], optimalTimes: [Date], count: Int, callback: @escaping () -> Void) {
        // Convert optimal times to hour-based scheduling similar to existing system
        let timeHours = optimalTimes.map { Calendar.current.component(.hour, from: $0) }
        let startTime = timeHours.min() ?? 9
        let endTime = timeHours.max() ?? 21
        
        // Use existing notification preparation with AI-optimized timing
        prepareNotifications(declarations: declarations, startTime: startTime, endTime: endTime, count: count, callback: callback)
        
    }
}


final class UpdateNotificationsOperation: Operation {
    
    private let appState: AppState
    
    init(appState: AppState) {
        self.appState = appState
    }
    
    override func start() {
        let categories = appState.selectedNotificationCategories.components(separatedBy: ",").compactMap({ DeclarationCategory($0) })
        var setCategories = Set(categories)
        if setCategories.count <= 1 {
            setCategories.insert(DeclarationCategory(rawValue: "destiny")!)
            setCategories.insert(DeclarationCategory(rawValue: "love")!)
        }
        let selectedCategories = setCategories.isEmpty ? nil : setCategories
        
        NotificationManager.shared.notificationsPending { [weak self] pending, count in
            
            guard let self = self else { return }
            
            if self.appState.notificationEnabled {
                self.appState.lastNotificationSetDate = Date()
                NotificationManager.shared.registerNotifications(count: self.appState.notificationCount,
                                                                 startTime: self.appState.startTimeIndex,
                                                                 endTime: self.appState.endTimeIndex,
                                                                 categories: selectedCategories)
                self.completionBlock?()
                
            }
            
        }
    }
}
