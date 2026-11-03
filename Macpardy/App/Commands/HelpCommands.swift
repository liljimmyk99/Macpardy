//
//  HelpCommands.swift
//  Macpardy
//
//  The Help menu. Replaces the empty "Macpardy Help" item with the
//  Keyboard Shortcuts and Logs windows.
//

import SwiftUI

struct HelpCommands: Commands {

    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .help) {
            LoggedButton("menu.help.keyboard_shortcuts", log: "Help › Keyboard shortcuts", source: .menu) {
                openWindow(id: "shortcuts")
            }
            .keyboardShortcut(.keyboardShortcuts)

            LoggedButton("menu.help.show_logs", log: "Help › Show logs", source: .menu) {
                openWindow(id: "logs")
            }
            .keyboardShortcut(.showLogs)
        }
    }
}
