import SwiftUI


struct SkillLevelView: View {
    @ObservedObject var progressManager: QuizProgressManager

    var body: some View {
        let level = progressManager.levelName
        let color = progressManager.colorForLevel(level)
        let icon = progressManager.iconForLevel(level)

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .imageScale(.large)
                    .padding(8)
                    .background(color.opacity(0.1))
                    .clipShape(Circle())

                VStack(alignment: .leading) {
                    Text("Your Level")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(level)
                        .font(.title3.bold())
                        .foregroundColor(color)
                }

                Spacer()
            }

            ProgressView(value: progressManager.progress)
                .progressViewStyle(LinearProgressViewStyle(tint: color))
                .animation(.easeInOut(duration: 0.5), value: progressManager.progress)
                .frame(height: 8)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(radius: 5)
        .padding(.horizontal)
    }
}

struct QuizConfettiView: View {
    @State private var particles: [ConfettiParticleData] = []
    @State private var isExploded = false

       var body: some View {
           ZStack {
               ForEach(particles) { particle in
                   ConfettiParticle(color: particle.color)
                       .frame(width: particle.size, height: particle.size)
                       .position(
                           x: isExploded ? particle.x : UIScreen.main.bounds.width / 2,
                           y: isExploded ? particle.y : UIScreen.main.bounds.height / 2
                       )
                       .opacity(isExploded ? 1 : 0)
                       .scaleEffect(isExploded ? 1 : 0.2)
                       .rotationEffect(.degrees(isExploded ? particle.rotation : 0))
                       .animation(
                           .interpolatingSpring(stiffness: 100, damping: 10)
                           .delay(particle.delay),
                           value: isExploded
                       )
               }
           }
           .onAppear {
               generateParticles()
               DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                   isExploded = true
               }
           }
           .frame(maxWidth: .infinity, maxHeight: .infinity)
       }

       private func generateParticles() {
           particles = []
           let centerX = UIScreen.main.bounds.width / 2
           let centerY = UIScreen.main.bounds.height / 2

           for i in 0..<60 {
               let angle = Double(i) * (360.0 / 60.0)
               let radius = Double.random(in: 80...180)
               let delay = Double.random(in: 0...0.3)

               let targetX = centerX + CGFloat(cos(angle * .pi / 180) * radius)
               let targetY = centerY + CGFloat(sin(angle * .pi / 180) * radius)

               particles.append(
                   ConfettiParticleData(
                       id: UUID(),
                       x: targetX,
                       y: targetY,
                       color: ConfettiParticle.randomColor(),
                       delay: delay,
                       size: CGFloat.random(in: 10...14),
                       scale: 1,
                       rotation: Double.random(in: 0...360),
                       opacity: 1
                   )
               )
           }
       }
   }

   struct ConfettiParticle: View {
       let color: Color

       var body: some View {
           Circle()
               .fill(color)
       }

       static func randomColor() -> Color {
           [.red, .yellow, .blue, .green, .pink, .purple, .orange].randomElement() ?? .blue
       }
   }

   struct ConfettiParticleData: Identifiable {
       let id: UUID
       let x: CGFloat
       let y: CGFloat
       let color: Color
       let delay: Double
       let size: CGFloat
       let scale: CGFloat
       let rotation: Double
       let opacity: Double
   }
