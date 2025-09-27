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
    @EnvironmentObject var timerViewModel: TimerViewModel
    @State var presentDevotionalSubscriptionView = false
    
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
    
    var body: some View {
        GeometryReader { geometry in
           
            ZStack {
                declarationContent(geometry)
                    if !appState.showScreenshotLabel {
                       
                        VStack() {
                           
                            HStack {
                                Spacer()
                                // Enhanced Streak System with Daily Checklist
                                EnhancedStreakView()
                                    .opacity(appState.showScreenshotLabel ? 0 : 1)
                                    .allowsHitTesting(!appState.showScreenshotLabel)
                                if !subscriptionStore.isPremium {
                                    Spacer()
                                        .frame(width: 8)
                                    
                                    CapsuleImageButton(title: "crown.fill") {
                                        premiumView()
                                        Selection.shared.selectionFeedback()
                                    }
                                    .opacity(appState.showScreenshotLabel ? 0 : 1)
                                    .foregroundStyle(Constants.gold)
                                   
                                    .sheet(isPresented: $isPresentingPremiumView) {
                                            self.isPresentingPremiumView = false
                                            Analytics.logEvent(Event.tryPremiumAbandoned, parameters: nil)
                                            timerViewModel.loadRemainingTime()
                                        } content: {
                                            PremiumView()
                                                .frame(height: UIScreen.main.bounds.height * 0.95)
                    
                                                .onDisappear {
                                                    if !subscriptionStore.isPremium, !subscriptionStore.isInDevotionalPremium {
                                                        if subscriptionStore.showDevotionalSubscription {
                                                            presentDevotionalSubscriptionView = true
                                                        }
                                                    }
                                                }
                                        }
                                        .sheet(isPresented: $presentDevotionalSubscriptionView) {
                                            DevotionalSubscriptionView() {
                                                presentDevotionalSubscriptionView = false
                                            }
                                           }
                                    
                                    
                                }
                                
                            } .padding([.leading,.trailing])
                            
                            Spacer()
                           if appState.showIntentBar {
                                 IntentsBarView(viewModel: viewModel, themeViewModel: themeViewModel)
                                   .opacity(appState.showScreenshotLabel ? 0 : 1)
                               .frame(height: geometry.size.height * 0.10)

                        }
                    }
                    }
                }
        }
            
            .background(
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
            )
            
            
            .alert(isPresented: $viewModel.showErrorMessage) {
                Alert(
                    title: Text("Error", comment: "Error title message") + Text(viewModel.errorMessage ?? ""),
                    message: Text("Select a category", comment: "OK alert message")
                )
            }
        
            .alert(isPresented: $viewModel.helpUsGrowAlert) {
                Alert(
                    title: Text("Help us grow?"),
                    message: Text("Leave us a 5 star review 🌟"),
                    primaryButton: .default(Text("Yes")) {
                        requestReview()
                    },
                    secondaryButton: .cancel()
                )
            }
        
            
            .onAppear {
                reviewCounter += 1
                shareCounter += 1
                premiumCount += 1
                shareApp() 
                timerViewModel.loadRemainingTime()
            }
            
            .alert("Know anyone that can benefit from SpeakLife?", isPresented: $share) {
                Button("Yes, I'll share with friends!") {
                    shareSpeakLife()
                }
                Button("No thanks") {
                }
            }
            .onDisappear {
                timerViewModel.saveRemainingTime()
            }
            
            .sheet(isPresented: $isShowingMailView) {
                MailView(isShowing: $isShowingMailView, result: self.$result, origin: .review)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
                timerViewModel.saveRemainingTime()
            }
            
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                timerViewModel.loadRemainingTime()
            }
            
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                timerViewModel.saveRemainingTime()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                timerViewModel.saveRemainingTime()
            }
        
    }
    private func premiumView()  {
        timerViewModel.saveRemainingTime()
        self.isPresentingPremiumView = true
        Analytics.logEvent(Event.tryPremiumTapped, parameters: nil)
    }
    
    private func shareApp() {
        let currentDate = Date()
        if shareCounter > 3 && shared < 2 && currentDate.timeIntervalSince(appState.lastSharedAttemptDate) >= 12 * 60 * 60 {
            share = true
            appState.lastSharedAttemptDate = currentDate
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
