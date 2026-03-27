//
//  ProfileView.swift
//  Dios Es Aqui
//
//  Created by Riccardo Washington on 1/16/22.
//

import SwiftUI
import MessageUI
import FirebaseAnalytics
import RevenueCat

struct LazyView<Content: View>: View {
    let build: () -> Content
    
    init(_ build: @autoclosure @escaping () -> Content) {
        self.build = build
    }
    
    var body: Content {
        build()
    }
}

struct ProfileView: View {
    
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var declarationStore: DeclarationViewModel
    //@EnvironmentObject var streakViewModel: EnhancedStreakViewModel
    @EnvironmentObject var streakViewModel: StreakViewModel
    @EnvironmentObject var enhancedStreakViewModel: EnhancedStreakViewModel
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var devotionalViewModel: DevotionalViewModel
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @AppStorage("useAnimatedText") private var useAnimatedText = true
    
    @State var result: Result<MFMailComposeResult, Error>? = nil
    private let appVersion = "App version: \(APP.Version.stringNumber)"
    
    // MARK: - Properties
    
    @State var isPresentingManageSubscriptionView = false
    @State var isPresentingContentView = false
    @State var isPresentingPrayerRequestView = false
    @State var isPresentingBottomSheet = false
    @State private var showStreakStats = false
    @State private var showShareSheet = false
    @State private var showSpiritualGrowth = false
    @State private var showSupportIDCopied = false
    @State private var showEmailCaptureSheet = false
    let url = URL(string:APP.Product.urlID)
    
    
    @ViewBuilder
    private func navigationStack<Content: View>(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            NavigationStack {
                content
            }
        } else {
            NavigationView {
                content
            }
            .navigationViewStyle(.stack)
        }
    }
    
    private var profileView: some View {
        navigationStack(content:
                            ZStack {
            Image(subscriptionStore.onboardingBGImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: UIScreen.main.bounds.size.width, height: UIScreen.main.bounds.size.height)
                .edgesIgnoringSafeArea([.all])
                .overlay(
                    Rectangle()
                        .fill(Color.black.opacity(0.2))
                        .edgesIgnoringSafeArea(.all)
                )
            VStack {
                VStack {
            Spacer().frame(height: 8)
                    
            AppLogo(height: 80)


            Spacer().frame(height: 8)
        }
                List {
                    Section(header: Text("Premium".uppercased()).font(.caption)) {
                        subscriptionRow
                        //bookLink
                    }
                    
                    
                    Section(header: Text("Yours").font(.caption)) {
                        AbbasLoveRow
                        streakStatsRow
                      //  dailyBurstStatsRow
                            quizRow
                           prayerRow
                       // }
                        
                        remindersRow
                     //   widgetPreferencesRow
                     //   emailsRow
                       // favoritesRow
                        musicRow
                        soundsRow
                        animationSettings
                    }
                    
                    
                    Section(header: Text("SUPPORT").font(.caption)) {
    
                        shareRow
                        reviewRow
                        feedbackRow
                        emailRow
                        supportIDRow
                        
                        
                    }
                    
                    .sheet(isPresented: $showShareSheet, content: {
                        ShareSheet(activityItems: ["Check out SpeakLife - Bible Affirmations app that'll transform your life!", url as Any])
                    })
                    .sheet(isPresented: $showEmailCaptureSheet) {
                        EmailCaptureView(source: "settings")
                            .environmentObject(appState)
                    }
                    
                    Section(header: Text("Other".uppercased()).font(.caption)) {
                        privacyPolicyRow
                        termsConditionsRow
                    }
                    
                    Section(footer: VStack {
                        Text(appVersion).font(.footnote)
                        Spacer().frame(height: 8)
                    }) {
                        
                    }
                   
                }
                .scrollContentBackground(.hidden)
                
            }
            .background(Color.clear)
            .padding([.top, .bottom], 60)
        }
                        
            .onChange(of: declarationStore.backgroundMusicEnabled) { newValue in
                if newValue {
                    AudioPlayerService.shared.playSound(files: resources)
                } else {
                    AudioPlayerService.shared.pauseMusic()
                }
            }
            .foregroundColor(.white)
        )
        .sheet(isPresented: $showSpiritualGrowth) {
            SpiritualGrowthView()
        }
        .alert(isPresented: $declarationStore.errorAlert) {
            Alert(
                title: Text("Failed to register notifications", comment: "notifications not enough"),
                message: Text("not enough in selected category", comment: "go to settings"),
                dismissButton: .default(Text("Choose more", comment: "settings alert"), action: {})
            )
        }
    }
    
    var body: some View {
        profileView
//            .onAppear {
//                Analytics.logEvent(Event.profileTapped, parameters: nil)
//            }
            .environment(\.colorScheme, .dark)
    }
    
    @MainActor
    private var subscriptionRow: some View {
        HStack {
            Image(systemName: "crown.fill")
                .foregroundColor(Constants.DAMidBlue)
            NavigationLink(destination: LazyView(PremiumView())) {
                HStack {
                    Text("Manage Subscription", comment:  "subs row")
                    Spacer()
//                        Image(systemName: "chevron.right")
//                            .resizable()
//                            .aspectRatio(contentMode: .fit)
//                            .frame(width: 8)
//                            .foregroundColor(Constants.DAMidBlue)
                }
            }
        }
    }
    
    @MainActor
    private var emailsRow: some View {
        HStack {
            Image(systemName: "crown.fill")
                .foregroundColor(Constants.DAMidBlue)
            NavigationLink(destination: LazyView(EmailCaptureView())) {
                HStack {
                    Text("Email", comment:  "subs row")
                    Spacer()
//                        Image(systemName: "chevron.right")
//                            .resizable()
//                            .aspectRatio(contentMode: .fit)
//                            .frame(width: 8)
//                            .foregroundColor(Constants.DAMidBlue)
                }
            }
        }
    }


    
    @MainActor
    private var remindersRow: some View {
        HStack {
            Image(systemName: "bell.fill")
                .foregroundColor(Constants.DAMidBlue)
            NavigationLink(destination: LazyView(ReminderView(reminderViewModel: ReminderViewModel()))) {
                HStack {
                    Text("Reminders", comment: "Reminder row title")
                    Spacer()
//                        Image(systemName: "chevron.right")
//                            .resizable()
//                            .aspectRatio(contentMode: .fit)
//                            .frame(width: 8)
//                            .foregroundColor(Constants.DAMidBlue)
                }
            }
            .simultaneousGesture(TapGesture().onEnded {
                Event.trackUserAction(
                    "reminders_opened",
                    category: "profile",
                    metadata: ["source": "profile_menu"]
                )
            })
        }
        
    }
    
    // Temporarily commented out - will be activated in future update
    /*
    @MainActor
    private var widgetPreferencesRow: some View {
        HStack {
            Image(systemName: "widget.small.fill")
                .foregroundColor(Constants.DAMidBlue)
            NavigationLink("Widget Preferences", destination: LazyView(WidgetPreferencesView()))
                .opacity(0)
                .background(
                    HStack {
                        Text("Widget Preferences", comment: "Widget preferences row title")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 8)
                            .foregroundColor(Constants.DAMidBlue)
                    })
        }
    }
    */
    
    @MainActor
    private var quizRow: some View {
        HStack {
            Image(systemName: "lightbulb.fill")
                .foregroundColor(Constants.DAMidBlue)
            NavigationLink(destination: LazyView(QuizHomeView())) {
                HStack {
                    Text("Quizzes", comment: "Reminder row title")
                    Spacer()
//                        Image(systemName: "chevron.right")
//                            .resizable()
//                            .aspectRatio(contentMode: .fit)
//                            .frame(width: 8)
//                            .foregroundColor(Constants.DAMidBlue)
                }
            }
            .simultaneousGesture(TapGesture().onEnded {
                Event.trackUserAction(
                    "quiz_opened",
                    category: "profile",
                    metadata: ["source": "profile_menu"]
                )
            })
        }
        
    }
    
    var musicRow: some View {
        HStack {
            Image(systemName: "music.note")
                .foregroundColor(Constants.DAMidBlue)
            Text("Currently playing \(AudioPlayerService.shared.currentTitle ?? "") by \(AudioPlayerService.shared.currentArtist ?? "")")
        }
    }
    
    private var widgetsRow: some View {
        // TO DO: - add back after add widget functionality
        EmptyView()
    }
    
    @MainActor
    private var prayerRow: some View {
        HStack {
            Image(systemName: "hands.sparkles.fill")
                .foregroundColor(Constants.DAMidBlue)
            NavigationLink(destination: LazyView(WarriorView())) {
                HStack {
                    Text("Prayers", comment:  "Prayers row title")
                    Spacer()
//                        Image(systemName: "chevron.right")
//                            .resizable()
//                            .aspectRatio(contentMode: .fit)
//                            .frame(width: 8)
//                            .foregroundColor(Constants.DAMidBlue)
                }
            }
            .simultaneousGesture(TapGesture().onEnded {
                Event.trackUserAction(
                    "prayers_opened",
                    category: "profile",
                    metadata: ["source": "profile_menu"]
                )
            })
        }
    }
    
    @MainActor
    private var tipsRow: some View {
        HStack {
            Image(systemName: "exclamationmark.shield.fill")
                .foregroundColor(Constants.DAMidBlue)
            NavigationLink(destination: LazyView(TipsView(tips: tips))) {
                HStack {
                    Text("Tips on how to use SpeakLife", comment:  "Tips row title")
                    Spacer()
//                        Image(systemName: "chevron.right")
//                            .resizable()
//                            .aspectRatio(contentMode: .fit)
//                            .frame(width: 8)
//                            .foregroundColor(Constants.DAMidBlue)
                }
            }
        }
    }

    // MARK: - Streak Stats + Badges Row

    @MainActor
    private var streakStatsRow: some View {
        let stats = enhancedStreakViewModel.streakStats
        let earnedBadges = enhancedStreakViewModel.badgeManager.allBadges.filter { $0.isUnlocked }

        return HStack(spacing: 12) {
            Image(systemName: "flame.fill")
                .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("Streak & Badges")
                    .font(.body)

                HStack(spacing: 10) {
                    Label("\(stats.currentStreak) day streak", systemImage: "bolt.fill")
                        .font(.caption)
                        .foregroundColor(.orange)

                    if earnedBadges.count > 0 {
                        Label("\(earnedBadges.count) badge\(earnedBadges.count == 1 ? "" : "s")", systemImage: "rosette")
                            .font(.caption)
                            .foregroundColor(.purple)
                    }
                }
            }

            Spacer()

            // Longest streak preview
            if stats.longestStreak > 0 {
                VStack(spacing: 1) {
                    Text("\(stats.longestStreak)")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("best")
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            showStreakStats = true
            Analytics.logEvent("Profile_StreakStats_Tapped", parameters: [
                "current_streak": stats.currentStreak,
                "badges_earned": earnedBadges.count
            ])
        }
        .sheet(isPresented: $showStreakStats) {
            StreakStatsProfileSheet(viewModel: enhancedStreakViewModel)
        }
    }

    private var streakRow: some View {
        ZStack {
            Button("") {
                isPresentingBottomSheet = true
            }
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundColor(Constants.DAMidBlue)
                
                Text("Streak")
                
            }
        }.sheet(isPresented: $isPresentingBottomSheet) {
                StreakSheet(isShown: $isPresentingBottomSheet, streakViewModel: streakViewModel)
                .presentationDetents([.medium, .fraction(0.7)])
                .preferredColorScheme(.light)
        }
    }
    
    @MainActor
    private var dailyBurstStatsRow: some View {
        HStack {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .foregroundColor(Constants.DAMidBlue)
            
            HStack {
                Text("Daily Burst Stats")
                
                Spacer()
                
                // Show current streak as a preview
                if BurstCompletionTracker.shared.currentStreak > 0 {
                    Text("\(BurstCompletionTracker.shared.currentStreak) days")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            // Add slight delay to ensure proper state transition
            DispatchQueue.main.async {
                showSpiritualGrowth = true
                Analytics.logEvent("Profile_DailyBurstStats_Tapped", parameters: nil)
            }
        }
    }
    
    @MainActor
    private var AbbasLoveRow: some View {
        HStack {
            Image(systemName: "bolt.heart.fill")
                .foregroundColor(Constants.DAMidBlue)
            NavigationLink(destination: LazyView(AbbasLoveView())) {
                HStack {
                    Text("Father's Love Letter", comment:  "Love row title")
                    Spacer()
//                        Image(systemName: "chevron.right")
//                            .resizable()
//                            .aspectRatio(contentMode: .fit)
//                            .frame(width: 8)
//                            .foregroundColor(Constants.DAMidBlue)
                }
            }
            .simultaneousGesture(TapGesture().onEnded {
                Event.trackUserAction(
                    "love_letter_opened",
                    category: "profile",
                    metadata: ["source": "profile_menu"]
                )
            })
        }
    }
    
    @MainActor
    private var favoritesRow: some View {
        HStack {
            Image(systemName: "star.fill")
                .foregroundColor(Constants.DAMidBlue)
            NavigationLink(destination: LazyView(FavoritesView())) {
                HStack {
                    Text("Favorites", comment:  "Favorites row title")
                    Spacer()
//                        Image(systemName: "chevron.right")
//                            .resizable()
//                            .aspectRatio(contentMode: .fit)
//                            .frame(width: 8)
//                            .foregroundColor(Constants.DAMidBlue)
                }
            }
        }
    }
    
    @MainActor
    private var createYourOwnRow: some View {
        HStack {
            Image(systemName: "plus.bubble.fill")
                .foregroundColor(Constants.DAMidBlue)
            NavigationLink(destination: LazyView(CreateYourOwnView())) {
                HStack {
                    Text("Create Your Own", comment: "create your own title")
                    Spacer()
//                        Image(systemName: "chevron.right")
//                            .resizable()
//                            .aspectRatio(contentMode: .fit)
//                            .frame(width: 8)
//                            .foregroundColor(Constants.DAMidBlue)
                }
            }
            .simultaneousGesture(TapGesture().onEnded {
                Event.trackUserAction(
                    "create_your_own_opened",
                    category: "profile",
                    metadata: ["source": "profile_menu"]
                )
            })
        }
    }
    
    @MainActor
    private var devotionalsRow: some View {
        HStack {
            if #available(iOS 17, *) {
                Image(systemName: "book.pages.fill")
                    .renderingMode(.original)
                    .foregroundColor(Constants.DAMidBlue)
            } else {
                Image(systemName: "book.fill")
                    .renderingMode(.original)
                    .foregroundColor(Constants.DAMidBlue)
            }
            
            NavigationLink(destination: LazyView( DevotionalView(viewModel: devotionalViewModel))) {
                HStack {
                    Text("Devotionals", comment: "")
                    Spacer()
//                        Image(systemName: "chevron.right")
//                            .resizable()
//                            .aspectRatio(contentMode: .fit)
//                            .frame(width: 8)
//                            .foregroundColor(Constants.DAMidBlue)
                }
            }
        }
    }
    
    private var shareRow: some View {
        SettingsRow(isPresentingContentView: $isPresentingContentView, imageTitle: "square.and.arrow.up.fill", title: "Share SpeakLife", viewToPresent: EmptyView()) {
            shareApp()
            Analytics.logEvent(Event.shareSpeakLifeTapped, parameters: nil)
        }
    }
    
    private var followUs: some View {
        SettingsRow(isPresentingContentView: $isPresentingContentView, imageTitle: "flame.fill", title: "Follow us on Instagram", viewToPresent: EmptyView(), url: APP.Product.instagramURL) {
        }
    }
    
    private var reviewRow: some View  {
        SettingsRow(isPresentingContentView: $isPresentingContentView, imageTitle: "star.bubble.fill", title: "Encourage us", viewToPresent: EmptyView(), url: "\(APP.Product.urlID)?action=write-review") {
        }
    }
    

//    Section("Animation Settings") {
//        Toggle("Enable Animated Text", isOn: $useAnimatedText)
    
    
    @MainActor
    @ViewBuilder
    private var feedbackRow: some View {
        if MFMailComposeViewController.canSendMail() {
            SettingsRow(isPresentingContentView: $isPresentingContentView, imageTitle: "highlighter", title: "Contact us", viewToPresent: LazyView(MailView(isShowing: $isPresentingContentView, result: self.$result, origin: .review, isSubscribed: subscriptionStore.isPremium))) {
                presentContentView()
            }
            .id(UUID())
        }
    }

    @ViewBuilder
    private var emailRow: some View {
        Button(action: { showEmailCaptureSheet = true }) {
            HStack {
                Image(systemName: appState.email.isEmpty ? "envelope.fill" : "envelope.badge.fill")
                    .foregroundColor(.primary)
                    .frame(width: 24)
                Text(appState.email.isEmpty ? "Join Weekly Emails" : "Update Email")
                    .foregroundColor(.primary)
                Spacer()
                if !appState.email.isEmpty {
                    Text(appState.email)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.footnote)
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var supportIDRow: some View {
        Button(action: {
            let userID = Purchases.shared.appUserID
            UIPasteboard.general.string = userID
            Analytics.logEvent("support_id_copied", parameters: nil)
            withAnimation {
                showSupportIDCopied = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation {
                    showSupportIDCopied = false
                }
            }
        }) {
            HStack {
                Image(systemName: showSupportIDCopied ? "checkmark.circle.fill" : "person.badge.key.fill")
                    .foregroundColor(showSupportIDCopied ? .green : .primary)
                    .frame(width: 24)
                Text(showSupportIDCopied ? "Support ID copied!" : "Copy Support ID")
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "doc.on.doc")
                    .foregroundColor(.secondary)
                    .font(.footnote)
            }
            .padding(.vertical, 4)
        }
    }
    
//    @ViewBuilder
//    private var prayerRequestRow: some View {
//        if MFMailComposeViewController.canSendMail() {
//            SettingsRow(isPresentingContentView: $isPresentingContentView, imageTitle: "hands.and.sparkles.fill", title: "Prayer Request", viewToPresent: LazyView(MailView(isShowing: $isPresentingContentView, result: self.$result, origin: .prayer))) {
//                presentContentView()
//            }
//            .id(UUID())
//        }
//    }
    
//    @MainActor
//    @ViewBuilder
//    private var scholarshipView: some View {
//        if MFMailComposeViewController.canSendMail(), !subscriptionStore.isPremium {
//            SettingsRow(isPresentingContentView: $isPresentingPrayerRequestView, imageTitle: "gift.fill", title: "Receive a free year on us", viewToPresent: LazyView(MailView(isShowing: $isPresentingPrayerRequestView, result: self.$result, origin: .profile))) {
//                presentPrayerRequestView()
//            }
//        }
//    }
    
    private var warriorView: some View {
        HStack {
            Image(systemName: "bolt.shield.fill")
                .foregroundColor(Constants.DAMidBlue)
            NavigationLink(destination: LazyView(WarriorView())) {
                HStack {
                    Text("Warrior's Prayer", comment: "pp")
                    Spacer()
//                        Image(systemName: "chevron.right")
//                            .resizable()
//                            .aspectRatio(contentMode: .fit)
//                            .frame(width: 8)
//                            .foregroundColor(Constants.DAMidBlue)
                }
            }
        }
    }
    
    private var privacyPolicyRow: some View {
        NavigationLink(destination: LazyView(PrivacyPolicyView())) {
            HStack {
                Text("Privacy Policy", comment: "pp")
                Spacer()
//                    Image(systemName: "chevron.right")
//                        .resizable()
//                        .aspectRatio(contentMode: .fit)
//                        .frame(width: 8)
//                        .foregroundColor(Constants.DAMidBlue)
            }
        }
    }
    
    private var termsConditionsRow: some View {
        ZStack {
            Text("Terms and Conditions", comment: "terms n conditions")
            Link("", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
        }
    }
    
    private var soundsRow: some View {
        ZStack {
            HStack {
                Text("Background Music", comment: "terms n conditions")
                Spacer()
                Toggle("", isOn: declarationStore.$backgroundMusicEnabled)
                    .padding()
            }
            
        }
    }
        
        private var animationSettings: some View {
            ZStack {
                HStack {
                    Text("Animation Settings", comment: "terms n conditions")
                    Spacer()
                    Toggle("", isOn: $useAnimatedText)
                        .padding()
                }
                
            }
        }
    
    @MainActor
    private var bookLink: some  View {
        HStack {
            Image(systemName:"book.fill")
                .foregroundColor(Constants.DAMidBlue)
            Link(destination: URL(string: "https://books.apple.com/us/book/100-days-of-power-declarations/id1616288315")!, label: {
                Text("100 Days of Power Declarations", comment: "")
            })
        }
    }
    private var copyrightView: some  View {
        Text("Scripture quotations marked (NLT) are taken from the Holy Bible, New Living Translation, copyright ©1996, 2004, 2015 by Tyndale House Foundation. Used by permission of Tyndale House Publishers, Carol Stream, Illinois 60188. All rights reserved.")
    }
    
    // MARK: - Private methods
    
    @MainActor
    private func presentContentView() {
        self.isPresentingContentView = true
    }
    
    @MainActor
    private func presentPrayerRequestView() {
        self.isPresentingPrayerRequestView = true
    }
    
    private func shareApp() {
        showShareSheet.toggle()
    }
    
}

extension UIView {
    func toImage() -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(bounds.size, false, 0.0)
        defer { UIGraphicsEndImageContext() }
        if let context = UIGraphicsGetCurrentContext() {
            layer.render(in: context)
            let image = UIGraphicsGetImageFromCurrentImageContext()
            return image
        }
        return nil
    }
}

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Privacy Policy for SpeakLife: Bible Affirmations")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Last Updated: 12-05-2023")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text("Welcome to SpeakLife ('we', 'us', 'our'). We are committed to protecting your privacy. This Privacy Policy explains how we handle and treat your data when you use SpeakLife: Bible Affirmations ('App')")
                    .font(.body)
                
                Text("1. Information We Collect")
                    .font(.subheadline)
                Text("* As a policy, our App does not collect, store, or process any personal data from our users. We believe in your right to privacy and have designed our App accordingly.")
                    .font(.body)
                
                Text("2. Data Usage")
                    .font(.subheadline)
                Text("* Since we do not collect any personal data, there is no usage of such data.")
                    .font(.body)
                
                Text("3. Third-Party Services")
                    .font(.subheadline)
                Text("* The following data may be collected but is not linked to your identity: App Installs, product interaction.")
                    .font(.body)
                
                
                Text("4. Changes to Our Privacy Policy")
                    .font(.subheadline)
                Text("* We may update our Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy on this page and updating the 'Last Updated' date.")
                    .font(.body)
                
                Text("5. Contact Us")
                    .font(.subheadline)
                Text("* If you have any questions about our Privacy Policy, please contact us at speaklife@diosesaqui.com.")
                    .font(.body)
                   
            }
            .padding()
        }
        .navigationTitle("Privacy Policy")
    }
}

