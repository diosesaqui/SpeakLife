//
//  HomeView.swift
//  SpeakLife
//
//  Created by Riccardo Washington on 12/17/22.
//

import SwiftUI
import FacebookCore
let resources: [MusicResources] = [.sethpiano, .washed, .rainstorm, .everpresent]

struct MusicResources {
    let name: String
    let artist: String
    let type: String
   
    static let sethpiano = MusicResources(name: "sethpiano", artist: "", type: "mp3")
    static let washed = MusicResources(name: "washed", artist: "Brock Hewitt", type: "mp3")
    static let rainstorm = MusicResources(name: "rainstorm", artist: "Brock Hewitt", type: "mp3")
    static let everpresent = MusicResources(name: "everpresent", artist: "Brock Hewitt", type: "mp3")
}

class TabViewModel: ObservableObject {
    @Published var selectedTab: Int = 0

    func goToAudio() {
        selectedTab = 2
    }

    func resetToHome() {
        selectedTab = 0
    }
}

struct HomeView: View {
    
    @EnvironmentObject var declarationStore: DeclarationViewModel
    @EnvironmentObject var themeStore: ThemeViewModel
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var devotionalViewModel: DevotionalViewModel
    @EnvironmentObject var timerViewModel: TimerViewModel
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @EnvironmentObject var viewModel: FacebookTrackingViewModel
    @EnvironmentObject var audioDeclarationViewModel: AudioDeclarationViewModel
    @EnvironmentObject var tabViewModel: TabViewModel
    @Binding var isShowingLanding: Bool
   
   
    @State var showGiftView = false
    @State private var isPresented = false
    @State var showSubscription = false
    
    private let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"

