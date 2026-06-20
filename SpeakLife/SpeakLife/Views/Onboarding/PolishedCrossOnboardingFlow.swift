//
//  PolishedCrossOnboardingFlow.swift
//  SpeakLife
//
//  Cross-centered onboarding flow emphasizing God's generosity
//

import SwiftUI
import FirebaseAnalytics
import UserNotifications

// MARK: - Tab Enum
enum PolishedCrossTab: Int {
    case testimonials = 0
    case foundationalTruth = 1
    case hiddenLimitation = 2
    case crossAnchor = 3
    case identityShift = 4
    case declarationReframe = 5
    case removeGuilt = 6
    case futureVision = 7
    case transformation = 8
    case dailyBurst = 9
    case subscription = 10
    case notification = 11
    case complete = 12
}

// MARK: - Main View
struct PolishedCrossOnboardingFlow: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var timerViewModel: TimerViewModel
    @Environment(\.colorScheme) var colorScheme
    
    @State var selection: PolishedCrossTab = .testimonials
    @State private var selectedLimitations: Set<String> = []
    @State private var selectedDesires: Set<String> = []
    
    let impactMed = UIImpactFeedbackGenerator(style: .soft)
    
    var body: some View {
        GeometryReader { geometry in
            TabView(selection: $selection) {
                
                // Screen 1: Social Proof
                TestimonialsOnboardingView(size: geometry.size) {
                    advance()
                }
                .tag(PolishedCrossTab.testimonials)
                
                // Screen 2: Foundational Truth
                FoundationalTruthScreen(
                    size: geometry.size,
                    onContinue: advance
                )
                .tag(PolishedCrossTab.foundationalTruth)
                
                // Screen 3: Hidden Limitation
                HiddenLimitationScreen(
                    size: geometry.size,
                    selectedLimitations: $selectedLimitations,
                    onContinue: advance
                )
                .tag(PolishedCrossTab.hiddenLimitation)
                
                // Screen 4: Cross Anchor
                CrossAnchorScreen(
                    size: geometry.size,
                    onContinue: advance
                )
                .tag(PolishedCrossTab.crossAnchor)
                
                // Screen 5: Identity Shift
                IdentityShiftScreen(
                    size: geometry.size,
                    onContinue: advance
                )
                .tag(PolishedCrossTab.identityShift)
                
                // Screen 6: Declaration Reframe
                DeclarationReframeScreen(
                    size: geometry.size,
                    onContinue: advance
                )
                .tag(PolishedCrossTab.declarationReframe)
                
                // Screen 7: Remove Guilt
                RemoveGuiltScreen(
                    size: geometry.size,
                    selectedDesires: $selectedDesires,
                    onContinue: advance
                )
                .tag(PolishedCrossTab.removeGuilt)
                
                // Screen 8: Future Vision
                FutureVisionScreen(
                    size: geometry.size,
                    onContinue: advance
                )
                .tag(PolishedCrossTab.futureVision)
                
                // Screen 9: Transformation Promise
                TransformationPromiseScreen(
                    size: geometry.size,
                    onContinue: advance
                )
                .tag(PolishedCrossTab.transformation)
                
                // Screen 10: Daily Burst Experience
                OnboardingDailyBurstScreen(
                    size: geometry.size,
                    onContinue: advance
                )
                .tag(PolishedCrossTab.dailyBurst)
                
                // Screen 11: Subscription
                OptimizedSubscriptionView(callback: {
                    advance()
                })
                .tag(PolishedCrossTab.subscription)
                
                // Screen 12: Notifications
                NotificationOnboarding(size: geometry.size) {
                    askNotificationPermission()
                }
                .tag(PolishedCrossTab.notification)
                
                // Screen 13: Complete
//                CompletionScreen(size: geometry.size) {
//                    completeOnboarding()
//                }
//                .tag(PolishedCrossTab.complete)
            }
            .frame(width: geometry.size.width)
            .ignoresSafeArea()
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .preferredColorScheme(.dark)
        .onAppear {
            UIScrollView.appearance().isScrollEnabled = false
            Analytics.logEvent("PolishedCrossOnboarding_Started", parameters: nil)
        }
    }
    
    private func advance() {
        withAnimation {
            switch selection {
            case .testimonials:
                selection = .foundationalTruth
            case .foundationalTruth:
                selection = .hiddenLimitation
            case .hiddenLimitation:
                if !selectedLimitations.isEmpty {
                    selection = .crossAnchor
                }
            case .crossAnchor:
                selection = .identityShift
            case .identityShift:
                selection = .declarationReframe
            case .declarationReframe:
                selection = .removeGuilt
            case .removeGuilt:
                if !selectedDesires.isEmpty {
                    selection = .futureVision
                }
            case .futureVision:
                selection = .transformation
            case .transformation:
                selection = .dailyBurst
            case .dailyBurst:
                selection = .subscription
            case .subscription:
                selection = .notification
            case .notification:
                selection = .complete
            case .complete:
                completeOnboarding()
            }
        }
        Juice.play(.tapLight)
    }
    
    func askNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { success, error in
            Analytics.logEvent("notification_permission", parameters: ["granted": success])
            if success {
                DispatchQueue.main.async {
                    DailyDeclarationReminderService.shared.isEnabled = true
                    // Only advance after permission is granted or denied
                    advance()
                }
            } else {
                // Also advance if permission is denied
                DispatchQueue.main.async {
                    advance()
                }
            }
        }
    }
    
    private func completeOnboarding() {
        Analytics.logEvent("PolishedCrossOnboarding_Completed", parameters: [
            "limitations_selected": selectedLimitations.joined(separator: ","),
            "desires_selected": selectedDesires.joined(separator: ",")
        ])
        withAnimation {
            appState.isOnboarded = true
            LifecycleNotificationService.shared.scheduleLifecycleNotifications()
        }
        
        timerViewModel.startTimerAfterOnboarding()
    }
}

