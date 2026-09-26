//
//  StormOnboarding.swift
//  SpeakLife
//
//  The `storm` onboarding arm: every new user speaks a declaration over the
//  storm they named before they ever see a price, then meets a paywall built to
//  remove payment fear (trial eligibility checked first, a timeline, "no payment
//  due now", a reminder they can switch on). Spec: "SpeakLife Onboarding +
//  Paywall Redesign", Sep 26 2026.
//
//  This file holds the model and the small services the arm needs. The screens
//  live in StormOnboardingView.swift and StormPaywallView.swift.
//
//  Assignment (see SubscriptionStore.computedAssignment):
//    - Organic installs: Remote Config `onboardingVariant = "storm"`.
//    - Ad installs whose `ob=` names a storm (healing, provision, anxiety, fear,
//      grief, marriage, parenting): a one-time coin flip weighted by Remote
//      Config `stormAdShare` (0...1, default 0 so it ships dormant). Winners get
//      this flow with their storm preselected; the rest keep their angle arm and
//      are stamped `storm_ad_bucket = control`, which is the comparison group.
//

import Foundation
import SwiftUI
import UserNotifications

// MARK: - Storm

/// What the user is facing, picked with one tap on screen 2. Tap-only on
/// purpose: nothing typed here, so nothing needs the crisis-safety screen that
/// free text is routed through elsewhere.
enum Storm: String, CaseIterable, Identifiable {
    case health, family, marriage, finances, fear, grief, identity

    var id: String { rawValue }

    /// The picker row.
    var label: String {
        switch self {
        case .health:   return "Health"
        case .family:   return "Family & children"
        case .marriage: return "Marriage"
        case .finances: return "Finances"
        case .fear:     return "Fear & anxiety"
        case .grief:    return "Grief"
        case .identity: return "Who I am"
        }
    }

    /// The gold word in "Your [Health] storm plan is ready."
    var planName: String {
        switch self {
        case .health:   return "Health"
        case .family:   return "Family"
        case .marriage: return "Marriage"
        case .finances: return "Finances"
        case .fear:     return "Peace of Mind"
        case .grief:    return "Comfort"
        case .identity: return "Identity"
        }
    }

    /// Where the storm lives, for "declarations over ___ every morning".
    var domain: String {
        switch self {
        case .health:   return "your body"
        case .family:   return "your children"
        case .marriage: return "your marriage"
        case .finances: return "your finances"
        case .fear:     return "your mind"
        case .grief:    return "your heart"
        case .identity: return "who you are"
        }
    }

    var symbol: String {
        switch self {
        case .health:   return "heart.fill"
        case .family:   return "figure.2.and.child.holdinghands"
        case .marriage: return "heart.circle.fill"
        case .finances: return "banknote.fill"
        case .fear:     return "brain.head.profile"
        case .grief:    return "cloud.rain.fill"
        case .identity: return "person.fill.checkmark"
        }
    }

    /// Seeds the home feed, notifications and the 7-day campaign.
    var category: DeclarationCategory {
        switch self {
        case .health:   return .health
        case .family:   return .parenting
        case .marriage: return .marriage
        case .finances: return .wealth
        case .fear:     return .anxiety
        case .grief:    return .grief
        case .identity: return .identity
        }
    }

    /// "When you speak God's promises over ___".
    var overPhrase: String {
        switch self {
        case .health:   return "your health"
        case .family:   return "your family"
        case .marriage: return "your marriage"
        case .finances: return "your finances"
        case .fear:     return "your mind"
        case .grief:    return "your heart"
        case .identity: return "who you are"
        }
    }

    /// What to ask Bible chat about, for the Day-2 trial push.
    var chatTopic: String {
        switch self {
        case .health:   return "your health"
        case .family:   return "your children"
        case .marriage: return "your marriage"
        case .finances: return "your finances"
        case .fear:     return "fear and worry"
        case .grief:    return "losing someone you love"
        case .identity: return "who you are in Christ"
        }
    }