    let data = [true, false]
    var body: some View {
       
            Group {
                if isShowingLanding {
                    LandingView()
                } else if appState.isOnboarded {
                        homeView
                            .onAppear() {
                                showSubscription = subscriptionStore.showSubscription && !subscriptionStore.isPremium && !appState.firstOpen
                                audioDeclarationViewModel.fetchAudio(version: subscriptionStore.audioRemoteVersion)
                                declarationStore.setRemoteDeclarationVersion(version: subscriptionStore.remoteVersion)
                                Task {
                                    if devotionalViewModel.shouldFetchNewDevotional() {
                                            await devotionalViewModel.fetchDevotional(remoteVersion: subscriptionStore.currentDevotionalVersion)
                                            devotionalViewModel.lastFetchDate = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
                                        }
                                }
                                if appState.firstOpen {
                                    appState.firstOpen = false
                                }
                            }
                            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                               
                                Task {
                                    // Always fetch remote config when coming from background
                                    await subscriptionStore.fetchRemoteConfig()
                                    
                                    // Update audio and declaration versions with new remote values
                                    audioDeclarationViewModel.fetchAudio(version: subscriptionStore.audioRemoteVersion)
                                    declarationStore.setRemoteDeclarationVersion(version: subscriptionStore.remoteVersion)
                                    
                                    // Fetch devotional if needed
                                    if devotionalViewModel.shouldFetchNewDevotional() {
                                        await devotionalViewModel.fetchDevotional(remoteVersion: subscriptionStore.currentDevotionalVersion)
                                        devotionalViewModel.lastFetchDate = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
                                    }
                                }
                            }
                            .sheet(isPresented: $appState.needEmail, content: {
                                //GeometryReader { proxy in
                                    EmailCaptureView()
                                //        .frame(height:  UIScreen.main.bounds.height * 0.96)
                             //   }
                            
                            })
                            .sheet(isPresented: $showSubscription, content: {
                                GeometryReader { proxy in
                                    OptimizedSubscriptionView() { //size: proxy.size) {
                                        showSubscription = false
                                    }
                                    .frame(height:  UIScreen.main.bounds.height * 0.9)
                                }
                            
                            })
                  
                } else {
                    OnboardingView()
                        .onAppear {
                            viewModel.requestPermission()
                        }
                }
            }
        
    }
    
    @ViewBuilder
    var homeView: some View {
        ZStack {
            TabView(selection: $tabViewModel.selectedTab) {
                declarationView
                devotionalView
                audioView
              //  BootcampMainView()
                createYourOwnView
                profileView
                    
                }
                .hideTabBar(if: appState.showScreenshotLabel)
                .sheet(isPresented: $isPresented) {
                    WhatsNewBottomSheet(isPresented: $isPresented, version: currentVersion)
                        .presentationDetents([.medium])
                        .presentationDragIndicator(.visible)
                }
                .accentColor(Constants.DAMidBlue)
                .onAppear {
                    checkForNewVersion()
                    UIScrollView.appearance().isScrollEnabled = true
                }
                .background(Color.clear)
                .environment(\.colorScheme, .dark)
                .ignoresSafeArea()
            
        }
    }
    
    var declarationView: some View {
        DeclarationView()
            .id(appState.rootViewId)
            .tag(0)
            .tabItem {
                Image(systemName: "house.fill")
                    .renderingMode(.original)
                
            }
    }
    
    var testimonyView: some View {
        TestimonyFeedView()
            .tabItem {
                Image(systemName: "quote.bubble")
                    .renderingMode(.original)
            }
    }
    
    var audioView: some View {
        AudioDeclarationView()
            .tag(2)
            .tabItem {
                if #available(iOS 17, *) {
                    Image(systemName: "waveform")
                        .renderingMode(.original)
                } else {
                    Image(systemName: "waveform")
                        .renderingMode(.original)
                }
            }
            .edgesIgnoringSafeArea(.all)
    }
    
    var devotionalView: some View {
        DevotionalView(viewModel:devotionalViewModel)
            .tag(1)
            .tabItem {
                if #available(iOS 17, *) {
                    Image(systemName: "book.pages.fill")
                        .renderingMode(.original)
                } else {
                    Image(systemName: "book.fill")
                        .renderingMode(.original)
                }
            }
    }
    
    var createYourOwnView: some View {
        CreateYourOwnView()
            .tag(3)
            .tabItem {
                Image(systemName: "plus.bubble.fill")
                    .renderingMode(.original)
            }
    }
    
    var profileView: some View {
        ProfileView()
            .tag(4)
            .tabItem {
                Image(systemName: "line.3.horizontal")
                    .renderingMode(.original)
            }
    }
    
    func presentGiftView() {
        if appState.showGiftViewCount <= 5 {
            showGiftView.toggle()
            appState.showGiftViewCount += 1
        }
    }
    
    private func checkForNewVersion() {
        let lastVersion = UserDefaults.standard.string(forKey: "lastVersion") ?? "0.0.0"
        if lastVersion != currentVersion {
            isPresented = true
            UserDefaults.standard.set(currentVersion, forKey: "lastVersion")
       }
        if currentVersion == "3.0.42" {
            declarationStore.cleanUpSelectedCategories { selectedCategories in
                let categoryString = selectedCategories.map { $0.name }.joined(separator: ",")
                appState.selectedNotificationCategories = categoryString
                declarationStore.save(selectedCategories)
            }
        }
    }
}


import AppTrackingTransparency
import AdSupport

class TrackingManager {
    static let shared = TrackingManager()

    func requestTrackingPermission(completion: @escaping (ATTrackingManager.AuthorizationStatus) -> Void) {
        ATTrackingManager.requestTrackingAuthorization { status in
            DispatchQueue.main.async {
                completion(status)
            }
        }
    }
}

class FacebookTrackingViewModel: ObservableObject {
    
    func requestPermission() {
        
        if ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
            TrackingManager.shared.requestTrackingPermission { status in
                switch status {
                case .notDetermined:
                    Settings.shared.isAdvertiserIDCollectionEnabled = false
                case .restricted:
                    Settings.shared.isAdvertiserIDCollectionEnabled = false
                case .denied:
                    Settings.shared.isAdvertiserIDCollectionEnabled = false
                case .authorized:
                    Settings.shared.isAdvertiserIDCollectionEnabled = true
                @unknown default: break
                }
            }
        }
    }
}
