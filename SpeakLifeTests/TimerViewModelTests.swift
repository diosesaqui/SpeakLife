//
//  TimerViewModelTests.swift
//  SpeakLifeTests
//
//  Created by Riccardo Washington on 3/24/24.
//

import XCTest
@testable import SpeakLife

final class TimerViewModelTests: XCTestCase {

    func testCurrentStreakShouldBeTwo() {
        let sut = TimerViewModel()
        sut.currentStreak = 1
        let currentDate = Date()
        let calendar = Calendar.current
        
        let startOfToday = calendar.startOfDay(for: currentDate)
    
        let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday)

        sut.lastCompletedStreak = startOfYesterday
        XCTAssertFalse(sut.checkIfMidnightOfTomorrowHasPassedSinceLastCompletedStreak())
        XCTAssert(sut.currentStreak == 1)
        sut.completeMeditation()
        
        XCTAssert(sut.currentStreak == 2)
    }
    
    func testCurrentStreakShouldBeTwoFromToday() {
        let sut = TimerViewModel()
        sut.currentStreak = 1
        let currentDate = Date()
        let calendar = Calendar.current
        
        let startOfToday = calendar.startOfDay(for: currentDate)
    
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday)

        sut.lastCompletedStreak = startOfTomorrow
        XCTAssert(sut.currentStreak == 1)
        sut.completeMeditation()
        
        XCTAssert(sut.currentStreak == 2)
    }
    
    func testCurrentStreakShouldBeZero() {
        let sut = TimerViewModel()
        sut.currentStreak = 1
        let currentDate = Date()
        let calendar = Calendar.current
        
        let startOfToday = calendar.startOfDay(for: currentDate)
    
        let startOfTwoDaysAgo = calendar.date(byAdding: .day, value: -2, to: startOfToday)

        sut.lastCompletedStreak = startOfTwoDaysAgo
        XCTAssertTrue(sut.checkIfMidnightOfTomorrowHasPassedSinceLastCompletedStreak())
        sut.checkAndUpdateCompletionDate()
        XCTAssert(sut.currentStreak == 0)
        sut.completeMeditation()
        
        XCTAssert(sut.currentStreak == 1)
    }
}
