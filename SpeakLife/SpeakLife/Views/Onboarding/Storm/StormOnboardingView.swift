//
//  StormOnboardingView.swift
//  SpeakLife
//
//  The storm arm's driver. Ten screens, under ninety seconds, one job: get a
//  new user to speak their first declaration out loud over the storm they
//  named, before they ever see a price.
//
//    welcome → storm → posture → mechanism → SPEAK → feeling → promise
//      → morning time → reminder explainer (+ iOS prompt) → 7-day plan
//      → [rating] → paywall
//
//  `storm` is skipped when an ad already named it. `rating` only follows a
//  declaration that was actually spoken, and honours the remote kill switch.
//  No sign-up, email or free text anywhere before the paywall.
//
//  Built for our best buyers, women 45–64: every size is a Dynamic Type text
//  style, body never under 17pt, secondary text never under 78% white.
//

import SwiftUI
import UserNotifications
import UIKit
import AVFoundation

// MARK: - Steps

enum StormStep: Int, CaseIterable, OnboardingFunnelStep {
    case welcome, storm, posture, mechanism, speak, feeling, promise, morningTime, reminder, plan, rating, paywall

    var funnelStepName: String {
        switch self {
        case .welcome:     return "welcome"
        case .storm:       return "storm_picker"
        case .posture:     return "current_posture"
        case .mechanism:   return "mechanism"
        case .speak:       return "first_declaration"
        case .feeling:     return "declaration_feeling"
        case .promise:     return "benefit_screen"
        case .morningTime: return "notification_time"
        case .reminder:    return "reminder_explainer"
        case .plan:        return "plan_reveal"
        case .rating:      return "rating"
        case .paywall:     return "paywall"
        }
    }

    var funnelStage: OnboardingStage {
        switch self {
        case .welcome, .mechanism:             return .hook
        case .storm, .posture:                 return .personalize
        case .speak, .feeling, .promise, .plan, .rating: return .value
        case .morningTime, .reminder:          return .setup
        case .paywall:                         return .paywall
        }
    }
}

// MARK: - Driver

