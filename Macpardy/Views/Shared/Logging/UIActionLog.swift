//
//  UIActionLog.swift
//  Macpardy
//
//  Logs a user action with how it was triggered (#87): `tap:` for a click,
//  `menu:` for a menu bar item, `shortcut:` when a key press set it off. One
//  action reachable from a button, a menu item and a shortcut is logged once,
//  with its source.
//

import AppKit
import SwiftUI

/// What kind of control an action came from when it wasn't a key press.
enum UIActionSource {
    /// A button, tile or other on-screen control.
    case tap
    /// A menu bar item.
    case menu
}

enum UIActionLog {

    /// Logs `description`, e.g. "Control › Score › Team 2 +400".
    static func action(_ description: String, source: UIActionSource = .tap, category: LogCategory = .control) {
        let logger = AppLogger.logger(for: category)
        if let keys = currentKeyGlyph() {
            logger.shortcut(keys, description)
        } else if source == .menu {
            logger.menu(description)
        } else {
            logger.tap(description)
        }
    }

    /// The key press being handled, as menus draw it ("⌘R"), or nil when the
    /// current event isn't a key press.
    static func currentKeyGlyph() -> String? {
        guard let event = NSApp?.currentEvent, event.type == .keyDown else { return nil }
        return glyph(for: event)
    }

    static func glyph(for event: NSEvent) -> String? {
        guard let character = event.charactersIgnoringModifiers?.first else { return nil }
        var modifiers: EventModifiers = []
        let flags = event.modifierFlags
        if flags.contains(.command) { modifiers.insert(.command) }
        if flags.contains(.option) { modifiers.insert(.option) }
        if flags.contains(.control) { modifiers.insert(.control) }
        if flags.contains(.shift) { modifiers.insert(.shift) }
        return ShortcutFormatter.glyph(key: KeyEquivalent(character), modifiers: modifiers)
    }

    /// `nav: file importer 'Import board' → picked Trivia.macpardy` (or cancelled / failed).
    static func filePicked(_ name: String, _ result: Result<URL, Error>, category: LogCategory = .control) {
        let logger = AppLogger.logger(for: category)
        switch result {
        case .success(let url): logger.nav("\(name) → picked \(url.lastPathComponent)")
        case .failure(let error): logger.nav("\(name) → failed (\(error.localizedDescription))")
        }
    }

    /// For pickers that report several files or none.
    static func filesPicked(_ name: String, _ result: Result<[URL], Error>, category: LogCategory = .control) {
        let logger = AppLogger.logger(for: category)
        switch result {
        case .success(let urls) where urls.isEmpty: logger.nav("\(name) → cancelled")
        case .success(let urls): logger.nav("\(name) → picked \(urls.map(\.lastPathComponent).joined(separator: ", "))")
        case .failure(let error): logger.nav("\(name) → failed (\(error.localizedDescription))")
        }
    }

    /// For file exporters: `nav: file exporter 'Save board' → saved Trivia.macpardy`.
    static func fileSaved(_ name: String, _ result: Result<URL, Error>, category: LogCategory = .control) {
        let logger = AppLogger.logger(for: category)
        switch result {
        case .success(let url): logger.nav("\(name) → saved \(url.lastPathComponent)")
        case .failure(let error): logger.nav("\(name) → failed (\(error.localizedDescription))")
        }
    }
}
