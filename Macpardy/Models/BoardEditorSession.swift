//
//  BoardEditorSession.swift
//  Macpardy
//

import AppKit
import Foundation
import Observation

/// Passes work between the launch screen, the editor window, and the app:
/// a loaded board to edit, an edited board the user wants to play, and
/// "save before closing?" requests.
@Observable
final class BoardEditorSession {

    /// What the user was doing when they had unsaved edits.
    enum CloseRequest: Equatable {
        /// Closing the editor window.
        case closeWindow
        /// Quitting the app.
        case quitApp
    }

    /// The app's session. The app delegate needs it to check for unsaved
    /// edits on quit, so it isn't created per view.
    static let shared = BoardEditorSession()

    /// A loaded board waiting for the editor to pick it up.
    private(set) var pendingDraft: BoardDraft?

    /// The file name to suggest when the pending draft is saved (set for
    /// copies of built-in games).
    private(set) var pendingSuggestedFilename: String?

    /// Goes up on every `edit(_:)` so an editor that's already open reloads.
    private(set) var editRequest = 0

    /// Boards the user chose to play after saving an edit. The app starts
    /// the game and clears this.
    var boardsToPlay: [MacpardyBoard]? {
        didSet {
            if let boardsToPlay { log.state("BoardEditorSession: play edited board (\(boardsToPlay.count) rounds)") }
        }
    }

    /// Whether an edited board has changes that haven't been saved. Kept up
    /// to date by the editor; only edits of existing boards count.
    var hasUnsavedEdits = false {
        didSet { log.change("BoardEditorSession.hasUnsavedEdits", from: oldValue, to: hasUnsavedEdits) }
    }

    /// A close or quit waiting on the user's "save changes?" answer.
    private(set) var closeRequest: CloseRequest? {
        didSet { log.change("BoardEditorSession.closeRequest", from: oldValue, to: closeRequest) }
    }

    private let log = AppLogger.control

    /// The editor's window, so a quit can bring it forward for the prompt.
    @ObservationIgnored
    weak var editorWindow: NSWindow?

    /// Tells AppKit whether to go ahead with a quit that's waiting on the prompt.
    @ObservationIgnored
    var onQuitDecision: ((Bool) -> Void)?

    /// Queues `draft` for the editor.
    func edit(_ draft: BoardDraft, suggestedFilename: String? = nil) {
        log.state("BoardEditorSession: board '\(draft.trimmedTitle)' queued for the editor\(suggestedFilename.map { " (save as \($0))" } ?? "")")
        pendingDraft = draft
        pendingSuggestedFilename = suggestedFilename
        editRequest += 1
    }

    /// Hands the queued draft to the editor, once.
    func takePendingDraft() -> BoardDraft? {
        defer { pendingDraft = nil }
        return pendingDraft
    }

    /// Hands the suggested file name for the draft just taken, once.
    func takePendingSuggestedFilename() -> String? {
        defer { pendingSuggestedFilename = nil }
        return pendingSuggestedFilename
    }

    /// Asks the editor to prompt about unsaved edits. Returns `false` if a
    /// prompt is already showing.
    @discardableResult
    func requestClose(_ request: CloseRequest) -> Bool {
        guard closeRequest == nil else { return false }
        closeRequest = request
        return true
    }

    /// Ends the pending request. `proceed` is whether the close or quit
    /// should go ahead; a quit is answered here, a window close by the editor.
    func finishClose(proceed: Bool) {
        let request = closeRequest
        log.state("BoardEditorSession: \(request.map { "\($0)" } ?? "close") \(proceed ? "goes ahead" : "cancelled")")
        closeRequest = nil
        if request == .quitApp {
            onQuitDecision?(proceed)
            onQuitDecision = nil
        }
    }
}
