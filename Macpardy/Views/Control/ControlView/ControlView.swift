//
//  ControlView.swift
//  Macpardy
//
//  Created by Jimmy Kane on 7/15/26.
//

import SwiftUI

struct ControlView: View {

    @Environment(\.openWindow) var openWindow
    @Environment(GameState.self) var gameState
    @Environment(\.undoManager) var undoManager
    @AppStorage(AppSettings.Key.buzzersEnabled) var buzzersEnabled = AppSettings.defaultBuzzersEnabled

    var body: some View {
        VStack(spacing: 0) {
            detailContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if let teamStripMode {
                TeamScoreStripView(mode: teamStripMode)
            }
        }
        .background(MacpardyTheme.boardBlue)
        .preferredColorScheme(.dark)
        .navigationTitle(navigationTitleText)
        .navigationSubtitle(navigationSubtitleText)
        .toolbar { controlToolbar }
        .toolbarBackground(MacpardyTheme.panelBlue, for: .windowToolbar)
        .toolbarBackgroundVisibility(.visible, for: .windowToolbar)
        // Score changes go on this window's undo stack (Edit > Undo).
        .onAppear { gameState.scoreUndoManager = undoManager }
        .onChange(of: undoManager) { _, manager in gameState.scoreUndoManager = manager }
    }
}

#Preview {
    let gameState = GameState()
    gameState.phase = .board

    return ControlView()
        .environment(gameState)
        .environment(BuzzerState())
        .frame(width: 1200, height: 800)
}
