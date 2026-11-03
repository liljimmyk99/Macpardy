//
//  CreateMacpardyGameView+Extension.swift
//  Macpardy
//
//  Created by Jimmy Kane on 10/6/26.
//
import Foundation
import SwiftUI
import UniformTypeIdentifiers

extension CreateMacpardyGameView {
    func updateQuestion(categoryIndex: Int, questionIndex: Int, clue: String? = nil, response: String? = nil, isDailyDouble: Bool? = nil) {
        if currentRound == 0 {
            guard categoryIndex >= 0, categoryIndex < round1Categories.count else { return }
            guard questionIndex >= 0, questionIndex < round1Categories[categoryIndex].questions.count else { return }

            if let clue { round1Categories[categoryIndex].questions[questionIndex].clue = clue }
            if let response { round1Categories[categoryIndex].questions[questionIndex].response = response }
            if let isDailyDouble { round1Categories[categoryIndex].questions[questionIndex].isDailyDouble = isDailyDouble }
        } else if currentRound == 1 {
            guard categoryIndex >= 0, categoryIndex < round2Categories.count else { return }
            guard questionIndex >= 0, questionIndex < round2Categories[categoryIndex].questions.count else { return }

            if let clue { round2Categories[categoryIndex].questions[questionIndex].clue = clue }
            if let response { round2Categories[categoryIndex].questions[questionIndex].response = response }
            if let isDailyDouble { round2Categories[categoryIndex].questions[questionIndex].isDailyDouble = isDailyDouble }
        }
    }

    /// Sets or clears (`nil`) the image on a question in the current round.
    func updateImage(categoryIndex: Int, questionIndex: Int, image: QuestionImage?) {
        if currentRound == 0 {
            guard round1Categories.indices.contains(categoryIndex),
                  round1Categories[categoryIndex].questions.indices.contains(questionIndex) else { return }
            round1Categories[categoryIndex].questions[questionIndex].image = image
        } else if currentRound == 1 {
            guard round2Categories.indices.contains(categoryIndex),
                  round2Categories[categoryIndex].questions.indices.contains(questionIndex) else { return }
            round2Categories[categoryIndex].questions[questionIndex].image = image
        }
    }

    /// The editor's current contents.
    var currentDraft: BoardDraft {
        BoardDraft(
            title: title,
            round1Title: round1Title,
            round1Categories: round1Categories,
            round1Values: round1BoardValues,
            round2Title: round2Title,
            round2Categories: round2Categories,
            round2Values: round2BoardValues,
            finalTitle: finalTitle,
            finalMacpardy: finalMacpardy
        )
    }

    /// Whether an edited board has changed since it was loaded or last saved.
    /// New games ("Create game") are never counted.
    var hasUnsavedEdits: Bool {
        guard isEditingExistingBoard, let savedDraft else { return false }
        return currentDraft != savedDraft
    }

    // MARK: - Default text

    /// Fields that are empty or still hold their default text.
    var unfilledFields: [UnfilledField] {
        currentDraft.unfilledFields()
    }

    /// Where the unfilled fields are, for the warning before saving.
    var unfilledAlertMessage: String {
        let fields = unfilledFields
        let groups = fields.groupedByArea
        let shown = groups.prefix(Self.maxAlertAreas)
        var lines = shown.map { "• \($0.area): \($0.count)" }
        if groups.count > shown.count {
            lines.append(String(localized: "create.unfilled.alert.more \(groups.count - shown.count)"))
        }
        let summary = String(localized: "create.unfilled.count \(fields.count)")
        return ([summary] + lines).joined(separator: "\n")
    }

    private static var maxAlertAreas: Int { 12 }

    // MARK: - Round titles

    var currentRoundKind: MacpardyRound {
        switch currentRound {
        case 0: .macpardy
        case 1: .doubleMacpardy
        default: .finalMacpardy
        }
    }

    /// The title field for whichever round is showing.
    var currentRoundTitle: Binding<String> {
        switch currentRound {
        case 0: $round1Title
        case 1: $round2Title
        default: $finalTitle
        }
    }

    // MARK: - Saving

