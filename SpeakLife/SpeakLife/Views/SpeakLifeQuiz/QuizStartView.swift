import SwiftUI
import FirebaseAnalytics

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
            AnalyticsService.shared.track(quizTitle.replacingOccurrences(of: " ", with: ""))
        }
    }
        
}