    /// The storm an ad's `ob=` code is about, or nil when the ad angle names no
    /// single storm (warfare, promises, command, ...). Only these codes are
    /// eligible for the ad coin flip.
    init?(adCode: String) {
        switch adCode.lowercased() {
        case "healing":              self = .health
        case "provision":            self = .finances
        case "anxiety", "fear":      self = .fear
        case "grief":                self = .grief
        case "marriage":             self = .marriage
        case "parenting":            self = .family
        default:                     return nil
        }
    }

    // MARK: Content

    /// The line spoken on screen 5, the "aha". Also Day 1 of the plan.
    var firstDeclaration: StormLine { lines[0] }
    /// The win given in the first minute after a trial starts.
    var secondDeclaration: StormLine { lines[1] }
    /// Seven days. Day 1 is the line they already spoke in onboarding, so the
    /// plan opens on something they have done rather than something they owe.
    var planDays: [StormLine] { [lines[0]] + Array(lines[2..<8]) }

    /// Every line is copied verbatim from `declarationsv10.json` (same text,
    /// verse and reference, same category), so it has already passed the
    /// fifteen rules in CLAUDE.md. Nothing unreviewed reaches the moment a
    /// person speaks over their own storm. Change a line there first, then here.
    private var lines: [StormLine] {
        switch self {
        case .health:
            return [
            .init(text: "Thank You Jesus, by Your wounds I am healed and whole.",
                  verse: "But he was pierced for our transgressions, he was crushed for our iniquities; the punishment that brought us peace was on him, and by his wounds we are healed.",
                  reference: "Isaiah 53:5"),
            .init(text: "Thank You Jesus, You took all my sickness, and strength rises in this body every morning.",
                  verse: "This was to fulfill what was spoken through the prophet Isaiah: 'He took up our infirmities and bore our diseases.'",
                  reference: "Matthew 8:17"),
            .init(text: "You carried sickness in Your own body, and by Your wounds I am healed.",
                  verse: "He himself bore our sins in his body on the cross, so that we might die to sins and live for righteousness; by his wounds you have been healed.",
                  reference: "1 Peter 2:24"),
            .init(text: "I am healed, and every system in this body runs right.",
                  verse: "Heal me, Lord, and I will be healed; save me and I will be saved, for you are the one I praise.",
                  reference: "Jeremiah 17:14"),
            .init(text: "The Spirit who raised Jesus lives in me and gives life to this body.",
                  verse: "And if the Spirit of him who raised Jesus from the dead is living in you, he who raised Christ from the dead will also give life to your mortal bodies because of his Spirit who lives in you.",
                  reference: "Romans 8:11"),
            .init(text: "My healing appears quickly, and Your light breaks over my body like the dawn.",
                  verse: "Then your light will break forth like the dawn, and your healing will quickly appear; then your righteousness will go before you, and the glory of the Lord will be your rear guard.",
                  reference: "Isaiah 58:8"),
            .init(text: "Your Word is life to me and health to my whole body every day.",
                  verse: "My son, pay attention to what I say; turn your ear to my words. Do not let them out of your sight, keep them within your heart; for they are life to those who find them and health to one's whole body.",
                  reference: "Proverbs 4:20-22"),
            .init(text: "I live and do not die, and I tell what You have done.",
                  verse: "I will not die but live, and will proclaim what the Lord has done.",
                  reference: "Psalm 118:17")
            ]
        case .family:
            return [
            .init(text: "You teach my children Yourself, and great is their peace.",
                  verse: "All your children will be taught by the Lord, and great will be their peace.",
                  reference: "Isaiah 54:13"),
            .init(text: "You command Your angels over my children, and they are guarded on every road they walk.",
                  verse: "For he will command his angels concerning you to guard you in all your ways;",
                  reference: "Psalm 91:11"),
            .init(text: "You are a shield around my children, and You lift their heads high.",
                  verse: "But you, Lord, are a shield around me, my glory, the One who lifts my head high.",
                  reference: "Psalm 3:3"),
            .init(text: "You began a good work in my children, and You carry it to completion.",
                  verse: "being confident of this, that he who began a good work in you will carry it on to completion until the day of Christ Jesus.",
                  reference: "Philippians 1:6"),
            .init(text: "You know Your plans for my children, plans to prosper them and give them hope.",
                  verse: "\"For I know the plans I have for you,\" declares the Lord, \"plans to prosper you and not to harm you, plans to give you hope and a future.\"",
                  reference: "Jeremiah 29:11"),
            .init(text: "My children lie down and sleep in peace, because You alone keep them safe.",
                  verse: "In peace I will lie down and sleep, for you alone, Lord, make me dwell in safety.",
                  reference: "Psalm 4:8"),
            .init(text: "I trust You with my children, and You make their paths straight before them.",
                  verse: "Trust in the Lord with all your heart and lean not on your own understanding; in all your ways submit to him, and he will make your paths straight.",
                  reference: "Proverbs 3:5-6"),
            .init(text: "You watch my children's going out and coming in, and they come home safe.",
                  verse: "The Lord will keep you from all harm— he will watch over your life; the Lord will watch over your coming and going both now and forevermore.",
                  reference: "Psalm 121:7-8")
            ]
        case .marriage:
            return [
            .init(text: "With You as the third strand, my marriage is a cord that holds.",
                  verse: "Though one may be overpowered, two can defend themselves. A cord of three strands is not quickly broken.",
                  reference: "Ecclesiastes 4:12"),
            .init(text: "I am clothed in Your love, and it binds my marriage in perfect unity.",
                  verse: "And over all these virtues put on love, which binds them all together in perfect unity.",
                  reference: "Colossians 3:14"),
            .init(text: "You joined us as one flesh, and my marriage is knit for life.",
                  verse: "That is why a man leaves his father and mother and is united to his wife, and they become one flesh.",
                  reference: "Genesis 2:24"),
            .init(text: "You build my house Yourself, and what You raise stands firm.",
                  verse: "Unless the Lord builds the house, the builders labor in vain. Unless the Lord watches over the city, the guards stand watch in vain.",
                  reference: "Psalm 127:1"),
            .init(text: "You are the Rock, and I build my marriage on Your words so it stands.",
                  verse: "Therefore everyone who hears these words of mine and puts them into practice is like a wise man who built his house on the rock.",
                  reference: "Matthew 7:24"),
            .init(text: "I have found a good thing, and Your favor rests on my marriage.",
                  verse: "He who finds a wife finds what is good and receives favor from the Lord.",
                  reference: "Proverbs 18:22"),
            .init(text: "Love runs deep in me, and it covers my marriage with grace.",
                  verse: "Above all, love each other deeply, because love covers over a multitude of sins.",
                  reference: "1 Peter 4:8"),
            .init(text: "You forgave me freely, and I forgive my spouse the same way.",
                  verse: "Be kind and compassionate to one another, forgiving each other, just as in Christ God forgave you.",
                  reference: "Ephesians 4:32")
            ]
        case .finances:
            return [
            .init(text: "You meet every need of mine from the riches of Your glory.",
                  verse: "And my God will meet all your needs according to the riches of his glory in Christ Jesus.",
                  reference: "Philippians 4:19"),
            .init(text: "You are my shepherd, and everything I need is already mine.",
                  verse: "The Lord is my shepherd, I lack nothing.",
                  reference: "Psalm 23:1"),
            .init(text: "You plant me by Your streams, and whatever I do prospers.",
                  verse: "That person is like a tree planted by streams of water, which yields its fruit in season and whose leaf does not wither— whatever they do prospers.",
                  reference: "Psalm 1:3"),
            .init(text: "You give me power to produce wealth, and my increase confirms Your covenant.",
                  verse: "But remember the Lord your God, for it is he who gives you the ability to produce wealth, and so confirms his covenant, which he swore to your ancestors, as it is today.",
                  reference: "Deuteronomy 8:18"),
            .init(text: "You bless me abundantly, so I have all I need and abound in every good work.",
                  verse: "And God is able to bless you abundantly, so that in all things at all times, having all that you need, you will abound in every good work.",
                  reference: "2 Corinthians 9:8"),
            .init(text: "Your blessing makes me rich, and it comes with rest and joy.",
                  verse: "The blessing of the LORD brings wealth, without painful toil for it.",
                  reference: "Proverbs 10:22"),
            .init(text: "I seek Your kingdom first, and You add everything else I need.",
                  verse: "But seek first his kingdom and his righteousness, and all these things will be given to you as well.",
                  reference: "Matthew 6:33"),
            .init(text: "You send Your blessing on my storehouse and everything I put my hand to.",
                  verse: "The Lord will send a blessing on your barns and on everything you put your hand to.",
                  reference: "Deuteronomy 28:8")
            ]
        case .fear:
            return [
            .init(text: "My mind stays fixed on You, and You keep me in perfect peace.",
                  verse: "You will keep in perfect peace those whose minds are steadfast, because they trust in you.",
                  reference: "Isaiah 26:3"),
            .init(text: "You gave me power, love, and a sound mind, and my thinking stays clear.",
                  verse: "For the Spirit God gave us does not make us timid, but gives us power, love and self-discipline.",
                  reference: "2 Timothy 1:7"),
            .init(text: "You gave me Your own peace, and I carry it into every room.",
                  verse: "Peace I leave with you; my peace I give you. I do not give to you as the world gives. Do not let your hearts be troubled and do not be afraid.",
                  reference: "John 14:27"),
            .init(text: "Your peace beyond all understanding guards my heart and my mind in Christ.",
                  verse: "And the peace of God, which transcends all understanding, will guard your hearts and your minds in Christ Jesus.",
                  reference: "Philippians 4:7"),
            .init(text: "You carry every care I hand You, because You care for me deeply.",
                  verse: "Cast all your anxiety on him because he cares for you.",
                  reference: "1 Peter 5:7"),
            .init(text: "You sustain me, and I am never shaken, no matter what the day brings.",
                  verse: "Cast your cares on the LORD and he will sustain you; he will never let the righteous be shaken.",
                  reference: "Psalm 55:22"),
            .init(text: "You give me rest, and I set the whole load down at Your feet.",
                  verse: "Come to me, all you who are weary and burdened, and I will give you rest.",
                  reference: "Matthew 11:28"),
            .init(text: "My heart is steady and anchored in You, and no report moves me an inch.",
                  verse: "They will have no fear of bad news; their hearts are steadfast, trusting in the LORD.",
                  reference: "Psalm 112:7")
            ]
        case .grief:
            return [
            .init(text: "You heal my heart and bind up my wounds, and I am whole again.",
                  verse: "He heals the brokenhearted and binds up their wounds.",
                  reference: "Psalm 147:3"),
            .init(text: "You turned my grief into joy, and no one takes that joy from me.",
                  verse: "So with you: Now is your time of grief, but I will see you again and you will rejoice, and no one will take away your joy.",
                  reference: "John 16:22"),
            .init(text: "Through the valley You walk beside me, and Your rod and staff comfort me.",
                  verse: "Even though I walk through the darkest valley, I will fear no evil, for you are with me; your rod and your staff, they comfort me.",
                  reference: "Psalm 23:4"),
            .init(text: "The comfort You promised is mine right now, and You call me blessed.",
                  verse: "Blessed are those who mourn, for they will be comforted.",
                  reference: "Matthew 5:4"),
            .init(text: "Underneath me are Your everlasting arms, and You are my refuge forever.",
                  verse: "The eternal God is your refuge, and underneath are the everlasting arms. He will drive out your enemies before you, saying, “Destroy them!”",
                  reference: "Deuteronomy 33:27"),
            .init(text: "Like a shepherd You gather me in Your arms and carry me close to Your heart.",
                  verse: "He tends his flock like a shepherd: He gathers the lambs in his arms and carries them close to his heart; he gently leads those that have young.",
                  reference: "Isaiah 40:11"),
            .init(text: "Weeping stayed for a night, and joy comes to me in the morning.",
                  verse: "For his anger lasts only a moment, but his favor lasts a lifetime; weeping may stay for the night, but rejoicing comes in the morning.",
                  reference: "Psalm 30:5"),
            .init(text: "You crown me with beauty instead of ashes and clothe me in the oil of joy.",
                  verse: "and provide for those who grieve in Zion, to bestow on them a crown of beauty instead of ashes, the oil of joy instead of mourning, and a garment of praise instead of a spirit of despair. They will be called oaks of righteousness, a planting of the LORD for the display of his splendor.",
                  reference: "Isaiah 61:3")
            ]
        case .identity:
            return [
            .init(text: "I am a new creation in You, and the old is gone for good.",
                  verse: "Therefore, if anyone is in Christ, the new creation has come: The old has gone, the new is here!",
                  reference: "2 Corinthians 5:17"),
            .init(text: "You formed me, redeemed me, and called me by name, and I am Yours forever.",
                  verse: "But now, this is what the Lord says—he who created you, Jacob, he who formed you, Israel: 'Do not fear, for I have redeemed you; I have summoned you by name; you are mine.'",
                  reference: "Isaiah 43:1"),
            .init(text: "You call me Your child, and that is exactly what I am right now.",
                  verse: "See what great love the Father has lavished on us, that we should be called children of God! And that is what we are!",
                  reference: "1 John 3:1"),
            .init(text: "I am complete in You, and nothing in me is missing or unfinished.",
                  verse: "and in Christ you have been brought to fullness. He is the head over every power and authority.",
                  reference: "Colossians 2:10"),
            .init(text: "You chose me before the world was made, and You set me apart in love.",
                  verse: "For he chose us in him before the creation of the world to be holy and blameless in his sight. In love.",
                  reference: "Ephesians 1:4"),
            .init(text: "I am Your righteousness in Christ, and I stand right before You today.",
                  verse: "God made him who had no sin to be sin for us, so that in him we might become the righteousness of God.",
                  reference: "2 Corinthians 5:21"),
            .init(text: "You made me fearfully and wonderfully, and I know it full well.",
                  verse: "I praise you because I am fearfully and wonderfully made; your works are wonderful, I know that full well.",
                  reference: "Psalm 139:14"),
            .init(text: "I am Your handiwork, made for good works You prepared before my first breath.",
                  verse: "For we are God's handiwork, created in Christ Jesus to do good works, which God prepared in advance for us to do.",
                  reference: "Ephesians 2:10")
            ]        }
    }
}

