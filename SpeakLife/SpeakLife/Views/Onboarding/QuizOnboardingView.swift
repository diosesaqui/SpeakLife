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
        case .battlefieldMind:   return "My thoughts are out of control."
        case .believerAuthority: return "I've prayed for years and nothing's moved."
        case .alreadyYours:      return "I keep begging for what God already gave me."
        case .hisHeart:          return "I need to feel His love again."
        case .unsegmented:       return "Just exploring — show me everything."
        }
    }

    var buttonSubhead: String {
        switch self {
        case .battlefieldMind:   return "Anxiety, fear, 3am wake-ups."
        case .believerAuthority: return ""
        case .alreadyYours:      return ""
        case .hisHeart:          return ""
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
        case .battlefieldMind:   return "You're not alone, and you're not powerless. There's a Scripture written for this exact storm."
        case .believerAuthority: return "Jesus didn't beg the storm. He spoke to it. So can you."
        case .alreadyYours:      return "It's time to stop begging and start agreeing."
        case .hisHeart:          return "Let's put His love in your mouth daily."
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

    var paywallSubheadline: String {
        switch self {
        case .battlefieldMind:   return "Start your 3-day free trial. Speak truth before the next 3am wake-up."
        case .believerAuthority: return "Start your 3-day free trial. Speak God's Word with authority."
        case .alreadyYours:      return "Start your 3-day free trial. Stop earning what He's already given."
        case .hisHeart:          return "Start your 3-day free trial. Receive His love every morning."
        case .unsegmented:       return "Start your 3-day free trial. 500,000+ believers do this daily."
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
    case godLoves         = 0
    case answersPrayer    = 1
    case promisesTrue     = 2
    case tooMessedUp      = 3
    case wordIsPowerful   = 4
    case faithStrength    = 5

    static var count: Int { allCases.count }

    var analyticsId: String {
        switch self {
        case .godLoves:       return "god_loves"
        case .answersPrayer:  return "god_answers_prayer"
        case .promisesTrue:   return "promises_for_me"
        case .tooMessedUp:    return "too_messed_up"
        case .wordIsPowerful: return "word_is_powerful"
        case .faithStrength:  return "faith_strength"
        }
    }

    var headline: String {
        switch self {
        case .godLoves:
            return "Do you believe God loves you — right now, today, exactly as you are?"
        case .answersPrayer:
            return "Do you believe God hears and answers when you pray?"
        case .promisesTrue:
            return "When you read God's promises in Scripture — are they for you?"
        case .tooMessedUp:
            return "Have you ever felt too far gone for God to fully accept or use you?"
        case .wordIsPowerful:
            return "Do you believe God's Word has real power when YOU speak it out loud?"
        case .faithStrength:
            return "Does your faith have to feel strong for God to move on your behalf?"
        }
    }

    var subhead: String? {
        switch self {
        case .godLoves:       return "Be honest. There's a Scripture waiting either way."
        case .answersPrayer:  return "Whichever you pick, the Word has an answer."
        case .promisesTrue:   return "Pick what's true today, not what you wish was true."
        case .tooMessedUp:    return "Shame thrives in silence. Let's bring it into the light."
        case .wordIsPowerful: return "This one matters. Speaking life is what this app is built on."
        case .faithStrength:  return "Mustard-seed faith counts. Let's see what God says about yours."
        }
    }

    var answers: [BeliefAnswer] {
        switch self {
        case .godLoves: return [
            BeliefAnswer(
                id: "love_yes",
                label: "Yes. Completely and unconditionally.",
                isConfident: true,
                declaration: "God demonstrates His love for me in this: while I was still a sinner, Christ died for me. I am fully, finally, eternally loved.",
                verseReference: "Romans 5:8"
            ),
            BeliefAnswer(
                id: "love_uncertain",
                label: "I want to believe it. I don't always feel it.",
                isConfident: false,
                declaration: "I am rooted and established in love. The Father's love for me is wider, longer, higher, and deeper than my feelings can measure.",
                verseReference: "Ephesians 3:17-18"
            ),
            BeliefAnswer(
                id: "love_general_not_me",
                label: "He loves people. Me specifically? I'm not sure.",
                isConfident: false,
                declaration: "The Father Himself loves me. Not the crowd. Me. Specifically. Personally. Right now.",
                verseReference: "John 16:27"
            ),
            BeliefAnswer(
                id: "love_unearned",
                label: "I don't think I've earned His love yet.",
                isConfident: false,
                declaration: "I am loved by grace alone. Nothing I do earns it. Nothing I fail at can lose it. His love is the foundation, not the reward.",
                verseReference: "Ephesians 2:8-9"
            )
        ]

        case .answersPrayer: return [
            BeliefAnswer(
                id: "answers_yes",
                label: "Yes. He hears and answers in His timing.",
                isConfident: true,
                declaration: "I have confidence that whatever I ask according to His will, He hears me. And if He hears me, I have what I asked of Him.",
                verseReference: "1 John 5:14-15"
            ),
            BeliefAnswer(
                id: "answers_unsure",
                label: "He hears. I'm not sure He answers me.",
                isConfident: false,
                declaration: "My prayers are powerful and effective because I am made right with God in Christ. Heaven leans in when I speak.",
                verseReference: "James 5:16"
            ),
            BeliefAnswer(
                id: "answers_others_not_me",
                label: "He answers others. Mine stay silent.",
                isConfident: false,
                declaration: "The Lord is near to all who call on Him. He hears MY cry, He inclines His ear to ME, and He answers.",
                verseReference: "Psalm 145:18-19"
            ),
            BeliefAnswer(
                id: "answers_stopped_asking",
                label: "I've stopped asking. It's been too long.",
                isConfident: false,
                declaration: "What looks like silence is preparation. The answer hastens toward me. I refuse to stop asking before God finishes answering.",
                verseReference: "Habakkuk 2:3"
            )
        ]

        case .promisesTrue: return [
            BeliefAnswer(
                id: "promises_yes",
                label: "Yes. Every promise has my name on it.",
                isConfident: true,
                declaration: "Every promise of God is YES and AMEN in Christ Jesus — through me, to the glory of God.",
                verseReference: "2 Corinthians 1:20"
            ),
            BeliefAnswer(
                id: "promises_intellectual",
                label: "I believe them. I struggle to claim them.",
                isConfident: false,
                declaration: "His divine power has GIVEN me everything I need for life and godliness. The promises are already mine. I receive them today.",
                verseReference: "2 Peter 1:3-4"
            ),
            BeliefAnswer(
                id: "promises_not_mature",
                label: "Maybe for the spiritually mature. Not me yet.",
                isConfident: false,
                declaration: "I am a child of Abraham — an heir according to the promise. There is no junior class in the Kingdom of God.",
                verseReference: "Galatians 3:29"
            ),
            BeliefAnswer(
                id: "promises_then_not_now",
                label: "Those were Bible times. I don't see them now.",
                isConfident: false,
                declaration: "Jesus Christ is the same yesterday, today, and forever. What God did then, He does now — in me, through me, for me.",
                verseReference: "Hebrews 13:8"
            )
        ]

        case .tooMessedUp: return [
            BeliefAnswer(
                id: "messed_no",
                label: "No. He chose me knowing exactly who I am.",
                isConfident: true,
                declaration: "I am a new creation in Christ. The old has gone, the new has come. God chose me on purpose, for purpose.",
                verseReference: "2 Corinthians 5:17"
            ),
            BeliefAnswer(
                id: "messed_some_days",
                label: "Some days yes, some days no.",
                isConfident: false,
                declaration: "There is NO condemnation for me because I am in Christ Jesus. I refuse to live under what He already paid for.",
                verseReference: "Romans 8:1"
            ),
            BeliefAnswer(
                id: "messed_forgiven_not_used",
                label: "Forgiven, maybe. Useful to Him? Not so sure.",
                isConfident: false,
                declaration: "God chose the foolish, the weak, the lowly — to shame the strong. He didn't disqualify me. He drafted me.",
                verseReference: "1 Corinthians 1:27-28"
            ),
            BeliefAnswer(
                id: "messed_hidden_shame",
                label: "If He really knew, He'd be done with me.",
                isConfident: false,
                declaration: "He has searched me and knows me fully. He sees everything — and still calls me His own. Still loved. Still chosen.",
                verseReference: "Psalm 139:1-3"
            )
        ]

        case .wordIsPowerful: return [
            BeliefAnswer(
                id: "word_yes",
                label: "Yes. There's authority in spoken Scripture.",
                isConfident: true,
                declaration: "The Word of God is alive and active, sharper than any double-edged sword. When I speak it, heaven moves.",
                verseReference: "Hebrews 4:12"
            ),
            BeliefAnswer(
                id: "word_open_inexperienced",
                label: "I believe it — I've just never really tried.",
                isConfident: false,
                declaration: "Faith comes by hearing — and hearing by the Word of God. When I speak truth, my own ears hear it, and faith rises in me.",
                verseReference: "Romans 10:17"
            ),
            BeliefAnswer(
                id: "word_pastors_not_me",
                label: "Powerful for pastors. Not sure about me.",
                isConfident: false,
                declaration: "Jesus said I will say to this mountain MOVE, and it will move. That authority belongs to me through His name.",
                verseReference: "Mark 11:23"
            ),
            BeliefAnswer(
                id: "word_symbolic",
                label: "Words are symbolic. They don't really change anything.",
                isConfident: false,
                declaration: "God spoke and there was light. He made me in His image. My words carry weight when they agree with His.",
                verseReference: "Genesis 1:3"
            )
        ]

        case .faithStrength: return [
            BeliefAnswer(
                id: "faith_no",
                label: "No. He works with whatever faith I have.",
                isConfident: true,
                declaration: "Faith the size of a mustard seed moves mountains. My faith — small as it is today — is enough because He is enough.",
                verseReference: "Matthew 17:20"
            ),
            BeliefAnswer(
                id: "faith_stuck",
                label: "I think so. That's why I feel stuck.",
                isConfident: false,
                declaration: "I cry, 'Lord, I believe — help my unbelief.' He honors the smallest yes I can offer Him today.",
                verseReference: "Mark 9:24"
            ),
            BeliefAnswer(
                id: "faith_compare",
                label: "Strong faith helps. Mine doesn't qualify.",
                isConfident: false,
                declaration: "He is faithful even when I am faithless — He cannot disown Himself. His character qualifies me, not my performance.",
                verseReference: "2 Timothy 2:13"
            ),
            BeliefAnswer(
                id: "faith_law",
                label: "Yes. Strong faith means results.",
                isConfident: false,
                declaration: "It is by grace I am saved through faith — and even this faith is a gift from God. He gives me what I need to believe.",
                verseReference: "Ephesians 2:8"
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

    static let quizVersion = "v2_belief"

    enum Step: Int, CaseIterable {
        case quiz
        case mirror
        case beliefSequence
        case matchedDeclaration
        case personalDeclaration
        case commitmentHold
        case paywall
    }

    @State private var currentStep: Step = .quiz
    @State private var selectedSegment: QuizSegment? = nil
    @State private var beliefIndex: Int = 0
    @State private var currentBeliefAnswer: BeliefAnswer? = nil
    @State private var savedPersonalDeclaration: PersonalDeclaration? = nil
    @State private var quizShownAt: Date = Date()
    @State private var stepEnteredAt: Date = Date()

    private var segment: QuizSegment { selectedSegment ?? .unsegmented }

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
                case .matchedDeclaration:
                    QuizDeclarationScreen(
                        size: size,
                        text: segment.declarationText,
                        verse: segment.declarationVerse
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
                        finishOnboarding()
                    }, source: "onboarding")
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
            Analytics.logEvent("onboarding_quiz_shown", parameters: [
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
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        selectedSegment = picked
        appState.onboardingSegment = picked.rawValue
        appState.onboardingQuizVersion = Self.quizVersion

        let timeToAnswer = Int(Date().timeIntervalSince(quizShownAt))
        Analytics.logEvent("onboarding_quiz_answered", parameters: [
            "quiz_version": Self.quizVersion,
            "answer": picked.rawValue,
            "time_to_answer_seconds": timeToAnswer
        ])

        if picked == .unsegmented {
            // "Just exploring" → bypass mirror + belief sequence + matched
            // declaration. Drop them straight into PersonalDeclaration so they
            // still create something before paywall.
            transition(to: .personalDeclaration)
        } else {
            transition(to: .mirror)
            Analytics.logEvent("onboarding_mirror_shown", parameters: [
                "segment": picked.rawValue
            ])
        }
    }

    private func advanceFromMirror() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        beliefIndex = 0
        currentBeliefAnswer = nil
        transition(to: .beliefSequence)
        fireBeliefShown(BeliefQuestion(rawValue: 0)!)
    }

    private func selectBeliefAnswer(question: BeliefQuestion, answer: BeliefAnswer) {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        Analytics.logEvent("onboarding_belief_answered", parameters: [
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
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        Analytics.logEvent("onboarding_belief_spoken", parameters: [
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
            // Belief sequence complete → matched declaration
            transition(to: .matchedDeclaration)
            fireDeclarationShown(for: segment)
        }
    }

    private func advanceFromMatchedDeclaration() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        let timeOnScreen = Int(Date().timeIntervalSince(stepEnteredAt))
        Analytics.logEvent("onboarding_first_declaration_spoken", parameters: [
            "segment": segment.rawValue,
            "declaration_id": segment.declarationVerse,
            "time_on_screen_seconds": timeOnScreen
        ])
        transition(to: .personalDeclaration)
    }

    private func advanceFromPersonalDeclaration() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        appState.hasPersonalDeclaration = savedPersonalDeclaration != nil
        Analytics.logEvent("onboarding_personal_declaration_completed", parameters: [
            "segment": segment.rawValue,
            "set_personal_declaration": (savedPersonalDeclaration != nil) as NSNumber
        ])
        transition(to: .commitmentHold)
    }

    private func advanceFromCommitmentHold() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        // Apply segment defaults BEFORE the paywall renders so the paywall
        // (and the analytics events fired from it) see the chosen segment.
        applySegmentDefaults()
        let totalDuration = Int(Date().timeIntervalSince(quizShownAt))
        Analytics.logEvent("onboarding_completed", parameters: [
            "segment": segment.rawValue,
            "total_duration_seconds": totalDuration
        ])
        transition(to: .paywall)
    }

    private func finishOnboarding() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            Analytics.logEvent("notification_permission", parameters: [
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
                        categories: segment.notificationCategories
                    )
                    appState.lastNotificationSetDate = Date()
                }
                onComplete()
            }
        }
    }

    private func transition(to step: Step) {
        withAnimation(.easeInOut(duration: 0.35)) {
            currentStep = step
        }
        stepEnteredAt = Date()
    }

    private func fireBeliefShown(_ question: BeliefQuestion) {
        Analytics.logEvent("onboarding_belief_shown", parameters: [
            "question_id": question.analyticsId,
            "question_index": question.rawValue,
            "segment": segment.rawValue
        ])
    }

    private func fireDeclarationShown(for segment: QuizSegment) {
        Analytics.logEvent("onboarding_first_declaration_shown", parameters: [
            "segment": segment.rawValue,
            "declaration_id": segment.declarationVerse
        ])
    }

    private func applySegmentDefaults() {
        appState.onboardingCompletedAt = Date()

        let category = segment.primaryCategory
        UserDefaults.standard.set(category.rawValue, forKey: "selectedCategory")
        UserPreferencesTracker.shared.trackCategorySelection(category.rawValue)
        declarationStore.choose(category) { _ in }

        appState.selectedNotificationCategories = segment.notificationCategories
            .map { $0.rawValue }
            .joined(separator: ",")
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
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.65))
                .textCase(.uppercase)
                .tracking(1.4)

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
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.65))
                    .textCase(.uppercase)
                    .tracking(1.4)
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
