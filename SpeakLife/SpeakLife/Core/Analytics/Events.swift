//
//  Events.swift
//  SpeakLife
//
//  Created by Riccardo Washington on 2/7/23.
//

import Foundation
import TikTokBusinessSDK

struct Event {
    
    // MARK: - Standardized Event Names (snake_case)
    static let categoryChooserTapped = "category_chooser_tapped"
    static let tryPremiumAbandoned = "try_premium_abandoned"
    static let addYourOwnAbandoned = "add_your_own_abandoned"
    static let remindersCategoriesTapped = "reminders_categories_tapped"
    static let favoriteTapped = "favorite_tapped"
    static let speechTapped = "speech_tapped"
    static let onboardingFinished = "onboarding_finished"  // Fixed: was onBoardingFinished
    static let onboardingStepViewed = "onboarding_step_viewed"  // cross-arm step funnel; see OnboardingFunnel
    static let shareTapped = "share_tapped"
    static let remindersTapped = "reminders_tapped"
    static let powerDeclarationsTapped = "power_declarations_tapped"
    static let freshInstall = "fresh_install"
    static let addYourOwnSaved = "add_your_own_saved"
    static let tryPremiumTapped = "try_premium_tapped"
    static let profileTapped = "profile_tapped"
    static let shareSpeakLifeTapped = "share_speak_life_tapped"
    static let addYourOwnAffirmation = "add_your_own_affirmation"  // Fixed: was add_your_own_affirmation
    static let createYourOwnTapped = "create_your_own_tapped"
    static let themeChangerTapped = "theme_changer_tapped"
    static let sessionStarted = "session_started"  // Fixed: was SessionStarted
    static let swipeAffirmation = "swipe_affirmation"  // Fixed: was swipe_affirmation
    static let manageSubscriptionTapped = "manage_subscription_tapped"
    static let premiumSucceeded = "premium_succeeded"  // Fixed typo: was premiumSucceded
    static let devotionalTapped = "devotional_tapped"
    static let loveLetterTapped = "love_letter_tapped"
    static let devotionalShared = "devotional_shared"
    static let ninetyOnePsalmTapped = "ninety_one_psalm_tapped"
    static let leaveReviewShown = "leave_review_shown"
    
    static let tabNavigated = "tab_navigated"
    static let audioPlayerOpened = "audio_player_opened"
    static let audioPlayerClosed = "audio_player_closed"
    static let streakViewed = "streak_viewed"
    static let streakCompleted = "streak_completed"
    static let badgeUnlocked = "badge_unlocked"
    static let settingsViewed = "settings_viewed"
    static let widgetConfigured = "widget_configured"
    
    // Bible Events
    static let bibleTabOpened = "bible_tab_opened"
    static let bibleBookSelected = "bible_book_selected"
    static let bibleChapterViewed = "bible_chapter_viewed"
    static let bibleVerseBookmarked = "bible_verse_bookmarked"
    static let bibleVerseHighlighted = "bible_verse_highlighted"
    static let bibleVerseShared = "bible_verse_shared"
    static let bibleSearchPerformed = "bible_search_performed"
    static let bibleVersionChanged = "bible_version_changed"
    static let notificationScheduled = "notification_scheduled"
    static let quizStarted = "quiz_started"
    static let quizCompleted = "quiz_completed"
    static let testimonyViewed = "testimony_viewed"
    static let bootcampViewed = "bootcamp_viewed"
    static let trackerViewed = "tracker_viewed"
    
    // MARK: - Audio Favorites Events
    static let audioFavoriteTapped = "audio_favorite_tapped"
    static let audioUnfavoriteTapped = "audio_unfavorite_tapped"
    static let favoriteAudioPlayed = "favorite_audio_played"
    static let favoritesCategoryViewed = "favorites_category_viewed"
    static let favoriteAudioShared = "favorite_audio_shared"
    static let favoriteAudioRemoved = "favorite_audio_removed"
    static let favoritesCleared = "favorites_cleared"
    static let favoritesSorted = "favorites_sorted"
    static let favoritesSearched = "favorites_searched"
    static let favoriteAudioReplayStarted = "favorite_audio_replay_started"
    static let favoriteFromPlayer = "favorite_from_player"
    static let unfavoriteFromPlayer = "unfavorite_from_player"
}

