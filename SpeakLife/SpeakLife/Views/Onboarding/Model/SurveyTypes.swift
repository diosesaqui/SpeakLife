//
//  SurveyTypes.swift
//  SpeakLife
//
//  Data models for the survey onboarding flow.
//

import Foundation

enum SurveyStep: Int, CaseIterable {
    case intro              = 0
    case heaviestBurden     = 1
    case productPositioning = 2
    case theSeed            = 3
    case burdenDuration     = 4
    case mergedBarriers     = 5   // MERGED: failedAttempts + innerLie
    case interstitialB      = 6
    case declarationExp     = 7
    case goalReveal         = 8
    case personalDeclaration = 9
    case takeAStand         = 10  // auto-advance transition — breath before commitment
    case commitmentHold     = 11
    case paywall            = 12
    case notificationTime   = 13  // post-paywall

    var isQuestion: Bool {
        switch self {
        case .intro, .productPositioning, .theSeed, .interstitialB,
             .goalReveal, .personalDeclaration, .takeAStand, .commitmentHold,
             .paywall, .notificationTime: return false
        default: return true
        }
    }

    var questionIndex: Int? {
        let questions: [SurveyStep] = [
            .heaviestBurden, .burdenDuration, .mergedBarriers, .declarationExp
        ]
        return questions.firstIndex(of: self).map { $0 + 1 }
    }

    static let totalQuestions = 4
}

// What the enemy has stolen — kingdom advancement framing
enum HeaviestBurden: String, CaseIterable, Identifiable {
    var id: String { rawValue }
    case peace      = "My peace"
    case health     = "My health"
    case joy        = "My joy"
    case identity   = "My identity"
    case purpose    = "My purpose"
    case abundance  = "My abundance"
    case allOfIt    = "I'm not in crisis — I just know there's MORE and I refuse to settle"

    var icon: String {
        switch self {
        case .peace:     return "🕊"
        case .health:    return "🌿"
        case .joy:       return "☀️"
        case .identity:  return "👑"
        case .purpose:   return "🧭"
        case .abundance: return "💰"
        case .allOfIt:   return "⚡"
        }
    }

    var description: String {
        switch self {
        case .peace:     return "Anxiety and fear have taken over my mind"
        case .health:    return "My body isn't walking in the healing God promised me"
        case .joy:       return "Life feels empty and I know that's not God's plan"
        case .identity:  return "I've lost sight of who God says I am"
        case .purpose:   return "I'm not walking in the calling placed on my life"
        case .abundance: return "I'm not experiencing the provision God prepared"
        case .allOfIt:   return ""
        }
    }

    var goalWord: SurveyGoalWord {
        switch self {
        case .peace:     return .peace
        case .health:    return .healing
        case .joy:       return .joy
        case .identity:  return .identity
        case .purpose:   return .purpose
        case .abundance: return .prosperity
        case .allOfIt:   return .confidence
        }
    }

    var declarationStyle: DeclarationStyle {
        switch self {
        case .peace:     return .peace
        case .health:    return .healing
        case .joy:       return .peace
        case .identity:  return .identity
        case .purpose:   return .destiny
        case .abundance: return .prosperity
        case .allOfIt:   return .warfare
        }
    }

    var shortLabel: String {
        switch self {
        case .peace:     return "peace"
        case .health:    return "health"
        case .joy:       return "joy"
        case .identity:  return "identity"
        case .purpose:   return "purpose"
        case .abundance: return "abundance"
        case .allOfIt:   return "more"
        }
    }

    var isGrowthTrack: Bool { self == .allOfIt }

    var testimonialGroup: TestimonialGroup {
        switch self {
        case .peace, .health:             return .fearAndHealth
        case .joy, .identity, .purpose:   return .identityAndPurpose
        case .abundance, .allOfIt:        return .defaultGrowth
        }
    }
}

enum TestimonialGroup {
    case fearAndHealth
    case identityAndPurpose
    case defaultGrowth
}

enum BurdenDuration: String, CaseIterable, Identifiable {
    var id: String { rawValue }
    case justStarting = "Just starting out"
    case fewYears     = "A few years in"
    case longTime     = "Walking with Him for a long time"
    case drifted      = "I've drifted and I'm coming back"
}

