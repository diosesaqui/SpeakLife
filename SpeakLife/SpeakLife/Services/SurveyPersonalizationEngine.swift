//
//  SurveyPersonalizationEngine.swift
//  SpeakLife
//

import Foundation

struct SurveyPaywallCopy {
    let headline: String
    let subheadline: String
    let valueProps: [SurveyValueProp]
    let ctaText: String
    let urgencyText: String
    let challengeName: String
}

struct SurveyValueProp {
    let icon: String
    let title: String
    let description: String
}

struct SurveyNotificationCopy {
    let headline: String
    let subheadline: String
    let statLine: String
    let ctaText: String
}

struct SurveyPersonalizationEngine {
    let goalWord: SurveyGoalWord?

    init(goalWordRaw: String) {
        self.goalWord = SurveyGoalWord(rawValue: goalWordRaw)
    }

    init(goalWord: SurveyGoalWord?) {
        self.goalWord = goalWord
    }

    var hasSurveyData: Bool { goalWord != nil }

    var paywallCopy: SurveyPaywallCopy {
        guard let word = goalWord else { return defaultPaywallCopy }
        switch word {
        case .peace:
            return SurveyPaywallCopy(
                headline: "Wake up to peace, not panic.",
                subheadline: "3 minutes of God's Word every morning rewires how your brain responds to fear.",
                valueProps: [
                    SurveyValueProp(icon: "wind", title: "Quiet the 3am thoughts", description: "Daily declarations rewire your mind until God's peace is your first response."),
                    SurveyValueProp(icon: "moon.stars.fill", title: "Speak peace over every storm", description: "Jesus spoke to storms and they obeyed. Learn to speak His Word over yours."),
                    SurveyValueProp(icon: "brain.head.profile", title: "Scripture in your ears daily", description: "Audio devotionals soak your mind in God's promises, morning and night."),
                    SurveyValueProp(icon: "person.2.fill", title: "Anchored, not anxious", description: "Join believers trading worry for an unshakeable identity in Christ.")
                ],
                ctaText: "Start My 30-Day SpeakLife Challenge",
                urgencyText: "3 Days Free • Cancel Anytime",
                challengeName: "30-Day SpeakLife Challenge"
            )
        case .identity:
            return SurveyPaywallCopy(
                headline: "Know who God says you are.",
                subheadline: "You've believed the lie long enough. God wrote a different story about you.",
                valueProps: [
                    SurveyValueProp(icon: "sparkles", title: "Silence the 'not enough' lie", description: "Daily declarations replace the old story with what God actually says about you."),
                    SurveyValueProp(icon: "book.fill", title: "Speak who you are", description: "Your identity gets sealed when your own voice agrees with God's Word."),
                    SurveyValueProp(icon: "repeat.circle.fill", title: "Hear His truth every morning", description: "Audio devotionals keep God's voice louder than every label you've carried."),
                    SurveyValueProp(icon: "person.2.fill", title: "Never walk this alone", description: "Join believers discovering who God says they are.")
                ],
                ctaText: "Start My 30-Day SpeakLife Challenge",
                urgencyText: "3 Days Free • Cancel Anytime",
                challengeName: "30-Day SpeakLife Challenge"
            )
        case .purpose:
            return SurveyPaywallCopy(
                headline: "Walk into your calling.",
                subheadline: "God wrote your destiny before you were born. Speak it until you're living it.",
                valueProps: [
                    SurveyValueProp(icon: "flame.fill", title: "Walk into your calling", description: "Daily declarations align your steps with the destiny God wrote for you."),
                    SurveyValueProp(icon: "map.fill", title: "Speak direction over confusion", description: "Declare God's plans out loud until clarity replaces second-guessing."),
                    SurveyValueProp(icon: "arrow.up.forward.circle.fill", title: "Vision in your ears daily", description: "Audio devotionals fill your mornings with purpose before the noise gets in."),
                    SurveyValueProp(icon: "person.2.fill", title: "Called and commissioned", description: "Join believers stepping into their God-given assignment.")
                ],
                ctaText: "Start My 30-Day SpeakLife Challenge",
                urgencyText: "3 Days Free • Cancel Anytime",
                challengeName: "30-Day SpeakLife Challenge"
            )
        case .joy:
            return SurveyPaywallCopy(
                headline: "Find a joy the world cannot steal.",
                subheadline: "Not happiness. The real thing — deep, unshakeable, God-given joy.",
                valueProps: [
                    SurveyValueProp(icon: "sun.max.fill", title: "Joy that outlasts circumstances", description: "God's Word planted daily grows a gladness the world cannot take."),
                    SurveyValueProp(icon: "music.note", title: "Speak gladness over heaviness", description: "Declaring God's promises out loud lifts what the day tries to put on you."),
                    SurveyValueProp(icon: "arrow.counterclockwise.circle.fill", title: "Start mornings with His delight", description: "Audio devotionals tune your heart to God's joy before anything else speaks."),
                    SurveyValueProp(icon: "person.2.fill", title: "Rooted in the God of joy", description: "Join believers whose joy is anchored in Christ, not circumstances.")
                ],
                ctaText: "Start My 30-Day SpeakLife Challenge",
                urgencyText: "3 Days Free • Cancel Anytime",
                challengeName: "30-Day SpeakLife Challenge"
            )
        case .confidence:
            return SurveyPaywallCopy(
                headline: "Walk like you know who made you.",
                subheadline: "God did not give you a spirit of fear. It's time to start living like it.",
                valueProps: [
                    SurveyValueProp(icon: "bolt.fill", title: "Bold in every room", description: "Daily declarations build confidence anchored in who made you, not how you feel."),
                    SurveyValueProp(icon: "crown.fill", title: "Speak boldness until it sticks", description: "Your voice agreeing with God's Word dismantles timidity at the root."),
                    SurveyValueProp(icon: "figure.stand", title: "Courage in your ears daily", description: "Audio devotionals remind you whose you are before doubt gets a word in."),
                    SurveyValueProp(icon: "person.2.fill", title: "Fearless in your identity", description: "Join believers walking in God-given boldness every day.")
                ],
                ctaText: "Start My 30-Day SpeakLife Challenge",
                urgencyText: "3 Days Free • Cancel Anytime",
                challengeName: "30-Day SpeakLife Challenge"
            )
        case .healing:
            return SurveyPaywallCopy(
                headline: "What broke, God restores.",
                subheadline: "Healing isn't just physical. SpeakLife speaks God's Word over your whole person.",
                valueProps: [
                    SurveyValueProp(icon: "leaf.fill", title: "Speak life over your body", description: "Daily healing declarations put God's promises over every diagnosis and pain."),
                    SurveyValueProp(icon: "heart.fill", title: "Faith stronger than fear", description: "Renew your mind daily until God's promises outweigh every report."),
                    SurveyValueProp(icon: "waveform.path.ecg", title: "Healing promises in your ears", description: "Audio devotionals soak your mind in God's restoring Word, morning and night."),
                    SurveyValueProp(icon: "person.2.fill", title: "Whole in body and soul", description: "Join believers speaking God's healing over their lives.")
                ],
                ctaText: "Start My 30-Day SpeakLife Challenge",
                urgencyText: "3 Days Free • Cancel Anytime",
                challengeName: "30-Day SpeakLife Challenge"
            )
        case .prosperity:
            return SurveyPaywallCopy(
                headline: "You were made to walk in overflow.",
                subheadline: "God's Word has more to say about abundance than you've been taught. Start speaking it.",
                valueProps: [
                    SurveyValueProp(icon: "star.fill", title: "Break the scarcity mindset", description: "Daily abundance declarations renew how you see provision, money, and overflow."),
                    SurveyValueProp(icon: "briefcase.fill", title: "Speak increase over your finances", description: "Declaring God's promises out loud shifts your beliefs, then your decisions."),
                    SurveyValueProp(icon: "arrow.up.forward.circle.fill", title: "Provision promises every morning", description: "Audio devotionals fill your ears with God's abundance before the world preaches lack."),
                    SurveyValueProp(icon: "person.2.fill", title: "An heir, not a beggar", description: "Join believers walking in God's overflow together.")
                ],
                ctaText: "Start My 30-Day SpeakLife Challenge",
                urgencyText: "3 Days Free • Cancel Anytime",
                challengeName: "30-Day SpeakLife Challenge"
            )
        }
    }

