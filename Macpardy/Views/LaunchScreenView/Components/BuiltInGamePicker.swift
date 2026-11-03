//
//  BuiltInGamePicker.swift
//  Macpardy
//
//  Lists the games that ship with the app, with "Load my own file…" below.
//

import SwiftUI

struct BuiltInGamePicker: View {

    let title: LocalizedStringKey
    let games: [BundledGame]
    let onSelect: (BundledGame) -> Void
    let onLoadOwnFile: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title2.bold())

            VStack(spacing: 8) {
                ForEach(games) { game in
                    LoggedButton(log: "Built-in games › '\(game.title)'") {
                        onSelect(game)
                    } label: {
                        Text(verbatim: game.title)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 6)
                    }
                    .controlSize(.large)
                }

                LoggedButton(log: "Built-in games › Load own file", action: onLoadOwnFile) {
                    Label("launch.picker.load_own_file", systemImage: "folder")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                }
                .controlSize(.large)
            }

            HStack {
                Spacer()
                LoggedButton("common.cancel", log: "Built-in games › Cancel", role: .cancel, action: onCancel)
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(24)
        .frame(width: 420)
    }
}

#Preview {
    BuiltInGamePicker(
        title: "launch.picker.play_title",
        games: [BundledGame(id: "a.json", title: "Classic Game 1")],
        onSelect: { _ in },
        onLoadOwnFile: {},
        onCancel: {}
    )
}
