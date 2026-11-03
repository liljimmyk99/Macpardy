import SwiftUI

extension PresentationView {
    /// The buzzer join screen the host puts over any phase from the Buzzers popover
    /// or the Game menu (#83), so late or dropped phones can join mid-game.
    func joinScreenContent() -> some View {
        VStack(spacing: 32) {
            Spacer()
            Text("display.join_screen.title")
                .font(MacpardyTheme.titleFont)
                .foregroundStyle(MacpardyTheme.gold)

            if buzzerState.isRunning {
                buzzerJoinContent()
            } else {
                Text("display.join_screen.unavailable")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.8))
            }
            Spacer()
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MacpardyTheme.boardBlue)
    }
}
