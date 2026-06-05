//
//  BibleChatView.swift
//  SpeakLife
//
//  Topic picker for "Ask the Bible".
//

import SwiftUI
import MessageUI

struct BibleChatView: View {
    @StateObject private var viewModel = BibleChatViewModel()
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @Environment(\.dismiss) private var dismiss
    @Namespace private var topicNamespace
    @State private var showMailSheet = false
    @State private var mailResult: Result<MFMailComposeResult, Error>? = nil

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    private let suggestPrefillBody = "Hi SpeakLife team,\n\nI'd love to see a Bible Chat topic about:\n\n"

    var body: some View {
        NavigationView {
            ZStack {
                Gradients().speakLifeCYOCell
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    header
                    searchBar
                    topicGrid
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Ask the Bible")
                        .font(.system(size: 18, weight: .bold, design: .serif))
                        .foregroundColor(.white)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
            .sheet(item: $viewModel.selectedTopic) { topic in
                BibleChatAnswerView(topic: topic)
            }
            .sheet(isPresented: $showMailSheet) {
                MailView(
                    isShowing: $showMailSheet,
                    result: $mailResult,
                    origin: .bibleChatTopic,
                    prefillBody: suggestPrefillBody,
                    isSubscribed: subscriptionStore.isPremium
                )
            }
        }
        .navigationViewStyle(.stack)
        .onAppear {
            viewModel.load()
            AnalyticsService.shared.trackScreenView("bible_chat")
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text("What does the Bible say about…")
                .font(.system(size: 22, weight: .semibold, design: .serif))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            Text("Tap a topic for a scripture-rooted answer.")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.65))
        }
        .padding(.top, 8)
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.55))
            TextField("", text: $viewModel.searchText, prompt: Text("Search topics").foregroundColor(.white.opacity(0.4)))
                .foregroundColor(.white)
                .autocorrectionDisabled()
            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.5))
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 14)
    }

    private var topicGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(Array(viewModel.filteredTopics.enumerated()), id: \.element.id) { index, topic in
                    TopicCardView(topic: topic, namespace: topicNamespace) {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
                            viewModel.select(topic)
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.92)),
                        removal: .opacity
                    ))
                    .animation(.easeOut(duration: 0.35).delay(Double(index) * 0.025), value: viewModel.topics.count)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)

            suggestTopicButton
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 32)
        }
    }

    private var suggestTopicButton: some View {
        Button {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            AnalyticsService.shared.trackUserAction(
                "bible_chat_suggest_topic_tap",
                category: "bible_chat"
            )
            if MFMailComposeViewController.canSendMail() {
                showMailSheet = true
            } else {
                openSuggestTopicMailto()
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "envelope.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Constants.gold)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Don't see your topic?")
                        .font(.system(size: 14, weight: .semibold, design: .serif))
                        .foregroundColor(.white)
                    Text("Email us your idea — we'll add it.")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.65))
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Constants.gold.opacity(0.18),
                                Color.black.opacity(0.30)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Constants.gold.opacity(0.45), lineWidth: 1)
                    )
                    .shadow(color: Constants.gold.opacity(0.20), radius: 10, x: 0, y: 4)
            )
        }
        .buttonStyle(.plain)
    }

    private func openSuggestTopicMailto() {
        let subject = "Bible Chat: Topic Request 🙏"
        let body = suggestPrefillBody
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = "speaklife@diosesaqui.com"
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]
        if let url = components.url {
            UIApplication.shared.open(url)
        }
    }
}

private struct TopicCardView: View {
    let topic: BibleChatTopic
    let namespace: Namespace.ID
    let action: () -> Void

    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                iconBadge

