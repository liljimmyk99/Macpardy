//
//  SessionLifecycleTests.swift
//  MacpardyTests
//

import BuzzerCore
import XCTest
@testable import Macpardy

@MainActor
final class SessionLifecycleTests: XCTestCase {

    private func makeSnapshot() throws -> (GameSnapshot, [Team]) {
        let teams = [Team(name: "Red", score: 600), Team(name: "Blue", score: -100)]
        let state = GameState(rounds: [MacpardyBoard.sample], teams: teams)
        return (GameSnapshot(from: state), teams)
    }

    func testRestoredTeamsKeepNamesAndScores() throws {
        let (snapshot, teams) = try makeSnapshot()
        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(GameSnapshot.self, from: data)

        let restored = GameState(from: decoded)
        XCTAssertEqual(restored.game.teams.map(\.name), teams.map(\.name))
        XCTAssertEqual(restored.game.teams.map(\.score), teams.map(\.score))
    }

    func testSnapshotHasNoBuzzerConnectionState() throws {
        let (snapshot, _) = try makeSnapshot()
        let json = try String(decoding: JSONEncoder().encode(snapshot), as: UTF8.self).lowercased()
        for key in ["joincode", "claim", "connected", "session"] {
            XCTAssertFalse(json.contains(key), "snapshot leaks buzzer state: \(key)")
        }
    }

    func testFreshRegistryHasAllSlotsUnclaimed() throws {
        let (snapshot, _) = try makeSnapshot()
        let registry = TeamClaimRegistry()
        for team in snapshot.game.teams {
            XCTAssertNil(registry.sessionID(for: team.id))
        }
    }

    func testJoinCodesDifferBetweenSessions() {
        let codes = Set((0..<20).map { _ in JoinCodeGenerator.generate() })
        XCTAssertGreaterThan(codes.count, 1)
    }

    func testStopServerClearsJoinCode() async {
        let buzzer = BuzzerState()
        await buzzer.startServer()
        // Start can fail on a machine with no network; only assert when it ran.
        guard buzzer.isRunning else { return }
        XCTAssertFalse(buzzer.joinCode.isEmpty)
        let first = buzzer.joinCode

        await buzzer.startServer()
        XCTAssertNotEqual(buzzer.joinCode, first, "restart must rotate the code")

        await buzzer.stopServer()
        XCTAssertTrue(buzzer.joinCode.isEmpty)
        XCTAssertNil(buzzer.serverURL)
        XCTAssertNil(buzzer.baseURL)
        XCTAssertTrue(buzzer.claimedTeamIDs.isEmpty)
    }

    func testStoppingTheServerTakesDownTheJoinScreen() async {
        let buzzer = BuzzerState()
        buzzer.isJoinScreenOnDisplay = true
        await buzzer.stopServer()
        XCTAssertFalse(buzzer.isJoinScreenOnDisplay, "no join screen without a Game PIN")
    }

    func testJoinURLsShowBareAddressAndQRLinkWithCode() throws {
        let urls = try XCTUnwrap(EmbeddedBuzzerBackend.joinURLs(ip: "192.168.1.20", port: 8472, code: "AB3XYZ"))
        XCTAssertEqual(urls.base.absoluteString, "http://192.168.1.20:8472")
        XCTAssertNil(urls.base.query)
        XCTAssertEqual(urls.join.absoluteString, "http://192.168.1.20:8472?code=AB3XYZ")
        let items = URLComponents(url: urls.join, resolvingAgainstBaseURL: false)?.queryItems
        XCTAssertEqual(items?.first(where: { $0.name == "code" })?.value, "AB3XYZ")
    }
}
