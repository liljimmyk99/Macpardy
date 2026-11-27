//
//  DisplayTeamConnectionRow.swift
//  Macpardy
//
//  One chip per team on the Display's setup screen showing whether a phone
//  has joined as that team yet (or just the team, when buzzers are off).
//

import SwiftUI

struct DisplayTeamConnectionRow: View {

    let teams: [Team]
    /// `nil` when buzzers are off: names only, no phone status.
    let connectedTeamIDs: Set<UUID>?

    /// Up to four chips fit on one line; five or six wrap into rows of three.
    private var rows: [[Team]] {
        let perRow = teams.count > 4 ? 3 : max(teams.count, 1)
        return stride(from: 0, to: teams.count, by: perRow).map {
            Array(teams[$0..<min($0 + perRow, teams.count)])
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            ForEach(rows.indices, id: \.self) { rowIndex in
                HStack(spacing: 20) {
                    ForEach(rows[rowIndex]) { team in
                        teamChip(team, isConnected: connectedTeamIDs?.contains(team.id))
                    }
                }
            }
        }
    }

    /// `isConnected` is `nil` when buzzers are off; the chip then reads as ready.
    private func teamChip(_ team: Team, isConnected phoneStatus: Bool?) -> some View {
        let isConnected = phoneStatus ?? true
        return VStack(spacing: 10) {
            Text(team.name)
                .font(.title2.weight(.semibold))
                .foregroundStyle(team.displayColor)
                .lineLimit(1)

            if phoneStatus != nil {
                Label(
                    isConnected ? "display.setup.team.connected" : "display.setup.team.not_connected",
                    systemImage: isConnected ? "checkmark.circle.fill" : "iphone.slash"
                )
                .font(.title3.weight(.medium))
                .foregroundStyle(isConnected ? .green : MacpardyTheme.mutedText)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 24)
        .frame(minWidth: 200)
        .background(MacpardyTheme.panelBlue, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(isConnected ? team.displayColor : .white.opacity(0.15), lineWidth: isConnected ? 3 : 1)
        }
        .opacity(isConnected ? 1 : 0.75)
        .animation(.easeInOut(duration: 0.25), value: isConnected)
    }
}

#Preview("Six teams") {
    let teams = Team.colorOptions.enumerated().map { Team(name: "Team \($0.offset + 1)", color: $0.element) }
    return DisplayTeamConnectionRow(teams: teams, connectedTeamIDs: [teams[0].id, teams[4].id])
        .padding()
        .background(MacpardyTheme.boardBlue)
}

#Preview {
    DisplayTeamConnectionRow(teams: Team.sampleTeams, connectedTeamIDs: [Team.sampleTeams[0].id])
        .padding()
        .background(MacpardyTheme.boardBlue)
}
