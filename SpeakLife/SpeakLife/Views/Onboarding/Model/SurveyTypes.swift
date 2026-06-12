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
    case productPositioning = 2   // merged with The Seed
    case burdenDuration     = 3
    case mergedBarriers     = 4
    case interstitialB      = 5
    case declarationExp     = 6
    case goalReveal         = 7
    case personalDeclaration = 8
    case takeAStand         = 9
    case commitmentHold     = 10
    case firstDeclaration   = 11  // taste before paywall
    case paywall            = 12
    case notificationTime   = 13  // post-paywall
    case rating             = 14  // dedicated SKStoreReviewController prime — highest-velocity ask

    var isQuestion: Bool {
        switch self {
        case .intro, .productPositioning, .interstitialB,
             .goalReveal, .personalDeclaration, .takeAStand,
             .commitmentHold, .firstDeclaration, .paywall,
             .notificationTime, .rating: return false
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

    // Named 30-day plan title shown on the pre-paywall plan reveal screen.
    var planTitle: String {
        switch self {
        case .peace:     return "Your 30-Day\nTake Back My Peace Plan"
        case .health:    return "Your 30-Day\nTake Back My Health Plan"
        case .joy:       return "Your 30-Day\nTake Back My Joy Plan"
        case .identity:  return "Your 30-Day\nKnow Who I Am Plan"
        case .purpose:   return "Your 30-Day\nWalk In My Calling Plan"
        case .abundance: return "Your 30-Day\nTake Back My Provision Plan"
        case .allOfIt:   return "Your 30-Day\nSpeak Life Plan"
        }
    }

    var testimonialGroup: TestimonialGroup {
        switch self {
        case .peace, .health:             return .fearAndHealth
        case .joy, .identity, .purpose:   return .identityAndPurpose
        case .abundance, .allOfIt:        return .defaultGrowth
        }
    }

    // One curated declaration per burden — shown on the "taste before paywall" screen
    var previewDeclaration: (text: String, verse: String, reference: String) {
        switch self {
        case .peace:
            return (
                "I walk in perfect peace. My mind is stayed on God and He keeps me in a stillness the world cannot shake.",
                "You will keep in perfect peace those whose minds are steadfast, because they trust in you.",
                "Isaiah 26:3"
            )
        case .health:
            return (
                "I am healed. By the stripes of Jesus every part of my body walks in the restoration God already paid for.",
                "By his wounds you have been healed.",
                "1 Peter 2:24"
            )
        case .joy:
            return (
                "The joy of the Lord is my strength. I carry deep, unshakeable joy that no circumstance can touch or take from me.",
                "The joy of the Lord is your strength.",
                "Nehemiah 8:10"
            )
        case .identity:
            return (
                "I am chosen, holy, and dearly loved. I know exactly who God says I am — and that settled truth is enough.",
                "You are a chosen people, a royal priesthood, a holy nation, God's special possession.",
                "1 Peter 2:9"
            )
        case .purpose:
            return (
                "I am called and commissioned. My steps are ordered by God and my destiny cannot be delayed, stolen, or denied.",
                "For we are God's handiwork, created in Christ Jesus to do good works, which God prepared in advance for us to do.",
                "Ephesians 2:10"
            )
        case .abundance:
            return (
                "God supplies all my needs according to His riches in glory. I walk in provision, favor, and overflow — not lack.",
                "And my God will meet all your needs according to the riches of his glory in Christ Jesus.",
                "Philippians 4:19"
            )
        case .allOfIt:
            return (
                "I am more than a conqueror through Christ who loves me. I take more ground today than I took yesterday.",
                "In all these things we are more than conquerors through him who loved us.",
                "Romans 8:37"
            )
        }
    }
}

// Quiz v2: burden-aware answers for the "victory_looks_like" outcome question
// (replaces connect_style when Remote Config `useQuizV2` is on). `value` is the
// raw analytics value; `echo` is replayed on the plan reveal's week-4 arc line.
extension HeaviestBurden {
    var victoryOptions: [(value: String, label: String, symbol: String, echo: String)] {
        switch self {
        case .peace:
            return [
                (value: "sleep",   label: "I sleep through the night",            symbol: "moon.zzz.fill",         echo: "Sleeping through the night"),
                (value: "present", label: "I'm present with the people I love",   symbol: "figure.2.arms.open",    echo: "Present with the people you love"),
                (value: "quiet",   label: "My mind finally gets quiet",           symbol: "brain.head.profile",    echo: "A quiet mind"),
                (value: "myself",  label: "I feel like myself again",             symbol: "person.fill.checkmark", echo: "Feeling like yourself again")
            ]
        case .health:
            return [
                (value: "strength", label: "I wake up with strength",             symbol: "sunrise.fill",          echo: "Waking up with strength"),
                (value: "active",   label: "I'm active with my family again",     symbol: "figure.run",            echo: "Active with your family again"),
                (value: "fear",     label: "The fear about my body is gone",      symbol: "shield.fill",           echo: "Free from fear about your body"),
                (value: "whole",    label: "I walk in the healing Jesus paid for", symbol: "heart.fill",           echo: "Walking in the healing Jesus paid for")
            ]
        case .joy:
            return [
                (value: "mornings", label: "I wake up expectant, not heavy",      symbol: "sunrise.fill",          echo: "Waking up expectant"),
                (value: "laugh",    label: "I laugh easily again",                symbol: "face.smiling",          echo: "Laughing easily again"),
                (value: "hope",     label: "Hope feels normal, not forced",       symbol: "sparkles",              echo: "Hope that feels normal"),
                (value: "light",    label: "The heaviness lifts off my house",    symbol: "house.fill",            echo: "A lighter home")
            ]
        case .identity:
            return [
                (value: "secure",  label: "I stop second-guessing who I am",      symbol: "person.fill.checkmark", echo: "Secure in who God says you are"),
                (value: "rooms",   label: "I walk into rooms without shrinking",  symbol: "figure.walk",           echo: "Walking in without shrinking"),
                (value: "voices",  label: "Other people's opinions lose their grip", symbol: "speaker.slash.fill", echo: "Free from other people's opinions"),
                (value: "son",     label: "I live like a loved son or daughter",  symbol: "crown.fill",            echo: "Living like a loved son or daughter")
            ]
        case .purpose:
            return [
                (value: "clarity", label: "I know my next step",                  symbol: "signpost.right.fill",   echo: "Clear on your next step"),
                (value: "courage", label: "I move without waiting for permission", symbol: "bolt.fill",            echo: "Moving with courage"),
                (value: "fruit",   label: "My work starts bearing fruit",         symbol: "leaf.fill",             echo: "Work that bears fruit"),
                (value: "aligned", label: "My days line up with my calling",      symbol: "scope",                 echo: "Days lined up with your calling")
            ]
        case .abundance:
            return [
                (value: "bills",    label: "Bills stop running my thoughts",      symbol: "checkmark.seal.fill",   echo: "Bills no longer running your thoughts"),
                (value: "doors",    label: "Doors open that I didn't force",      symbol: "key.fill",              echo: "Doors opening that you didn't force"),
                (value: "give",     label: "I give without fear",                 symbol: "gift.fill",             echo: "Giving without fear"),
                (value: "overflow", label: "My family lives from overflow",       symbol: "drop.fill",             echo: "A family living from overflow")
            ]
        case .allOfIt:
            return [
                (value: "more",       label: "I stop surviving and start advancing", symbol: "flag.fill",          echo: "Advancing, not surviving"),
                (value: "atmosphere", label: "The atmosphere of my life shifts",  symbol: "wind",                  echo: "A shifted atmosphere"),
                (value: "words",      label: "My words start building, not leaking", symbol: "quote.bubble.fill",  echo: "Words that build"),
                (value: "ceiling",    label: "I break the ceiling I've been living under", symbol: "arrow.up.circle.fill", echo: "Breaking the ceiling")
            ]
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

// Merged barriers screen — most emotionally charged options listed first
enum BarrierOption: String, CaseIterable, Identifiable {
    var id: String { rawValue }
    case mountains    = "\"I see other people's faith move mountains. Mine feels like it barely moves me.\""
    case promises     = "\"I've messed up too much. Part of me wonders if God's promises are really for someone like me.\""
    case prayer       = "I pray — but the fear and doubt come right back"
    case readBible    = "I read the Bible — but it stays in my head, not my heart"
    case mondayHits   = "Worship and sermons lift me up — then Monday hits and it's gone"
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
        case .morning: return 12   // 6:00 AM
        case .midday:  return 24   // 12:00 PM
        case .evening: return 38   // 7:00 PM
        case .allDay:  return 12   // 6:00 AM
        }
    }

    var endTimeIndex: Int {
        switch self {
        case .morning: return 18   // 9:00 AM
        case .midday:  return 28   // 2:00 PM
        case .evening: return 42   // 9:00 PM
        case .allDay:  return 44   // 10:00 PM
        }
    }

    var previewTime: String {
        switch self {
        case .morning: return "7:00 AM"
        case .midday:  return "12:30 PM"
        case .evening: return "8:00 PM"
        case .allDay:  return "Throughout the day"
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

    // Extended quiz answers (warfare/product flows, Q2-Q6). Stored as the raw
    // analytics values; the question copy + options live in
    // SurveyOnboardingScreens.swift (QuizQuestion).
    @Published var battleDuration: String? = nil   // weeks | months | years | always
    @Published var alreadyTried: String? = nil     // prayer | devotionals | therapy | willpower | everything
    @Published var hitsHardest: String? = nil      // night | morning | midday | evening
    @Published var connectStyle: String? = nil     // speaking | listening | reading | journaling (quiz v1 only)
    @Published var dailyMinutes: String? = nil     // one | three | ten

    // Quiz v2 answers (only set when Remote Config `useQuizV2` is on).
    @Published var victoryOutcome: String? = nil   // burden-aware "victory_looks_like" value
    @Published var beliefLevel: String? = nil      // yes | want_to | unsure

    /// The plan reveal's week-4 echo phrase, derived from the victory-outcome
    /// answer. Nil in quiz v1 (victoryOutcome is never set there).
    var victoryEcho: String? {
        guard let value = victoryOutcome else { return nil }
        let burden = heaviestBurden ?? .peace  // mirrors the screen's fallback
        return burden.victoryOptions.first(where: { $0.value == value })?.echo
    }

    /// Maps the "when does it hit hardest?" answer to a notification window so
    /// the time screen arrives pre-selected (the user can still change it).
    /// 3am/night battles get all-day anchoring; the rest map directly.
    var suggestedNotificationTime: NotificationTime? {
        switch hitsHardest {
        case "morning": return .morning
        case "midday":  return .midday
        case "evening": return .evening
        case "night":   return .allDay
        default:        return nil
        }
    }

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