    var notificationCopy: SurveyNotificationCopy {
        guard let word = goalWord else { return defaultNotificationCopy }
        switch word {
        case .peace:
            return SurveyNotificationCopy(
                headline: "Protect Your 30-Day Habit",
                subheadline: "Peace isn't found in a moment — it's built over 30 days of speaking God's truth louder than your fear. Don't miss a single day.",
                statLine: "Users who set a daily reminder are 4x more likely to complete their 30-day reset",
                ctaText: "Yes, Build My Peace Habit"
            )
        case .identity:
            return SurveyNotificationCopy(
                headline: "Protect Your 30-Day Habit",
                subheadline: "Identity is rebuilt through daily repetition. 30 days of declarations replaces the old story with what God actually says about you.",
                statLine: "Users with daily reminders are 4x more likely to finish their 30-day reset",
                ctaText: "Yes, Build My Identity Habit"
            )
        case .purpose:
            return SurveyNotificationCopy(
                headline: "Protect Your 30-Day Habit",
                subheadline: "Purpose is walked into one obedient day at a time. 30 days of daily declarations builds the momentum that changes your trajectory.",
                statLine: "Consistency over 30 days is the #1 predictor of breakthrough",
                ctaText: "Yes, Build My Purpose Habit"
            )
        case .joy:
            return SurveyNotificationCopy(
                headline: "Protect Your 30-Day Habit",
                subheadline: "Joy is a muscle. 30 days of declaring it daily — even when it doesn't feel true — is what makes it permanent.",
                statLine: "92% of users who set reminders report lasting mood shifts within 30 days",
                ctaText: "Yes, Build My Joy Habit"
            )
        case .confidence:
            return SurveyNotificationCopy(
                headline: "Protect Your 30-Day Habit",
                subheadline: "Confidence isn't a feeling you wait for — it's a habit you build. 30 days of showing up daily is what changes who you are.",
                statLine: "30 days of daily declarations creates measurable shifts in self-perception",
                ctaText: "Yes, Build My Confidence Habit"
            )
        case .healing:
            return SurveyNotificationCopy(
                headline: "Protect Your 30-Day Habit",
                subheadline: "Healing happens in agreement with God's Word — daily, consistently, over time. 30 days builds the foundation restoration stands on.",
                statLine: "Consistent daily declaration over 30 days is the foundation of restoration",
                ctaText: "Yes, Build My Healing Habit"
            )
        case .prosperity:
            return SurveyNotificationCopy(
                headline: "Protect Your 30-Day Habit",
                subheadline: "Abundance starts in the mind before it shows up in your life. 30 days of speaking it daily is what shifts your beliefs — and your decisions.",
                statLine: "30 days of daily abundance declarations rewire your financial beliefs",
                ctaText: "Yes, Build My Abundance Habit"
            )
        }
    }

