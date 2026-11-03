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
            Button("control.question.button.return_to_board") {
                gameState.showBoard()
            }
            .keyboardShortcut(.returnToBoard)
            .disabled(!availability.canReturnToBoard)

            Button("control.board.button.next_round") {
                gameState.advanceRound()
            }
            .keyboardShortcut(.nextRound)
            .disabled(!availability.canAdvanceRound)

            Button("round.final_macpardy") {
                gameState.showFinalMacpardy()
            }
            .keyboardShortcut(.finalMacpardy)
            .disabled(!availability.canGoToFinal)

            Divider()

            Button("control.question.button.reveal_answer") {
                gameState.revealAnswer()
            }
            .keyboardShortcut(.revealAnswer)
            .disabled(!availability.canRevealAnswer)

            Button(gameState.timer.isRunning ? "menu.game.timer.pause" : "menu.game.timer.start") {
                if gameState.timer.isRunning {
                    gameState.timer.stop()
                } else {
                    gameState.timer.start()
                }
            }
            .keyboardShortcut(.toggleTimer)
            .disabled(!availability.canControlTimer)

            Button("menu.game.timer.reset") {
                gameState.resetTimer()
            }
            .keyboardShortcut(.resetTimer)
            .disabled(!availability.canControlTimer)

            Button("menu.game.timer.minus_5") {
                gameState.timer.addSeconds(-5)
            }
            .keyboardShortcut(.timerMinus5)
            .disabled(!availability.canControlTimer)

            Button("menu.game.timer.plus_5") {
                gameState.timer.addSeconds(5)
            }
            .keyboardShortcut(.timerPlus5)
            .disabled(!availability.canControlTimer)

            Divider()

            Button("control.toolbar.show_display") {
                openWindow(id: "display")
            }
            .keyboardShortcut(.showDisplay)
            .disabled(!availability.canShowDisplay)

            Button("menu.game.buzzers") {
                buzzerState.isPopoverPresented.toggle()
            }
            .keyboardShortcut(.buzzers)
            .disabled(!availability.canOpenBuzzers)

            Button(buzzerState.isJoinScreenOnDisplay ? "menu.game.join_screen.hide" : "menu.game.join_screen.show") {
                buzzerState.isJoinScreenOnDisplay.toggle()
            }
            .keyboardShortcut(.joinScreen)
            .disabled(!availability.canShowJoinScreen)
        }
    }
}