// MARK: - Screen 2: Foundational Truth
struct FoundationalTruthScreen: View {
    let size: CGSize
    let onContinue: () -> Void
    @State private var contentOpacity = 0.0
    @State private var showSecondPart = false
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    
    var body: some View {
        ZStack {
            backgroundView
            
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: size.height * 0.25)
                
                VStack(spacing: 30) {
                    if !showSecondPart {
                        VStack(spacing: 20) {
                            Text("God didn't hesitate with you.")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                            
                            Text("He gave His most treasured possession—")
                                .font(.system(size: 18))
                                .foregroundColor(.white.opacity(0.85))
                                .multilineTextAlignment(.center)
                            
                            Text("Jesus")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                        }
                        .transition(.scale.combined(with: .opacity))
                    } else {
                        VStack(spacing: 20) {
                            Image(systemName: "gift.fill")
                                .font(.system(size: 50))
                                .foregroundColor(Color(red: 0.9, green: 0.7, blue: 0.3))
                            
                            Text("If He didn't withhold Jesus,")
                                .font(.system(size: 22))
                                .foregroundColor(.white.opacity(0.9))
                            
                            Text("nothing else is off-limits.")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 30)
                .opacity(contentOpacity)
                
                Spacer()
                
                Button(action: nextPhase) {
                    Text(showSecondPart ? "I receive this truth →" : "Continue →")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: size.width * 0.85, height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .fill(DS.Gradient.gold)
                        )
                }
                .buttonStyle(.dsPressable(feel: .tapSolid, haptics: false))
                .padding(.bottom, 40)
            }
        }
        .frame(width: size.width)
        .onAppear {
            withAnimation(.easeIn(duration: 0.8)) {
                contentOpacity = 1
            }
        }
    }
    
    private func nextPhase() {
        if !showSecondPart {
            withAnimation(.easeInOut(duration: 0.5)) {
                contentOpacity = 0
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showSecondPart = true
                withAnimation(.easeIn(duration: 0.5)) {
                    contentOpacity = 1
                }
            }
        } else {
            onContinue()
        }
    }
    
    private var backgroundView: some View {
        ZStack {
            Image(subscriptionStore.onboardingBGImage)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            
            Color.black.opacity(0.3)
                .ignoresSafeArea()
        }
    }
}

// MARK: - Screen 3: Hidden Limitation
struct HiddenLimitationScreen: View {
    let size: CGSize
    @Binding var selectedLimitations: Set<String>
    let onContinue: () -> Void
    @State private var contentOpacity = 0.0
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    
    let limitations = [
        ("house", "God won't provide for me"),
        ("heart.slash", "I'm too broken for healing"),
        ("cloud.rain", "My prayers don't reach heaven"),
        ("lock.circle", "My situation won't change"),
        ("hourglass", "It's too late for me"),
        ("xmark.shield", "God's promises aren't for me")
    ]
    
