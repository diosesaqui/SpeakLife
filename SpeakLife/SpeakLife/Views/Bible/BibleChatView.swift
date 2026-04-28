//
//  BibleChatView.swift
//  SpeakLife
//
//  Topic picker for "Ask the Bible".
//

import SwiftUI

struct BibleChatView: View {
    @StateObject private var viewModel = BibleChatViewModel()
    @Environment(\.dismiss) private var dismiss
    @Namespace private var topicNamespace

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

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
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.white.opacity(0.6))
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
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
                .opacity(0.6)
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
            .padding(.bottom, 32)
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
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(topic.accentColor.opacity(0.18))
                        .frame(width: 42, height: 42)
                    Image(systemName: topic.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(topic.accentColor)
                }

                Text(topic.title)
                    .font(.system(size: 16, weight: .bold, design: .serif))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)

                Text(topic.question)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(topic.accentColor.opacity(0.35), lineWidth: 1)
                    )
                    .shadow(color: topic.accentColor.opacity(0.18), radius: 12, x: 0, y: 6)
            )
            .scaleEffect(pressed ? 0.97 : 1)
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { isPressing in
            withAnimation(.easeOut(duration: 0.12)) { pressed = isPressing }
        }, perform: {})
    }
}
