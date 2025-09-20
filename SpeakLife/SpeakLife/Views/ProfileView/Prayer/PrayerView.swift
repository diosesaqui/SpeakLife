//
//  PrayerView.swift
//  SpeakLife
//
//  Created by Riccardo Washington on 4/10/23.
//

import SwiftUI
import FirebaseAnalytics

struct PrayerView: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @Environment(\.colorScheme) var colorScheme
    @State private var isPresentingManageSubscriptionView = false
    @StateObject private var prayerViewModel = PrayerViewModel()
    
    var body: some View {
            NavigationView {
                ZStack {
                    // Gradient background
                    Image(subscriptionStore.onboardingBGImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: UIScreen.main.bounds.size.width)
                       .edgesIgnoringSafeArea([.all])


                    // ScrollView with VStack for custom list-like layout
                    ScrollView {
                        VStack(spacing: 4) {
                            ForEach(prayerViewModel.sectionData.indices, id: \.self) { index in
                                sectionView(for: index)
                                    .padding()
                                    .onTapGesture {
                                        let prayerCategory = prayerViewModel.sectionData[index].title
                                        Analytics.logEvent("\(prayerCategory) prayer tapped", parameters: nil)
                                    }
                            }
                        }
                    }
                    .navigationBarTitle("Powerful Prayers")
                    .foregroundColor(.white)
                }
                .onAppear(perform: fetchPrayers)
                .sheet(isPresented: $isPresentingManageSubscriptionView) {
                    PremiumView()
                }
                .alert("Failed to load prayers", isPresented: $prayerViewModel.hasError) {
                    Button("OK", role: .cancel) {}
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                isPresentingManageSubscriptionView = false
            }
        }

    
    private func sectionView(for index: Int) -> some View {
        DisclosureGroup(isExpanded: $prayerViewModel.sectionData[index].isExpanded) {
            ForEach(prayerViewModel.sectionData[index].items, id: \.self) { prayer in
                if prayer.isPremium && !subscriptionStore.isPremium {
                    premiumPrayerRow(prayer)
                } else {
                    standardPrayerRow(prayer, index: index)
                }
            }
        } label: {
            Text(prayerViewModel.sectionData[index].title.uppercased())
                .font(Font.custom("AppleSDGothicNeo-Regular", size: 20, relativeTo: .title))
                .padding()
        }
    }
    
    private func premiumPrayerRow(_ prayer: Prayer) -> some View {
        Button(action: { isPresentingManageSubscriptionView.toggle() }) {
            prayerRowView(prayer)
                .padding()
        }
    }
    
    private func standardPrayerRow(_ prayer: Prayer, index: Int) -> some View {
        NavigationLink(destination: PrayerDetailView(prayer: prayer.prayerText, showConfetti: index == 0) { Image("sunset3") }) {
            prayerRowView(prayer)
                .font(Font.custom("AppleSDGothicNeo-Regular", size: 20, relativeTo: .body))
                .lineLimit(/*@START_MENU_TOKEN@*/2/*@END_MENU_TOKEN@*/)
                .padding()
        }
    }
    
    private func prayerRowView(_ prayer: Prayer) -> some View {
        HStack(alignment: .center) {
            if prayer.isPremium {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
            }
            Text(prayer.prayerText)
                .font(Font.custom("AppleSDGothicNeo-Regular", size: 20, relativeTo: .body))
                .lineLimit(/*@START_MENU_TOKEN@*/2/*@END_MENU_TOKEN@*/)
        }
    }
    
    private func fetchPrayers() {
        Task {
            await prayerViewModel.fetchPrayers()
        }
    }
}
