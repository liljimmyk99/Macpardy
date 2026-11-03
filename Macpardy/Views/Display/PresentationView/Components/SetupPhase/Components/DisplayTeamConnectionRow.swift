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

    var body: some View {
        HStack(spacing: 20) {
            ForEach(teams) { team in
                teamChip(team, isConnected: connectedTeamIDs?.contains(team.id))
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

#Preview {
    DisplayTeamConnectionRow(teams: Team.sampleTeams, connectedTeamIDs: [Team.sampleTeams[0].id])
        .padding()
        .background(MacpardyTheme.boardBlue)
}
