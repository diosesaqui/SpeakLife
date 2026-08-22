//
//  DirectOnboardingView.swift
//  SpeakLife
//
//  The pain-led arm. Every other arm opens by talking — a storm scene, a
//  thief, a promise, a nearness statement — and only asks the user what is
//  actually wrong five or six screens in. This one inverts that completely:
//
//    0. Declaration — "What brought you here today?" on the very first frame,
//                     asked open, answered in their own words, and answered by
//                     the product: a declaration matched to their actual
//                     situation, with the verse it stands on and "read it out
//                     loud right now."
//    0a. Picker     — ONLY if that produced nothing (skipped, declined,
//                     unmatchable). Seven taps, so a user who wouldn't type
//                     still leaves with a seeded feed instead of a generic app.
//    0b. Retry      — the same feature re-asked narrow, scoped to the tap:
//                     "You said your mind won't stop racing. What's it racing
//                     about?" A blank open question asks for a summary of your
//                     life; this asks for one fact, which is a much smaller
//                     thing to give and is aimed at exactly the users about to
//                     leave with nothing. Skipping again is fine.
//    1. Mechanism   — how Jesus answered every problem. Deliberately AFTER,
//                     because for anyone who answered it is no longer a claim
//                     about what speaking does: it is the explanation of
//                     something they just did. "That's authority. You spoke to
//                     your mountain just like Jesus" beats promising they will.
//    2. Proof       — the review wall, immediately before the ask.
//    3. Paywall
//    4. Time        — when their declaration arrives daily (terminal).
//
//  Screen zero is the arm. There is nothing in front of it: no logo, no scene,
//  no pitch, no category list. The first thing that happens is the product
//  doing its one job on the user's real situation, and everything after it is
//  interpreting or selling what already happened. The picker exists only so
//  that a refusal to type is not also a refusal to be personalized, and the
//  pain it captures is read back out of the matcher's own classification for
//  everyone else, so nobody is asked the same question twice in two formats.
//
//  Mechanically it still writes the same `SurveyResponses.heaviestBurden` the
//  other arms write, so the shared back-half screens, the category seeding,
//  and the notification scheduling all work unchanged.
//
//  One arm of the onboarding A/B: HomeView routes here when Remote Config
//  `onboardingVariant` == "direct".
//

import SwiftUI
import UserNotifications

