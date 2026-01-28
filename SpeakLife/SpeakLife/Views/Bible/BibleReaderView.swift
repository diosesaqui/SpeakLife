//
//  BibleReaderView.swift
//  SpeakLife
//
//  Created by SpeakLife Team on 1/28/26.
//

import SwiftUI

struct BibleReaderView: View {
    @ObservedObject var viewModel: BibleViewModel
    let chapter: ChapterDisplayModel
    
    @State private var fontSize: CGFloat = 18
    @State private var selectedVerse: VerseDisplayModel?
    @State private var showVerseActions = false
    @State private var loadError = false
    @AppStorage("BibleReaderFont") private var selectedFont = "Georgia"
    @AppStorage("BibleLineSpacing") private var lineSpacing: Double = 8
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Chapter Header
                    VStack(spacing: 8) {
                        Text(chapter.bookName)
                            .font(.system(size: 24, weight: .bold, design: .serif))
                        
                        Text("Chapter \(chapter.chapterNumber)")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Divider()
                            .padding(.top, 8)
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    
                    // Verses
                    VStack(alignment: .leading, spacing: lineSpacing) {
                        ForEach(chapter.verses) { verse in
                            VerseView(
                                verse: verse,
                                fontSize: fontSize,
                                fontName: selectedFont,
                                onTap: {
                                    selectedVerse = verse
                                    showVerseActions = true
                                }
                            )
                            .id(verse.id)
                        }
                    }
                    .padding()
                    
                    // Chapter Navigation
                    HStack {
                        if chapter.previousChapter != nil {
                            Button(action: {
                                Task { await viewModel.navigateToPreviousChapter() }
                            }) {
                                HStack {
                                    Image(systemName: "chevron.left")
                                    Text("Previous")
                                }
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.blue)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(Color.blue.opacity(0.1))
                                )
                            }
                        }
                        
                        Spacer()
                        
                        if chapter.nextChapter != nil {
                            Button(action: {
                                Task { await viewModel.navigateToNextChapter() }
                            }) {
                                HStack {
                                    Text("Next")
                                    Image(systemName: "chevron.right")
                                }
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.blue)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(Color.blue.opacity(0.1))
                                )
                            }
                        }
                    }
                    .padding()
                    .padding(.bottom, 20)
                }
            }
        }
        .overlay(alignment: .bottom) {
            ReaderControlsView(
                fontSize: $fontSize,
                fontName: $selectedFont,
                lineSpacing: $lineSpacing
            )
        }
        .sheet(isPresented: $showVerseActions) {
            if let verse = selectedVerse {
                VerseActionsSheet(
                    verse: verse,
                    viewModel: viewModel,
                    isPresented: $showVerseActions
                )
                .presentationDetents([.medium])
            }
        }
    }
}

// MARK: - Verse View
struct VerseView: View {
    let verse: VerseDisplayModel
    let fontSize: CGFloat
    let fontName: String
    let onTap: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Verse Number
            Text("\(verse.number)")
                .font(.custom(fontName, size: fontSize * 0.7))
                .foregroundColor(.secondary)
                .frame(minWidth: 30, alignment: .trailing)
            