// Merged barriers screen — best of old Screens 5 + 6
enum BarrierOption: String, CaseIterable, Identifiable {
    var id: String { rawValue }
    case prayer       = "I pray — but the fear and doubt come right back"
    case readBible    = "I read the Bible — but it stays in my head, not my heart"
    case mondayHits   = "Worship and sermons lift me up — then Monday hits and it's gone"
    case mountains    = "\"I see other people's faith move mountains. Mine feels like it barely moves me.\""
    case promises     = "\"I've messed up too much. Part of me wonders if God's promises are really for someone like me.\""
    case cantTrust    = "\"I believe — but not enough to actually trust Him completely.\""
}

enum DeclarationExperience: String, CaseIterable, Identifiable {
    var id: String { rawValue }
    case yesWantMore        = "Yes — something moved when I spoke it. I want to go deeper."
    case heardNotTried      = "I've heard this is powerful but I've never actually tried it."
    case triedInconsistent  = "I've tried a few times — but I couldn't stay consistent."
    case brandNew           = "No — this is brand new to me. Show me how."
}

enum DeclarationStyle: String, CaseIterable, Identifiable {
    var id: String { rawValue }
    case healing     = "Healing & health"
    case warfare     = "Bold & warfare"
    case identity    = "Identity — who God says I am"
    case destiny     = "Destiny & purpose"
    case peace       = "Peace & anxiety"
    case prosperity  = "Prosperity & breakthrough"

    var icon: String {
        switch self {
        case .healing:    return "🌿"
        case .warfare:    return "⚡"
        case .identity:   return "👑"
        case .destiny:    return "🧭"
        case .peace:      return "🕊"
        case .prosperity: return "💰"
        }
    }

    var description: String {
        switch self {
        case .healing:    return "Speak restoration over my body, mind, and emotions"
        case .warfare:    return "Stand firm and fight back with the Word"
        case .identity:   return "Declare who I am in Christ until I fully believe it"
        case .destiny:    return "Call forth my calling and step into it"
        case .peace:      return "Quiet the fear and anchor my mind in truth"
        case .prosperity: return "Open doors, speak abundance, and receive favor"
        }
    }

    // Sword-selection framing (Screen 4)
    var swordLabel: String {
        switch self {
        case .peace:      return "Gentle & restoring"
        case .warfare:    return "Bold & warfare"
        case .healing:    return "Healing-focused"
        case .identity:   return "Identity-anchored"
        case .destiny:    return "Calling-forward"
        case .prosperity: return "All of it"
        }
    }

    var swordScripture: String {
        switch self {
        case .peace:      return "\"Be still and know that I am God.\""
        case .warfare:    return "\"It is written — the enemy must flee.\""
        case .healing:    return "\"By His stripes, I am healed.\""
        case .identity:   return "\"I am who God says I am.\""
        case .destiny:    return "\"I step into what He prepared for me.\""
        case .prosperity: return "I'm taking ground in every direction."
        }
    }

    var swordIcon: String {
        switch self {
        case .peace:      return "🕊"
        case .warfare:    return "⚔️"
        case .healing:    return "💚"
        case .identity:   return "👑"
        case .destiny:    return "🧭"
        case .prosperity: return "✨"
        }
    }

    var goalWord: SurveyGoalWord {
        switch self {
        case .healing:    return .healing
        case .warfare:    return .confidence
        case .identity:   return .identity
        case .destiny:    return .purpose
        case .peace:      return .peace
        case .prosperity: return .prosperity
        }
    }

    var communityCount: String {
        switch self {
        case .healing:    return "41,278"
        case .peace:      return "38,322"
        case .identity:   return "34,902"
        case .destiny:    return "29,023"
        case .warfare:    return "24,290"
        case .prosperity: return "21,790"
        }
    }

    var barFraction: Double {
        switch self {
        case .healing:    return 0.82
        case .peace:      return 0.76
        case .identity:   return 0.68
        case .destiny:    return 0.58
        case .warfare:    return 0.48
        case .prosperity: return 0.42
        }
    }

    var percentLabel: String {
        switch self {
        case .healing:    return "41%"
        case .peace:      return "38%"
        case .identity:   return "34%"
        case .destiny:    return "29%"
        case .warfare:    return "24%"
        case .prosperity: return "21%"
        }
    }

