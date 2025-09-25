//
//  GenericSectionedView.swift
//  SpeakLife
//
//  Created by Claude on 12/26/24.
//

import SwiftUI

// MARK: - Generic Sectioned View

struct GenericSectionedView<ContentType: SectionableContent, Provider: SectionProvider>: View 
where Provider.ContentType == ContentType {
    
    let sectionProvider: Provider
    let onItemTap: (ContentType) -> Void
    let onFavoriteTap: (ContentType) -> Void
    
    @State private var refreshing = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Main content
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Pull to refresh indicator
                        if refreshing {
                            refreshIndicator
                        }
                        
                        // Sections
                        ForEach(sectionProvider.sections) { section in
                            GenericHorizontalSection(
                                section: section,
                                onItemTap: onItemTap,
                                onFavoriteTap: onFavoriteTap,
                                onSeeAllTap: {
                                    // Future: Handle see all
                                }
                            )
                            .id(section.id)
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .move(edge: .top).combined(with: .opacity)
                            ))
                        }
                        
                        // Bottom spacing for tab bar
                        Spacer()
                            .frame(height: geometry.size.height * 0.15)
                    }
                    .padding(.top, 8)
                }
                .refreshable {
                    await refreshContent()
                }
                
                // Empty state
                if sectionProvider.sections.isEmpty {
                    emptyStateView
                }
            }
        }
    }
    
    // MARK: - Private Views
    
    private var refreshIndicator: some View {
        HStack {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(0.8)
            Text("Refreshing...")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.top, 8)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "rectangle.stack.badge.play")
                .resizable()
                .frame(width: 80, height: 80)
                .foregroundColor(.white.opacity(0.5))
            
            Text("No Content Available")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("Check back later for new content")
                .font(.body)
                .foregroundColor(.white.opacity(0.7))
            
            Button(action: {
                Task {
                    await refreshContent()
                }
            }) {
                Label("Refresh", systemImage: "arrow.clockwise")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Constants.DAMidBlue)
                    )
            }
        }
        .padding(40)
    }
    
    // MARK: - Private Methods
    
    private func refreshContent() async {
        withAnimation {
            refreshing = true
        }
        
        // Simulate refresh - actual implementation depends on provider
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        
        withAnimation {
            refreshing = false
        }
    }
}