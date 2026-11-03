//
//  GameStateLoggingTests.swift
//  MacpardyTests
//
//  GameState's state lines (#87): phases, clues, scores with their reason,
//  Final steps, and never a clue, answer or Final answer's text.
//

import XCTest
@testable import Macpardy

@MainActor
final class GameStateLoggingTests: XCTestCase {

    private static let clue = "Longest river in Africa"
    private static let response = "What is the Nile?"

    private func makeState() -> GameState {
        let board = MacpardyBoard(
            title: "Round One",
            round: .macpardy,
            categories: [
                Category(title: "Rivers", questions: [
                    Question(value: 200, clue: Self.clue, response: Self.response),
                    Question(value: 400, clue: "Second clue text", response: "Second answer text"),
                ]),
            ]
        )
        return GameState(rounds: [board], teams: [Team(name: "Red"), Team(name: "Blue", score: 400)])
    }

    func testPhaseChangesAreLogged() {
        let state = makeState()
        let log = LogCapture.capture { state.startGame() }
        XCTAssertTrue(log.messages.contains("state: GameState.phase: setup → board"))
    }

    func testPickingAClueLogsWhereItIsButNotItsText() {
        let state = makeState()
        state.startGame()
        let question = state.game.rounds[0].categories[0].questions[1]

        let log = LogCapture.capture {
            state.selectQuestion(question, categoryTitle: "Rivers")
            state.revealAnswer()
        }

        XCTAssertEqual(log.messages.filter { $0.contains("currentClue") }, ["state: GameState.currentClue: none → R1 · 'Rivers' · $400 (C1 row 2)"])
        XCTAssertTrue(log.messages.contains("state: GameState.phase: board → question"))
        XCTAssertTrue(log.messages.contains("state: GameState.phase: question → answer"))
        for message in log.messages {
            XCTAssertFalse(message.contains("Second clue text"), message)
            XCTAssertFalse(message.contains("Second answer text"), message)
        }
    }

    func testScoreChangesCarryTheirReason() {
        let state = makeState()
        let blue = state.game.teams[1].id

        let log = LogCapture.capture {
            state.adjustScore(for: blue, by: 400, reason: .correct)
            state.adjustScore(for: blue, by: -200, reason: .incorrect)
            state.adjustScore(for: blue, by: 100)
        }

        XCTAssertEqual(log.messages.filter { $0.contains("score") }, [
            "state: Team 2 'Blue' score: 400 → 800 (+400, correct)",
            "state: Team 2 'Blue' score: 800 → 600 (-200, incorrect)",
            "state: Team 2 'Blue' score: 600 → 700 (+100, host edit)",
        ])
        XCTAssertEqual(log.entries.first { $0.message.contains("score") }?.teamName, "Blue")
    }

    func testResettingAZeroScoreLogsNothing() {
        let state = makeState()
        let log = LogCapture.capture { state.resetScore(for: state.game.teams[0].id) }
        XCTAssertFalse(log.messages.contains { $0.contains("score") })
    }

    func testUndoingAScoreIsLoggedAsUndo() {
        let state = makeState()
        let manager = UndoManager()
        manager.groupsByEvent = false
        state.scoreUndoManager = manager
        let red = state.game.teams[0].id
        manager.beginUndoGrouping()
        state.adjustScore(for: red, by: 200, reason: .correct)
        manager.endUndoGrouping()

        let log = LogCapture.capture { manager.undo() }

        XCTAssertTrue(log.messages.contains("state: Team 1 'Red' score: 200 → 0 (-200, undo)"))
    }

    func testFinalAnswersLogTheirLengthOnly() {
        let state = makeState()
        state.startGame()
        state.showFinalMacpardy()
        state.revealFinalMacpardyQuestion()
        let blue = state.game.teams[1].id

        let log = LogCapture.capture { state.setFinalAnswer(teamID: blue, answer: "What is the Nile?") }

        XCTAssertEqual(log.messages, ["state: Team 2 'Blue' Final answer saved (length 17)"])
    }

    func testFinalWagersAreLoggedWithTheDefaultsApplied() {
        let state = makeState()
        state.startGame()
        state.showFinalMacpardy()
        let blue = state.game.teams[1].id

        let log = LogCapture.capture {
            state.setFinalWager(teamID: blue, amount: 1_000)
            state.revealFinalMacpardyQuestion()
        }

        XCTAssertTrue(log.messages.contains("state: Team 2 'Blue' Final wager: none → 400 (asked for 1000)"))
        XCTAssertTrue(log.messages.contains("state: Team 1 'Red' Final wager: none → 0 (not eligible)"))
    }

    func testNoLineEverHasTheClueOrResponse() {
        let state = makeState()
        let log = LogCapture.capture {
            state.startGame()
            let question = state.game.rounds[0].categories[0].questions[0]
            state.selectQuestion(question, categoryTitle: "Rivers")
            state.adjustScore(for: state.game.teams[0].id, by: 200, reason: .correct)
            state.revealAnswer()
            state.showBoard()
            state.endGame()
        }
        XCTAssertFalse(log.messages.isEmpty)
        for message in log.messages {
            XCTAssertFalse(message.contains(Self.clue), message)
            XCTAssertFalse(message.contains(Self.response), message)
        }
    }
}
