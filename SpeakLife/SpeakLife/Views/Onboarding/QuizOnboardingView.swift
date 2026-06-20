//
//  QuizOnboardingView.swift
//  SpeakLife
//
//  Personalized onboarding (Treatment cohort of useQuizOnboarding A/B). Routes
//  the user from one of 4 felt-need ad campaigns through a 6-question belief
//  sequence — every answer (right OR wrong) is reinforced with a spoken
//  scripture-anchored declaration so they're sold on the app's core mechanic
//  before the paywall. Unsegmented ("Just exploring") users skip the belief
//  sequence and route straight to PersonalDeclaration + CommitmentHold.
//
//  Spec: DEV_TICKET_Onboarding_Quiz.md (+ Aug 2026 belief-sequence expansion).
//

import SwiftUI
import FirebaseAnalytics
import UserNotifications
import UIKit

// MARK: - QuizSegment

enum QuizSegment: String, CaseIterable {
    case battlefieldMind   = "battlefield_mind"
    case believerAuthority = "believer_authority"
    case alreadyYours      = "already_yours"
    case hisHeart          = "his_heart"
    case unsegmented       = "unsegmented"

    var buttonHeadline: String {
        switch self {
        case .battlefieldMind:   return "My thoughts won't stop."
        case .believerAuthority: return "I've prayed for years. Nothing's moved."
        case .alreadyYours:      return "I'm tired of begging for what's already mine."
        case .hisHeart:          return "I need to feel God's love again."
        case .unsegmented:       return "Just exploring — show me everything."
        }
    }

    var buttonSubhead: String {
        switch self {
        case .battlefieldMind:   return "Anxiety. Fear. 3am wake-ups."
        case .believerAuthority: return "Praying harder isn't working."
        case .alreadyYours:      return "Healing, provision, peace — already paid for."
        case .hisHeart:          return "He feels far. I'm tired of striving."
        case .unsegmented:       return ""
        }
    }

    var mirrorHeadline: String {
        switch self {
        case .battlefieldMind:   return "You're in a battle for your mind."
        case .believerAuthority: return "Long prayers aren't the answer. Authority is."
        case .alreadyYours:      return "You've been working for what's already yours."
        case .hisHeart:          return "He's not far. He's been waiting."
        case .unsegmented:       return "Welcome to SpeakLife."
        }
    }

    var mirrorBody: String {
        switch self {
        case .battlefieldMind:   return "You're not crazy. You're not powerless. There's a Scripture written for this exact storm."
        case .believerAuthority: return "Jesus didn't beg the storm. He spoke to it. You can too."
        case .alreadyYours:      return "Time to stop begging. Start agreeing."
        case .hisHeart:          return "Let's get His love on your lips every morning."
        case .unsegmented:       return "Speak the truth. Win the day."
        }
    }

    var declarationText: String {
        switch self {
        case .battlefieldMind:
            return "I take every thought captive to the obedience of Christ. No fear, no lie, no anxiety has authority over my mind."
        case .believerAuthority:
            return "Whatsoever I say to this mountain, believing, shall come to pass. I speak with authority, not in begging."
        case .alreadyYours:
            return "His divine power has GIVEN unto me all things that pertain unto life and godliness. I receive what's already mine."
        case .hisHeart:
            return "As the Father has loved me, so have I loved you. I am deeply, specifically, eternally loved."
        case .unsegmented:
            return "I am more than a conqueror through Christ who loves me. I take more ground today than I took yesterday."
        }
    }

    var declarationVerse: String {
        switch self {
        case .battlefieldMind:   return "2 Corinthians 10:5"
        case .believerAuthority: return "Mark 11:23"
        case .alreadyYours:      return "2 Peter 1:3"
        case .hisHeart:          return "John 15:9"
        case .unsegmented:       return "Romans 8:37"
        }
    }

    var paywallHeadline: String {
        switch self {
        case .battlefieldMind:   return "Take every thought captive."
        case .believerAuthority: return "Stop begging. Start agreeing."
        case .alreadyYours:      return "Claim what's already yours."
        case .hisHeart:          return "Hear Him speak love over you."
        case .unsegmented:       return "Speak life today."
        }
    }

    // Trial details live in the plan section below, so the subhead leads with the
    // promise instead of repeating "Start your 3-day free trial."
    var paywallSubheadline: String {
        switch self {
        case .battlefieldMind:   return "Speak truth before the next 3am wake-up."
        case .believerAuthority: return "Speak God's Word with authority, every day."
        case .alreadyYours:      return "Everything He's already given, claimed daily."
        case .hisHeart:          return "Receive His love every single morning."
        case .unsegmented:       return "Join \(SocialProof.believersCount) believers who do this daily."
        }
    }

    var primaryCategory: DeclarationCategory {
        switch self {
        case .battlefieldMind:   return .anxiety
        case .believerAuthority: return .confidence
        case .alreadyYours:      return .wealth
        case .hisHeart:          return .godsheart
        case .unsegmented:       return .destiny
        }
    }

