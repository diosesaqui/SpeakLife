//
//  PrayerWallView.swift
//  SpeakLife
//
//  Community Prayer Wall — browse community prayer requests, pray for others,
//  post your own requests (requires Apple Sign In), and track answered prayers.
//

import SwiftUI
import FirebaseFirestore
import AuthenticationServices

// MARK: - PrayerWallView

struct PrayerWallView: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @StateObject private var viewModel = PrayerWallViewModel()
    @ObservedObject private var appleSignIn = AppleSignInService.shared

    @State private var selectedTab: PrayerTab = .wall
    @State private var showPostForm = false
    @State private var showSignInPrompt = false

    enum PrayerTab { case wall, mine }

    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Image(subscriptionStore.onboardingBGImage)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()

                Color.black.opacity(0.50)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    segmentedControl
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 12)

                    if selectedTab == .wall {
                        categoryFilterBar
                            .padding(.bottom, 8)
                    }

                    if viewModel.isLoading && currentPosts.isEmpty {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.4)
                        Spacer()
                    } else if currentPosts.isEmpty {
                        ScrollView {
                            emptyState
                                .frame(maxWidth: .infinity)
                        }
                        .refreshable { viewModel.refresh() }
                    } else {
                        postList
                    }
                }
            }
            .navigationTitle("Warrior Room")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        if appleSignIn.isSignedIn {
                            showPostForm = true
                        } else {
                            showSignInPrompt = true
                        }
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .foregroundColor(.white)
                            .font(.system(size: 18, weight: .medium))
                    }
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .navigationViewStyle(.stack)
        .sheet(isPresented: $showPostForm) {
            PostPrayerView(viewModel: viewModel)
                .environmentObject(subscriptionStore)
        }
        .sheet(isPresented: $showSignInPrompt) {
            AppleSignInPromptView(appleSignIn: appleSignIn)
                .environmentObject(subscriptionStore)
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .onAppear {
            // Only reset-fetch if no live network fetch has completed yet.
            // Prevents sheet dismissals (PostPrayerView, AppleSignInPromptView)
            // from resetting the pagination cursor and causing Load More
            // to re-fetch already-seen pages.
            if !viewModel.hasFetchedFromNetwork {
                viewModel.fetchPosts(reset: true)
            }
            viewModel.fetchMyPosts()
            if appleSignIn.isSignedIn {
                viewModel.registerForPrayerWallNotifications(
                    uid: appleSignIn.uid,
                    fcmToken: UserDefaults.standard.string(forKey: "fcmToken") ?? ""
                )
            }
        }
    }

    // MARK: - Segmented Control

    private var segmentedControl: some View {
        HStack(spacing: 0) {
            tabButton("Warrior Room", tab: .wall)
            tabButton("My Prayers", tab: .mine)
        }
        .background(Color.white.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func tabButton(_ title: String, tab: PrayerTab) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab }
        } label: {
            Text(title)
                .font(Font.custom("AppleSDGothicNeo-Regular", size: 14, relativeTo: .body))
                .foregroundColor(selectedTab == tab ? .black : .white.opacity(0.7))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(
                    selectedTab == tab
                        ? Color.white
                        : Color.clear
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - Post List

    private var currentPosts: [PrayerWallPost] {
        selectedTab == .wall ? viewModel.filteredPosts : viewModel.myPosts
    }

    // MARK: - Category Filter Bar

    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterPill(label: "All",
                           isSelected: viewModel.categoryFilter == nil) {
                    viewModel.categoryFilter = nil
                }
                ForEach(WarriorRoomCategory.allCases) { category in
                    filterPill(
                        label: "\(category.emoji) \(category.label)",
                        isSelected: viewModel.categoryFilter == category
                    ) {
                        viewModel.categoryFilter = category
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func filterPill(label: String,
                            isSelected: Bool,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(Font.custom("AppleSDGothicNeo-Regular", size: 13, relativeTo: .body))
                .foregroundColor(isSelected ? .white : .white.opacity(0.7))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(isSelected ? Color(hex: "7C3AED") : Color.white.opacity(0.12))
                )
        }
    }

    private var postList: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                ForEach(currentPosts) { post in
                    PrayerPostCard(
                        post: post,
                        isMyPost: selectedTab == .mine,
                        viewModel: viewModel
                    )
                }

                // Load more / end-of-feed (wall tab, no active filter only —
                // pagination is server-side chronological and isn't filterable here)
                if selectedTab == .wall && viewModel.categoryFilter == nil && !viewModel.posts.isEmpty {
                    if viewModel.hasMore {
                        Button {
                            viewModel.fetchPosts(reset: false)
                        } label: {
                            if viewModel.isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text("Load more…")
                                    .font(Font.custom("AppleSDGothicNeo-Regular", size: 14, relativeTo: .body))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                        .disabled(viewModel.isLoading)
                        .padding(.vertical, 16)
                    } else {
                        // End of feed
                        VStack(spacing: 6) {
                            Text("🙏")
                                .font(.title2)
                            Text("You're all caught up")
                                .font(Font.custom("AppleSDGothicNeo-Regular", size: 13, relativeTo: .body))
                                .foregroundColor(.white.opacity(0.4))
                        }
                        .padding(.vertical, 20)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 4)
            .padding(.bottom, 30)
        }
        .refreshable {
            viewModel.refresh()
        }
    }

    // MARK: - Empty State

    private var emptyStateMessage: String {
        if selectedTab == .mine {
            return "You haven't declared anything yet.\nTake your ground."
        }
        if let filter = viewModel.categoryFilter {
            return "No declarations in \(filter.label) yet.\nBe the first to take this ground."
        }
        return "No declarations yet. Be the first to take ground.\nThis room rises with you."
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "hands.and.sparkles.fill")
                .font(.system(size: 48))
                .foregroundColor(Color(hex: "A78BFA").opacity(0.7))
            Text(emptyStateMessage)
                .font(Font.custom("AppleSDGothicNeo-Regular", size: 16, relativeTo: .body))
                .foregroundColor(.white.opacity(0.65))
                .multilineTextAlignment(.center)
                .italic()
                .padding(.horizontal, 40)
            Spacer()
        }
    }
}

