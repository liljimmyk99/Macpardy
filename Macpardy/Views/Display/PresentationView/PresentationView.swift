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

    /// The host put the join screen up over a game phase (#83). Setup already shows it.
    var showsJoinScreen: Bool {
        buzzerState.isJoinScreenOnDisplay && gameState.phase != .setup
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                phaseContent

                if showsJoinScreen {
                    joinScreenContent()
                        .transition(animates ? .opacity : .identity)
                        .zIndex(1)
                }
            }
            .animation(animates ? MacpardyMotion.quick : nil, value: gameState.phase)
            .animation(animates ? MacpardyMotion.quick : nil, value: showsJoinScreen)

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