/// One declaration with its verse.
struct StormLine: Equatable {
    let text: String
    let verse: String
    let reference: String

    /// As a pool `Declaration`, so a plan can start a real Enforcement week.
    func declaration(in category: DeclarationCategory) -> Declaration {
        Declaration(text: text, book: reference, bibleVerseText: verse, category: category)
    }
}

// MARK: - Screen-3 posture and screen-6 feeling

enum StormPosture: String, CaseIterable, Identifiable {
    case askGod = "ask_god"
    case worry
    case noWords = "no_words"
    case speakScripture = "speak_scripture"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .askGod:         return "Ask God to fix it"
        case .worry:          return "Worry about it"
        case .noWords:        return "Don't know what to say"
        case .speakScripture: return "Speak Scripture over it"
        }
    }
}

enum StormFeeling: String, CaseIterable, Identifiable {
    case strong, emotional, peaceful
    case notSure = "not_sure"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .strong:    return "Strong"
        case .emotional: return "Emotional"
        case .peaceful:  return "Peaceful"
        case .notSure:   return "Not sure"
        }
    }

    var symbol: String {
        switch self {
        case .strong:    return "bolt.fill"
        case .emotional: return "drop.fill"
        case .peaceful:  return "leaf.fill"
        case .notSure:   return "questionmark"
        }
    }
}

