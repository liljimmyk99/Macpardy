//
//  GameTimerLoggingTests.swift
//  MacpardyTests
//
//  The timer logs start, pause, resume, reset, added time and expiry, never
//  each tick (#87).
//

import XCTest
@testable import Macpardy

@MainActor
final class GameTimerLoggingTests: XCTestCase {

    func testStartPauseResumeAndReset() {
        let timer = GameTimer(name: "Question timer", seconds: 15)

        let log = LogCapture.capture {
            timer.start()
            timer.addSeconds(-5)
            timer.stop()
            timer.start()
            timer.stop()
            timer.reset()
        }

        XCTAssertEqual(log.messages, [
            "state: Question timer started at 15.0s of 15.0s",
            "state: Question timer -5s: 15.0s → 10.0s",
            "state: Question timer paused at 10.0s",
            "state: Question timer resumed at 10.0s of 15.0s",
            "state: Question timer paused at 10.0s",
            "state: Question timer reset from 10.0s to 15.0s",
        ])
    }

    func testStoppingAStoppedTimerOrResettingAFullOneLogsNothing() {
        let timer = GameTimer(name: "Response timer", seconds: 5)
        let log = LogCapture.capture {
            timer.stop()
            timer.reset()
        }
        XCTAssertTrue(log.entries.isEmpty)
    }
}
