//
//  NotificationManagerTests.swift
//  SpeakLifeTests
//
//  Created by Riccardo Washington on 12/31/23.
//

import XCTest
@testable import SpeakLife

final class NotificationManagerTests: XCTestCase {

    func testGetHourMinute() {
        let sut = NotificationManager.shared
        //8 am 1 pm
        let times = sut.getHourMinute(startTime: 16, endTime: 26, count: 10)
        XCTAssert(times.count == 10)
        XCTAssert(times[0].hour == 8)
        XCTAssert(times[0].minute == 0)
        XCTAssert(times[1].hour == 8)
        XCTAssert(times[1].minute == 30)
        XCTAssert(times[2].hour == 9)
        XCTAssert(times[2].minute == 0)
        XCTAssert(times[3].hour == 9)
        XCTAssert(times[3].minute == 30)
        XCTAssert(times[4].hour == 10)
        XCTAssert(times[4].minute == 0)
        XCTAssert(times[5].hour == 10)
        XCTAssert(times[5].minute == 30)
        XCTAssert(times[6].hour == 11)
        XCTAssert(times[6].minute == 0)
        XCTAssert(times[7].hour == 11)
        XCTAssert(times[7].minute == 30)
        XCTAssert(times[8].hour == 12)
        XCTAssert(times[8].minute == 0)
        XCTAssert(times[9].hour == 12)
        XCTAssert(times[9].minute == 30)
    }
    
    func testGetHourMinuteTwelveCountOnlyTenSlots() {
        let sut = NotificationManager.shared
        //8 am 1 pm
        let times = sut.getHourMinute(startTime: 16, endTime: 26, count: 12)
        XCTAssert(times.count == 12)
        XCTAssert(times[0].hour == 8)
        XCTAssert(times[0].minute == 0)
        XCTAssert(times[1].hour == 8)
        XCTAssert(times[1].minute == 30)
        XCTAssert(times[2].hour == 9)
        XCTAssert(times[2].minute == 0)
        XCTAssert(times[3].hour == 9)
        XCTAssert(times[3].minute == 30)
        XCTAssert(times[4].hour == 10)
        XCTAssert(times[4].minute == 0)
        XCTAssert(times[5].hour == 10)
        XCTAssert(times[5].minute == 30)
        XCTAssert(times[6].hour == 11)
        XCTAssert(times[6].minute == 0)
        XCTAssert(times[7].hour == 11)
        XCTAssert(times[7].minute == 30)
        XCTAssert(times[8].hour == 12)
        XCTAssert(times[8].minute == 0)
        XCTAssert(times[9].hour == 12)
        XCTAssert(times[9].minute == 30)
        XCTAssertTrue(times[10].hour == 13)
        XCTAssert(times[10].minute == 0)
        XCTAssert(times[11].hour == 13)
        XCTAssert(times[11].minute == 0)
    }
    
    
    func testGetHourMinute5CountOnlyTenSlots() {
        let sut = NotificationManager.shared
        //8 am 1 pm
        let times = sut.getHourMinute(startTime: 16, endTime: 26, count: 5)
        XCTAssert(times.count == 5)
        XCTAssert(times[0].hour == 8)
        XCTAssert(times[0].minute == 0)
        XCTAssert(times[1].hour == 8)
        XCTAssert(times[1].minute == 30)
        XCTAssert(times[2].hour == 9)
        XCTAssert(times[2].minute == 0)
        XCTAssert(times[3].hour == 9)
        XCTAssert(times[3].minute == 30)
        XCTAssert(times[4].hour == 10)
        XCTAssert(times[4].minute == 0)
    }
    
    func testGetHourMinuteTenCountOnlyTwentySlots() {
        let sut = NotificationManager.shared
        //8 am 6 pm
        let times = sut.getHourMinute(startTime: 16, endTime: 36, count: 10)
        XCTAssert(times.count == 10)
        XCTAssert(times[0].hour == 8)
        XCTAssert(times[0].minute == 0)
        XCTAssert(times[1].hour == 8)
        XCTAssert(times[1].minute == 30)
        XCTAssert(times[2].hour == 9)
        XCTAssert(times[2].minute == 0)
        XCTAssert(times[3].hour == 9)
        XCTAssert(times[3].minute == 30)
        XCTAssert(times[4].hour == 10)
        XCTAssert(times[4].minute == 0)
        XCTAssert(times[5].hour == 10)
        XCTAssert(times[5].minute == 30)
        XCTAssert(times[6].hour == 11)
        XCTAssert(times[6].minute == 0)
        XCTAssert(times[7].hour == 11)
        XCTAssert(times[7].minute == 30)
        XCTAssert(times[8].hour == 12)
        XCTAssert(times[8].minute == 0)
        XCTAssert(times[9].hour == 12)
        XCTAssert(times[9].minute == 30)
        XCTAssertTrue(times[10].hour == 13)
        XCTAssert(times[10].minute == 0)
        XCTAssert(times[11].hour == 18)
        XCTAssert(times[11].minute == 0)
    }


}