    var body: some View {
        ZStack {
            backgroundView
                .frame(width: size.width, height: size.height)
            
            VStack(spacing: 0) {
                Spacer().frame(height: size.height * 0.05)
                
                VStack(spacing: 16) {
                    Text("Faith isn't the problem—")
                        .font(.system(size: 20))
                        .foregroundColor(.white.opacity(0.9))
                    
                    Text("Expectation is.")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Most believers trust God for salvation,\nbut quietly limit Him in everyday life.")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                }
                .padding(.horizontal, 30)
                .opacity(contentOpacity)
                
                Spacer().frame(height: 30)
                
                Text("Which doubts whisper to you?")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                    .opacity(contentOpacity)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 10) {
                        ForEach(limitations, id: \.1) { icon, limitation in
                            LimitationButton(
                                icon: icon,
                                text: limitation,
                                isSelected: selectedLimitations.contains(limitation)
                            ) {
                                if selectedLimitations.contains(limitation) {
                                    selectedLimitations.remove(limitation)
                                } else {
                                    selectedLimitations.insert(limitation)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 100)
                }
                .opacity(contentOpacity)
                
                Spacer()
                
                Button(action: onContinue) {
                    Text(selectedLimitations.isEmpty ? "Select your doubts" : "God has an answer →")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: size.width * 0.85, height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .fill(Color(red: 0.4, green: 0.5, blue: 0.9).opacity(selectedLimitations.isEmpty ? 0.4 : 1))
                        )
                }
                .disabled(selectedLimitations.isEmpty)
                .padding(.bottom, 40)
            }
        }
        .frame(width: size.width)
        .onAppear {
            withAnimation(.easeIn(duration: 0.6)) {
                contentOpacity = 1
            }
        }
    }
    
    private var backgroundView: some View {
        ZStack {
            Image(subscriptionStore.onboardingBGImage)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            Color.black.opacity(0.4)
                .ignoresSafeArea()
        }
    }
}

// MARK: - Screen 4: Cross Anchor
struct CrossAnchorScreen: View {
    let size: CGSize
    let onContinue: () -> Void
    @State private var showVerse = false
    @State private var showMeaning = false
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    
    var body: some View {
        ZStack {
            backgroundView
                .frame(width: size.width, height: size.height)
            
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 30) {
                    Image("cross")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 160, height: 180)
                        .foregroundColor(Color(red: 0.9, green: 0.7, blue: 0.3))
                        .opacity(showVerse ? 1 : 0)
                        .scaleEffect(showVerse ? 1 : 0.5)
                    
                    if showVerse {
                        VStack(spacing: 16) {
                            Text("The Cross Settled This")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("\"He who did not spare His own Son...")
                                .font(.system(size: 18))
                                .foregroundColor(.white.opacity(0.9))
                                .multilineTextAlignment(.center)
                            
                            Text("how will He not also graciously give us all things?\"")
                                .font(.system(size: 18))
                                .foregroundColor(.white.opacity(0.9))
                                .multilineTextAlignment(.center)
                            
                            Text("Romans 8:32")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    
                    if showMeaning {
                        VStack(spacing: 12) {
                            Divider()
                                .background(Color.white.opacity(0.3))
                                .padding(.horizontal, 60)
                            
                            Text("The cross wasn't partial.")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                            
                            Text("It was heaven's full yes.")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(Color(red: 0.9, green: 0.7, blue: 0.3))
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 30)
                
                Spacer()
                
                Button(action: onContinue) {
                    Text("This changes everything →")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: size.width * 0.85, height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .fill(DS.Gradient.gold)
                        )
                }
                .buttonStyle(.dsPressable(feel: .tapSolid, haptics: false))
                .padding(.bottom, 40)
                .opacity(showMeaning ? 1 : 0.3)
                .disabled(!showMeaning)
            }
        }
        .frame(width: size.width)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.spring()) {
                    showVerse = true
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation(.spring()) {
                    showMeaning = true
                }
            }
        }
    }
    
    private var backgroundView: some View {
        ZStack {
            Image(subscriptionStore.onboardingBGImage)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            Color.black.opacity(0.3)
                .ignoresSafeArea()
        }
    }
}

