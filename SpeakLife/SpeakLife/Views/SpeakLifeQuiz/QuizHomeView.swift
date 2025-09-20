import SwiftUI
import Firebase
import Foundation

class QuizProgressManager: ObservableObject {
    @AppStorage("completedQuizTitlesRaw") private var completedRaw: String = ""

    @Published var completedQuizTitles: [String] = []

    init() {
        load()
    }

    private func load() {
        completedQuizTitles = (try? JSONDecoder().decode([String].self, from: Data(completedRaw.utf8))) ?? []
    }

    private func save() {
        if let data = try? JSONEncoder().encode(completedQuizTitles) {
            completedRaw = String(data: data, encoding: .utf8) ?? ""
        }
    }

    func markQuizComplete(_ title: String) {
        if !completedQuizTitles.contains(title) {
            completedQuizTitles.append(title)
            save()
        }
    }
    
    var levelName: String {
        switch completedQuizTitles.count {
        case 0: return "New Listener"
        case 1...2: return "Faith Builder"
        case 3...4: return "Word Warrior"
        case 5...6: return "Life Speaker"
        default: return "SpeakLife Master"
        }
    }

    var progress: Double {
        Double(completedQuizTitles.count) / Double(totalQuizCount)
    }

    var totalQuizCount: Int {
        QuizHomeView.quizzes.count 
    }
    
    func colorForLevel(_ level: String) -> Color {
        switch level {
        case "New Listener": return .gray
        case "Faith Builder": return .green
        case "Word Warrior": return .indigo
        case "Life Speaker": return .orange
        case "SpeakLife Master": return .yellow
        default: return .blue
        }
    }

    func iconForLevel(_ level: String) -> String {
        switch level {
        case "New Listener": return "ear.fill"
        case "Faith Builder": return "leaf.fill"
        case "Word Warrior": return "shield.fill"
        case "Life Speaker": return "megaphone.fill"
        case "SpeakLife Master": return "crown.fill"
        default: return "circle.fill"
        }
    }
}
struct QuizHomeView: View {
    @StateObject private var progressManager = QuizProgressManager()
    
    static let quizzes = [Quiz(title: "When to Speak Faith", questions: questions), Quiz(title:"How to Get & Stay Healed", questions: healingQuizQuestions), Quiz(title:"Who You Are in Christ", questions: identityQuizQuestions), Quiz(title:"How to Stay in Peace", questions: peaceQuizQuestions), Quiz(title:"The Power of Words", questions: wordsQuizQuestions), Quiz(title:"God’s Protection", questions: protectionQuizQuestions), Quiz(title:"Count it all Joy", questions: joyQuizQuestions), Quiz(title:"Trusting God With Your Destiny", questions: destinyQuizQuestions)]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 12) {
                        SkillLevelView(progressManager: progressManager)
                    }
                    .padding(.top)
                    ForEach(QuizHomeView.quizzes) { quiz in
                        NavigationLink(
                            destination: QuizStartView(
                                quizTitle: quiz.title,
                                questions: quiz.questions,
                                progressManager: progressManager
                            )
                        ) {
                            HStack {
                                QuizCardView(title: quiz.title)
                                if progressManager.completedQuizTitles.contains(quiz.title) {
                                    Image(systemName: "checkmark.seal.fill")
                                        .foregroundColor(.green)
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding()
            }
            .navigationTitle("SpeakLife Lessons")
        }
    }
}


struct QuizCardView: View {
    let title: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 25)
                .fill(LinearGradient(gradient: Gradient(colors: [.purple, .blue]), startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(radius: 10)
                .frame(height: 120)
                .overlay(
                    Text(title)
                        .font(.title2.bold())
                        .foregroundColor(.white)
                        .padding()
                )
        }
        .scaleEffect(1.0)
        .animation(.spring(), value: UUID())
    }
}