                Text(topic.title)
                    .font(.system(size: 17, weight: .bold, design: .serif))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)
                    .fixedSize(horizontal: false, vertical: true)

                Text(topic.summary)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.72))
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 152, alignment: .topLeading)
            .padding(16)
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
                        colors: [
                            topic.accentColor,
                            topic.accentColor.opacity(0.55)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 44, height: 44)
                .shadow(color: topic.accentColor.opacity(0.55), radius: 10, x: 0, y: 4)
            Image(systemName: topic.icon)
                .font(.system(size: 19, weight: .semibold))
                .foregroundColor(.white)
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        topic.accentColor.opacity(0.30),
                        topic.accentColor.opacity(0.08),
                        Color.black.opacity(0.35)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                topic.accentColor.opacity(0.75),
                                topic.accentColor.opacity(0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                    .blendMode(.plusLighter)
            )
            .shadow(color: topic.accentColor.opacity(0.40), radius: 18, x: 0, y: 10)
            .shadow(color: Color.black.opacity(0.45), radius: 14, x: 0, y: 6)
    }
}

// MARK: - Live AI conversation
//
// The tab content. A chat-first screen: empty state sells the feature with
// starter chips drawn from the curated topics; typing or tapping a chip starts
// a live, scripture-rooted conversation through the bibleChat proxy.

struct BibleChatConversationView: View {
    @StateObject private var viewModel = BibleChatConversationViewModel()
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    // Held only to forward into the paywall → OptimizedSubscriptionView sheet,
    // since SwiftUI does not reliably propagate env objects across sheet hops.
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var declarationStore: DeclarationViewModel
    @State private var showPaywall = false
    @FocusState private var inputFocused: Bool

    private let starters: [BibleChatTopic] = (try? BibleChatService.shared.loadTopics()) ?? []

    var body: some View {
        NavigationView {
            ZStack {
                Gradients().speakLifeCYOCell.ignoresSafeArea()
                VStack(spacing: 0) {
                    transcript
                    inputBar
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Bible Chat")
                        .font(.system(size: 18, weight: .bold, design: .serif))
                        .foregroundColor(.white)
                }
            }
        }
        .navigationViewStyle(.stack)
        .onChange(of: viewModel.needsPaywall) { newValue in
            if newValue {
                viewModel.needsPaywall = false
                showPaywall = true
            }
        }
        .sheet(isPresented: $showPaywall) {
            BibleChatPaywallSplash { showPaywall = false }
                .environmentObject(appState)
                .environmentObject(declarationStore)
                .environmentObject(subscriptionStore)
                .presentationDetents([.large])
        }
        .onAppear { AnalyticsService.shared.trackScreenView("bible_chat_conversation") }
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 14) {
                    if viewModel.messages.isEmpty {
                        emptyState
                    } else {
                        ForEach(viewModel.messages) { msg in
                            ChatBubble(message: msg).id(msg.id)
                        }
                    }
                    if viewModel.isSending {
                        typingIndicator.id("typing")
                    }
                    if let err = viewModel.errorMessage {
                        Text(err)
                            .font(.system(size: 13))
                            .foregroundColor(.red.opacity(0.9))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)
            }
            .onChange(of: viewModel.messages.count) { _ in
                if let last = viewModel.messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
            .onChange(of: viewModel.isSending) { sending in
                if sending { withAnimation { proxy.scrollTo("typing", anchor: .bottom) } }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.text.bubble.right.fill")
                .font(.system(size: 40))
                .foregroundColor(Constants.gold)
            Text("What's on your heart?")
                .font(.system(size: 22, weight: .bold, design: .serif))
                .foregroundColor(.white)
            Text("Ask anything about life or faith. Get a warm, scripture-rooted answer in seconds.")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            VStack(spacing: 10) {
                ForEach(starters.prefix(5)) { topic in
                    Button {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        viewModel.send(topic.question, isPremium: subscriptionStore.isPremium)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: topic.icon)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(topic.accentColor)
                            Text(topic.title)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white.opacity(0.4))
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white.opacity(0.06))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 6)
        }
        .padding(.top, 36)
    }

    private var typingIndicator: some View {
        HStack {
            TypingDots()
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )
            Spacer(minLength: 40)
        }
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField(
                "",
                text: $viewModel.draft,
                prompt: Text("Ask about life or faith…").foregroundColor(.white.opacity(0.4))
            )
            .textFieldStyle(.plain)
            .foregroundColor(.white)
            .focused($inputFocused)
            .submitLabel(.send)
            .onSubmit { viewModel.sendDraft(isPremium: subscriptionStore.isPremium) }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )

            Button {
                inputFocused = false
                viewModel.sendDraft(isPremium: subscriptionStore.isPremium)
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(viewModel.canSend ? Constants.gold : .white.opacity(0.25))
            }
            .disabled(!viewModel.canSend)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.2))
    }
}

