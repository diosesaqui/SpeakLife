//
//  StreakDetails.swift
//  SpeakLife
//
//  Created by Riccardo Washington on 3/17/24.
//

import SwiftUI


struct DayCompletion: Codable {
    let date: Date
    var isCompleted: Bool
}

final class StreakViewModel: ObservableObject {
    @Published var weekCompletions: [DayCompletion] = []
    
    @AppStorage("currentStreak") var currentStreak = 0
    @AppStorage("longestStreak") var longestStreak = 0
    @AppStorage("totalDaysCompleted") var totalDaysCompleted = 0
    
    var hasCurrentStreak: Bool {
        currentStreak > 0
    }
    
    var progress: Double {
        let completed = weekCompletions.filter { $0.isCompleted }.count
        return Double(completed) / 7.0
    }
    
    @Published var titleText: String = ""
    @Published var subTitleText: String = ""
    @Published var subTitleDetailText: String = ""
    
    init() {
        loadFromUserDefaults()
        NotificationCenter.default.addObserver(self, selector: #selector(eventCompletedReceived), name: Notification.Name("StreakCompleted"), object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func eventCompletedReceived() {
        completeEvent()
    }
    
    func updateCompletionStatus(for date: Date, isCompleted: Bool) {
        if let index = weekCompletions.firstIndex(where: { $0.date == date }) {
            weekCompletions[index].isCompleted = isCompleted
            saveToUserDefaults()
        }
    }
    
    // Call this method when an event is completed
    func markDayAsCompleted(for date: Date) {
        updateCompletionStatus(for: date, isCompleted: true)
    }
    
    func completeEvent() {
        let today = Calendar.current.startOfDay(for: Date())
        markDayAsCompleted(for: today)
        
    }
    
    
    func saveToUserDefaults() {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(weekCompletions) {
            UserDefaults.standard.set(encoded, forKey: "weekCompletions")
        }
    }
    
    func loadFromUserDefaults() {
        let titleText = currentStreak == 1 ? "\(currentStreak) day" : "\(currentStreak) days"
        let subTitleText = longestStreak == 1 ? "\(longestStreak) day" : "\(longestStreak) days"
        let subTitleDetailText = totalDaysCompleted == 1 ? "\(totalDaysCompleted) day" : "\(totalDaysCompleted) days"
        self.titleText = "\(titleText)"
        self.subTitleText = "\(subTitleText)"
        self.subTitleDetailText = "\(subTitleDetailText)"
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!
        
        
        if let savedCompletions = UserDefaults.standard.object(forKey: "weekCompletions") as? Data {
            let decoder = JSONDecoder()
            
            if let loadedCompletions = try? decoder.decode([DayCompletion].self, from: savedCompletions) {
                weekCompletions = (0..<7).compactMap { offset in
                    let currentDate = calendar.date(byAdding: .day, value: offset, to: weekStart)!
                    if let loaded = loadedCompletions.first(where: { $0.date == currentDate }) {
                        return loaded
                    } else {
                        return DayCompletion(date: currentDate, isCompleted: false)
                    }
                }
            }
            
        } else {
            weekCompletions = (0..<7).compactMap { offset in
                let currentDate = calendar.date(byAdding: .day, value: offset, to: weekStart)!
                // Initially set isCompleted to false
                return DayCompletion(date: currentDate, isCompleted: false)
            }
        }
    }
}

struct StreakView: View {
    let streak: [Bool]
    let daysOfWeek = ["S", "M", "T", "W", "T", "F", "S"]
    
    var body: some View {
        HStack {
            ForEach(0..<daysOfWeek.count, id: \.self) { index in
                VStack {
                    Text(daysOfWeek[index])
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Image(systemName: streak[index] ? "heart.fill" : "circle")
                        .foregroundColor(streak[index] ? .red : .gray)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .shadow(radius: 5)
    }
}

//struct Sparkles: View {
//    var body: some View {
//        ForEach(0..<10, id: \.self) { _ in
//            Circle()
//                .fill(Color.white.opacity(0.6))
//                .frame(width: CGFloat.random(in: 2...5), height: CGFloat.random(in: 2...5))
//                .position(x: CGFloat.random(in: 20...100), y: CGFloat.random(in: 20...100))
//                .opacity(Double.random(in: 0.5...1.0))
//                .animation(Animation.easeInOut(duration: Double.random(in: 0.6...1.2)).repeatForever(), value: UUID())
//        }
//    }
//}


struct ProgressRing: View {
    let progress: Double
    let showSparkles: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: 12)
                .opacity(0.2)
                .foregroundColor(.white)
                .frame(width: 120, height: 120)

            Circle()
                .trim(from: 0.0, to: progress)
                .stroke(style: StrokeStyle(lineWidth: 12, lineCap: .round, lineJoin: .round))
                .foregroundColor(.green)
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 1.0), value: progress)
                .frame(width: 120, height: 120)

            VStack(spacing: 4) {
                Text("Progress")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                Text("\(Int(progress * 100))%")
                    .font(.title3.bold())
                    .foregroundColor(.white)
            }

            if showSparkles {
                Sparkles()
            }
        }
    }
}


struct HandleBar: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(Color.white.opacity(0.3))
            .frame(width: 40, height: 5)
    }
}

struct StatBlock: View {
    let title: String
    let value: String

    let titleFont = Font.system(size: 22, weight: .semibold, design: .rounded)
    let bodyFont = Font.system(size: 18, weight: .medium, design: .rounded)

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(titleFont)

            HStack(spacing: 6) {
                Text(value)
                    .font(bodyFont)
                Image(systemName: "bolt.fill")
                    .resizable()
                    .frame(width: 16, height: 20)
            }
        }
    }
}



struct StreakStatsView: View {
    let viewModel: StreakViewModel

    let titleFont = Font.system(size: 22, weight: .semibold, design: .rounded)
    let bodyFont = Font.system(size: 18, weight: .medium, design: .rounded)

    var body: some View {
        VStack(spacing: 12) {
            StatBlock(title: "Current streak 🔥", value: viewModel.titleText)
            StatBlock(title: "Longest streak 🥇", value: viewModel.subTitleText)
            VStack(spacing: 4) {
                Text("Total days completed 📈")
                    .font(titleFont)
                Text(viewModel.subTitleDetailText)
                    .font(bodyFont)
            }
        }
    }
}



struct StreakSheet: View {
    @Binding var isShown: Bool
    @ObservedObject var streakViewModel: StreakViewModel

    private var progress: Double {
        streakViewModel.progress
    }

    private var showSparkles: Bool {
        progress >= 0.8
    }

    var body: some View {
        ZStack {
            Gradients().speakLifeCYOCell
                .ignoresSafeArea()

            VStack(spacing: 20) {
                HandleBar()
                    .padding(.top, 12)

                StreakView(streak: streakViewModel.weekCompletions.map(\.isCompleted))
                    .padding(.top, 8)

                ProgressRing(progress: progress, showSparkles: showSparkles)
                    .padding(.top, 12)

                StreakStatsView(viewModel: streakViewModel)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
            }
        }
        .foregroundColor(.white)
        .onAppear {
            streakViewModel.loadFromUserDefaults()
        }
    }
}
