//
//  StreakShareRenderArgs.swift
//  SpeakLifeServices
//
//  A Foundation-typed value the app-side renderer accepts, so
//  `EnhancedStreakViewModel` can install a share-image renderer without
//  the package importing UIKit.
//
//  The app registers its renderer at startup:
//      EnhancedStreakViewModel.shareImageRenderer = { StreakShareCardRenderer.render($0) }
//  Tests leave it nil and `CompletionCelebration.shareImage` comes back nil,
//  which the share sheet already handles.
//

import Foundation

public struct StreakShareRenderArgs {
    public let currentStreak: Int
    public let milestone: String
    public let motivationalMessage: String

    public init(currentStreak: Int, milestone: String, motivationalMessage: String) {
        self.currentStreak = currentStreak
        self.milestone = milestone
        self.motivationalMessage = motivationalMessage
    }
}
