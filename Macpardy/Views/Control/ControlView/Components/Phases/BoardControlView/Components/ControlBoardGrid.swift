import SwiftUI

extension BoardControlView {
    func boardGrid(_ board: MacpardyBoard) -> some View {
        HStack(alignment: .top, spacing: 4) {
            ForEach(Array(board.categories.enumerated()), id: \.element.id) { column, category in
                VStack(spacing: 4) {
                    CategoryHeaderView(title: category.title, font: MacpardyTheme.controlCategoryFont)
                        .frame(height: 64)

                    ForEach(Array(category.questions.enumerated()), id: \.element.id) { row, question in
                        let position = BoardPosition(column: column, row: row)
                        ControlQuestionTile(
                            question: question,
                            categoryTitle: category.title,
                            isHighlighted: gameState.highlightedTile == position
                        ) {
                            gameState.selectQuestion(question, categoryTitle: category.title)
                        } onHover: {
                            gameState.highlightedTile = position
                        }
                    }
                }
            }
        }
        .padding(8)
    }
}
