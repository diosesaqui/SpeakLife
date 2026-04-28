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
    case productPositioning = 2   // NEW: "read vs speak"
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

enum HeaviestBurden: String, CaseIterable, Identifiable {
    var id: String { rawValue }
    case anxiety     = "Anxiety or fear that just won't go away"
    case purpose     = "I feel lost — unsure of who I am or why I'm here"
    case worthiness  = "I know God loves me — but I don't feel it. Something's blocking me."
    case joyless     = "I've lost my joy — life feels empty or numb"
    case hardSeason  = "I'm going through a health battle and need God's healing"
    case calling     = "I believe in God — but my life doesn't look like I believe His promises."
    case thriving    = "Life is good — I just want to make speaking God's Word a daily habit"

    var goalWord: SurveyGoalWord {
        switch self {
        case .anxiety:    return .peace
        case .purpose:    return .identity
        case .worthiness: return .identity
        case .joyless:    return .joy
        case .hardSeason: return .healing
        case .calling:    return .identity
        case .thriving:   return .purpose
        }
    }

    var shortLabel: String {
        switch self {
        case .anxiety:    return "anxiety"
        case .purpose:    return "feeling lost"
        case .worthiness: return "not feeling God's love"
        case .joyless:    return "lost joy"
        case .hardSeason: return "this health battle"
        case .calling:    return "wanting to walk in God's promises"
        case .thriving:   return "growing in God"
        }
    }

    var isGrowthTrack: Bool {
        self == .thriving || self == .calling
    }
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

    static var allOptions: [PreviousAttempt] {
        [.prayer, .readBible, .prayedNoBreakthrough, .worship, .people, .noStart]
    }
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

enum FutureChange: String, CaseIterable, Identifiable {
    var id: String { rawValue }
    case fearMornings    = "\"Fear doesn't run my mornings anymore.\""
    case speakHealing    = "\"I speak healing over my body — and I believe it.\""
    case knowIdentity    = "\"I know exactly who God says I am. And I'm walking in it.\""
    case stepCalling     = "\"I step into my calling without shrinking back.\""
    case prayerShift     = "\"My prayers shifted from begging to declaring.\""
    case wakeInPeace     = "\"I wake up in peace — not dread.\""

    static var allOptions: [FutureChange] {
        [.fearMornings, .speakHealing, .knowIdentity, .stepCalling, .prayerShift, .wakeInPeace]
    }
}

enum ReadinessLevel: String, CaseIterable, Identifiable {
    var id: String { rawValue }
    case ready     = "I'm ready. Something in me knows this is the moment."
    case open      = "I'm open — I just need a place to start and someone to walk with me."
    case unsure    = "I'm not fully sure yet — but something brought me here and I want to find out why."
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
        case .peace:      return "30-Day Peace Reset"
        case .identity:   return "30-Day Identity Reset"
        case .purpose:    return "30-Day Purpose Awakening"
        case .joy:        return "30-Day Joy Challenge"
        case .confidence: return "30-Day Confidence Builder"
        case .healing:    return "30-Day Healing Journey"
        case .prosperity: return "30-Day Abundance Declaration"
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
        case .prosperity: return "Prosperity"
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

    var resolvedGoalWord: SurveyGoalWord {
        primaryDeclarationStyle?.goalWord ?? heaviestBurden?.goalWord ?? .peace
    }

    var primaryDeclarationStyle: DeclarationStyle? {
        DeclarationStyle.allCases.first { declarationStyles.contains($0) }
    }

    var burdenShortLabel: String {
        heaviestBurden?.shortLabel ?? "this struggle"
    }

    var durationLabel: String {
        burdenDuration?.rawValue.lowercased() ?? "a long time"
    }
}
