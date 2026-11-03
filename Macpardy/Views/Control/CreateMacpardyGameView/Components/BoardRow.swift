//
//  BoardRow.swift
//  Macpardy
//
//  Created by Jimmy Kane on 10/6/26.
//
import SwiftUI

struct BoardRow: View {
    @Binding var draftCategories: [DraftCategory]
    @Binding var selectedQuestion: EditingQuestion?
    var rowIndex: Int
    var value: Int
    var round = 0
    var unfilled: [UnfilledField] = []

    var body: some View {
        ForEach(Array(draftCategories.enumerated()), id: \.element.id) { categoryIndex, category in
            let question = category.questions[rowIndex]
            let isUnfilled = unfilled.contains(.clue, round: round, category: categoryIndex, row: rowIndex)
                || unfilled.contains(.answer, round: round, category: categoryIndex, row: rowIndex)
            let status = isUnfilled
                ? String(localized: "create.board.tile_default_text")
                : (question.isComplete ? String(localized: "create.board.tile_completed") : String(localized: "create.board.tile_incomplete"))
            QuestionTileButtonView(
                value: value,
                isComplete: question.isComplete && !isUnfilled,
                isUnfilled: isUnfilled,
                isDailyDouble: question.isDailyDouble,
                hasImage: question.image != nil,
                log: "Editor › R\(round + 1) C\(categoryIndex + 1) row \(rowIndex + 1) $\(value)",
                action: {
                    selectedQuestion = EditingQuestion(
                        categoryIndex: categoryIndex,
                        questionIndex: rowIndex,
                        value: value,
                        clue: question.clue,
                        response: question.response,
                        isDailyDouble: question.isDailyDouble
                    )
                }
            )
            .frame(width: 180, height: 120)
            .accessibilityLabel(Text("create.board.tile_accessibility \(category.title) \(value) \(status)"))
        }
    }
}
