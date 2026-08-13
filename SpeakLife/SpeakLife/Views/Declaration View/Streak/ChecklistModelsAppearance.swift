//
//  ChecklistModelsAppearance.swift
//  SpeakLife
//
//  SwiftUI appearance for the checklist models.
//
//  These `color` properties used to live on the enums themselves in
//  `DailyChecklistModels.swift`, which forced the whole model layer to
//  `import SwiftUI` for two switches. Moved out here so `DailyChecklistModels`
//  stays Foundation-only and can ship in the SpeakLifeCore package.
//

import SwiftUI

extension TaskCategory {
    var color: Color {
        switch self {
        case .foundation: return .blue
        case .growth: return .green
        case .impact: return .orange
        case .mastery: return .purple
        }
    }
}

extension ProgressionPhase {
    var color: Color {
        switch self {
        case .foundation: return .blue
        case .growth: return .green
        case .impact: return .orange
        case .mastery: return .purple
        }
    }
}
