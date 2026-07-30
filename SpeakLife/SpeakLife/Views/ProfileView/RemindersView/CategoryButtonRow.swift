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

    /// Number of currently selected categories for the badge.
    private var selectedCount: Int {
        declarationStore.selectedCategories.count
    }

    var body: some View {
        Button(action: displayCategoryView) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "bell.badge.fill")
                        .foregroundColor(Constants.DAMidBlue)
                        .font(.system(size: 16, weight: .medium))

                    Text("Notification Topics")
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .semibold))

                    Spacer()

                    if selectedCount > 0 {
                        Text("\(selectedCount) selected")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Constants.DAMidBlue)
                            .padding(.horizontal, DS.Spacing.xs)
                            .padding(.vertical, 3)
                            .background(
                                Capsule().fill(Constants.DAMidBlue.opacity(0.15))
                            )
                    }

                    Image(systemName: "chevron.right")
                        .foregroundColor(.white.opacity(0.6))
                        .font(.system(size: 14, weight: .medium))
                }

                Text("Choose which topics appear in your daily reminders")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.55))
                    .padding(.leading, 26)
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Constants.DAMidBlue, lineWidth: 1)
            )
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
            AnalyticsService.shared.track(Event.tryPremiumTapped)
        } else {
            isPresentingCategoryList = true
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
