//
//  ControlToolbar.swift
//  Macpardy
//
//  Window toolbar: buzzers, the Display window, and the board's round actions.
//

import SwiftUI

extension ControlView {
    @ToolbarContentBuilder
    var controlToolbar: some ToolbarContent {
        if commandAvailability.canReturnToBoard {
            ToolbarItem(placement: .navigation) {
                Button("control.question.button.return_to_board", systemImage: "chevron.backward") {
                    gameState.showBoard()
                }
                .labelStyle(.titleAndIcon)
            }
        }

        if commandAvailability.canOpenBuzzers {
            ToolbarItem(placement: .primaryAction) {
                BuzzerStatusButton()
            }
        }

        ToolbarItem(placement: .primaryAction) {
            SoundMenu()
        }

        ToolbarItem(placement: .primaryAction) {
            Button("shortcuts.toolbar", systemImage: "keyboard") {
                openWindow(id: "shortcuts")
            }
            .help(Text("shortcuts.toolbar.help") + Text(verbatim: " (\(AppShortcut.keyboardShortcuts.glyph))"))
        }

        ToolbarItem(placement: .primaryAction) {
            Button("control.toolbar.show_display", systemImage: "display") {
                openWindow(id: "display")
            }
            .labelStyle(.titleAndIcon)
            .help(Text("control.toolbar.show_display.help") + Text(verbatim: " (\(AppShortcut.showDisplay.glyph))"))
        }

        if commandAvailability.canGoToFinal {
            ToolbarSpacer(.fixed, placement: .primaryAction)

            ToolbarItem(placement: .primaryAction) {
                Button("round.final_macpardy", systemImage: "flag.checkered") {
                    gameState.showFinalMacpardy()
                }
                .labelStyle(.titleAndIcon)
                .foregroundStyle(MacpardyTheme.gold)
            }

            ToolbarItem(placement: .primaryAction) {
                Button("control.board.button.next_round", systemImage: "forward.fill") {
                    gameState.advanceRound()
                }
                .labelStyle(.titleAndIcon)
                .buttonStyle(.borderedProminent)
                .tint(MacpardyTheme.gold)
                .foregroundStyle(MacpardyTheme.boardBlue)
            }
        }
    }
}
