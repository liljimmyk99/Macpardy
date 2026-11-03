//
//  GameCommands.swift
//  Macpardy
//
//  The Game menu. Items are always listed and greyed out when they don't
//  apply, and call the same GameState methods as the on-screen buttons.
//

import SwiftUI

struct GameCommands: Commands {

    let gameState: GameState
    let buzzerState: BuzzerState
    let hasSelectedGame: Bool
    let buzzersEnabled: Bool

    @Environment(\.openWindow) private var openWindow

    private var availability: GameCommandAvailability {
        GameCommandAvailability(phase: gameState.phase, hasSelectedGame: hasSelectedGame, buzzersEnabled: buzzersEnabled)
    }

    var body: some Commands {
        CommandMenu("menu.game") {
            LoggedButton("control.question.button.return_to_board", log: "Game › Return to board", source: .menu) {
                gameState.showBoard()
            }
            .keyboardShortcut(.returnToBoard)
            .disabled(!availability.canReturnToBoard)

            LoggedButton("control.board.button.next_round", log: "Game › Next round", source: .menu) {
                gameState.advanceRound()
            }
            .keyboardShortcut(.nextRound)
            .disabled(!availability.canAdvanceRound)

            LoggedButton("round.final_macpardy", log: "Game › Final Macpardy", source: .menu) {
                gameState.showFinalMacpardy()
            }
            .keyboardShortcut(.finalMacpardy)
            .disabled(!availability.canGoToFinal)

            Divider()

            LoggedButton("control.question.button.reveal_answer", log: "Game › Reveal answer", source: .menu) {
                gameState.revealAnswer()
            }
            .keyboardShortcut(.revealAnswer)
            .disabled(!availability.canRevealAnswer)

            LoggedButton(gameState.timer.isRunning ? "menu.game.timer.pause" : "menu.game.timer.start", log: "Game › \(gameState.timer.isRunning ? "Pause" : "Start") timer", source: .menu) {
                if gameState.timer.isRunning {
                    gameState.timer.stop()
                } else {
                    gameState.timer.start()
                }
            }
            .keyboardShortcut(.toggleTimer)
            .disabled(!availability.canControlTimer)

            LoggedButton("menu.game.timer.reset", log: "Game › Reset timer", source: .menu) {
                gameState.resetTimer()
            }
            .keyboardShortcut(.resetTimer)
            .disabled(!availability.canControlTimer)

            LoggedButton("menu.game.timer.minus_5", log: "Game › Timer −5s", source: .menu) {
                gameState.timer.addSeconds(-5)
            }
            .keyboardShortcut(.timerMinus5)
            .disabled(!availability.canControlTimer)

            LoggedButton("menu.game.timer.plus_5", log: "Game › Timer +5s", source: .menu) {
                gameState.timer.addSeconds(5)
            }
            .keyboardShortcut(.timerPlus5)
            .disabled(!availability.canControlTimer)

            Divider()

            LoggedButton("control.toolbar.show_display", log: "Game › Show Display", source: .menu) {
                openWindow(id: "display")
            }
            .keyboardShortcut(.showDisplay)
            .disabled(!availability.canShowDisplay)

            LoggedButton("menu.game.buzzers", log: "Game › Buzzers", source: .menu) {
                buzzerState.isPopoverPresented.toggle()
            }
            .keyboardShortcut(.buzzers)
            .disabled(!availability.canOpenBuzzers)

            LoggedButton(buzzerState.isJoinScreenOnDisplay ? "menu.game.join_screen.hide" : "menu.game.join_screen.show", log: "Game › \(buzzerState.isJoinScreenOnDisplay ? "Hide" : "Show") join screen", source: .menu) {
                buzzerState.isJoinScreenOnDisplay.toggle()
            }
            .keyboardShortcut(.joinScreen)
            .disabled(!availability.canShowJoinScreen)
        }
    }
}
