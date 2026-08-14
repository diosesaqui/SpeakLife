//
//  StrengthLevelAppearance.swift
//  SpeakLife
//
//  SwiftUI appearance for `BurstCompletionTracker.StrengthLevel`.
//
//  The `color` property used to live on the nested enum inside
//  `BurstCompletionModel.swift`, which forced the whole tracker to
//  `import SwiftUI` for one switch. Moved out here so the model file only
//  needs Foundation + Combine and can ship in the SpeakLifeCore package.
//

import SwiftUI

extension BurstCompletionTracker.StrengthLevel {
    var color: Color {
        switch self {
        case .warrior: return .blue
        case .champion: return .green
        case .conqueror: return .orange
        case .victorious: return .purple
        case .unstoppable: return .yellow
        }
    }
}