struct StormOnboardingView: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var declarationStore: DeclarationViewModel

    let size: CGSize
    /// Set when an ad's `ob=` already named the storm. The picker is skipped.
    let preselectedStorm: Storm?
    let onComplete: () -> Void

    @State private var step: StormStep = .welcome
    @State private var storm: Storm?
    @State private var posture: StormPosture?
    @State private var spokeFirstDeclaration = false
    @State private var morning = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var lastLoggedStep: StormStep?
    @State private var isRequestingNotifications = false
    @State private var startedAt = Date()

    private var resolvedStorm: Storm { storm ?? preselectedStorm ?? .fear }

    private var progress: Double {
        let visible = StormStep.allCases.filter { $0 != .paywall }
        guard let idx = visible.firstIndex(of: step) else { return 1 }
        return Double(idx + 1) / Double(visible.count)
    }

    var body: some View {
        ZStack(alignment: .top) {
            StormBackground()

            screen
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .offset(y: 20)),
                    removal: .opacity
                ))
                .id(step)

            if step != .paywall && step != .rating {
                StormProgressBar(progress: progress)
                    .padding(.horizontal, 28)
                    .padding(.top, size.height * 0.065)
            }
        }
        .ignoresSafeArea()
        .environment(\.colorScheme, .dark)
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .onAppear {
            if storm == nil { storm = preselectedStorm }
            if let preselectedStorm { StormOnboarding.selectedStorm = preselectedStorm }
            startedAt = Date()
            logStepViewed()
        }
        .onChange(of: step) { _, _ in logStepViewed() }
    }

    @ViewBuilder
    private var screen: some View {
        switch step {
        case .welcome:
            StormWelcomeScreen { advance() }
        case .storm:
            StormPickerScreen(selection: storm) { picked in
                storm = picked
                StormOnboarding.selectedStorm = picked
                AnalyticsService.shared.track("storm_selected", parameters: ["storm": picked.rawValue])
                advance()
            }
        case .posture:
            StormPostureScreen(selection: posture) { picked in
                posture = picked
                AnalyticsService.shared.track("storm_posture_selected", parameters: [
                    "posture": picked.rawValue, "storm": resolvedStorm.rawValue
                ])
                advance()
            }
        case .mechanism:
            StormMechanismScreen(storm: resolvedStorm, posture: posture) { advance() }
        case .speak:
            StormSpeakScreen(
                line: resolvedStorm.firstDeclaration,
                eyebrow: "SPEAK THIS OUT LOUD",
                title: resolvedStorm == .grief ? "Let this be spoken over you" : "Speak to your storm",
                backup: StormSpeakBackup(config: subscriptionStore.stormSpeakBackup)
            ) { outcome in
                let spoke = outcome == .spoken
                spokeFirstDeclaration = spoke
                if outcome == .heard {
                    AnalyticsService.shared.track("first_declaration_heard", parameters: [
                        "storm": resolvedStorm.rawValue,
                        "step_index": StormStep.speak.rawValue,
                        "variant": subscriptionStore.onboardingVariantName,
                        "seconds_since_start": Int(Date().timeIntervalSince(startedAt))
                    ])
                }
                if spoke {
                    AnalyticsService.shared.track("first_declaration_spoken", parameters: [
                        "storm": resolvedStorm.rawValue,
                        "step_index": StormStep.speak.rawValue,
                        "variant": subscriptionStore.onboardingVariantName,
                        "seconds_since_start": Int(Date().timeIntervalSince(startedAt))
                    ])
                    GrowthMetrics.shared.trackActivation(action: "declaration_spoken")
                } else if outcome == .readSilently {
                    AnalyticsService.shared.track("first_declaration_read_silently", parameters: [
                        "storm": resolvedStorm.rawValue
                    ])
                }
                advance()
            }
        case .feeling:
            StormFeelingScreen { feeling in
                if let feeling {
                    AnalyticsService.shared.track("first_declaration_feeling", parameters: [
                        "feeling": feeling.rawValue, "storm": resolvedStorm.rawValue
                    ])
                }
                advance()
            }
        case .promise:
            StormPromiseScreen(storm: resolvedStorm) { advance() }
        case .morningTime:
            StormMorningTimeScreen(time: $morning) {
                let c = Calendar.current.dateComponents([.hour, .minute], from: morning)
                StormOnboarding.morningMinutes = (c.hour ?? 7) * 60 + (c.minute ?? 0)
                AnalyticsService.shared.track("storm_morning_time_selected", parameters: [
                    "hour": c.hour ?? 7, "minute": c.minute ?? 0
                ])
                advance()
            }
        case .reminder:
            StormReminderExplainerScreen(storm: resolvedStorm, time: morning, isBusy: isRequestingNotifications) { wantsReminders in
                guard wantsReminders else {
                    AnalyticsService.shared.track("notification_permission", parameters: [
                        "granted": false, "source": "storm_onboarding",
                        "placement": "before_paywall", "asked": false
                    ])
                    advance()
                    return
                }
                guard !isRequestingNotifications else { return }
                isRequestingNotifications = true
                requestNotificationPermission { advance() }
            }
        case .plan:
            StormPlanScreen(storm: resolvedStorm, morning: morning) { advance() }
        case .rating:
            RatingView(size: size) { advance() }
        case .paywall:
            StormPaywallView(storm: resolvedStorm, placement: "onboarding") { _ in
                complete()
            }
        }
    }

    // MARK: Navigation

    private func advance() {
        Juice.play(.tapLight)
        AnalyticsService.shared.track("storm_step_completed", parameters: [
            "step": step.rawValue, "step_name": step.funnelStepName
        ])
        var next = step.rawValue + 1
        while let candidate = StormStep(rawValue: next), shouldSkip(candidate) { next += 1 }
        guard let target = StormStep(rawValue: next) else { complete(); return }
        withAnimation(.easeInOut(duration: 0.3)) { step = target }
    }

    private func shouldSkip(_ candidate: StormStep) -> Bool {
        switch candidate {
        case .storm:
            return preselectedStorm != nil
        case .promise:
            return !subscriptionStore.stormBenefitScreen
        case .rating:
            // Only right after a real spoken win, and never with the kill switch off.
            return !spokeFirstDeclaration || !subscriptionStore.onboardingRatingEnabled
        default:
            return false
        }
    }

    private func logStepViewed() {
        guard !appState.debugReplayOnboarding, lastLoggedStep != step else { return }
        lastLoggedStep = step
        OnboardingFunnel.stepViewed(
            variant: subscriptionStore.onboardingVariantName,
            stepName: step.funnelStepName,
            stepIndex: step.rawValue,
            stage: step.funnelStage,
            flowSchema: 1,
            storm: storm?.rawValue ?? preselectedStorm?.rawValue
        )
    }

    // MARK: Completion

    /// Seed the feed and notifications from the storm, then finish. Runs whether
    /// the paywall ended in a purchase or a close.
    private func complete() {
        let storm = resolvedStorm
        let category = storm.category
        StormOnboarding.selectedStorm = storm
        appState.selectedNotificationCategories = category.rawValue
        UserDefaults.standard.set(category.rawValue, forKey: "selectedCategory")
        UserPreferencesTracker.shared.trackCategorySelection(category.rawValue)
        declarationStore.choose(category) { _ in }
        AnalyticsService.shared.track("storm_onboarding_completed", parameters: [
            "storm": storm.rawValue,
            "posture": posture?.rawValue ?? "unknown",
            "spoke_first_declaration": spokeFirstDeclaration,
            "seconds_to_paywall_close": Int(Date().timeIntervalSince(startedAt)),
            "preselected": preselectedStorm != nil
        ])
        onComplete()
    }

    /// Ask for push and, if granted, schedule what brings the user back. The
    /// paywall that follows is terminal, so anything left for completion would
    /// never be scheduled for someone who closes the app on it.
    private func requestNotificationPermission(then next: @escaping () -> Void) {
        appState.startTimeIndex = NotificationTime.allDay.startTimeIndex
        appState.endTimeIndex = NotificationTime.allDay.endTimeIndex
        let category = resolvedStorm.category
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            AnalyticsService.shared.track("notification_permission", parameters: [
                "granted": granted,
                "source": "storm_onboarding",
                "placement": "before_paywall",
                "asked": true
            ])
            DispatchQueue.main.async {
                appState.notificationEnabled = granted
                if granted {
                    UIApplication.shared.registerForRemoteNotifications()
                    NotificationManager.shared.registerNotifications(
                        count: appState.notificationCount,
                        startTime: appState.startTimeIndex,
                        endTime: appState.endTimeIndex,
                        categories: [category]
                    )
                    appState.lastNotificationSetDate = Date()
                    // Now carries the user's chosen morning time.
                    DailyDeclarationReminderService.shared.setupDailyReminders()
                    LifecycleNotificationService.shared.scheduleLifecycleNotifications()
                    LifecycleNotificationService.shared.scheduleBedtimeAudio(
                        isPremium: subscriptionStore.isPremium,
                        category: category.rawValue
                    )
                }
                isRequestingNotifications = false
                next()
            }
        }
    }
}

