//
//  VerseCardView.swift
//  SpeakLife
//
//  Beautiful verse response card for the Ask tab.
//  Displays the AI-returned Bible verse, reference, and encouragement.
//

import SwiftUI

struct VerseCardView: View {
    let response: AIVerseResponse
    let onSave: () -> Void
    let isSaved: Bool
    
    @State private var appeared = false
    @State private var saveScale: CGFloat = 1.0
    @State private var showCopied = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header pill
            HStack(spacing: 6) {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Constants.gold)
                Text("Scripture")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Constants.gold)
                    .textCase(.uppercase)
                    .tracking(1.2)
                Spacer()
                // Topic pills
                ForEach(response.topics.prefix(2), id: \.self) { topic in
                    Text(topic)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 14)
            
            // Divider
            Rectangle()
                .fill(LinearGradient(
                    colors: [Constants.gold.opacity(0.5), Color.clear],
                    startPoint: .leading,
                    endPoint: .trailing
                ))
                .frame(height: 1)
                .padding(.horizontal, 18)
            
            // Verse text
            Text("\"\(response.verse)\"")
                .font(.custom("Georgia", size: 17))
                .fontWeight(.regular)
                .foregroundColor(.white)
                .lineSpacing(6)
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 6)
            
            // Reference
            Text("— \(response.reference)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Constants.DAMidBlue)
                .padding(.horizontal, 18)
                .padding(.bottom, 16)
            
            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
                .padding(.horizontal, 18)
            
            // Encouragement
            HStack(alignment: .top, spacing: 10) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Constants.DAMidBlue.opacity(0.7))
                    .frame(width: 3)
                
                Text(response.encouragement)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.85))
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            
            // Action bar
            HStack(spacing: 16) {
                Spacer()
                
                // Copy button
                Button {
                    copyVerse()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 13, weight: .medium))
                        Text(showCopied ? "Copied" : "Copy")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
                }
                .buttonStyle(PlainButtonStyle())
                
                // Save button
                Button {
                    guard !isSaved else { return }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                        saveScale = 1.3
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            saveScale = 1.0
                        }
                    }
                    onSave()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: isSaved ? "heart.fill" : "heart")
                            .font(.system(size: 13, weight: .medium))
                            .scaleEffect(saveScale)
                        Text(isSaved ? "Saved" : "Save")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(isSaved ? .pink : .white.opacity(0.6))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(isSaved ? Color.pink.opacity(0.15) : Color.white.opacity(0.08))
                    .clipShape(Capsule())
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 16)
        }
        .background(
            ZStack {
                // Glass card background
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(red: 0.1, green: 0.12, blue: 0.22).opacity(0.95))
                
                // Subtle glow border
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Constants.DAMidBlue.opacity(0.5), Constants.gold.opacity(0.3), Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
            }
        )
        .shadow(color: Constants.DADarkBlue.opacity(0.4), radius: 20, x: 0, y: 8)
        .scaleEffect(appeared ? 1.0 : 0.92)
        .opacity(appeared ? 1.0 : 0.0)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                appeared = true
            }
        }
    }
    
    private func copyVerse() {
        let text = "\"\(response.verse)\"\n— \(response.reference)"
        UIPasteboard.general.string = text
        withAnimation {
            showCopied = true
        }
        PremiumHaptics.light()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showCopied = false
            }
        }
    }
}

// MARK: - Typing Indicator

struct TypingIndicatorView: View {
    @State private var dotScale: [CGFloat] = [0.5, 0.5, 0.5]
    
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Constants.DAMidBlue.opacity(0.8))
                    .frame(width: 8, height: 8)
                    .scaleEffect(dotScale[index])
                    .animation(
                        .easeInOut(duration: 0.5)
                        .repeatForever()
                        .delay(Double(index) * 0.18),
                        value: dotScale[index]
                    )
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.08))
        )
        .onAppear {
            dotScale = [1.2, 1.2, 1.2]
        }
    }
}