// MARK: - PrayerPostCard

struct PrayerPostCard: View {
    let post: PrayerWallPost
    let isMyPost: Bool
    @ObservedObject var viewModel: PrayerWallViewModel
    @ObservedObject private var appleSignIn = AppleSignInService.shared

    @State private var showReportAlert = false
    @State private var showAnsweredGlow = false
    @State private var isAgreementsExpanded = false
    @State private var pendingAgreementReaction: WarriorRoomReaction?
    @State private var showAgreementSheet = false

    private var postId: String { post.id ?? "" }
    private var agreements: [Agreement] { viewModel.agreementsByPost[postId] ?? [] }
    private var agreementsLoading: Bool { viewModel.loadingAgreementsForPost.contains(postId) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Category pill (top)
            if let category = post.categoryEnum {
                categoryPill(category)
            }

            // Header row
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(post.displayName)
                        .font(Font.custom("AppleSDGothicNeo-Regular", size: 12, relativeTo: .caption))
                        .foregroundColor(.white.opacity(0.5))
                        .italic()

                    if post.isAnswered {
                        Label("Answered ✓", systemImage: "checkmark.seal.fill")
                            .font(Font.custom("AppleSDGothicNeo-Regular", size: 11, relativeTo: .caption2))
                            .foregroundColor(Color(hex: "FBBF24"))
                    }
                }

                Spacer()

