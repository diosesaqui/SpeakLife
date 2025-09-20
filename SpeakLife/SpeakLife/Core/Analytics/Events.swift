//
//  Events.swift
//  SpeakLife
//
//  Created by Riccardo Washington on 2/7/23.
//

import Foundation

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
