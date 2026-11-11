//
//  HelpCommands.swift
//  Macpardy
//
//  The Help menu. Replaces the empty "Macpardy Help" item with the
//  Keyboard Shortcuts and Logs windows.
//

import SwiftUI

struct HelpCommands: Commands {

    let walkthrough: WalkthroughCoordinator

    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .help) {
            LoggedButton("menu.help.show_walkthrough", log: "Help › Show walkthrough", source: .menu) {
                openWindow(id: "control")
                walkthrough.request()
            }
            .disabled(!walkthrough.isAvailable())

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
