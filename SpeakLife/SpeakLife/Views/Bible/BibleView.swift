//
//  BibleView.swift
//  SpeakLife
//
//  Created by SpeakLife Team on 1/28/26.
//

import SwiftUI

struct BibleView: View {
    @StateObject private var viewModel = BibleViewModel()
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @State private var showSearch = false
    @State private var showBookmarks = false
    @State private var showSettings = false
    @State private var showAuthSheet = false
    @State private var selectedTab = 0
    @State private var showDailyVerseDetail = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                Gradients().speakLifeCYOCell
                    .ignoresSafeArea(.all)
                
                // Main content
                if viewModel.showBookSelection {
                    if viewModel.testamentSections.isEmpty && !viewModel.isLoading {
                        errorView
                    } else {
                        BibleBookSelectionView(
                            viewModel: viewModel,
                            showDailyVerseDetail: $showDailyVerseDetail
                        )
                    }
                } else if viewModel.showChapterGrid {
                    BibleChapterGridView(viewModel: viewModel)
                } else if let chapter = viewModel.currentChapter {
                    BibleReaderView(viewModel: viewModel, chapter: chapter)
                } else if viewModel.showError && !viewModel.isLoading {
                    errorView
                } else {
                    loadingView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !viewModel.showBookSelection {
                        Button(action: {
                            withAnimation(.spring()) {
                                if viewModel.currentChapter != nil {
                                    viewModel.backToChapters()
                                } else {
                                    viewModel.backToBooks()
                                }
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 16, weight: .semibold))
                                Text(viewModel.currentChapter != nil ? "Chapters" : "Books")
                                    .font(.system(size: 16))
                            }
                            .foregroundColor(.primary)
                        }
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    Text("Bible")
                        .font(.system(size: 18, weight: .bold, design: .serif))
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        // Auth status indicator
                        if !viewModel.isAuthenticated {
                            Button(action: { viewModel.showAuthView = true }) {
                                Image(systemName: "person.crop.circle.badge.exclamationmark")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.orange)
                            }
                        }
                        
                        Button(action: { showSearch.toggle() }) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 16, weight: .medium))
                        }
                        
                        Menu {
                            if !viewModel.isAuthenticated {
                                Button(action: { viewModel.showAuthView = true }) {
                                    Label("Sign In for Unlimited Access", systemImage: "person.crop.circle.badge.plus")
                                }
                                
                                Divider()
                            }
                            
                            Button(action: { showBookmarks.toggle() }) {
                                Label("Bookmarks", systemImage: "bookmark.fill")
                            }
                            
                            Button(action: {
                                Task { 
                                    await viewModel.loadDailyVerse()
                                    if viewModel.dailyVerse != nil {
                                        showDailyVerseDetail = true
                                    }
                                }
                            }) {
                                Label("Daily Verse", systemImage: "quote.bubble.fill")
                            }
                            
                            Divider()
                            
                            Button(action: { showSettings.toggle() }) {
                                Label("Settings", systemImage: "gearshape")
                            }
                            
                            if viewModel.isAuthenticated {
                                Divider()
                                
                                Button(action: { viewModel.signOut() }) {
                                    Label("Sign Out", systemImage: "person.crop.circle.badge.minus")
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 16, weight: .medium))
                        }
                    }
                }
            }
            .sheet(isPresented: $showSearch) {
                BibleSearchView(viewModel: viewModel)
            }
            .sheet(isPresented: $showBookmarks) {
                BibleBookmarksView(viewModel: viewModel)
            }
            .sheet(isPresented: $showSettings) {
                BibleSettingsView(viewModel: viewModel)
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") { viewModel.showError = false }
            } message: {
                Text(viewModel.errorMessage ?? "An error occurred")
            }
            .sheet(isPresented: $viewModel.showAuthView) {
                BibleAuthenticationView(
                    onSuccess: {
                        viewModel.handleAuthenticationSuccess()
                    },
                    onDismiss: {
                        viewModel.showAuthView = false
                    }
                )
            }
            .sheet(isPresented: $showDailyVerseDetail) {
                if let dailyVerse = viewModel.dailyVerse {
                    DailyVerseDetailView(verse: dailyVerse)
                } else {
                    // Loading view while verse is being fetched
                    NavigationView {
                        VStack(spacing: 20) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(1.5)
                            
                            Text("Loading Daily Verse...")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .navigationTitle("Daily Verse")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Cancel") {
                                    showDailyVerseDetail = false
                                }
                            }
                        }
                    }
                    .onAppear {
                        Task {
                            await viewModel.loadDailyVerse()
                            if viewModel.dailyVerse == nil {
                                // If still no verse after loading, dismiss
                                showDailyVerseDetail = false
                            }
                        }
                    }
                }
            }
            .onChange(of: viewModel.isAuthenticated) { newValue in
                if newValue {
                    // Show a success banner or update UI
                }
                
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            // Make navigation bar transparent to show gradient
            let appearance = UINavigationBarAppearance()
            appearance.configureWithTransparentBackground()
            appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
            appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
            
            UINavigationBar.appearance().standardAppearance = appearance
            UINavigationBar.appearance().compactAppearance = appearance
            UINavigationBar.appearance().scrollEdgeAppearance = appearance
        }
    }
    
    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.5)
            
            Text("Loading Bible...")
                .font(.system(size: 16, weight: .medium, design: .serif))
                .foregroundColor(.secondary)
        }
    }
    
    @ViewBuilder
    private var errorView: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("Unable to Load Bible")
                .font(.title2.bold())
            
            Text(viewModel.errorMessage ?? "We couldn't load the Bible content. Please check your internet connection and try again.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            VStack(spacing: 12) {
                Button(action: {
                    Task {
                        viewModel.showError = false
                        await viewModel.loadBooks()
                    }
                }) {
                    Text("Try Again")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(width: 140, height: 44)
                        .background(Color.blue)
                        .cornerRadius(22)
                }
                
                if !viewModel.isAuthenticated {
                    Button(action: {
                        viewModel.showAuthView = true
                    }) {
                        Text("Sign In")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Book Selection View
struct BibleBookSelectionView: View {
    @ObservedObject var viewModel: BibleViewModel
    @Binding var showDailyVerseDetail: Bool
    @State private var selectedTestament = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Testament Picker
            Picker("Testament", selection: $selectedTestament) {
                ForEach(0..<viewModel.testamentSections.count, id: \.self) { index in
                    Text(viewModel.testamentSections[index].name)
                        .tag(index)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            .background(Color(UIColor.systemBackground))
            
            if viewModel.isLoading {
                Spacer()
                ProgressView("Loading books...")
                    .progressViewStyle(CircularProgressViewStyle())
                Spacer()
            } else if !viewModel.testamentSections.isEmpty {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        ForEach(viewModel.testamentSections[selectedTestament].books) { book in
                            BookCardView(book: book) {
                                viewModel.selectBook(book)
                            }
                        }
                    }
                    .padding()
                }
            }
            
            // Daily Verse Card
            if let dailyVerse = viewModel.dailyVerse {
                DailyVerseCard(verse: dailyVerse) {
                    showDailyVerseDetail = true
                }
                .padding()
            }
        }
    }
}

// MARK: - Book Card View
struct BookCardView: View {
    let book: BookDisplayModel
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: book.icon)
                    .font(.system(size: 24))
                    .foregroundColor(book.testamentColor)
                
                Text(book.abbreviation)
                    .font(.system(size: 14, weight: .bold, design: .serif))
                    .foregroundColor(.primary)
                
                Text(book.name)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)
                
                Text(book.chapterRange)
                    .font(.system(size: 9))
                   // .foregroundColor(.tertiary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(book.testamentColor.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Chapter Grid View
