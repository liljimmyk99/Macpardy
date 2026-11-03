//
//  DraftFinalMacpardyView.swift
//  Macpardy
//
//  Created by Jimmy Kane on 10/8/26.
//

import SwiftUI

struct DraftFinalMacpardyView: View {
    @FocusState private var focusedField: Field?
    @Binding var draft: DraftFinalMacpardy
    var unfilled: [UnfilledField] = []
    
    private enum Field: Hashable {
        case category
        case question
        case answer
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("create.final_macpardy.category_label")
                    .font(.headline)
                    .foregroundStyle(.primary)

                TextField("create.final_macpardy.category_placeholder", text: $draft.category)
                    .focused($focusedField, equals: .category)
                    .logCommit("Editor › Final › Category", text: draft.category, isFocused: focusedField == .category)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 480)
                    .unfilledIndicator(unfilled.contains(.finalCategory, round: 2), cornerRadius: 5)
                    .accessibilityLabel(Text("create.final_macpardy.category_accessibility"))
                    .onSubmit {
                        focusedField = .question
                    }
                    .onKeyPress(phases: .down) { press in
                        if press.key == .tab {
                            if press.modifiers.contains(.shift) {
                                focusedField = .answer
                            } else {
                                focusedField = .question
                            }
                            return .handled
                        }
                        return .ignored
                    }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("create.question.clue_label")
                    .font(.headline)
                    .foregroundStyle(.primary)

                MultilineTextEditor(
                    text: $draft.clue,
                    placeholder: String(localized: "create.final_macpardy.clue_placeholder"),
                    minHeight: 140
                )
                .unfilledIndicator(unfilled.contains(.finalClue, round: 2), cornerRadius: 8)
                .focused($focusedField, equals: .question)
                .logCommit("Editor › Final › Clue", text: draft.clue, isFocused: focusedField == .question)
                .accessibilityLabel(Text("create.final_macpardy.clue_accessibility"))
                .onSubmit {
                    focusedField = .answer
                }
                .onKeyPress(phases: .down) { press in
                    if press.key == .tab {
                        if press.modifiers.contains(.shift) {
                            focusedField = .category
                        } else {
                            focusedField = .answer
                        }
                        return .handled
                    }
                    return .ignored
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("create.question.response_label")
                    .font(.headline)
                    .foregroundStyle(.primary)

                MultilineTextEditor(
                    text: $draft.response,
                    placeholder: String(localized: "create.final_macpardy.response_placeholder"),
                    minHeight: 140
                )
                .unfilledIndicator(unfilled.contains(.finalAnswer, round: 2), cornerRadius: 8)
                .focused($focusedField, equals: .answer)
                .logCommit("Editor › Final › Answer", text: draft.response, isFocused: focusedField == .answer)
                .accessibilityLabel(Text("create.final_macpardy.response_accessibility"))
                .onSubmit {
                    focusedField = .category
                }
                .onKeyPress(phases: .down) { press in
                    if press.key == .tab {
                        if press.modifiers.contains(.shift) {
                            focusedField = .question
                        } else {
                            focusedField = .category
                        }
                        return .handled
                    }
                    return .ignored
                }
            }

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(MacpardyTheme.boardBlue.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(MacpardyTheme.gold.opacity(0.4), lineWidth: 1.5)
        )
        .onAppear {
            focusedField = .category
        }
    }
}
