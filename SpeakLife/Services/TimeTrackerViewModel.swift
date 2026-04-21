//
//  TimeTracker.swift
//  SpeakLife
//
//  Created by Riccardo Washington on 5/11/23.
//

import Foundation

final class TimeTrackerViewModel: ObservableObject {
    
    @Published var startTime = Date()
    @Published var minutesPerDay: [Double] = []
    @Published var totalTimeValue = ""
    
    private var resetTimer: Timer?
    
    init() {
        minutesPerDay = UserDefaults.standard.array(forKey: "minutesPerDay") as? [Double] ?? []
        scheduleResetTimer()
        startTracking()
    }
    
    func startTracking() {
        startTime = Date()
        scheduleResetTimer()
    }
    
    func calculateElapsedTime() {
        let elapsedTime = Date().timeIntervalSince(startTime) / 60.0 // convert seconds to minutes
        minutesPerDay.append(elapsedTime)
        let (hours, minutes) = calculateTotalTime(minutesArray: minutesPerDay)
        DispatchQueue.main.async { [weak self] in
            
            if hours > 0 {
                self?.totalTimeValue = "\(hours) hours \(minutes) minutes"
            } else {
                self?.totalTimeValue = "\(minutes) minutes"
            }
        }
        
        // save to UserDefaults
        UserDefaults.standard.set(minutesPerDay, forKey: "minutesPerDay")
    }
    
    func calculateTotalTime(minutesArray: [Double]) -> (totalHours: Int, totalMinutes: Int) {
        let mostCurrent = minutesArray.last ?? 0.0
        //let totalMinutes = minutesArray.reduce(0, +)
        let totalHours = Int(mostCurrent) / 60
        let remainingMinutes = Int(mostCurrent) % 60
        return (totalHours, remainingMinutes)
    }
    
    private func scheduleResetTimer() {
        let calendar = Calendar.current
        let now = Date()
        
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: now)
        
        // Set the components to the next midnight
        components.setValue(23, for: .hour)
        components.setValue(59, for: .minute)
        components.setValue(59, for: .second)
        
        guard let nextMidnight = calendar.date(from: components)?.addingTimeInterval(1) else { return }
        
        let timeUntilMidnight = nextMidnight.timeIntervalSince(now)
        
        resetTimer = Timer.scheduledTimer(withTimeInterval: timeUntilMidnight, repeats: false) { [weak self] _ in
            self?.calculateElapsedTime()
            //self?.startTracking()
        }
    }
    
    //    static let totalElapseTimeKey = "totalElapseTimeKey"
    //    static let totalTimeArrayKey = "totalTimeKey"
    //
    //    @Published var totalTimeValue: String = ""
    //    @Published var startTime: Date
    //    @Published var elapsedTime: TimeInterval
    //
    //    private(set) var totalTimeInSeconds: [Double] = []
    //
    //    private(set) var totalTimeInMinutes: [Double] = []
    //
    //    private var resetTimer: Timer?
    //
    //    init() {
    //        self.startTime = Date()
    //
    //        let arrayOfSeconds = UserDefaults.standard.array(forKey: TimeTrackerViewModel.totalTimeArrayKey) as? [Double] ?? []
    //        self.totalTimeInMinutes = TimeTrackerViewModel.convertSecondsToMinutes(secondsArray: arrayOfSeconds)
    //        self.elapsedTime = arrayOfSeconds.reduce(0, +)
    //        //totalTime.last ?? 0.0
    //       // let totalSeconds =
    //
    //        let (hours, minutes, seconds) = TimeTrackerViewModel.convertSecondsToHoursMinutesSeconds(elapsedTime)
    //        self.totalTimeValue = "\(hours) hours, \(minutes) minutes, \(seconds) seconds"
    //
    //        // set up the timer to reset elapsedTime
    //        //scheduleResetTimer()
    //    }
    //
    //    private static func convertSecondsToHoursMinutesSeconds(_ seconds: Double) -> (hours: Int, minutes: Int, seconds: Int) {
    //        let hours = Int(seconds) / 3600
    //        let minutes = Int(seconds) % 3600 / 60
    //        let remainingSeconds = Int(seconds) % 60
    //        return (hours, minutes, remainingSeconds)
    //    }
    //
    //    private func updateTotalTimeValue(totalSeconds: Double) {
    //        let (hours, minutes, seconds) = TimeTrackerViewModel.convertSecondsToHoursMinutesSeconds(totalSeconds)
    //        self.totalTimeValue = "\(hours) hours, \(minutes) minutes, \(seconds) seconds"
    //    }
    //
    //    private static func convertSecondsToMinutes(secondsArray: [Double]) -> [Double] {
    //        return secondsArray.map { $0 / 60.0 }
    //    }
    //
    //    func calculateElapsedTime() {
    //        self.elapsedTime += Date().timeIntervalSince(self.startTime)
    //        self.startTime = Date()
    //        saveChanges()// reset the start time
    //    }
    //
    //    private func saveChanges() {
    //        if elapsedTime >= 1 {
    //            totalTimeInSeconds.append(elapsedTime)
    //            UserDefaults.standard.set(totalTimeInSeconds, forKey: TimeTrackerViewModel.totalTimeArrayKey)
    //            let minutesToAdd = TimeTrackerViewModel.convertSecondsToMinutes(secondsArray: [elapsedTime])
    //            totalTimeInMinutes += minutesToAdd
    //            UserDefaults.standard.set(totalTimeInMinutes.reduce(0, +), forKey: TimeTrackerViewModel.totalElapseTimeKey)
    //            updateTotalTimeValue(totalSeconds: elapsedTime)
    //        }
    //    }
    //
    //    private func scheduleResetTimer() {
    //        let calendar = Calendar.current
    //        let now = Date()
    //
    //        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: now)
    //
    //        // Set the components to the next midnight
    //        components.setValue(23, for: .hour)
    //        components.setValue(59, for: .minute)
    //        components.setValue(59, for: .second)
    //
    //        guard let nextMidnight = calendar.date(from: components)?.addingTimeInterval(1) else { return }
    //
    //        let timeUntilMidnight = nextMidnight.timeIntervalSince(now)
    //
    //        resetTimer = Timer.scheduledTimer(withTimeInterval: timeUntilMidnight, repeats: false) { [weak self] _ in
    //            self?.elapsedTime = 0
    //            self?.scheduleResetTimer()
    //        }
    //    }
}