struct DirectOnboardingView: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var declarationStore: DeclarationViewModel
    let size: CGSize
    let onComplete: () -> Void

    // Reuse the survey response model so the shared back-half screens and the
    // seeding logic work unchanged. Only `heaviestBurden` (the opening
    // question) and `notificationTime` (the terminal screen) are ever set.
    @StateObject private var responses = SurveyResponses()
    @State private var currentStep: DirectStep = .declaration

    /// The declaration the user got back after describing their situation, or
    /// nil if they skipped or the match failed. Kept so completion (and
    /// therefore conversion) can be split by whether they actually reached the
    /// payoff this arm is built around.
    @State private var savedDeclaration: PersonalDeclaration? = nil

    /// Which ask actually produced the declaration: the open question on frame
    /// one, the narrow retry after the picker, or neither. This is the number
    /// that says whether the recovery ladder is worth its screens.
    @State private var declarationSource = "none"

    /// The resolved pain, at the matcher's granularity rather than the picker's
    /// seven. Set from the declaration's own category when there is one, from
    /// the picked burden when there isn't. Drives the mechanism screen's copy
    /// and the segment the paywall reads.
    @State private var pain: UserPain? = nil

    /// Funnel entry time, for `total_duration_seconds`. Set in onAppear rather
    /// than at init so it measures time on screen, not time since the struct
    /// was built.
    @State private var startedAt: Date? = nil

    var body: some View {
        ZStack(alignment: .top) {
            backgroundView

            currentStepView
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .offset(x: 0, y: 24)),
                    removal: .opacity.combined(with: .offset(x: 0, y: -16))
                ))
                .id(currentStep.rawValue)

        }
        .ignoresSafeArea()
        .onAppear {
            if startedAt == nil { startedAt = Date() }
            AnalyticsService.shared.track("direct_onboarding_started", parameters: [
                "flow_schema": DirectStep.flowSchema
            ])
        }
    }

    @ViewBuilder
    private var currentStepView: some View {
        switch currentStep {
        case .declaration:
            // Frame one, and the real feature rather than a demo of it. The
            // question IS "what brought you here" — asked open, in their own
            // words, so the answer is a situation the matcher can work with
            // instead of a category they picked off a list.
            PersonalDeclarationOnboardingView(
                viewModel: DIContainer.shared.makePersonalDeclarationViewModel(),
                size: size,
                flow: "direct",
                prompt: "What brought you\nhere today?"
            ) { declaration in
                savedDeclaration = declaration
                if declaration != nil { declarationSource = "open" }
                advance()
            }
        case .painFallback:
            // Only reached when the declaration produced nothing — skipped,
            // declined, or unmatchable. Without it those users would carry no
            // category at all: generic feed, generic notifications, generic
            // paywall. One tap is the cheapest possible way to recover them.
            DirectPainScreen(size: size, responses: responses) { advance() }
        case .declarationRetry:
            // The same feature, re-asked narrow. The open question was declined,
            // so this one is scoped to what they just tapped and asks for a
            // single fact rather than a summary of their life — a much smaller
            // ask, aimed at the users most likely to leave with nothing.
            // Skipping again is still fine; it just lands on the mechanism.
            PersonalDeclarationOnboardingView(
                viewModel: DIContainer.shared.makePersonalDeclarationViewModel(),
                size: size,
                // Distinct flow tag so the retry's take-rate is separable from
                // the frame-one ask's — the whole point of running it.
                flow: "direct_retry",
                prompt: DirectPain.prompt(for: responses.heaviestBurden),
                contextLine: DirectPain.echoLine(for: responses.heaviestBurden)
            ) { declaration in
                savedDeclaration = declaration
                if declaration != nil { declarationSource = "retry" }
                advance()
            }
        case .mechanism:
            DirectMechanismScreen(
                size: size,
                pain: pain ?? .more,
                spokeDeclaration: savedDeclaration != nil
            ) { advance() }
        case .testimonials:
            TestimonialWallView(size: size, flow: "direct") { advance() }
        case .paywall:
            HighConversionPaywallView(callback: { advance() }, source: "onboarding", isHardPaywall: true)
        case .notificationTime:
            SurveyQ8NotificationScreen(size: size, responses: responses, flow: "direct") { advance() }
        }
    }

    private func advance() {
        Juice.play(.tapLight)
        // `step_name` is the one to build funnels on — the raw Int is only kept
        // so a renumbering is detectable against `flow_schema`.
        AnalyticsService.shared.track("direct_step_completed", parameters: [
            "step": currentStep.rawValue,
            "step_name": currentStep.name,
            "flow_schema": DirectStep.flowSchema
        ])

        // Leaving either declaration ask: read the pain back out of the match.
        // The matcher already classified what they wrote — at its own
        // granularity, not the picker's seven — so a user who answered never
        // has to be asked a second time in a different format, and never gets
        // rounded off to a bucket that doesn't fit them.
        if currentStep == .declaration || currentStep == .declarationRetry,
           let declaration = savedDeclaration {
            let resolved = UserPain.from(categoryRaw: declaration.categoryRaw)
            pain = resolved
            responses.heaviestBurden = resolved.burden
        }

        // The picker only speaks the coarse vocabulary, so widen it back out.
        if currentStep == .painFallback, let burden = responses.heaviestBurden, pain == nil {
            pain = UserPain.from(segment: burden.shortLabel)
        }

        // Whichever way the pain arrived, stamp the segment so every downstream
        // paywall event carries a meaningful one, and pin it as a person
        // property so EVERY later event — trial_started, subscription_started,
        // retention — can be split by what the user actually came in carrying.
        if let pain,
           currentStep == .declaration || currentStep == .painFallback || currentStep == .declarationRetry {
            appState.onboardingSegment = "direct_\(pain.rawValue)"
            AnalyticsService.shared.setUserProperty("onboarding_burden", value: pain.rawValue)
        }

        // Leaving the review wall is the last pre-paywall milestone, which is
        // where the quiz arm fires `onboarding_completed` — step 1 of the
        // Activation → Trial funnel. Firing it here in the same shape (segment
        // + duration) is what puts this arm into that funnel at all; without it
        // the arm is invisible there. Split that funnel by the
        // `onboarding_variant` person property to read the arms apart.
        if currentStep == .testimonials {
            AnalyticsService.shared.track("onboarding_completed", parameters: [
                "segment": appState.onboardingSegment,
                "variant": "direct",
                "total_duration_seconds": elapsedSeconds
            ])
        }

        switch currentStep {
        case .notificationTime:
            applyResponsesAndComplete()
        default:
            var nextRaw = currentStep.rawValue + 1
            // The picker and the retry are both recovery, not part of the flow.
            // A user whose declaration landed has already told us more than
            // either could, so they skip straight past both.
            if savedDeclaration != nil {
                while let candidate = DirectStep(rawValue: nextRaw),
                      candidate == .painFallback || candidate == .declarationRetry {
                    nextRaw += 1
                }
            }
            guard let next = DirectStep(rawValue: nextRaw) else {
                assertionFailure("DirectOnboardingView.advance(): no successor for \(currentStep). .notificationTime should be terminal.")
                onComplete()
                return
            }
            withAnimation(.easeInOut(duration: 0.35)) { currentStep = next }
        }
    }

    // Mirrors the warfare/closer completion: persist the chosen category, seed
    // the home feed + notifications from it, then finish.
    private func applyResponsesAndComplete() {
        let goalWord = responses.resolvedGoalWord
        appState.surveyGoalWord = goalWord.rawValue
        if let style = responses.primaryDeclarationStyle {
            appState.selectedDeclarationStyles = [style.rawValue]
        }
        // The matcher's own category beats the one derived from the burden: it
        // classified what the user actually wrote, where the burden is that
        // answer rounded to one of seven. Only falls back to the goal word for
        // users who never got a declaration.
        let category = savedDeclaration
            .flatMap { DeclarationCategory(rawValue: $0.categoryRaw) }
            ?? goalWord.declarationCategory
        let notificationCategoriesSet: Set<DeclarationCategory> = [category]
        appState.selectedNotificationCategories = category.rawValue
        UserDefaults.standard.set(category.rawValue, forKey: "selectedCategory")
        UserPreferencesTracker.shared.trackCategorySelection(category.rawValue)
        declarationStore.choose(category) { _ in }
        // Mirrors the other arms: the personal-declaration push is scheduled off
        // this flag, so an arm that captures one and doesn't set it silently
        // drops that notification for every user in the arm.
        appState.hasPersonalDeclaration = savedDeclaration != nil
        if let notifTime = responses.notificationTime {
            appState.startTimeIndex = notifTime.startTimeIndex
            appState.endTimeIndex   = notifTime.endTimeIndex
            appState.personalDeclarationTimeIndex = notifTime.startTimeIndex
            // Cross-arm event name, same shape the quiz arm uses, so "did they
            // set a daily time" is one query across every flow rather than
            // per-arm. Safe for the quiz-flow funnel: that funnel is ordered
            // and starts at `onboarding_quiz_shown`, which this arm never fires.
            AnalyticsService.shared.track("onboarding_notification_time_picked", parameters: [
                "segment": appState.onboardingSegment,
                "variant": "direct",
                "notification_time": notifTime.rawValue
            ])
        }
        AnalyticsService.shared.track("direct_onboarding_completed", parameters: [
            "goal_word": goalWord.rawValue,
            // Both granularities: `pain` is what the matcher actually resolved
            // (fifteen values), `burden` is that rounded to the seven the other
            // arms speak, so this arm can be compared against them without
            // losing the detail that makes it different.
            "pain": pain?.rawValue ?? "unknown",
            "burden": responses.heaviestBurden?.rawValue ?? "unknown",
            // How far down the recovery ladder this user had to go. "open" is
            // the frame-one ask landing; "retry" is the narrow re-ask rescuing
            // someone who declined it; "picker" is a tap and nothing more;
            // "none" is a user who gave us nothing at all. A large "retry"
            // share earns the extra screen. A large "picker" share says the
            // free-text open is too heavy an ask for frame one.
            "pain_source": declarationSource != "none" ? declarationSource : (responses.heaviestBurden != nil ? "picker" : "none"),
            "seeded_category": category.rawValue,
            "notification_time": responses.notificationTime?.rawValue ?? "unknown",
            // The arm's payoff moment. Carried onto completion so conversion
            // can be cut by whether they actually reached a declaration of
            // their own rather than skipping past it.
            "set_personal_declaration": (savedDeclaration != nil) as NSNumber,
            "total_duration_seconds": elapsedSeconds,
            "flow_schema": DirectStep.flowSchema  // joins with direct_step_completed
        ])

        requestNotificationPermissionThenComplete(categories: notificationCategoriesSet)
    }

    private func requestNotificationPermissionThenComplete(categories: Set<DeclarationCategory>) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            AnalyticsService.shared.track("notification_permission", parameters: ["granted": granted, "source": "direct_onboarding"])
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
                    // Trial pushes may have been scheduled pre-authorization on
                    // the paywall; re-add now that delivery is guaranteed.
                    TrialExperienceService.shared.reschedulePendingTrialPushesIfNeeded()
                }
                onComplete()
            }
        }
    }

    /// Seconds since the flow first appeared. 0 if onAppear somehow never ran.
    private var elapsedSeconds: Int {
        guard let startedAt else { return 0 }
        return Int(Date().timeIntervalSince(startedAt))
    }

    private var backgroundView: some View {
        ZStack {
            Image(subscriptionStore.onboardingBGImage)
                .resizable().aspectRatio(contentMode: .fill)
                .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                .clipped()
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.86),
                    Color.black.opacity(0.62),
                    Color.black.opacity(0.78)
                ]),
                startPoint: .top, endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - Flow Steps

