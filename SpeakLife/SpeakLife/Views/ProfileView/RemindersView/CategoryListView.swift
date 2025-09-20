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
        self.categories = declarationStore.allcategories
        self.selectedCategories = declarationStore.selectedCategories
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
        let categoryString = selectedCategories.map { $0.name }.joined(separator: ",")
        appState.selectedNotificationCategories = categoryString
        declarationStore.save(selectedCategories)
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
                    Text("✨ Personalize your experience")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                        .padding(.top)
                    
                    Text("Choose the categories that inspire and uplift you most.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
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
            .navigationTitle("Choose Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                        .foregroundColor(.blue)
                }
            }
        }
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
