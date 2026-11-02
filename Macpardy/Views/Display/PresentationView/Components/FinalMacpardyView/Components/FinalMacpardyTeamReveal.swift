import SwiftUI

extension FinalMacpardyView {
    /// The team the host is spotlighting after the correct response (#80):
    /// its name, the answer it typed on its phone, and its wager.
    @ViewBuilder
    func finalMacpardyTeamReveal() -> some View {
        if let team = gameState.finalMacpardyRevealedTeam {
            VStack(spacing: 14) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(team.displayColor)
                        .frame(width: 22, height: 22)
                    Text(verbatim: team.name)
                        .font(MacpardyTheme.titleFont)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }

                Group {
                    if let answer = gameState.finalMacpardyAnswers[team.id] {
                        Text(verbatim: answer)
                            .foregroundStyle(.white)
                    } else {
                        Text("display.final_macpardy.team_answer.none")
                            .foregroundStyle(MacpardyTheme.mutedText)
                    }
                }
                .font(MacpardyTheme.clueFont)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.5)

                Text("display.final_macpardy.team_wager \(gameState.finalMacpardyWagers[team.id] ?? 0)")
                    .font(MacpardyTheme.scoreFont)
                    .foregroundStyle(MacpardyTheme.gold)
            }
            .padding(.vertical, 28)
            .padding(.horizontal, 48)
            .frame(maxWidth: 1200)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(MacpardyTheme.panelBlue)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(team.displayColor, lineWidth: 4)
            )
            .padding(.horizontal, 60)
            .id(team.id)
            .transition(.asymmetric(
                insertion: MacpardyMotion.flipIn(animated: animationsEnabled),
                removal: .opacity
            ))
        }
    }
}
