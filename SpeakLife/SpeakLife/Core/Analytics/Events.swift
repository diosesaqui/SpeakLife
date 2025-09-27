//
//  Events.swift
//  SpeakLife
//
//  Created by Riccardo Washington on 2/7/23.
//

import Foundation
import FirebaseAnalytics
import TikTokBusinessSDK

struct Event {
    
    static let categoryChooserTapped = "category_chooser_tapped"
    static let tryPremiumAbandoned = "try_premium_abandoned"
    static let addYourOwnAbandoned = "add_your_own_abandoned"
    static let reminders_categoriesTapped = "reminders_categories_tapped"
    static let favoriteTapped = "favorite_tapped"
    static let speechTapped = "speech_tapped"
    static let onBoardingFinished = "onboarding_finished"
    static let shareTapped = "share_tapped"
    static let remindersTapped = "reminders_tapped"
    static let powerDeclarationsTapped = "power_declarations_tapped"
    static let freshInstall = "fresh_install"
    static let addYourOwnSaved = "add_your_own_saved"
    static let tryPremiumTapped = "try_premium_tapped"
    static let profileTapped = "profile_tapped"
    static let shareSpeakLifeTapped = "share_speak_life_tapped"
    static let add_your_own_affirmation = "add_your_own_affirmation"
    static let createYourOwnTapped = "create_your_own_tapped"
    static let themeChangerTapped = "theme_changer_tapped"
    static let SessionStarted = "session_started"
    static let swipe_affirmation = "swipe_affirmation"
    static let manageSubscriptionTapped = "manage_subscription_tapped"
    static let premiumSucceded = "premium_succeeded"
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
        Analytics.logEvent("tiktok_app_install", parameters: nil)
    }
    
    static func trackTikTokAppLaunch() {
        TikTokBusiness.trackTTEvent(.init(eventName: "LAUNCHAPP"))
        Analytics.logEvent("tiktok_app_launch", parameters: nil)
    }
    
    static func trackTikTokPremiumPurchase(value: Double, currency: String = "USD") {
        TikTokBusiness.trackTTEvent(.init(eventName:"Purchase"))
        Analytics.logEvent("tiktok_purchase", parameters: [
            "value": value,
            "currency": currency
        ])
    }
    
    static func trackTikTokContentView(contentType: String, contentId: String) {
        TikTokBusiness.trackTTEvent(.init(eventName:"ViewContent"))
        Analytics.logEvent("tiktok_view_content", parameters: [
            "content_type": contentType,
            "content_id": contentId
        ])
    }
    
    static func trackTikTokShare(contentType: String) {
        TikTokBusiness.trackTTEvent(.init(eventName:"Share"))
        Analytics.logEvent("tiktok_share", parameters: [
            "content_type": contentType
        ])
    }
    
    static func trackTikTokEngagement(action: String, category: String? = nil) {
        TikTokBusiness.trackTTEvent(.init(eventName:"UserEngagement"))
        var params: [String: Any] = ["action": action]
        if let category = category {
            params["category"] = category
        }
        Analytics.logEvent("tiktok_engagement", parameters: params)
    }
}
