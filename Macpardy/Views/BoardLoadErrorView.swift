//
//  BoardLoadErrorView.swift
//  Macpardy
//

import SwiftUI

/// Explains why a board couldn't be opened for editing.
struct BoardLoadErrorView: View {

    @Environment(\.dismiss) private var dismiss

    let report: BoardLoadReport

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label {
                Text("board_load.error_title \(report.fileName)")
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            }
            .font(.title2.bold())

            Text("board_load.error_detail")
                .foregroundStyle(.secondary)

            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(report.problems) { problem in
                        VStack(alignment: .leading, spacing: 2) {
                            if let location = problem.location {
                                Text(location)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            Text(problem.message)
                                .textSelection(.enabled)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(Color.red.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
            .frame(minHeight: 80, maxHeight: 320)

            HStack {
                Spacer()
                LoggedButton("common.ok", log: "Board load error › OK") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 520)
    }
}

#Preview {
    BoardLoadErrorView(
        report: BoardLoadReport(
            fileName: "trivia-night.json",
            error: BoardLoader.LoadError.json(
                BoardLoader.JSONProblem(kind: .missingField, path: "boards[0].categories[2].title", inPackage: false)
            )
        )
    )
}
