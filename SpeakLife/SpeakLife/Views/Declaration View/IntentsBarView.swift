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
            Selection.shared.selectionFeedback()
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
                    timerViewModel.loadRemainingTime()
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
        HStack(spacing: 8) {
            CapsuleImageButton(title: "paintbrush.fill") {
                chooseWallPaper()
                Selection.shared.selectionFeedback()
            }.sheet(isPresented: $isPresentingThemeChooser) {
                self.isPresentingThemeChooser = false
                if appState.onBoardingTest {
                    timerViewModel.loadRemainingTime()
                }
            } content: {
                ThemeChooserView(themesViewModel: themeViewModel)
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
            presentDevotional()
            Selection.shared.selectionFeedback()
        }.sheet(isPresented: $isPresentingDevotionalView) {
            self.isPresentingDevotionalView = false
            withAnimation {
                if appState.onBoardingTest {
                    timerViewModel.loadRemainingTime()
                }
            }
        } content: {
            DevotionalView(viewModel: devotionalViewModel)

        }
    }
    
    
    // MARK: - Intent(s)
    
    private func chooseWallPaper() {
        timerViewModel.saveRemainingTime()
        self.isPresentingThemeChooser = true
        Analytics.logEvent(Event.themeChangerTapped, parameters: nil)
    }
    
    private func presentDevotional() {
        timerViewModel.saveRemainingTime()
        self.isPresentingDevotionalView = true
    }
    
    private func profileButtonTapped() {
        timerViewModel.saveRemainingTime()
        self.isPresentingProfileView = true
    }
    
    private func chooseCategory() {
        timerViewModel.saveRemainingTime()
        self.isPresentingCategoryChooser = true
    }
    
    private func premiumView()  {
        self.isPresentingPremiumView = true
        Analytics.logEvent(Event.tryPremiumTapped, parameters: nil)
    }
}
