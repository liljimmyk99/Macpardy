import SwiftUI

struct CategoryColumnView: View {

    let category: Category
    /// The board intro shows titles one by one, then the clues together.
    var isTitleShown = true
    var areCluesShown = true
    /// The row the host has highlighted on the Control board (#88), if it's in this column.
    var highlightedRow: Int?

    var body: some View {
        VStack(spacing: 4) {
            categoryHeader()
            questionTiles()
        }
    }
}

#Preview {
    CategoryColumnView(category: MacpardyBoard.sample.categories[0])
        .frame(width: 160)
        .padding()
        .background(MacpardyTheme.boardBlue)
}
