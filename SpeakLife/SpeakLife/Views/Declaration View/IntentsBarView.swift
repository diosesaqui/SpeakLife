//
//  IntentsBarView.swift
//  Dios Es Aqui
//
//  Created by Riccardo Washington on 1/2/22.
//

import SwiftUI
import FirebaseAnalytics

struct IntentsBarView: View {
    
    // MARK: - Properties
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var themeStore: ThemeViewModel
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var timerViewModel: TimerViewModel
    @EnvironmentObject var devotionalViewModel: DevotionalViewModel
    
    @ObservedObject var viewModel: DeclarationViewModel
    @ObservedObject var themeViewModel: ThemeViewModel
    @State private var isPresentingView = false
    @State private var isPresentingThemeChooser = false
    @State private var isPresentingCategoryChooser = false
    @State private var isPresentingPremiumView = false
    @State private var isPresentingProfileView = false
    @State private var isPresentingDevotionalView = false
    @State private var showEntryView = false
    
    
    var body: some View {
        HStack(spacing: 8) {
            
            categoryChooserButton
           // devotionalButton
            Spacer()
            themeChooserButton
            
        }
        .padding()
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            self.isPresentingThemeChooser = false
            self.isPresentingPremiumView = false
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DismissCategoryChooser"))) { _ in
            self.isPresentingCategoryChooser = false
            self.isPresentingDevotionalView = false
            self.showEntryView = false
            self.isPresentingProfileView = false
        }
        .foregroundColor(.white)
    }
    
    var categoryChooserButton: some View {
        Button {
            chooseCategory()
            Juice.play(.tapLight)
        } label: {
            HStack {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.callout)
                Text(viewModel.selectedCategory.categoryTitle)
                    .font(Font.custom("AppleSDGothicNeo-Regular", size: 14, relativeTo: .callout))
                if appState.newCategoriesAddedv4 {
                    NewCategoriesBadge()
                }
            }
        }.sheet(isPresented: $isPresentingCategoryChooser, onDismiss: {
            withAnimation {
                self.isPresentingCategoryChooser = false
                self.appState.newCategoriesAddedv4 = false
                if appState.onBoardingTest {
                 //   timerViewModel.loadRemainingTime()
                }
            }
        }, content: {
            CategoryChooserView(viewModel: viewModel)
        })
        .frame(height: 48)
        .padding([.leading, .trailing], Constants.padding)
        .background(themeStore.selectedTheme.mode == .dark ? Constants.backgroundColor : Constants.backgroundColorLight)
        .cornerRadius(Constants.cornerRadius)
    }
    
    var themeChooserButton: some View {
        HStack(spacing: DS.Spacing.xs) {
            CapsuleImageButton(title: "paintbrush.fill") {
                chooseWallPaper()
                Juice.play(.tapLight)
            }.sheet(isPresented: $isPresentingThemeChooser) {
                self.isPresentingThemeChooser = false
                if appState.onBoardingTest {
                 //   timerViewModel.loadRemainingTime()
                }
            } content: {
                ThemeChooserView(themesViewModel: themeViewModel)
            }
        }
    }
    
  
    
    
    // MARK: - Intent(s)
    
    private func chooseWallPaper() {
        // Timer continues running - don't save
        self.isPresentingThemeChooser = true
        AnalyticsService.shared.track(Event.themeChangerTapped)
    }
    
    private func presentDevotional() {
        // Timer continues running - don't save
        self.isPresentingDevotionalView = true
    }
    
    private func profileButtonTapped() {
        // Timer continues running - don't save
        self.isPresentingProfileView = true
    }
    
    private func chooseCategory() {
        // Timer continues running - don't save
        self.isPresentingCategoryChooser = true
    }
    
    private func premiumView()  {
        self.isPresentingPremiumView = true
        AnalyticsService.shared.track(Event.tryPremiumTapped)
    }
}
