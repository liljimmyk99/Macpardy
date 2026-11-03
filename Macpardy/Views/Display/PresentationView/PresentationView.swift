//
//  PresentationView.swift
//  Macpardy
//
//  Created by Jimmy Kane on 7/15/26.
//

import SwiftUI

struct PresentationView: View {

    @Environment(GameState.self) var gameState
    @Environment(BuzzerState.self) var buzzerState
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @AppStorage(AppSettings.Key.animationsEnabled)
    var animationsSetting = AppSettings.defaultAnimationsEnabled
    @AppStorage(AppSettings.Key.buzzersEnabled)
    var buzzersEnabled = AppSettings.defaultBuzzersEnabled

    var animates: Bool {
        AppSettings.shouldAnimate(setting: animationsSetting, reduceMotion: reduceMotion)
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                phaseContent
            }
            .animation(animates ? MacpardyMotion.quick : nil, value: gameState.phase)

            ScoreboardView(
                teams: gameState.game.teams,
                disconnectedTeamIDs: buzzerState.disconnectedTeamIDs,
                responseCountdown: gameState.responseCountdown
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MacpardyTheme.boardBlue)
        .environment(\.animationsEnabled, animates)
    }
}

#Preview {
    PresentationView()
        .environment(GameState())
        .environment(BuzzerState())
        .frame(width: 960, height: 540)
}