    var notificationCategories: Set<DeclarationCategory> {
        switch self {
        case .battlefieldMind:   return [.anxiety, .rest, .identity, .fear]
        case .believerAuthority: return [.faith, .confidence, .destiny, .praise]
        case .alreadyYours:      return [.wealth, .health, .grace, .favor]
        case .hisHeart:          return [.godsheart, .love, .identity, .grace]
        case .unsegmented:       return [.destiny, .faith, .identity, .grace, .joy, .rest]
        }
    }
}

// MARK: - BeliefQuestion

struct BeliefAnswer: Identifiable, Equatable {
    let id: String
    let label: String
    let isConfident: Bool
    let declaration: String
    let verseReference: String
}

enum BeliefQuestion: Int, CaseIterable {
    // Ordered for a love → worthiness → promises → response → mechanic → authority
    // theological arc. Foundation first (lowest barrier to entry), authority last
    // (sends them into the matched declaration with the right posture).
    case godLoves         = 0
    case tooMessedUp      = 1
    case promisesTrue     = 2
    case answersPrayer    = 3
    case wordIsPowerful   = 4
    case authority        = 5

    static var count: Int { allCases.count }

    var analyticsId: String {
        switch self {
        case .godLoves:       return "god_loves"
        case .answersPrayer:  return "god_answers_prayer"
        case .promisesTrue:   return "promises_for_me"
        case .tooMessedUp:    return "too_messed_up"
        case .wordIsPowerful: return "word_is_powerful"
        case .authority:      return "authority_over_enemy"
        }
    }

    var headline: String {
        switch self {
        case .godLoves:
            return "Right now, today — do you really believe God loves you?"
        case .tooMessedUp:
            return "Deep down — do you ever feel too far gone for God?"
        case .promisesTrue:
            return "When you read God's promises — does your heart hear 'this is mine'?"
        case .answersPrayer:
            return "When you pray — do you actually expect God to answer?"
        case .wordIsPowerful:
            return "Does God's Word actually move things when YOU speak it?"
        case .authority:
            return "Do you know you have authority over the enemy?"
        }
    }

    var subhead: String? {
        switch self {
        case .godLoves:       return "Be honest. There's a Scripture for you either way."
        case .tooMessedUp:    return "Shame loses its grip the second you name it."
        case .promisesTrue:   return "Pick what's true today — not what you wish was true."
        case .answersPrayer:  return "Your honest answer here is sacred. Pick it."
        case .wordIsPowerful: return "This one matters. Everything in SpeakLife flows from this."
        case .authority:      return "This is the one that changes everything."
        }
    }

