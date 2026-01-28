//
//  DailyVerseDetailView.swift
//  SpeakLife
//
//  Created by SpeakLife Team on 1/28/26.
//

import SwiftUI

struct DailyVerseDetailView: View {
    let verse: RandomVerse
    @Environment(\.dismiss) var dismiss
    @State private var showShareSheet = false
    @State private var shareText = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(UIColor.systemBackground),
                        Constants.DAMidBlue.opacity(0.05)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Header
                        VStack(spacing: 8) {
                            Image(systemName: "quote.bubble.fill")
                                .font(.system(size: 48))
                                .foregroundColor(Constants.DAMidBlue)
                            
                            Text("Verse of the Day")
                                .font(.system(size: 24, weight: .bold, design: .serif))
                                .foregroundColor(.primary)
                        }
                        .padding(.top, 20)
                        
                        // Verse Content
                        VStack(spacing: 24) {
                            // The verse text
                            Text(verse.text)
                                .font(.system(size: 20, weight: .medium, design: .serif))
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)
                                .lineSpacing(6)
                                .padding(.horizontal, 20)
                            
                            // Reference
                            Text("\(verse.book.name) \(verse.chapter):\(verse.number)")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Constants.DAMidBlue)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(Constants.DAMidBlue.opacity(0.1))
                                )
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(UIColor.secondarySystemBackground))
                                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                        )
                        .padding(.horizontal)
                        
                        // Action Buttons
                        VStack(spacing: 16) {
                            // Share Button
                            Button(action: {
                                shareVerse()
                            }) {
                                HStack {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 16, weight: .medium))
                                    Text("Share Verse")
                                        .font(.system(size: 16, weight: .medium))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Constants.DAMidBlue)
                                .cornerRadius(12)
                            }
                            
                            // Copy Button
                            Button(action: {
                                copyVerse()
                            }) {
                                HStack {
                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 16, weight: .medium))
                                    Text("Copy to Clipboard")
                                        .font(.system(size: 16, weight: .medium))
                                }
                                .foregroundColor(Constants.DAMidBlue)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Constants.DAMidBlue, lineWidth: 2)
                                        .fill(Color.clear)
                                )
                            }
                        }
                        .padding(.horizontal, 40)
                        
                        Spacer()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(activityItems: [shareText])
            }
        }
    }
    
    private func shareVerse() {
        shareText = "\"\(verse.text)\"\n\n\(verse.book.name) \(verse.chapter):\(verse.number)\n\nShared from SpeakLife"
        showShareSheet = true
    }
    
    private func copyVerse() {
        let text = "\"\(verse.text)\" - \(verse.book.name) \(verse.chapter):\(verse.number)"
        UIPasteboard.general.string = text
        
        // Show feedback (you could add a toast/banner here)
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
}

// Note: Using existing ShareSheet from DeclarationContentView

#Preview {
    DailyVerseDetailView(
        verse: RandomVerse(
            book: BibleBookInfo(
                abbrev: BibleBookAbbrev(pt: "jo", en: "jhn"),
                name: "John",
                author: "John",
                group: "Gospel",
                version: "nlt"
            ),
            chapter: 3,
            number: 16,
            text: "For God so loved the world that he gave his one and only Son, that whoever believes in him shall not perish but have eternal life."
        )
    )
}