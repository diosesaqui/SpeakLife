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
    case productPositioning = 2   // NEW: treasure chest — "take what's yours"
    case burdenDuration     = 3
    case interstitialA      = 4
    case failedAttempts     = 5
    case innerLie           = 6
    case interstitialB      = 7
    case declarationExp     = 8
    case futurePacing       = 9
    case readiness          = 10
    case declarationStyle   = 11  // NEW: style preference
    case styleProof         = 12  // NEW: social proof chart
    case goalReveal         = 13
    case personalDeclaration = 14
    case commitmentHold     = 15  // NEW: tap-and-hold
    case paywall            = 16
    case notificationTime   = 17  // MOVED: post-paywall

    var isQuestion: Bool {
        switch self {
        case .intro, .productPositioning, .interstitialA, .interstitialB,
             .styleProof, .goalReveal, .personalDeclaration, .commitmentHold,
             .paywall, .notificationTime: return false
        default: return true
        }
    }

    var questionIndex: Int? {
        let questions: [SurveyStep] = [
            .heaviestBurden, .burdenDuration, .failedAttempts,
            .innerLie, .declarationExp, .futurePacing,
            .readiness, .declarationStyle
        ]
        return questions.firstIndex(of: self).map { $0 + 1 }
    }

    static let totalQuestions = 8
}

// What the enemy has stolen — kingdom advancement framing
enum HeaviestBurden: String, CaseIterable, Identifiable {
    var id: String { rawValue }
    case peace      = "My peace — anxiety and fear have taken over my mind"
    case health     = "My health — my body isn't walking in the healing God promised me"
    case joy        = "My joy — life feels empty and I know that's not God's plan"
    case identity   = "My identity — I've lost sight of who God says I am"
    case purpose    = "My purpose — I'm not walking in the calling placed on my life"
    case abundance  = "My abundance — I'm not experiencing the provision God prepared"
    case thriving   = "I'm not in crisis — I just know there's MORE and I refuse to settle"

    var goalWord: SurveyGoalWord {
        switch self {
        case .peace:     return .peace
        case .health:    return .healing
        case .joy:       return .joy
        case .identity:  return .identity
        case .purpose:   return .purpose
        case .abundance: return .prosperity
        case .thriving:  return .confidence
        }
    }

    var shortLabel: String {
        switch self {
        case .peace:     return "your peace"
        case .health:    return "your health"
        case .joy:       return "your joy"
        case .identity:  return "your identity"
        case .purpose:   return "your purpose"
        case .abundance: return "your abundance"
        case .thriving:  return "your next level"
        }
    }

    var isGrowthTrack: Bool {
        self == .thriving
    }