    var answers: [BeliefAnswer] {
        switch self {
        case .godLoves: return [
            BeliefAnswer(
                id: "love_yes",
                label: "Yes. He's crazy about me.",
                isConfident: true,
                declaration: "God isn't just OK with me. He delights in me. While I was still a mess, Christ died for me. I am fully, finally, forever loved.",
                verseReference: "Romans 5:8"
            ),
            BeliefAnswer(
                id: "love_uncertain",
                label: "I want to. I don't always feel it.",
                isConfident: false,
                declaration: "I am rooted and grounded in love. The Father's love for me is wider, longer, higher, deeper than anything I feel today.",
                verseReference: "Ephesians 3:17-18"
            ),
            BeliefAnswer(
                id: "love_general_not_me",
                label: "He loves people. Me specifically? Not sure.",
                isConfident: false,
                declaration: "The Father Himself loves me. Not the crowd. Me. By name. Right now.",
                verseReference: "John 16:27"
            ),
            BeliefAnswer(
                id: "love_unearned",
                label: "Honestly? I don't think I've earned it.",
                isConfident: false,
                declaration: "I am loved by grace. Not by performance. Nothing I do earns it. Nothing I do can lose it. His love is the floor, not the ceiling.",
                verseReference: "Ephesians 2:8-9"
            )
        ]

        case .answersPrayer: return [
            BeliefAnswer(
                id: "answers_yes",
                label: "Yes. He hears me. Always.",
                isConfident: true,
                declaration: "Whatever I ask in line with His will, He hears me. And if He hears me, I already have what I asked.",
                verseReference: "1 John 5:14-15"
            ),
            BeliefAnswer(
                id: "answers_unsure",
                label: "He hears. I'm not sure He answers.",
                isConfident: false,
                declaration: "My prayer is powerful and effective because I've been made right with God in Christ. Heaven leans in when I speak.",
                verseReference: "James 5:16"
            ),
            BeliefAnswer(
                id: "answers_others_not_me",
                label: "He answers others. Mine go silent.",
                isConfident: false,
                declaration: "The Lord is near to all who call on Him. He hears MY cry. He inclines His ear to ME. He answers.",
                verseReference: "Psalm 145:18-19"
            ),
            BeliefAnswer(
                id: "answers_stopped_asking",
                label: "I stopped asking. It's been too long.",
                isConfident: false,
                declaration: "What looks like silence is preparation. The answer is racing toward me. I will not stop asking before God finishes answering.",
                verseReference: "Habakkuk 2:3"
            )
        ]

        case .promisesTrue: return [
            BeliefAnswer(
                id: "promises_yes",
                label: "Yes. Every one has my name on it.",
                isConfident: true,
                declaration: "Every promise of God is YES and AMEN in Christ. Through me. For me. To His glory.",
                verseReference: "2 Corinthians 1:20"
            ),
            BeliefAnswer(
                id: "promises_intellectual",
                label: "I believe them. Claiming them feels harder.",
                isConfident: false,
                declaration: "His divine power has ALREADY given me everything I need for life and godliness. Past tense. Done deal. I stop asking and start receiving.",
                verseReference: "2 Peter 1:3-4"
            ),
            BeliefAnswer(
                id: "promises_not_mature",
                label: "Maybe for the spiritually mature. Not someone like me.",
                isConfident: false,
                declaration: "I am a child of Abraham. I am an heir of the promise. There is no junior class in the Kingdom. The promises are for me now.",
                verseReference: "Galatians 3:29"
            ),
            BeliefAnswer(
                id: "promises_then_not_now",
                label: "Those were Bible times. I don't see them today.",
                isConfident: false,
                declaration: "Jesus Christ is the same yesterday, today, and forever. What He did then, He does now. In me. Through me. For me.",
                verseReference: "Hebrews 13:8"
            )
        ]

        case .tooMessedUp: return [
            BeliefAnswer(
                id: "messed_no",
                label: "No. He picked me on purpose.",
                isConfident: true,
                declaration: "I am a new creation in Christ. The old me is gone. God chose me on purpose. For purpose.",
                verseReference: "2 Corinthians 5:17"
            ),
            BeliefAnswer(
                id: "messed_some_days",
                label: "Some days yeah. Some days no.",
                isConfident: false,
                declaration: "There is NO condemnation for me, because I am in Christ. I refuse to keep paying a bill He already paid in full.",
                verseReference: "Romans 8:1"
            ),
            BeliefAnswer(
                id: "messed_forgiven_not_used",
                label: "Forgiven, yeah. Useful to Him? Not so sure.",
                isConfident: false,
                declaration: "God picks the unlikely. He didn't disqualify me. He drafted me. My past is the testimony, not the verdict.",
                verseReference: "1 Corinthians 1:27-28"
            ),
            BeliefAnswer(
                id: "messed_hidden_shame",
                label: "If He really knew me, He'd be done with me.",
                isConfident: false,
                declaration: "He's already searched me. He sees all of it. And still calls me His. Still loved. Still chosen. Nothing hidden has changed His mind.",
                verseReference: "Psalm 139:1-3"
            )
        ]

        case .wordIsPowerful: return [
            BeliefAnswer(
                id: "word_yes",
                label: "Yes. When I speak it, something shifts.",
                isConfident: true,
                declaration: "The Word of God is alive and active, sharper than any sword. When I speak it, heaven moves and hell trembles.",
                verseReference: "Hebrews 4:12"
            ),
            BeliefAnswer(
                id: "word_open_inexperienced",
                label: "I believe it. I've just never really tried.",
                isConfident: false,
                declaration: "Faith comes by hearing. Hearing comes by the Word. When I speak truth, my own ears hear it, and faith rises in me.",
                verseReference: "Romans 10:17"
            ),
            BeliefAnswer(
                id: "word_pastors_not_me",
                label: "Powerful for pastors. Not sure about me.",
                isConfident: false,
                declaration: "I speak directly to my mountain. I don't doubt in my heart. What I declare in Jesus' name is done.",
                verseReference: "Mark 11:23"
            ),
            BeliefAnswer(
                id: "word_symbolic",
                label: "Words are symbolic. They don't change anything.",
                isConfident: false,
                declaration: "God spoke. And there was light. He made me in His image. When my words agree with His, they carry weight.",
                verseReference: "Genesis 1:3"
            )
        ]

        case .authority: return [
            BeliefAnswer(
                id: "authority_yes",
                label: "Yes. I speak — the enemy flees.",
                isConfident: true,
                declaration: "I have authority to trample on serpents and scorpions, and over all the power of the enemy. Nothing shall harm me.",
                verseReference: "Luke 10:19"
            ),
            BeliefAnswer(
                id: "authority_unsure_how",
                label: "Yes — but I freeze when it matters.",
                isConfident: false,
                declaration: "I don't need to learn authority. I need to BELIEVE it. I am seated with Christ, far above every power, principality, and dominion. I already have it.",
                verseReference: "Ephesians 2:6"
            ),
            BeliefAnswer(
                id: "authority_not_for_me",
                label: "Spiritual warfare feels too dramatic for my real life.",
                isConfident: false,
                declaration: "The weapons of my warfare are not natural. They're mighty in God for tearing down strongholds. This is for my real, daily life.",
                verseReference: "2 Corinthians 10:4"
            ),
            BeliefAnswer(
                id: "authority_defeated",
                label: "I feel powerless. The enemy is winning.",
                isConfident: false,
                declaration: "Greater is He who is in me than he who is in the world. I am not a victim. I submit to God. I resist the devil. And he flees.",
                verseReference: "1 John 4:4; James 4:7"
            )
        ]
        }
    }
}

