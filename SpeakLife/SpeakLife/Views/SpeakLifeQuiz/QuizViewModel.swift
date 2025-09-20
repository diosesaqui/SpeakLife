//
//  QuizViewModel.swift
//  SpeakLife
//
//  Created by Riccardo Washington on 5/13/25.
//

import SwiftUI

class QuizViewModel: ObservableObject {
    @Published var currentQuestionIndex = 0
    @Published var selectedAnswerIndex: Int? = nil
    @Published var showExplanation = false
    @Published var isQuizComplete = false
    
    let quiz: Quiz

    init(quiz: Quiz) {
        self.quiz = quiz
    }

    var currentQuestion: (String, [String], Int, String) {
        quiz.questions[currentQuestionIndex]
    }

    var progress: Double {
        Double(currentQuestionIndex + 1) / Double(quiz.questions.count)
    }

    func selectAnswer(index: Int) {
        selectedAnswerIndex = index
        showExplanation = true
    }

    func nextQuestion() {
        if currentQuestionIndex + 1 < quiz.questions.count {
            currentQuestionIndex += 1
            selectedAnswerIndex = nil
            showExplanation = false
        } else {
            isQuizComplete = true
        }
    }

    func resetQuiz() {
        currentQuestionIndex = 0
        selectedAnswerIndex = nil
        showExplanation = false
        isQuizComplete = false
    }
}
