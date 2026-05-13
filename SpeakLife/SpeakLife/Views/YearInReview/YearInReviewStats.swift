//
//  YearInReviewStats.swift
//  SpeakLife
//
//  Rolls up a calendar year's worth of BurstCompletion records into the
//  numbers shown on the Year in Review slides.
//

import Foundation

struct YearInReviewStats: Identifiable {
    var id: Int { year }
    let year: Int
    let daysActive: Int
    let longestStreakInYear: Int
    let bestMonth: (name: String, count: Int)?
    let totalDeclarationsSpoken: Int
    let currentStreak: Int

    /// Recap is meaningful only if the user showed up at all this year.
    var hasMeaningfulActivity: Bool { daysActive >= 1 }

    /// Days active expressed as a percent of the calendar year.
    var percentOfYear: Int {
        let calendar = Calendar.current
        let yearStart = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) ?? Date()
        let daysInYear = calendar.range(of: .day, in: .year, for: yearStart)?.count ?? 365
        return Int((Double(daysActive) / Double(daysInYear)) * 100)
    }

    /// Builds the stats by filtering BurstCompletionTracker.shared.completions
    /// down to a single calendar year. We pull `currentStreak` from the same
    /// source so it matches what the user sees on their streak screen.
    static func build(for year: Int) -> YearInReviewStats {
        let calendar = Calendar.current
        let components = DateComponents(year: year, month: 1, day: 1)
        let yearStart = calendar.date(from: components) ?? Date()
        let yearEnd = calendar.date(byAdding: .year, value: 1, to: yearStart) ?? Date()

        let inYear = BurstCompletionTracker.shared.completions.filter {
            $0.date >= yearStart && $0.date < yearEnd
        }

        let uniqueDayStarts = Set(inYear.map { calendar.startOfDay(for: $0.date) })
        let daysActive = uniqueDayStarts.count

        let longest = longestConsecutiveRun(in: uniqueDayStarts, calendar: calendar)

        let bestMonth = bestMonth(in: inYear, calendar: calendar)

        let totalDeclarations = inYear.map { $0.declarationCount }.reduce(0, +)

        return YearInReviewStats(
            year: year,
            daysActive: daysActive,
            longestStreakInYear: longest,
            bestMonth: bestMonth,
            totalDeclarationsSpoken: totalDeclarations,
            currentStreak: BurstCompletionTracker.shared.currentStreak
        )
    }

    private static func longestConsecutiveRun(in dayStarts: Set<Date>,
                                              calendar: Calendar) -> Int {
        guard !dayStarts.isEmpty else { return 0 }
        let sorted = dayStarts.sorted()
        var longest = 1
        var current = 1
        for i in 1..<sorted.count {
            let prev = sorted[i - 1]
            let next = sorted[i]
            if let oneDayLater = calendar.date(byAdding: .day, value: 1, to: prev),
               calendar.isDate(oneDayLater, inSameDayAs: next) {
                current += 1
                longest = max(longest, current)
            } else {
                current = 1
            }
        }
        return longest
    }

    private static func bestMonth(in completions: [BurstCompletion],
                                  calendar: Calendar) -> (name: String, count: Int)? {
        guard !completions.isEmpty else { return nil }

        var perMonthDays: [Int: Set<Date>] = [:]
        for completion in completions {
            let month = calendar.component(.month, from: completion.date)
            perMonthDays[month, default: []].insert(calendar.startOfDay(for: completion.date))
        }

        guard let top = perMonthDays.max(by: { $0.value.count < $1.value.count }),
              top.value.count > 0 else { return nil }

        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL"
        let monthDate = calendar.date(from: DateComponents(month: top.key)) ?? Date()
        let name = formatter.string(from: monthDate)
        return (name: name, count: top.value.count)
    }
}
