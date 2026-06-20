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
                    .dsGlass(cornerRadius: DS.Radius.lg)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                // ✅ Continue Button
                Button(action: onContinue) {
                    Text("Continue")
                        .font(.headline)
                        .foregroundColor(DS.Palette.deepBlue)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(DS.Gradient.gold)
                        .cornerRadius(15)
                        .shadow(color: DS.Palette.gold.opacity(0.45), radius: 8, x: 0, y: 3)
                }
                .buttonStyle(.dsPressable(feel: .tapSolid))
                .padding(.horizontal)
            }
            .padding()
        }
        .onAppear {
            animate = true
        }
    }
}
