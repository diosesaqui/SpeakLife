//
//  DeclarationView.swift
//  Dios Es Aqui
//
//  Created by Riccardo Washington on 1/1/22.
//

import SwiftUI
import MessageUI
import StoreKit
import UIKit
import FirebaseAnalytics
import Combine

/// Identifiable wrapper for the prefill text passed to the Warrior Room
/// testimony composer. Setting it on a parent's @State drives a
/// `.sheet(item:)` that presents `WarriorRoomTestimonyComposer`.
struct WarriorRoomTestimonyPrefill: Identifiable {
    let id = UUID()
    let text: String
}


struct DeclarationView: View {
    
    // MARK: - Properties
    
    @EnvironmentObject var viewModel: DeclarationViewModel
    @EnvironmentObject var themeViewModel: ThemeViewModel
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @EnvironmentObject var devotionalViewModel: DevotionalViewModel
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var streakViewModel: EnhancedStreakViewModel
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isIPad: Bool { horizontalSizeClass == .regular }
    
    @AppStorage("review.counter") private var reviewCounter = 0
    @AppStorage("share.counter") private var shareCounter = 0
    @AppStorage("review.try") private var reviewTry = 1
    @AppStorage("shared.count") private var shared = 0
    @AppStorage("premium.count") private var premiumCount = 0
    @State var result: Result<MFMailComposeResult, Error>? = nil
    @State private var share = false
    @State private var goPremium = false
    @State var isShowingMailView = false
    @State var showDailyDevotion = false
    @State private var isPresentingPremiumView = false
    @State private var isPresentingCreateYourOwn = false
    @EnvironmentObject var timerViewModel: TimerViewModel
    @State var presentDevotionalSubscriptionView = false
    @State var isPresentingBottomSheet = false
    @State private var showDailyBurst = false
    
    // Consolidated sheet management
    @State private var activeSheet: ActiveSheet?
    @State private var mailResult: Result<MFMailComposeResult, Error>? = nil
    
    enum ActiveSheet: Identifiable {
        case premium
        case createYourOwn  
        case devotionalSubscription
        case loveLetter
        case dailyChecklist
        case timerStreak
        case personalDeclaration
       // case mail
        
        var id: Int { hashValue }
    }
    @State private var showSpeakAloudBanner = false
    @State private var showBreakthroughFlow = false
    @State private var showNewDeclarationSheet = false
    @State private var showMomentDeclarationSheet = false
    private let momentDeclarationGenerator: OnDeviceDeclarationGeneratorProtocol = OnDeviceDeclarationGenerator()
    /// Drives the pulse animation on the checklist icon when the user has
    /// pending tasks for the day. Toggled by the autoreverse animation below.
    @State private var checklistPulse = false
    /// Identifiable prefill for the Warrior Room testimony composer.
    /// Set when the Breakthrough flow's "Share Testimony" button fires —
    /// presenting the prefilled composer is how we celebrate.
    @State private var warriorRoomTestimonyPrefill: WarriorRoomTestimonyPrefill?
    @StateObject private var speechSynthesizer = SpeechSynthesizer()
    @State private var loadedDeclaration: PersonalDeclaration? = nil
    
    private var cancellables = Set<AnyCancellable>()
    
    @State private var timeElapsed = 0
    
    func declarationContent(_ geometry: GeometryProxy) -> some View {
        DeclarationContentView(themeViewModel: themeViewModel, viewModel: viewModel)
            .frame(width: geometry.size.width, height: geometry.size.height)
            .onReceive(viewModel.$requestReview) { value in
                if value {
                    showReview()
                }
            }
    }
    
    // MARK: - Overlay Content
    
    @ViewBuilder
    private func overlayContent(_ geometry: GeometryProxy) -> some View {
        VStack {
            topButtonsRow(geometry)
            Spacer()
            if appState.showIntentBar {
                IntentsBarView(viewModel: viewModel, themeViewModel: themeViewModel)
                    .opacity(appState.showScreenshotLabel ? 0 : 1)
                    .frame(height: geometry.size.height * 0.10)
            }
        }
    }
    