enum DirectStep: Int, CaseIterable {
    case declaration      = 0  // "What brought you here?" — free text, frame one
    case painFallback     = 1  // the picker, ONLY when the declaration produced nothing
    case declarationRetry = 2  // the same feature re-asked narrow, scoped to what they picked
    case mechanism        = 3  // how Jesus answered — after, so it explains what just happened
    case testimonials     = 4  // the review wall, right before the ask
    case paywall          = 5
    case notificationTime = 6  // terminal — completes onboarding

    /// Bumped whenever the raw values are renumbered, a step is inserted, or a
    /// step changes into a materially different screen — so events from two
    /// different flow shapes never get pooled into one funnel. Stamped on every
    /// event this arm fires.
    ///
    /// 1 → 2: step 2 became the real personal-declaration feature instead of a
    /// canned one-of-seven preview.
    /// 2 → 3: the declaration moved to frame one and the picker became a
    /// fallback behind it, so the step order and the drop-off shape are both
    /// different.
    /// 3 → 4: the picker now leads into a second, narrower declaration ask
    /// rather than straight to the mechanism. Schema-3 data is not comparable
    /// step-for-step.
    static let flowSchema = 4

    /// Stable analytics name. Funnels and breakdowns are built on this, not on
    /// the raw Int — a `step_name` of "mechanism" is readable in PostHog where
    /// a `step` of 2 needs a decoder ring.
    var name: String {
        switch self {
        case .declaration:      return "personal_declaration"
        case .painFallback:     return "pain_fallback"
        case .declarationRetry: return "personal_declaration_retry"
        case .mechanism:        return "mechanism"
        case .testimonials:     return "testimonials"
        case .paywall:          return "paywall"
        case .notificationTime: return "notification_time"
        }
    }
}

