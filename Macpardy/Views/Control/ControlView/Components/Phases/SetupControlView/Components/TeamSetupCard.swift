//
//  TeamSetupCard.swift
//  Macpardy
//
//  One team on the setup screen: name, color swatches, phone status (when
//  buzzers are on), remove.
//

import SwiftUI

struct TeamSetupCard: View {

    @Environment(GameState.self) var gameState
    @Environment(BuzzerState.self) var buzzerState
    @AppStorage(AppSettings.Key.buzzersEnabled) private var buzzersEnabled = AppSettings.defaultBuzzersEnabled

    let team: Team

    private var teamIndex: Int? {
        gameState.game.teams.firstIndex(where: { $0.id == team.id })
    }

    private var nameBinding: Binding<String> {
        Binding(
            get: { teamIndex.map { gameState.game.teams[$0].name } ?? team.name },
            set: { newName in
                if let teamIndex { gameState.game.teams[teamIndex].name = newName }
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("control.setup.team_name_label")
                    .font(.caption.bold())
                    .foregroundStyle(MacpardyTheme.mutedText)
                TextField("control.setup.team_name_placeholder", text: nameBinding)
                    .textFieldStyle(.plain)
                    .font(.title2.bold())
                    .padding(10)
                    .background(MacpardyTheme.panelBlue, in: RoundedRectangle(cornerRadius: 8))
                    .logCommit("Control › Setup › \(gameState.teamLabel(team.id)) › Name", text: team.name)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("control.setup.color_picker_label")
                    .font(.caption.bold())
                    .foregroundStyle(MacpardyTheme.mutedText)
                HStack(spacing: 10) {
                    ForEach(Team.colorOptions, id: \.self) { color in
                        swatch(color)
                    }
                }
            }

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                if buzzersEnabled {
                    phoneStatus
                }
                Spacer()
                if buzzersEnabled, buzzerState.claimedTeamIDs.contains(team.id) {
                    LoggedButton("control.team.remove_phone", log: "Control › Setup › \(gameState.teamLabel(team.id)) › Remove phone") {
                        Task { await buzzerState.removePhone(forTeam: team.id) }
                    }
                    .help("control.team.remove_phone.help")
                }
                if gameState.game.teams.count > 1 {
                    LoggedButton("control.setup.button.remove_team", log: "Control › Setup › \(gameState.teamLabel(team.id)) › Remove team", role: .destructive) {
                        gameState.removeTeam(id: team.id)
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .padding(20)
        .padding(.top, 6)
        .background(MacpardyTheme.tileBlue)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(team.displayColor)
                .frame(height: 6)
        }
    }

    private func swatch(_ color: String) -> some View {
        let isSelected = team.color == color
        return LoggedButton(log: "Control › Setup › \(gameState.teamLabel(team.id)) › Color \(color)") {
            if let teamIndex { gameState.game.teams[teamIndex].color = color }
        } label: {
            Circle()
                .fill(Team.displayColor(for: color))
                .frame(width: 26, height: 26)
                .padding(3)
                .overlay(
                    Circle()
                        .strokeBorder(isSelected ? Color.white : .clear, lineWidth: 2)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(Self.colorName(color)))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .help(Text(Self.colorName(color)))
    }

    @ViewBuilder
    private var phoneStatus: some View {
        if buzzerState.claimedTeamIDs.contains(team.id) {
            Label("control.buzzer.team.connected", systemImage: "iphone")
                .foregroundStyle(.green)
        } else if buzzerState.disconnectedTeamIDs.contains(team.id) {
            Label("control.team.disconnected", systemImage: "iphone.slash")
                .foregroundStyle(.orange)
        } else {
            Label("control.buzzer.team.waiting", systemImage: "iphone")
                .foregroundStyle(MacpardyTheme.mutedText)
        }
    }

    private static func colorName(_ color: String) -> LocalizedStringKey {
        switch color {
        case "blue": "color.blue"
        case "red": "color.red"
        case "green": "color.green"
        case "yellow": "color.yellow"
        case "purple": "color.purple"
        case "orange": "color.orange"
        default: "color.blue"
        }
    }
}

#Preview {
    TeamSetupCard(team: Team.sampleTeams[0])
        .environment(GameState())
        .environment(BuzzerState())
        .frame(width: 420, height: 280)
        .padding()
        .background(MacpardyTheme.boardBlue)
}
