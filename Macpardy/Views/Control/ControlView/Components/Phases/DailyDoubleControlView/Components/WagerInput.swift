import SwiftUI

extension DailyDoubleControlView {
    @ViewBuilder
    func wagerInput() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("control.daily_double.wager_amount_label")
                    .font(.headline)
                Spacer()
                Text("control.daily_double.max_allowed \(maxWager)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("$")
                    .font(.title2.bold())
                    .foregroundStyle(.secondary)

                TextField("control.daily_double.wager_placeholder", text: $wagerText)
                    .textFieldStyle(.roundedBorder)
                    .font(.title3.monospacedDigit())
                    .logCommit("Control › Daily Double › Wager", text: wagerText)
            }

            quickWagerButtons()
        }
    }
}
