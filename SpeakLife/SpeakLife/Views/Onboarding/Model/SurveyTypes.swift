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
    case burdenDuration     = 2
    case interstitialA      = 3
    case failedAttempts     = 4
    case innerLie           = 5
    case interstitialB      = 6
    case declarationExp     = 7
    case futurePacing       = 8
    case readiness          = 9
    case notificationTime   = 10
    case goalWord           = 11
    case goalReveal         = 12
    case personalDeclaration = 13
    case paywall            = 14

    var isQuestion: Bool {
        switch self {
        case .intro, .interstitialA, .interstitialB, .goalReveal, .personalDeclaration, .paywall: return false
        default: return true
        }
    }

    var questionIndex: Int? {
        let questions: [SurveyStep] = [
            .heaviestBurden, .burdenDuration, .failedAttempts,
            .innerLie, .declarationExp, .futurePacing,
            .readiness, .notificationTime, .goalWord
        ]
        return questions.firstIndex(of: self).map { $0 + 1 }
    }

    static let totalQuestions = 9
}

enum HeaviestBurden: String, CaseIterable, Identifiable {
    var id: String { rawValue }
    case anxiety     = "Anxiety or fear that just won't go away"
    case purpose     = "I feel lost — unsure of who I am or why I'm here"
    case worthiness  = "A deep feeling that I'm just not enough"
    case joyless     = "I've lost my joy — life feels empty or numb"
    case hardSeason  = "I'm going through a health battle and need God's healing"
    case calling     = "I want deeper faith — to really trust God, not just believe in Him"
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
        case .worthiness: return "not feeling enough"
        case .joyless:    return "lost joy"
        case .hardSeason: return "this health battle"
        case .calling:    return "wanting to go deeper in faith"
        case .thriving:   return "growing in God"
        }
    }

    /// True when the user is in a growth/thriving track rather than a pain/struggle track
    var isGrowthTrack: Bool {
        self == .thriving || self == .calling
    }
}

enum BurdenDuration: String, CaseIterable, Identifiable {
    var id: String { rawValue }
    case newlyStarted      = "This is new — just started"
    case fewMonths         = "A few months"
    case overAYear         = "Over a year"
    case mostOfMyLife      = "Most of my adult life"
    case asLongAsRemember  = "As long as I can remember"
}

enum PreviousAttempt: String, CaseIterable, Identifiable {
    var id: String { rawValue }
    // Pain-track options
    case prayer       = "I pray — but the feelings keep coming back"
    case mediaContent = "Podcasts and books help in the moment, but nothing sticks"
    case people       = "Talking to people I trust — it helps, then fades"
    case willpower    = "I push through on willpower alone"
    case therapy      = "I've tried therapy or counseling"
    case noStart      = "I haven't really tried — I don't know where to start"
    // Aspiration-track options
    case faithContent        = "Faith content and books — inspiring, but no real breakthrough yet"
    case prayedNoBreakthrough = "I've prayed and believed but haven't seen the results yet"
    case goalsAndPlanning    = "I've set goals but something always gets in the way"
    case scarcityMindset     = "I've struggled with fear or a scarcity mindset"
    case fearOfFailure       = "Fear of failure keeps holding me back"
    case justStartingOut     = "I'm just getting started — not sure where to begin"
    // Growth-track options (thriving users)
    case readsBible          = "I read my Bible but want a stronger daily habit"
    case sermons             = "I listen to sermons and faith content — want to go deeper"
    case praysDailyWantsMore = "I pray every day but want my faith to be more active"
    case triedDeclarations   = "I've tried declarations before — just wasn't consistent"
    case allInButMissing     = "I do all the things but something still feels like it's missing"
    case newToDeclarations   = "This is new to me — I'm just getting started"