    // Testimonial bucket for interstitial A
    var testimonialGroup: TestimonialGroup {
        switch self {
        case .peace, .health:             return .fearAndHealth
        case .identity, .joy, .purpose:   return .identityAndPurpose
        case .abundance, .thriving:       return .defaultGrowth
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
    case newlyStarted      = "This is new — just started exploring faith"
    case fewMonths         = "A few months — finding my footing"
    case overAYear         = "Over a year — I know God but want to go deeper"
    case mostOfMyLife      = "Most of my adult life — but something feels missing"
    case asLongAsRemember  = "As long as I can remember — ready to go to the next level"
}

enum PreviousAttempt: String, CaseIterable, Identifiable {
    var id: String { rawValue }
    case prayer                = "I pray — but the fear and doubt come right back"
    case readBible             = "I read the Bible — but it stays in my head, not my heart"
    case prayedNoBreakthrough  = "I've believed and stood in faith — but I'm still waiting"
    case worship               = "Worship and sermons lift me up — then Monday hits and it's gone"
    case people                = "I've talked to people I trust — it helps for a moment, then fades"
    case noStart               = "Honestly, I don't know where to start — I've never had a real practice"
}

enum InnerLie: String, CaseIterable, Identifiable {
    var id: String { rawValue }
    // Pain-track
    case failure      = "\"I can't do this. I'm going to fail.\""
    case notEnough    = "\"I'm not enough — I'll never be enough.\""
    case noChange     = "\"Nothing in my life is ever really going to change.\""
    case godFar       = "\"God feels far away. I don't feel heard.\""
    case lostIdentity = "\"I don't even know who I am anymore.\""
    case tired        = "\"I'm so tired of fighting. I just want peace.\""
    // Faith-track
    case faithWeak    = "\"My faith is too weak. I keep doubting.\""
    case godSilent    = "\"I pray, but God feels silent. I wonder if He hears me.\""
    case faithNotReal = "\"I see other people's faith move mountains. Mine feels like it barely moves me.\""
    case tooSinful    = "\"I've messed up too much. Part of me wonders if God's promises are really for someone like me.\""
    case faithSmall   = "\"I believe — but not enough to actually trust Him completely.\""
    // Growth-track
    case wantSpeakConfidence  = "Speaking God's word with real confidence and conviction"
    case wantTrustMore        = "Trusting God with the things I'm still waiting on"
    case wantUnshakeableFaith = "Building faith that doesn't waver when things get hard"
    case wantPurpose          = "Walking clearly in my God-given purpose"
    case wantPrayerLife       = "A deeper, more consistent prayer and declaration life"

    static var painOptions: [InnerLie] {
        [.failure, .notEnough, .noChange, .godFar, .lostIdentity, .tired]
    }
    static var faithOptions: [InnerLie] {
        [.faithWeak, .godSilent, .faithNotReal, .tooSinful, .faithSmall]
    }
    static var growthOptions: [InnerLie] {
        [.wantSpeakConfidence, .wantTrustMore, .wantUnshakeableFaith, .wantPurpose, .wantPrayerLife]
    }
}

enum DeclarationExperience: String, CaseIterable, Identifiable {
    var id: String { rawValue }
    case yesWantMore        = "Yes — something moved when I spoke it. I want to go deeper."
    case heardNotTried      = "I've heard this is powerful but I've never actually tried it."
    case triedInconsistent  = "I've tried a few times — but I couldn't stay consistent."
    case brandNew           = "No — this is brand new to me. Show me how."
}

// Inheritance possession options — Screen 9
enum FutureChange: String, CaseIterable, Identifiable {
    var id: String { rawValue }
    case healing    = "\"My healing — I take my body back in Jesus' name\""
    case peace      = "\"My peace — fear doesn't get to live in my mind anymore\""
    case identity   = "\"My identity — I know who God says I am and I walk in it\""
    case calling    = "\"My calling — I step into my purpose and take the land\""
    case abundance  = "\"My abundance — I receive the full provision God already prepared\""
    case allOfIt    = "\"All of it — I'm not leaving any of my inheritance on the table\""

    var goalWord: SurveyGoalWord {
        switch self {
        case .healing:   return .healing
        case .peace:     return .peace
        case .identity:  return .identity
        case .calling:   return .purpose
        case .abundance: return .prosperity
        case .allOfIt:   return .confidence
        }
    }
}

enum ReadinessLevel: String, CaseIterable, Identifiable {
    var id: String { rawValue }
    case ready  = "I'm ready. Something in me knows this is the moment."
    case open   = "I'm open — I just need a place to start and someone to walk with me."
    case unsure = "I'm not fully sure yet — but something brought me here and I want to find out why."
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
        case .healing:    return "41,000"
        case .peace:      return "38,000"
        case .identity:   return "34,000"
        case .destiny:    return "29,000"
        case .warfare:    return "24,000"
        case .prosperity: return "21,000"
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
    @Published var previousAttempts: Set<PreviousAttempt> = []
    @Published var innerLie: InnerLie? = nil
    @Published var declarationExperience: DeclarationExperience? = nil
    @Published var futureChanges: Set<FutureChange> = []
    @Published var readinessLevel: ReadinessLevel? = nil
    @Published var declarationStyles: Set<DeclarationStyle> = []
    @Published var notificationTime: NotificationTime? = nil

    // Priority: explicit style > vision casting > pain point > default
    var resolvedGoalWord: SurveyGoalWord {
        if let style = primaryDeclarationStyle { return style.goalWord }
        if let future = primaryFutureChange { return future.goalWord }
        return heaviestBurden?.goalWord ?? .peace
    }

    var primaryDeclarationStyle: DeclarationStyle? {
        DeclarationStyle.allCases.first { declarationStyles.contains($0) }
    }

    var primaryFutureChange: FutureChange? {
        FutureChange.allCases.first { futureChanges.contains($0) }
    }

    var burdenShortLabel: String {
        heaviestBurden?.shortLabel ?? "your inheritance"
    }

    var durationLabel: String {
        burdenDuration?.rawValue.lowercased() ?? "a long time"
    }
}
