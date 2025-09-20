//
//  TimeSlots.swift
//  Dios Es Aqui
//
//  Created by Riccardo Washington on 2/8/22.
//

import Foundation


final class TimeSlots {
    
    
    static func getTimeSlots() -> [String] {
        var timeSlots = [Double]()
        let firstTime: Double = 0.0
        let lastTime: Double = 24
        let slotIncrement = 0.5
        let numberOfSlots = Double((lastTime - firstTime) / slotIncrement)
        
        var i: Double = 0
        while Double(timeSlots.count) <= numberOfSlots {
            timeSlots.append(firstTime + i*slotIncrement)
            i += 1
        }
        
        let dateComponentsFormatter = DateComponentsFormatter()
        dateComponentsFormatter.unitsStyle = .positional
        
        
        var times = timeSlots.compactMap{dateComponentsFormatter.string(from: $0 * 60)}
        times[0] = "0:00"
        times[1] = "0:30"
        
        
        let dateFormatter = DateFormatter()
        dateFormatter.timeStyle = .medium
        dateFormatter.dateFormat = "HH:mm"
        dateFormatter.timeZone = TimeZone.autoupdatingCurrent
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        let amTimes = times.compactMap { dateFormatter.date(from: $0) }
        
        dateFormatter.dateFormat = "h:mm a"
        
        let stringAmTimes = amTimes.compactMap { dateFormatter.string(from: $0) }
        
        return stringAmTimes
    }
    
    static func getDateTimeSlots() -> [Date] {
        var timeSlots = [Double]()
        let firstTime: Double = 0.0
        let lastTime: Double = 24
        let slotIncrement = 0.5
        let numberOfSlots = Double((lastTime - firstTime) / slotIncrement)
        
        var i: Double = 0
        while Double(timeSlots.count) <= numberOfSlots {
            timeSlots.append(firstTime + i*slotIncrement)
            i += 1
        }
        
        let dateComponentsFormatter = DateComponentsFormatter()
        dateComponentsFormatter.unitsStyle = .positional
        
        var times = timeSlots.compactMap{dateComponentsFormatter.string(from: $0 * 60)}
        times[0] = "0:00"
        times[1] = "0:30"
        
        let dateFormatter = DateFormatter()
        dateFormatter.timeStyle = .short
        dateFormatter.dateFormat = "HH:mm"
        dateFormatter.timeZone = TimeZone.autoupdatingCurrent
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        let amTimes = times.compactMap { dateFormatter.date(from: $0) }
        
        return amTimes
    }
}