// MARK: - Shared chrome

struct StormBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [StormStyle.navy, StormStyle.navyDeep],
                           startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [StormStyle.gold.opacity(0.16), .clear],
                           center: .top, startRadius: 10, endRadius: 420)
        }
        .ignoresSafeArea()
    }
}

private struct StormProgressBar: View {
    let progress: Double
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.15))
                Capsule().fill(StormStyle.gold)
                    .frame(width: geo.size.width * progress)
                    .animation(.spring(response: 0.5, dampingFraction: 0.85), value: progress)
            }
        }
        .frame(height: 4)
        .accessibilityHidden(true)
    }
}

/// The one primary button: gold fill, navy text, 58pt, 16pt corners.
struct StormPrimaryButton: View {
    let title: String
    var isEnabled = true
    var isLoading = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView().tint(StormStyle.navy)
                } else {
                    Text(title)
                        .font(.title3.weight(.semibold))
                        .foregroundColor(StormStyle.navy)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.8)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 58)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isEnabled ? StormStyle.gold : StormStyle.gold.opacity(0.35))
            )
        }
        .buttonStyle(.dsPressable(feel: .tapSolid))
        .disabled(!isEnabled || isLoading)
    }
}

/// A plain, readable secondary action. Never tiny gray text.
struct StormTextButton: View {
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.body.weight(.medium))
                .foregroundColor(StormStyle.secondary)
                .underline()
                .frame(minHeight: 44)
                .padding(.horizontal, 8)
        }
    }
}

private struct StormAppear: ViewModifier {
    let shown: Bool
    let delay: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func body(content: Content) -> some View {
        content
            .opacity(shown || reduceMotion ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 14)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.45).delay(delay), value: shown)
    }
}

extension View {
    func stormAppear(_ shown: Bool, delay: Double = 0) -> some View {
        modifier(StormAppear(shown: shown, delay: delay))
    }
}