// MARK: - Screen 5: Identity Shift
struct IdentityShiftScreen: View {
    let size: CGSize
    let onContinue: () -> Void
    @State private var showTransformation = false
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    
    var body: some View {
        ZStack {
            backgroundView
                .frame(width: size.width, height: size.height)
            
            VStack(spacing: 0) {
                Spacer()
                
                if !showTransformation {
                    VStack(spacing: 30) {
                        Image(systemName: "person.crop.circle.badge.xmark")
                            .font(.system(size: 60))
                            .foregroundColor(.red.opacity(0.7))
                        
                        Text("You were never meant\nto live begging")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        
                        VStack(spacing: 8) {
                            Text("Begging speaks uncertainty.")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.7))
                            
                            Text("Agreement speaks faith.")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                    .transition(.move(edge: .leading).combined(with: .opacity))
                } else {
                    VStack(spacing: 30) {
                        Image(systemName: "person.crop.circle.badge.checkmark")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                        
                        Text("Sons and daughters\ndon't negotiate—")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        
                        Text("they align.")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(Color(red: 0.9, green: 0.7, blue: 0.3))
                    }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
                
                Spacer()
                
                Button(action: {
                    if !showTransformation {
                        withAnimation(.easeInOut(duration: 0.6)) {
                            showTransformation = true
                        }
                    } else {
                        onContinue()
                    }
                }) {
                    Text(showTransformation ? "I am a son/daughter →" : "Show me my identity →")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: size.width * 0.85, height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .fill(Color(red: 0.4, green: 0.5, blue: 0.9))
                        )
                }
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 30)
        }
        .frame(width: size.width)
    }
    
    private var backgroundView: some View {
        ZStack {
            Image(subscriptionStore.onboardingBGImage)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            Color.black.opacity(0.3)
                .ignoresSafeArea()
        }
    }
}

// MARK: - Screen 6: Declaration Reframe
struct DeclarationReframeScreen: View {
    let size: CGSize
    let onContinue: () -> Void
    @State private var contentOpacity = 0.0
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    
    var body: some View {
        ZStack {
            backgroundView
                .frame(width: size.width, height: size.height)
            
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 30) {
                    Image(systemName: "text.bubble.fill")
                        .font(.system(size: 50))
                        .foregroundColor(Color(red: 0.4, green: 0.5, blue: 0.9))
                    
                    Text("Declarations are\nagreement, not hype")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    VStack(spacing: 16) {
                        Text("You don't speak to convince God.")
                            .font(.system(size: 17))
                            .foregroundColor(.white.opacity(0.85))
                        
                        Text("You speak to align your mind and future\nwith what He already said.")
                            .font(.system(size: 17))
                            .foregroundColor(.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                        
                        Divider()
                            .background(Color.white.opacity(0.3))
                            .padding(.horizontal, 60)
                        
                        Text("Faith speaks first.")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Color(red: 0.9, green: 0.7, blue: 0.3))
                    }
                }
                .padding(.horizontal, 30)
                .opacity(contentOpacity)
                
                Spacer()
                
                Button(action: onContinue) {
                    Text("I'm ready to align →")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: size.width * 0.85, height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .fill(Color(red: 0.4, green: 0.5, blue: 0.9))
                        )
                }
                .padding(.bottom, 40)
            }
        }
        .frame(width: size.width)
        .onAppear {
            withAnimation(.easeIn(duration: 0.8)) {
                contentOpacity = 1
            }
        }
    }
    
    private var backgroundView: some View {
        ZStack {
            Image(subscriptionStore.onboardingBGImage)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            Color.black.opacity(0.3)
                .ignoresSafeArea()
        }
    }
}

// MARK: - Screen 7: Remove Guilt
struct RemoveGuiltScreen: View {
    let size: CGSize
    @Binding var selectedDesires: Set<String>
    let onContinue: () -> Void
    @State private var contentOpacity = 0.0
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    
    let desires = [
        ("heart", "Peace in my mind and heart"),
        ("figure.walk", "Health and strength in my body"),
        ("dollarsign.circle", "Provision for my needs"),
        ("person.2", "Restoration in relationships"),
        ("star.fill", "Purpose and direction"),
        ("shield.checkered", "Protection for my family")
    ]
    