    var chartLabel: String {
        switch self {
        case .identity:   return "Identity"
        case .prosperity: return "Prosperity"
        default:          return rawValue
        }
    }
}

enum NotificationTime: String, CaseIterable, Identifiable {
    var id: String { rawValue }
    case morning = "Morning (6-9am) — start my day in truth before the world gets loud"
    case midday  = "Midday (12-2pm) — when the pressure and stress hits hardest"
    case evening = "Evening (7-9pm) — quiet my mind and reset before bed"
    case allDay  = "All day — I need constant anchoring right now"

    var startTimeIndex: Int {
        switch self {
        case .morning: return 12
        case .midday:  return 24
        case .evening: return 38
        case .allDay:  return 12
        }
    }
}

enum SurveyGoalWord: String, CaseIterable, Identifiable {
    var id: String { rawValue }
    case peace      = "PEACE"
    case identity   = "IDENTITY"
    case purpose    = "PURPOSE"
    case joy        = "JOY"
    case confidence = "CONFIDENCE"
    case healing    = "HEALING"
    case prosperity = "PROSPERITY"

    var tagline: String {
        switch self {
        case .peace:      return "Anxiety has had enough of you."
        case .identity:   return "It's time to know who God says you are."
        case .purpose:    return "Your calling is waiting to be walked into."
        case .joy:        return "Not happiness — deep, unshakeable joy."
        case .confidence: return "Step boldly into who you were made to be."
        case .healing:    return "What broke — God restores."
        case .prosperity: return "Walk in overflow. God's blessing is your portion."
        }
    }

    var icon: String {
        switch self {
        case .peace:      return "dove.fill"
        case .identity:   return "sparkles"
        case .purpose:    return "flame.fill"
        case .joy:        return "sun.max.fill"
        case .confidence: return "bolt.fill"
        case .healing:    return "leaf.fill"
        case .prosperity: return "star.fill"
        }
    }

    var challengeName: String {
        switch self {
        case .peace:      return "30-Day Peace Possession"
        case .identity:   return "30-Day Identity Possession"
        case .purpose:    return "30-Day Purpose Possession"
        case .joy:        return "30-Day Joy Possession"
        case .confidence: return "30-Day Confidence Possession"
        case .healing:    return "30-Day Healing Possession"
        case .prosperity: return "30-Day Abundance Possession"
        }
    }

    var styleLabel: String {
        switch self {
        case .peace:      return "Peace"
        case .identity:   return "Identity"
        case .purpose:    return "Purpose"
        case .joy:        return "Joy"
        case .confidence: return "Confidence"
        case .healing:    return "Healing"
        case .prosperity: return "Abundance"
        }
    }

    var declarationCategory: DeclarationCategory {
        switch self {
        case .peace:      return .anxiety
        case .identity:   return .identity
        case .purpose:    return .faith
        case .joy:        return .joy
        case .confidence: return .confidence
        case .healing:    return .health
        case .prosperity: return .wealth
        }
    }

    var notificationCategories: Set<DeclarationCategory> {
        switch self {
        case .peace:      return [.anxiety, .faith, .rest, .grace]
        case .identity:   return [.identity, .grace, .confidence, .faith]
        case .purpose:    return [.destiny, .faith, .confidence, .wisdom]
        case .joy:        return [.joy, .gratitude, .praise, .faith]
        case .confidence: return [.confidence, .identity, .faith, .wisdom]
        case .healing:    return [.health, .faith, .grace, .rest]
        case .prosperity: return [.wealth, .faith, .favor, .work]
        }
    }
}

class SurveyResponses: ObservableObject {
    @Published var heaviestBurden: HeaviestBurden? = nil
    @Published var burdenDuration: BurdenDuration? = nil
    @Published var barriers: Set<BarrierOption> = []
    @Published var declarationExperience: DeclarationExperience? = nil
    @Published var notificationTime: NotificationTime? = nil

    var resolvedGoalWord: SurveyGoalWord {
        heaviestBurden?.goalWord ?? .peace
    }

    var primaryDeclarationStyle: DeclarationStyle? {
        heaviestBurden?.declarationStyle
    }

    var burdenShortLabel: String {
        heaviestBurden?.shortLabel ?? "your inheritance"
    }

    var durationLabel: String {
        burdenDuration?.rawValue.lowercased() ?? "a long time"
    }
}