/// Title + optional subtitle, the header every question screen shares.
private struct StormHeader: View {
    let title: String
    var subtitle: String? = nil
    let shown: Bool

    var body: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.title.weight(.bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .stormAppear(shown)
            if let subtitle {
                Text(subtitle)
                    .font(.body)
                    .foregroundColor(StormStyle.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .stormAppear(shown, delay: 0.08)
            }
        }
        .padding(.horizontal, 24)
    }
}

/// A full-width single-tap choice row.
private struct StormChoiceRow: View {
    let symbol: String?
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.title3)
                        .foregroundColor(isSelected ? StormStyle.navy : StormStyle.gold)
                        .frame(width: 30)
                }
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundColor(isSelected ? StormStyle.navy : .white)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? StormStyle.gold : Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(isSelected ? StormStyle.gold : Color.white.opacity(0.18), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.dsPressable(feel: .tapLight))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - 1. Welcome

private struct StormWelcomeScreen: View {
    let onContinue: () -> Void
    @State private var v = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 22) {
                Image(systemName: "cloud.bolt.rain.fill")
                    .font(.system(size: 56))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundColor(StormStyle.gold)
                    .accessibilityHidden(true)
                    .stormAppear(v)
                Text("Victory over every storm.")
                    .font(.largeTitle.weight(.bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .stormAppear(v, delay: 0.08)
                Text("Speak God's Word out loud over your life each morning, the way Jesus spoke to the storm.")
                    .font(.body)
                    .foregroundColor(StormStyle.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .stormAppear(v, delay: 0.16)
            }
            .padding(.horizontal, 28)
            Spacer()
            StormPrimaryButton(title: "Continue", action: onContinue)
                .padding(.horizontal, 24)
                .padding(.bottom, 44)
                .stormAppear(v, delay: 0.24)
        }
        .onAppear { v = true }
    }
}

// MARK: - 2. Name your storm

private struct StormPickerScreen: View {
    let selection: Storm?
    let onPick: (Storm) -> Void
    @State private var picked: Storm?
    @State private var v = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                Spacer().frame(height: 96)
                StormHeader(title: "What storm are you facing?",
                            subtitle: "Pick the one that weighs on you most.",
                            shown: v)
                VStack(spacing: 10) {
                    ForEach(Storm.allCases) { storm in
                        StormChoiceRow(symbol: storm.symbol, title: storm.label,
                                       isSelected: (picked ?? selection) == storm) {
                            guard picked == nil else { return }
                            picked = storm
                            // Let the gold land before the screen moves on.
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { onPick(storm) }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .stormAppear(v, delay: 0.12)
                Spacer().frame(height: 40)
            }
        }
        .onAppear { v = true }
    }
}

// MARK: - 3. Current posture

private struct StormPostureScreen: View {
    let selection: StormPosture?
    let onPick: (StormPosture) -> Void
    @State private var picked: StormPosture?
    @State private var v = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                Spacer().frame(height: 110)
                StormHeader(title: "When this storm hits, I usually…", shown: v)
                VStack(spacing: 10) {
                    ForEach(StormPosture.allCases) { posture in
                        StormChoiceRow(symbol: nil, title: posture.label,
                                       isSelected: (picked ?? selection) == posture) {
                            guard picked == nil else { return }
                            picked = posture
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { onPick(posture) }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .stormAppear(v, delay: 0.12)
                Spacer().frame(height: 40)
            }
        }
        .onAppear { v = true }
    }
}

// MARK: - 4. The mechanism

private struct StormMechanismScreen: View {
    let storm: Storm
    let posture: StormPosture?
    let onContinue: () -> Void
    @State private var v = false