// MARK: - Shared components

private struct DirectStagger: ViewModifier {
    let shown: Bool
    let delay: Double
    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 16)
            .animation(.easeOut(duration: 0.5).delay(delay), value: shown)
    }
}

private extension View {
    func directStagger(_ shown: Bool, delay: Double = 0) -> some View {
        modifier(DirectStagger(shown: shown, delay: delay))
    }
}

/// The arm's single CTA style: full-width gold, matching the storm opener the
/// other arms lead with so the brand moment is unchanged even though the
/// pacing is not.
private struct DirectCTA: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(DS.Palette.deepBlue)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    Capsule()
                        .fill(DS.Gradient.gold)
                        .shadow(color: DS.Palette.gold.opacity(0.45), radius: 14, x: 0, y: 6)
                )
        }
        .buttonStyle(.dsPressable(feel: .tapSolid))
        .padding(.horizontal, 28)
    }
}

// MARK: - Screen 0: What brought you here?

/// The pain the user is carrying, in their own words, phrased the way they
/// would actually say it — not as a category name. Each maps to the shared
/// `HeaviestBurden` so seeding and the back-half work unchanged.
private struct DirectPain: Identifiable {
    let id = UUID()
    let burden: HeaviestBurden
    let icon: String
    let line: String

    /// The same line handed back in second person on the retry ask. Written out
    /// rather than derived from `line`: turning "I'm off track from my calling"
    /// into "you're off track from your calling" is not something string
    /// surgery does without producing something a person would never say.
    let echo: String

