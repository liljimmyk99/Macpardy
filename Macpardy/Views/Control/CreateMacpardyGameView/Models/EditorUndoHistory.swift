//
//  EditorUndoHistory.swift
//  Macpardy
//
//  Decides how the board editor's changes group into undo steps. The undo
//  manager keeps the steps themselves; this works out what each change was
//  called and whether it continues the step before it.
//

import Foundation

/// What a single edit changed, and where. Two edits with the same `kind` and
/// `target` close together are one undo step.
struct EditorChange: Equatable {

    enum Kind: String {
        case editTitle, renameRound, editCategory, editClue, editAnswer
        case changeValue, toggleDailyDouble, addImage, removeImage
        /// A change that isn't one of the above (e.g. several fields at once).
        case edit

        /// Localization key of the name shown in the Edit menu.
        var titleKey: String {
            switch self {
            case .editTitle: "undo.edit_title"
            case .renameRound: "undo.rename_round"
            case .editCategory: "undo.edit_category"
            case .editClue: "undo.edit_clue"
            case .editAnswer: "undo.edit_answer"
            case .changeValue: "undo.change_value"
            case .toggleDailyDouble: "undo.toggle_daily_double"
            case .addImage: "undo.add_image"
            case .removeImage: "undo.remove_image"
            case .edit: "undo.edit"
            }
        }

        /// Typed into a text field, which also keeps its own typing undo.
        var isTyping: Bool {
            switch self {
            case .editTitle, .renameRound, .editCategory, .editClue, .editAnswer: true
            default: false
            }
        }
    }

    let kind: Kind
    /// Which field changed, e.g. `r1.c2.q3.clue`.
    let target: String

    /// "editClue r1.c2.q3.clue": the kind and field, never the text.
    var logDescription: String {
        target.isEmpty ? kind.rawValue : "\(kind.rawValue) \(target)"
    }

    /// Names the first difference between two drafts.
    static func between(_ old: BoardDraft, _ new: BoardDraft) -> EditorChange {
        if old.title != new.title { return EditorChange(kind: .editTitle, target: "title") }

        if old.round1Title != new.round1Title { return EditorChange(kind: .renameRound, target: "r1.title") }
        if old.round2Title != new.round2Title { return EditorChange(kind: .renameRound, target: "r2.title") }
        if old.finalTitle != new.finalTitle { return EditorChange(kind: .renameRound, target: "final.title") }

        if old.round1Values != new.round1Values { return EditorChange(kind: .changeValue, target: "r1.values") }
        if old.round2Values != new.round2Values { return EditorChange(kind: .changeValue, target: "r2.values") }

        if let change = categoryChange(old.round1Categories, new.round1Categories, round: "r1") { return change }
        if let change = categoryChange(old.round2Categories, new.round2Categories, round: "r2") { return change }

        if old.finalMacpardy.category != new.finalMacpardy.category {
            return EditorChange(kind: .editCategory, target: "final.category")
        }
        if old.finalMacpardy.clue != new.finalMacpardy.clue {
            return EditorChange(kind: .editClue, target: "final.clue")
        }
        if old.finalMacpardy.response != new.finalMacpardy.response {
            return EditorChange(kind: .editAnswer, target: "final.response")
        }
        return EditorChange(kind: .edit, target: "")
    }

    private static func categoryChange(_ old: [DraftCategory], _ new: [DraftCategory], round: String) -> EditorChange? {
        guard old.count == new.count else { return EditorChange(kind: .edit, target: round) }
        for (c, (before, after)) in zip(old, new).enumerated() {
            if before.title != after.title {
                return EditorChange(kind: .editCategory, target: "\(round).c\(c).title")
            }
            guard before.questions.count == after.questions.count else {
                return EditorChange(kind: .edit, target: "\(round).c\(c)")
            }
            for (q, (was, now)) in zip(before.questions, after.questions).enumerated() {
                let target = "\(round).c\(c).q\(q)"
                if was.clue != now.clue { return EditorChange(kind: .editClue, target: target + ".clue") }
                if was.response != now.response { return EditorChange(kind: .editAnswer, target: target + ".response") }
                if was.isDailyDouble != now.isDailyDouble {
                    return EditorChange(kind: .toggleDailyDouble, target: target + ".dd")
                }
                if was.image != now.image {
                    return EditorChange(kind: now.image == nil ? .removeImage : .addImage, target: target + ".image")
                }
            }
        }
        return nil
    }
}

/// Tracks the editor's draft and groups edits into undo steps.
struct EditorUndoHistory {

    /// Edits to the same field within this long of each other are one step.
    static let mergeWindow: TimeInterval = 1.0

    enum Decision: Equatable {
        /// Nothing changed, or the change was an undo or redo being applied.
        case ignore
        /// Continues the step before it; the undo manager already has it.
        case merge
        /// Starts a step that undoes back to `before`.
        case newStep(EditorChange, before: BoardDraft)
    }

    /// The draft as of the last recorded change.
    private(set) var current: BoardDraft

    private var lastChange: EditorChange?
    private var lastChangeTime: Date?

    init(draft: BoardDraft) {
        current = draft
    }

    /// Records that the editor now holds `draft`.
    mutating func record(_ draft: BoardDraft, at now: Date = Date()) -> Decision {
        guard draft != current else { return .ignore }
        let before = current
        let change = EditorChange.between(before, draft)
        current = draft

        if let lastChange, let lastChangeTime,
           lastChange == change,
           now.timeIntervalSince(lastChangeTime) <= Self.mergeWindow {
            self.lastChangeTime = now
            return .merge
        }
        lastChange = change
        lastChangeTime = now
        return .newStep(change, before: before)
    }

    /// Notes that an undo or redo put `draft` in the editor. The next edit
    /// starts a new step.
    mutating func applied(_ draft: BoardDraft) {
        current = draft
        lastChange = nil
        lastChangeTime = nil
    }

    /// Ends the current step, e.g. when the user moves to another field.
    mutating func closeStep() {
        lastChange = nil
        lastChangeTime = nil
    }
}
