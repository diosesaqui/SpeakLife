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
                        .background(Color.white)
                        .foregroundColor(.purple)
                        .cornerRadius(20)
                        .shadow(radius: 5)
                }
                .padding(.horizontal, 40)
            }
            .padding()
        }
        .onAppear {
            animateStar = true
            animateText = true
            animateGradient = true
        }
    }
}