    func saveGame() {
        saveGame(thenFinish: nil)
    }

    /// Validates and opens the save panel. With a `request`, the close or
    /// quit it stands for goes ahead once the save succeeds, and is called
    /// off if the save doesn't happen.
    ///
    /// A game that still has default text is saved only once the user
    /// confirms the warning (`confirmedUnfilled`).
    func saveGame(thenFinish request: BoardEditorSession.CloseRequest?, confirmedUnfilled: Bool = false) {
        let draft = currentDraft

        if draft.trimmedTitle.isEmpty {
            AppLogger.control.state("Editor save blocked: the game has no title")
            validationMessage = String(localized: "create.validation.missing_title")
            showValidationAlert = true
            if request != nil {
                finishClose(proceed: false)
            }
            return
        }

        if !confirmedUnfilled, !draft.unfilledFields().isEmpty {
            AppLogger.control.state("Editor save paused: \(draft.unfilledFields().count) field(s) still have default text")
            unfilledAlertRequest = request
            showUnfilledAlert = true
            return
        }

        closeAfterSave = request
        draftBeingSaved = draft
        // An edited board is saved as plain JSON unless it has pictures,
        // which need a package. New games are always saved as packages.
        exportContentType = isEditingExistingBoard && !draft.hasImages ? .json : .macpardyBoard
        exportDocument = FileManagerService().makeExportDocument(for: draft.makeBoards(), title: draft.trimmedTitle)
        AppLogger.control.state("Editor export ready: '\(draft.trimmedTitle)' as \(exportContentType == .json ? "JSON" : ".macpardy package")\(draft.hasImages ? " with images" : "")")
        showFileExporter = true
    }

    // MARK: - Closing with unsaved edits

    var unsavedPromptTitle: String {
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty
            ? String(localized: "edit.alert.unsaved.title_untitled")
            : String(localized: "edit.alert.unsaved.title \(name)")
    }

    /// Answers the pending close or quit. Going ahead throws away unsaved
    /// edits (they've either just been saved or the user chose not to).
    func finishClose(proceed: Bool) {
        let request = editorSession.closeRequest
        if proceed {
            savedDraft = currentDraft
            editorSession.hasUnsavedEdits = false
        }
        editorSession.finishClose(proceed: proceed)
        if proceed, request == .closeWindow {
            dismissWindow(id: "create-macpardy")
        }
    }

    /// Calls off a close or quit that was waiting on a save that didn't happen.
    func cancelPendingClose() {
        guard closeAfterSave != nil else { return }
        closeAfterSave = nil
        finishClose(proceed: false)
    }

    // MARK: - Loading

    /// Fills the editor with a board queued by "Edit game", if there is one.
    func loadPendingDraft() {
        guard let draft = editorSession.takePendingDraft() else { return }
        AppLogger.control.state("Editor loaded board '\(draft.trimmedTitle)'")
        showDraft(draft)
        currentRound = 0
        selectedQuestion = nil
        exportDocument = nil
        savedDraft = draft
        suggestedFilename = editorSession.takePendingSuggestedFilename()
        isEditingExistingBoard = true
        resetUndo(to: draft)
    }

    /// Puts `draft`'s contents in the editor's fields.
    func showDraft(_ draft: BoardDraft) {
        title = draft.title
        round1Title = draft.round1Title
        round1Categories = draft.round1Categories
        round1BoardValues = draft.round1Values
        round2Title = draft.round2Title
        round2Categories = draft.round2Categories
        round2BoardValues = draft.round2Values
        finalTitle = draft.finalTitle
        finalMacpardy = draft.finalMacpardy
    }

    // MARK: - Undo

    /// Starts undo history afresh from what the editor holds now (the window
    /// opened, or a different board was loaded).
    func resetUndo(to draft: BoardDraft) {
        undoController.apply = { showDraft($0) }
        undoController.reset(to: draft, undoManager: undoManager)
    }

    func recordUndoStep(for draft: BoardDraft) {
        undoController.apply = { showDraft($0) }
        undoController.draftChanged(draft, undoManager: undoManager)
    }
}