                Text(timeAgo(from: post.timestamp))
                    .font(Font.custom("AppleSDGothicNeo-Regular", size: 11, relativeTo: .caption2))
                    .foregroundColor(.white.opacity(0.35))
            }

            // Declaration text
            Text(post.text)
                .font(Font.custom("AppleSDGothicNeo-Regular", size: 15, relativeTo: .body))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)

            // Reaction row
            reactionRow

            // Reaction summary
            if post.totalReactions > 0 {
                reactionSummaryRow
            }

            // Agreement chain
            agreementChainRow

            // Footer actions: Mark as Answered (own posts) + Report (community)
            HStack(spacing: 14) {
                if isMyPost && !post.isAnswered {
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                            showAnsweredGlow = true
                        }
                        viewModel.markAsAnswered(post)
                    } label: {
                        Text("Mark as Answered ✓")
                            .font(Font.custom("AppleSDGothicNeo-Regular", size: 12, relativeTo: .caption))
                            .foregroundColor(Color(hex: "FBBF24"))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color(hex: "FBBF24").opacity(0.6), lineWidth: 1)
                            )
                    }
                }

                Spacer()

                if !isMyPost {
                    Button {
                        showReportAlert = true
                    } label: {
                        Image(systemName: "flag")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.3))
                    }
                    .alert("Report this declaration?", isPresented: $showReportAlert) {
                        Button("Report", role: .destructive) {
                            viewModel.reportPost(post)
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("Flag this post if it's inappropriate or spam.")
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(showAnsweredGlow ? 0.22 : 0.12))
                .shadow(color: showAnsweredGlow ? Color(hex: "FBBF24").opacity(0.45) : .clear, radius: 12)
        )
        .animation(.easeOut(duration: 0.6), value: showAnsweredGlow)
        .sheet(isPresented: $showAgreementSheet) {
            if let reaction = pendingAgreementReaction {
                AgreementPromptSheet(
                    post: post,
                    reaction: reaction,
                    viewModel: viewModel
                )
                .presentationDetentsCompat()
            }
        }
    }

    // MARK: - Subviews

    private func categoryPill(_ category: WarriorRoomCategory) -> some View {
        HStack(spacing: 4) {
            Text(category.emoji)
            Text(category.label)
        }
        .font(Font.custom("AppleSDGothicNeo-Regular", size: 11, relativeTo: .caption))
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.18))
        )
    }

    private var reactionRow: some View {
        HStack(spacing: 8) {
            ForEach(WarriorRoomReaction.allCases) { reaction in
                reactionButton(reaction)
            }
            Spacer(minLength: 0)
        }
    }

    private func reactionButton(_ reaction: WarriorRoomReaction) -> some View {
        let isSelected = viewModel.reaction(for: post) == reaction
        let count = post.count(for: reaction)
        return Button {
            handleReactionTap(reaction)
        } label: {
            HStack(spacing: 4) {
                Text(reaction.emoji)
                    .font(.system(size: 13))
                if count > 0 {
                    Text("\(count)")
                        .font(Font.custom("AppleSDGothicNeo-Regular", size: 12, relativeTo: .caption))
                }
            }
            .foregroundColor(isSelected ? .white : .white.opacity(0.85))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isSelected ? Color(hex: "7C3AED") : Color.white.opacity(0.10))
            )
        }
    }

    private func handleReactionTap(_ reaction: WarriorRoomReaction) {
        let priorReaction = viewModel.reaction(for: post)
        viewModel.toggleReaction(reaction, on: post)

        // Only prompt for an agreement when this is a NEW reaction selection
        // (not toggle-off, not switching), the user is signed in, and they
        // haven't already added an agreement to this post.
        let didAddNewReaction = priorReaction == nil
        guard didAddNewReaction,
              appleSignIn.isSignedIn,
              !viewModel.hasAgreed(on: post) else { return }
        pendingAgreementReaction = reaction
        showAgreementSheet = true
    }

    private var reactionSummaryRow: some View {
        let top = post.topReactions.prefix(2).map { $0.reaction.emoji }.joined()
        let total = post.totalReactions
        let suffix = total == 1
            ? "1 believer standing with you"
            : "\(total) believers standing with this declaration"
        return HStack(spacing: 6) {
            if !top.isEmpty {
                Text(top)
                    .font(.system(size: 13))
            }
            Text(suffix)
                .font(Font.custom("AppleSDGothicNeo-Regular", size: 12, relativeTo: .caption))
                .foregroundColor(.white.opacity(0.55))
        }
    }

    @ViewBuilder
    private var agreementChainRow: some View {
        let count = agreements.count
        let title: String = {
            if count > 0 {
                return count == 1
                    ? "1 declaration of agreement"
                    : "\(count) declarations of agreement"
            }
            return "View declarations of agreement"
        }()

        VStack(alignment: .leading, spacing: 6) {
            Button {
                if !isAgreementsExpanded && agreements.isEmpty {
                    viewModel.loadAgreements(for: post)
                }
                withAnimation(.easeInOut(duration: 0.2)) {
                    isAgreementsExpanded.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Text(title)
                        .font(Font.custom("AppleSDGothicNeo-Regular", size: 12, relativeTo: .caption))
                        .foregroundColor(.white.opacity(0.55))
                    Image(systemName: isAgreementsExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.45))
                }
            }

            if isAgreementsExpanded {
                if agreementsLoading && agreements.isEmpty {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white.opacity(0.5)))
                        .scaleEffect(0.8)
                } else if agreements.isEmpty {
                    Text("Be the first to declare in agreement.")
                        .font(Font.custom("AppleSDGothicNeo-Regular", size: 12, relativeTo: .caption))
                        .foregroundColor(.white.opacity(0.4))
                        .italic()
                } else {
                    let preview = Array(agreements.prefix(3))
                    ForEach(preview) { agreement in
                        AgreementRow(agreement: agreement)
                    }
                    if agreements.count > 3 {
                        Text("+ \(agreements.count - 3) more")
                            .font(Font.custom("AppleSDGothicNeo-Regular", size: 11, relativeTo: .caption2))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
            }
        }
    }

    // MARK: - Time Ago Helper

    private func timeAgo(from timestamp: Timestamp) -> String {
        let seconds = Date().timeIntervalSince(timestamp.dateValue())
        switch seconds {
        case ..<60:            return "just now"
        case ..<3600:          return "\(Int(seconds / 60))m ago"
        case ..<86400:         return "\(Int(seconds / 3600))h ago"
        case ..<604800:        return "\(Int(seconds / 86400))d ago"
        default:
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: timestamp.dateValue())
        }
    }
}