// MARK: - Brand

enum StormStyle {
    /// Spec colors. Gold on navy clears 4.5:1 for every text size used.
    static let gold = Color(hex: "#F5B742")
    static let navy = Color(hex: "#1A264D")
    static let navyDeep = Color(hex: "#111A38")
    /// Secondary text. 78% white on navy stays above 4.5:1; the old 55% gray did not.
    static let secondary = Color.white.opacity(0.78)
}

// MARK: - Membership and preferences

/// Persisted facts about a storm-arm install. Persisted rather than read from
/// `resolvedOnboardingVariant` because that is recomputed from Remote Config on
/// every launch: a member must keep the storm paywall and free layer after the
/// experiment config changes, or the arm's own users leak into the control.
enum StormOnboarding {
    static let variantName = "storm"

    private static let memberKey = "storm_arm_member"
    private static let stormKey = "storm_selected"
    private static let morningMinutesKey = "storm_morning_minutes"
    private static let planStartKey = "storm_plan_started_on"
    private static let adBucketKey = "storm_ad_bucket"

    private static let memberSinceKey = "storm_member_since"

    static var isMember: Bool { UserDefaults.standard.bool(forKey: memberKey) }

    /// Called once, when onboarding locks the storm arm. Idempotent.
    static func enroll() {
        guard !isMember else { return }
        UserDefaults.standard.set(true, forKey: memberKey)
        UserDefaults.standard.set(Date(), forKey: memberSinceKey)
    }