    // Personal Declaration compact button shown in top row — always visible
    @ViewBuilder
    private var personalDeclarationButton: some View {
        if appState.hasPersonalDeclaration {
            // Active declaration — gold filled hands icon
            Button {
                Task {
                    loadedDeclaration = await DIContainer.shared.personalDeclarationRepository.load()
                    activeSheet = .personalDeclaration
                }
            } label: {
                Image(systemName: "hands.sparkles.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.yellow)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.7))
                            .overlay(
                                Circle()
                                    .stroke(Color.yellow.opacity(0.4), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(PlainButtonStyle())
            .onAppear {
                Task {
                    loadedDeclaration = await DIContainer.shared.personalDeclarationRepository.load()
                }
            }
            .onChange(of: appState.scrollToPersonalDeclaration) { shouldScroll in
                if shouldScroll {
                    Task {
                        loadedDeclaration = await DIContainer.shared.personalDeclarationRepository.load()
                        activeSheet = .personalDeclaration
                        appState.scrollToPersonalDeclaration = false
                    }
                }
            }
        } else {
            // No active declaration — dimmed outline, tap to create
            Button {
                showNewDeclarationSheet = true
            } label: {
                Image(systemName: "hands.sparkles")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.5))
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    @ViewBuilder
    private func topButtonsRow(_ geometry: GeometryProxy) -> some View {
        HStack {
            //loveLetterButton
            devotionalButton
            //dailyBurstButton
            personalDeclarationButton
            momentDeclarationButton

            speakAloudBannerSection(geometry)
            if !showSpeakAloudBanner {
                Spacer()
               // timerSection
                dailyChecklistButton
                if !subscriptionStore.isPremium {
                    premiumButton
                }
            }
        }
        .padding([.leading, .trailing])
    }

    /// "Declaration of the Moment" — premium-only. Hidden for free users
    /// so the top button row keeps its original layout (the extra icon
    /// was squeezing the personal-declaration button off screen). Free
    /// users still get this kind of flow via the Warrior Room
    /// post-submit hook, which is rate-limited to 1/day.
    @ViewBuilder
    private var momentDeclarationButton: some View {
        if momentDeclarationGenerator.isAvailable && subscriptionStore.isPremium {
            Button {
                Analytics.logEvent("moment_declaration_open",
                                   parameters: ["source": "declaration_view"])
                showMomentDeclarationSheet = true
            } label: {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.7))
                            .overlay(
                                Circle()
                                    .stroke(Color(hex: "A78BFA").opacity(0.6), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    @ViewBuilder
    private var loveLetterButton: some View {
        if !showSpeakAloudBanner {
            Button(action: {
                activeSheet = .loveLetter
                Analytics.logEvent("love_letter_opened", parameters: nil)
            }) {
                Image(systemName: "envelope.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.7))
                            .overlay(
                                Circle()
                                    .stroke(Constants.DAMidBlue.opacity(0.6), lineWidth: 1)
                            )
                    )
            }
        }
    }
    
    @ViewBuilder
    private var dailyChecklistButton: some View {
        if !showSpeakAloudBanner {
            let isDone = streakViewModel.todayChecklist.isStreakEarned
            Button(action: {
                activeSheet = .dailyChecklist
                Analytics.logEvent("checkList_opened", parameters: nil)
            }) {
                Image(systemName: "checklist")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isDone ? .white : Constants.gold)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.7))
                            .overlay(
                                Circle()
                                    .stroke(
                                        isDone
                                            ? Constants.DAMidBlue.opacity(0.6)
                                            : Constants.gold.opacity(0.8),
                                        lineWidth: isDone ? 1 : 1.5
                                    )
                            )
                    )
                    .shadow(
                        color: Constants.gold.opacity(checklistPulse ? 0.6 : 0.0),
                        radius: checklistPulse ? 12 : 0
                    )
            }
            // Animation modifier switches between repeatForever (pending) and a
            // one-shot easeInOut (done). Changing the modifier AND the value
            // together lets SwiftUI stop the repeating cycle cleanly on completion,
            // and restart it when tasks reset the next day.
            .animation(
                isDone
                    ? .easeInOut(duration: 0.4)
                    : .easeInOut(duration: 1.1).repeatForever(autoreverses: true),
                value: checklistPulse
            )
            .onAppear {
                checklistPulse = !isDone
            }
            .onDisappear { checklistPulse = false }
            .onChange(of: isDone) { done in
                // Drive checklistPulse explicitly so the right animation modifier
                // is active at the moment the value changes.
                checklistPulse = !done
            }
        }
    }
    
    @ViewBuilder
    private var dailyBurstButton: some View {
        if !showSpeakAloudBanner {
            Button(action: {
                showDailyBurst = true
                Analytics.logEvent("daily_burst_opened", parameters: [
                    "source": "home_screen"
                ])
            }) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 1.0, green: 0.58, blue: 0.0), Color(red: 1.0, green: 0.34, blue: 0.13)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    )
            }
        }
    }
    
    var devotionalButton: some View {
        let title: String
        if #available(iOS 17, *) {
            title = "book.pages.fill"
        } else {
            title = "book.fill"
        }
        return CapsuleImageButton(title: title) {
            handleDevotionalPresentation(true)
            Selection.shared.selectionFeedback()
        }
    }
    