// MARK: - QuizOnboardingView

struct QuizOnboardingView: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var declarationStore: DeclarationViewModel
    let size: CGSize
    let onComplete: () -> Void

    static let quizVersion = "v3_burden"

    enum Step: Int, CaseIterable {
        case quiz
        case mirror
        case beliefSequence
        case burdenSelection   // 2-axis personalization: drives matched declaration content + home category
        case matchedDeclaration
        case rating            // App Store review prompt — slotted before paywall so every funnel-progress user sees it (ASO velocity); placed AFTER matched declaration so the user has had at least one personalized payoff and BEFORE personalDeclaration/paywall so it doesn't compete with the trial decision
        case personalDeclaration
        case commitmentHold
        case paywall
        case notificationTime  // post-paywall: pick a window, then iOS permission prompt
    }

    @State private var currentStep: Step = .quiz
    @State private var selectedSegment: QuizSegment? = nil
    @State private var beliefIndex: Int = 0
    @State private var currentBeliefAnswer: BeliefAnswer? = nil
    @State private var selectedBurden: HeaviestBurden? = nil
    @State private var savedPersonalDeclaration: PersonalDeclaration? = nil
    @State private var quizShownAt: Date = Date()
    @State private var stepEnteredAt: Date = Date()

    // Backing model for SurveyQ8NotificationScreen so we can reuse that
    // screen verbatim (same UI as Control's notification picker). We only
    // populate heaviestBurden (for the subtitle/preview) and notificationTime
    // (set by the user's pick on the screen).
    @StateObject private var notificationResponses = SurveyResponses()

    private var segment: QuizSegment { selectedSegment ?? .unsegmented }

    // Burden drives the matched declaration content + the home/Daily Burst
    // category seed. Falls back to segment-specific defaults if the user
    // somehow lands at the matched declaration without picking a burden
    // (shouldn't happen — the burden screen is in-flow — but defensive).
    private var matchedDeclarationText: String {
        if let preview = selectedBurden?.previewDeclaration {
            return preview.text
        }
        return segment.declarationText
    }

    private var matchedDeclarationVerse: String {
        if let preview = selectedBurden?.previewDeclaration {
            return preview.reference
        }
        return segment.declarationVerse
    }

    var body: some View {
        ZStack {
            backgroundView

            Group {
                switch currentStep {
                case .quiz:
                    QuizQuestionScreen(size: size) { picked in
                        handleAnswer(picked)
                    }
                case .mirror:
                    QuizMirrorScreen(size: size, segment: segment) {
                        advanceFromMirror()
                    }
                case .beliefSequence:
                    beliefSequenceView
                case .burdenSelection:
                    BurdenSelectionScreen(size: size) { burden in
                        handleBurdenAnswer(burden)
                    }
                case .matchedDeclaration:
                    QuizDeclarationScreen(
                        size: size,
                        text: matchedDeclarationText,
                        verse: matchedDeclarationVerse
                    ) {
                        advanceFromMatchedDeclaration()
                    }
                case .personalDeclaration:
                    PersonalDeclarationOnboardingView(
                        viewModel: DIContainer.shared.makePersonalDeclarationViewModel(),
                        size: size
                    ) { declaration in
                        savedPersonalDeclaration = declaration
                        advanceFromPersonalDeclaration()
                    }
                case .commitmentHold:
                    SurveyCommitmentHoldScreen(size: size) {
                        advanceFromCommitmentHold()
                    }
                case .paywall:
                    HighConversionPaywallView(callback: {
                        advanceFromPaywall()
                    }, source: "onboarding", isHardPaywall: true)
                case .notificationTime:
                    SurveyQ8NotificationScreen(
                        size: size,
                        responses: notificationResponses,
                        onContinue: {
                            advanceFromNotificationTime()
                        }
                    )
                case .rating:
                    RatingView(size: size) {
                        advanceFromRating()
                    }
                }
            }
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .offset(x: 0, y: 24)),
                removal: .opacity.combined(with: .offset(x: 0, y: -16))
            ))
            .id(transitionId)
        }
        .ignoresSafeArea()
        .onAppear {
            quizShownAt = Date()
            stepEnteredAt = Date()
            AnalyticsService.shared.track("onboarding_quiz_shown", parameters: [
                "quiz_version": Self.quizVersion
            ])
        }
    }

    // Drives SwiftUI to re-run transitions when we move within the belief
    // sequence or flip from question to response.
    private var transitionId: String {
        if currentStep == .beliefSequence {
            let phase = currentBeliefAnswer == nil ? "q" : "r"
            return "belief-\(beliefIndex)-\(phase)"
        }
        return "step-\(currentStep.rawValue)"
    }

    @ViewBuilder
    private var beliefSequenceView: some View {
        if let question = BeliefQuestion(rawValue: beliefIndex) {
            if let answer = currentBeliefAnswer {
                BeliefResponseScreen(
                    size: size,
                    question: question,
                    answer: answer,
                    progressIndex: beliefIndex,
                    progressTotal: BeliefQuestion.count
                ) {
                    speakBeliefAnswer(question: question, answer: answer)
                }
            } else {
                BeliefQuestionScreen(
                    size: size,
                    question: question,
                    progressIndex: beliefIndex,
                    progressTotal: BeliefQuestion.count
                ) { picked in
                    selectBeliefAnswer(question: question, answer: picked)
                }
            }
        } else {
            // Defensive fallback — should never hit because speakBeliefAnswer
            // advances out of .beliefSequence once beliefIndex >= count.
            Color.clear.onAppear { transition(to: .matchedDeclaration) }
        }
    }

    private var backgroundView: some View {
        ZStack {
            Image(subscriptionStore.onboardingBGImage)
                .resizable().aspectRatio(contentMode: .fill)
                .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                .clipped()
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.82),
                    Color.black.opacity(0.55),
                    Color.black.opacity(0.72)
                ]),
                startPoint: .top, endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }

    // MARK: - Step transitions

    private func handleAnswer(_ picked: QuizSegment) {
        Juice.play(.tapLight)
        selectedSegment = picked
        appState.onboardingSegment = picked.rawValue
        appState.onboardingQuizVersion = Self.quizVersion

        let timeToAnswer = Int(Date().timeIntervalSince(quizShownAt))
        AnalyticsService.shared.track("onboarding_quiz_answered", parameters: [
            "quiz_version": Self.quizVersion,
            "answer": picked.rawValue,
            "time_to_answer_seconds": timeToAnswer
        ])

        // Every cohort — including 'Just exploring' (unsegmented) — runs the
        // full flow: mirror → 6 belief Qs → burden → matched declaration →
        // PersonalDeclaration → CommitmentHold → paywall. The unsegmented
        // mirror is a generic welcome ('Speak the truth. Win the day.') —
        // they still get every belief-barrier reinforcement before pricing.
        transition(to: .mirror)
        AnalyticsService.shared.track("onboarding_mirror_shown", parameters: [
            "segment": picked.rawValue
        ])
    }

    private func advanceFromMirror() {
        Juice.play(.tapLight)
        beliefIndex = 0
        currentBeliefAnswer = nil
        transition(to: .beliefSequence)
        fireBeliefShown(BeliefQuestion(rawValue: 0)!)
    }

    private func selectBeliefAnswer(question: BeliefQuestion, answer: BeliefAnswer) {
        Juice.play(.tapLight)
        AnalyticsService.shared.track("onboarding_belief_answered", parameters: [
            "question_id": question.analyticsId,
            "question_index": question.rawValue,
            "answer_id": answer.id,
            "is_confident": answer.isConfident,
            "segment": segment.rawValue
        ])
        withAnimation(.easeInOut(duration: 0.3)) {
            currentBeliefAnswer = answer
        }
        stepEnteredAt = Date()
    }

    private func speakBeliefAnswer(question: BeliefQuestion, answer: BeliefAnswer) {
        Juice.play(.tapLight)
        AnalyticsService.shared.track("onboarding_belief_spoken", parameters: [
            "question_id": question.analyticsId,
            "question_index": question.rawValue,
            "answer_id": answer.id,
            "segment": segment.rawValue,
            "time_on_screen_seconds": Int(Date().timeIntervalSince(stepEnteredAt))
        ])

        let nextIndex = beliefIndex + 1
        if let nextQuestion = BeliefQuestion(rawValue: nextIndex) {
            withAnimation(.easeInOut(duration: 0.35)) {
                beliefIndex = nextIndex
                currentBeliefAnswer = nil
            }
            stepEnteredAt = Date()
            fireBeliefShown(nextQuestion)
        } else {
            // Belief sequence complete → burden selection (diagnostic axis)
            transition(to: .burdenSelection)
            fireBurdenShown()
        }
    }

    private func handleBurdenAnswer(_ burden: HeaviestBurden) {
        Juice.play(.tapLight)
        selectedBurden = burden

        // Persist downstream so HighConversionPaywallView's surveyEngine path
        // (used as fallback when segment is .unsegmented) renders personalized
        // copy, and so NotificationScene + other surveyGoalWord readers stay
        // wired up the same way they were under the Control onboarding.
        let goalWord = burden.goalWord
        appState.surveyGoalWord = goalWord.rawValue
        appState.selectedDeclarationStyles = [burden.declarationStyle.rawValue]

        AnalyticsService.shared.track("onboarding_burden_answered", parameters: [
            "segment": segment.rawValue,
            "burden": burden.rawValue,
            "goal_word": goalWord.rawValue,
            "time_to_answer_seconds": Int(Date().timeIntervalSince(stepEnteredAt))
        ])

        // Ask for notification permission now — the user has just told us their
        // struggle, so this is the contextual moment to offer daily declarations
        // for it. Scheduling still happens after they pick a time post-paywall.
        requestNotificationPermissionAtBurdenSelection()

        transition(to: .matchedDeclaration)
        fireMatchedDeclarationShown()
    }

    private func requestNotificationPermissionAtBurdenSelection() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            AnalyticsService.shared.track("notification_permission", parameters: [
                "granted": granted,
                "source": "quiz_onboarding_burden"
            ])
            DispatchQueue.main.async {
                appState.notificationEnabled = granted
                if granted {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }

    private func advanceFromMatchedDeclaration() {
        Juice.play(.tapLight)
        let timeOnScreen = Int(Date().timeIntervalSince(stepEnteredAt))
        AnalyticsService.shared.track("onboarding_first_declaration_spoken", parameters: [
            "segment": segment.rawValue,
            "burden": selectedBurden?.rawValue ?? "none",
            "declaration_id": matchedDeclarationVerse,
            "time_on_screen_seconds": timeOnScreen
        ])
        transition(to: .personalDeclaration)
    }

    private func advanceFromPersonalDeclaration() {
        Juice.play(.tapLight)
        appState.hasPersonalDeclaration = savedPersonalDeclaration != nil
        AnalyticsService.shared.track("onboarding_personal_declaration_completed", parameters: [
            "segment": segment.rawValue,
            "set_personal_declaration": (savedPersonalDeclaration != nil) as NSNumber
        ])
        // App Store review prompt at the emotional peak — right after the user
        // has spoken their OWN declaration aloud — and still BEFORE the paywall
        // so it never competes with or gets soured by the pricing decision.
        AnalyticsService.shared.track("onboarding_rating_step_shown", parameters: [
            "segment": segment.rawValue,
            "position": "post_personal_declaration"
        ])
        transition(to: .rating)
    }

    private func advanceFromCommitmentHold() {
        Juice.play(.tapLight)
        // Apply segment defaults BEFORE the paywall renders so the paywall
        // (and the analytics events fired from it) see the chosen segment.
        applySegmentDefaults()
        let totalDuration = Int(Date().timeIntervalSince(quizShownAt))
        AnalyticsService.shared.track("onboarding_completed", parameters: [
            "segment": segment.rawValue,
            "total_duration_seconds": totalDuration
        ])
        transition(to: .paywall)
    }

    private func advanceFromPaywall() {
        // We pass isHardPaywall: true here, but actual hardness is gated by
        // Remote Config `showPayWhatYouCanLink`. When that flag is false the
        // only path that fires this callback is a successful purchase. When
        // it's true the close button reappears and dismiss also advances.
        // Seed the screen with the burden so its subtitle and preview render
        // the user's matched declaration text instead of a generic fallback.
        notificationResponses.heaviestBurden = selectedBurden
        AnalyticsService.shared.track("onboarding_notification_time_shown", parameters: [
            "segment": segment.rawValue
        ])
        transition(to: .notificationTime)
    }

    private func advanceFromNotificationTime() {
        Juice.play(.tapLight)
        if let notifTime = notificationResponses.notificationTime {
            appState.startTimeIndex = notifTime.startTimeIndex
            appState.endTimeIndex   = notifTime.endTimeIndex
            // Mirror to the personal declaration push time — same pattern
            // SurveyOnboardingView uses for the survey flow's notification step.
            appState.personalDeclarationTimeIndex = notifTime.startTimeIndex
            AnalyticsService.shared.track("onboarding_notification_time_picked", parameters: [
                "segment": segment.rawValue,
                "notification_time": notifTime.rawValue
            ])
        }
        finishOnboarding()
    }

    private func finishOnboarding() {
        // Schedule notifications from ONLY the user's primary category — same
        // category seeded into home + Daily Burst in applySegmentDefaults.
        // Previously expanded to a hardcoded 4-category mix, which surfaced
        // pushes from categories the user never picked.
        let primaryCategory = selectedBurden?.goalWord.declarationCategory ?? segment.primaryCategory
        let categories: Set<DeclarationCategory> = [primaryCategory]
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            AnalyticsService.shared.track("notification_permission", parameters: [
                "granted": granted,
                "source": "quiz_onboarding"
            ])
            DispatchQueue.main.async {
                appState.notificationEnabled = granted
                if granted {
                    UIApplication.shared.registerForRemoteNotifications()
                    NotificationManager.shared.registerNotifications(
                        count: appState.notificationCount,
                        startTime: appState.startTimeIndex,
                        endTime: appState.endTimeIndex,
                        categories: categories
                    )
                    appState.lastNotificationSetDate = Date()
                }
                // Rating step now fires earlier in the funnel (right after
                // matchedDeclaration) so non-converters see it too. By the
                // time we finish onboarding the user has already been asked,
                // and the 3-day local throttle in requestReviewIfEligible
                // would suppress a second ask anyway — so skip straight to
                // onComplete.
                onComplete()
            }
        }
    }

    private func advanceFromRating() {
        Juice.play(.tapLight)
        // Rating now lives right after personalDeclaration (the emotional peak),
        // so advancing continues into the commitment hold and then the paywall.
        transition(to: .commitmentHold)
    }

    private func transition(to step: Step) {
        withAnimation(.easeInOut(duration: 0.35)) {
            currentStep = step
        }
        stepEnteredAt = Date()
    }

    private func fireBeliefShown(_ question: BeliefQuestion) {
        AnalyticsService.shared.track("onboarding_belief_shown", parameters: [
            "question_id": question.analyticsId,
            "question_index": question.rawValue,
            "segment": segment.rawValue
        ])
    }

    private func fireBurdenShown() {
        AnalyticsService.shared.track("onboarding_burden_shown", parameters: [
            "segment": segment.rawValue
        ])
    }

    private func fireMatchedDeclarationShown() {
        AnalyticsService.shared.track("onboarding_first_declaration_shown", parameters: [
            "segment": segment.rawValue,
            "burden": selectedBurden?.rawValue ?? "none",
            "declaration_id": matchedDeclarationVerse
        ])
    }

    private func applySegmentDefaults() {
        appState.onboardingCompletedAt = Date()

        // Two-axis personalization:
        //   - Burden (diagnostic axis) drives the actual content seeded into
        //     home + Daily Burst + push notifications.
        //   - Segment (ad-match axis) drives paywall framing already applied
        //     in HighConversionPaywallView.
        let burdenGoalWord = selectedBurden?.goalWord
        let category = burdenGoalWord?.declarationCategory ?? segment.primaryCategory

        UserDefaults.standard.set(category.rawValue, forKey: "selectedCategory")
        UserPreferencesTracker.shared.trackCategorySelection(category.rawValue)
        declarationStore.choose(category) { _ in }

        // Notifications scheduled from ONLY this category — matches the home
        // feed seeded above. Pushes shouldn't surface content from categories
        // the user didn't pick.
        appState.selectedNotificationCategories = category.rawValue
    }
}

