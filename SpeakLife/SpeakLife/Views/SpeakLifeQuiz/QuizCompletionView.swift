import SwiftUI

struct QuizCompletionView: View {
    @State private var animateStar = false
    @State private var animateText = false
    @State private var animateGradient = false
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            // 🌈 Animated gradient background
            LinearGradient(gradient: Gradient(colors: [.purple, .blue, .pink, .indigo]),
                           startPoint: animateGradient ? .topLeading : .bottomTrailing,
                           endPoint: animateGradient ? .bottomTrailing : .topLeading)
                .animation(.easeInOut(duration: 6).repeatForever(autoreverses: true), value: animateGradient)
                .ignoresSafeArea()

            // Scrolls when content exceeds the screen (small devices, large
            // Dynamic Type); stays vertically centered otherwise.
            GeometryReader { geo in
                ScrollView(showsIndicators: false) {
                    completionContent
                        .frame(minWidth: geo.size.width, minHeight: geo.size.height)
                }
            }
        }
        .onAppear {
            animateStar = true
            animateText = true
            animateGradient = true
        }
    }

    private var completionContent: some View {
            VStack(spacing: 30) {
                // 🎉 Victory Message
                Text("🎉 Quiz Complete!")
                    .font(.largeTitle.bold())
                    .foregroundColor(.white)
                    .scaleEffect(animateText ? 1.1 : 0.9)
                    .animation(.easeInOut(duration: 0.8).repeatForever(), value: animateText)

                Text("Well done! You’re growing in grace and truth.")
                    .font(.title3)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                // 🌟 Star celebration
                Image(systemName: "star.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .foregroundColor(.yellow)
                    .scaleEffect(animateStar ? 1.2 : 0.8)
                    .shadow(color: .yellow.opacity(0.5), radius: 20)
                    .animation(.easeInOut(duration: 1.2).repeatForever(), value: animateStar)

                // ✅ CTA Button
                Button(action: {
                    dismiss()
                   // appState.showQuizButton = false
                }) {
                    Text("Back to Lessons")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(DS.Gradient.gold)
                        .foregroundColor(DS.Palette.deepBlue)
                        .cornerRadius(20)
                        .shadow(color: DS.Palette.gold.opacity(0.45), radius: 8, x: 0, y: 3)
                }
                .buttonStyle(.dsPressable(feel: .tapSolid))
                .padding(.horizontal, 40)
            }
            .padding()
    }
}
