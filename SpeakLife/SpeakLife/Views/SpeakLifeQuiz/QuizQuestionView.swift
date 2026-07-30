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
    let questions: [QuizQuestion]

    var body: some View {
        if quizCompleted {
            QuizCompletionView().onAppear {
                progressManager.markQuizComplete(quizTitle)
                AnalyticsService.shared.track(quizTitle.replacingOccurrences(of: " ", with: ""))
            }
        } else if showExplanation {
                if !isAnswerCorrect {
                    QuizExplanationView(explanation: questions[questionIndex].explanation) {
                    resetFeedback()
                }
            }
        } else {
            // Scrolls when content exceeds the screen (small devices, large
            // Dynamic Type) so answer buttons are never clipped or unreachable.
            GeometryReader { geo in
                ZStack {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {
                            ProgressView(value: Double(questionIndex + 1), total: Double(questions.count))
                                .progressViewStyle(LinearProgressViewStyle(tint: .cyan))
                                .padding()
                                .dsAppear(0)

                            Image("appIconDisplay")
                                .resizable()
                                .scaledToFit()
                                .frame(height: geo.size.height < 700 ? 120 : 180)
                                .cornerRadius(20)
                                .shadow(radius: 5)
                                .padding(.horizontal)
                                .dsAppear(0.06)

                            Text(questions[questionIndex].question)
                                .font(DS.Typography.headline)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                                .dsAppear(0.12)

                            ForEach(0..<4) { index in
                                Button(action: {
                                    withAnimation {
                                        selectedIndex = index
                                        showFeedback = true
                                        isAnswerCorrect = index == questions[questionIndex].correctAnswerIndex
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
                                    Text(questions[questionIndex].answers[index])
                                        .padding()
                                        .frame(maxWidth: .infinity)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .background(buttonColor(for: index))
                                        .foregroundColor(.cyan)
                                        .cornerRadius(10)
                                }
                                .buttonStyle(.dsPressable(feel: .tapSolid))
                                .disabled(showFeedback)
                            }
                        }
                        .padding([.leading, .trailing])
                        .padding(.bottom, 24)
                    }

                    if showCelebration {
                        QuizConfettiView()
                            .allowsHitTesting(false)
                    }
                }
            }
        }
    }

    private func buttonColor(for index: Int) -> Color {
        guard let selected = selectedIndex else { return Color.gray.opacity(0.2) }
        if index == selected {
            return selected == questions[questionIndex].correctAnswerIndex ? Color.green : Color.red
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
