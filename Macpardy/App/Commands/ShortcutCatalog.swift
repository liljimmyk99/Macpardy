//
//  ShortcutCatalog.swift
//  Macpardy
//
//  Every keyboard shortcut in the app, defined once. Menu items and buttons
//  read their key from here so two actions can't claim the same one.
//

import SwiftUI

/// Where in the app a shortcut applies.
nonisolated enum ShortcutArea: String, CaseIterable {
    case start, file, edit, game, timer, editor, view, window, app, help

    /// Order of the groups in the Keyboard Shortcuts window.
    static let displayOrder: [ShortcutArea] = [.start, .file, .edit, .game, .timer, .editor, .view, .window, .app, .help]

    /// Localization key of the group's heading.
    var titleKey: String { "shortcuts.area.\(rawValue)" }
}

nonisolated enum AppShortcut: String, CaseIterable, Identifiable {

    // File
    case newBoard, importBoard
    // Editor
    case saveGame
    // Game
    case returnToBoard, nextRound, finalMacpardy, revealAnswer, showDisplay, buzzers
    // Timer
    case toggleTimer, resetTimer, timerMinus5, timerPlus5
    // Provided by macOS, listed so the Keyboard Shortcuts window is complete.
    // Never bound with `.keyboardShortcut`; they only appear in the catalog.
    case settings, undo, redo, fullScreen, closeWindow, minimize
    // Help
    case keyboardShortcuts, showLogs

    var id: String { rawValue }

    /// Localization key of the action's title.
    var titleKey: String {
        switch self {
        case .newBoard: "menu.file.new_board"
        case .importBoard: "menu.file.import_board"
        case .saveGame: "create.button.save_game"
        case .returnToBoard: "control.question.button.return_to_board"
        case .nextRound: "control.board.button.next_round"
        case .finalMacpardy: "round.final_macpardy"
        case .revealAnswer: "control.question.button.reveal_answer"
        case .showDisplay: "control.toolbar.show_display"
        case .buzzers: "menu.game.buzzers"
        case .toggleTimer: "menu.game.timer.toggle"
        case .resetTimer: "menu.game.timer.reset"
        case .timerMinus5: "menu.game.timer.minus_5"
        case .timerPlus5: "menu.game.timer.plus_5"
        case .settings: "menu.app.settings"
        case .undo: "menu.edit.undo"
        case .redo: "menu.edit.redo"
        case .fullScreen: "menu.view.full_screen"
        case .closeWindow: "menu.window.close"
        case .minimize: "menu.window.minimize"
        case .keyboardShortcuts: "menu.help.keyboard_shortcuts"
        case .showLogs: "menu.help.show_logs"
        }
    }

    var key: KeyEquivalent {
        switch self {
        case .newBoard: "n"
        case .importBoard: "o"
        case .saveGame: "s"
        case .returnToBoard, .buzzers: "b"
        case .nextRound: .rightArrow
        case .finalMacpardy: "f"
        case .revealAnswer: "r"
        case .showDisplay: "d"
        case .toggleTimer: "t"
        case .resetTimer: .leftArrow
        case .timerMinus5: "-"
        case .timerPlus5: "+"
        case .settings: ","
        case .undo, .redo: "z"
        case .fullScreen: "f"
        case .closeWindow: "w"
        case .minimize: "m"
        case .keyboardShortcuts: "/"
        case .showLogs: "l"
        }
    }

    var modifiers: EventModifiers {
        switch self {
        case .buzzers, .redo: [.command, .shift]
        case .fullScreen: [.command, .control]
        case .showLogs: [.command, .option]
        default: .command
        }
    }

    var area: ShortcutArea {
        switch self {
        case .newBoard, .importBoard: .file
        case .saveGame: .editor
        case .returnToBoard, .nextRound, .finalMacpardy, .revealAnswer, .showDisplay, .buzzers: .game
        case .toggleTimer, .resetTimer, .timerMinus5, .timerPlus5: .timer
        case .settings: .app
        case .undo, .redo: .edit
        case .fullScreen: .view
        case .closeWindow, .minimize: .window
        case .keyboardShortcuts, .showLogs: .help
        }
    }

    /// Whether macOS provides the shortcut (the app doesn't bind it itself).
    var isSystemProvided: Bool {
        switch self {
        case .settings, .undo, .redo, .fullScreen, .closeWindow, .minimize: true
        default: false
        }
    }

    /// The shortcut as menus draw it, e.g. "⇧⌘B".
    var glyph: String {
        ShortcutFormatter.glyph(key: key, modifiers: modifiers)
    }
}

/// The catalog as the Keyboard Shortcuts window shows it: grouped by area, in
/// display order, with empty groups left out.
nonisolated enum ShortcutGroups {

    struct Group: Identifiable {
        let area: ShortcutArea
        let shortcuts: [AppShortcut]
        var id: ShortcutArea { area }
    }

    static func all() -> [Group] {
        ShortcutArea.displayOrder.compactMap { area in
            let shortcuts = AppShortcut.allCases.filter { $0.area == area }
            return shortcuts.isEmpty ? nil : Group(area: area, shortcuts: shortcuts)
        }
    }
}

extension View {
    /// Binds a button or menu item to a shortcut from the catalog.
    func keyboardShortcut(_ shortcut: AppShortcut) -> some View {
        keyboardShortcut(shortcut.key, modifiers: shortcut.modifiers)
    }
}