// MARK: - StreakStatsProfileSheet

struct StreakStatsProfileSheet: View {
    @ObservedObject var viewModel: EnhancedStreakViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {

                    // ── Streak Stats ──────────────────────────────────────
                    VStack(spacing: 16) {
                        Text("Your Streak")
                            .font(.title2.bold())
                            .frame(maxWidth: .infinity, alignment: .leading)

                        HStack(spacing: 12) {
                            streakStatCard(icon: "flame.fill",              color: .orange, value: "\(viewModel.streakStats.currentStreak)",    label: "Current")
                            streakStatCard(icon: "trophy.fill",             color: .yellow, value: "\(viewModel.streakStats.longestStreak)",     label: "Best")
                            streakStatCard(icon: "calendar.badge.checkmark",color: .green,  value: "\(viewModel.streakStats.totalDaysCompleted)",label: "Total Days")
                        }

                        if viewModel.streakStats.streakFreezeAvailable {
                            HStack(spacing: 8) {
                                Text("🛡️")
                                Text("Streak freeze available — one missed day won't break your streak")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.blue.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                    .padding(.horizontal, 20)

                    Divider().padding(.horizontal, 20)

                    // ── Badges ────────────────────────────────────────────
                    VStack(spacing: 16) {
                        let allBadges   = viewModel.badgeManager.allBadges
                        let earnedCount = allBadges.filter { $0.isUnlocked }.count

                        HStack {
                            Text("Badges").font(.title2.bold())
                            Spacer()
                            Text("\(earnedCount)/\(allBadges.count)").font(.caption).foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 20)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            ForEach(allBadges) { badge in
                                streakBadgeCell(badge)
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    Color.clear.frame(height: 20)
                }
                .padding(.top, 20)
            }
            .navigationTitle("Streak & Badges")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func streakStatCard(icon: String, color: Color, value: String, label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.title2).foregroundColor(color)
            Text(value).font(.title.bold())
            Text(label).font(.caption).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func streakBadgeCell(_ badge: Badge) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(badge.isUnlocked ? badge.type.primaryColor.opacity(0.15) : Color(.tertiarySystemBackground))
                    .frame(width: 60, height: 60)
                Image(systemName: badge.type.iconName)
                    .font(.system(size: 24))
                    .foregroundColor(badge.isUnlocked ? badge.type.primaryColor : .gray.opacity(0.3))
            }
            Text(badge.isUnlocked ? badge.title : "???")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(badge.isUnlocked ? .primary : .secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            if badge.isUnlocked {
                Text(badge.rarity.rawValue.capitalized)
                    .font(.system(size: 8))
                    .foregroundColor(streakRarityColor(badge.rarity))
            }
        }
    }

    private func streakRarityColor(_ rarity: BadgeRarity) -> Color {
        switch rarity {
        case .common: return .gray
        case .rare: return .blue
        case .epic: return .purple
        case .legendary: return .orange
        }
    }
}
