//
//  AppState.swift
//  Dios Es Aqui
//
//  Created by Riccardo Washington on 1/25/22.
//

import SwiftUI
import StoreKit
import FirebaseAnalytics
import FirebaseRemoteConfig

final class AppState: ObservableObject {
    @Published var rootViewId = UUID()
    /// A personalized message delivered via push notification, awaiting display in
    /// its own screen. Set when a `deepLink == "message"` notification is tapped;
    /// drives the `.sheet(item:)` in HomeView. Not persisted — it lives only for
    /// the duration of the presentation.
    @Published var remoteMessage: RemoteMessage?
    @Published var showIntentBar = true
    @Published var onBoardingTest = true
    @Published var showScreenshotLabel = false {
        didSet {
            // Automatically reset after 5 seconds as a safety measure
            if showScreenshotLabel {
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
                    if self?.showScreenshotLabel == true {
                        // Auto-resetting stuck showScreenshotLabel
                        self?.showScreenshotLabel = false
                    }
                }
            }
        }
    }
    @AppStorage("onboarded") var isOnboarded = false
    @AppStorage("newPrayersAdded") var newPrayersAdded = true
    @AppStorage("newCategoriesAddedv4") var newCategoriesAddedv4 = true
    @AppStorage("newThemesAdded") var newThemesAdded = true
    @AppStorage("newSettingsAdded") var newSettingsAdded = true
    @AppStorage("abbasLoveAdded") var abbasLoveAdded = true
    @AppStorage("newTrackerAdded") var newTrackerAdded = true
    @AppStorage("lastNotificationSetDate") var lastNotificationSetDate = Date()
    @AppStorage("lastSharedAttemptDate") var lastSharedAttemptDate = Date()
    @AppStorage("notificationEnabled") var notificationEnabled = false
    @AppStorage("notificationCount") var notificationCount = 5
    @AppStorage("startTimeNotification") var startTimeNotification = ""
    @AppStorage("endTimeNotification") var endTimeNotification = ""
    @AppStorage("startTimeIndex") var startTimeIndex = 14
    @AppStorage("endTimeIndex") var endTimeIndex = 47
    @AppStorage("selectedNotificationCategories") var selectedNotificationCategories: String = ""
    @AppStorage("abbasLoveLetterIndex") var loveLetterIndex = 0
    @AppStorage("resetNotifications") var resetNotifications = true
    // Migration flag: set false in 4.10 so existing users get reset to all-day window + 10 reminders.
    // Default value here is "true" so brand-new installs (no key in defaults) skip the reset since
    // they already start with the new defaults above. The migration code below explicitly checks
    // for the key being absent vs. false to know whether this is a fresh install or a pre-4.10 user.
    @AppStorage("notificationDefaultsMigratedV2") var notificationDefaultsMigratedV2 = true
    // V3 migration: the first 4.10 build's V2 migration wrote startTimeIndex=0 (midnight),
    // which sent reminders overnight. This flag bumps those users to 7:00 AM (index 14).
    // Defaults to true so brand-new installs (no existing pref keys) skip the reset.
    @AppStorage("notificationDefaultsMigratedV3") var notificationDefaultsMigratedV3 = true
    // V4 migration: drops notificationCount default from 10 to 5. 10/day was above
    // the industry-best-practice ceiling for habit-formation apps and was driving
    // users to disable the toggle entirely. Resets count to 5 unless the user
    // explicitly wanted more (we can't distinguish, so this is a hard reset —
    // users who actually wanted more can bump it back up in Reminders).
    @AppStorage("notificationDefaultsMigratedV4") var notificationDefaultsMigratedV4 = true
    // V5 migration: heals the personal declaration daily push for users whose
    // schedule call was silently dropped (saved before iOS permission was granted)
    // or stuck at the pre-V3 midnight start time. The trigger is repeats=true,
    // so a one-time heal is enough — iOS handles the daily re-fire from there.
    @AppStorage("personalDeclarationRescheduledV1") var personalDeclarationRescheduledV1 = true

    // Time the personal declaration daily push fires at. Independent of
    // startTimeIndex (which is the content batch window start) so the user can
    // adjust their content window without moving their personal declaration.
    // 30-minute slots from midnight; 16 = 8:00 AM. Once set at save time the
    // declaration push stays at that time regardless of other notification
    // settings changes.
    @AppStorage("personalDeclarationTimeIndex") var personalDeclarationTimeIndex = 16
    @AppStorage("lastReviewRequestSetDatev1") var lastReviewRequestSetDate: Date?
    @AppStorage("offerDiscount") var offerDiscount = false
    @AppStorage("offerDiscountTry") var offerDiscountTry = 0
    @AppStorage("shareDiscountTry") var shareDiscountTry = 0
    @AppStorage("discountEndTime") var discountEndTime: Date?
    @AppStorage("lastRequestedRatingVersion") var lastRequestedRatingVersion: String?
    @AppStorage("helpUs") var helpUsGrowCount = 0
    @Published var timeRemainingForDiscount = 0
    @AppStorage("userName") var userName = ""
    @AppStorage("firstSelection") var firstSelection = ""
    @AppStorage("discountSelection") var discountSelection = ""
    @AppStorage("discountPercentage") var discountPercentage = ""
    @AppStorage("subscriptionTest") var subscriptionTestnineteen = false
    @AppStorage("firstOpen") var firstOpen = true
    @AppStorage("showGiftViewCount") var showGiftViewCount = 0
    @AppStorage("showQuizButton") var showQuizButton = true
    
    @AppStorage("hasCompletedDemo") var hasCompletedDemo = false
    @AppStorage("hasCompletedEnhancedOnboarding") var hasCompletedEnhancedOnboarding = false

    // Survey personalization — set by SurveyOnboardingView, read by NotificationScene and paywalls
    @AppStorage("surveyGoalWord") var surveyGoalWord: String = ""

    // Quiz onboarding (Treatment cohort of useQuizOnboarding A/B). Set by
    // QuizOnboardingView; read by HighConversionPaywallView for headline
    // framing and by analytics for segment lift measurement.
    @AppStorage("onboarding_segment") var onboardingSegment: String = ""
    @AppStorage("onboarding_completed_at") var onboardingCompletedAt: Date?
    @AppStorage("onboarding_quiz_version") var onboardingQuizVersion: String = ""

    var selectedDeclarationStyles: [String] {
        get {
            let raw = UserDefaults.standard.string(forKey: "selectedDeclarationStyles") ?? ""
            return raw.isEmpty ? [] : raw.components(separatedBy: ",")
        }
        set {
            UserDefaults.standard.set(newValue.joined(separator: ","), forKey: "selectedDeclarationStyles")
        }
    }

    // Soul Profile — everything onboarding collected, captured at completion.
    // The record itself lives under `soul_profile_v1` (SoulProfileRepository);
    // this flag is just the cheap "is there one?" check for callers that would
    // otherwise decode the blob to find out.
    @AppStorage("hasSoulProfile") var hasSoulProfile = false

    // Personal Declaration
    @AppStorage("hasPersonalDeclaration") var hasPersonalDeclaration = false
    @AppStorage("scrollToPersonalDeclaration") var scrollToPersonalDeclaration = false

    // Weekly Focus — the Sunday check-in layer. Additive to the Personal
    // Declaration above, never a replacement: the Anchor's day count keeps
    // climbing while the week resets every Sunday by design.
    //
    // Set by the `weeklyFocus` deep link (and by the feed card) to present the
    // check-in sheet. Persisted rather than @Published for the same reason
    // scrollToPersonalDeclaration is: a cold-launch notification tap sets it
    // before any view exists to observe it.
    @AppStorage("presentWeeklyCheckIn") var presentWeeklyCheckIn: Bool = false
    // Kill switch, mirrored from Remote Config `weeklyFocusEnabled` in
    // SubscriptionStore.updateConfigValues (same pattern as enableAIFeatures).
    // Defaults true so a fresh install has the feature before the first fetch.
    @AppStorage("weeklyFocusEnabled") var weeklyFocusEnabled: Bool = true
    
    // Track when app was last backgrounded to prevent stale audio from restarting
    @AppStorage("lastBackgroundDate") var lastBackgroundDate: Date?
    @AppStorage("backgroundMusicWasPlaying") var backgroundMusicWasPlaying = false
    
    // Checklist notification settings
    @AppStorage("checklistNotificationsEnabled") var checklistNotificationsEnabled = true
    @AppStorage("morningReminderEnabled") var morningReminderEnabled = true
    @AppStorage("eveningCheckInEnabled") var eveningCheckInEnabled = true
    @AppStorage("morningReminderHour") var morningReminderHour = 8
    @AppStorage("morningReminderMinute") var morningReminderMinute = 0
    @AppStorage("eveningCheckInHour") var eveningCheckInHour = 19
    @AppStorage("eveningCheckInMinute") var eveningCheckInMinute = 0
    
    init() {
        let defaults = UserDefaults.standard

        // Detect a pre-4.10 user: they have notification keys saved from a prior version
        // but no migration flag yet. Brand-new installs have neither, so they skip the reset.
        let hasExistingNotificationPrefs = defaults.object(forKey: "notificationCount") != nil
            || defaults.object(forKey: "startTimeIndex") != nil
            || defaults.object(forKey: "endTimeIndex") != nil
        let migrationFlagPresent = defaults.object(forKey: "notificationDefaultsMigratedV2") != nil
        let needsV2Migration = hasExistingNotificationPrefs && !migrationFlagPresent

        // Force initialization of @AppStorage properties with defaults
        if defaults.object(forKey: "notificationCount") == nil {
            defaults.set(5, forKey: "notificationCount")
        }
        if defaults.object(forKey: "startTimeIndex") == nil {
            defaults.set(14, forKey: "startTimeIndex") // 7:00 AM (index = hour × 2)
        }
        if defaults.object(forKey: "endTimeIndex") == nil {
            defaults.set(47, forKey: "endTimeIndex")
        }

        // 4.10 reset: existing users get the new all-day window.
        // Their preferences are overwritten once, then the flag is set so this never repeats.
        if needsV2Migration {
            defaults.set(5, forKey: "notificationCount")
            defaults.set(14, forKey: "startTimeIndex") // 7:00 AM
            defaults.set(47, forKey: "endTimeIndex")   // 11:30 PM
            // Force the next foreground tick in SpeakLifeApp to reschedule notifications
            // with the new window instead of waiting for the existing batch to expire.
            defaults.removeObject(forKey: "lastScheduledNotificationDate")
            defaults.removeObject(forKey: "nextRescheduleDate")
        }
        defaults.set(true, forKey: "notificationDefaultsMigratedV2")

        // V3 fix-up: anyone who already ran the earlier V2 migration got startTimeIndex=0
        // (midnight) and is now stuck there because @AppStorage defaults don't override
        // existing UserDefaults values. Bump them to 7:00 AM exactly once.
        if hasExistingNotificationPrefs,
           defaults.object(forKey: "notificationDefaultsMigratedV3") == nil {
            defaults.set(14, forKey: "startTimeIndex") // 7:00 AM
            defaults.removeObject(forKey: "lastScheduledNotificationDate")
            defaults.removeObject(forKey: "nextRescheduleDate")
        }
        defaults.set(true, forKey: "notificationDefaultsMigratedV3")

        // V4 fix-up: drop count from 10 to 5 for everyone who hasn't migrated yet.
        // Volume above 5/day was the #1 cause of users disabling notifications entirely.
        if hasExistingNotificationPrefs,
           defaults.object(forKey: "notificationDefaultsMigratedV4") == nil {
            defaults.set(5, forKey: "notificationCount")
            defaults.removeObject(forKey: "lastScheduledNotificationDate")
            defaults.removeObject(forKey: "nextRescheduleDate")
        }
        defaults.set(true, forKey: "notificationDefaultsMigratedV4")

        // V5 heal: the personal declaration push has its own time setting now —
        // independent of startTimeIndex (content batch window). For existing users
        // we seed personalDeclarationTimeIndex to 8:00 AM (default) and re-schedule
        // once. The trigger is repeats=true, so this one-time heal restores users
        // whose schedule was silently dropped (pre-permission save) or stuck at
        // the pre-V3 midnight time. Runs async so the repository is wired by then.
        let needsPersonalDeclarationHeal = defaults.bool(forKey: "hasPersonalDeclaration")
            && defaults.object(forKey: "personalDeclarationRescheduledV1") == nil
        if needsPersonalDeclarationHeal {
            // Seed the new dedicated time setting once. If the user's current
            // startTimeIndex is reasonable (not the pre-V3 midnight slot) reuse
            // it so users whose declaration was already firing at the right time
            // (e.g. 7 AM) don't get yanked to a new hour. Otherwise default to
            // 8 AM (index 16). 12 = 6 AM is the lowest "reasonable" morning.
            if defaults.object(forKey: "personalDeclarationTimeIndex") == nil {
                let currentStart = defaults.integer(forKey: "startTimeIndex")
                let seed = (currentStart >= 12) ? currentStart : 16
                defaults.set(seed, forKey: "personalDeclarationTimeIndex")
            }
            let healTimeIndex = defaults.integer(forKey: "personalDeclarationTimeIndex")
            DispatchQueue.main.async {
                DIContainer.shared.rescheduleActivePersonalDeclarationIfNeeded(
                    startTimeIndex: healTimeIndex
                )
            }
        }
        defaults.set(true, forKey: "personalDeclarationRescheduledV1")

        // V6 heal: declarations content was stuck on stale buggy-era state for
        // users where prior versions of CoreDataAPIService (in-memory remoteVersion
        // not forwarding to LocalAPIClient's @AppStorage) and setRemoteDeclarationVersion
        // (clobbering UserDefaults back to 0) left localVersion at some value but
        // disk content was never refreshed. Reset localVersion=0 and wipe the on-disk
        // declarations file so the next loadFromBackEnd is forced to re-fetch from
        // Firebase Storage (or fall back to the freshly-bundled v10). Idempotent:
        // sentinel flag keeps it one-shot.
        if defaults.object(forKey: "declarationsHealedAfterBugFixV1") == nil {
            print("🩹 rwrw V6 heal: resetting localVersion and clearing on-disk declarations cache")
            defaults.set(0, forKey: "localVersion")
            // Don't touch remoteVersion — let RC drive it on next async fetch.
            // Don't touch lastRemoteFetchDate — preserves the legitimate fresh-install
            // distinction for any future logic.
            let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            if let url = docDir?.appendingPathComponent("declarations").appendingPathExtension("txt") {
                try? FileManager.default.removeItem(at: url)
            }
            LocalAPIClient.clearCache()
            defaults.set(true, forKey: "declarationsHealedAfterBugFixV1")
        }

        // V7 heal: align personalDeclarationTimeIndex with the user's current
        // startTimeIndex. Until the picker-mirror commit there was no user-facing
        // way to set the PD time independently of the window picker — but V5
        // only seeded personalDeclarationTimeIndex if the key was nil, so users
        // whose V5 heal already wrote 8 AM (or seeded from a then-stale
        // startTimeIndex) never got resynced when they later adjusted their
        // window. Sentinel flag keeps it one-shot. Only resyncs if the current
        // startTimeIndex is a reasonable morning hour (>= 6 AM) so we don't
        // move anyone to midnight.
        let needsPersonalDeclarationTimeResync = defaults.bool(forKey: "hasPersonalDeclaration")
            && defaults.object(forKey: "personalDeclarationTimeResyncedV1") == nil
        if needsPersonalDeclarationTimeResync {
            let currentStart = defaults.integer(forKey: "startTimeIndex")
            if currentStart >= 12 {
                defaults.set(currentStart, forKey: "personalDeclarationTimeIndex")
                DispatchQueue.main.async {
                    DIContainer.shared.rescheduleActivePersonalDeclarationIfNeeded(
                        startTimeIndex: currentStart
                    )
                }
            }
        }
        defaults.set(true, forKey: "personalDeclarationTimeResyncedV1")

        // V8 heal: collapse an auto-widened notification category set back down to
        // the single category the user actually chose in onboarding. Older
        // onboarding builds wrote goalWord.notificationCategories /
        // segment.notificationCategories (a curated 4-6 category set) into
        // selectedNotificationCategories, so daily pushes surfaced topics the user
        // never picked. New onboarding writes only the single category, and the
        // background reschedule paths now respect the saved set exactly — but
        // existing users still carry the widened value in UserDefaults.
        //
        // Precise + safe: only collapse when the stored set EXACTLY matches one of
        // the known auto-widened patterns. A user who deliberately multi-selected
        // in Settings won't match one of those curated combos and is left
        // untouched. One-shot via sentinel.
        if defaults.object(forKey: "notificationCategoriesCollapsedV1") == nil {
            let rawStored = defaults.string(forKey: "selectedNotificationCategories") ?? ""
            let storedSet = Set(rawStored.split(separator: ",").compactMap { DeclarationCategory(rawValue: String($0)) })
            print("🔎 notification categories check: stored=\(storedSet.map { $0.rawValue }.sorted()) onboardingCategory=\(defaults.string(forKey: "selectedCategory") ?? "nil")")
            if storedSet.count > 1 {
                // Enum-derived patterns from the two routed onboarding flows, plus
                // the hardcoded fallback sets used by older/unrouted flows
                // (StreamlinedSpiritualWarfareFlow + EnhancedOnboardingViewRefactored
                // fall back to [.faith,.confidence,.wisdom,.destiny] when goalWord is
                // nil; OnboardingView seeds [.faith,.confidence,.wisdom,.speaklife]).
                let autoWidenedPatterns: [Set<DeclarationCategory>] =
                    SurveyGoalWord.allCases.map { $0.notificationCategories }
                    + QuizSegment.allCases.map { $0.notificationCategories }
                    + [
                        [.faith, .confidence, .wisdom, .destiny],
                        [.faith, .confidence, .wisdom, .speaklife],
                    ]
                if autoWidenedPatterns.contains(storedSet),
                   let single = DeclarationCategory(rawValue: defaults.string(forKey: "selectedCategory") ?? ""),
                   storedSet.contains(single) {
                    defaults.set(single.rawValue, forKey: "selectedNotificationCategories")
                    print("🩹 V8 heal: collapsed auto-widened notification categories \(storedSet.map { $0.rawValue }.sorted()) → \(single.rawValue)")
                    DispatchQueue.main.async {
                        NotificationManager.shared.rescheduleFromUserDefaults()
                    }
                }
            }
        }
        defaults.set(true, forKey: "notificationCategoriesCollapsedV1")

        // Heal lifecycle pushes (D1-D30) that were wiped by the legacy
        // removeAllPendingNotificationRequests() bug in NotificationManager.
        // Service-side flag (lifecycle_repaired_v1) keeps it one-shot.
        DispatchQueue.main.async {
            LifecycleNotificationService.shared.repairLifecycleIfNeeded()
            // Remove legacy repeating "We've Missed You" re-engagement pushes
            // that an earlier build pinned to a fixed (often middle-of-the-night)
            // time, so existing users stop getting 1 AM notifications.
            AINotificationService.shared.cleanupLegacyRepeatingOneShots()
        }

        // Validate and fix any invalid existing values
        validateAndFixNotificationSettings()
    }
    
    private func validateAndFixNotificationSettings() {
        // Fix notification count
        if notificationCount <= 0 {
            notificationCount = 5
        }

        // Fix time indices — default window starts at 7:00 AM and runs to 11:30 PM
        // so reminders never wake users overnight.
        if startTimeIndex < 0 || startTimeIndex >= 48 {
            startTimeIndex = 14 // 7:00 AM
        }

        if endTimeIndex <= startTimeIndex || endTimeIndex >= 48 {
            endTimeIndex = 47
        }

        // Ensure minimum window of 2 hours
        if (endTimeIndex - startTimeIndex) < 4 { // 4 = 2 hours (30min intervals)
            endTimeIndex = min(startTimeIndex + 4, 47)
        }
    }

    // Call this method when user changes start/end times to ensure validity
    func validateTimeRange() {
        if endTimeIndex <= startTimeIndex {
            endTimeIndex = min(startTimeIndex + 4, 47) // Minimum 2 hour window
        }
    }

    // Call this method to ensure notification count is valid
    func validateNotificationCount() {
        if notificationCount <= 0 {
            notificationCount = 5
        }
    }

    /// Requests an App Store review if the throttle allows it. Apple's
    /// SKStoreReviewController hard-caps at 3 prompts per 365 days regardless,
    /// so this gate exists to avoid burning the OS-level budget on rapid-fire
    /// triggers (every favorite tap, every devotional share, etc.) and to
    /// re-open the budget for returning users after a fresh app release.
    func requestReviewIfEligible(trigger: ReviewTrigger) {
        // Onboarding rating ask is remote-gated (onboardingRatingEnabled).
        // Enforce the kill switch at the presentation choke point too, so no
        // onboarding surface — present or future — can bypass it even if its
        // flow forgets the navigation-level skip. Non-onboarding triggers
        // (streaks, shares, anniversaries) are unaffected.
        if case .onboardingRatingScreen = trigger,
           !RemoteConfig.remoteConfig()["onboardingRatingEnabled"].boolValue {
            return
        }
        // Serialize the throttle check and write on main so two near-simultaneous
        // callers can't both pass the guard and double-log to Analytics.
        DispatchQueue.main.async {
            let currentVersion = Self.currentAppVersion
            let versionChanged = self.lastRequestedRatingVersion != currentVersion
            let elapsedEnough: Bool = {
                guard let last = self.lastReviewRequestSetDate else { return true }
                return Date().timeIntervalSince(last) >= Self.minimumReviewInterval
            }()

            guard versionChanged || elapsedEnough else { return }
            guard let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive })
                as? UIWindowScene else { return }

            SKStoreReviewController.requestReview(in: scene)
            self.lastReviewRequestSetDate = Date()
            self.lastRequestedRatingVersion = currentVersion
            // Route through the dispatcher so PostHog (and any future provider)
            // sees when the native review sheet was actually presented, not just
            // Firebase. Covers every ReviewTrigger via the `trigger` property.
            AnalyticsService.shared.track(Event.leaveReviewShown, parameters: ["trigger": trigger.analyticsKey])
        }
    }

    private static let currentAppVersion: String = APP.Version.stringNumber

    // Spread the (Apple-capped 3/year) review prompts out instead of letting
    // rapid triggers — every 7th swipe, every favorite, each streak milestone —
    // burn all three in the first week, which reads as "asked too much".
    private static let minimumReviewInterval: TimeInterval = 60 * 60 * 24 * 21
}

