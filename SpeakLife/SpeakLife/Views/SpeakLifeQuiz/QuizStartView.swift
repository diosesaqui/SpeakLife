import SwiftUI
import FirebaseAnalytics

struct QuizStartView: View {
    let quizTitle: String
    let questions: [(String, [String], Int, String)]
    @ObservedObject var progressManager: QuizProgressManager

    var body: some View {
        VStack(spacing: 30) {
            Text(quizTitle)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)

            Text("Discover when and how to speak life through powerful Scripture truths.")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            NavigationLink(destination: QuizQuestionView(progressManager: progressManager, quizTitle: quizTitle, questions: questions)) {
                Text("Start Lesson")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(15)
                    .padding(.horizontal)
            }

            Spacer()
        }
        .padding()
        .onAppear {
            Analytics.logEvent(quizTitle.replacingOccurrences(of: " ", with: ""), parameters: nil)
        }
    }
        
}
