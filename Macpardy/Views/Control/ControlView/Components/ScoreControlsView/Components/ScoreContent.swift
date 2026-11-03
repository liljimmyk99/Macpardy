import SwiftUI

extension ScoreControlsView {
    @ViewBuilder
    func scoreContent() -> some View {
        if let ddTeamID = gameState.dailyDoubleTeamID,
           let team = gameState.game.teams.first(where: { $0.id == ddTeamID }) {
            dailyDoubleTeamControls(for: team, wager: gameState.dailyDoubleWager)
        } else if gameState.phase == .finalMacpardyQuestion || gameState.phase == .finalMacpardyAnswer {
            ForEach(gameState.game.teams) { team in
                let wager = gameState.finalMacpardyWagers[team.id] ?? 0
                finalMacpardyTeamControls(for: team, wager: wager)
            }
        } else {
            ForEach(gameState.game.teams) { team in
                standardTeamControls(for: team)
            }
        }
    }

    func dailyDoubleTeamControls(for team: Team, wager: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            teamHeader(team)

            HStack(spacing: 8) {
                Text("control.score.daily_double_wager \(wager)")
                    .font(.caption.bold())
                    .foregroundStyle(MacpardyTheme.gold)

                Spacer()

                scoreButton(title: "control.score.button.correct_wager \(wager)", for: team, amount: wager, isCorrect: true)
                scoreButton(title: "control.score.button.wrong_wager \(wager)", for: team, amount: -wager, isCorrect: false)
            }
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    func finalMacpardyTeamControls(for team: Team, wager: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            teamHeader(team)

            HStack(spacing: 8) {
                Text("control.score.fj_wager \(wager)")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                Spacer()

                scoreButton(title: "control.score.button.correct_wager \(wager)", for: team, amount: wager, isCorrect: true)
                scoreButton(title: "control.score.button.wrong_wager \(wager)", for: team, amount: -wager, isCorrect: false)
            }

            if showsFinalAnswer(for: team) {
                finalAnswerRow(for: team)
            }
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    /// Only teams playing with a phone (or that already sent an answer) get an
    /// answer row, so a game without buzzers looks as it did before.
    func showsFinalAnswer(for team: Team) -> Bool {
        gameState.finalMacpardyAnswers[team.id] != nil
            || buzzerState.claimedTeamIDs.contains(team.id)
            || buzzerState.disconnectedTeamIDs.contains(team.id)
    }

    /// The answer the team typed on its phone (#80). Once the correct response
    /// is revealed, the host can put it on the Display, one team at a time.
    func finalAnswerRow(for team: Team) -> some View {
        let answer = gameState.finalMacpardyAnswers[team.id]
        let isRevealed = gameState.finalMacpardyRevealedTeamID == team.id
        let revealTitle: LocalizedStringKey = isRevealed
            ? "control.score.button.hide_fj_answer"
            : "control.score.button.show_fj_answer"
        return HStack(spacing: 8) {
            Image(systemName: "text.bubble.fill")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Group {
                if let answer {
                    Text(verbatim: answer)
                        .fontWeight(.semibold)
                        .textSelection(.enabled)
                } else if gameState.finalAnswerWindow == .open {
                    Text("control.score.fj_answer.waiting")
                        .foregroundStyle(.secondary)
                } else {
                    Text("control.score.fj_answer.none")
                        .foregroundStyle(.secondary)
                }
            }
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)

            if gameState.phase == .finalMacpardyAnswer {
                LoggedButton(log: "Control › Score › \(gameState.teamLabel(team.id)) › \(isRevealed ? "Hide" : "Show") Final answer on Display") {
                    gameState.revealFinalAnswer(teamID: isRevealed ? nil : team.id)
                } label: {
                    Label(revealTitle, systemImage: isRevealed ? "eye.slash.fill" : "tv.fill")
                }
                .buttonStyle(.bordered)
                .tint(isRevealed ? MacpardyTheme.gold : nil)
            }
        }
        .font(.callout)
    }

    func standardTeamControls(for team: Team) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            teamHeader(team)

            HStack(spacing: 6) {
                if let value = gameState.currentQuestion?.value {
                    scoreButton(title: "control.score.button.correct_value \(value)", for: team, amount: value, isCorrect: true)
                    scoreButton(title: "control.score.button.wrong_value \(value)", for: team, amount: -value, isCorrect: false)
                } else {
                    scoreButton(title: "control.score.amount.plus_100", for: team, amount: 100)
                    scoreButton(title: "control.score.amount.minus_100", for: team, amount: -100)
                    scoreButton(title: "control.score.amount.plus_200", for: team, amount: 200)
                    scoreButton(title: "control.score.amount.minus_200", for: team, amount: -200)

                    LoggedButton("control.score.button.reset", log: "Control › Score › \(gameState.teamLabel(team.id)) › Reset") {
                        gameState.resetScore(for: team.id)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    func teamHeader(_ team: Team) -> some View {
        HStack {
            Circle()
                .fill(team.displayColor)
                .frame(width: 12, height: 12)

            Text(team.name)
                .fontWeight(.semibold)

            if buzzerState.firstBuzzTeamID == team.id {
                Label("control.team.buzzed_first", systemImage: "bolt.fill")
                    .font(.caption.bold())
                    .foregroundStyle(MacpardyTheme.gold)
            }

            Spacer()

            Text("$\(team.score)")
                .font(.title3.monospacedDigit())
                .fontWeight(.bold)
        }
    }

    /// Standard questions only: a wrong answer locks the team out and re-arms the
    /// others, a correct one stops the buzzers. Daily Double and Final scoring
    /// never touch the buzzers.
    private func updateBuzzer(for team: Team, isCorrect: Bool?) {
        guard let isCorrect,
              gameState.dailyDoubleTeamID == nil,
              gameState.phase == .question || gameState.phase == .answer else { return }
        gameState.judgeResponse(teamID: team.id, isCorrect: isCorrect)
        Task {
            if isCorrect {
                await buzzerState.teamAnsweredCorrect()
            } else {
                await buzzerState.teamAnsweredWrong(team.id)
            }
        }
    }

    func scoreButton(title: LocalizedStringKey, for team: Team, amount: Int, isCorrect: Bool? = nil) -> some View {
        LoggedButton(title, log: "Control › Score › \(gameState.teamLabel(team.id)) \(amount >= 0 ? "+" : "")\(amount)\(scoreLogSuffix(isCorrect))") {
            gameState.adjustScore(for: team.id, by: amount, reason: scoreReason(isCorrect))
            if isCorrect == false { SoundPlayer.shared.play(.incorrect) }
            updateBuzzer(for: team, isCorrect: isCorrect)
        }
        .buttonStyle(.bordered)
        .tint(isCorrect == true ? .green : (isCorrect == false ? .red : nil))
        .frame(maxWidth: .infinity)
    }

    private func scoreReason(_ isCorrect: Bool?) -> GameState.ScoreReason {
        switch isCorrect {
        case true?: .correct
        case false?: .incorrect
        case nil: .hostEdit
        }
    }

    private func scoreLogSuffix(_ isCorrect: Bool?) -> String {
        switch isCorrect {
        case true?: " (correct)"
        case false?: " (wrong)"
        case nil: ""
        }
    }
}
