//
//  GameSettingsPane.swift
//  Macpardy
//

import SwiftUI

struct GameSettingsPane: View {

    @AppStorage(AppSettings.Key.questionTimerSeconds)
    private var timerSeconds = AppSettings.defaultQuestionTimerSeconds

    @AppStorage(AppSettings.Key.responseSeconds)
    private var responseSeconds = AppSettings.defaultResponseSeconds

    @AppStorage(AppSettings.Key.defaultTeamCount)
    private var teamCount = AppSettings.defaultTeamCountValue

    @AppStorage(AppSettings.Key.animationsEnabled)
    private var animationsEnabled = AppSettings.defaultAnimationsEnabled

    var body: some View {
        Form {
            Section {
                Stepper(
                    "settings.game.timer \(AppSettings.clampQuestionTimerSeconds(timerSeconds))",
                    value: $timerSeconds,
                    in: AppSettings.questionTimerRange,
                    step: AppSettings.questionTimerStep
                )
                Stepper(
                    "settings.game.response \(AppSettings.clampResponseSeconds(responseSeconds))",
                    value: $responseSeconds,
                    in: AppSettings.responseRange
                )
            } header: {
                Text("settings.game.timers_header")
            } footer: {
                Text("settings.game.timers_footer")
            }

            Section {
                Toggle("settings.game.animations", isOn: $animationsEnabled)
            } header: {
                Text("settings.game.display_header")
            } footer: {
                Text("settings.game.animations_footer")
            }

            Section {
                Stepper(
                    "settings.game.team_count \(AppSettings.clampTeamCount(teamCount))",
                    value: $teamCount,
                    in: AppSettings.teamCountRange
                )
                ForEach(0..<AppSettings.clampTeamCount(teamCount), id: \.self) { index in
                    TeamNameField(index: index)
                }
            } header: {
                Text("settings.game.teams_header")
            } footer: {
                Text("settings.game.teams_footer")
            }
        }
        .formStyle(.grouped)
    }
}

/// The starting name for one team. Empty means "Team N".
private struct TeamNameField: View {

    let index: Int

    @AppStorage private var name: String

    init(index: Int) {
        self.index = index
        _name = AppStorage(wrappedValue: "", AppSettings.Key.teamNamePrefix + String(index))
    }

    var body: some View {
        TextField(
            "settings.game.team_name \(index + 1)",
            text: $name,
            prompt: Text("team.default_name \(index + 1)")
        )
        .logCommit("Settings › Game › Team \(index + 1) name", text: name)
        .onChange(of: name) { _, value in
            if value.count > AppSettings.teamNameMaxLength {
                name = String(value.prefix(AppSettings.teamNameMaxLength))
            }
        }
    }
}
