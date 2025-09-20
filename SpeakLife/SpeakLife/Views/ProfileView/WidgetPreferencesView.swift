//
//  WidgetPreferencesView.swift
//  SpeakLife
//
//  Created by Claude on 8/9/25.
//

import SwiftUI

struct WidgetPreferencesView: View {
    @EnvironmentObject var declarationViewModel: DeclarationViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedCategories: Set<DeclarationCategory> = []
    @State private var showingSaved = false
    
    // Widget-relevant categories for users to choose from
    private let availableCategories: [(DeclarationCategory, String, String)] = [
        (.faith, "Faith & Trust", "Build confidence in God's promises"),
        (.hope, "Hope & Future", "Encouraging promises for tomorrow"),
        (.love, "Love & Relationships", "Strengthen your connections"),
        (.rest, "Peace & Rest", "Find calm in God's presence"),
        (.wisdom, "Wisdom & Guidance", "Seek divine understanding"),
        (.gratitude, "Gratitude & Joy", "Celebrate God's blessings"),
        (.health, "Health & Healing", "Pray for physical wellness"),
        (.work, "Work & Purpose", "Find meaning in your calling"),
        (.anxiety, "Anxiety & Worry", "Find peace in troubled times"),
        (.fear, "Fear & Courage", "Be brave in God's strength"),
        (.identity, "Identity & Worth", "Know who you are in Christ"),
        (.destiny, "Purpose & Destiny", "Discover your God-given path"),
        (.favor, "Favor & Blessings", "Walk in divine provision"),
        (.confidence, "Confidence", "Stand strong in who you are")
    ]
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                
                ScrollView {
                    categoryGrid
                }
                
                Spacer()
                
                actionButtons
            }
            .padding()
            .navigationTitle("Widget Preferences")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarBackButtonHidden(true)
            .onAppear {
                selectedCategories = declarationViewModel.selectedCategories
            }
            .alert("Preferences Saved!", isPresented: $showingSaved) {
                Button("OK") {}
            } message: {
                Text("Your widget will now show personalized promises based on your selected categories.")
            }
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Personalize Your Widget")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Select the types of promises you'd like to see in your widget. The widget will intelligently choose relevant content based on the time of day and your preferences.")
                .font(.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    private var categoryGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            ForEach(availableCategories, id: \.0) { category, title, description in
                CategoryCard(
                    category: category,
                    title: title,
                    description: description,
                    isSelected: selectedCategories.contains(category)
                ) {
                    toggleCategory(category)
                }
            }
        }
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: savePreferences) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Save Preferences")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
            }
            .disabled(selectedCategories.isEmpty)
            
            Button(action: { dismiss() }) {
                Text("Cancel")
                    .font(.headline)
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.blue, lineWidth: 1)
                    )
            }
        }
    }
    
    private func toggleCategory(_ category: DeclarationCategory) {
        if selectedCategories.contains(category) {
            selectedCategories.remove(category)
        } else {
            selectedCategories.insert(category)
        }
    }
    
    private func savePreferences() {
        declarationViewModel.updateCategorySelections(selectedCategories)
        showingSaved = true
        
        // Dismiss after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            dismiss()
        }
    }
}

struct CategoryCard: View {
    let category: DeclarationCategory
    let title: String
    let description: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: category.icon)
                    .foregroundColor(isSelected ? .white : .blue)
                    .font(.title2)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                        .font(.title3)
                }
            }
            
            Text(title)
                .font(.headline)
                .foregroundColor(isSelected ? .white : .primary)
                .fontWeight(.semibold)
            
            Text(description)
                .font(.caption)
                .foregroundColor(isSelected ? .white.opacity(0.9) : .secondary)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
        .padding()
        .frame(height: 120)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isSelected ? Color.blue : Color(UIColor.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? Color.clear : Color(UIColor.systemGray4), lineWidth: 1)
        )
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3), value: isSelected)
        .onTapGesture {
            onTap()
        }
    }
}

// Extension to provide icons for categories
private extension DeclarationCategory {
    var icon: String {
        switch self {
        case .faith: return "cross.fill"
        case .hope: return "sunrise.fill"
        case .love: return "heart.fill"
        case .rest: return "leaf.fill"
        case .wisdom: return "brain.head.profile"
        case .gratitude: return "hand.raised.fill"
        case .health: return "heart.text.square.fill"
        case .work: return "briefcase.fill"
        case .anxiety: return "cloud.rain.fill"
        case .fear: return "shield.fill"
        case .identity: return "person.fill"
        case .destiny: return "star.fill"
        case .favor: return "crown.fill"
        case .confidence: return "person.badge.plus.fill"
        default: return "circle.fill"
        }
    }
}

#if DEBUG
struct WidgetPreferencesView_Previews: PreviewProvider {
    static var previews: some View {
        WidgetPreferencesView()
            .environmentObject(DeclarationViewModel(apiService: MockAPIService(), notificationManager: NotificationManager.shared))
    }
}
#endif