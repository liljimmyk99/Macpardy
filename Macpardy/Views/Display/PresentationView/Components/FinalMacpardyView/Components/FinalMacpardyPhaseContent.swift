import SwiftUI

extension FinalMacpardyView {
    @ViewBuilder
    func finalMacpardyPhaseContent() -> some View {
        switch gameState.phase {
        case .finalMacpardyCategory:
            EmptyView()

        case .finalMacpardyQuestion:
            finalMacpardyQuestion()
            TimerView()
                .onAppear {
                    gameState.timer.start()
                }

        case .finalMacpardyAnswer:
            finalMacpardyAnswer()
            finalMacpardyTeamReveal()

        default:
            EmptyView()
        }
    }
}