// MARK: - Screen 1: Quiz

private struct QuizQuestionScreen: View {
    let size: CGSize
    let onSelect: (QuizSegment) -> Void

    private let primaryAnswers: [QuizSegment] = [
        .battlefieldMind, .believerAuthority, .alreadyYours, .hisHeart
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: size.height * 0.10)

            VStack(spacing: 12) {
                Text("Welcome.")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("Before we start, what brought you here today?")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                Text("Pick the one that hits closest. We'll match Scripture to your storm.")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer().frame(height: 28)

            VStack(spacing: 12) {
                ForEach(primaryAnswers, id: \.self) { segment in
                    AnswerButton(segment: segment, isPrimary: true) {
                        onSelect(segment)
                    }
                }
            }
            .padding(.horizontal, 24)

            Spacer().frame(height: 20)

            AnswerButton(segment: .unsegmented, isPrimary: false) {
                onSelect(.unsegmented)
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    private struct AnswerButton: View {
        let segment: QuizSegment
        let isPrimary: Bool
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(segment.buttonHeadline)
                        .font(.system(size: isPrimary ? 16 : 14, weight: isPrimary ? .semibold : .regular))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                    if !segment.buttonSubhead.isEmpty {
                        Text(segment.buttonSubhead)
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.leading)
                    }
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 18)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(isPrimary ? Color.white.opacity(0.12) : Color.white.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.white.opacity(isPrimary ? 0.25 : 0.12), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel(Text(segment.buttonHeadline))
            .accessibilityHint(Text(segment.buttonSubhead.isEmpty ? "Select this answer" : segment.buttonSubhead))
        }
    }
}

