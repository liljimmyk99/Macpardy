//
//  GameStateEndGameTests.swift
//  MacpardyTests
//
//  Completing a game (#82): GameState stops, stops saving, and returns to setup.
//

import XCTest
@testable import Macpardy

@MainActor
final class GameStateEndGameTests: XCTestCase {

    private func makeFinishedGame() -> GameState {
        let state = GameState(rounds: [MacpardyBoard.sample], teams: [Team(name: "Red", score: 800)])
        state.startGame()
        state.showFinalMacpardy()
        state.revealFinalMacpardyQuestion()
        state.revealAnswer()
        return state
    }

    func testEndGameReturnsToSetupAndClearsTheClue() {
        let state = makeFinishedGame()
        let teamID = state.game.teams[0].id
        state.revealFinalAnswer(teamID: teamID)

        state.endGame()

        XCTAssertEqual(state.phase, .setup)
        XCTAssertNil(state.currentQuestion)
        XCTAssertNil(state.currentCategoryTitle)
        XCTAssertNil(state.finalMacpardyRevealedTeamID)
        XCTAssertFalse(state.boardIntroPending)
        XCTAssertEqual(state.finalAnswerWindow, .closed)
    }

    func testEndGameStopsTheTimers() {
        let state = makeFinishedGame()
        state.timer.start()

        state.endGame()

        XCTAssertFalse(state.timer.isRunning)
        XCTAssertNil(state.responseCountdown)
    }

    func testNothingIsSavedAfterTheGameEnds() {
        let state = makeFinishedGame()
        var saves = 0
        state.onSaveTriggered = { _ in saves += 1 }

        state.endGame()
        state.adjustScore(for: state.game.teams[0].id, by: 100)

        XCTAssertEqual(saves, 0)
    }

    func testEndGameClearsScoreUndo() {
        let state = makeFinishedGame()
        let manager = UndoManager()
        manager.groupsByEvent = false
        state.scoreUndoManager = manager
        manager.beginUndoGrouping()
        state.adjustScore(for: state.game.teams[0].id, by: 100)
        manager.endUndoGrouping()

        state.endGame()

        XCTAssertFalse(manager.canUndo)
    }
}
