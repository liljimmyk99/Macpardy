import SwiftUI

struct QuestionTileView: View {

    @Environment(\.animationsEnabled) var animationsEnabled

    let question: Question
    /// False while the board intro is still to turn this tile over.
    var isRevealed = true
    /// The tile's row, which staggers the board intro.
    var row = 0
    /// Picked by the host with the arrow keys or the mouse; drawn only while unplayed.
    var isHighlighted = false

    var body: some View {
        tileContent()
    }
}

#Preview {
    HStack {
        QuestionTileView(question: Question(value: 400, clue: "Test", response: "Test"))
        QuestionTileView(question: Question(value: 600, clue: "Test", response: "Test"), isHighlighted: true)
        QuestionTileView(
            question: Question(value: 400, clue: "Test", response: "Test", hasBeenPlayed: true)
        )
    }
    .frame(width: 450)
    .padding()
    .background(MacpardyTheme.boardBlue)
}