enum ReviewTrigger {
    case declarationView
    case onboardingRatingScreen
    case streakMilestone(Int)
    case breakthroughCelebration
    case premiumAnniversary(Int)
    case devotionalShared
    case personalDeclarationCreated

    var analyticsKey: String {
        switch self {
        case .declarationView:              return "declaration_view"
        case .onboardingRatingScreen:       return "onboarding_rating_screen"
        case .streakMilestone(let days):    return "streak_milestone_\(days)"
        case .breakthroughCelebration:      return "breakthrough_celebration"
        case .premiumAnniversary(let days): return "premium_anniversary_\(days)"
        case .devotionalShared:             return "devotional_shared"
        case .personalDeclarationCreated:   return "personal_declaration_created"
        }
    }
}

@propertyWrapper
struct AppStorageCodable<T: Codable> {
    let key: String
    let defaultValue: T
    var container: UserDefaults = .standard

    var wrappedValue: T {
        get {
            guard let data = container.data(forKey: key) else {
                return defaultValue
            }
            let decodedValue = try? JSONDecoder().decode(T.self, from: data)
            return decodedValue ?? defaultValue
        }
        set {
            let encodedData = try? JSONEncoder().encode(newValue)
            container.set(encodedData, forKey: key)
        }
    }
}

extension Date: @retroactive RawRepresentable {
    private static let formatter = ISO8601DateFormatter()
    
    public var rawValue: String {
        Date.formatter.string(from: self)
    }
    
    public init?(rawValue: String) {
        self = Date.formatter.date(from: rawValue) ?? Date()
    }
    
    func toPrettyString() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale.current
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        return dateFormatter.string(from: self)
    }
    
    func toSimpleDate() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale.current
        dateFormatter.dateFormat = "MMMM d"
        return dateFormatter.string(from: self)
    }
    
    var isDateToday: Bool {
        let calendar = Calendar.current
        return calendar.isDateInToday(self)
    }
}