struct BibleChapterGridView: View {
    @ObservedObject var viewModel: BibleViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            if let book = viewModel.selectedBook {
                // Book Header
                VStack(spacing: 8) {
                    Text(book.name)
                        .font(.system(size: 24, weight: .bold, design: .serif))
                    
                    Text("by \(book.author)")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    
                    Text("\(book.chapters) Chapters")
                        .font(.system(size: 12))
                       // .foregroundColor(.tertiary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(UIColor.systemBackground))
                
                Divider()
                
                // Chapter Grid
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        ForEach(1...book.chapters, id: \.self) { chapterNumber in
                            ChapterNumberButton(
                                number: chapterNumber,
                                isSelected: viewModel.selectedChapterNumber == chapterNumber
                            ) {
                                Task {
                                    await viewModel.selectChapter(chapterNumber)
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
        }
    }
}

// MARK: - Chapter Number Button
struct ChapterNumberButton: View {
    let number: Int
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text("\(number)")
                .font(.system(size: 18, weight: .medium, design: .serif))
                .foregroundColor(isSelected ? .white : .primary)
                .frame(width: 50, height: 50)
                .background(
                    Circle()
                        .fill(isSelected ? Color.blue : Color(UIColor.secondarySystemBackground))
                        .overlay(
                            Circle()
                                .stroke(Color.blue.opacity(0.3), lineWidth: isSelected ? 0 : 1)
                        )
                )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Daily Verse Card
struct DailyVerseCard: View {
    let verse: RandomVerse
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "quote.bubble.fill")
                        .foregroundColor(Constants.DAMidBlue)
                    Text("Verse of the Day")
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Text(verse.text)
                    .font(.system(size: 14, design: .serif))
                    .foregroundColor(.primary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                
                Text("\(verse.book.name) \(verse.chapter):\(verse.number)")
                    .font(.system(size: 12))
                    .foregroundColor(Constants.DAMidBlue)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Constants.DAMidBlue.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Scale Button Style
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

#Preview {
    BibleView()
        .environmentObject(SubscriptionStore())
}