            // Verse Text
            Text(verse.text)
                .font(.custom(fontName, size: fontSize))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .background(
                    verse.highlightColor ?? Color.clear
                )
                .cornerRadius(4)
                .overlay(alignment: .topTrailing) {
                    if verse.isBookmarked {
                        Image(systemName: "bookmark.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.blue)
                            .offset(x: 20, y: -5)
                    }
                }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - Reader Controls
struct ReaderControlsView: View {
    @Binding var fontSize: CGFloat
    @Binding var fontName: String
    @Binding var lineSpacing: Double
    @State private var showControls = false
    
    let availableFonts = ["Georgia", "Helvetica", "Times New Roman", "Palatino", "Baskerville"]
    
    var body: some View {
        VStack(spacing: 0) {
            if showControls {
                VStack(spacing: 16) {
                    // Font Size Control
                    HStack {
                        Text("Text Size")
                            .font(.system(size: 14, weight: .medium))
                        
                        Spacer()
                        
                        HStack(spacing: 20) {
                            Button(action: { 
                                fontSize = max(12, fontSize - 2)
                            }) {
                                Image(systemName: "textformat.size.smaller")
                                    .font(.system(size: 16))
                            }
                            
                            Text("\(Int(fontSize))")
                                .font(.system(size: 14))
                                .frame(width: 30)
                            
                            Button(action: { 
                                fontSize = min(32, fontSize + 2)
                            }) {
                                Image(systemName: "textformat.size.larger")
                                    .font(.system(size: 16))
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Font Selection
                    HStack {
                        Text("Font")
                            .font(.system(size: 14, weight: .medium))
                        
                        Spacer()
                        
                        Menu {
                            ForEach(availableFonts, id: \.self) { font in
                                Button(action: { fontName = font }) {
                                    HStack {
                                        Text(font)
                                            .font(.custom(font, size: 14))
                                        if font == fontName {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            Text(fontName)
                                .font(.custom(fontName, size: 14))
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Divider()
                    
                    // Line Spacing
                    HStack {
                        Text("Line Spacing")
                            .font(.system(size: 14, weight: .medium))
                        
                        Slider(value: $lineSpacing, in: 4...16)
                            .padding(.horizontal)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.regularMaterial)
                )
                .padding()
            }
            
            // Toggle Button
            Button(action: { 
                withAnimation(.spring()) {
                    showControls.toggle()
                }
            }) {
                Image(systemName: showControls ? "chevron.down.circle.fill" : "textformat")
                    .font(.system(size: 20))
                    .foregroundColor(.primary)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(.regularMaterial)
                    )
            }
            .padding(.bottom, 8)
        }
    }
}

// MARK: - Verse Actions Sheet
struct VerseActionsSheet: View {
    let verse: VerseDisplayModel
    @ObservedObject var viewModel: BibleViewModel
    @Binding var isPresented: Bool
    
    let highlightColors: [BibleHighlight.HighlightColor] = [.yellow, .blue, .green, .pink, .purple]
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                // Verse Preview
                VStack(alignment: .leading, spacing: 8) {
                    Text(verse.reference)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    Text(verse.text)
                        .font(.system(size: 16, design: .serif))
                        .lineLimit(4)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(UIColor.secondarySystemBackground))
                )
                
                // Actions
                VStack(spacing: 16) {
                    // Bookmark Toggle
                    Button(action: {
                        viewModel.toggleBookmark(for: verse)
                        isPresented = false
                    }) {
                        HStack {
                            Image(systemName: verse.isBookmarked ? "bookmark.fill" : "bookmark")
                            Text(verse.isBookmarked ? "Remove Bookmark" : "Add Bookmark")
                            Spacer()
                        }
                        .foregroundColor(.primary)
                        .padding(.vertical, 12)
                    }
                    
                    Divider()
                    
                    // Highlight Options
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Highlight")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 12) {
                            ForEach(highlightColors, id: \.self) { color in
                                Button(action: {
                                    viewModel.toggleHighlight(for: verse, color: color)
                                    isPresented = false
                                }) {
                                    Circle()
                                        .fill(Color(hex: color.hexValue))
                                        .frame(width: 36, height: 36)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                                        )
                                }
                            }
                            
                            if verse.highlightColor != nil {
                                Spacer()
                                Button(action: {
                                    viewModel.removeHighlight(for: verse)
                                    isPresented = false
                                }) {
                                    Text("Remove")
                                        .font(.system(size: 14))
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Share
                    Button(action: {
                        viewModel.shareVerse(verse)
                        isPresented = false
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share")
                            Spacer()
                        }
                        .foregroundColor(.primary)
                        .padding(.vertical, 12)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Verse Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}