    var body: some View {
        ZStack {
            backgroundView
                .frame(width: size.width, height: size.height)
            
            VStack(spacing: 0) {
                Spacer().frame(height: size.height * 0.05)
                
                VStack(spacing: 16) {
                    Text("Doubting God's generosity\nis the real ceiling.")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.top, 8)
                        .multilineTextAlignment(.center)

                    VStack(spacing: 8) {
                        Text("Peace isn't excessive.")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.8))
                        Text("Health isn't unrealistic.")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.8))
                        Text("Provision isn't pride.")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(.horizontal, 30)
                .opacity(contentOpacity)
                
                Spacer().frame(height: 30)
                
                Text("What do you need from God?")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                    .opacity(contentOpacity)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 10) {
                        ForEach(desires, id: \.1) { icon, desire in
                            DesireButton(
                                icon: icon,
                                text: desire,
                                isSelected: selectedDesires.contains(desire)
                            ) {
                                if selectedDesires.contains(desire) {
                                    selectedDesires.remove(desire)
                                } else {
                                    selectedDesires.insert(desire)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 100)
                }
                .opacity(contentOpacity)
                
                Spacer()
                
                Button(action: onContinue) {
                    Text(selectedDesires.isEmpty ? "Select what you need" : "God wants this for you →")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: size.width * 0.85, height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .fill(Color(red: 0.3, green: 0.7, blue: 0.4).opacity(selectedDesires.isEmpty ? 0.4 : 1))
                        )
                }
                .disabled(selectedDesires.isEmpty)
                .padding(.bottom, 40)
            }
        }
        .frame(width: size.width)
        .onAppear {
            withAnimation(.easeIn(duration: 0.6)) {
                contentOpacity = 1
            }
        }
    }
    
    private var backgroundView: some View {
        ZStack {
            Image(subscriptionStore.onboardingBGImage)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            Color.black.opacity(0.4)
                .ignoresSafeArea()
        }
    }
}

// MARK: - Screen 8: Future Vision
struct FutureVisionScreen: View {
    let size: CGSize
    let onContinue: () -> Void
    @State private var showTransformation = false
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    
    var body: some View {
        ZStack {
            backgroundView
                .frame(width: size.width, height: size.height)
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 30) {
                    Text("What if fear never got\nthe first word again?")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    if showTransformation {
                        VStack(spacing: 20) {
                            // Before/After comparison
                            VStack(spacing: 16) {
                                // Old way
                                HStack(spacing: 16) {
                                    Image(systemName: "bolt.slash.circle")
                                        .font(.system(size: 24))
                                        .foregroundColor(.red.opacity(0.7))
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("OLD: \"What if it doesn't work out?\"")
                                            .font(.system(size: 14))
                                            .foregroundColor(.white.opacity(0.5))
                                            .strikethrough()
                                    }
                                    Spacer()
                                }
                                
                                // New way
                                HStack(spacing: 16) {
                                    Image(systemName: "bolt.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.green)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("NEW: \"God already worked it out\"")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                    Spacer()
                                }
                            }
                            
                            Divider()
                                .background(Color.white.opacity(0.3))
                            
                            // Second comparison
                            VStack(spacing: 16) {
                                // Old way
                                HStack(spacing: 16) {
                                    Image(systemName: "dollarsign.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.red.opacity(0.7))
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("OLD: \"I can't afford this\"")
                                            .font(.system(size: 14))
                                            .foregroundColor(.white.opacity(0.5))
                                            .strikethrough()
                                    }
                                    Spacer()
                                }
                                
                                // New way
                                HStack(spacing: 16) {
                                    Image(systemName: "hands.and.sparkles.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.green)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("NEW: \"My God supplies all my needs\"")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                    Spacer()
                                }
                            }
                            
                            Divider()
                                .background(Color.white.opacity(0.3))
                            
                            // Third comparison
                            VStack(spacing: 16) {
                                // Old way
                                HStack(spacing: 16) {
                                    Image(systemName: "heart.slash.circle")
                                        .font(.system(size: 24))
                                        .foregroundColor(.red.opacity(0.7))
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("OLD: \"I'm too broken\"")
                                            .font(.system(size: 14))
                                            .foregroundColor(.white.opacity(0.5))
                                            .strikethrough()
                                    }
                                    Spacer()
                                }
                                
                                // New way
                                HStack(spacing: 16) {
                                    Image(systemName: "heart.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.green)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("NEW: \"I'm a New Creation\"")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                    Spacer()
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    
                    Text("This is the life waiting for you—\nwhere truth speaks first.")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color(red: 0.9, green: 0.7, blue: 0.3))
                        .multilineTextAlignment(.center)
                        .opacity(showTransformation ? 1 : 0)
                }
                .padding(.horizontal, 30)
                
                Spacer()
                
                Button(action: onContinue) {
                    Text("I want this transformation →")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: size.width * 0.85, height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .fill(Color(red: 0.4, green: 0.5, blue: 0.9))
                        )
                }
                .padding(.bottom, 40)
            }
        }
        .frame(width: size.width)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                withAnimation(.spring()) {
                    showTransformation = true
                }
            }
        }
    }
    
    private var backgroundView: some View {
        ZStack {
            Image(subscriptionStore.onboardingBGImage)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            Color.black.opacity(0.3)
                .ignoresSafeArea()
        }
    }
}

