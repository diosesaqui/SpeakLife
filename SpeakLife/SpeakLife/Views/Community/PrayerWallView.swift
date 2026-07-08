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

/// A request from a card to present the agreement prompt sheet.
/// Identifiable so it can drive `.sheet(item:)` at the parent level —
/// a single sheet in the hierarchy avoids the per-card race where two
/// cards' sheet modifiers can clash when posts re-render.
private struct AgreementPresentationRequest: Identifiable {
    let post: PrayerWallPost
    let reaction: WarriorRoomReaction
    var id: String { (post.id ?? "no-id") + ":" + reaction.rawValue }
}

struct PrayerWallView: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @StateObject private var viewModel = PrayerWallViewModel()
    @ObservedObject private var appleSignIn = AppleSignInService.shared

    @State private var selectedTab: PrayerTab = .wall
    @State private var showPostForm = false
    @State private var showSignInPrompt = false
    @State private var agreementRequest: AgreementPresentationRequest?

    // "Messages" tab — broadcast messages from SpeakLife, read from Firestore
    // so the full history is visible even to users who installed after a
    // message was sent. Tapping a card opens the same RemoteMessageView
    // reader (Amen CTA) that a notification tap shows.
    @StateObject private var messagesViewModel = SpeakLifeMessagesViewModel()
    @State private var selectedMessage: RemoteMessage?

    enum PrayerTab { case wall, mine, messages }

    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Image(subscriptionStore.onboardingBGImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                    .clipped()
                    
                    .ignoresSafeArea()

                Color.black.opacity(0.50)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer().frame(height: UIScreen.main.bounds.height * 0.1)
                    segmentedControl
                        .padding(.horizontal, 20)
                        .padding(.top, DS.Spacing.xs)
                        .padding(.bottom, DS.Spacing.sm)
                        .dsAppear(0)

                    if selectedTab == .wall {
                        categoryFilterBar
                            .padding(.leading, 20)
                            .padding(.bottom, DS.Spacing.xs)
                            .dsAppear(0.06)
                    }

                    if selectedTab == .messages {
                        SpeakLifeMessagesListView(viewModel: messagesViewModel) { message in
                            selectedMessage = RemoteMessage(title: message.title, body: message.body)
                        }
                    } else if viewModel.isLoading && currentPosts.isEmpty {
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
                    // Composer writes prayer posts — irrelevant on the
                    // read-only Messages tab, so hide it there.
                    if selectedTab != .messages {
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
        .sheet(item: $selectedMessage) { message in
            RemoteMessageView(message: message)
        }
        .sheet(item: $agreementRequest) { request in
            AgreementPromptSheet(
                post: request.post,
                reaction: request.reaction,
                viewModel: viewModel
            )
            .environmentObject(subscriptionStore)
            .presentationDetentsCompat()
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
            tabButton("Messages", tab: .messages)
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
        switch selectedTab {
        case .wall: return viewModel.posts
        case .mine: return viewModel.myPosts
        // The Messages tab renders its own content; an exhaustive switch
        // keeps any future consumer of currentPosts from silently reading
        // My Prayers data while Messages is showing.
        case .messages: return []
        }
    }

    // MARK: - Category Filter Bar

    private var categoryFilterBar: some View {
        // Leading padding lives on the parent (`.padding(.leading, 20)` at
        // the call site) — applying it to the inner HStack here doesn't
        // render reliably across iOS versions when the ScrollView clips
        // its content. Trailing padding inside the HStack still works for
        // the last-pill-scroll-bleed.
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.xs) {
                Spacer().frame(width: 8)
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
                Spacer().frame(width: 8)
            }
            .padding(.trailing, 20)
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
                        viewModel: viewModel,
                        onPresentAgreement: { reaction in
                            agreementRequest = AgreementPresentationRequest(
                                post: post,
                                reaction: reaction
                            )
                        }
                    )
                }

                // Load more / end-of-feed (wall tab). Works under category
                // filters too — the server-side query in fetchPosts adds the
                // category constraint and the cursor advances within that
                // filtered slice.
                if selectedTab == .wall && !viewModel.posts.isEmpty {
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
                        .buttonStyle(.dsPressable(feel: .tapSolid))
                        .disabled(viewModel.isLoading)
                        .padding(.vertical, DS.Spacing.md)
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
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.top, DS.Spacing.xxs)
            .padding(.bottom, 30)
        }
        .refreshable {
            viewModel.refresh()
        }
    }

    // MARK: - Empty State

    private var emptyStateMessage: String {
        if selectedTab == .mine {
            return "You haven't shared anything yet.\nThis room is waiting on you."
        }
        if let filter = viewModel.categoryFilter {
            return "No posts in \(filter.label) yet.\nBe the first to share."
        }
        return "No posts yet. Be the first to share.\nThis room is waiting on you."
    }

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.md) {
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
    /// Called by the card when the user should be prompted to add an
    /// agreement. The parent owns the sheet and presents it — we don't
    /// host one per card because per-card sheets race each other when
    /// the post list re-renders after a reaction publishes a change.
    let onPresentAgreement: (WarriorRoomReaction) -> Void
    @ObservedObject private var appleSignIn = AppleSignInService.shared

    @State private var showReportAlert = false
    @State private var showDeleteAlert = false
    @State private var showAnsweredGlow = false
    @State private var isAgreementsExpanded = false

    private var postId: String { post.id ?? "" }
    private var agreements: [Agreement] { viewModel.agreementsByPost[postId] ?? [] }
    private var agreementsLoading: Bool { viewModel.loadingAgreementsForPost.contains(postId) }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            // Category pill (top)
            if let category = post.categoryEnum {
                categoryPill(category)
            }

            // Header row
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(post.displayName)
                            .font(Font.custom("AppleSDGothicNeo-Regular", size: 12, relativeTo: .caption))
                            .foregroundColor(.white.opacity(0.5))
                            .italic()

                        if post.authorIsPremium == true {
                            premiumCrownBadge
                        }
                    }

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

            // Post text
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

            // Always-visible "Stand in agreement" button — no auto-pop
            // after reactions; users add their voice explicitly here.
            // Hidden once the user has already added an agreement (and
            // for non-signed-in users, who'd hit a sign-in hint instead).
            if canAddAgreement {
                addAgreementButton
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
                            .padding(.horizontal, DS.Spacing.sm)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color(hex: "FBBF24").opacity(0.6), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.dsPressable(feel: .tapSolid))
                }

                Spacer()

                Menu {
                    if isMyPost {
                        Button(role: .destructive) {
                            showDeleteAlert = true
                        } label: {
                            Label("Delete post", systemImage: "trash")
                        }
                    } else {
                        Button(role: .destructive) {
                            showReportAlert = true
                        } label: {
                            Label("Report", systemImage: "flag")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.35))
                        .padding(.horizontal, DS.Spacing.xxs)
                        .padding(.vertical, DS.Spacing.xxs)
                }
                .alert("Delete this post?", isPresented: $showDeleteAlert) {
                    Button("Delete", role: .destructive) {
                        viewModel.deletePost(post)
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This can't be undone.")
                }
                .alert("Report this post?", isPresented: $showReportAlert) {
                    Button("Report", role: .destructive) {
                        viewModel.reportPost(post, reporterUid: appleSignIn.uid)
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Flag this post if it's inappropriate or spam.")
                }
            }
        }
        .padding(DS.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(showAnsweredGlow ? 0.22 : 0.12))
                .shadow(color: showAnsweredGlow ? Color(hex: "FBBF24").opacity(0.45) : .clear, radius: 12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(
                        colors: post.authorIsPremium == true
                            ? [Color(hex: "FBBF24").opacity(0.55), Color(hex: "F59E0B").opacity(0.25)]
                            : [Color.clear, Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: post.authorIsPremium == true ? 1 : 0
                )
        )
        .animation(.easeOut(duration: 0.6), value: showAnsweredGlow)
    }

    // MARK: - Subviews

    private func categoryPill(_ category: WarriorRoomCategory) -> some View {
        HStack(spacing: DS.Spacing.xxs) {
            Text(category.emoji)
            Text(category.label)
        }
        .font(Font.custom("AppleSDGothicNeo-Regular", size: 11, relativeTo: .caption))
        .foregroundColor(.white)
        .padding(.horizontal, DS.Spacing.xs)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.18))
        )
    }

    private var premiumCrownBadge: some View {
        Image(systemName: "crown.fill")
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(Color(hex: "FBBF24"))
            .accessibilityLabel("Premium subscriber")
    }

    private var reactionRow: some View {
        HStack(spacing: DS.Spacing.xs) {
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
            HStack(spacing: DS.Spacing.xxs) {
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
        viewModel.toggleReaction(reaction, on: post)
        // Reactions no longer auto-open the agreement sheet. The user opts
        // in explicitly via the always-visible "Stand in agreement" button
        // below the reaction summary — the auto-pop was pushy and forced
        // users to dismiss a modal after every reaction.
    }

    private var reactionSummaryRow: some View {
        let top = post.topReactions.prefix(2).map { $0.reaction.emoji }.joined()
        let total = post.totalReactions
        let suffix = total == 1
            ? "1 believer standing with you"
            : "\(total) believers standing with you"
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
                    ? "1 voice in agreement"
                    : "\(count) voices in agreement"
            }
            return "View those standing in agreement"
        }()

        VStack(alignment: .leading, spacing: 6) {
            Button {
                if !isAgreementsExpanded && agreements.isEmpty {
                    // Pass uid so loadAgreements can self-heal local
                    // "I agreed" state if there's no matching server doc.
                    viewModel.loadAgreements(for: post, currentUserId: appleSignIn.uid)
                }
                withAnimation(.easeInOut(duration: 0.2)) {
                    isAgreementsExpanded.toggle()
                }
            } label: {
                HStack(spacing: DS.Spacing.xxs) {
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
                    Text(emptyAgreementHint)
                        .font(Font.custom("AppleSDGothicNeo-Regular", size: 12, relativeTo: .caption))
                        .foregroundColor(.white.opacity(0.4))
                        .italic()
                } else {
                    let preview = Array(agreements.prefix(3))
                    ForEach(preview) { agreement in
                        AgreementRow(
                            agreement: agreement,
                            onDelete: agreement.userId == appleSignIn.uid
                                ? { viewModel.deleteAgreement(from: post, userId: appleSignIn.uid) }
                                : nil
                        )
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

    private var canAddAgreement: Bool {
        appleSignIn.isSignedIn && !viewModel.hasAgreed(on: post)
    }

    private var emptyAgreementHint: String {
        // Shown only when the chain is expanded and there are no
        // agreements yet. The "Stand in agreement" CTA is always visible
        // above the chain — this row just explains the empty state.
        appleSignIn.isSignedIn
            ? "Be the first to stand in agreement."
            : "Sign in to stand in agreement."
    }

    private var addAgreementButton: some View {
        Button {
            startAgreementFlow()
        } label: {
            HStack(spacing: DS.Spacing.xxs) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 11))
                Text("Stand in agreement")
                    .font(Font.custom("AppleSDGothicNeo-Regular", size: 12, relativeTo: .caption))
            }
            .foregroundColor(Color(hex: "A78BFA"))
            .padding(.top, 2)
        }
        .buttonStyle(.dsPressable(feel: .tapSolid))
    }

    /// Opens the agreement prompt. If the user has no current reaction yet,
    /// registers a `.standing` reaction first so the agreement always carries
    /// a reaction context.
    private func startAgreementFlow() {
        guard appleSignIn.isSignedIn else { return }
        guard !viewModel.hasAgreed(on: post) else { return }

        // Capture the reaction we want to prompt for; the parent presents.
        let reaction: WarriorRoomReaction
        if let current = viewModel.reaction(for: post) {
            reaction = current
        } else {
            viewModel.toggleReaction(.standing, on: post)
            reaction = .standing
        }
        onPresentAgreement(reaction)
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
    /// Set when the row is the signed-in user's own agreement, so it can
    /// be deleted via long-press. Nil disables the delete affordance.
    var onDelete: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text(agreement.reaction?.emoji ?? "🔥")
                .font(.system(size: 12))
            (Text(agreement.displayName + ": ").foregroundColor(.white.opacity(0.55))
                + Text(agreement.text).foregroundColor(.white.opacity(0.85)))
                .font(Font.custom("AppleSDGothicNeo-Regular", size: 12, relativeTo: .caption))
                .fixedSize(horizontal: false, vertical: true)
        }
        .contentShape(Rectangle())
        .contextMenu {
            if let onDelete {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            }
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
    /// Shared with the post composer via @AppStorage — defaults to whatever
    /// the user last picked there. Drives the anonymous displayName written
    /// to Firestore so agreements match the wall's "A sister/brother in
    /// Christ" anonymity instead of leaking the user's real Apple name.
    @AppStorage("warriorRoomIsSister") private var isSister = true

    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canStand: Bool { !trimmed.isEmpty }
    private var anonymousDisplayName: String {
        isSister ? "A sister in Christ" : "A brother in Christ"
    }
    private var remaining: Int { Agreement.maxLength - text.count }

    var body: some View {
        VStack(spacing: 18) {
            Capsule()
                .fill(Color.white.opacity(0.25))
                .frame(width: 40, height: 4)
                .padding(.top, 10)

            Text("Stand in agreement?")
                .font(Font.custom("AppleSDGothicNeo-Bold", size: 18, relativeTo: .title3))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.lg)

            HStack(spacing: 6) {
                Text(reaction.emoji)
                Text(reaction.label)
                    .font(Font.custom("AppleSDGothicNeo-Regular", size: 13, relativeTo: .body))
                    .foregroundColor(.white.opacity(0.7))
            }

            // Anonymous salutation toggle — mirrors the post composer.
            // The wall is anonymous, so agreements should be too.
            HStack(spacing: 0) {
                anonymousPill("Sister", isSelected: isSister) { isSister = true }
                anonymousPill("Brother", isSelected: !isSister) { isSister = false }
            }
            .background(Color.white.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .frame(width: 200)

            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(reaction.agreementPlaceholder)
                        .font(Font.custom("AppleSDGothicNeo-Regular", size: 14, relativeTo: .body))
                        .foregroundColor(.white.opacity(0.35))
                        .padding(.top, DS.Spacing.sm)
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
            .padding(.horizontal, DS.Spacing.xxs)
            .background(Color.white.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, DS.Spacing.lg)

            HStack {
                Spacer()
                Text("\(text.count) / \(Agreement.maxLength)")
                    .font(Font.custom("AppleSDGothicNeo-Regular", size: 11, relativeTo: .caption2))
                    .foregroundColor(remaining <= 15 ? Color(hex: "F87171") : .white.opacity(0.4))
            }
            .padding(.horizontal, 28)

            // Single primary action. Swipe-down dismisses the sheet
            // (iOS default) — no Skip button, since the user opened this
            // sheet specifically to stand in agreement.
            Button {
                viewModel.addAgreement(
                    to: post,
                    reaction: reaction,
                    text: trimmed,
                    userId: appleSignIn.uid,
                    // Anonymous salutation (matches post wall's pattern).
                    // Apple's full name is intentionally NOT used here.
                    displayName: anonymousDisplayName
                )
                dismiss()
            } label: {
                Text("Stand With Them →")
                    .font(Font.custom("AppleSDGothicNeo-Bold", size: 14, relativeTo: .body))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(canStand ? Color(hex: "7C3AED") : Color.gray.opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.dsPressable(feel: .tapSolid))
            .disabled(!canStand)
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.lg)
        }
        // Width fills the sheet; height fits content. Combining
        // `maxHeight: .infinity` with the `.medium` detent caused the
        // sheet to occasionally collapse to zero height — letting the
        // VStack size to its intrinsic content fixes that.
        .frame(maxWidth: .infinity)
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

    private func anonymousPill(_ label: String,
                               isSelected: Bool,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(Font.custom("AppleSDGothicNeo-Regular", size: 13, relativeTo: .body))
                .foregroundColor(isSelected ? .black : .white.opacity(0.65))
                .frame(width: 100)
                .padding(.vertical, 7)
                .background(isSelected ? Color.white : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 22))
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
    @ObservedObject private var appleSignIn = AppleSignInService.shared
    @Environment(\.dismiss) private var dismiss

    /// Persisted across sessions so the agreement sheet defaults to the
    /// same salutation the user picked the last time they posted.
    @AppStorage("warriorRoomIsSister") private var isSister = true
    @State private var text: String
    @State private var selectedCategory: WarriorRoomCategory?
    @State private var isTestimony: Bool
    private let maxChars = 280
    private let minWords = 5

    /// Default initialiser for normal Warrior Room composer entries.
    init(viewModel: PrayerWallViewModel) {
        self.init(viewModel: viewModel,
                  initialText: "",
                  initialIsTestimony: false,
                  initialCategory: nil)
    }

    /// Initialiser for prefilled launches — e.g. the Personal Declaration
    /// breakthrough flow lands here with the declaration as starter text
    /// and `isTestimony` already toggled on.
    init(viewModel: PrayerWallViewModel,
         initialText: String,
         initialIsTestimony: Bool,
         initialCategory: WarriorRoomCategory?) {
        self.viewModel = viewModel
        self._text = State(initialValue: initialText)
        self._isTestimony = State(initialValue: initialIsTestimony)
        self._selectedCategory = State(initialValue: initialCategory)
    }

    private var wordCount: Int {
        text.split(whereSeparator: \.isWhitespace).count
    }

    private var canPost: Bool {
        wordCount >= minWords && selectedCategory != nil && !viewModel.isSubmitting
    }

    private var placeholderText: String {
        if isTestimony {
            return selectedCategory == nil
                ? "Share what God did. Tell the room."
                : "Share what God did in this area. Tell the room."
        }
        return selectedCategory?.composerPlaceholder
            ?? "What do you need prayer for? Share it with the room."
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
                        .padding(.top, DS.Spacing.sm)

                    VStack(spacing: DS.Spacing.xxs) {
                        Text(isTestimony
                             ? "Share what God did"
                             : "Share with the Warrior Room")
                            .font(Font.custom("AppleSDGothicNeo-Bold", size: 20, relativeTo: .title2))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        Text(isTestimony
                             ? "Your testimony builds someone's faith."
                             : "The whole room is here to stand with you.")
                            .font(Font.custom("AppleSDGothicNeo-Regular", size: 13, relativeTo: .caption))
                            .foregroundColor(.white.opacity(0.6))
                            .italic()
                            .multilineTextAlignment(.center)
                    }

                    // Type toggle: Prayer Request / Testimony
                    HStack(spacing: 0) {
                        typePill("🙏 Prayer Request", isSelected: !isTestimony) {
                            isTestimony = false
                        }
                        typePill("🏆 Testimony", isSelected: isTestimony) {
                            isTestimony = true
                        }
                    }
                    .background(Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 22))

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
                            HStack(spacing: DS.Spacing.xs) {
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
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.md)
            }

            // Submit button — sits below scroll, lifts with keyboard naturally
            Button {
                guard let category = selectedCategory else { return }
                viewModel.addPost(text: text,
                                  isSister: isSister,
                                  category: category,
                                  authorUid: appleSignIn.uid,
                                  authorIsPremium: subscriptionStore.isPremium,
                                  isTestimony: isTestimony)
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
                        Text(isTestimony ? "Post Testimony" : "Post Prayer Request")
                            .font(Font.custom("AppleSDGothicNeo-Bold", size: 16, relativeTo: .body))
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(canPost ? Color(hex: "7C3AED") : Color.gray.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.dsPressable(feel: .tapSolid))
            .disabled(!canPost)
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.top, DS.Spacing.sm)
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
                .padding(.vertical, DS.Spacing.xs)
                .background(isSelected ? Color.white : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 22))
        }
    }

    private func typePill(_ label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(Font.custom("AppleSDGothicNeo-Regular", size: 14, relativeTo: .body))
                .foregroundColor(isSelected ? .white : .white.opacity(0.65))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(isSelected ? Color(hex: "7C3AED") : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 22))
        }
    }

    private func categoryPickerPill(_ category: WarriorRoomCategory) -> some View {
        let isSelected = selectedCategory == category
        return Button {
            selectedCategory = category
        } label: {
            HStack(spacing: DS.Spacing.xxs) {
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

// MARK: - WarriorRoomTestimonyComposer

/// Lightweight wrapper around `PostPrayerView` that owns its own
/// `PrayerWallViewModel`. Used when the composer needs to be presented
/// from outside the Warrior Room tab (e.g. the Personal Declaration
/// breakthrough flow). Because the @StateObject is created inside this
/// wrapper, it lives only as long as the sheet is on screen.
struct WarriorRoomTestimonyComposer: View {
    let initialText: String
    let initialIsTestimony: Bool

    @StateObject private var viewModel = PrayerWallViewModel()

    var body: some View {
        PostPrayerView(
            viewModel: viewModel,
            initialText: initialText,
            initialIsTestimony: initialIsTestimony,
            initialCategory: nil
        )
    }
}
