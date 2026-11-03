import SwiftUI

extension DailyDoubleControlView {
    @ViewBuilder
    func quickWagerButtons() -> some View {
        HStack(spacing: 8) {
            LoggedButton("control.daily_double.quick_wager.min", log: "Control › Daily Double › Quick wager $5") {
                wagerText = "5"
            }
            .buttonStyle(.bordered)

            if let clueValue = gameState.currentQuestion?.value {
                LoggedButton("control.daily_double.quick_wager.clue_value \(clueValue)", log: "Control › Daily Double › Quick wager clue value $\(clueValue)") {
                    wagerText = "\(clueValue)"
                }
                .buttonStyle(.bordered)
            }

            LoggedButton("control.daily_double.quick_wager.true_daily_double \(maxWager)", log: "Control › Daily Double › Quick wager true Daily Double $\(maxWager)") {
                wagerText = "\(maxWager)"
            }
            .buttonStyle(.bordered)
            .tint(MacpardyTheme.gold)
        }
    }
}
