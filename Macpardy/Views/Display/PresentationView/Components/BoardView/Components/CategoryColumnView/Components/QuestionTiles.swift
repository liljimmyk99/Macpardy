import SwiftUI

extension CategoryColumnView {
    func questionTiles() -> some View {
        ForEach(Array(category.questions.enumerated()), id: \.element.id) { row, question in
            QuestionTileView(
                question: question,
                isRevealed: areCluesShown,
                row: row,
                isHighlighted: row == highlightedRow
            )
        }
    }
}
