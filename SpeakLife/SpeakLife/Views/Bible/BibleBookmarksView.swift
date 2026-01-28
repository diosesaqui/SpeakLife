//
//  BibleBookmarksView.swift
//  SpeakLife
//
//  Created by SpeakLife Team on 1/28/26.
//

import SwiftUI

struct BibleBookmarksView: View {
    @ObservedObject var viewModel: BibleViewModel
    @Environment(\.dismiss) var dismiss
    @State private var selectedBookmark: BibleBookmark?
    
    var body: some View {
        NavigationView {
            ZStack {
                Gradients().speakLifeCYOCell
                    .ignoresSafeArea(.all)
                
                Group {
                    if viewModel.bookmarks.isEmpty {
                        emptyStateView
                    } else {
                        bookmarksList
                    }
                }
                .navigationTitle("Bookmarks")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "bookmark")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.8))
            
            VStack(spacing: 8) {
                Text("No Bookmarks Yet")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                
                Text("Tap and hold any verse to bookmark it")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .padding()
    }
    
    private var bookmarksList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.bookmarks) { bookmark in
                    BookmarkCard(
                        bookmark: bookmark,
                        onTap: {
                            Task {
                                await viewModel.loadChapter(
                                    bookAbbrev: bookmark.bookAbbrev,
                                    chapterNumber: bookmark.chapter
                                )
                                dismiss()
                            }
                        },
                        onDelete: {
                            viewModel.removeBookmark(bookmark)
                        }
                    )
                }
            }
            .padding()
        }
    }
}

// MARK: - Bookmark Card
struct BookmarkCard: View {
    let bookmark: BibleBookmark
    let onTap: () -> Void
    let onDelete: () -> Void
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(bookmark.bookName) \(bookmark.chapter):\(bookmark.verseNumber)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Constants.DAMidBlue)
                        
                        Text(formattedDate)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        showDeleteConfirmation = true
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                    }
                }
                
                Text(bookmark.verseText)
                    .font(.system(size: 14, design: .serif))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                
                if let note = bookmark.note, !note.isEmpty {
                    Text(note)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.8))
                        .italic()
                        .lineLimit(2)
                        .padding(.top, 4)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.secondarySystemBackground))
            )
        }
        .buttonStyle(PlainButtonStyle())
        .confirmationDialog(
            "Remove Bookmark?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This bookmark will be permanently deleted.")
        }
    }
    
    private var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: bookmark.dateAdded, relativeTo: Date())
    }
}

// MARK: - Bible Settings View
struct BibleSettingsView: View {
    @ObservedObject var viewModel: BibleViewModel
    @Environment(\.dismiss) var dismiss
    @AppStorage("BibleShowVerseNumbers") private var showVerseNumbers = true
    @State private var cacheSize = "Calculating..."
    
    var body: some View {
        NavigationView {
            Form {
                Section("Reading Preferences") {
                    Toggle("Show Verse Numbers", isOn: $showVerseNumbers)
                }
                
                Section("Bible Version") {
                    if viewModel.availableVersions.isEmpty {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Loading versions...")
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(.vertical, 4)
                    } else {
                        ForEach(viewModel.availableVersions) { version in
                            BibleVersionRow(
                                version: version,
                                isSelected: version.version == viewModel.selectedVersion
                            ) {
                                Task { 
                                    await viewModel.changeVersion(version.version)
                                }
                            }
                        }
                    }
                }
                
                Section("Reading History") {
                    if !viewModel.readingHistory.isEmpty {
                        ForEach(viewModel.readingHistory.prefix(5)) { entry in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(entry.reference)
                                        .font(.system(size: 14, weight: .medium))
                                    Text(entry.timeAgo)
                                        .font(.system(size: 12))
                                        .foregroundColor(.white.opacity(0.8))
                                }
                                Spacer()
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                Task {
                                    await viewModel.continueReading(
                                        book: entry.bookAbbrev,
                                        chapter: entry.chapter
                                    )
                                    dismiss()
                                }
                            }
                        }
                    } else {
                        Text("No reading history yet")
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                
                Section("Storage") {
                    HStack {
                        Text("Cache Size")
                        Spacer()
                        Text(cacheSize)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Button(action: {
                        viewModel.clearCache()
                        cacheSize = "0 KB"
                    }) {
                        Text("Clear Cache")
                            .foregroundColor(.red)
                    }
                }
                
                Section("About") {
                    HStack {
                        Text("Bible API")
                        Spacer()
                        Text("aBibliaDigital")
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
            .navigationTitle("Bible Settings")
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
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            cacheSize = viewModel.getCacheSizeFormatted()
        }
    }
}

// MARK: - Bible Version Row
struct BibleVersionRow: View {
    let version: BibleVersion
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(version.displayName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
//                    if let description = version.description, !description.isEmpty {
//                        Text(description)
//                            .font(.system(size: 13))
//                            .foregroundColor(.secondary)
//                            .lineLimit(2)
//                            .frame(maxWidth: .infinity, alignment: .leading)
//                    } else {
                        Text(version.version.uppercased())
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Constants.DAMidBlue.opacity(0.8))
                            .frame(maxWidth: .infinity, alignment: .leading)
                //    }
                }
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Constants.DAMidBlue)
                } else {
                    Circle()
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        .frame(width: 20, height: 20)
                }
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}
