//
//  QuestionTileButtonView.swift
//  Macpardy
//
//  Created by Jimmy Kane on 10/6/26.
//
import SwiftUI

struct QuestionTileButtonView: View {

    let value: Int
    let isComplete: Bool
    var isUnfilled: Bool = false
    var isDailyDouble: Bool = false
    var hasImage: Bool = false
    /// Where the click is logged, e.g. "Editor › R1 C2 row 3".
    var log = "Editor › Tile"
    let action: () -> Void

    var body: some View {
        LoggedButton(log: log, action: action) {
            ZStack(alignment: .topTrailing) {
                Rectangle()
                    .fill(isComplete ? MacpardyTheme.tileBlue : MacpardyTheme.tileIncomplete)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isComplete ? MacpardyTheme.gold : Color.clear, lineWidth: 2)
                    )
                    .unfilledIndicator(isUnfilled, cornerRadius: 8, iconAlignment: .topLeading)

                HStack(spacing: 4) {
                    if hasImage {
                        Image(systemName: "photo.fill")
                            .foregroundStyle(MacpardyTheme.gold)
                            .font(.caption)
                            .accessibilityLabel(Text("create.board.tile_has_image"))
                    }
                    if isDailyDouble {
                        Image(systemName: "star.fill")
                            .foregroundStyle(MacpardyTheme.gold)
                            .font(.caption)
                    }
                    if isComplete {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(MacpardyTheme.gold)
                    }
                }
                .padding(8)

                QuestionValueView(value: value)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isComplete ? [.isButton, .isSelected] : [.isButton])
        .accessibilityHint(isComplete ? "Completed question, edit to update" : "Incomplete question, edit to complete")
    }
}