    static var memberSince: Date? {
        UserDefaults.standard.object(forKey: memberSinceKey) as? Date
    }

    static var selectedStorm: Storm? {
        get { UserDefaults.standard.string(forKey: stormKey).flatMap(Storm.init(rawValue:)) }
        set { UserDefaults.standard.set(newValue?.rawValue, forKey: stormKey) }
    }

    /// Minutes after midnight the user chose on screen 7. Nil until chosen.
    static var morningMinutes: Int? {
        get { UserDefaults.standard.object(forKey: morningMinutesKey) as? Int }
        set { UserDefaults.standard.set(newValue, forKey: morningMinutesKey) }
    }

    static var morningTime: (hour: Int, minute: Int)? {
        morningMinutes.map { ($0 / 60, $0 % 60) }
    }

    // MARK: Ad coin flip

    /// "storm" or "control" once an ad install with a storm-mappable `ob=` has
    /// been flipped. Nil for everyone else, including ad installs flipped while
    /// the share was 0, so the control group only ever holds users who could
    /// have landed in the arm.
    static var adBucket: String? {
        UserDefaults.standard.string(forKey: adBucketKey)
    }

    /// Flip once, persist, and never flip again. `share` 0 flips nothing.
    static func resolveAdBucket(share: Double) -> String? {
        if let existing = adBucket { return existing }
        guard share > 0 else { return nil }
        let bucket = Double.random(in: 0..<1) < min(share, 1) ? "storm" : "control"
        UserDefaults.standard.set(bucket, forKey: adBucketKey)
        return bucket
    }

