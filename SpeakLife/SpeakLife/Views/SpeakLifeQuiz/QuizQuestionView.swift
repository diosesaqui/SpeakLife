import SwiftUI
import FirebaseAnalytics

struct QuizQuestionView: View {
    @State private var selectedIndex: Int? = nil
    @State private var showFeedback = false
    @State private var questionIndex = 0
    @State private var showExplanation = false
    @State private var showCelebration = false
    @State private var isAnswerCorrect = false
    @State private var quizCompleted = false
    @ObservedObject var progressManager: QuizProgressManager

    let quizTitle: String
    let questions: [(String, [String], Int, String)]

    var body: some View {
        if quizCompleted {
            QuizCompletionView().onAppear {
                progressManager.markQuizComplete(quizTitle)
                Analytics.logEvent(quizTitle.replacingOccurrences(of: " ", with: ""), parameters: nil)
            }
        } else if showExplanation {
                if !isAnswerCorrect {
                    QuizExplanationView(explanation: questions[questionIndex].3) {
                    resetFeedback()
                }
            }
        } else {
            VStack(spacing: 20) {
                ProgressView(value: Double(questionIndex + 1), total: Double(questions.count))
                    .progressViewStyle(LinearProgressViewStyle(tint: .cyan))
                    .padding()
                
                Image("appIconDisplay")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 180)
                        .cornerRadius(20)
                        .shadow(radius: 5)
                        .padding(.horizontal)
                

                Text(questions[questionIndex].0)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)

                ForEach(0..<4) { index in
                    Button(action: {
                        withAnimation {
                            selectedIndex = index
                            showFeedback = true
                            isAnswerCorrect = index == questions[questionIndex].2
                            if isAnswerCorrect {
                                showCelebration = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                                    showCelebration = false
                                    nextQuestion()
                                }
                            } else {
                                showExplanation = true
                            }
                        }
                    }) {
                        Text(questions[questionIndex].1[index])
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(buttonColor(for: index))
                            .foregroundColor(.cyan)
                            .cornerRadius(10)
                    }
                    .disabled(showFeedback)
                }

                if showCelebration {
                    QuizConfettiView()
    
                }

            }
            .padding([.leading, .trailing])
        }
    }

    private func buttonColor(for index: Int) -> Color {
        guard let selected = selectedIndex else { return Color.gray.opacity(0.2) }
        if index == selected {
            return selected == questions[questionIndex].2 ? Color.green : Color.red
        }
        return Color.gray.opacity(0.2)
    }

    private func nextQuestion() {
        if questionIndex + 1 >= questions.count {
            quizCompleted = true
        } else {
            questionIndex = (questionIndex + 1) % questions.count
            resetFeedback()
        }
    }

    private func resetFeedback() {
        selectedIndex = nil
        showFeedback = false
        showExplanation = false
        showCelebration = false
        isAnswerCorrect = false
    }
}
