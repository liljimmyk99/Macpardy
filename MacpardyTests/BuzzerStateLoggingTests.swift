//
//  BuzzerStateLoggingTests.swift
//  MacpardyTests
//
//  BuzzerState's state lines (#87), checked without a running server.
//

import BuzzerCore
import XCTest
@testable import Macpardy

@MainActor
final class BuzzerStateLoggingTests: XCTestCase {

    func testModeChangesAreLoggedOnceAndUnderBuzzer() async {
        let state = BuzzerState()

        let log = await LogCapture.capture {
            await state.setMode(.armed)
            await state.setMode(.armed)
            await state.setMode(.disabled)
        }

        XCTAssertEqual(log.messages, [
            "state: BuzzerState.mode: disabled → armed",
            "state: BuzzerState.mode: armed → disabled",
        ])
        XCTAssertTrue(log.entries.allSatisfy { $0.category == .buzzer })
    }

    func testLockoutNamesTheTeam() async {
        let state = BuzzerState()
        let team = Team(name: "Blue")
        await state.syncTeams([BuzzerTeam(team: team)])

        let log = await LogCapture.capture {
            await state.teamAnsweredWrong(team.id)
        }

        XCTAssertEqual(log.messages, ["state: Buzzer lockout: 'Blue' answered wrong; other teams re-armed"])
        XCTAssertEqual(log.entries.first?.teamName, "Blue")
    }

    func testJoinScreenToggleIsLogged() {
        let state = BuzzerState()
        let log = LogCapture.capture {
            state.isJoinScreenOnDisplay = true
            state.isJoinScreenOnDisplay = true
        }
        XCTAssertEqual(log.messages, ["state: BuzzerState.joinScreenOnDisplay: false → true"])
    }
}
