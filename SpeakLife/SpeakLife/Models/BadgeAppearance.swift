//
//  BadgeAppearance.swift
//  SpeakLife
//
//  SwiftUI Color extensions on `BadgeType` and `BadgeRarity`. These
//  used to live in `BadgeModel.swift`, which forced the whole file
//  (including the plain Foundation `Badge` value type and
//  `BadgeManager`) to `import SwiftUI`. Split out here so BadgeModel
//  ships in the Foundation-only SpeakLifeServices package, matching
//  the `ChecklistModelsAppearance.swift` / `ProgressionPhase+Appearance.swift`
//  pattern.
//

import SwiftUI
import SpeakLifeServices

extension BadgeType {
    var primaryColor: Color {
        switch self {
        case .streak: return .orange
        case .consistency: return .blue
        case .spiritual: return .purple
        case .social: return .green
        case .milestone: return .yellow
        case .enforcement: return .indigo
        case .guarding: return .teal
        }
    }

    var secondaryColor: Color {
        switch self {
        case .streak: return .red
        case .consistency: return .cyan
        case .spiritual: return .pink
        case .social: return .mint
        case .milestone: return .orange
        case .enforcement: return .purple
        case .guarding: return .cyan
        }
    }
}

extension BadgeRarity {
    /// Refined metallic palette per tier: [highlight, base, shadow].
    /// One restrained metal per rarity — no per-type rainbow — so badges read
    /// as minted medals rather than candy. Drives the rim and emblem gradients.
    var metalGradient: [Color] {
        switch self {
        case .common: // Bronze
            return [
                Color(red: 0.85, green: 0.62, blue: 0.40),
                Color(red: 0.60, green: 0.40, blue: 0.24),
                Color(red: 0.36, green: 0.23, blue: 0.13)
            ]
        case .rare: // Silver
            return [
                Color(red: 0.96, green: 0.97, blue: 0.99),
                Color(red: 0.72, green: 0.75, blue: 0.80),
                Color(red: 0.42, green: 0.45, blue: 0.50)
            ]
        case .epic: // Gold
            return [
                Color(red: 1.00, green: 0.90, blue: 0.56),
                Color(red: 0.92, green: 0.72, blue: 0.27),
                Color(red: 0.56, green: 0.40, blue: 0.09)
            ]
        case .legendary: // Platinum / iridescent
            return [
                Color(red: 0.93, green: 0.91, blue: 1.00),
                Color(red: 0.66, green: 0.62, blue: 0.88),
                Color(red: 0.38, green: 0.34, blue: 0.60)
            ]
        }
    }

    var metalHighlight: Color { metalGradient[0] }
    var metalBase: Color { metalGradient[1] }
    var metalShadow: Color { metalGradient[2] }

    /// Single representative tone for text labels and small indicators.
    var ringColor: Color { metalBase }
}