// MARK: - AgreementRow

private struct AgreementRow: View {
    let agreement: Agreement

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text(agreement.reaction?.emoji ?? "🔥")
                .font(.system(size: 12))
            (Text(agreement.displayName + ": ").foregroundColor(.white.opacity(0.55))
                + Text(agreement.text).foregroundColor(.white.opacity(0.85)))
                .font(Font.custom("AppleSDGothicNeo-Regular", size: 12, relativeTo: .caption))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - AgreementPromptSheet

private struct AgreementPromptSheet: View {
    let post: PrayerWallPost
    let reaction: WarriorRoomReaction
    @ObservedObject var viewModel: PrayerWallViewModel
    @ObservedObject private var appleSignIn = AppleSignInService.shared
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @Environment(\.dismiss) private var dismiss

    @State private var text: String = ""

    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canDeclare: Bool { !trimmed.isEmpty }
    private var remaining: Int { Agreement.maxLength - text.count }

    var body: some View {
        VStack(spacing: 18) {
            Capsule()
                .fill(Color.white.opacity(0.25))
                .frame(width: 40, height: 4)
                .padding(.top, 10)

            Text("Add your declaration over this?")
                .font(Font.custom("AppleSDGothicNeo-Bold", size: 18, relativeTo: .title3))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            HStack(spacing: 6) {
                Text(reaction.emoji)
                Text(reaction.label)
                    .font(Font.custom("AppleSDGothicNeo-Regular", size: 13, relativeTo: .body))
                    .foregroundColor(.white.opacity(0.7))
            }

            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(reaction.declarationPlaceholder)
                        .font(Font.custom("AppleSDGothicNeo-Regular", size: 14, relativeTo: .body))
                        .foregroundColor(.white.opacity(0.35))
                        .padding(.top, 12)
                        .padding(.leading, 14)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $text)
                    .font(Font.custom("AppleSDGothicNeo-Regular", size: 14, relativeTo: .body))
                    .foregroundColor(.white)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .frame(height: 90)
                    .onChange(of: text) { newValue in
                        if newValue.count > Agreement.maxLength {
                            text = String(newValue.prefix(Agreement.maxLength))
                        }
                    }
            }
            .padding(.horizontal, 4)
            .background(Color.white.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 24)

