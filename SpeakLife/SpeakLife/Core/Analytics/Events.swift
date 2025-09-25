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
    static let categoryChooserTapped = "categoryChooserTapped"
    static let tryPremiumAbandoned = "tryPremiumAbandoned"
    static let addYourOwnAbandoned = "addYourOwnAbandoned"
    static let reminders_categoriesTapped = "reminders_categoriesTapped"
    static let favoriteTapped = "favoriteTapped"
    static let speechTapped = "speechTapped"
    static let onBoardingFinished = "onBoardingFinished"
    static let shareTapped = "shareTapped"
    static let remindersTapped = "remindersTapped"
    static let powerDeclarationsTapped = "powerDeclarationsTapped"
    static let freshInstall = "freshInstall"
    static let addYourOwnSaved = "addYourOwnSaved"
    static let tryPremiumTapped = "tryPremiumTapped"
    static let profileTapped = "profileTapped"
    static let shareSpeakLifeTapped = "shareSpeakLifeTapped"
    static let add_your_own_affirmation = "add_your_own_affirmation"
    static let createYourOwnTapped = "createYourOwnTapped"
    static let themeChangerTapped = "themeChangerTapped"
    static let SessionStarted = "SessionStarted"
    static let swipe_affirmation = "swipe_affirmation"
    static let manageSubscriptionTapped = "manageSubscriptionTapped"
    static let premiumSucceded = "premiumSucceded"
    static let devotionalTapped = "devotionalTapped"
    static let loveLetterTapped = "loveLetterTapped"
    static let devotionalShared = "devotionalShared"
    static let ninetyOnePsalmTapped = "ninetyOnePsalmTapped"
    static let leaveReviewShown = "leaveReviewShown"
    
    // MARK: - Audio Favorites Events
    static let audioFavoriteTapped = "audioFavoriteTapped"
    static let audioUnfavoriteTapped = "audioUnfavoriteTapped"
    static let favoriteAudioPlayed = "favoriteAudioPlayed"
    static let favoritesCategoryViewed = "favoritesCategoryViewed"
    static let favoriteAudioShared = "favoriteAudioShared"
    static let favoriteAudioRemoved = "favoriteAudioRemoved"
    static let favoritesCleared = "favoritesCleared"
    static let favoritesSorted = "favoritesSorted"
    static let favoritesSearched = "favoritesSearched"
    static let favoriteAudioReplayStarted = "favoriteAudioReplayStarted"
    static let favoriteFromPlayer = "favoriteFromPlayer"
    static let unfavoriteFromPlayer = "unfavoriteFromPlayer"
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
