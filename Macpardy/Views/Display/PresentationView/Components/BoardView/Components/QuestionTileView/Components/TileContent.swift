import SwiftUI

extension QuestionTileView {
    var showsHighlight: Bool { isHighlighted && !question.hasBeenPlayed }

    private var tileFill: Color {
        if question.hasBeenPlayed { return MacpardyTheme.tilePlayed }
        return showsHighlight ? MacpardyTheme.tileHover : MacpardyTheme.tileBlue
    }

    func tileContent() -> some View {
        ZStack {
            Rectangle()
                .fill(tileFill)

            if !question.hasBeenPlayed {
                QuestionValueView(value: question.value)
            }

            if showsHighlight {
                Rectangle()
                    .strokeBorder(MacpardyTheme.gold, lineWidth: 6)
            }
        }
        .animation(animationsEnabled ? MacpardyMotion.tileHighlight : nil, value: showsHighlight)
        .aspectRatio(1.4, contentMode: .fit)
        .rotation3DEffect(
            .degrees(isRevealed ? 0 : -90),
            axis: (x: 1, y: 0, z: 0),
            anchor: .top,
            perspective: 0.4
        )
        .opacity(isRevealed ? 1 : 0)
        .animation(MacpardyMotion.tileReveal(row: row), value: isRevealed)
    }
}
