//
//  StructuredDayView.swift
//  SpeakLife
//
//  Modern sequential card-based daily checklist.
//  Inspired by: Fabulous (hero card), Duolingo (progress ring),
//  Headspace (featured content), Apple Activity Rings (ring close = dopamine).
//

import SwiftUI

// MARK: - Progress Ring

struct DayProgressRing: View {
    let completed: Int
    let total: Int
    let streakCount: Int
    @State private var animatedProgress: CGFloat = 0

    private var progress: CGFloat { total > 0 ? CGFloat(completed) / CGFloat(total) : 0 }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 8)
                    .frame(width: 88, height: 88)
                Circle()
                    .trim(from: 0, to: animatedProgress)
                    .stroke(
                        AngularGradient(gradient: Gradient(colors: [Color.green.opacity(0.7), Color.green]), center: .center),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 88, height: 88)
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 1) {
                    Text("\(completed)")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("of \(total)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            if streakCount > 0 {
                HStack(spacing: 4) {
                    Text("🔥").font(.system(size: 13))
                    Text("\(streakCount) day streak")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Capsule().fill(Color.orange.opacity(0.12)))
            }
        }
        .onAppear { withAnimation(.easeOut(duration: 0.9)) { animatedProgress = progress } }
        .onChange(of: completed) { _ in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { animatedProgress = progress }
        }
    }
}

// MARK: - Week Streak Strip
//
// Week-at-a-glance row (S M T W T F S) modeled on Apple Fitness / Duolingo /
// Haven. Visualizing the week so far is one of the strongest return-drivers in
// habit apps: completed days read as earned, today is the obvious next move,
// and a gap creates gentle "don't break it" pressure. Backed by real per-day
// completion history from BurstCompletionTracker, so it never lies.

struct WeekStreakStrip: View {
    let currentStreak: Int
    @ObservedObject private var tracker = BurstCompletionTracker.shared
    private let calendar = Calendar.current

    private struct DayCell: Identifiable {
        let id = UUID()
        let label: String
        let isToday: Bool
        let isCompleted: Bool
        let isFuture: Bool
    }

    private var days: [DayCell] {
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today) // 1 = Sunday
        guard let startOfWeek = calendar.date(byAdding: .day, value: -(weekday - 1), to: today) else { return [] }
        let symbols = ["S", "M", "T", "W", "T", "F", "S"]

        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: startOfWeek) else { return nil }
            let completed = tracker.completions.contains { calendar.isDate($0.date, inSameDayAs: date) }
            return DayCell(
                label: symbols[offset],
                isToday: calendar.isDate(date, inSameDayAs: today),
                isCompleted: completed,
                isFuture: date > today
            )
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(days) { day in
                VStack(spacing: 6) {
                    Text(day.label)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(day.isFuture ? 0.3 : 0.6))
                    ZStack {
                        Circle()
                            .fill(day.isCompleted ? Color.orange.opacity(0.9) : Color.white.opacity(0.08))
                            .frame(width: 30, height: 30)
                        if day.isToday {
                            Circle()
                                .stroke(Color.white.opacity(0.9), lineWidth: 2)
                                .frame(width: 30, height: 30)
                        }
                        if day.isCompleted {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                        } else if !day.isFuture {
                            Circle()
                                .fill(Color.white.opacity(0.18))
                                .frame(width: 5, height: 5)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(day.isCompleted ? "\(day.label), completed" : day.label)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.04)))
    }
}

// MARK: - Hero Card

struct NextUpTaskCard: View {
    let task: DailyTask
    let onNavigate: (DailyTask) -> Void
    let onToggle: (String) -> Void
    @State private var isPressed = false

    private var cardGradient: LinearGradient {
        let colors: [Color]
        switch task.navigationDestination {
        case .burst:       colors = [Color(hex: "#7C3AED"), Color(hex: "#4F46E5")]
        case .devotional:  colors = [Color(hex: "#0EA5E9"), Color(hex: "#0369A1")]
        case .audioTab:    colors = [Color(hex: "#059669"), Color(hex: "#065F46")]
        case .none:        colors = [Color(hex: "#B45309"), Color(hex: "#78350F")]
        }
        return LinearGradient(gradient: Gradient(colors: colors), startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var ctaLabel: String {
        switch task.navigationDestination {
        case .burst:      return "Start Burst →"
        case .devotional: return "Open Devotional →"
        case .audioTab:   return "Listen Now →"
        case .none:       return "Complete →"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("NEXT UP")
                    .font(.system(size: 10, weight: .bold)).tracking(1.5)
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
                Text("\(task.estimatedMinutes) min")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(Color.white.opacity(0.12)))
            }
            .padding(.horizontal, 20).padding(.top, 18)

            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Color.white.opacity(0.15)).frame(width: 52, height: 52)
                    Image(systemName: task.icon).font(.system(size: 24)).foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.system(size: 19, weight: .bold)).foregroundColor(.white).lineLimit(2)
                    Text(task.description)
                        .font(.system(size: 13)).foregroundColor(.white.opacity(0.75)).lineLimit(2)
                }
            }
            .padding(.horizontal, 20).padding(.top, 14)

            Spacer(minLength: 16)

            HStack {
                Button(action: { UIImpactFeedbackGenerator(style: .medium).impactOccurred(); onNavigate(task) }) {
                    Text(ctaLabel)
                        .font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                        .padding(.horizontal, 20).padding(.vertical, 11)
                        .background(Capsule().fill(Color.white.opacity(0.2)))
                }
                Spacer()
                Button(action: { onToggle(task.id) }) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 26)).foregroundColor(.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 20).padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity, minHeight: 160)
        .background(cardGradient)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(.easeOut(duration: 0.12), value: isPressed)
    }
}

