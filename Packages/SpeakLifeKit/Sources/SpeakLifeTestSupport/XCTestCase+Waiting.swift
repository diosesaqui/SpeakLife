//
//  XCTestCase+Waiting.swift
//  SpeakLifeTestSupport
//

import Foundation
import XCTest

/// Two ways to wait that do not depend on a shared CI runner keeping time.
///
/// The pattern these replace was everywhere in this suite: create an
/// `XCTestExpectation`, fulfil it from `DispatchQueue.main.asyncAfter(0.6)`,
/// and `wait(for:timeout: 1.0)`. The expectation was never attached to the
/// thing under test — it was a sleep with a stopwatch on it, and the stopwatch
/// allowed 0.4s of slack.
///
/// That is not enough slack on a loaded macOS runner. Production schedules its
/// own `asyncAfter(0.5)` on the main queue and the test's timer queues behind
/// it, so the two delays serialise into the 1.0s budget with the view model's
/// work in between. `testAutoCompleteFirstTask_ShouldNotHappenOnFutureDays`
/// and `testHandlePersistentStoreRemoteChangeNotification` both went red on
/// main this way while passing locally. Nine more tests carried the same fuse
/// unlit.
///
/// These began life inside `EnhancedStreakViewModelTests.swift`, which worked
/// while the whole suite was one target. Splitting into `SpeakLifeCoreTests`,
/// `SpeakLifePersistenceTests` and `SpeakLifeServicesTests` made an extension
/// declared in one of them invisible to the other two — so the persistence
/// tests that called `waitUntil` and `drainMainQueue` stopped compiling. They
/// live here instead, in a target the test targets depend on.
///
/// This target is only ever a dependency of test targets, which is why it can
/// import XCTest without that leaking into the app.
extension XCTestCase {

    /// Spins the main run loop until `condition` holds, then returns at once.
    ///
    /// Fast when the machine is fast — it returns on the first poll that
    /// passes, not after a fixed sleep — and patient when the machine is
    /// loaded. The timeout is generous because it only ever costs anything on
    /// a genuine failure.
    public func waitUntil(_ description: String,
                          timeout: TimeInterval = 10,
                          file: StaticString = #filePath,
                          line: UInt = #line,
                          _ condition: () -> Bool) {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            guard Date() < deadline else {
                XCTFail("Timed out after \(timeout)s waiting for: \(description)",
                        file: file, line: line)
                return
            }
            // Running the main run loop is what lets main-queue work — the
            // `asyncAfter` production schedules — actually execute.
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.01))
        }
    }

    /// Lets scheduled main-queue work run for a fixed window, then returns.
    ///
    /// For asserting that something did NOT happen, which cannot be expressed
    /// as waiting for a condition. Unlike the old pattern there is no timeout
    /// racing the delay, so a slow runner makes this late rather than failed.
    public func drainMainQueue(for interval: TimeInterval) {
        let deadline = Date().addingTimeInterval(interval)
        while Date() < deadline {
            RunLoop.current.run(mode: .default, before: deadline)
        }
    }
}
