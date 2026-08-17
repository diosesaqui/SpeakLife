//
//  BibleView.swift
//  SpeakLife
//
//  Created by SpeakLife Team on 1/28/26.
//

import SwiftUI

struct BibleView: View {
    @StateObject private var viewModel: BibleViewModel
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @State private var showSearch = false
    @State private var showBookmarks = false
    @State private var showSettings = false
    @State private var showAuthSheet = false
    @State private var selectedTab = 0
    @State private var showBibleChat = false

    /// `initialReference` (e.g. "John 3:16", from a chat answer) is handed to the
    /// view model so the initial load opens that passage directly.
    init(initialReference: String? = nil) {
        _viewModel = StateObject(wrappedValue: BibleViewModel(initialReference: initialReference))
    }

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
                            showBibleChat: $showBibleChat
                        )
                    }
                } else if viewModel.showChapterGrid {
                    BibleChapterGridView(viewModel: viewModel)
                } else if let chapter = viewModel.currentChapter {
                    BibleReaderView(viewModel: viewModel, chapter: chapter)
                        // Previous/Next keep the old chapter on screen while the
                        // new one loads, which looked like the buttons did
                        // nothing. Show that work is happening.
                        .overlay {
                            if viewModel.loadingChapterNumber != nil {
                                chapterLoadingOverlay
                            }
                        }
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
                            withAnimation(DS.Motion.smooth) {
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
                    HStack(spacing: DS.Spacing.md) {
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
            .sheet(isPresented: $showBibleChat) {
                // Sheets are a fresh environment context — forward
                // subscriptionStore or BibleChatView crashes reading it, and pin
                // the dark scheme so it doesn't render light.
                BibleChatView()
                    .environmentObject(subscriptionStore)
                    .preferredColorScheme(.dark)
            }
            .sheet(isPresented: $showSearch) {
                BibleSearchView(viewModel: viewModel)
                    .preferredColorScheme(.dark)
            }
            .sheet(isPresented: $showBookmarks) {
                BibleBookmarksView(viewModel: viewModel)
                    .preferredColorScheme(.dark)
            }
            .sheet(isPresented: $showSettings) {
                BibleSettingsView(viewModel: viewModel)
                    .preferredColorScheme(.dark)
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
                .preferredColorScheme(.dark)
            }
            .onChange(of: viewModel.isAuthenticated) { newValue in
                if newValue {
                    // Show a success banner or update UI
                }
                
            }
        }
        .navigationViewStyle(.stack)
        .navigationViewStyle(StackNavigationViewStyle())
        // The Bible feature is built for the app's forced-dark theme (verse text
        // uses .primary, backgrounds use systemBackground). When BibleView is
        // shown in a sheet it no longer inherits HomeView's dark scheme, so pin
        // it here or text renders black and headers render white.
        .preferredColorScheme(.dark)
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
    private var chapterLoadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()

            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.3)
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                        .fill(.regularMaterial)
                )
        }
        .transition(.opacity)
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
        VStack(spacing: DS.Spacing.lg) {
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
            
            VStack(spacing: DS.Spacing.sm) {
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
    @Binding var showBibleChat: Bool
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
                    BibleChatEntryCard {
                        Juice.play(.tapLight)
                        showBibleChat = true
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)

                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: DS.Spacing.md) {
                        ForEach(viewModel.testamentSections[selectedTestament].books) { book in
                            BookCardView(book: book) {
                                viewModel.selectBook(book)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
    }
}

// MARK: - Book Card View
struct BookCardView: View {
    let book: BookDisplayModel
    let action: () -> Void

    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                iconBadge

                Spacer(minLength: 0)

                Text(book.name)
                    .font(.system(size: 16, weight: .bold, design: .serif))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .minimumScaleFactor(0.7)
                    .fixedSize(horizontal: false, vertical: true)

                Text(book.chapterRange)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(book.accentColor)
            }
            .padding(DS.Spacing.sm)
            .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
            .background(cardBackground)
            .scaleEffect(pressed ? 0.97 : 1)
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { isPressing in
            withAnimation(.easeOut(duration: 0.12)) { pressed = isPressing }
        }, perform: {})
    }

    private var iconBadge: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [book.accentColor, book.accentColor.opacity(0.55)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 32, height: 32)
                .shadow(color: book.accentColor.opacity(0.55), radius: 6, x: 0, y: 3)
            Image(systemName: book.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        book.accentColor.opacity(0.28),
                        book.accentColor.opacity(0.08),
                        Color.black.opacity(0.35)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                book.accentColor.opacity(0.65),
                                book.accentColor.opacity(0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.1
                    )
            )
            .shadow(color: book.accentColor.opacity(0.30), radius: 14, x: 0, y: 7)
            .shadow(color: Color.black.opacity(0.40), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Chapter Grid View
struct BibleChapterGridView: View {
    @ObservedObject var viewModel: BibleViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            if let book = viewModel.selectedBook {
                // Book Header
                VStack(spacing: DS.Spacing.xs) {
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

                // A failed chapter keeps the grid on screen, so say so here and
                // offer the retry in place. Previously the only signal was an
                // alert, and a load that stalled gave no signal at all.
                if let failedChapter = viewModel.failedChapterNumber,
                   viewModel.loadingChapterNumber == nil {
                    ChapterLoadFailureBanner(
                        bookName: book.name,
                        chapterNumber: failedChapter
                    ) {
                        Task { await viewModel.retryFailedChapter() }
                    }
                }

                // Chapter Grid
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: DS.Spacing.md) {
                        ForEach(1...book.chapters, id: \.self) { chapterNumber in
                            ChapterNumberButton(
                                number: chapterNumber,
                                isSelected: viewModel.selectedChapterNumber == chapterNumber,
                                isLoading: viewModel.loadingChapterNumber == chapterNumber,
                                failed: viewModel.failedChapterNumber == chapterNumber
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

// MARK: - Chapter Load Failure Banner
struct ChapterLoadFailureBanner: View {
    let bookName: String
    let chapterNumber: Int
    let onRetry: () -> Void

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14))
                .foregroundColor(.orange)

            Text("Couldn't load \(bookName) \(chapterNumber).")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)

            Spacer(minLength: 0)

            Button(action: onRetry) {
                Text("Retry")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.blue))
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color.orange.opacity(0.12))
    }
}