    /// One line that meets them where they said they are. Proof, not a sermon.
    private var bridge: String {
        switch posture {
        case .speakScripture:
            return "You already know this. Now you'll do it every morning, out loud, over \(storm.domain)."
        case .noWords:
            return "You won't need to find the words. We'll put His words in your mouth, one line a day."
        default:
            return "Praying about it asks God to move. Speaking to it uses the authority He already gave you."
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 20) {
                Text("MARK 4:39")
                    .font(.footnote.weight(.bold))
                    .kerning(1.4)
                    .foregroundColor(StormStyle.gold)
                    .stormAppear(v)
                Text("Jesus didn't pray about the storm. He spoke to it.")
                    .font(.title.weight(.bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .stormAppear(v, delay: 0.08)
                Text("\u{201C}Quiet! Be still!\u{201D} Then the wind died down and it was completely calm.")
                    .font(.system(.body, design: .serif).italic())
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .stormAppear(v, delay: 0.16)
                Text(bridge)
                    .font(.body)
                    .foregroundColor(StormStyle.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .stormAppear(v, delay: 0.24)
            }
            .padding(.horizontal, 28)
            Spacer()
            StormPrimaryButton(title: "I'm ready to speak", action: onContinue)
                .padding(.horizontal, 24)
                .padding(.bottom, 44)
                .stormAppear(v, delay: 0.3)
        }
        .onAppear { v = true }
    }
}

// MARK: - 5. Speak it (also used after purchase)

/// How a speak screen ended.
enum StormSpeakOutcome {
    /// Held the button all the way through while saying it.
    case spoken
    /// Tapped "Hear it spoken over you" and listened to the end.
    case heard
    /// Tapped "Read silently instead".
    case readSilently
}

/// The speak screen's secondary option, Remote Config `stormSpeakBackup`.
enum StormSpeakBackup {
    case hear, read

    init(config: String) { self = config.lowercased() == "read" ? .read : .hear }
}

/// Reads a declaration aloud in the voice the feed's speaker button uses.
/// Not `SpeechCoordinator` itself: that restarts the app's background music
/// when it finishes, which has no place in the middle of onboarding.
@MainActor
final class StormVoice: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published private(set) var isSpeaking = false
    private let synthesizer = AVSpeechSynthesizer()
    var onFinish: (() -> Void)?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String) {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = SpeechCoordinator().bestVoice(gender: .female) ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.46
        isSpeaking = true
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
            self.onFinish?()
        }
    }
}

/// The declaration card and the hold-to-speak control. No microphone and no
/// permission prompt: the hold paces the line and the user says it out loud.
struct StormSpeakScreen: View {
    let line: StormLine
    let eyebrow: String
    let title: String
    let backup: StormSpeakBackup
    let onDone: (StormSpeakOutcome) -> Void

