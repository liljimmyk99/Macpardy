//
//  EditableCategoryHeaderView.swift
//  Macpardy
//
//  Created by Jimmy Kane on 10/8/26.
//

import SwiftUI

struct EditableCategoryHeaderView: View {
    @Binding var title: String
    var placeholder: String = String(localized: "create.category_placeholder")
    var font: Font = MacpardyTheme.categoryFont
    var isUnfilled = false
    /// Where the field is, for the log, e.g. "Editor › R1 C2 › Category".
    var logLocation = "Editor › Category"

    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            MacpardyTheme.tileBlue

            TextField(
                "",
                text: $title,
                prompt: Text(placeholder.uppercased())
                    .font(font)
                    .foregroundColor(.white.opacity(0.45))
            )
            .font(font)
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .textFieldStyle(.plain)
            .padding(.horizontal, 8)
            .focused($isFocused)
            .logCommit(logLocation, text: title, isFocused: isFocused)
            .accessibilityLabel(Text("create.category_accessibility \(title.isEmpty ? placeholder : title)"))
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isFocused ? MacpardyTheme.gold : Color.clear, lineWidth: 2)
        )
        .unfilledIndicator(isUnfilled)
    }
}

#Preview {
    EditableCategoryHeaderView(
        title: .constant("Science"),
        placeholder: "Category 1"
    )
    .frame(width: 180, height: 80)
}
