//
//  CategoryRow.swift
//  Macpardy
//
//  Created by Jimmy Kane on 10/6/26.
//
import SwiftUI
struct CategoryRow: View {
    @Binding var draftCategories: [DraftCategory]
    var round = 0
    var unfilled: [UnfilledField] = []

    var body: some View {
        HStack(spacing: 8) {
            ForEach(draftCategories.indices, id: \.self) { index in
                EditableCategoryHeaderView(
                    title: $draftCategories[index].title,
                    placeholder: "Category \(index + 1)",
                    isUnfilled: unfilled.contains(.category, round: round, category: index),
                    logLocation: "Editor › R\(round + 1) C\(index + 1) › Category"
                )
                .frame(width: 180, height: 80)
            }
        }
    }
}