    /// The retry's question, written to pick up from `echo` without repeating
    /// it — "your mind won't stop racing" is answered by "what's it racing
    /// about?", not by asking about their mind a second time.
    ///
    /// This is the narrow, concrete version of the open question they already
    /// declined. Someone who stalls on a blank "what brought you here" will
    /// often answer "what's it racing about?", because it asks for one fact
    /// rather than a summary of their life.
    let prompt: String

    /// The receipt and the retry question for a picked burden.
    static func echoLine(for burden: HeaviestBurden?) -> String? {
        guard let burden else { return nil }
        return all.first(where: { $0.burden == burden })?.echo
    }

    static func prompt(for burden: HeaviestBurden?) -> String? {
        guard let burden else { return nil }
        return all.first(where: { $0.burden == burden })?.prompt
    }

    static let all: [DirectPain] = [
        .init(burden: .peace,     icon: "🕊", line: "My mind won't stop racing",
              echo: "You said your mind won't stop racing.",
              prompt: "What's it racing about?"),
        .init(burden: .health,    icon: "🌿", line: "My body needs healing",
              echo: "You said your body needs healing.",
              prompt: "What are you believing God to heal?"),
        .init(burden: .abundance, icon: "💰", line: "The money isn't there",
              echo: "You said the money isn't there.",
              prompt: "What do you need God to cover?"),
        .init(burden: .identity,  icon: "👑", line: "I don't feel good enough",
              echo: "You said you don't feel good enough.",
              prompt: "What's making you feel that way?"),
        .init(burden: .joy,       icon: "☀️", line: "I feel flat and empty",
              echo: "You said you're feeling flat and empty.",
              prompt: "What's been draining you?"),
        .init(burden: .purpose,   icon: "🧭", line: "I'm off track from my calling",
              echo: "You said you're off track from your calling.",
              prompt: "Where do you need God to open a door?"),
        .init(burden: .allOfIt,   icon: "⚡", line: "I just want more of God",
              echo: "You said you want more of God.",
              prompt: "What are you believing Him for?"),
    ]
}

private struct DirectPainRow: View {
    let pain: DirectPain
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Text(pain.icon)
                    .font(.system(size: 22))
                Text(pain.line)
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 17)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .fill(isSelected ? Color.white.opacity(0.22) : Color.white.opacity(0.09))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .stroke(isSelected ? DS.Palette.gold : Color.white.opacity(0.14), lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.dsPressable(feel: .tapLight))
    }
}

/// Screen one. No logo, no scene, no promise — the question is the first thing
/// on screen, and tapping an answer advances immediately. There is deliberately
/// no Continue button: a second tap to confirm a one-tap question is the exact
/// kind of friction this arm exists to remove.
private struct DirectPainScreen: View {
    let size: CGSize
    @ObservedObject var responses: SurveyResponses
    let onContinue: () -> Void

