//
//  BoardControlView.swift
//  Macpardy
//
//  Created by Jimmy Kane on 10/10/26.
//

import SwiftUI

/// The host's copy of the Display board: same layout, plus Daily Double and
/// picture markers only the host sees. Clicking a tile opens that clue; the
/// arrow keys move a highlight over the open tiles and Return or Space opens it.
struct BoardControlView: View {

    @Environment(GameState.self) var gameState

    @FocusState private var isFocused: Bool

    var body: some View {
        Group {
            if let board = gameState.game.currentBoard {
                boardGrid(board)
            } else {
                Text("control.board.no_board_available")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .focusable()
        .focusEffectDisabled()
        .focused($isFocused)
        .onAppear { isFocused = true }
        .onKeyPress(keys: [.upArrow, .downArrow, .leftArrow, .rightArrow]) { press in
            handleArrow(press)
        }
        .onKeyPress(keys: [.return, .space]) { press in
            guard isPlainKey(press) else { return .ignored }
            AppLogger.control.shortcut(ShortcutFormatter.keyGlyph(press.key), "Open highlighted clue")
            gameState.openHighlightedQuestion()
            return .handled
        }
    }
}

#Preview {
    let gameState = GameState()
    gameState.loadGame(boards: [MacpardyBoard.sample])

    return BoardControlView()
        .environment(gameState)
        .background(MacpardyTheme.boardBlue)
        .frame(width: 1100, height: 640)
}
