import SwiftUI

struct QuizExplanationView: View {
    let explanation: String
    let onContinue: () -> Void

    @State private var animate = false

    var body: some View {
        ZStack {
            // 🔮 Subtle animated gradient background
            LinearGradient(gradient: Gradient(colors: [.indigo, .purple, .blue]),
                           startPoint: animate ? .topLeading : .bottomTrailing,
                           endPoint: animate ? .bottomTrailing : .topLeading)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 6).repeatForever(autoreverses: true), value: animate)

            VStack(spacing: 30) {
                // 🧠 Title
                Text("Let’s Learn")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.white)
                    .scaleEffect(animate ? 1.05 : 0.95)
                    .opacity(animate ? 1 : 0)
                    .animation(.easeInOut(duration: 1).repeatForever(), value: animate)

                // 📖 Revelation box
                Text(explanation)
                    .font(.body)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white.opacity(0.15))
                            .blur(radius: 0.5)
                            .shadow(color: .white.opacity(0.2), radius: 10, x: 0, y: 8)
                    )
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                // ✅ Continue Button
                Button(action: onContinue) {
                    Text("Continue")
                        .font(.headline)
                        .foregroundColor(.purple)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(.white)
                        .cornerRadius(15)
                        .shadow(color: .white.opacity(0.4), radius: 10)
                }
                .padding(.horizontal)
            }
            .padding()
        }
        .onAppear {
            animate = true
        }
    }
}
