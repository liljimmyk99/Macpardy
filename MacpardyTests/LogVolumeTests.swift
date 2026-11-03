//
//  LogVolumeTests.swift
//  MacpardyTests
//
//  A full 4-team game with the verbose log (#87) must stay well under the
//  per-run cap. Plays two rounds and Final through the models, adding the
//  taps and phone lines the views and buzzer server log for each clue.
//

import XCTest
@testable import Macpardy

@MainActor
final class LogVolumeTests: XCTestCase {

    private func makeBoard(_ round: MacpardyRound, values: [Int]) -> MacpardyBoard {
        MacpardyBoard(
            title: round == .macpardy ? "Round One" : "Round Two",
            round: round,
            categories: (1...6).map { column in
                Category(title: "Category \(column)", questions: values.enumerated().map { row, value in
                    Question(
                        value: value,
                        clue: String(repeating: "clue ", count: 20),
                        response: "What is it?",
                        isDailyDouble: column == 3 && row == 3
                    )
                })
            }
        )
    }

    func testAFullFourTeamGameStaysUnderHalfTheRunCap() throws {
        let final = MacpardyBoard(
            title: "Final",
            round: .finalMacpardy,
            categories: [Category(title: "Rivers", questions: [Question(value: 0, clue: "c", response: "r")])]
        )
        let state = GameState(
            rounds: [
                makeBoard(.macpardy, values: [200, 400, 600, 800, 1000]),
                makeBoard(.doubleMacpardy, values: [400, 800, 1200, 1600, 2000]),
                final,
            ],
            teams: (1...4).map { Team(name: "Team number \($0)") }
        )

        let log = LogCapture.capture {
            UIActionLog.action("Control › Setup › Start game")
            state.startGame()
            for round in 0..<2 {
                let board = state.game.rounds[round]
                for (column, category) in board.categories.enumerated() {
                    for (row, question) in category.questions.enumerated() {
                        playClue(question, column: column, row: row, category: category.title, in: state)
                    }
                }
                UIActionLog.action("Control › Toolbar › Next round", source: .menu)
                state.advanceRound()
            }
            for team in state.game.teams {
                UIActionLog.action("Control › Final › \(state.teamLabel(team.id)) › Wager")
                state.setFinalWager(teamID: team.id, amount: max(0, team.score / 2))
            }
            state.revealFinalMacpardyQuestion()
            for team in state.game.teams {
                AppLogger.buzzer.phone("Team (10.0.0.\(team.name.count) #abcd): submitAnswer (length 14)", team: team.name)
                state.setFinalAnswer(teamID: team.id, answer: "What is the Nile")
            }
            state.revealAnswer()
            for team in state.game.teams {
                state.revealFinalAnswer(teamID: team.id)
                state.adjustScore(for: team.id, by: state.finalMacpardyWagers[team.id] ?? 0, reason: .correct)
            }
            state.endGame()
        }

        let encoder = LogEntry.makeEncoder()
        let bytes = try log.entries.reduce(0) { $0 + (try $1.jsonLine(using: encoder).count) }
        // Recorded in the PR: lines and bytes for one scripted game.
        print("Scripted 4-team game: \(log.entries.count) lines, \(bytes) bytes")
        XCTAssertLessThan(bytes, LogFileStore.defaultMaxRunBytes / 2)
    }

    /// One clue as the host plays it: pick the tile, three phones buzz, one
    /// team is wrong, the next is right, back to the board.
    private func playClue(_ question: Question, column: Int, row: Int, category: String, in state: GameState) {
        let teams = state.game.teams
        UIActionLog.action("Board tile R\(state.game.currentRound + 1) C\(column + 1) row \(row + 1) $\(question.value)")
        state.selectQuestion(question, categoryTitle: category)
        if question.isDailyDouble {
            UIActionLog.action("Control › Daily Double › Show question")
            state.submitDailyDoubleWager(teamID: teams[0].id, wager: 1000)
            state.adjustScore(for: teams[0].id, by: 1000, reason: .correct)
        } else {
            state.timer.start()
            for team in teams.prefix(3) {
                AppLogger.buzzer.phone("\(team.name) (10.0.0.2 #abcd): buzz", team: team.name, remote: "10.0.0.2")
            }
            AppLogger.buzzer.state("Tie window closed: 3 buzz(es), winner '\(teams[0].name)' (tie broken)")
            state.teamBuzzedIn(teams[0].id)
            UIActionLog.action("Control › Score strip › \(state.teamLabel(teams[0].id)) Wrong −\(question.value)")
            state.adjustScore(for: teams[0].id, by: -question.value, reason: .incorrect)
            state.judgeResponse(teamID: teams[0].id, isCorrect: false)
            state.teamBuzzedIn(teams[1].id)
            UIActionLog.action("Control › Score strip › \(state.teamLabel(teams[1].id)) Correct +\(question.value)")
            state.adjustScore(for: teams[1].id, by: question.value, reason: .correct)
            state.judgeResponse(teamID: teams[1].id, isCorrect: true)
        }
        UIActionLog.action("Control › Question › Reveal answer")
        state.revealAnswer()
        UIActionLog.action("Control › Toolbar › Return to board")
        state.showBoard()
    }
}