// MARK: - Screen 2: Mirror

private struct QuizMirrorScreen: View {
    let size: CGSize
    let segment: QuizSegment
    let onAdvance: () -> Void

    @State private var autoAdvanceTask: DispatchWorkItem? = nil

    var body: some View {
        VStack {
            Spacer()
            VStack(spacing: 18) {
                Text(segment.mirrorHeadline)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                Text(segment.mirrorBody)
                    .font(.system(size: 17))
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            Spacer()
            Text("Tap to continue")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
                .padding(.bottom, size.height * 0.08)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            triggerAdvance()
        }
        .onAppear {
            let task = DispatchWorkItem { triggerAdvance() }
            autoAdvanceTask = task
            DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: task)
        }
        .onDisappear {
            autoAdvanceTask?.cancel()
        }
    }

    private func triggerAdvance() {
        guard autoAdvanceTask?.isCancelled == false else { return }
        autoAdvanceTask?.cancel()
        onAdvance()
    }
}

// MARK: - Belief sequence screens

private struct BeliefProgressBar: View {
    let index: Int
    let total: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<total, id: \.self) { i in
                Capsule()
                    .fill(i <= index ? Color.white.opacity(0.9) : Color.white.opacity(0.18))
                    .frame(height: 3)
            }
        }
        .frame(maxWidth: 220)
    }
}

