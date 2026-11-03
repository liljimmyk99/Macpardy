//
//  FileCommands.swift
//  Macpardy
//
//  The File menu: New Board, Import Board… and Open Recent.
//

import SwiftUI

struct FileCommands: Commands {

    let coordinator: BoardOpenCoordinator

    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            LoggedButton("menu.file.new_board", log: "File › New board", source: .menu) {
                openWindow(id: "create-macpardy")
            }
            .keyboardShortcut(.newBoard)

            LoggedButton("menu.file.import_board", log: "File › Import board", source: .menu) {
                openWindow(id: "control")
                coordinator.requestImport()
            }
            .keyboardShortcut(.importBoard)

            Menu("menu.file.open_recent") {
                let urls = coordinator.recents.urls
                if urls.isEmpty {
                    LoggedButton("menu.file.no_recent_boards", log: "File › Open Recent › No recent boards", source: .menu) {}
                        .disabled(true)
                } else {
                    ForEach(urls, id: \.self) { url in
                        LoggedButton(verbatim: url.lastPathComponent, log: "File › Open Recent › \(url.lastPathComponent)", source: .menu) {
                            openWindow(id: "control")
                            coordinator.open(url: url)
                        }
                    }
                    Divider()
                    LoggedButton("menu.file.clear_menu", log: "File › Open Recent › Clear menu", source: .menu) {
                        coordinator.recents.clear()
                    }
                }
            }
        }
    }
}
