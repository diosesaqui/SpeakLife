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
    
    @AppStorage("share.counter") private var shareCounter = 0
    @AppStorage("shared.count") private var shared = 0
    // Ask the user to share the app at most once, ever.
    @AppStorage("hasAskedToShareApp") private var hasAskedToShareApp = false
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
    /// Drives the pulse animation on the checklist icon when the user has
    /// pending tasks for the day. Toggled by the autoreverse animation below.
    @State private var checklistPulse = false
    @StateObject private var speechSynthesizer = SpeechSynthesizer()
    /// Set when a personal declaration reminder is tapped, so the list opens
    /// straight onto that declaration's card.
    @State private var deepLinkedDeclarationId: UUID? = nil
    
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
    
    // Personal Declaration compact button shown in top row — always visible.
    // Opens the full list of what the user is believing for (a premium user can
    // be carrying several); the list owns creating, speaking, and closing them out.
    private var personalDeclarationButton: some View {
        let hasActive = appState.hasPersonalDeclaration

        return Button {
            activeSheet = .personalDeclaration
        } label: {
            Image(systemName: hasActive ? "hands.sparkles.fill" : "hands.sparkles")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(hasActive ? Color.yellow : Color.white.opacity(0.4))
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(Color.black.opacity(hasActive ? 0.7 : 0.5))
                        .overlay(
                            Circle()
                                .stroke(
                                    hasActive ? Color.yellow.opacity(0.4) : Color.white.opacity(0.15),
                                    lineWidth: 1
                                )
                        )
                )
        }
        .buttonStyle(PlainButtonStyle())
    }

    /// Opens the declaration a tapped reminder was for.
    ///
    /// Called from `.onChange` (feed already on screen) AND from `onAppear`
    /// (feed wasn't mounted when the tap landed). Both are required.
    ///
    /// `scrollToPersonalDeclaration` is `@AppStorage`, so it survives launches,
    /// but it used to be consumed by `.onChange` alone — which only fires on a
    /// transition. Any tap arriving while this view was not mounted (user on the
    /// Today, Audio, or Profile tab, or a cold launch) left the flag stuck at
    /// true with nobody to clear it. Every later tap then set true over true,
    /// which is not a change, so the deep link silently stopped working and
    /// never recovered.
    ///
    /// It showed up for people carrying several declarations first: three
    /// reminders a day instead of one means three times the chance of tapping
    /// while some other tab is up, and one is enough to latch it forever.
    private func openPendingPersonalDeclaration() {
        guard appState.scrollToPersonalDeclaration else { return }

        // The flags are NOT cleared here. They are cleared in the sheet's
        // onAppear, once the list is actually on screen. Clearing up front looks
        // safer but makes every dropped presentation permanent, and there are
        // several ways to drop one. Leaving them set is safe now that `onAppear`
        // and `onChange` both retry: a miss self-heals on the next appearance
        // instead of latching, which was the original bug.
        //
        // Empty id means the reminder predates per-declaration deep links; the
        // list then opens without preselecting a card.
        deepLinkedDeclarationId = UUID(uuidString: appState.pendingPersonalDeclarationId)

        // Everything currently covering this view has to come down first, not
        // just `activeSheet`. The Burst runs in a fullScreenCover and the mail
        // composer in its own sheet, and with either up SwiftUI silently drops a
        // sheet assignment. `.personalDeclaration` counts as "already up" too:
        // re-assigning it is a no-op, and `MyDeclarationsView` has latched
        // `didHandleDeepLink`, so a reminder for a *different* declaration would
        // navigate nowhere. Tearing it down forces a fresh list on the new id.
        let somethingIsPresented = activeSheet != nil || showDailyBurst || isShowingMailView
        guard somethingIsPresented else {
            activeSheet = .personalDeclaration
            return
        }

        activeSheet = nil
        showDailyBurst = false
        isShowingMailView = false
        // asyncAfter, not async: a plain async lands mid-dismissal animation and
        // the presentation is dropped. 0.4s clears the ~0.35s sheet dismissal.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            activeSheet = .personalDeclaration
        }
    }

    @ViewBuilder
    private func topButtonsRow(_ geometry: GeometryProxy) -> some View {
        HStack {
            //loveLetterButton
            devotionalButton
            //dailyBurstButton
            personalDeclarationButton
            
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
                AnalyticsService.shared.track("love_letter_opened")
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
        // Hidden when the checklist owns the home tab (the icon would be
        // redundant). Only shows in the reverted feed-as-home layout.
        if !showSpeakAloudBanner && !subscriptionStore.checklistHomeEnabled {
            let isDone = streakViewModel.todayChecklist.isStreakEarned
            Button(action: {
                activeSheet = .dailyChecklist
                AnalyticsService.shared.track("checkList_opened")
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
                AnalyticsService.shared.track("daily_burst_opened", parameters: [
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
            Juice.play(.tapLight)
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
            Juice.play(.tapLight)
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
                .environmentObject(subscriptionStore)
        }
        // Presented from the "Today" checklist tab: it switches to this feed tab
        // and posts this so the burst opens here, where its cover is fully wired.
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ShowDailyDeclarationBurst"))) { _ in
            showDailyBurst = true
        }
        // On `body`, not on the personal-declaration button. That button lives
        // inside `overlayContent`, which is not rendered while
        // `showScreenshotLabel` is set, so the observer could be absent from the
        // hierarchy exactly when a tap needed it.
        .onChange(of: appState.scrollToPersonalDeclaration) { _ in
            openPendingPersonalDeclaration()
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
            // Owns the whole loop: the list, each declaration's card, adding a
            // new one, and the breakthrough celebration.
            MyDeclarationsView(initialDeclarationId: deepLinkedDeclarationId)
                .environmentObject(appState)
                .environmentObject(subscriptionStore)
                // The deep link is spent here, not at the point it was routed:
                // this is the first moment we know the list actually presented.
                // Anything that drops the presentation leaves the flags set, and
                // the next onAppear retries instead of losing the reminder.
                .onAppear {
                    appState.scrollToPersonalDeclaration = false
                    appState.pendingPersonalDeclarationId = ""
                }
                .onDisappear { deepLinkedDeclarationId = nil }
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
        shareCounter += 1
        premiumCount += 1
        shareApp()
        timerViewModel.debugFixStreak()
        // Picks up a reminder tapped while this view was not mounted, including
        // one left over from a previous launch. Without it the flag can only be
        // cleared by a transition that will never come.
        openPendingPersonalDeclaration()
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
        AnalyticsService.shared.track(Event.tryPremiumTapped)
    }
    private func premiumView()  {
        activeSheet = .premium
        AnalyticsService.shared.track(Event.tryPremiumTapped)
    }
    
    private func loveLetter()  {
        activeSheet = .loveLetter
        AnalyticsService.shared.track(Event.tryPremiumTapped)
    }
    
    private func dailyChecklist() {
        activeSheet = .dailyChecklist
        AnalyticsService.shared.track("daily_checklist_opened")
    }
    
    private func showTimerSheet() {
        activeSheet = .timerStreak
        AnalyticsService.shared.track("timer_streak_opened")
    }
    
    private func shareApp() {
        let currentDate = Date()
        // Ask only once, ever — don't re-prompt users who declined.
        if !hasAskedToShareApp && shareCounter > 3 {
            share = true
            hasAskedToShareApp = true
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
    
    private func showReview() {
        appState.requestReviewIfEligible(trigger: .declarationView)
    }
}
