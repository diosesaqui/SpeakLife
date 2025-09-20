//
//  CategoryButtonRow.swift
//  Dios Es Aqui
//
//  Created by Riccardo Washington on 2/19/22.
//

import SwiftUI
import FirebaseAnalytics

struct CategoryButtonRow: View  {

    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @EnvironmentObject var declarationStore: DeclarationViewModel

    @State var presentDevotionalSubscriptionView = false
    @State var isPresentingCategoryList = false
    @State var isPresentingPremiumView = false {
        didSet {
            print("\(isPresentingPremiumView) is being changed")
        }
    }

    @Binding var showConfirmation: Bool

    var body: some View {
        Button(action: displayCategoryView) {
                HStack {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundColor(Constants.DAMidBlue)
                        .font(.system(size: 16, weight: .medium))

                    Text("Categories", comment: "category button title")
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .semibold))

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundColor(.white.opacity(0.6))
                        .font(.system(size: 14, weight: .medium))
                }
                .padding(.horizontal, 16)
                .frame(height: 50)
                .overlay(RoundedRectangle(cornerRadius: 20)
                .stroke(Constants.DAMidBlue, lineWidth: 1))// ✅ same as the rest of the input cells
            }
            .buttonStyle(PlainButtonStyle())

        .sheet(
            isPresented: subscriptionStore.isPremium ? $isPresentingCategoryList : $isPresentingPremiumView,
            onDismiss: {
                if isPresentingCategoryList {
                    withAnimation {
                        showConfirmation = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        withAnimation {
                            showConfirmation = false
                        }
                    }
                }
                self.isPresentingPremiumView = false
                self.isPresentingCategoryList = false
            },
            content: {
                contentView
                    .sheet(isPresented: $presentDevotionalSubscriptionView) {
                        DevotionalSubscriptionView {
                            presentDevotionalSubscriptionView = false
                        }
                    }
            }
        )
    }

    private func displayCategoryView() {
        if !subscriptionStore.isPremium {
            isPresentingPremiumView = true
            Analytics.logEvent(Event.tryPremiumTapped, parameters: nil)
        } else {
            isPresentingCategoryList = true
            Analytics.logEvent(Event.reminders_categoriesTapped, parameters: nil)
        }
    }

    @ViewBuilder
    private var contentView: some View {
        if !subscriptionStore.isPremium {
            OptimizedSubscriptionView() {//(size: UIScreen.main.bounds.size) {
                // Handle callback - typically dismiss or navigation
            }
                .onDisappear {
                    if !subscriptionStore.isPremium, !subscriptionStore.isInDevotionalPremium {
                        if subscriptionStore.showDevotionalSubscription {
                            presentDevotionalSubscriptionView = true
                        }
                    }
                }
        } else {
            CategoryListView(
                categoryList: CategoryListViewModel(declarationStore),
                onSave: {
                    withAnimation {
                        showConfirmation = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        withAnimation {
                            showConfirmation = false
                        }
                    }
                }
            )
        }
    }
}
