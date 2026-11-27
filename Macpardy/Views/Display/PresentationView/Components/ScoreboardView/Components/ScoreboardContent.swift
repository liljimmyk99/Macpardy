import SwiftUI

extension ScoreboardView {
    func scoreboardContent() -> some View {
        HStack(spacing: teams.count > 4 ? 16 : 32) {
            ForEach(teams) { team in
                TeamScoreView(
                    team: team,
                    isDisconnected: disconnectedTeamIDs.contains(team.id),
                    responseCountdown: responseCountdown?.teamID == team.id ? responseCountdown : nil
                )
            }
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 16)
        .background(MacpardyTheme.boardBlue.opacity(0.95))
    }
}