    static var painOptions: [PreviousAttempt] {
        [.prayer, .mediaContent, .people, .willpower, .therapy, .noStart]
    }
    static var aspirationOptions: [PreviousAttempt] {
        [.faithContent, .prayedNoBreakthrough, .goalsAndPlanning, .scarcityMindset, .fearOfFailure, .justStartingOut]
    }
    static var faithOptions: [PreviousAttempt] {
        [.prayer, .faithContent, .prayedNoBreakthrough, .mediaContent, .people, .noStart]
    }
    static var growthOptions: [PreviousAttempt] {
        [.readsBible, .sermons, .praysDailyWantsMore, .triedDeclarations, .allInButMissing, .newToDeclarations]
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
    // Aspiration-track
    case notForMe     = "\"That kind of life is for other people — not me.\""
    case dontDeserve  = "\"I don't deserve more than what I have.\""
    case tooLate      = "\"I've waited too long. I missed my window.\""
    case godWontBless = "\"I don't know if God actually wants this for me.\""
    case notCapable   = "\"I don't have what it takes.\""
    // Faith-track
    case faithWeak    = "\"My faith is too weak. I keep doubting.\""
    case godSilent    = "\"I pray, but God feels silent. I wonder if He hears me.\""
    case faithNotReal = "\"Faith works for other people — I just can't seem to make it real.\""
    case tooSinful    = "\"I've messed up too much. I don't know if God can fully use me.\""
    case faithSmall   = "\"I believe — but not enough to actually trust Him completely.\""
    // Growth-track (thriving users — what they want to build, not a lie)
    case wantSpeakConfidence  = "Speaking God's word with real confidence and conviction"
    case wantTrustMore        = "Trusting God with the things I'm still waiting on"
    case wantUnshakeableFaith = "Building faith that doesn't waver when things get hard"
    case wantPurpose          = "Walking clearly in my God-given purpose"
    case wantPrayerLife       = "A deeper, more consistent prayer and declaration life"

    static var painOptions: [InnerLie] {
        [.failure, .notEnough, .noChange, .godFar, .lostIdentity, .tired]
    }
    static var aspirationOptions: [InnerLie] {
        [.notForMe, .dontDeserve, .tooLate, .godWontBless, .notCapable]
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
    case yesWantMore        = "Yes — it was real. I want to go deeper."
    case heardNotTried      = "I've heard about it but never actually tried it."
    case triedInconsistent  = "I tried it a few times but wasn't consistent."
    case brandNew           = "No — this is completely new to me."
}

enum FutureChange: String, CaseIterable, Identifiable {
    var id: String { rawValue }
    // Pain-track
    case purpose        = "I step into my purpose with confidence"
    case family         = "I show up better for the people I love"
    case boldSteps      = "I stop doubting myself and take bold steps"
    case peaceInBody    = "I feel peace in my body — no more dread"
    case knowIdentity   = "I know who God says I am and I believe it"
    case livingChosen   = "I stop living small and start living like I'm chosen"
    // Prosperity-track
    case familyFree     = "My family is financially free and secure"
    case buildLegacy    = "I build something that outlasts me"
    case giveGenerously = "I give generously without holding back"
    case overflow       = "I stop surviving and start walking in God's overflow"
    case provisionDoors = "My obedience unlocks doors I couldn't open on my own"
    // Faith-track
    case faithPrayers   = "My prayers shift from worry to belief"
    case faithStand     = "I stop being moved by what I see and stand on what God said"
    case faithFoundation = "My faith becomes the foundation every decision is built on"
    case faithConfidence = "I wake up confident in God's promises over my life"
    case faithObedience = "I step into what God is calling me to — without fear"

    static var painOptions: [FutureChange] {
        [.purpose, .family, .boldSteps, .peaceInBody, .knowIdentity, .livingChosen]
    }
    static var prosperityOptions: [FutureChange] {
        [.familyFree, .buildLegacy, .giveGenerously, .overflow, .provisionDoors, .livingChosen]
    }
    static var callingOptions: [FutureChange] {
        [.faithPrayers, .faithStand, .faithFoundation, .faithConfidence, .faithObedience, .knowIdentity]
    }
}

enum ReadinessLevel: String, CaseIterable, Identifiable {
    var id: String { rawValue }
    case ready     = "I'm ready. I need this to change now."
    case open      = "I'm open but need help knowing where to start."
    case skeptical = "I'm skeptical — but willing to try something new."
}

enum NotificationTime: String, CaseIterable, Identifiable {
    var id: String { rawValue }
    case morning = "Morning (6-9am) — start my day in truth before the world gets loud"
    case midday  = "Midday (12-2pm) — when the pressure and stress hits hardest"
    case evening = "Evening (7-9pm) — quiet my mind and reset before bed"
    case allDay  = "All day — I need constant anchoring right now"

    var startTimeIndex: Int {
        // Index = 30-minute slots from midnight (e.g. index 24 = 12:00 PM)
        switch self {
        case .morning: return 12  // 6:00 AM
        case .midday:  return 24  // 12:00 PM
        case .evening: return 38  // 7:00 PM
        case .allDay:  return 12  // 6:00 AM
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

    /// Curated notification categories that match what the user said they need in the survey.
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
    @Published var notificationTime: NotificationTime? = nil
    @Published var goalWord: SurveyGoalWord? = nil

    var resolvedGoalWord: SurveyGoalWord {
        goalWord ?? heaviestBurden?.goalWord ?? .peace
    }

    var burdenShortLabel: String {
        heaviestBurden?.shortLabel ?? "this struggle"
    }

    var durationLabel: String {
        burdenDuration?.rawValue.lowercased() ?? "a long time"
    }
}