    // MARK: Plan window

    static var planStartedOn: Date? {
        get { UserDefaults.standard.object(forKey: planStartKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: planStartKey) }
    }

    /// The plan line for a calendar day, while the seven-day plan is running.
    static func planLine(on date: Date, calendar: Calendar = .current) -> (day: Int, line: StormLine, storm: Storm)? {
        guard let storm = selectedStorm, let start = planStartedOn else { return nil }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: start),
                                           to: calendar.startOfDay(for: date)).day ?? -1
        guard (0..<storm.planDays.count).contains(days) else { return nil }
        return (days + 1, storm.planDays[days], storm)
    }
}

// MARK: - Trial reminder

/// The promise the paywall makes: "We'll remind you 2 days before." One local
/// notification on Day 5 of a 7-day trial, at the morning time the user chose,
/// worded plainly: when the charge happens, how much, and how to cancel.
enum StormTrialReminder {
    static let identifier = "trial_d5"

    /// - Returns: the fire date, or nil when the slot has already passed.
    @discardableResult
    static func schedule(trialStart: Date, trialDays: Int, priceText: String,
                         calendar: Calendar = .current) -> Date? {
        guard trialDays >= 3 else { return nil }
        let chargeDate = calendar.date(byAdding: .day, value: trialDays, to: trialStart) ?? trialStart
        // Two days before the charge, on the morning they speak.
        guard let day = calendar.date(byAdding: .day, value: trialDays - 2, to: trialStart) else { return nil }
        let time = StormOnboarding.morningTime ?? (8, 0)
        guard let fire = calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: day),
              fire > Date() else { return nil }

