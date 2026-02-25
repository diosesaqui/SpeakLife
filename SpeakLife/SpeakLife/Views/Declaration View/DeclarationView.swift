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

struct DeclarationView: View {
    
    // MARK: - Properties
    
    @EnvironmentObject var viewModel: DeclarationViewModel
    @EnvironmentObject var themeViewModel: ThemeViewModel
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @EnvironmentObject var devotionalViewModel: DevotionalViewModel
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var streakViewModel: EnhancedStreakViewModel
    @Environment(\.presentationMode) var presentationMode
    
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
       // case mail
        
        var id: Int { hashValue }
    }
    @State private var showSpeakAloudBanner = false
    
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
    
    @ViewBuilder
    private func topButtonsRow(_ geometry: GeometryProxy) -> some View {
        HStack {
            loveLetterButton
            dailyBurstButton
            
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
            Button(action: {
                activeSheet = .dailyChecklist
                Analytics.logEvent("checkList_opened", parameters: nil)
            }) {
                Image(systemName: "checklist")
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
        .sheet(item: $activeSheet, content: sheetContent)
        .onChange(of: presentDevotionalSubscriptionView, perform: handleDevotionalPresentation)
        .alert(isPresented: $viewModel.showErrorMessage, content: errorAlert)
        .alert(isPresented: $viewModel.helpUsGrowAlert, content: growAlert)
        .alert("Know anyone that can benefit from SpeakLife?", isPresented: $share, actions: shareAlert)
        .sheet(isPresented: $isShowingMailView) {
            MailView(isShowing: $isShowingMailView, result: self.$result, origin: .review, isSubscribed: subscriptionStore.isPremium)
        }
        .fullScreenCover(isPresented: $showDailyBurst) {
            DailyDeclarationBurstView()
                .environmentObject(viewModel)
                .environmentObject(themeViewModel)
                .environmentObject(timerViewModel)
                .environmentObject(streakViewModel)
        }
        .onAppear(perform: handleOnAppear)
        .onDisappear(perform: handleOnDisappear)
        .setupNotificationObservers(timerViewModel: timerViewModel)
    }
    
    // MARK: - Sheet Management
    
    @ViewBuilder
    private func sheetContent(_ sheet: ActiveSheet) -> some View {
        switch sheet {
        case .createYourOwn:
            CreateYourOwnView()
        case .premium:
            PremiumView()
                .frame(height: UIScreen.main.bounds.height * 0.95)
        case .devotionalSubscription:
            DevotionalView(viewModel: devotionalViewModel)
        case .loveLetter:
            AbbasLoveView()
        case .dailyChecklist:
            ModernDailyChecklistView(viewModel: streakViewModel)
                .environmentObject(streakViewModel)
        case .timerStreak:
            TimerStreakDetailView(timerViewModel: timerViewModel)
//            StreakSheet(isShown: $isPresentingBottomSheet, streakViewModel: streakViewModel)
//                .environmentObject(streakViewModel)
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
        timerViewModel.loadRemainingTime()
        
        // Debug streak info
        
        // Try to fix broken streak state
        timerViewModel.debugFixStreak()
    }
    
    private func handleOnDisappear() {
        // Don't save timer here - let it keep running
    }
    
    // MARK: - Sheet Actions
    
    private func createYourOwnView() {
        
        // Timer continues running - don't save
        
        // Clear any existing sheet first
        activeSheet = nil
        
        // Use consolidated sheet approach with delay to ensure clean state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.activeSheet = .createYourOwn
        }
        
        Analytics.logEvent(Event.tryPremiumTapped, parameters: nil)
    }
    private func premiumView()  {
        // Timer continues running - don't save
        activeSheet = .premium
        Analytics.logEvent(Event.tryPremiumTapped, parameters: nil)
    }
    
    private func loveLetter()  {
        // Timer continues running - don't save
        activeSheet = .loveLetter
        Analytics.logEvent(Event.tryPremiumTapped, parameters: nil)
    }
    
    private func dailyChecklist() {
        // Timer continues running - don't save
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
        // Check if this is a first install by checking if banner has been shown
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
