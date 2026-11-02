//
//  FinalAnswerGameStateTests.swift
//  MacpardyTests
//
//  GameState's side of Final answers from phones (#80): when answering is
//  open, what gets stored, the Display spotlight, and auto-save.
//

import XCTest
@testable import Macpardy

@MainActor
final class FinalAnswerGameStateTests: XCTestCase {

    private func makeState() -> (GameState, Team, Team) {
        let rich = Team(name: "Rich", score: 1200)
        let broke = Team(name: "Broke", score: -200)
        let state = GameState(rounds: [MacpardyBoard.sample], teams: [rich, broke])
        return (state, rich, broke)
    }

    func testAnswerWindowFollowsPhase() {
        let (state, _, _) = makeState()
        state.phase = .board
        XCTAssertEqual(state.finalAnswerWindow, .closed)
        state.showFinalMacpardy()
        XCTAssertEqual(state.finalAnswerWindow, .closed)
        state.revealFinalMacpardyQuestion()
        XCTAssertEqual(state.finalAnswerWindow, .open)
        state.revealAnswer()
        XCTAssertEqual(state.finalAnswerWindow, .locked)
    }

    func testAnswersStoredOnlyWhileClueIsUp() {
        let (state, rich, broke) = makeState()
        state.showFinalMacpardy()
        state.setFinalAnswer(teamID: rich.id, answer: "Too early")
        XCTAssertNil(state.finalMacpardyAnswers[rich.id])

        state.revealFinalMacpardyQuestion()
        state.setFinalAnswer(teamID: rich.id, answer: "  What is Paris? ")
        // Excluded teams can still answer for fun.
        state.setFinalAnswer(teamID: broke.id, answer: "What is Rome?")
        XCTAssertEqual(state.finalMacpardyAnswers[rich.id], "What is Paris?")
        XCTAssertEqual(state.finalMacpardyAnswers[broke.id], "What is Rome?")

        state.revealAnswer()
        state.setFinalAnswer(teamID: rich.id, answer: "What is Lyon?")
        XCTAssertEqual(state.finalMacpardyAnswers[rich.id], "What is Paris?")
    }

    func testUnknownTeamAndBlankAnswerAreIgnored() {
        let (state, rich, _) = makeState()
        state.showFinalMacpardy()
        state.revealFinalMacpardyQuestion()
        state.setFinalAnswer(teamID: UUID(), answer: "Ghost")
        state.setFinalAnswer(teamID: rich.id, answer: "   ")
        XCTAssertTrue(state.finalMacpardyAnswers.isEmpty)
    }

    func testRevealOneTeamAtATimeAfterResponse() {
        let (state, rich, broke) = makeState()
        state.showFinalMacpardy()
        state.revealFinalMacpardyQuestion()
        state.revealFinalAnswer(teamID: rich.id)
        XCTAssertNil(state.finalMacpardyRevealedTeamID, "can't reveal before the response")

        state.revealAnswer()
        state.revealFinalAnswer(teamID: rich.id)
        XCTAssertEqual(state.finalMacpardyRevealedTeam?.id, rich.id)
        state.revealFinalAnswer(teamID: broke.id)
        XCTAssertEqual(state.finalMacpardyRevealedTeam?.id, broke.id)
        state.revealFinalAnswer(teamID: nil)
        XCTAssertNil(state.finalMacpardyRevealedTeam)
        state.revealFinalAnswer(teamID: UUID())
        XCTAssertNil(state.finalMacpardyRevealedTeamID)
    }

    func testNewFinalAndBoardClearAnswersAndSpotlight() {
        let (state, rich, _) = makeState()
        state.showFinalMacpardy()
        state.revealFinalMacpardyQuestion()
        state.setFinalAnswer(teamID: rich.id, answer: "Paris")
        state.revealAnswer()
        state.revealFinalAnswer(teamID: rich.id)

        state.showBoard()
        XCTAssertNil(state.finalMacpardyRevealedTeamID)

        state.showFinalMacpardy()
        XCTAssertTrue(state.finalMacpardyAnswers.isEmpty)
    }

    func testAnswersSurviveAutoSave() throws {
        let (state, rich, _) = makeState()
        state.showFinalMacpardy()
        state.revealFinalMacpardyQuestion()
        state.setFinalAnswer(teamID: rich.id, answer: "Paris")
        state.revealAnswer()
        state.revealFinalAnswer(teamID: rich.id)

        let data = try JSONEncoder().encode(GameSnapshot(from: state))
        let decoded = try JSONDecoder().decode(GameSnapshot.self, from: data)
        let restored = GameState(from: decoded)
        XCTAssertEqual(restored.finalMacpardyAnswers[rich.id], "Paris")
        XCTAssertEqual(restored.finalMacpardyRevealedTeamID, rich.id)

        let other = GameState()
        other.restore(from: decoded)
        XCTAssertEqual(other.finalMacpardyAnswers[rich.id], "Paris")
    }

    func testSaveFromBeforeAnswersStillLoads() throws {
        let (state, _, _) = makeState()
        state.phase = .board
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(GameSnapshot(from: state))) as? [String: Any]
        )
        object["finalMacpardyAnswers"] = nil
        object["finalMacpardyRevealedTeamID"] = nil
        let oldData = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(GameSnapshot.self, from: oldData)
        XCTAssertNil(decoded.finalMacpardyAnswers)
        XCTAssertTrue(GameState(from: decoded).finalMacpardyAnswers.isEmpty)
    }
}
