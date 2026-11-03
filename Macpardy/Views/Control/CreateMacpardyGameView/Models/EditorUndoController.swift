//
//  EditorUndoController.swift
//  Macpardy
//
//  Puts the board editor's undo steps on the window's undo manager, so the
//  standard Edit > Undo / Redo items work and show what they will undo.
//

import Foundation

@Observable
final class EditorUndoController {

    /// Whether text edits are registered as steps. Typing in a focused field
    /// also has the field editor's own undo; turn this off if the two ever
    /// stack up and ⌘Z undoes twice.
    static let registersTypingSteps = true

    @ObservationIgnored private var history: EditorUndoHistory
    @ObservationIgnored private var undoManager: UndoManager?

    /// Puts a draft back in the editor.
    @ObservationIgnored var apply: (BoardDraft) -> Void = { _ in }

    init(draft: BoardDraft) {
        history = EditorUndoHistory(draft: draft)
    }

    /// Starts over from `draft` with an empty stack (a different board was loaded).
    func reset(to draft: BoardDraft, undoManager: UndoManager?) {
        clearStack()
        self.undoManager = undoManager
        history = EditorUndoHistory(draft: draft)
    }

    /// Drops every step, e.g. when the editor closes.
    func clearStack() {
        undoManager?.removeAllActions(withTarget: self)
    }

    /// Ends the current step so the next edit starts a new one.
    func closeStep() {
        history.closeStep()
    }

    /// Call whenever the editor's contents change.
    func draftChanged(_ draft: BoardDraft, undoManager: UndoManager?, now: Date = Date()) {
        self.undoManager = undoManager
        guard case .newStep(let change, let before) = history.record(draft, at: now) else { return }
        // Where the edit was, never what was typed; later keystrokes merge into this step.
        AppLogger.control.state("Editor edit: \(change.logDescription)")
        guard Self.registersTypingSteps || !change.kind.isTyping else { return }
        register(restoring: before, redoingTo: draft, change: change)
    }

    private func register(restoring before: BoardDraft, redoingTo after: BoardDraft, change: EditorChange) {
        guard let undoManager else { return }
        undoManager.registerUndo(withTarget: self) { controller in
            let how = controller.undoManager?.isRedoing == true ? "redo" : "undo"
            AppLogger.control.state("Editor \(how): \(change.logDescription)")
            controller.apply(before)
            controller.history.applied(before)
            // Registered while undoing, so it becomes the redo.
            controller.register(restoring: after, redoingTo: before, change: change)
        }
        undoManager.setActionName(String(localized: String.LocalizationValue(change.kind.titleKey)))
    }
}
