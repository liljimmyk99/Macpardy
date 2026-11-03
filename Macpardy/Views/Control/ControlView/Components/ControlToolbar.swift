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
                LoggedButton("control.question.button.return_to_board", systemImage: "chevron.backward", log: "Control › Toolbar › Return to board") {
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
            LoggedButton("shortcuts.toolbar", systemImage: "keyboard", log: "Control › Toolbar › Keyboard shortcuts") {
                openWindow(id: "shortcuts")
            }
            .help(Text("shortcuts.toolbar.help") + Text(verbatim: " (\(AppShortcut.keyboardShortcuts.glyph))"))
        }

        ToolbarItem(placement: .primaryAction) {
            LoggedButton("control.toolbar.show_display", systemImage: "display", log: "Control › Toolbar › Show Display") {
                openWindow(id: "display")
            }
            .labelStyle(.titleAndIcon)
            .help(Text("control.toolbar.show_display.help") + Text(verbatim: " (\(AppShortcut.showDisplay.glyph))"))
        }

        if commandAvailability.canGoToFinal {
            ToolbarSpacer(.fixed, placement: .primaryAction)

            ToolbarItem(placement: .primaryAction) {
                LoggedButton("round.final_macpardy", systemImage: "flag.checkered", log: "Control › Toolbar › Final Macpardy") {
                    gameState.showFinalMacpardy()
                }
                .labelStyle(.titleAndIcon)
                .foregroundStyle(MacpardyTheme.gold)
            }

            ToolbarItem(placement: .primaryAction) {
                LoggedButton("control.board.button.next_round", systemImage: "forward.fill", log: "Control › Toolbar › Next round") {
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