        let content = UNMutableNotificationContent()
        content.title = "Your free week ends in 2 days"
        let chargeDay = chargeDate.formatted(.dateTime.weekday(.wide).month(.wide).day())
        content.body = "If you keep SpeakLife, \(priceText) begins on \(chargeDay). To cancel, open Settings, tap your name, then Subscriptions."
        content.sound = .default
        content.userInfo = ["lifecycle_id": identifier]

        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
        UNUserNotificationCenter.current().add(UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        ))
        AnalyticsService.shared.track("trial_reminder_scheduled", parameters: [
            "scheduled_for": ISO8601DateFormatter().string(from: fire),
            "trial_days": trialDays
        ])
        return fire
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}

// MARK: - Trial week feature pushes

/// Users who touch audio and Bible chat during the trial convert more, so the
/// trial week introduces both: audio on the first night (see
/// `LifecycleNotificationService.scheduleTrialFirstNightAudio`), Bible chat on
/// Day 2, tied to their storm.
enum StormTrialPushes {
    static let bibleChatID = "trial_bible_chat_d2"

    static func schedule(storm: Storm, trialStart: Date, calendar: Calendar = .current) {
        LifecycleNotificationService.shared.scheduleTrialFirstNightAudio(
            category: storm.category.rawValue,
            domain: storm.domain
        )

        // Day 2, midday: clear of the morning Burst and the evening audio.
        guard let day2 = calendar.date(byAdding: .day, value: 1, to: trialStart),
              let fire = calendar.date(bySettingHour: 12, minute: 30, second: 0, of: day2),
              fire > Date() else { return }
        let content = UNMutableNotificationContent()
        content.title = "Ask what Scripture says about \(storm.chatTopic)"
        content.body = "Type any question in Ask the Bible and get an answer rooted in verses."
        content.sound = .default
        content.userInfo = ["action": bibleChatID, "deepLink": "bibleChat"]
        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
        UNUserNotificationCenter.current().add(UNNotificationRequest(
            identifier: bibleChatID,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        ))
        AnalyticsService.shared.track("trial_feature_pushes_scheduled", parameters: [
            "storm": storm.rawValue
        ])
    }
}

// MARK: - Free layer

/// What a storm-arm install that closed the paywall keeps: one declaration a
/// day. Protects the organic flywheel and review velocity without giving the
/// product away. The paywall comes back from the moment the day's line is used,
/// from day 2 on.
enum StormFreeLayer {
    private static let dayKey = "storm_free_day"
    private static let countKey = "storm_free_count"

    static func isActive(hasFullAccess: Bool) -> Bool {
        StormOnboarding.isMember && !hasFullAccess
    }

    /// Declarations a free member gets per day.
    static let dailyAllowance = 1

    /// Declarations used today.
    static var usedToday: Int {
        let today = dayStamp(Date())
        guard UserDefaults.standard.string(forKey: dayKey) == today else { return 0 }
        return UserDefaults.standard.integer(forKey: countKey)
    }

    static var hasAllowanceLeft: Bool { usedToday < dailyAllowance }

    static func recordUse() {
        let today = dayStamp(Date())
        let count = usedToday + 1
        UserDefaults.standard.set(today, forKey: dayKey)
        UserDefaults.standard.set(count, forKey: countKey)
    }

    /// 1 on install day. The limit screen offers the paywall softly on day 1
    /// and leads with it from day 2.
    static var freeDay: Int {
        let installed = StormOnboarding.memberSince ?? Date()
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: installed),
                                                   to: Calendar.current.startOfDay(for: Date())).day ?? 0
        return days + 1
    }

    private static func dayStamp(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
    }
}
