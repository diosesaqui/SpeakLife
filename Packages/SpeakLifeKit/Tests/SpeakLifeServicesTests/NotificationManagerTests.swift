//
//  NotificationManagerTests.swift
//  SpeakLifeTests
//
//  Created by Riccardo Washington on 12/31/23.
//

import XCTest
import SpeakLifeCore
@testable import SpeakLifeServices

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
        // Ten were asked for and ten come back, so there is no times[10]. Four
        // assertions reaching for [10] and [11] used to sit here, copy-pasted
        // from the twelve-count test above, contradicting this test's own
        // `times.count == 10` on the first line. They did not fail — they
        // trapped on Index out of range and took the whole test process down,
        // which is why every other suite in the run reported passing while
        // xcodebuild still printed ** TEST FAILED **.
        XCTAssertEqual(times.count, 10, "asking for ten must not hand back an eleventh")
    }


}
