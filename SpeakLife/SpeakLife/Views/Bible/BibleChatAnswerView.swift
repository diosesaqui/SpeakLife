//
//  BibleChatAnswerView.swift
//  SpeakLife
//
//  Chat-style scripture-rooted answer for a topic.
//

import SwiftUI

struct BibleChatAnswerView: View {
    let topic: BibleChatTopic
    @Environment(\.dismiss) private var dismiss
    @State private var revealedVerses = 0
    @State private var headerVisible = false
    @State private var answerVisible = false
    @State private var reflectionVisible = false

    var body: some View {
        NavigationView {
            ZStack {
                Gradients().speakLifeCYOCell
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        topicHeader
                            .opacity(headerVisible ? 1 : 0)
                            .offset(y: headerVisible ? 0 : 12)

                        questionBubble
                            .opacity(headerVisible ? 1 : 0)
                            .offset(y: headerVisible ? 0 : 12)

                        answerBubble
                            .opacity(answerVisible ? 1 : 0)
                            .offset(y: answerVisible ? 0 : 12)

                        if !topic.verses.isEmpty {
                            versesSection
                        }

                        if let reflection = topic.reflection, !reflection.isEmpty {
                            reflectionBubble(text: reflection)
                                .opacity(reflectionVisible ? 1 : 0)
                                .offset(y: reflectionVisible ? 0 : 12)
                        }

                        actionRow
                            .opacity(reflectionVisible || topic.reflection == nil ? 1 : 0)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(topic.title)
                        .font(.system(size: 17, weight: .bold, design: .serif))
                        .foregroundColor(.white)
                        .lineLimit(1)
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
            .onAppear {
                AnalyticsService.shared.trackScreenView("bible_chat_answer", metadata: ["topic_id": topic.id])
                runRevealAnimation()
            }
        }
        .navigationViewStyle(.stack)
    }

    private var topicHeader: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(topic.accentColor.opacity(0.22))
                    .frame(width: 44, height: 44)
                Image(systemName: topic.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(topic.accentColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(topic.title)
                    .font(.system(size: 18, weight: .bold, design: .serif))
                    .foregroundColor(.white)
                Text(topic.summary)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.65))
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
    }

    private var questionBubble: some View {
        HStack {
            Spacer(minLength: 40)
            Text(topic.question)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(topic.accentColor.opacity(0.35))
                )
        }
    }

    private var answerBubble: some View {
        Text(topic.answer)
            .font(.system(size: 15, design: .serif))
            .foregroundColor(.white)
            .lineSpacing(4)
            .multilineTextAlignment(.leading)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                topic.accentColor.opacity(0.18),
                                Color.white.opacity(0.04),
                                Color.black.opacity(0.30)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(topic.accentColor.opacity(0.30), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.35), radius: 10, x: 0, y: 4)
            )
    }

    private var versesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Scripture")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.55))
                .textCase(.uppercase)
                .padding(.leading, 4)
                .padding(.top, 4)

            ForEach(Array(topic.verses.enumerated()), id: \.element.id) { index, verse in
                if index < revealedVerses {
                    VerseCard(verse: verse, accent: topic.accentColor)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .bottom)),
                            removal: .opacity
                        ))
                }
            }
        }
    }

    private func reflectionBubble(text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .foregroundColor(Constants.gold)
                    .font(.system(size: 13, weight: .semibold))
                Text("Reflection")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.55))
                    .textCase(.uppercase)
            }
            Text(text)
                .font(.system(size: 14, design: .serif))
                .foregroundColor(.white)
                .lineSpacing(3)
                .multilineTextAlignment(.leading)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Constants.gold.opacity(0.10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Constants.gold.opacity(0.30), lineWidth: 1)
                        )
                )
        }
    }

    private var actionRow: some View {
        HStack(spacing: 12) {
            ShareLink(item: shareText) {
                actionLabel(systemImage: "square.and.arrow.up", title: "Share")
            }
            Button {
                let pasteboard = UIPasteboard.general
                pasteboard.string = shareText
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                AnalyticsService.shared.trackContentInteraction(
                    contentType: "bible_chat_topic",
                    contentId: topic.id,
                    action: "copy"
                )
            } label: {
                actionLabel(systemImage: "doc.on.doc", title: "Copy")
            }
        }
        .padding(.top, 8)
    }

    private func actionLabel(systemImage: String, title: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
            Text(title)
        }
        .font(.system(size: 13, weight: .semibold))
        .foregroundColor(.white)
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
        )
    }

    private var shareText: String {
        var lines = [topic.title, "", topic.answer]
        if !topic.verses.isEmpty {
            lines.append("")
            for verse in topic.verses {
                lines.append("\u{201C}\(verse.text)\u{201D} \u{2014} \(verse.reference)")
            }
        }
        lines.append("")
        lines.append("via SpeakLife")
        return lines.joined(separator: "\n")
    }

    private func runRevealAnimation() {
        withAnimation(.easeOut(duration: 0.35)) {
            headerVisible = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.easeOut(duration: 0.35)) {
                answerVisible = true
            }
        }
        for index in 0..<topic.verses.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55 + Double(index) * 0.18) {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
                    revealedVerses = index + 1
                }
            }
        }
        let reflectionDelay = 0.55 + Double(topic.verses.count) * 0.18 + 0.15
        DispatchQueue.main.asyncAfter(deadline: .now() + reflectionDelay) {
            withAnimation(.easeOut(duration: 0.35)) {
                reflectionVisible = true
            }
        }
    }
}

private struct VerseCard: View {
    let verse: BibleChatVerse
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\u{201C}\(verse.text)\u{201D}")
                .font(.system(size: 14, design: .serif))
                .foregroundColor(.white)
                .lineSpacing(3)
                .multilineTextAlignment(.leading)
            HStack {
                Text(verse.reference)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(accent)
                if let translation = verse.translation, !translation.isEmpty {
                    Text(translation.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.4))
                }
                Spacer()
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            accent.opacity(0.16),
                            Color.black.opacity(0.30)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(accent.opacity(0.45), lineWidth: 1)
                )
                .shadow(color: accent.opacity(0.20), radius: 8, x: 0, y: 4)
        )
    }
}
