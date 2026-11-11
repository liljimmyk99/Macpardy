//
//  BuzzerStateTests.swift
//  MacpardyTests
//
//  BuzzerState driven through a fake backend (#102): start and stop, the
//  resync step, command forwarding and room events.
//

import BuzzerCore
import XCTest
@testable import Macpardy

@MainActor
final class BuzzerStateTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!
    private var backend: FakeBuzzerBackend!
    private var state: BuzzerState!

    private let blue = Team(name: "Blue")
    private let red = Team(name: "Red")

    override func setUp() {
        super.setUp()
        suiteName = "BuzzerStateTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        backend = FakeBuzzerBackend()
        state = BuzzerState(backend: backend, defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        state = nil
        backend = nil
        defaults = nil
        super.tearDown()
    }

    // MARK: - Start and stop

    func testStartTakesThePINAndURLsFromTheBackend() async {
        await state.startServer()

        XCTAssertTrue(state.isRunning)
        XCTAssertNil(state.startError)
        XCTAssertEqual(state.joinCode, "AAAAAA")
        XCTAssertEqual(state.baseURL?.absoluteString, "http://192.168.1.20:8472")
        XCTAssertEqual(state.serverURL?.absoluteString, "http://192.168.1.20:8472?code=AAAAAA")
    }

    func testRestartStopsTheOldSessionAndRotatesThePIN() async {
        await state.startServer()
        await state.startServer()

        XCTAssertEqual(state.joinCode, "BBBBBB")
        XCTAssertEqual(backend.calls.filter { $0 == .start || $0 == .stop }, [.stop, .start, .stop, .start])
    }

    func testStartFailureShowsTheBackendsReason() async {
        backend.startError = FakeBuzzerBackend.StartFailure()

        await state.startServer()

        XCTAssertFalse(state.isRunning)
        XCTAssertEqual(state.startError, "Port in use")
        XCTAssertTrue(state.joinCode.isEmpty)
        XCTAssertNil(state.serverURL)
        XCTAssertNil(state.baseURL)
    }

    func testStartClearsAnEarlierError() async {
        backend.startError = FakeBuzzerBackend.StartFailure()
        await state.startServer()
        await state.startServer()

        XCTAssertNil(state.startError)
        XCTAssertTrue(state.isRunning)
    }

    func testBuzzersOffInSettingsDoesNotStartTheBackend() async {
        defaults.set(false, forKey: AppSettings.Key.buzzersEnabled)

        await state.startServer()

        XCTAssertFalse(state.isRunning)
        XCTAssertFalse(backend.calls.contains(.start))
    }

    func testStopClearsTheSession() async {
        await state.startServer()
        backend.emit(.claimedTeams([blue.id]))
        backend.emit(.connectedCount(1))
        backend.emit(.firstBuzz(blue.id))
        await waitUntil { self.state.firstBuzzTeamID == self.blue.id }
        state.isJoinScreenOnDisplay = true

        await state.stopServer()

        XCTAssertEqual(backend.calls.last, .stop)
        XCTAssertFalse(state.isRunning)
        XCTAssertTrue(state.joinCode.isEmpty)
        XCTAssertNil(state.serverURL)
        XCTAssertNil(state.baseURL)
        XCTAssertEqual(state.connectedClientCount, 0)
        XCTAssertTrue(state.claimedTeamIDs.isEmpty)
        XCTAssertTrue(state.disconnectedTeamIDs.isEmpty)
        XCTAssertNil(state.firstBuzzTeamID)
        XCTAssertFalse(state.isJoinScreenOnDisplay)
    }

    // MARK: - Resync

    func testStartResyncsTheGamesCurrentState() async {
        let teams = [BuzzerTeam(team: blue), BuzzerTeam(team: red)]
        await state.syncTeams(teams)
        await state.syncScores([blue.id: 400, red.id: 200])
        await state.setMode(.armed)
        await state.openWagering(limits: [blue.id: 400, red.id: 200], wagers: [blue.id: 100])
        await state.setAnswering(.open, answers: [red.id: "What is Ohio?"])

        await state.startServer()

        XCTAssertEqual(backend.callsSinceStart, [
            .teams(teams),
            .scores([blue.id: 400, red.id: 200]),
            .mode(.armed),
            .openWagering(limits: [blue.id: 400, red.id: 200], wagers: [blue.id: 100]),
            .answering(.open, [red.id: "What is Ohio?"]),
        ])
    }

    func testResyncSkipsWageringWhenClosedAndDropsClosedAnswers() async {
        await state.openWagering(limits: [blue.id: 400], wagers: [:])
        await state.closeWagering()
        await state.setAnswering(.closed, answers: [blue.id: "ignored"])

        await state.startServer()

        XCTAssertEqual(backend.callsSinceStart, [
            .teams([]),
            .scores([:]),
            .mode(.disabled),
            .answering(.closed, [:]),
        ])
    }

    func testResyncIncludesWagersFromPhonesAndTheHost() async {
        var wagerArrived = false
        state.onWagerSubmitted = { _ in wagerArrived = true }
        await state.openWagering(limits: [blue.id: 400, red.id: 200], wagers: [:])
        await state.startServer()
        backend.emit(.wager(WagerSubmission(teamID: blue.id, amount: 300)))
        await waitUntil { wagerArrived }
        await state.hostSetWager(teamID: red.id, amount: 50)
        backend.clearCalls()

        await state.resync()

        XCTAssertTrue(backend.calls.contains(.openWagering(limits: [blue.id: 400, red.id: 200], wagers: [blue.id: 300, red.id: 50])))
    }

    // MARK: - Commands

    func testGameCommandsReachTheBackend() async {
        await state.startServer()
        backend.clearCalls()

        await state.teamAnsweredWrong(blue.id)
        await state.teamAnsweredCorrect()
        await state.setResponseTimer(teamID: blue.id, seconds: 5)
        await state.setResponseTimer(teamID: nil, seconds: 0)
        await state.closeWagering()
        await state.hostSetWager(teamID: red.id, amount: nil)
        await state.removePhone(forTeam: red.id)
        await state.broadcastPhase("board")

        XCTAssertEqual(backend.calls, [
            .wrong(blue.id),
            .correct,
            .responseTimer(blue.id, 5),
            .responseTimer(nil, 0),
            .closeWagering,
            .setWager(red.id, nil),
            .removePhone(red.id),
            .phase("board"),
        ])
    }

    // MARK: - Events

    func testClaimEventsTrackDisconnectedTeams() async {
        await state.startServer()

        backend.emit(.claimedTeams([blue.id, red.id]))
        await waitUntil { self.state.claimedTeamIDs == [self.blue.id, self.red.id] }
        backend.emit(.claimedTeams([red.id]))
        await waitUntil { self.state.claimedTeamIDs == [self.red.id] }

        XCTAssertEqual(state.disconnectedTeamIDs, [blue.id])
    }

    func testCountAndFirstBuzzEventsUpdateTheState() async {
        await state.startServer()

        backend.emit(.connectedCount(2))
        backend.emit(.firstBuzz(red.id))
        await waitUntil { self.state.firstBuzzTeamID == self.red.id }

        XCTAssertEqual(state.connectedClientCount, 2)
    }

    func testSubmissionsReachTheCallbacks() async {
        var wagers: [WagerSubmission] = []
        var answers: [AnswerSubmission] = []
        state.onWagerSubmitted = { wagers.append($0) }
        state.onAnswerSubmitted = { answers.append($0) }
        await state.startServer()

        backend.emit(.wager(WagerSubmission(teamID: blue.id, amount: 300)))
        backend.emit(.answer(AnswerSubmission(teamID: blue.id, answer: "What is Ohio?")))
        await waitUntil { !answers.isEmpty }

        XCTAssertEqual(wagers, [WagerSubmission(teamID: blue.id, amount: 300)])
        XCTAssertEqual(answers, [AnswerSubmission(teamID: blue.id, answer: "What is Ohio?")])
    }

    func testFailureEventStopsAndShowsTheReason() async {
        await state.startServer()

        backend.emit(.failed("Listener failed"))
        await waitUntil { !self.state.isRunning }

        XCTAssertEqual(state.startError, "Listener failed")
    }

    func testEventsFromAStoppedSessionAreIgnored() async {
        await state.startServer()
        await state.stopServer()

        backend.emit(.connectedCount(3))
        await Task.yield()

        XCTAssertEqual(state.connectedClientCount, 0)
    }

    // MARK: - Helpers

    /// Lets the event observer task run until `condition` holds.
    private func waitUntil(_ condition: () -> Bool, file: StaticString = #filePath, line: UInt = #line) async {
        for _ in 0..<1_000 {
            if condition() { return }
            await Task.yield()
        }
        XCTFail("Timed out waiting for the condition", file: file, line: line)
    }

    // MARK: - External server connection (#104)

    func testReconnectingShowsUntilTheBackendIsBackThenResyncs() async {
        await state.syncTeams([BuzzerTeam(team: blue)])
        await state.setMode(.armed)
        await state.startServer()
        backend.clearCalls()

        backend.onStatusChange?(.reconnecting)
        XCTAssertTrue(state.isReconnecting)
        XCTAssertTrue(state.isRunning, "The game keeps its PIN and QR code while reconnecting")

        backend.onStatusChange?(.connected)
        XCTAssertFalse(state.isReconnecting)
        await waitForCalls { self.backend.calls.contains(.mode(.armed)) }
        XCTAssertEqual(backend.calls.first, .teams([BuzzerTeam(team: blue)]))
    }

    func testEndedRoomShowsAnErrorAndStopsRunning() async {
        await state.startServer()
        backend.onStatusChange?(.reconnecting)
        backend.onStatusChange?(.ended(reason: "grace period over"))

        XCTAssertFalse(state.isReconnecting)
        XCTAssertFalse(state.isRunning)
        XCTAssertNotNil(state.startError)
    }

    func testStoppingClearsReconnecting() async {
        await state.startServer()
        backend.onStatusChange?(.reconnecting)
        await state.stopServer()
        XCTAssertFalse(state.isReconnecting)
    }

    private func waitForCalls(_ condition: () -> Bool) async {
        for _ in 0..<200 where !condition() { try? await Task.sleep(for: .milliseconds(5)) }
    }
}
