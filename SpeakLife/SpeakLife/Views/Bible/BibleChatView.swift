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
