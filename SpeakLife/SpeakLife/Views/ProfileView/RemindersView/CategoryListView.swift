//
//  CategoryListView.swift
//  Dios Es Aqui
//
//  Created by Riccardo Washington on 2/19/22.
//

import SwiftUI


final class CategoryListViewModel: ObservableObject {

    init(_ declarationStore: DeclarationViewModel) {
        self.declarationStore = declarationStore
        // Bible-book categories (Genesis, Matthew, Psalms, etc.) belong on the
        // declaration feed picker but not on the notification topics list.
        // Notifications are a curated set of life themes (peace, identity, faith,
        // etc.); flooding the picker with 50+ Bible books is overwhelming and
        // doesn't map to how users think about reminders.
        self.categories = declarationStore.allcategories.filter { !$0.isBibleBook }

        // Selected state must read from appState.selectedNotificationCategories
        // (where the survey wrote during onboarding), NOT from declarationStore.
        // selectedCategories — that's the feed selection, a different storage.
        // Both end up holding category sets but the survey only writes the
        // notification one, so reading the feed showed "0 selected" even when
        // the user had completed onboarding and was getting reminders.
        let raw = UserDefaults.standard.string(forKey: "selectedNotificationCategories") ?? ""
        let parsed = raw
            .split(separator: ",")
            .compactMap { DeclarationCategory(rawValue: String($0)) }
        self.selectedCategories = Set(parsed)
    }

    private let declarationStore: DeclarationViewModel
    
    @Published var selectedCategories: Set<DeclarationCategory>
    
    let categories: [DeclarationCategory]
    
    func addCategory(_ category: DeclarationCategory) {
        selectedCategories.update(with: category)
    }
    
    func remove(category:  DeclarationCategory) {
        selectedCategories.remove(category)
    }
    
    func saveCategories(_ appState: AppState) {
        // Use rawValue (e.g. "anxiety") not .name (e.g. "Anxiety & Worry") —
        // the parser in rescheduleFromUserDefaults uses DeclarationCategory(rawValue:).
        let categoryString = selectedCategories.map { $0.rawValue }.joined(separator: ",")
        appState.selectedNotificationCategories = categoryString
        declarationStore.save(selectedCategories)

        // Reschedule notifications immediately so content reflects the new category
        // selection without waiting for the next natural resync cycle.
        guard appState.notificationEnabled else { return }
        NotificationManager.shared.registerNotifications(
            count: max(appState.notificationCount, 5),
            startTime: appState.startTimeIndex,
            endTime: appState.endTimeIndex,
            categories: selectedCategories
        )
        appState.lastNotificationSetDate = Date()
    }
    
    func toggleCategory(_ category: DeclarationCategory) {
        
        if selectedCategories.contains(category) {
            selectedCategories.remove(category)
        } else {
            selectedCategories.insert(category)
        }
    }
    
}

struct CategoryListView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var categoryList: CategoryListViewModel
    var onSave: (() -> Void)? = nil
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [Color(red: 0.06, green: 0.08, blue: 0.2), Color(red: 0.1, green: 0.15, blue: 0.3)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 16) {
                    Text("Notification Topics")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                        .padding(.top)

                    // Notification context banner
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "bell.badge.fill")
                            .foregroundColor(.yellow)
                            .font(.system(size: 15, weight: .semibold))
                            .padding(.top, 1)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("This controls your daily reminders")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                            Text("The declarations sent to you every day are pulled from these topics. Select what you want God's Word to speak into.")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(.white.opacity(0.75))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.yellow.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.yellow.opacity(0.25), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal)

                    List {
                        ForEach(categoryList.categories, id: \.id) { category in
                            CategoryListCard(category: category, isSelected: categoryList.selectedCategories.contains(category)) {
                                categoryList.toggleCategory(category)
                            }
                            .listRowBackground(Color.clear)
                            
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .cornerRadius(20)
                    .padding(.bottom, 8)
                }
            }
            .navigationTitle("Notification Topics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Text("\(categoryList.selectedCategories.count) selected")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.blue)
                }
            }
        }
        .navigationViewStyle(.stack)
        .onAppear {
            UINavigationBar.appearance().largeTitleTextAttributes = [.foregroundColor: UIColor.white]
            UINavigationBar.appearance().titleTextAttributes = [.foregroundColor: UIColor.white]
        }
        .onDisappear {
            categoryList.saveCategories(appState)
            onSave?()
        }
    }
}

struct CategoryListCard: View {
    let category: DeclarationCategory
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: {
            withAnimation(.easeInOut) {
                onTap()
            }
        }) {
            HStack {
                Text(category.categoryTitle)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .transition(.scale)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ? Color.blue.opacity(0.8) : Color.clear, lineWidth: 1.5)
                    )
                    .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 3)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
