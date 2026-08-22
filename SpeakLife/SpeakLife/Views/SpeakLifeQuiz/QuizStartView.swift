import SwiftUI

struct QuizStartView: View {
    let quizTitle: String
    let questions: [QuizQuestion]
    @ObservedObject var progressManager: QuizProgressManager

    var body: some View {
        VStack(spacing: 30) {
            Text(quizTitle)
                .font(DS.Typography.title)
                .multilineTextAlignment(.center)
                .dsAppear(0)

            Text("Discover when and how to speak life through powerful Scripture truths.")
                .font(DS.Typography.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .dsAppear(0.06)

            Spacer()

            NavigationLink(destination: QuizQuestionView(progressManager: progressManager, quizTitle: quizTitle, questions: questions)) {
                Text("Start Lesson")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(DS.Gradient.brand)
                    .foregroundColor(.white)
                    .cornerRadius(15)
                    .padding(.horizontal)
            }
            .buttonStyle(.dsPressable(feel: .tapSolid))

            Spacer()
        }
        .padding()
        .onAppear {
            // The title used to BE the event name, which created one series per
            // quiz and — because the completion screen emitted the same name —
            // made starts and completions indistinguishable. Stable name, title
            // as a property, so completion rate is now measurable.
            AnalyticsService.shared.track(Event.quizStarted, parameters: [
                "quiz_title": quizTitle
            ])
        }
    }
        
}
