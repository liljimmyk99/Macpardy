import SwiftUI

struct FinalMacpardyView: View {

    @Environment(GameState.self) var gameState
    @Environment(\.animationsEnabled) var animationsEnabled

    var body: some View {
        finalMacpardyContent()
            .animation(
                animationsEnabled ? MacpardyMotion.quick : nil,
                value: gameState.finalMacpardyRevealedTeamID
            )
    }
}

#Preview {
    let gameState = GameState()
    gameState.currentCategoryTitle = "Think Music"
    gameState.phase = .finalMacpardyCategory

    return FinalMacpardyView()
        .environment(gameState)
        .frame(width: 960, height: 540)
}