// MARK: - Compact Rows

struct CompletedTaskRow: View {
    let task: DailyTask
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.green.opacity(0.15)).frame(width: 36, height: 36)
                Image(systemName: "checkmark").font(.system(size: 14, weight: .bold)).foregroundColor(.green)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .strikethrough(true, color: .white.opacity(0.3))
                if let completedAt = task.completedAt {
                    Text("Done at \(DateFormatter.timeFormatter.string(from: completedAt))")
                        .font(.system(size: 11)).foregroundColor(.white.opacity(0.3))
                }
            }
            Spacer()
            Text(task.category.emoji).font(.system(size: 16)).opacity(0.5)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.03)))
    }
}

struct UpcomingTaskRow: View {
    let task: DailyTask
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.06)).frame(width: 36, height: 36)
                Image(systemName: task.icon).font(.system(size: 14)).foregroundColor(.white.opacity(0.4))
            }
            Text(task.title).font(.system(size: 14, weight: .medium)).foregroundColor(.white.opacity(0.4))
            Spacer()
            Text("\(task.estimatedMinutes)m").font(.system(size: 11)).foregroundColor(.white.opacity(0.3))
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.02)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }
}

// MARK: - Celebration

struct DayCelebrationView: View {
    let streakCount: Int
    let onDismiss: () -> Void
    @State private var scale: CGFloat = 0.7
    @State private var opacity: CGFloat = 0

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("🙌").font(.system(size: 72)).scaleEffect(scale).opacity(opacity)
            VStack(spacing: 8) {
                Text("Day Complete!").font(.system(size: 28, weight: .bold)).foregroundColor(.white)
                Text("You showed up for your faith today.")
                    .font(.system(size: 16)).foregroundColor(.white.opacity(0.7)).multilineTextAlignment(.center)
            }.opacity(opacity)
            if streakCount > 0 {
                HStack(spacing: 8) {
                    Text("🔥").font(.system(size: 24))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(streakCount) day streak").font(.system(size: 20, weight: .bold)).foregroundColor(.orange)
                        Text("Keep going tomorrow").font(.system(size: 13)).foregroundColor(.white.opacity(0.6))
                    }
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.orange.opacity(0.12))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.orange.opacity(0.25), lineWidth: 1)))
                .opacity(opacity)
            }
            Spacer()
            Button(action: onDismiss) {
                Text("Done").font(.system(size: 17, weight: .semibold)).foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.green.opacity(0.3)))
                    .padding(.horizontal, 24)
            }.opacity(opacity).padding(.bottom, 32)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { scale = 1.0; opacity = 1.0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
    }
}

// MARK: - Main View

struct StructuredDayView: View {
    let tasks: [DailyTask]
    let streakCount: Int
    let onToggle: (String) -> Void
    let onNavigate: (DailyTask) -> Void
    let onAllComplete: () -> Void

    private var completedTasks: [DailyTask] { tasks.filter { $0.isCompleted } }
    private var incompleteTasks: [DailyTask] { tasks.filter { !$0.isCompleted } }
    private var nextTask: DailyTask? { incompleteTasks.first }
    private var upcomingTasks: [DailyTask] { incompleteTasks.dropFirst().map { $0 } }
    private var allDone: Bool { tasks.allSatisfy { $0.isCompleted } }

    var body: some View {
        VStack(spacing: 16) {
            if allDone {
                DayCelebrationView(streakCount: streakCount, onDismiss: onAllComplete)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.9).combined(with: .opacity),
                        removal: .opacity))
            } else {
                DayProgressRing(completed: completedTasks.count, total: tasks.count, streakCount: streakCount)
                    .padding(.top, 8)

                if let next = nextTask {
                    NextUpTaskCard(task: next, onNavigate: onNavigate, onToggle: onToggle)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.95).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)))
                        .id(next.id)
                }

                if !upcomingTasks.isEmpty {
                    VStack(spacing: 6) {
                        HStack {
                            Text("UP NEXT").font(.system(size: 10, weight: .bold)).tracking(1.5)
                                .foregroundColor(.white.opacity(0.35))
                            Spacer()
                        }.padding(.horizontal, 4)
                        ForEach(upcomingTasks) { UpcomingTaskRow(task: $0) }
                    }
                }

                if !completedTasks.isEmpty {
                    VStack(spacing: 6) {
                        HStack {
                            Text("COMPLETED").font(.system(size: 10, weight: .bold)).tracking(1.5)
                                .foregroundColor(.white.opacity(0.35))
                            Spacer()
                        }.padding(.horizontal, 4)
                        ForEach(completedTasks) { task in
                            CompletedTaskRow(task: task)
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                    }
                }
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: tasks.map { $0.isCompleted })
    }
}
