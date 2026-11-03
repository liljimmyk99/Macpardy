import SwiftUI

extension FinalMacpardyCategoryControlView {
    func finalMacpardyHeader() -> some View {
        VStack(spacing: 8) {
            Text("display.final_macpardy.header")
                .font(.system(size: 32, weight: .black))
                .foregroundStyle(MacpardyTheme.gold)

            if let category = gameState.currentCategoryTitle {
                Text("control.daily_double.label_category \(category)")
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
            }

            Text("control.final_macpardy.subtitle_status")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 10)
    }

    func teamWagerGroup() -> some View {
        GroupBox("control.final_macpardy.team_wagers_group") {
            VStack(spacing: 16) {
                ForEach(gameState.game.teams, id: \.id) { team in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(team.displayColor)
                            .frame(width: 14, height: 14)

                        Text(team.name)
                            .fontWeight(.semibold)

                        Spacer()

                        Text("control.final_macpardy.current_score \(team.score)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        wagerStatus(for: team)

                        if gameState.isFinalEligible(team) {
                            HStack {
                                Text("$")
                                    .foregroundStyle(.secondary)

                                TextField("control.daily_double.wager_placeholder", text: Binding(
                                    get: { wagers[team.id] ?? "" },
                                    set: { wagers[team.id] = $0 }
                                ))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 100)
                                .font(.monospacedDigit(.body)())
                                .onSubmit { commitWager(for: team) }
                                .logCommit("Control › Final › \(gameState.teamLabel(team.id)) › Wager", text: wagers[team.id] ?? "")
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding()
        }
        .frame(maxWidth: 600)
    }

    func wagerStatus(for team: Team) -> some View {
        Group {
            if !gameState.isFinalEligible(team) {
                Text("control.final_macpardy.wager_status.excluded")
            } else if let wager = gameState.finalMacpardyWagers[team.id] {
                Text("control.final_macpardy.wager_status.submitted \(wager)")
            } else {
                Text("control.final_macpardy.wager_status.waiting")
            }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }

    func revealQuestionButton() -> some View {
        LargeButton(
            title: "control.final_macpardy.button.reveal_question",
            systemImage: "questionmark.circle.fill",
            tint: MacpardyTheme.gold,
            log: "Control › Final › Reveal question"
        ) {
            for team in gameState.game.teams {
                commitWager(for: team)
            }
            // Teams without a wager go all-in.
            gameState.revealFinalMacpardyQuestion()
        }
        .frame(maxWidth: 300)
    }

    /// Stores the host's entry (also pushing it to the team's phone). A blank
    /// entry clears the wager, so the team defaults to all-in.
    func commitWager(for team: Team) {
        guard gameState.isFinalEligible(team) else { return }
        let text = (wagers[team.id] ?? "").trimmingCharacters(in: .whitespaces)
        if let parsed = Int(text) {
            let stored = gameState.setFinalWager(teamID: team.id, amount: parsed)
            wagers[team.id] = stored.map(String.init) ?? ""
            Task { await buzzerState.hostSetWager(teamID: team.id, amount: stored) }
        } else if gameState.finalMacpardyWagers[team.id] != nil, text.isEmpty {
            gameState.clearFinalWager(teamID: team.id)
            Task { await buzzerState.hostSetWager(teamID: team.id, amount: nil) }
        }
    }

    func syncWagersFromGameState() {
        // Only stored wagers overwrite the fields, so a half-typed entry survives
        // another team's wager arriving.
        for team in gameState.game.teams {
            if let wager = gameState.finalMacpardyWagers[team.id] {
                wagers[team.id] = String(wager)
            }
        }
    }
}