            HStack {
                Spacer()
                Text("\(text.count) / \(Agreement.maxLength)")
                    .font(Font.custom("AppleSDGothicNeo-Regular", size: 11, relativeTo: .caption2))
                    .foregroundColor(remaining <= 15 ? Color(hex: "F87171") : .white.opacity(0.4))
            }
            .padding(.horizontal, 28)

            HStack(spacing: 12) {
                Button("Skip") { dismiss() }
                    .font(Font.custom("AppleSDGothicNeo-Regular", size: 14, relativeTo: .body))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.25), lineWidth: 1)
                    )

                Button {
                    viewModel.addAgreement(
                        to: post,
                        reaction: reaction,
                        text: trimmed,
                        userId: appleSignIn.uid,
                        displayName: appleSignIn.displayName
                    )
                    dismiss()
                } label: {
                    Text("Declare It →")
                        .font(Font.custom("AppleSDGothicNeo-Bold", size: 14, relativeTo: .body))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(canDeclare ? Color(hex: "7C3AED") : Color.gray.opacity(0.4))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(!canDeclare)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ZStack {
                Image(subscriptionStore.onboardingBGImage)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                Color.black.opacity(0.7)
                    .ignoresSafeArea()
            }
        }
    }
}

// MARK: - Detents helper

private extension View {
    /// Applies `.medium` detents on iOS 16+, no-op on earlier versions.
    @ViewBuilder
    func presentationDetentsCompat() -> some View {
        if #available(iOS 16.0, *) {
            self.presentationDetents([.medium])
        } else {
            self
        }
    }
}

// MARK: - PostPrayerView (Sheet)