    private var defaultPaywallCopy: SurveyPaywallCopy {
        SurveyPaywallCopy(
            headline: "Become Unshakable — One Declaration at a Time",
            subheadline: "Join believers who chose God's truth over their feelings.",
            valueProps: [
                SurveyValueProp(icon: "book.fill", title: "Declarations made for you", description: "God's Word spoken over your exact situation, every single morning."),
                SurveyValueProp(icon: "bolt.fill", title: "Speak truth, take ground", description: "Spoken Scripture is your greatest weapon. It is how Jesus won every battle."),
                SurveyValueProp(icon: "headphones", title: "Faith comes by hearing", description: "Audio devotionals put God's promises in your ears morning and night."),
                SurveyValueProp(icon: "person.2.fill", title: "Unshakeable identity in Christ", description: "Join believers who know who they are in Him.")
            ],
            ctaText: "Begin My Faith Reset",
            urgencyText: "3 Days Free • Cancel Anytime",
            challengeName: "30-Day SpeakLife Challenge"
        )
    }

    private var defaultNotificationCopy: SurveyNotificationCopy {
        SurveyNotificationCopy(
            headline: "Protect Your 30-Day Habit",
            subheadline: "Real change isn't a moment — it's 30 days of showing up. Set your daily reminder and don't miss a day.",
            statLine: "Users with daily reminders are 4x more likely to complete their 30-day reset",
            ctaText: "Yes, Build My Daily Habit"
        )
    }
}