// Animated "typing" indicator — three dots pulsing in a wave.
private struct TypingDots: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: 7, height: 7)
                    .scaleEffect(animating ? 1.0 : 0.5)
                    .opacity(animating ? 1.0 : 0.4)
                    .animation(
                        .easeInOut(duration: 0.6).repeatForever().delay(Double(i) * 0.2),
                        value: animating
                    )
            }
        }
        .onAppear { animating = true }
    }
}

private struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }
            Text(message.text)
                .font(.system(size: 15, design: message.role == .assistant ? .serif : .default))
                .foregroundColor(.white)
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .background(bubbleBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(
                            message.role == .user ? Constants.gold.opacity(0.4) : Color.white.opacity(0.1),
                            lineWidth: 1
                        )
                )
                .textSelection(.enabled)
            if message.role == .assistant { Spacer(minLength: 40) }
        }
    }

    @ViewBuilder
    private var bubbleBackground: some View {
        if message.role == .user {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Constants.gold.opacity(0.35), Constants.gold.opacity(0.18)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        } else {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.08))
        }
    }
}

// MARK: - Benefits splash + paywall
//
// Shown when a non-premium user exhausts their free messages. Sells the value,
// then hands off to the existing OptimizedSubscriptionView for purchase.

struct BibleChatPaywallSplash: View {
    var onClose: () -> Void
    @State private var showSubscription = false
    // OptimizedSubscriptionView requires these; forward them across the sheet hop.
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var declarationStore: DeclarationViewModel
    @EnvironmentObject var subscriptionStore: SubscriptionStore

    private let benefits: [(icon: String, text: String)] = [
        ("book.fill", "Scripture-rooted answers to anything you're facing"),
        ("heart.fill", "Warm, biblical guidance for anxiety, relationships, and more"),
        ("infinity", "Unlimited conversations, any time, day or night"),
        ("sparkles", "Private, personal, and always pointing you to Christ")
    ]

    var body: some View {
        ZStack {
            Gradients().speakLifeCYOCell.ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer(minLength: 16)
                Image(systemName: "bubble.left.and.text.bubble.right.fill")
                    .font(.system(size: 46))
                    .foregroundColor(Constants.gold)
                    .padding(.bottom, 14)
                Text("Keep the conversation going")
                    .font(.system(size: 25, weight: .bold, design: .serif))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                Text("You've used your free messages. Unlock Bible Chat to ask anything, anytime.")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .padding(.top, 8)

                VStack(alignment: .leading, spacing: 16) {
                    ForEach(benefits, id: \.icon) { item in
                        HStack(spacing: 14) {
                            Image(systemName: item.icon)
                                .font(.system(size: 18))
                                .foregroundColor(Constants.gold)
                                .frame(width: 28)
                            Text(item.text)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                    }
                }
                .padding(.horizontal, 30)
                .padding(.vertical, 28)

                Spacer(minLength: 0)

                Button {
                    showSubscription = true
                } label: {
                    Text("Unlock Bible Chat")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Constants.gold)
                        )
                }
                .padding(.horizontal, 24)

                Button("Maybe later") { onClose() }
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.top, 12)
                    .padding(.bottom, 22)
            }
        }
        .sheet(isPresented: $showSubscription) {
            OptimizedSubscriptionView {
                showSubscription = false
                onClose()
            }
            .environmentObject(appState)
            .environmentObject(declarationStore)
            .environmentObject(subscriptionStore)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .presentationDetents([.large])
        }
        .onAppear { AnalyticsService.shared.trackScreenView("bible_chat_paywall") }
    }
}