    @State private var v = false
    @State private var selected: HeaviestBurden? = nil

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    Spacer().frame(height: size.height * 0.12)

                    VStack(spacing: 10) {
                        // Deliberately not "what brought you here" any more —
                        // they were just asked that and chose not to answer.
                        // Re-asking the same question in a different format
                        // reads as not listening; offering the shortcut reads
                        // as letting them off the hook.
                        Text("No problem.\nWhich is closest?")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .directStagger(v)

                        Text("One tap and we'll build your feed around it.")
                            .font(.system(size: 15, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.65))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .directStagger(v, delay: 0.08)
                    }
                    .padding(.horizontal, 28)

                    VStack(spacing: 10) {
                        ForEach(DirectPain.all) { pain in
                            DirectPainRow(pain: pain, isSelected: selected == pain.burden) {
                                choose(pain.burden)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .directStagger(v, delay: 0.16)

                    Spacer().frame(height: 40)
                }
            }
        }
        .onAppear {
            AnalyticsService.shared.track("direct_pain_shown", parameters: [
                "flow_schema": DirectStep.flowSchema
            ])
            withAnimation { v = true }
        }
    }

    /// Selects, then advances on a short beat so the highlight is visible
    /// before the screen changes — the tap still feels acknowledged without
    /// costing a second tap.
    private func choose(_ burden: HeaviestBurden) {
        guard selected == nil else { return }  // ignore double taps mid-transition
        withAnimation(.easeOut(duration: 0.15)) { selected = burden }
        responses.heaviestBurden = burden
        AnalyticsService.shared.track("direct_pain_answered", parameters: [
            "burden": burden.rawValue
        ])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) { onContinue() }
    }
}

// MARK: - Screen 1: How Jesus handled it

/// The mechanism screen's closing line, per pain, in both tenses. Kept here
/// rather than on `UserPain` itself because this is onboarding copy — the
/// paywall never says any of it.
///
/// Both halves say the same thing about the method, which is the point: Jesus
/// spoke to it, and so do you. Only the tense and the domain move.
private extension UserPain {
    /// Before they've done it — the promise of what speaking will be.
    var mechanismBefore: String {
        switch self {
        case .peace:      return "So you won't beg your mind to settle. You'll speak peace to it."
        case .fear:       return "So you won't talk yourself down from it. You'll speak God's protection over it."
        case .health:     return "So you won't beg your body to hold on. You'll speak healing to it."
        case .abundance:  return "So you won't beg for provision. You'll speak God's supply over it."
        case .identity:   return "So you won't try to feel better about yourself. You'll speak what God already says you are."
        case .shame:      return "So you won't keep apologizing for it. You'll speak what the cross already settled."
        case .bondage:    return "So you won't white-knuckle it. You'll speak the freedom Jesus bought you."
        case .purpose:    return "So you won't wonder about your calling. You'll speak it into motion."
        case .joy:        return "So you won't wait to feel better. You'll speak His joy over your day."
        case .grief:      return "So you won't carry it silently. You'll speak God's comfort over your heart."
        case .loneliness: return "So you won't sit in it alone. You'll speak God's nearness over your life."
        case .marriage:   return "So you won't argue it into shape. You'll speak God's peace over your home."
        case .family:     return "So you won't lie awake worrying. You'll speak God's promises over them."
        case .nearness:   return "So you won't chase a feeling. You'll speak what God says about being near you."
        case .more:       return "So you won't keep asking. You'll speak what God already said."
        }
    }

