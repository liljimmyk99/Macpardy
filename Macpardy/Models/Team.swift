//
//  Team.swift
//  Macpardy
//
//  Created by Jimmy Kane on 7/15/26.
//
import Foundation
import SwiftUI

struct Team: Identifiable, Equatable, Codable {

    /// Most teams a game can have; each can be claimed by one buzzer phone.
    /// One per team color, so no two teams start with the same color.
    static let maxCount = 6

    let id: UUID
    var name: String
    var score: Int
    var color: String

    init(id: UUID = UUID(), name: String, score: Int = 0, color: String = "blue") {
        self.id = id
        self.name = name
        self.score = score
        self.color = color
    }

    /// Color names a team can pick, in picker order.
    static let colorOptions = ["blue", "red", "green", "yellow", "purple", "orange"]

    var displayColor: Color {
        Team.displayColor(for: color)
    }

    static func displayColor(for color: String) -> Color {
        switch color.lowercased() {
        case "blue": MacpardyAsset.teamBlue.swiftUIColor
        case "red": MacpardyAsset.teamRed.swiftUIColor
        case "green": MacpardyAsset.teamGreen.swiftUIColor
        case "yellow": MacpardyAsset.teamYellow.swiftUIColor
        case "purple": MacpardyAsset.teamPurple.swiftUIColor
        case "orange": MacpardyAsset.teamOrange.swiftUIColor
        default: .gray
        }
    }
}

extension Team {

    /// Colors given to new teams, in order. One per team up to `maxCount`.
    static let defaultColors = colorOptions

    /// The first color in `defaultColors` no team in `teams` is using, or the
    /// next one in order when all are taken.
    static func nextColor(after teams: [Team]) -> String {
        let used = Set(teams.map { $0.color.lowercased() })
        return defaultColors.first { !used.contains($0) }
            ?? defaultColors[teams.count % defaultColors.count]
    }

    /// The starting teams, using the count and names from Settings.
    static var defaultNewTeams: [Team] {
        let count = AppSettings.defaultTeamCount()
        return (0..<count).map { index in
            Team(
                name: AppSettings.customTeamName(at: index) ?? String(localized: "team.default_name \(index + 1)"),
                score: 0,
                color: defaultColors[index % defaultColors.count]
            )
        }
    }

    static let sampleTeams: [Team] = [
        Team(name: "Blue Team", score: 2400, color: "blue"),
        Team(name: "Red Team", score: 1800, color: "red"),
        Team(name: "Green Team", score: 600, color: "green"),
    ]
}
