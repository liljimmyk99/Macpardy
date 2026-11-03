//
//  FinalMacpardyControlView.swift
//  Macpardy
//
//  Created by Jimmy Kane on 10/10/26.
//

import SwiftUI

struct FinalMacpardyControlView: View {

    @Environment(GameState.self) var gameState
    @Environment(\.completeGame) var completeGame

    var body: some View {
        VStack(spacing: 20) {
            finalMacpardyHeader()
            finalMacpardyQuestionDetails()
            revealAnswerButton()
            TimerControlsView()
            ScoreControlsView()
            Spacer()
        }
        .padding()
    }
}

#Preview {
    let gameState = GameState()
    gameState.showFinalMacpardy(categoryTitle: "Science")
    gameState.revealFinalMacpardyQuestion()

    return FinalMacpardyControlView()
        .environment(gameState)
}