    /// After they've done it. **Declare it daily, because it is already yours
    /// and declaring is how you take hold of it.**
    ///
    /// "Say it again tomorrow" framed this as a habit worth building, which
    /// undersells what is actually happening. The victory is finished — Jesus
    /// already won it and already handed over the authority — so speaking is
    /// not how you persuade God to act. It is how you enforce, against an enemy
    /// with no legal claim, ground that has your name on it. Every line names
    /// the daily declaration and then what it is doing.
    ///
    /// The action stays the speaker's own. Never another person changing.
    var mechanismAfter: String {
        switch self {
        case .peace:      return "Declare it every morning. That is you enforcing peace the enemy has no claim on."
        case .fear:       return "Declare it every morning. Fear has no authority here, and saying so is how you use yours."
        case .health:     return "Declare it every morning. You are enforcing healing the cross already bought and paid for."
        case .abundance:  return "Declare it every morning. You are enforcing supply God already put in your name."
        case .identity:   return "Declare it every morning. You are enforcing a verdict God already handed down about you."
        case .shame:      return "Declare it every morning. You are enforcing a debt Jesus already cleared in full."
        case .bondage:    return "Declare it every morning. You are enforcing freedom that was bought, and it has to let go."
        case .purpose:    return "Declare it every morning, then take the step. You are enforcing an order God already gave."
        case .joy:        return "Declare it every morning. You are enforcing joy the enemy has no right to touch."
        case .grief:      return "Declare it every morning. You are holding God to a comfort He already promised you."
        case .loneliness: return "Declare it every morning. You are enforcing a presence God already swore He would be."
        case .marriage:   return "Declare it every morning. You are enforcing peace over ground that belongs to your house."
        case .family:     return "Declare it every morning. You are standing on promises God already made over them."
        case .nearness:   return "Declare it every morning, then go be with Him. He already came near; take Him at it."
        case .more:       return "Declare it every morning. Jesus already won it and handed you the authority to enforce it."
        }
    }
}

/// How Jesus answered — the arm's one teaching screen. The framing is
/// authority: He spoke to the thing, and He handed the same authority over.
/// Only the last line moves, to land that on this user's actual situation.
///
/// It used to be framed as expulsion — "He did not beg the problem to leave" —
/// which silently broke on every pain the user wants to RECEIVE rather than be
/// rid of. See the note on `headline`.
///
/// The four parts land one at a time rather than as one wall — the stagger runs
/// to ~1.35s so each block gets its own beat and the screen reads as a sequence
/// instead of a page of text. The CTA is last on purpose: this is the arm's one
/// teaching screen, and there is nothing to decide until it has been read.
///
/// Four parts, in this order: He did it (the storm, the sickness, the grave),
/// He said we do it (Mark 11:23-24, where saying is the part He names), what
/// that means for this user, and James 2:17 under it — because the line tells
/// them to say it again AND to move on it today, and the moving half needs a
/// warrant rather than reading as our own advice. Mark is the hinge; James is
/// why the screen doesn't end on a feeling.
private struct DirectMechanismScreen: View {
    let size: CGSize
    let pain: UserPain
    /// True when the user actually got a declaration. It changes the screen's
    /// whole job: for them this explains something that just happened, which is
    /// a far stronger position than promising something that hasn't. For a user
    /// who skipped, the same three beats have to carry it as a claim instead.
    let spokeDeclaration: Bool
    let onContinue: () -> Void

    @State private var v = false

    private var eyebrow: String {
        spokeDeclaration ? "WHAT YOU JUST DID" : "SPEAKLIFE · PRAY LIKE JESUS"
    }

    /// Framed as authority, not as expulsion.
    ///
    /// This used to read "instead of begging it to leave", which only works when
    /// the thing is present and unwanted. Roughly half of `UserPain` is the
    /// opposite — abundance, identity, purpose, loneliness, nearness, family,
    /// marriage are all things the user wants to RECEIVE, and nobody begs
    /// provision to leave. On those the headline contradicted the line four
    /// blocks below it: "you are enforcing supply God already put in your name"
    /// is a claim on something arriving, not a request for something to go.
    ///
    /// `mechanismAfter` was already written on the enforcement frame throughout;
    /// the headline was the last piece still on the older one. Authority holds
    /// for all fifteen pains, because you can walk in it over lack, over a
    /// prodigal, over a calling, and over sickness alike.
    ///
    /// "Just like Jesus" cashes the three beats directly beneath it — the storm,
    /// the sickness, the grave are Jesus doing exactly this — so the headline
    /// names what the user just did and the evidence for it sits right under it.
    private var headline: String {
        spokeDeclaration
            ? "That's authority.\nYou spoke to your mountain\njust like Jesus."
            : "This is authority.\nJesus spoke to the mountain.\nSo can you."
    }