struct PostPrayerView: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @ObservedObject var viewModel: PrayerWallViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var isSister = true
    @State private var text = ""
    @State private var selectedCategory: WarriorRoomCategory?
    private let maxChars = 280
    private let minWords = 5

    private var wordCount: Int {
        text.split(whereSeparator: \.isWhitespace).count
    }

    private var canPost: Bool {
        wordCount >= minWords && selectedCategory != nil && !viewModel.isSubmitting
    }

    private var placeholderText: String {
        selectedCategory?.composerPlaceholder
            ?? "What are you declaring and taking ground on?"
    }

    var body: some View {
        // VStack is the layout root — background is visual-only via .background{}
        // This gives the VStack a proper width context so padding works correctly.
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Handle bar
                    Capsule()
                        .fill(Color.white.opacity(0.25))
                        .frame(width: 40, height: 4)
                        .padding(.top, 12)

                    VStack(spacing: 4) {
                        Text("Add your declaration to the Warrior Room")
                            .font(Font.custom("AppleSDGothicNeo-Bold", size: 20, relativeTo: .title2))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        Text("Speak it out. The whole room stands with you.")
                            .font(Font.custom("AppleSDGothicNeo-Regular", size: 13, relativeTo: .caption))
                            .foregroundColor(.white.opacity(0.6))
                            .italic()
                            .multilineTextAlignment(.center)
                    }

                    // Gender toggle
                    HStack(spacing: 0) {
                        genderPill("Sister", isSelected: isSister) { isSister = true }
                        genderPill("Brother", isSelected: !isSister) { isSister = false }
                    }
                    .background(Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .frame(width: 200)

                    // Category selector
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Choose your ground:")
                            .font(Font.custom("AppleSDGothicNeo-Regular", size: 12, relativeTo: .caption))
                            .foregroundColor(.white.opacity(0.5))
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(WarriorRoomCategory.allCases) { category in
                                    categoryPickerPill(category)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Text editor
                    ZStack(alignment: .topLeading) {
                        if text.isEmpty {
                            Text(placeholderText)
                                .font(Font.custom("AppleSDGothicNeo-Regular", size: 15, relativeTo: .body))
                                .foregroundColor(.white.opacity(0.35))
                                .padding(.top, 14)
                                .padding(.leading, 18)
                                .padding(.trailing, 18)
                                .allowsHitTesting(false)
                        }

                        TextEditor(text: $text)
                            .font(Font.custom("AppleSDGothicNeo-Regular", size: 15, relativeTo: .body))
                            .foregroundColor(.white)
                            .scrollContentBackground(.hidden)
                            .background(Color.clear)
                            .frame(height: 150)
                            .onChange(of: text) { newValue in
                                if newValue.count > maxChars {
                                    text = String(newValue.prefix(maxChars))
                                }
                            }
                    }
                    .frame(maxWidth: .infinity, minHeight: 150, maxHeight: 150)
                    .background(Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )

                    // Counter + word-count hint
                    HStack {
                        if !text.isEmpty && wordCount < minWords {
                            Text("\(minWords - wordCount) more word\(minWords - wordCount == 1 ? "" : "s") needed")
                                .font(Font.custom("AppleSDGothicNeo-Regular", size: 12, relativeTo: .caption))
                                .foregroundColor(.white.opacity(0.45))
                        }
                        Spacer()
                        let remaining = maxChars - text.count
                        Text(remaining == maxChars ? "\(maxChars) characters" : "\(remaining) left")
                            .font(Font.custom("AppleSDGothicNeo-Regular", size: 12, relativeTo: .caption))
                            .foregroundColor(remaining <= 20 ? Color(hex: "F87171") : .white.opacity(0.4))
                    }

                    // Submission / error feedback
                    if let msg = viewModel.submissionMessage {
                        Text(msg)
                            .font(Font.custom("AppleSDGothicNeo-Regular", size: 14, relativeTo: .body))
                            .foregroundColor(Color(hex: "A78BFA"))
                            .multilineTextAlignment(.center)
                    }

                    if let err = viewModel.errorMessage {
                        Text(err)
                            .font(Font.custom("AppleSDGothicNeo-Regular", size: 13, relativeTo: .caption))
                            .foregroundColor(Color(hex: "F87171"))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }

            // Declare button — sits below scroll, lifts with keyboard naturally
            Button {
                guard let category = selectedCategory else { return }
                viewModel.addPost(text: text, isSister: isSister, category: category)
                if viewModel.errorMessage == nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        dismiss()
                    }
                }
            } label: {
                Group {
                    if viewModel.isSubmitting {
                        ProgressView().tint(.white)
                    } else {
                        Text("Declare It")
                            .font(Font.custom("AppleSDGothicNeo-Bold", size: 16, relativeTo: .body))
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(canPost ? Color(hex: "7C3AED") : Color.gray.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(!canPost)
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .background {
            ZStack {
                Image(subscriptionStore.onboardingBGImage)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                Color.black.opacity(0.62)
                    .ignoresSafeArea()
            }
        }
    }

    private func genderPill(_ label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(Font.custom("AppleSDGothicNeo-Regular", size: 14, relativeTo: .body))
                .foregroundColor(isSelected ? .black : .white.opacity(0.65))
                .frame(width: 100)
                .padding(.vertical, 8)
                .background(isSelected ? Color.white : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 22))
        }
    }

    private func categoryPickerPill(_ category: WarriorRoomCategory) -> some View {
        let isSelected = selectedCategory == category
        return Button {
            selectedCategory = category
        } label: {
            HStack(spacing: 4) {
                Text(category.emoji)
                Text(category.label)
            }
            .font(Font.custom("AppleSDGothicNeo-Regular", size: 13, relativeTo: .body))
            .foregroundColor(isSelected ? .white : .white.opacity(0.7))
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(isSelected ? Color(hex: "7C3AED") : Color.white.opacity(0.12))
            )
        }
    }
}