// MARK: - Screen Tracking Helpers
extension Event {
    
    static func trackScreen(_ screenName: String, metadata: [String: Any] = [:]) {
        AnalyticsService.shared.trackScreenView(screenName, metadata: metadata)
    }
    
    static func trackUserAction(_ action: String, category: String? = nil, metadata: [String: Any] = [:]) {
        AnalyticsService.shared.trackUserAction(action, category: category, metadata: metadata)
    }
    
    static func trackContent(type: String, id: String, action: String, metadata: [String: Any] = [:]) {
        AnalyticsService.shared.trackContentInteraction(
            contentType: type,
            contentId: id,
            action: action,
            metadata: metadata
        )
    }
}

// MARK: - TikTok Analytics Helper
extension Event {
    
    // Track key SpeakLife events for TikTok
    static func trackTikTokAppInstall() {
        // InstallApp is auto-tracked by SDK, but we can manually track it too
        TikTokBusiness.trackTTEvent(.init(eventName:"LaunchAPP"))
        AnalyticsService.shared.track("tiktok_app_install")
    }
    
    static func trackTikTokAppLaunch() {
        TikTokBusiness.trackTTEvent(.init(eventName: "LAUNCHAPP"))
        AnalyticsService.shared.track("tiktok_app_launch")
    }
    
    static func trackTikTokPremiumPurchase(value: Double, currency: String = "USD") {
        // Track TikTok purchase with revenue
        let ttEvent = TikTokBaseEvent(eventName: "Purchase")
        ttEvent.addProperty(withKey: "value", value: value)
        ttEvent.addProperty(withKey: "currency", value: currency)
        TikTokBusiness.trackTTEvent(ttEvent)
        
        // Also log to Firebase with revenue
        AnalyticsService.shared.track("tiktok_purchase", parameters: [
            "value": value,
            "currency": currency
        ])
    }
    
    static func trackTikTokContentView(contentType: String, contentId: String) {
        TikTokBusiness.trackTTEvent(.init(eventName:"ViewContent"))
        AnalyticsService.shared.track("tiktok_view_content", parameters: [
            "content_type": contentType,
            "content_id": contentId
        ])
    }
    
    static func trackTikTokShare(contentType: String) {
        TikTokBusiness.trackTTEvent(.init(eventName:"Share"))
        AnalyticsService.shared.track("tiktok_share", parameters: [
            "content_type": contentType
        ])
    }
    
    static func trackTikTokEngagement(action: String, category: String? = nil) {
        TikTokBusiness.trackTTEvent(.init(eventName:"UserEngagement"))
        var params: [String: Any] = ["action": action]
        if let category = category {
            params["category"] = category
        }
        AnalyticsService.shared.track("tiktok_engagement", parameters: params)
    }
    
    // MARK: - Bible Events
    static func trackBookmark(_ action: String, metadata: [String: Any]? = nil) {
        var params: [String: Any] = ["action": action]
        if let metadata = metadata {
            params.merge(metadata) { _, new in new }
        }
        AnalyticsService.shared.track(bibleVerseBookmarked, parameters: params)
    }
    
    static func trackHighlight(_ action: String, metadata: [String: Any]? = nil) {
        var params: [String: Any] = ["action": action]
        if let metadata = metadata {
            params.merge(metadata) { _, new in new }
        }
        AnalyticsService.shared.track(bibleVerseHighlighted, parameters: params)
    }
}

// MARK: - Unified onboarding step funnel
//
// Lives here rather than in its own file because the app target's sources are
// listed in project.pbxproj by hand (no synchronized folder), and a new file
// that is not added there compiles in nobody's build but the author's.

