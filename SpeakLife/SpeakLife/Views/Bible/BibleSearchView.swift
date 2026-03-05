//
//  BibleSearchView.swift
//  SpeakLife
//
//  Created by SpeakLife Team on 1/28/26.
//

import SwiftUI

struct BibleSearchView: View {
    @ObservedObject var viewModel: BibleViewModel
    @Environment(\.dismiss) var dismiss
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Constants.DAMidBlue)
                    
                    TextField("Search verses...", text: $viewModel.searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .focused($isSearchFocused)
                        .submitLabel(.search)
                        .foregroundColor(.white)
                        .onSubmit {
                            Task { await viewModel.searchVerses(query: viewModel.searchText) }
                        }
                    
                    if !viewModel.searchText.isEmpty {
                        Button(action: {
                            viewModel.searchText = ""
                            viewModel.searchResults = []
                            viewModel.showSearchError = false
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(Constants.DAMidBlue)
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Constants.backgroundColor)
                        .stroke(Constants.DAMidBlue.opacity(0.3), lineWidth: 1)
                )
                .padding()
                
                // Results
                if viewModel.isSearching {
                    Spacer()
                    ProgressView("Searching...")
                        .progressViewStyle(CircularProgressViewStyle())
                    Spacer()
                } else if viewModel.showSearchError && !viewModel.searchText.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(.orange)
                        
                        Text("Search Failed")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                        
                        Text(viewModel.errorMessage ?? "Unable to search. Please check your connection and try again.")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button(action: {
                            Task { await viewModel.searchVerses(query: viewModel.searchText) }
                        }) {
                            Text("Try Again")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 8)
                                .background(Constants.DAMidBlue)
                                .cornerRadius(20)
                        }
                    }
                    Spacer()
                } else if viewModel.searchResults.isEmpty && !viewModel.searchText.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.white.opacity(0.8))
                        
                        Text("No results found")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                        
                        Text("Try different keywords")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    Spacer()
                } else if !viewModel.searchResults.isEmpty {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            Text("\(viewModel.searchResults.count) results")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.8))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                            
                            ForEach(viewModel.searchResults) { result in
                                SearchResultCard(
                                    result: result,
                                    onTap: {
                                        Task {
                                            await viewModel.loadChapter(
                                                bookAbbrev: result.bookAbbrev,
                                                chapterNumber: result.chapter
                                            )
                                            dismiss()
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.vertical)
                    }
                } else {
                    Spacer()
                    VStack(spacing: 24) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.white.opacity(0.8))
                        
                        VStack(spacing: 8) {
                            Text("Search the Bible")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                            
                            Text("Find verses by keywords")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        
                        // Suggested Searches
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Try searching for:")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                            
                            BibleFlowLayout(spacing: 8) {
                                ForEach(["love", "faith", "hope", "peace", "strength", "wisdom"], id: \.self) { suggestion in
                                    Button(action: {
                                        viewModel.searchText = suggestion
                                        Task { await viewModel.searchVerses(query: suggestion) }
                                    }) {
                                        Text(suggestion)
                                            .font(.system(size: 14))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(
                                                Capsule()
                                                    .fill(Constants.DAMidBlue.opacity(0.1))
                                            )
                                            .foregroundColor(Constants.DAMidBlue)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 40)
                    }
                    Spacer()
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .background(
                Gradients().speakLifeCYOCell
                    .ignoresSafeArea(.all)
            )
        }
        .navigationViewStyle(.stack)
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            isSearchFocused = true
        }
    }
}

// MARK: - Search Result Card
struct SearchResultCard: View {
    let result: SearchResultDisplayModel
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(result.reference)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Constants.DAMidBlue)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Text(result.text)
                    .font(.system(size: 14, design: .serif))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.secondarySystemBackground))
            )
            .padding(.horizontal)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Flow Layout
struct BibleFlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.width ?? 0,
            spacing: spacing,
            subviews: subviews
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            spacing: spacing,
            subviews: subviews
        )
        
        for (index, size) in zip(result.indices, result.sizes) {
            let frame = CGRect(
                origin: result.positions[index],
                size: size
            )
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(size)
            )
        }
    }
    
    struct FlowResult {
        let indices: Range<Int>
        let sizes: [CGSize]
        let positions: [CGPoint]
        let size: CGSize
        
        init(in width: CGFloat, spacing: CGFloat, subviews: Subviews) {
            var sizes: [CGSize] = []
            var positions: [CGPoint] = []
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if currentX + size.width > width && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                positions.append(CGPoint(x: currentX, y: currentY))
                sizes.append(size)
                
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
            }
            
            self.indices = subviews.indices
            self.sizes = sizes
            self.positions = positions
            self.size = CGSize(width: width, height: currentY + lineHeight)
        }
    }
}