private struct BeliefQuestionScreen: View {
    let size: CGSize
    let question: BeliefQuestion
    let progressIndex: Int
    let progressTotal: Int
    let onSelect: (BeliefAnswer) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: size.height * 0.08)

            BeliefProgressBar(index: progressIndex, total: progressTotal)
                .padding(.bottom, 14)

            VStack(spacing: 12) {
                Text(question.headline)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                if let subhead = question.subhead {
                    Text(subhead)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 36)
                }
            }

            Spacer().frame(height: 24)

            VStack(spacing: 10) {
                ForEach(question.answers) { answer in
                    Button(action: { onSelect(answer) }) {
                        Text(answer.label)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .padding(.vertical, 14)
                            .padding(.horizontal, 18)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.white.opacity(0.10))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(Color.white.opacity(0.22), lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityLabel(Text(answer.label))
                }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }
}

private struct BeliefResponseScreen: View {
    let size: CGSize
    let question: BeliefQuestion
    let answer: BeliefAnswer
    let progressIndex: Int
    let progressTotal: Int
    let onSpoken: () -> Void

    @State private var isPressed = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: size.height * 0.08)

            BeliefProgressBar(index: progressIndex, total: progressTotal)
                .padding(.bottom, 16)

            Text(answer.isConfident ? "Stand on this." : "Hear what God says.")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white.opacity(0.9))
                .textCase(.uppercase)
                .tracking(1.6)

            Spacer()

            VStack(spacing: 22) {
                Text("\u{201C}\(answer.declaration)\u{201D}")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 26)
                Text(answer.verseReference)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.65))
            }

            Spacer()

            Button(action: {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                    isPressed = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    onSpoken()
                }
            }) {
                Text(speakLabel)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 28)
                            .fill(LinearGradient(
                                colors: [Constants.DAMidBlue, Constants.DAMidBlue.opacity(0.85)],
                                startPoint: .leading, endPoint: .trailing
                            ))
                    )
                    .scaleEffect(isPressed ? 1.04 : 1.0)
                    .shadow(color: Constants.DAMidBlue.opacity(0.4),
                            radius: isPressed ? 16 : 8, x: 0, y: 4)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 24)
            .padding(.bottom, size.height * 0.06)
            .accessibilityLabel(Text(speakLabel))
        }
    }

    private var speakLabel: String {
        progressIndex == progressTotal - 1
            ? "Speak this — and continue."
            : "Speak this out loud."
    }
}

