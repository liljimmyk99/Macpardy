//
//  TeamScoreCard.swift
//  Macpardy
//
//  One team's name, phone status and score, with the strip mode's buttons.
//  Right-click to reset the score.
//

import SwiftUI

struct TeamScoreCard: View {

    @Environment(GameState.self) var gameState
    @Environment(BuzzerState.self) var buzzerState

    let team: Team
    let mode: TeamScoreStripMode

    private var buzzedFirst: Bool { buzzerState.firstBuzzTeamID == team.id }

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(team.name)
                        .font(.subheadline.bold())
                        .lineLimit(1)
                    teamStatus
                }

                Text("$\(team.score)")
                    .font(MacpardyTheme.controlTeamScoreFont)
            }

            Spacer(minLength: 0)

            buttons
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity)
        .background(buzzedFirst ? team.displayColor.opacity(0.22) : .clear)
        .background(MacpardyTheme.panelBlue)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(team.displayColor)
                .frame(height: 4)
        }
        .contextMenu {
            LoggedButton("control.score.button.reset", log: "Control › Score strip › \(gameState.teamLabel(team.id)) › Reset (context menu)") {
                gameState.resetScore(for: team.id)
            }
        }
    }

    @ViewBuilder
    private var teamStatus: some View {
        if buzzedFirst {
            Label("control.team.buzzed_first", systemImage: "bolt.fill")
                .font(.caption.bold())
                .foregroundStyle(MacpardyTheme.gold)
        } else if buzzerState.disconnectedTeamIDs.contains(team.id) {
            Image(systemName: "iphone.slash")
                .foregroundStyle(.orange)
                .help("control.team.disconnected")
        } else if buzzerState.claimedTeamIDs.contains(team.id) {
            Image(systemName: "iphone")
                .foregroundStyle(.green)
                .help("control.buzzer.team.connected")
        }
    }

    @ViewBuilder
    private var buttons: some View {
        switch mode {
        case .readOnly:
            EmptyView()

        case .manual:
            adjustButton("control.score.amount.minus_100", amount: -100)
            adjustButton("control.score.amount.plus_100", amount: 100)

        case .clue(let amount, let dailyDoubleTeamID):
            if dailyDoubleTeamID == nil || dailyDoubleTeamID == team.id {
                clueButton(isCorrect: false, amount: amount, isDailyDouble: dailyDoubleTeamID != nil)
                clueButton(isCorrect: true, amount: amount, isDailyDouble: dailyDoubleTeamID != nil)
            }
        }
    }

    private func adjustButton(_ title: LocalizedStringKey, amount: Int) -> some View {
        LoggedButton(title, log: "Control › Score strip › \(gameState.teamLabel(team.id)) \(amount >= 0 ? "+" : "")\(amount)") {
            gameState.adjustScore(for: team.id, by: amount, reason: .hostEdit)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }

    private func clueButton(isCorrect: Bool, amount: Int, isDailyDouble: Bool) -> some View {
        LoggedButton(log: "Control › Score strip › \(gameState.teamLabel(team.id)) \(isCorrect ? "Correct +" : "Wrong −")\(amount)\(isDailyDouble ? " (Daily Double)" : "")") {
            gameState.adjustScore(for: team.id, by: isCorrect ? amount : -amount, reason: isCorrect ? .correct : .incorrect)
            if !isCorrect { SoundPlayer.shared.play(.incorrect) }
            if !isDailyDouble {
                // Ends this team's response time; wrong resumes the question timer.
                gameState.judgeResponse(teamID: team.id, isCorrect: isCorrect)
                updateBuzzer(isCorrect: isCorrect)
            }
        } label: {
            Label(
                isCorrect ? "control.score.short.correct \(amount)" : "control.score.short.wrong \(amount)",
                systemImage: isCorrect ? "checkmark" : "xmark"
            )
            .font(.callout.bold())
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .tint(isCorrect ? .green : .red)
        .accessibilityLabel(Text(isCorrect ? "control.score.button.correct_value \(amount)" : "control.score.button.wrong_value \(amount)"))
    }

    /// A wrong answer locks this team out and re-arms the others; a correct one
    /// stops the buzzers.
    private func updateBuzzer(isCorrect: Bool) {
        Task {
            if isCorrect {
                await buzzerState.teamAnsweredCorrect()
            } else {
                await buzzerState.teamAnsweredWrong(team.id)
            }
        }
    }
}

#Preview {
    TeamScoreCard(team: Team.sampleTeams[0], mode: .clue(amount: 400, dailyDoubleTeamID: nil))
        .environment(GameState())
        .environment(BuzzerState())
        .frame(width: 360)
        .padding()
        .background(MacpardyTheme.boardBlue)
}
