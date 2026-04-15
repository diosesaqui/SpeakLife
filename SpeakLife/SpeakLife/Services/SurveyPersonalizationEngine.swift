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
                headline: "Anxiety Has Had Enough of You.",
                subheadline: "3 minutes of God's Word every morning rewires how your brain responds to fear.",
                valueProps: [
                    SurveyValueProp(icon: "wind", title: "Declarations for Peace", description: "Targeted scripture over anxiety, fear, and worry — spoken out loud, daily."),
                    SurveyValueProp(icon: "moon.stars.fill", title: "Night-Mode Declarations", description: "Quiet your mind before bed with promises that stop anxious thoughts cold."),
                    SurveyValueProp(icon: "brain.head.profile", title: "Mind Renewal Track", description: "A 21-day plan to replace fear-thinking with Kingdom-thinking."),
                    SurveyValueProp(icon: "person.2.fill", title: "100,000+ Believers Praying", description: "You are not fighting this alone. Never were.")
                ],
                ctaText: "Start My 30-Day SpeakLife Challenge",
                urgencyText: "3 Days Free • Cancel Anytime",
                challengeName: "30-Day SpeakLife Challenge"
            )
        case .identity:
            return SurveyPaywallCopy(
                headline: "It's Time to Know Who God Says You Are.",
                subheadline: "You've believed the lie long enough. God wrote a different story about you.",
                valueProps: [
                    SurveyValueProp(icon: "sparkles", title: "Identity Declarations", description: "Scripture that dismantles 'I'm not enough' and replaces it with who God says you are."),
                    SurveyValueProp(icon: "book.fill", title: "Identity Devotionals", description: "Daily readings that anchor your worth in God, not performance."),
                    SurveyValueProp(icon: "repeat.circle.fill", title: "21-Day Identity Reset", description: "A guided journey from self-doubt to unshakeable God-confidence."),
                    SurveyValueProp(icon: "person.2.fill", title: "100,000+ Believers Standing With You", description: "A community declaring truth over each other every single day.")
                ],
                ctaText: "Start My 30-Day SpeakLife Challenge",
                urgencyText: "3 Days Free • Cancel Anytime",
                challengeName: "30-Day SpeakLife Challenge"
            )
        case .purpose:
            return SurveyPaywallCopy(
                headline: "Your Calling Is Waiting to Be Walked Into.",
                subheadline: "God wrote your destiny before you were born. SpeakLife helps you walk into it.",
                valueProps: [
                    SurveyValueProp(icon: "flame.fill", title: "Purpose Declarations", description: "Speak boldness, clarity, and calling into existence every morning."),
                    SurveyValueProp(icon: "map.fill", title: "Destiny Devotionals", description: "Daily word for those who feel they were made for more — because you were."),
                    SurveyValueProp(icon: "arrow.up.forward.circle.fill", title: "Purpose Activation Track", description: "A 21-day plan for those stepping into their God-given assignment."),
                    SurveyValueProp(icon: "person.2.fill", title: "100,000+ Believers Pursuing Their Calling", description: "A community of people who refused to stay small.")
                ],
                ctaText: "Start My 30-Day SpeakLife Challenge",
                urgencyText: "3 Days Free • Cancel Anytime",
                challengeName: "30-Day SpeakLife Challenge"
            )
        case .joy:
            return SurveyPaywallCopy(
                headline: "Find a Joy the World Cannot Steal.",
                subheadline: "Not happiness. The real thing — deep, unshakeable, God-given joy.",
                valueProps: [
                    SurveyValueProp(icon: "sun.max.fill", title: "Joy Declarations", description: "Scripture that restores gladness when life has drained it from you."),
                    SurveyValueProp(icon: "music.note", title: "Joy Audio Devotionals", description: "Start your day with praise that shifts your atmosphere in minutes."),
                    SurveyValueProp(icon: "arrow.counterclockwise.circle.fill", title: "21-Day Joy Restoration", description: "A guided plan to reignite what grief, stress, or burnout took from you."),
                    SurveyValueProp(icon: "person.2.fill", title: "100,000+ Believers Choosing Joy Daily", description: "Proof that it's possible — and that you won't be doing it alone.")
                ],
                ctaText: "Start My 30-Day SpeakLife Challenge",
                urgencyText: "3 Days Free • Cancel Anytime",
                challengeName: "30-Day SpeakLife Challenge"
            )
        case .confidence:
            return SurveyPaywallCopy(
                headline: "Walk Like You Know Who Made You.",
                subheadline: "God did not give you a spirit of fear. It's time to start living like it.",
                valueProps: [
                    SurveyValueProp(icon: "bolt.fill", title: "Confidence Declarations", description: "Speak boldness into your DNA — daily, out loud, until it sticks."),
                    SurveyValueProp(icon: "crown.fill", title: "Identity in Christ Track", description: "Know your position so thoroughly that doubt can't find a foothold."),
                    SurveyValueProp(icon: "figure.stand", title: "Bold Living Devotionals", description: "Daily readings for those stepping into rooms they almost talked themselves out of."),
                    SurveyValueProp(icon: "person.2.fill", title: "100,000+ Believers Walking in Authority", description: "A community of people who decided to stop living small.")
                ],
                ctaText: "Start My 30-Day SpeakLife Challenge",
                urgencyText: "3 Days Free • Cancel Anytime",
                challengeName: "30-Day SpeakLife Challenge"
            )
        case .healing:
            return SurveyPaywallCopy(
                headline: "What Broke — God Restores.",
                subheadline: "Healing isn't just physical. SpeakLife speaks God's Word over your whole person.",
                valueProps: [
                    SurveyValueProp(icon: "leaf.fill", title: "Healing Declarations", description: "God's promises over your body, mind, and soul — spoken aloud every day."),
                    SurveyValueProp(icon: "heart.fill", title: "Restoration Devotionals", description: "Daily word for those walking through grief, loss, sickness, or broken seasons."),
                    SurveyValueProp(icon: "waveform.path.ecg", title: "Healing Scriptures Track", description: "A 21-day journey through God's promises for wholeness."),
                    SurveyValueProp(icon: "person.2.fill", title: "100,000+ Believers Standing in Faith", description: "A community praying for healing and breakthrough — together.")
                ],
                ctaText: "Start My 30-Day SpeakLife Challenge",
                urgencyText: "3 Days Free • Cancel Anytime",
                challengeName: "30-Day SpeakLife Challenge"
            )
        case .prosperity:
            return SurveyPaywallCopy(
                headline: "You Were Made to Walk in Overflow.",
                subheadline: "God's Word has more to say about abundance than you've been taught. Start speaking it.",
                valueProps: [
                    SurveyValueProp(icon: "star.fill", title: "Wealth & Abundance Declarations", description: "Scripture-backed declarations over your finances, provision, and breakthrough."),
                    SurveyValueProp(icon: "briefcase.fill", title: "Prosperity Devotionals", description: "Daily word for those building something — and believing God for increase."),
                    SurveyValueProp(icon: "arrow.up.forward.circle.fill", title: "Kingdom Abundance Track", description: "A 21-day plan to renew your money mindset with what God actually says."),
                    SurveyValueProp(icon: "person.2.fill", title: "100,000+ Believers Walking in Blessing", description: "A community declaring abundance over each other every single day.")
                ],
                ctaText: "Start My 30-Day SpeakLife Challenge",
                urgencyText: "3 Days Free • Cancel Anytime",
                challengeName: "30-Day SpeakLife Challenge"
            )
        }
    }

    var notificationCopy: SurveyNotificationCopy {
        guard let word = goalWord else { return defaultNotificationCopy }
        let challenge = word.challengeName
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
            subheadline: "Join 100,000+ believers who chose God's truth over their feelings.",
            valueProps: [
                SurveyValueProp(icon: "bolt.fill", title: "Daily Declarations", description: "God's Word spoken over your exact situation, every morning."),
                SurveyValueProp(icon: "headphones", title: "Audio Devotionals", description: "Immersive faith content you can absorb on the go."),
                SurveyValueProp(icon: "book.fill", title: "Scripture-Based Plans", description: "Guided 21-day tracks built around what you're believing for."),
                SurveyValueProp(icon: "person.2.fill", title: "100,000+ Believers", description: "A community declaring truth over each other every single day.")
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
