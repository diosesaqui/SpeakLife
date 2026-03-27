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
            viewModel.fetchPosts(reset: true)
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
        selectedTab == .wall ? viewModel.posts : viewModel.myPosts
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

                // Load more (wall tab only)
                if selectedTab == .wall && !viewModel.posts.isEmpty {
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
                    .padding(.vertical, 16)
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

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "hands.and.sparkles.fill")
                .font(.system(size: 48))
                .foregroundColor(Color(hex: "A78BFA").opacity(0.7))
            Text(selectedTab == .wall
                 ? "No prayers yet. Be the first to ask.\nSomeone here will show up for you."
                 : "You haven't shared any prayer requests yet.")
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
    @State private var showReportAlert = false
    @State private var showAnsweredGlow = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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

                // Time ago
                Text(timeAgo(from: post.timestamp))
                    .font(Font.custom("AppleSDGothicNeo-Regular", size: 11, relativeTo: .caption2))
                    .foregroundColor(.white.opacity(0.35))
            }

            // Prayer text
            Text(post.text)
                .font(Font.custom("AppleSDGothicNeo-Regular", size: 15, relativeTo: .body))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)

            // Action row
            HStack(spacing: 14) {
                // Pray button
                Button {
                    viewModel.prayForPost(post)
                } label: {
                    HStack(spacing: 6) {
                        Text("🙏")
                            .font(.system(size: 14))
                        Text("Praying (\(post.prayerCount))")
                            .font(Font.custom("AppleSDGothicNeo-Regular", size: 13, relativeTo: .body))
                    }
                    .foregroundColor(viewModel.hasPrayed(for: post) ? Color(hex: "A78BFA") : .white.opacity(0.8))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                viewModel.hasPrayed(for: post) ? Color(hex: "A78BFA") : Color.white.opacity(0.3),
                                lineWidth: 1.2
                            )
                    )
                }
                .disabled(viewModel.hasPrayed(for: post))

                // "Mark as Answered" — only on My Prayers tab, only if not yet answered
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

                // Report button (community tab only)
                if !isMyPost {
                    Button {
                        showReportAlert = true
                    } label: {
                        Image(systemName: "flag")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.3))
                    }
                    .alert("Report this prayer?", isPresented: $showReportAlert) {
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

// MARK: - PostPrayerView (Sheet)

struct PostPrayerView: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @ObservedObject var viewModel: PrayerWallViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var isSister = true
    @State private var text = ""
    private let maxChars = 280

    var body: some View {
        ZStack {
            Image(subscriptionStore.onboardingBGImage)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            Color.black.opacity(0.62)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Handle bar
                Capsule()
                    .fill(Color.white.opacity(0.25))
                    .frame(width: 40, height: 4)
                    .padding(.top, 12)

                Text("Share Your Prayer Request")
                    .font(Font.custom("AppleSDGothicNeo-Bold", size: 20, relativeTo: .title2))
                    .foregroundColor(.white)

                // Gender toggle
                HStack(spacing: 0) {
                    genderPill("Sister", isSelected: isSister) { isSister = true }
                    genderPill("Brother", isSelected: !isSister) { isSister = false }
                }
                .background(Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .frame(width: 200)

                // Text editor
                GeometryReader { proxy in
                    ZStack(alignment: .topLeading) {
                        if text.isEmpty {
                            Text("Share your prayer request…")
                                .font(Font.custom("AppleSDGothicNeo-Regular", size: 15, relativeTo: .body))
                                .foregroundColor(.white.opacity(0.35))
                                .padding(14)
                        }
                        
                        TextEditor(text: $text)
                            .font(Font.custom("AppleSDGothicNeo-Regular", size: 15, relativeTo: .body))
                            .foregroundColor(.white)
                            .scrollContentBackground(.hidden)
                            .background(Color.clear)
                            .padding(10)
                            .onChange(of: text) { newValue in
                                if newValue.count > maxChars {
                                    text = String(newValue.prefix(maxChars))
                                }
                            }
                    }
                    .frame(width: proxy.size.width * 0.9, height: 200)
                    .background(Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .padding(.horizontal, 4)
                }

                // Character counter
                HStack {
                    Spacer()
                    Text("\(text.count)/\(maxChars)")
                        .font(Font.custom("AppleSDGothicNeo-Regular", size: 12, relativeTo: .caption))
                        .foregroundColor(text.count >= maxChars ? Color(hex: "F87171") : .white.opacity(0.4))
                }

                // Submission feedback
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

                // Post button
                Button {
                    viewModel.addPost(text: text, isSister: isSister)
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
                            Text("Post Request")
                                .font(Font.custom("AppleSDGothicNeo-Bold", size: 16, relativeTo: .body))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSubmitting
                            ? Color.gray.opacity(0.4)
                            : Color(hex: "7C3AED")
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSubmitting)

                Spacer()
            }
            .padding(.horizontal, 24)
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
}
