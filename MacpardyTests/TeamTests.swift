//
//  TeamTests.swift
//  MacpardyTests
//
//  Up to six teams, each starting with its own color.
//

import XCTest
@testable import Macpardy

@MainActor
final class TeamTests: XCTestCase {

    func testMaxCountIsSixWithAColorEach() {
        XCTAssertEqual(Team.maxCount, 6)
        XCTAssertGreaterThanOrEqual(Team.defaultColors.count, Team.maxCount)
        XCTAssertEqual(Set(Team.defaultColors).count, Team.defaultColors.count)
    }

    func testAddTeamStopsAtMaxCount() {
        let state = GameState(rounds: [MacpardyBoard.sample], teams: [Team(name: "One")])
        for _ in 0..<10 { state.addTeam() }
        XCTAssertEqual(state.game.teams.count, Team.maxCount)
    }

    func testAddedTeamsGetDistinctColors() {
        let state = GameState(rounds: [MacpardyBoard.sample], teams: [])
        for _ in 0..<Team.maxCount { state.addTeam() }
        let colors = state.game.teams.map(\.color)
        XCTAssertEqual(Set(colors).count, Team.maxCount)
        XCTAssertEqual(colors, Team.defaultColors)
    }

    func testAddTeamReusesAFreedColor() {
        let state = GameState(rounds: [MacpardyBoard.sample], teams: [])
        for _ in 0..<3 { state.addTeam() }   // blue, red, green
        state.removeTeam(at: 1)               // frees red
        state.addTeam()
        XCTAssertEqual(state.game.teams.last?.color, "red")
    }

    func testNextColorWrapsWhenAllAreTaken() {
        let teams = Team.defaultColors.map { Team(name: $0, color: $0) }
        XCTAssertTrue(Team.defaultColors.contains(Team.nextColor(after: teams)))
    }

    func testDefaultNewTeamsSupportsSixFromSettings() {
        let defaults = UserDefaults(suiteName: "TeamTests")!
        defaults.removePersistentDomain(forName: "TeamTests")
        defaults.set(6, forKey: AppSettings.Key.defaultTeamCount)
        XCTAssertEqual(AppSettings.defaultTeamCount(defaults), 6)
        defaults.removePersistentDomain(forName: "TeamTests")
    }
}