    @ViewBuilder
    private func speakAloudBannerSection(_ geometry: GeometryProxy) -> some View {
        SpeakAloudBanner(showBanner: $showSpeakAloudBanner) {
            showSpeakAloudBanner = false
        }
        .frame(height: geometry.size.height * 0.10)
    }
    
    @ViewBuilder
    private var timerSection: some View {
        VStack(spacing: 4) {
            if !timerViewModel.checkIfCompletedToday() {
                CountdownTimerView(viewModel: timerViewModel) {
                    showTimerSheet()
                }
            }
        }
    }
    
    @ViewBuilder
    private var premiumButton: some View {
        Spacer()
            .frame(width: 8)
        
        CapsuleImageButton(title: "crown.fill") {
            premiumView()
            Selection.shared.selectionFeedback()
        }
        .opacity(appState.showScreenshotLabel ? 0 : 1)
        .foregroundStyle(Constants.gold)
    }
    
    // MARK: - Background Content
    
    @ViewBuilder
    private var backgroundContent: some View {
        ZStack {
            if themeViewModel.showUserSelectedImage {
                Image(uiImage: themeViewModel.selectedImage!)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()
            } else {
                Image(themeViewModel.selectedTheme.backgroundImageString)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()
            }
            
            Rectangle()
                .fill(Color.black.opacity(themeViewModel.selectedTheme.blurEffect ? 0.25 : 0))
                .edgesIgnoringSafeArea(.all)
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                declarationContent(geometry)
                
                if !appState.showScreenshotLabel {
                    overlayContent(geometry)
                }
            }
        }
        .background(backgroundContent)
        // On iPad use fullScreenCover so sheets fill the whole screen.
        // On iPhone keep the standard bottom sheet behaviour.
        .modifier(AdaptiveSheetModifier(item: $activeSheet, isIPad: isIPad) { sheet in
            AnyView(sheetContent(sheet))
        })
        .onChange(of: presentDevotionalSubscriptionView, perform: handleDevotionalPresentation)
        .alert(isPresented: $viewModel.showErrorMessage, content: errorAlert)
        .alert(isPresented: $viewModel.helpUsGrowAlert, content: growAlert)
        .alert("Know anyone that can benefit from SpeakLife?", isPresented: $share, actions: shareAlert)
        .sheet(isPresented: $isShowingMailView) {
            MailView(isShowing: $isShowingMailView, result: self.$result, origin: .review, isSubscribed: subscriptionStore.isPremium)
        }
        .sheet(isPresented: $showMomentDeclarationSheet) {
            MomentDeclarationSheet(source: "declaration_view")
                .environmentObject(subscriptionStore)
        }
        .fullScreenCover(isPresented: $showDailyBurst) {
            DailyDeclarationBurstView()
                .environmentObject(viewModel)
                .environmentObject(themeViewModel)
                .environmentObject(timerViewModel)
                .environmentObject(streakViewModel)
        }
        // Top-level cover — handles both "create first declaration" and "set new after breakthrough"
        .fullScreenCover(isPresented: $showNewDeclarationSheet) {
            GeometryReader { geo in
                PersonalDeclarationOnboardingView(
                    viewModel: DIContainer.shared.makePersonalDeclarationViewModel(),
                    size: geo.size
                ) { newDeclaration in
                    if newDeclaration != nil {
                        appState.hasPersonalDeclaration = true
                    }
                    showNewDeclarationSheet = false
                    Task {
                        loadedDeclaration = await DIContainer.shared.personalDeclarationRepository.load()
                    }
                }
                .environmentObject(appState)
            }
            .ignoresSafeArea()
        }
        .onAppear(perform: handleOnAppear)
        .onDisappear(perform: handleOnDisappear)
    }
    
    // MARK: - Sheet Management
    
    @ViewBuilder
    private func sheetContent(_ sheet: ActiveSheet) -> some View {
        switch sheet {
        case .createYourOwn:
            CreateYourOwnView()
        case .premium:
            PremiumView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .devotionalSubscription:
            DevotionalView(viewModel: devotionalViewModel)
        case .loveLetter:
            AbbasLoveView()
        case .dailyChecklist:
            ModernDailyChecklistView(viewModel: streakViewModel)
                .environmentObject(streakViewModel)
        case .timerStreak:
            TimerStreakDetailView(timerViewModel: timerViewModel)

        case .personalDeclaration:
            if let declaration = loadedDeclaration {
                PersonalDeclarationCard(
                    declaration: declaration,
                    onBreakthrough: {
                        activeSheet = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showBreakthroughFlow = true
                        }
                    }
                )
                .fullScreenCover(isPresented: $showBreakthroughFlow) {
                    if let d = loadedDeclaration {
                        BreakthroughFlowView(
                            declaration: d,
                            onDismiss: { showBreakthroughFlow = false },
                            onSetNew: {
                                showBreakthroughFlow = false
                                showNewDeclarationSheet = true
                            },
                            onShareToWarriorRoom: { prefill in
                                warriorRoomTestimonyPrefill = WarriorRoomTestimonyPrefill(text: prefill)
                            }
                        )
                        .environmentObject(appState)
                    }
                }
                .sheet(item: $warriorRoomTestimonyPrefill) { prefill in
                    WarriorRoomTestimonyComposer(
                        initialText: prefill.text,
                        initialIsTestimony: true
                    )
                    .environmentObject(subscriptionStore)
                }

            } else {
                ProgressView().tint(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(red: 0.06, green: 0.08, blue: 0.18))
            }
        }
    }
    
    private func handleDevotionalPresentation(_ newValue: Bool) {
        if newValue && activeSheet == nil {
            activeSheet = .devotionalSubscription
            presentDevotionalSubscriptionView = false
        }
    }
    
    // MARK: - Alert Content
    
    private func errorAlert() -> Alert {
        Alert(
            title: Text("Error", comment: "Error title message") + Text(viewModel.errorMessage ?? ""),
            message: Text("Select a category", comment: "OK alert message")
        )
    }
    
    private func growAlert() -> Alert {
        Alert(
            title: Text("Help us grow?"),
            message: Text("Leave us a 5 star review 🌟"),
            primaryButton: .default(Text("Yes")) {
                requestReview()
            },
            secondaryButton: .cancel()
        )
    }
    
    @ViewBuilder
    private func shareAlert() -> some View {
        Button("Yes, I'll share with friends!") {
            shareSpeakLife()
        }
        Button("No thanks") {
        }
    }
    
    // MARK: - Event Handlers
    
    private func handleOnAppear() {
        checkAndShowBanner()
        reviewCounter += 1
        shareCounter += 1
        premiumCount += 1
        shareApp()
        timerViewModel.debugFixStreak()
    }
    
    private func handleOnDisappear() {
        // Don't save timer here - let it keep running
    }
    
    // MARK: - Sheet Actions
    
    private func createYourOwnView() {
        activeSheet = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.activeSheet = .createYourOwn
        }
        Analytics.logEvent(Event.tryPremiumTapped, parameters: nil)
    }
    private func premiumView()  {
        activeSheet = .premium
        Analytics.logEvent(Event.tryPremiumTapped, parameters: nil)
    }
    
    private func loveLetter()  {
        activeSheet = .loveLetter
        Analytics.logEvent(Event.tryPremiumTapped, parameters: nil)
    }
    
    private func dailyChecklist() {
        activeSheet = .dailyChecklist
        Analytics.logEvent("daily_checklist_opened", parameters: nil)
    }
    
    private func showTimerSheet() {
        activeSheet = .timerStreak
        Analytics.logEvent("timer_streak_opened", parameters: nil)
    }
    
    private func shareApp() {
        let currentDate = Date()
        if shareCounter > 3 && shared < 2 && currentDate.timeIntervalSince(appState.lastSharedAttemptDate) >= 12 * 60 * 60 {
            share = true
            appState.lastSharedAttemptDate = currentDate
        }
    }
    
    private func checkAndShowBanner() {
        @AppStorage("hasShownSpeakAloudBanner") var hasShownBanner = false
        
        if !hasShownBanner {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation(.easeInOut(duration: 0.5)) {
                    showSpeakAloudBanner = true
                }
            }
        }
    }
    
    private func shareSpeakLife()  {
        DispatchQueue.main.async {
            if let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive })
                as? UIWindowScene {
                let url = URL(string: "\(APP.Product.urlID)")!
                
                let activityVC = UIActivityViewController(activityItems: ["Check out Speak Life - Bible Meditation app that'll transform your life!", url], applicationActivities: nil)
                let window = scene.windows.first
                window?.rootViewController?.present(activityVC, animated: true)
                shared += 1
            }
        }
    }
    
    func requestReview() {
        showReview()
    }
    
    private func showReview() {
     
        let currentDate = Date()
        if reviewTry <= 3 && appState.lastReviewRequestSetDate == nil {
            DispatchQueue.main.async {
                if let scene = UIApplication.shared.connectedScenes
                    .first(where: { $0.activationState == .foregroundActive })
                    as? UIWindowScene {
                    SKStoreReviewController.requestReview(in: scene)
                   
                    reviewTry += 1
                    appState.lastReviewRequestSetDate = Date()
                    Analytics.logEvent(Event.leaveReviewShown, parameters: nil)
                    
                }
            }
        } else if reviewTry <= 1, let lastReviewSetDate = appState.lastReviewRequestSetDate, currentDate.timeIntervalSince(lastReviewSetDate) >= 60 * 1 {
            DispatchQueue.main.async {
                if let scene = UIApplication.shared.connectedScenes
                    .first(where: { $0.activationState == .foregroundActive })
                    as? UIWindowScene {
                    SKStoreReviewController.requestReview(in: scene)
                    reviewTry += 1
                    appState.lastReviewRequestSetDate = Date()
                    Analytics.logEvent(Event.leaveReviewShown, parameters: nil)
                }
            }
        }
            else if let lastReviewSetDate = appState.lastReviewRequestSetDate,
                  currentDate.timeIntervalSince(lastReviewSetDate) >= 60 * 60 * 24 * 5,
                  reviewTry < 3 {
            DispatchQueue.main.async {
                if let scene = UIApplication.shared.connectedScenes
                    .first(where: { $0.activationState == .foregroundActive })
                    as? UIWindowScene {
                    SKStoreReviewController.requestReview(in: scene)
                    reviewTry += 1
                    appState.lastReviewRequestSetDate = Date()
                    Analytics.logEvent(Event.leaveReviewShown, parameters: nil)
                }
            }
        }
    }
}