    @StateObject private var voice = StormVoice()
    private var finishedByListening: Bool { finished && !isSealed && !isCharging && voiceUsed }
    @State private var voiceUsed = false
    @State private var isCharging = false
    @State private var isSealed = false
    @State private var finished = false
    @State private var v = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Long enough to say the line at an unhurried pace.
    private var chargeDuration: Double {
        let words = line.text.split(separator: " ").count
        return min(max(Double(words) * 0.36, 2.8), 6.5)
    }

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                Spacer(minLength: 90)
                VStack(spacing: 18) {
                    Text(eyebrow)
                        .font(.footnote.weight(.bold))
                        .kerning(1.4)
                        .foregroundColor(StormStyle.gold)
                        .stormAppear(v)
                    Text(title)
                        .font(.title2.weight(.bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .stormAppear(v, delay: 0.06)

                    VStack(spacing: 16) {
                        Text(line.text)
                            .font(.title2.weight(.semibold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                        VStack(spacing: 6) {
                            Text("\u{201C}\(line.verse)\u{201D}")
                                .font(.system(.callout, design: .serif).italic())
                                .foregroundColor(StormStyle.secondary)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                                .lineLimit(5)
                            Text(line.reference)
                                .font(.callout.weight(.semibold))
                                .foregroundColor(StormStyle.gold)
                        }
                    }
                    .padding(22)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Color.white.opacity(isSealed || finished || voice.isSpeaking ? 0.14 : 0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .strokeBorder(StormStyle.gold.opacity(isCharging || isSealed || finished ? 0.9 : 0.3),
                                                  lineWidth: isCharging ? 2 : 1)
                            )
                            .shadow(color: StormStyle.gold.opacity(isSealed || finished ? 0.45 : 0),
                                    radius: 24)
                    )
                    .scaleEffect(isCharging && !reduceMotion ? 1.02 : 1)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.4), value: isCharging)
                    .stormAppear(v, delay: 0.12)
                }
                .padding(.horizontal, 22)

                Spacer(minLength: 24)

                VStack(spacing: 12) {
                    if finished {
                        Label(finishedByListening ? "Spoken over you." : "Spoken. It's done.",
                              systemImage: "checkmark.seal.fill")
                            .font(.title3.weight(.semibold))
                            .foregroundColor(StormStyle.gold)
                            .frame(minHeight: 58)
                            .transition(.opacity)
                    } else {
                        Text(isCharging ? "Keep speaking…" : "Hold the button and say it out loud.")
                            .font(.body)
                            .foregroundColor(StormStyle.secondary)
                            .multilineTextAlignment(.center)
                        HoldToDeclareButton(
                            title: "Hold and speak",
                            width: geo.size.width - 48,
                            chargeDuration: chargeDuration,
                            isLocked: finished,
                            isCharging: $isCharging,
                            isSealed: $isSealed,
                            onSealed: { PremiumHaptics.safeHeartbeat() },
                            onRelease: { sealed in
                                guard sealed else { return }
                                withAnimation { finished = true }
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                                voice.stop()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { onDone(.spoken) }
                            }
                        )
                    }
                    if !finished {
                        switch backup {
                        case .read:
                            StormTextButton(title: "Read silently instead") { onDone(.readSilently) }
                        case .hear:
                            if voice.isSpeaking {
                                Label("Listening…", systemImage: "speaker.wave.2.fill")
                                    .font(.body.weight(.medium))
                                    .foregroundColor(StormStyle.gold)
                                    .frame(minHeight: 44)
                            } else {
                                StormTextButton(title: "Hear it spoken over you") {
                                    voice.onFinish = {
                                        withAnimation { finished = true }
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { onDone(.heard) }
                                    }
                                    voiceUsed = true
                                    voice.speak(line.text)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 36)
                .stormAppear(v, delay: 0.2)
            }
        }
        .onAppear { v = true }
        .onDisappear { voice.stop() }
    }
}

// MARK: - 6. How was that?

private struct StormFeelingScreen: View {
    let onPick: (StormFeeling?) -> Void
    @State private var picked: StormFeeling?
    @State private var v = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            StormHeader(title: "How was that?", subtitle: "You just spoke God's Word over your storm.", shown: v)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(StormFeeling.allCases) { feeling in
                    Button {
                        guard picked == nil else { return }
                        picked = feeling
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { onPick(feeling) }
                    } label: {
                        VStack(spacing: 10) {
                            Image(systemName: feeling.symbol).font(.title2)
                            Text(feeling.label).font(.body.weight(.semibold))
                        }
                        .foregroundColor(picked == feeling ? StormStyle.navy : .white)
                        .frame(maxWidth: .infinity, minHeight: 104)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(picked == feeling ? StormStyle.gold : Color.white.opacity(0.08))
                                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
                        )
                    }
                    .buttonStyle(.dsPressable(feel: .tapLight))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 28)
            .stormAppear(v, delay: 0.12)
            Spacer()
            StormTextButton(title: "Skip") { onPick(nil) }
                .padding(.bottom, 40)
        }
        .onAppear { v = true }
    }
}

// MARK: - 6b. Benefit screen

/// Right after she speaks: what speaking will do for her, in her storm's three
/// promises. The paywall repeats the same three, in the same order, so it reads
/// as "unlock what you were just shown". All copy comes from the storm config.
private struct StormPromiseScreen: View {
    let storm: Storm
    let onContinue: () -> Void
    @State private var v = false
    @State private var shownPromises = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var config: ResolvedStormConfig { StormConfigStore.resolved(for: storm) }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    Spacer().frame(height: 100)
                    Text(config.benefitHeadline)
                        .font(.title.weight(.bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .stormAppear(v)
                    VStack(spacing: 6) {
                        Text("\u{201C}Death and life are in the power of the tongue.\u{201D}")
                            .font(.system(.title3, design: .serif).italic())
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Proverbs 18:21")
                            .font(.callout.weight(.semibold))
                            .foregroundColor(StormStyle.gold)
                    }
                    .stormAppear(v, delay: 0.08)
                    Text("When you speak God's promises over your \(config.bodyLabel), you're not hoping harder. You're agreeing with what He already said.")
                        .font(.body)
                        .foregroundColor(StormStyle.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .stormAppear(v, delay: 0.16)
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(Array(config.promises.enumerated()), id: \.offset) { index, promise in
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(StormStyle.gold)
                                    .accessibilityHidden(true)
                                Text(promise)
                                    .font(.body)
                                    .foregroundColor(.white)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .opacity(reduceMotion || index < shownPromises ? 1 : 0)
                            .offset(x: reduceMotion || index < shownPromises ? 0 : -10)
                        }
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.06)))
                    .stormAppear(v, delay: 0.24)
                }
                .padding(.horizontal, 24)
            }
            StormPrimaryButton(title: "Continue", action: onContinue)
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 40)
        }
        .onAppear {
            v = true
            AnalyticsService.shared.track("storm_benefit_screen_shown", parameters: [
                "storm": storm.rawValue, "config": StormConfigStore.source
            ])
        }
        .task {
            // Checkmarks land one at a time, ~0.2s apart, after the card appears.
            guard !reduceMotion else { return }
            try? await Task.sleep(nanoseconds: 450_000_000)
            for i in 1...max(config.promises.count, 1) {
                withAnimation(.easeOut(duration: 0.3)) { shownPromises = i }
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
        }
    }
}

