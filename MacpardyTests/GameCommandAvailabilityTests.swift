//
//  GameCommandAvailabilityTests.swift
//  MacpardyTests
//

import XCTest
@testable import Macpardy

@MainActor
final class GameCommandAvailabilityTests: XCTestCase {

    private func availability(_ phase: GamePhase, hasGame: Bool = true) -> GameCommandAvailability {
        GameCommandAvailability(phase: phase, hasSelectedGame: hasGame)
    }

    func testBoardOffersRoundNavigationOnly() {
        let board = availability(.board)
        XCTAssertTrue(board.canGoToFinal)
        XCTAssertTrue(board.canAdvanceRound)
        XCTAssertFalse(board.canReturnToBoard)
        XCTAssertFalse(board.canRevealAnswer)
        XCTAssertFalse(board.canControlTimer)
    }

    func testQuestionOffersAnswerAndTimer() {
        let question = availability(.question)
        XCTAssertTrue(question.canReturnToBoard)
        XCTAssertTrue(question.canRevealAnswer)
        XCTAssertTrue(question.canControlTimer)
        XCTAssertFalse(question.canGoToFinal)
    }

    func testAnswerCanReturnButNotRevealAgain() {
        let answer = availability(.answer)
        XCTAssertTrue(answer.canReturnToBoard)
        XCTAssertFalse(answer.canRevealAnswer)
        XCTAssertFalse(answer.canControlTimer)
    }

    func testFinalQuestionAndAnswerKeepTheTimer() {
        XCTAssertTrue(availability(.finalMacpardyQuestion).canRevealAnswer)
        XCTAssertTrue(availability(.finalMacpardyQuestion).canControlTimer)
        XCTAssertFalse(availability(.finalMacpardyAnswer).canRevealAnswer)
        XCTAssertTrue(availability(.finalMacpardyAnswer).canControlTimer)
    }

    func testBuzzersCanOpenOnlyWhenTurnedOn() {
        for phase in GamePhase.allCases {
            XCTAssertTrue(availability(phase).canOpenBuzzers)
            let off = GameCommandAvailability(phase: phase, hasSelectedGame: true, buzzersEnabled: false)
            XCTAssertFalse(off.canOpenBuzzers)
            XCTAssertTrue(off.canShowDisplay)
        }
    }

    func testJoinScreenCanShowOverEveryPhaseButSetup() {
        for phase in GamePhase.allCases {
            XCTAssertEqual(availability(phase).canShowJoinScreen, phase != .setup, "\(phase)")
        }
    }

    func testJoinScreenNeedsBuzzersOn() {
        for phase in GamePhase.allCases {
            let off = GameCommandAvailability(phase: phase, hasSelectedGame: true, buzzersEnabled: false)
            XCTAssertFalse(off.canShowJoinScreen)
        }
    }

    func testNothingIsEnabledWithoutAGame() {
        for phase in GamePhase.allCases {
            let none = availability(phase, hasGame: false)
            XCTAssertFalse(none.canReturnToBoard)
            XCTAssertFalse(none.canGoToFinal)
            XCTAssertFalse(none.canAdvanceRound)
            XCTAssertFalse(none.canRevealAnswer)
            XCTAssertFalse(none.canControlTimer)
            XCTAssertFalse(none.canShowDisplay)
            XCTAssertFalse(none.canOpenBuzzers)
            XCTAssertFalse(none.canShowJoinScreen)
        }
    }
}