// MARK: - Screen 9: Transformation Promise
struct TransformationPromiseScreen: View {
    let size: CGSize
    let onContinue: () -> Void
    @State private var visibleSteps: [Bool] = [false, false, false, false]
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    
    let transformationSteps = [
        ("1", "Scripture-rooted declarations", Color(red: 0.4, green: 0.5, blue: 0.9)),
        ("2", "Renew your mind daily", Color(red: 0.5, green: 0.6, blue: 0.9)),
        ("3", "Reshape your language", Color(red: 0.6, green: 0.7, blue: 0.9)),
        ("4", "Retrain your expectations", Color(red: 0.7, green: 0.8, blue: 0.9))
    ]
    
    var body: some View {
        ZStack {
            backgroundView
                .frame(width: size.width, height: size.height)
            
            VStack(spacing: 0) {
                Spacer().frame(height: size.height * 0.2)
                
                VStack(spacing: 20) {
                    Text("Speak Life trains\nbelief daily")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    Text("This is alignment—every day.")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.horizontal, 30)
                
                Spacer()
                
                VStack(spacing: 16) {
                    ForEach(0..<transformationSteps.count, id: \.self) { index in
                        if visibleSteps[index] {
                            HStack(spacing: 16) {
                                Circle()
                                    .fill(transformationSteps[index].2.opacity(0.2))
                                    .overlay(
                                        Circle()
                                            .stroke(transformationSteps[index].2, lineWidth: 2)
                                    )
                                    .frame(width: 50, height: 50)
                                    .overlay(
                                        Text(transformationSteps[index].0)
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundColor(.white)
                                    )
                                
                                Text(transformationSteps[index].1)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white.opacity(0.9))
                                
                                Spacer()
                            }
                            .padding(.horizontal, 40)
                            .transition(.move(edge: .leading).combined(with: .opacity))
                        }
                    }
                }
                
                Spacer()
                
                VStack(spacing: 16) {
                    Text("Your words are a gateway")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Color(red: 0.9, green: 0.7, blue: 0.3))
                    
                    Text("What you consistently speak\nbecomes what you consistently expect.")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                }
                .opacity(visibleSteps[3] ? 1 : 0)
                
                Spacer().frame(height: 20)
                
                Button(action: onContinue) {
                    Text("Let's build this together →")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: size.width * 0.85, height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .fill(Color(red: 0.9, green: 0.7, blue: 0.3))
                        )
                }
                .padding(.bottom, 40)
                .opacity(visibleSteps[3] ? 1 : 0.3)
                .disabled(!visibleSteps[3])
            }
        }
        .frame(width: size.width)
        .onAppear {
            for i in 0..<transformationSteps.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.4) {
                    withAnimation(.spring()) {
                        visibleSteps[i] = true
                    }
                }
            }
        }
    }
    
    private var backgroundView: some View {
        ZStack {
            Image(subscriptionStore.onboardingBGImage)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            Color.black.opacity(0.3)
                .ignoresSafeArea()
        }
    }
}

