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

    var isQuestion: Bool {
        switch self {
        case .intro, .interstitialA, .interstitialB, .goalReveal: return false
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
    case anxiety     = "Anxiety and fear that won't shut off"
    case purpose     = "I don't know who I am or what I'm here for"
    case worthiness  = "A deep feeling that I'm not enough"
    case joyless     = "I've lost my joy — life feels numb"
    case hardSeason  = "I'm fighting a health battle and need God's healing"
    case prosperity  = "I'm ready for financial breakthrough and abundance"
    case calling     = "I want to step into my calling and reach my potential"

    var goalWord: SurveyGoalWord {
        switch self {
        case .anxiety:    return .peace
        case .purpose:    return .purpose
        case .worthiness: return .identity
        case .joyless:    return .joy
        case .hardSeason: return .healing
        case .prosperity: return .prosperity
        case .calling:    return .purpose
        }
    }

    var shortLabel: String {
        switch self {
        case .anxiety:    return "anxiety"
        case .purpose:    return "feeling lost"
        case .worthiness: return "not feeling enough"
        case .joyless:    return "lost joy"
        case .hardSeason: return "this health battle"
        case .prosperity: return "financial limitation"
        case .calling:    return "feeling stuck in your calling"
        }
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
    case prayer       = "I pray, but the feelings keep coming back"
    case mediaContent = "Podcasts, books — helpful in the moment but nothing sticks"
    case people       = "Talking to people I trust — it helps, then fades"
    case willpower    = "I white-knuckle it and push through"
    case therapy      = "I've tried therapy or counseling"
    case noStart      = "I haven't really tried — I don't know where to start"
}

enum InnerLie: String, CaseIterable, Identifiable {
    var id: String { rawValue }
    case failure      = "\"I can't do this. I'm going to fail.\""
    case notEnough    = "\"I'm not enough — I'll never be enough.\""
    case noChange     = "\"Nothing in my life will ever really change.\""
    case godFar       = "\"God is far away. I don't feel heard.\""
    case lostIdentity = "\"I don't know who I am anymore.\""
    case tired        = "\"I'm tired of fighting. I just want peace.\""
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
    case purpose        = "I step into my purpose with confidence"
    case family         = "I show up better for the people I love"
    case boldSteps      = "I stop doubting myself and take bold steps"
    case peaceInBody    = "I feel peace in my body — no more dread"
    case knowIdentity   = "I know who God says I am and I believe it"
    case livingChosen   = "I stop living small and start living like I'm chosen"
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
        case .peace:      return "30-Day SpeakLife Challenge"
        case .identity:   return "30-Day SpeakLife Challenge"
        case .purpose:    return "30-Day SpeakLife Challenge"
        case .joy:        return "30-Day SpeakLife Challenge"
        case .confidence: return "30-Day SpeakLife Challenge"
        case .healing:    return "30-Day SpeakLife Challenge"
        case .prosperity: return "30-Day SpeakLife Challenge"
        }
    }

    var declarationCategory: DeclarationCategory {
        switch self {
        case .peace:      return .anxiety
        case .identity:   return .identity
        case .purpose:    return .destiny
        case .joy:        return .joy
        case .confidence: return .confidence
        case .healing:    return .anxiety
        case .prosperity: return .wealth
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
