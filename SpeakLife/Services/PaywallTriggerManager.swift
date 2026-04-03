//
//  PaywallTriggerManager.swift
//  SpeakLife
//
//  Manages paywall trigger logic based on user behavior
//

import Foundation
import SwiftUI

final class PaywallTriggerManager: ObservableObject {
    static let shared = PaywallTriggerManager()
    
    @Published var shouldShowPaywall = false
    @Published var triggerReason: PaywallTriggerReason = .none
    
    // Session tracking
    private var sessionStartTime = Date()
    private var categoryChangesInSession = 0
    private var favoritesAddedInSession = 0
    
    // Persistent storage keys
    @AppStorage("firstLaunchDate") private var firstLaunchDate: Double = Date().timeIntervalSince1970
    @AppStorage("hasShownDay2Paywall") private var hasShownDay2Paywall = false
    @AppStorage("hasShownDay3Paywall") private var hasShownDay3Paywall = false
    @AppStorage("lastPaywallShownDate") private var lastPaywallShownDate: Double = 0
    
    private init() {
        resetSessionTracking()
    }
    
    enum PaywallTriggerReason: String {
        case none = "none"
        case categoryChange = "category_change_twice"
        case favoritesSaved = "favorites_saved"
        case audioCompletion = "audio_4min_completion"
        case day2FirstOpen = "day2_first_open"
        case day3FirstOpen = "day3_first_open"
    }
    
    // MARK: - Public Methods
    
    func resetSessionTracking() {
        sessionStartTime = Date()
        categoryChangesInSession = 0
        favoritesAddedInSession = 0
    }
    
    func trackCategoryChange() {
        categoryChangesInSession += 1
        
        if categoryChangesInSession == 2 && !hasRecentlyShownPaywall() {
            triggerPaywall(reason: .categoryChange)
        }
    }
    
    func trackFavoriteSaved() {
        favoritesAddedInSession += 1
        
        if favoritesAddedInSession > 2 && !hasRecentlyShownPaywall() {
            triggerPaywall(reason: .favoritesSaved)
        }
    }
    
    func trackAudioCompletion(durationInSeconds: Double) {
        // Check if audio was at least 4 minutes (240 seconds)
        if durationInSeconds >= 240 && !hasRecentlyShownPaywall() {
            triggerPaywall(reason: .audioCompletion)
        }
    }
    
    func checkDayBasedTriggers() {
        let now = Date()
        let firstLaunch = Date(timeIntervalSince1970: firstLaunchDate)
        let daysSinceFirstLaunch = Calendar.current.dateComponents([.day], from: firstLaunch, to: now).day ?? 0
        
        // Day 2 trigger
        if daysSinceFirstLaunch == 1 && !hasShownDay2Paywall && !hasRecentlyShownPaywall() {
            hasShownDay2Paywall = true
            triggerPaywall(reason: .day2FirstOpen)
        }
        // Day 3 trigger
        else if daysSinceFirstLaunch == 2 && !hasShownDay3Paywall && !hasRecentlyShownPaywall() {
            hasShownDay3Paywall = true
            triggerPaywall(reason: .day3FirstOpen)
        }
    }
    
    func dismissPaywall() {
        shouldShowPaywall = false
        triggerReason = .none
    }
    
    // MARK: - Private Methods
    
    private func triggerPaywall(reason: PaywallTriggerReason) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.triggerReason = reason
            self.shouldShowPaywall = true
            self.lastPaywallShownDate = Date().timeIntervalSince1970
            
            // Track the trigger event
            AnalyticsService.shared.trackUserAction(
                "paywall_triggered",
                category: "monetization",
                metadata: [
                    "trigger_reason": reason.rawValue,
                    "session_duration": Date().timeIntervalSince(self.sessionStartTime),
                    "category_changes": self.categoryChangesInSession,
                    "favorites_added": self.favoritesAddedInSession
                ]
            )
        }
    }
    
    private func hasRecentlyShownPaywall() -> Bool {
        let lastShown = Date(timeIntervalSince1970: lastPaywallShownDate)
        let hoursSinceLastShown = Date().timeIntervalSince(lastShown) / 3600
        
        // Don't show paywall if one was shown in the last 4 hours
        return hoursSinceLastShown < 4
    }
}