// MARK: - Completion Screen
//struct CompletionScreen: View {
//    let size: CGSize
//    let onContinue: () -> Void
//    @State private var showContent = false
//    @EnvironmentObject var subscriptionStore: SubscriptionStore
//    
//    var body: some View {
//        ZStack {
//            backgroundView
//                .frame(width: size.width, height: size.height)
//            
//            VStack(spacing: 0) {
//                Spacer()
//                
//                VStack(spacing: 30) {
//                    Image(systemName: "hands.and.sparkles.fill")
//                        .font(.system(size: 60))
//                        .foregroundColor(Color(red: 0.9, green: 0.7, blue: 0.3))
//                        .scaleEffect(showContent ? 1 : 0.5)
//                        .opacity(showContent ? 1 : 0)
//                    
//                    VStack(spacing: 16) {
//                        Text("Welcome to Your New Life")
//                            .font(.system(size: 28, weight: .bold))
//                            .foregroundColor(.white)
//                        
//                        Text("Where faith speaks first\nand heaven responds")
//                            .font(.system(size: 18))
//                            .foregroundColor(.white.opacity(0.85))
//                            .multilineTextAlignment(.center)
//                    }
//                    .opacity(showContent ? 1 : 0)
//                    
//                    VStack(spacing: 12) {
//                        HStack(spacing: 8) {
//                            Image(systemName: "checkmark.circle.fill")
//                                .foregroundColor(.green)
//                            Text("Daily morning burst activated")
//                                .font(.system(size: 14))
//                                .foregroundColor(.white.opacity(0.8))
//                        }
//                        
//                        HStack(spacing: 8) {
//                            Image(systemName: "checkmark.circle.fill")
//                                .foregroundColor(.green)
//                            Text("8 AM reminder scheduled")
//                                .font(.system(size: 14))
//                                .foregroundColor(.white.opacity(0.8))
//                        }
//                        
//                        HStack(spacing: 8) {
//                            Image(systemName: "checkmark.circle.fill")
//                                .foregroundColor(.green)
//                            Text("Ready to build spiritual strength")
//                                .font(.system(size: 14))
//                                .foregroundColor(.white.opacity(0.8))
//                        }
//                    }
//                    .opacity(showContent ? 1 : 0)
//                }
//                .padding(.horizontal, 30)
//                
//                Spacer()
//                
//                Button(action: onContinue) {
//                    Text("Begin Your Journey")
//                        .font(.system(size: 17, weight: .semibold))
//                        .foregroundColor(.black)
//                        .frame(width: size.width * 0.85, height: 50)
//                        .background(
//                            RoundedRectangle(cornerRadius: 25)
//                                .fill(
//                                    LinearGradient(
//                                        colors: [Color(red: 0.9, green: 0.7, blue: 0.3), Color.yellow],
//                                        startPoint: .leading,
//                                        endPoint: .trailing
//                                    )
//                                )
//                        )
//                }
//                .padding(.bottom, 40)
//                .opacity(showContent ? 1 : 0)
//            }
//        }
//        .frame(width: size.width)
//        .onAppear {
//            withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
//                showContent = true
//            }
//        }
//    }
//    
//    private var backgroundView: some View {
//        ZStack {
//            Image(subscriptionStore.onboardingBGImage)
//                .resizable()
//                .scaledToFill()
//                .ignoresSafeArea()
//            Color.black.opacity(0.3)
//                .ignoresSafeArea()
//        }
//    }
//}

// MARK: - Helper Components
struct LimitationButton: View {
    let icon: String
    let text: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(isSelected ? .red : .white.opacity(0.5))
                    .frame(width: 24)
                
                Text(text)
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(isSelected ? 1 : 0.85))
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.red.opacity(0.8))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(isSelected ? 0.15 : 0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.red.opacity(0.5) : Color.white.opacity(0.15), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct DesireButton: View {
    let icon: String
    let text: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(isSelected ? Color(red: 0.3, green: 0.7, blue: 0.4) : .white.opacity(0.5))
                    .frame(width: 24)
                
                Text(text)
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(isSelected ? 1 : 0.85))
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color(red: 0.3, green: 0.7, blue: 0.4))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(isSelected ? 0.15 : 0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color(red: 0.3, green: 0.7, blue: 0.4) : Color.white.opacity(0.15), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
