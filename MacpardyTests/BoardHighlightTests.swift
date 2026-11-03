//
//  BoardHighlightTests.swift
//  MacpardyTests
//
//  GameState's arrow-key highlight on the board (#88).
//

import XCTest
@testable import Macpardy

@MainActor
final class BoardHighlightTests: XCTestCase {

    private func boardState(rounds: [MacpardyBoard] = [MacpardyBoard.sample]) -> GameState {
        let state = GameState(rounds: rounds)
        state.startGame()
        return state
    }

    func testArrowsOnlyWorkOnTheBoard() {
        let state = GameState()
        state.moveHighlight(.down)
        XCTAssertNil(state.highlightedTile, "setup ignores the arrows")

        state.startGame()
        state.moveHighlight(.down)
        XCTAssertEqual(state.highlightedTile, BoardPosition(column: 0, row: 0))
    }

    func testReturnOpensTheHighlightedClue() throws {
        let state = boardState()
        state.moveHighlight(.right)
        state.moveHighlight(.right)
        state.moveHighlight(.down)
        let position = try XCTUnwrap(state.highlightedTile)
        let board = try XCTUnwrap(state.game.currentBoard)
        let expected = board.categories[position.column].questions[position.row]

        state.openHighlightedQuestion()

        XCTAssertEqual(state.currentQuestion?.id, expected.id)
        XCTAssertEqual(state.currentCategoryTitle, board.categories[position.column].title)
        XCTAssertTrue(state.phase == .question || state.phase == .dailyDouble)
        XCTAssertTrue(try XCTUnwrap(state.game.currentBoard).categories[position.column].questions[position.row].hasBeenPlayed)
    }

    func testReturnWithNothingHighlightedDoesNothing() {
        let state = boardState()
        state.openHighlightedQuestion()
        XCTAssertEqual(state.phase, .board)
        XCTAssertNil(state.currentQuestion)
    }

    func testPlayedTileCantBeOpenedAgainAndArrowsMoveOn() {
        let state = boardState()
        state.moveHighlight(.down)
        state.openHighlightedQuestion()
        state.showBoard()

        XCTAssertEqual(state.highlightedTile, BoardPosition(column: 0, row: 0), "kept so the next press starts here")
        state.openHighlightedQuestion()
        XCTAssertEqual(state.phase, .board, "a played tile doesn't reopen")

        state.moveHighlight(.down)
        XCTAssertEqual(state.highlightedTile, BoardPosition(column: 0, row: 1))
    }

    func testNewRoundClearsTheHighlight() {
        let state = boardState(rounds: [MacpardyBoard.sample, MacpardyBoard.sample])
        state.moveHighlight(.down)
        state.advanceRound()
        XCTAssertNil(state.highlightedTile)
    }

    func testLoadingAGameClearsTheHighlight() {
        let state = boardState()
        state.moveHighlight(.down)
        state.loadGame(boards: [MacpardyBoard.sample])
        XCTAssertNil(state.highlightedTile)
    }
}
