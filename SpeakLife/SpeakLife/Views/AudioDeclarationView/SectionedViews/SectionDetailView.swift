//
//  SectionDetailView.swift
//  SpeakLife
//
//  Created by Claude on 12/26/24.
//

import SwiftUI

struct SectionDetailView: View {
    let sectionId: String
    let sectionTitle: String
    let items: [AudioDeclaration]
    let audioViewModel: AudioPlayerViewModel
    let onItemTap: (AudioDeclaration) -> Void
    let onFavoriteTap: (AudioDeclaration) -> Void
    
    @EnvironmentObject var viewModel: AudioDeclarationViewModel
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchText = ""
    @State private var sortOption: SortOption = .default
    
    enum SortOption: String, CaseIterable {
        case `default` = "Default"
        case title = "Title"
        case duration = "Duration"
        case newest = "Newest First"
        
        var icon: String {
            switch self {
            case .default: return "list.bullet"
            case .title: return "textformat"
            case .duration: return "clock"
            case .newest: return "calendar"
            }
        }
    }
    
    private var filteredItems: [AudioDeclaration] {
        let filtered = searchText.isEmpty ? items : items.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.subtitle.localizedCaseInsensitiveContains(searchText)
        }
        
        switch sortOption {
        case .default:
            return filtered
        case .title:
            return filtered.sorted { $0.title < $1.title }
        case .duration:
            return filtered.sorted { 
                extractMinutes(from: $0.duration) < extractMinutes(from: $1.duration)
            }
        case .newest:
            return filtered.reversed()
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Gradients().speakLifeCYOCell
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.white.opacity(0.6))
                        
                        TextField("Search in \(sectionTitle)", text: $searchText)
                            .foregroundColor(.white)
                            .autocapitalization(.none)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(.ultraThinMaterial)
                    )
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // Sort options
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(SortOption.allCases, id: \.self) { option in
                                SortChip(
                                    title: option.rawValue,
                                    icon: option.icon,
                                    isSelected: sortOption == option,
                                    action: { sortOption = option }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 12)
                    
                    // Items list
                    if items.isEmpty {
                        Spacer()
                        VStack(spacing: 16) {
                            Image(systemName: "music.note.list")
                                .font(.system(size: 50))
                                .foregroundColor(.white.opacity(0.5))
                            
                            Text("No items in this section")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            
                            Text("Check back later for new content")
                                .font(.body)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        Spacer()
                    } else if filteredItems.isEmpty {
                        Spacer()
                        emptySearchView
                        Spacer()
                    } else {
                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVStack(spacing: 12) {
                                ForEach(filteredItems) { item in
                                    CompactAudioCell(
                                        item: item,
                                        isFavorite: viewModel.favoritesManager.isFavorite(item),
                                        onTap: {
                                            dismiss()
                                            onItemTap(item)
                                        },
                                        onFavoriteTap: {
                                            onFavoriteTap(item)
                                        }
                                    )
                                    .padding(.horizontal)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
            }
            .navigationTitle(sectionTitle)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.body.weight(.medium))
                    .foregroundColor(Constants.DAMidBlue)
                }
            }
        }
    }
    
    private var emptySearchView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.white.opacity(0.5))
            
            Text("No results found")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Text("Try adjusting your search or filters")
                .font(.body)
                .foregroundColor(.white.opacity(0.7))
        }
    }
    
    private func extractMinutes(from duration: String) -> Int {
        let components = duration.split(separator: ":")
        guard components.count >= 1,
              let minutes = Int(components[0]) else { return 0 }
        return minutes
    }
}

struct SortChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? Constants.DAMidBlue : Color.white.opacity(0.2))
            )
        }
    }
}