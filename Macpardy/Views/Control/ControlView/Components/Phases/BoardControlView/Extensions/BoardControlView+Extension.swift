//
//  BoardControlView+Extension.swift
//  Macpardy
//
//  Arrow-key navigation on the host's board (#88).
//

import SwiftUI

extension BoardControlView {

    func handleArrow(_ press: KeyPress) -> KeyPress.Result {
        // ⌘→ and ⌘← belong to the Game menu (Next Round, Reset Timer).
        guard isPlainKey(press) else { return .ignored }
        switch press.key {
        case .upArrow: gameState.moveHighlight(.up)
        case .downArrow: gameState.moveHighlight(.down)
        case .leftArrow: gameState.moveHighlight(.left)
        case .rightArrow: gameState.moveHighlight(.right)
        default: return .ignored
        }
        return .handled
    }

    /// No ⌘, ⌥, ⌃ or ⇧ held. Arrow keys also report the function and keypad
    /// flags, which don't count.
    func isPlainKey(_ press: KeyPress) -> Bool {
        press.modifiers.isDisjoint(with: [.command, .option, .control, .shift])
    }
}