// MARK: - 7. Pick your time

private struct StormMorningTimeScreen: View {
    @Binding var time: Date
    let onContinue: () -> Void
    @State private var v = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            StormHeader(title: "When will you speak each morning?",
                        subtitle: "Your Daily Burst will be ready: 7 scriptures to speak before the day starts talking to you.",
                        shown: v)
            DatePicker("Morning time", selection: $time, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .colorScheme(.dark)
                .padding(.top, 12)
                .stormAppear(v, delay: 0.12)
            Spacer()
            StormPrimaryButton(title: "Continue", action: onContinue)
                .padding(.horizontal, 24)
                .padding(.bottom, 44)
        }
        .onAppear { v = true }
    }
}

// MARK: - 7b. Reminder explainer, then the iOS prompt

private struct StormReminderExplainerScreen: View {
    let storm: Storm
    let time: Date
    let isBusy: Bool
    let onChoice: (Bool) -> Void
    @State private var v = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 20) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 52))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundColor(StormStyle.gold)
                    .accessibilityHidden(true)
                    .stormAppear(v)
                Text("Your Daily Burst, every morning at \(time.formatted(date: .omitted, time: .shortened))")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .stormAppear(v, delay: 0.08)
                Text("One reminder a day. Tap it and speak 7 scriptures for \(storm.domain) out loud. That's the whole habit.")
                    .font(.body)
                    .foregroundColor(StormStyle.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .stormAppear(v, delay: 0.16)
            }
            .padding(.horizontal, 28)
            Spacer()
            VStack(spacing: 8) {
                StormPrimaryButton(title: "Turn on my reminder", isLoading: isBusy) { onChoice(true) }
                StormTextButton(title: "Not now") { onChoice(false) }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .onAppear { v = true }
    }
}

// MARK: - 8. Your 7-day plan

private struct StormPlanScreen: View {
    let storm: Storm
    let morning: Date
    let onContinue: () -> Void
    @State private var v = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    Spacer().frame(height: 92)
                    VStack(spacing: 10) {
                        Text(StormConfigStore.resolved(for: storm).planTitle)
                            .font(.title.weight(.bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        Text("Every morning at \(morning.formatted(date: .omitted, time: .shortened)), a Daily Burst of 7 scriptures for \(storm.domain). Each day opens with its own promise.")
                            .font(.body)
                            .foregroundColor(StormStyle.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 24)
                    .stormAppear(v)

                    VStack(spacing: 0) {
                        ForEach(Array(storm.planDays.enumerated()), id: \.offset) { index, line in
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle().fill(index == 0 ? StormStyle.gold : Color.white.opacity(0.1))
                                        .frame(width: 40, height: 40)
                                    if index == 0 {
                                        Image(systemName: "checkmark").font(.body.weight(.bold))
                                            .foregroundColor(StormStyle.navy)
                                    } else {
                                        Text("\(index + 1)").font(.body.weight(.bold)).foregroundColor(.white)
                                    }
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(index == 0 ? "Day 1 · Spoken today" : "Day \(index + 1)")
                                        .font(.body.weight(.semibold))
                                        .foregroundColor(.white)
                                    Text(index == 0 ? line.reference : "\(line.reference) + 6 more")
                                        .font(.callout)
                                        .foregroundColor(index == 0 ? StormStyle.gold : StormStyle.secondary)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 10)
                            .accessibilityElement(children: .combine)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.white.opacity(0.06)))
                    .padding(.horizontal, 20)
                    .stormAppear(v, delay: 0.12)
                    Spacer().frame(height: 12)
                }
            }
            StormPrimaryButton(title: "Continue", action: onContinue)
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 40)
        }
        .onAppear { v = true }
    }
}
