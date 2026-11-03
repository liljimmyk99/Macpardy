import SwiftUI

extension FinalMacpardyControlView {
    func finalMacpardyHeader() -> some View {
        HStack {
            Text("display.final_macpardy.header")
                .font(.headline)
                .foregroundStyle(MacpardyTheme.gold)

            if let categoryTitle = gameState.currentCategoryTitle {
                Text("• \(categoryTitle.uppercased())")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if gameState.phase == .finalMacpardyAnswer {
                LoggedButton(log: "Control › Final › Complete game", role: .destructive) {
                    completeGame()
                } label: {
                    Label("control.final_macpardy.button.complete_game", systemImage: "flag.checkered.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }

            LoggedButton(log: "Control › Final › Return to board") {
                gameState.showBoard()
            } label: {
                Label("control.question.button.return_to_board", systemImage: "arrowshape.turn.up.backward.fill")
            }
            .buttonStyle(.bordered)
        }
    }

    func finalMacpardyQuestionDetails() -> some View {
        Group {
            if let question = gameState.currentQuestion {
                GroupBox("control.final_macpardy.clue_and_answer_group") {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("control.final_macpardy.clue_header")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            Text(question.clue)
                                .font(.title3)
                                .fontWeight(.medium)
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 4) {
                            Text("control.question.correct_response_header")
                                .font(.caption.bold())
                                .foregroundStyle(MacpardyTheme.gold)
                            Text(question.response)
                                .font(.title3.bold())
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                }
            }
        }
    }

    func revealAnswerButton() -> some View {
        HStack {
            LargeButton(
                title: gameState.phase == .finalMacpardyAnswer ? "control.question.button.answer_revealed" : "control.question.button.reveal_answer",
                systemImage: "eye.fill",
                tint: gameState.phase == .finalMacpardyAnswer ? .secondary : .accentColor,
                log: "Control › Final › Reveal answer"
            ) {
                gameState.revealAnswer()
            }
            .disabled(gameState.phase == .finalMacpardyAnswer)
            .help(Text("control.question.button.reveal_answer") + Text(verbatim: " (\(AppShortcut.revealAnswer.glyph))"))

            Spacer()
        }
    }
}