/// The stage a screen occupies in ANY onboarding arm, so arms with different
/// screens can be read as the same onboarding with different content.
///
/// Every arm used to report progress only through its own
/// `<flow>_step_completed` with an integer `step`, and step 7 of `product` has
/// nothing to do with step 7 of `closer`. The integers could never be pooled,
/// so there was no way to ask "which arm loses people before they personalize"
/// without a per-arm decoder. The stage is that decoder, carried on the event.
///
/// Stages are contiguous within an arm by construction: once an arm has entered
/// a stage it never shows a screen from an earlier one. That is what keeps a
/// stage funnel ordered, and why an interstitial sitting INSIDE the question
/// block (the quiz insight, the quiz arm's mirror, warfare's burden payoff,
/// direct's mechanism) is `personalize` rather than `value`: calling it value
/// would put value ahead of the questions that follow it. `OnboardingAngleTests`
/// holds every driver to this.
///
/// - `hook`: before the user tells us anything that shapes their plan. Includes
///   rhetorical agreement questions (closer's yes/no ladder), whose answers
///   neither branch the flow nor seed anything.
/// - `personalize`: from the first answer that segments or seeds (a picker, the
///   quiz arm's segment question, direct's free-text declaration) through the
///   last question.
/// - `value`: after the questions, before the ask. First declaration, rating,
///   plan loader, plan reveal, pledge, testimonials.
/// - `paywall`: the onboarding paywall.
/// - `setup`: everything after the paywall.
enum OnboardingStage: String, CaseIterable {
    case hook
    case personalize
    case value
    case paywall
    case setup

    /// Sort key for `stage_index`, so a PostHog breakdown by stage orders by
    /// funnel position instead of alphabetically.
    var index: Int {
        switch self {
        case .hook:        return 0
        case .personalize: return 1
        case .value:       return 2
        case .paywall:     return 3
        case .setup:       return 4
        }
    }
}

/// A driver's step type, mapped into the unified funnel. Conformances sit next
/// to each step enum as exhaustive switches, so a new step does not compile
/// until someone decides which stage it belongs to.
protocol OnboardingFunnelStep {
    /// Stable snake_case screen name. A screen shared between arms carries the
    /// same name in every arm (`paywall`, `notification_time`, `testimonials`,
    /// `plan_reveal`, the extended-quiz questions), so it can be compared across
    /// arms by name as well as by stage.
    var funnelStepName: String { get }
    var funnelStage: OnboardingStage { get }
}

enum OnboardingFunnel {
    /// Fire once each time a step becomes the VISIBLE step. Steps a driver jumps
    /// over (the retired personal declaration ask, a remote-disabled rating or
    /// pledge, quiz v1's belief question) are never displayed and must never be
    /// logged, or the funnel shows people "reaching" screens nobody saw.
    ///
    /// Callers suppress this during a debug replay, the way HomeView suppresses
    /// `onboarding_started` / `onboarding_finished`: a tester walking an arm is
    /// not a real user moving through it.
    ///
    /// - Parameters:
    ///   - variant: `subscriptionStore.onboardingVariantName`, the value
    ///     `onboarding_started` carries. Not the per-arm `flow` slug.
    ///   - stepIndex: the integer the driver reports as `step` on its per-arm
    ///     event, so the two join.
    ///   - flowSchema: the driver's `flow_schema`, or nil for a driver without one.
    static func stepViewed(
        variant: String,
        stepName: String,
        stepIndex: Int,
        stage: OnboardingStage,
        flowSchema: Int?,
        storm: String? = nil
    ) {
        var parameters: [String: Any] = [
            "variant": variant,
            "step_name": stepName,
            "step_index": stepIndex,
            "stage": stage.rawValue,
            "stage_index": stage.index
        ]
        if let flowSchema { parameters["flow_schema"] = flowSchema }
        // The storm arm's picked storm, once known. Nil on every other arm.
        if let storm { parameters["storm"] = storm }
        AnalyticsService.shared.track(Event.onboardingStepViewed, parameters: parameters)
    }
}
