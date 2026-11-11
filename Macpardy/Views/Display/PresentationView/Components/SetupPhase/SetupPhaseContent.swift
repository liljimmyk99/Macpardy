import SwiftUI

extension PresentationView {
    func setupPhaseContent() -> some View {
        VStack(spacing: 32) {
            Spacer()
            GameTitleView(title: "Macpardy!")

            if buzzerState.isRunning {
                buzzerJoinContent()
            } else if !buzzersEnabled {
                // No phones this game (#74): just the teams, no join code or QR.
                DisplayTeamConnectionRow(teams: gameState.game.teams, connectedTeamIDs: nil)
            } else {
                Text("display.setup.waiting")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.8))
            }
            Spacer()
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MacpardyTheme.boardBlue)
    }

    /// QR code, page address and Game PIN, then each team's phone status. Shown
    /// during setup and on the join screen the host can put up mid-game (#83).
    @ViewBuilder
    func buzzerJoinContent() -> some View {
        if let url = buzzerState.serverURL, let baseURL = buzzerState.baseURL {
            if buzzerState.isReconnecting {
                // Phones can't buzz until the room is taken back (#104).
                BuzzerReconnectingBanner()
                    .font(.title3)
            }
            DisplayBuzzerJoinPanel(joinURL: url, baseURL: baseURL, joinCode: buzzerState.joinCode)
            DisplayTeamConnectionRow(
                teams: gameState.game.teams,
                connectedTeamIDs: buzzerState.claimedTeamIDs
            )
        }
    }
}