// MARK: - Matched declaration (segment-specific)

private struct QuizDeclarationScreen: View {
    let size: CGSize
    let text: String
    let verse: String
    let onSpoken: () -> Void

    @State private var isPressed = false

    var body: some View {
        VStack {
            Spacer()
            VStack(spacing: 24) {
                Text("Your verse for this storm.")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
                    .textCase(.uppercase)
                    .tracking(1.6)
                Text("\u{201C}\(text)\u{201D}")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                Text(verse)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.65))
            }
            Spacer()
            Button(action: {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                    isPressed = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    onSpoken()
                }
            }) {
                Text("Speak this out loud.")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 28)
                            .fill(LinearGradient(
                                colors: [Constants.DAMidBlue, Constants.DAMidBlue.opacity(0.85)],
                                startPoint: .leading, endPoint: .trailing
                            ))
                    )
                    .scaleEffect(isPressed ? 1.04 : 1.0)
                    .shadow(color: Constants.DAMidBlue.opacity(0.4),
                            radius: isPressed ? 16 : 8, x: 0, y: 4)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 24)
            .padding(.bottom, size.height * 0.08)
            .accessibilityLabel(Text("Speak this declaration out loud."))
        }
    }
}

// MARK: - Burden selection (diagnostic axis)

private struct BurdenSelectionScreen: View {
    let size: CGSize
    let onSelect: (HeaviestBurden) -> Void

    // Curated subset that maps cleanly to the matched-declaration content.
    // Order is rough most-common-first to maximize tap rate on the visible
    // options without scroll.
    private let options: [HeaviestBurden] = [
        .peace, .health, .identity, .joy, .purpose, .abundance, .allOfIt
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: size.height * 0.08)

            Text("Last question.")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white.opacity(0.9))
                .textCase(.uppercase)
                .tracking(1.6)

            Text("What do you need MOST from God right now?")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.top, 10)

            Text("We'll match Scripture to where you actually are.")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
                .padding(.top, 8)

            Spacer().frame(height: 20)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    ForEach(options, id: \.self) { burden in
                        BurdenButton(burden: burden) {
                            onSelect(burden)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, size.height * 0.04)
            }
        }
    }

    private struct BurdenButton: View {
        let burden: HeaviestBurden
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                HStack(spacing: 14) {
                    Text(burden.icon)
                        .font(.system(size: 26))
                        .frame(width: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(burden.rawValue)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                        if !burden.description.isEmpty {
                            Text(burden.description)
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.65))
                                .multilineTextAlignment(.leading)
                        }
                    }
                    Spacer()
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white.opacity(0.10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.white.opacity(0.22), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel(Text(burden.rawValue))
            .accessibilityHint(Text(burden.description))
        }
    }
}