// MARK: - Chapter Number Button
struct ChapterNumberButton: View {
    let number: Int
    let isSelected: Bool
    /// Swaps the number for a spinner while this chapter is being fetched, so a
    /// tap always produces visible feedback even on a slow network.
    var isLoading: Bool = false
    /// Marks the chapter whose last load failed, so it stays distinguishable
    /// from the ones that simply haven't been opened.
    var failed: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                } else {
                    Text("\(number)")
                        .font(.system(size: 18, weight: .medium, design: .serif))
                        .foregroundColor(isSelected ? .white : .primary)
                }
            }
            .frame(width: 50, height: 50)
            .background(
                Circle()
                    .fill(isSelected ? Color.blue : Color(UIColor.secondarySystemBackground))
                    .overlay(
                        Circle()
                            .stroke(strokeColor, lineWidth: isSelected ? 0 : 1)
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(accessibilityLabel)
    }

    private var strokeColor: Color {
        failed ? Color.orange.opacity(0.8) : Color.blue.opacity(0.3)
    }

    private var accessibilityLabel: String {
        if isLoading { return "Chapter \(number), loading" }
        if failed { return "Chapter \(number), failed to load, tap to retry" }
        return "Chapter \(number)"
    }
}

// MARK: - Bible Chat Entry Card
struct BibleChatEntryCard: View {
    let onTap: () -> Void
    @State private var shimmer = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Constants.DAMidBlue, Color(hex: "#9DA5FF")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 46, height: 46)
                    Image(systemName: "sparkles")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("Ask the Bible")
                            .font(.system(size: 16, weight: .bold, design: .serif))
                            .foregroundColor(.white)
                        Text("New")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundColor(.black)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Constants.gold))
                    }
                    Text("What does the Bible say about love, anxiety, money…")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Constants.DAMidBlue.opacity(0.32),
                                Color(hex: "#9DA5FF").opacity(0.14),
                                Color.black.opacity(0.30)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [Constants.DAMidBlue.opacity(0.75), Color(hex: "#9DA5FF").opacity(0.25)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 1.2
                            )
                    )
                    .shadow(color: Constants.DAMidBlue.opacity(0.45), radius: 16, x: 0, y: 8)
                    .shadow(color: Color.black.opacity(0.40), radius: 10, x: 0, y: 4)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Scale Button Style
//struct ScaleButtonStyle: ButtonStyle {
//    func makeBody(configuration: Configuration) -> some View {
//        configuration.label
//            .scaleEffect(configuration.isPressed ? 0.95 : 1)
//            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
//    }
//}
//
//#Preview {
//    BibleView()
//        .environmentObject(SubscriptionStore())
//}