    /// The line that lands Jesus' method on this user's exact situation. Past
    /// tense once they have actually done it — the screen is naming what
    /// happened, not forecasting it.
    private var applied: String {
        spokeDeclaration ? pain.mechanismAfter : pain.mechanismBefore
    }

    private let beats: [(String, String)] = [
        ("The storm",   "\"Quiet! Be still!\" — and the wind stopped."),
        ("The sickness","\"Be clean.\" — and the leprosy left."),
        ("The grave",   "\"Lazarus, come out!\" — and a dead man walked.")
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 26) {
                    Spacer().frame(height: size.height * 0.10)

                    VStack(spacing: 12) {
                        Text(eyebrow)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(DS.Palette.gold.opacity(0.9))
                            .kerning(1.4)
                            .directStagger(v)

                        Text(headline)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.8)
                            .fixedSize(horizontal: false, vertical: true)
                            .directStagger(v, delay: 0.12)
                    }
                    .padding(.horizontal, 28)

                    VStack(spacing: 14) {
                        ForEach(Array(beats.enumerated()), id: \.offset) { idx, beat in
                            HStack(alignment: .top, spacing: 12) {
                                Text(beat.0)
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(DS.Palette.gold)
                                    .frame(width: 92, alignment: .leading)
                                Text(beat.1)
                                    .font(.system(size: 15, weight: .regular, design: .rounded))
                                    .foregroundColor(.white.opacity(0.82))
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                            }
                            .directStagger(v, delay: 0.30 + Double(idx) * 0.15)
                        }
                    }
                    .padding(20)
                    .dsGlass(cornerRadius: DS.Radius.lg)
                    .padding(.horizontal, 24)

                    // The hinge of the whole screen. The three beats above are
                    // Jesus doing it; this is Jesus saying to do it, and saying
                    // out loud is the part He names — "says to this mountain",
                    // "believes that what they say will happen". Without it the
                    // screen shows a pattern and asks the user to infer a
                    // command from it. With it, speaking is not our idea.
                    VStack(spacing: 10) {
                        Text("Then He said we do the same.")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .directStagger(v, delay: 0.78)

                        VStack(spacing: 6) {
                            Text("\"Truly I tell you, if anyone says to this mountain, 'Go, throw yourself into the sea,' and does not doubt in their heart but believes that what they say will happen, it will be done for them. Therefore I tell you, whatever you ask for in prayer, believe that you have received it, and it will be yours.\"")
                                .font(.system(size: 14, weight: .regular, design: .serif))
                                .italic()
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)

                            Text("Mark 11:23-24")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(DS.Palette.gold.opacity(0.85))
                        }
                        .directStagger(v, delay: 0.90)
                    }
                    .padding(.horizontal, 28)

                    VStack(spacing: 10) {
                        Text(applied)
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                            .directStagger(v, delay: 1.10)

                        // The warrant for the second half of that line. Speaking
                        // and then living unchanged is the thing James names, so
                        // the screen cites it rather than leaving "then do
                        // something" as our own advice.
                        VStack(spacing: 3) {
                            Text("\"Faith by itself, if it is not accompanied by action, is dead.\"")
                                .font(.system(size: 13, weight: .regular, design: .serif))
                                .italic()
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("James 2:17")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(DS.Palette.gold.opacity(0.8))
                        }
                        .directStagger(v, delay: 1.22)
                    }
                    .padding(.horizontal, 30)

                    Spacer().frame(height: 8)
                }
            }

            DirectCTA(label: spokeDeclaration ? "Make This My Daily Habit →" : "Show Me How →") { onContinue() }
                .padding(.bottom, 36)
                .directStagger(v, delay: 1.35)
        }
        .onAppear {
            AnalyticsService.shared.track("direct_mechanism_shown", parameters: [
                "pain": pain.rawValue,
                "spoke_declaration": spokeDeclaration as NSNumber
            ])
            withAnimation { v = true }
        }
    }
}
