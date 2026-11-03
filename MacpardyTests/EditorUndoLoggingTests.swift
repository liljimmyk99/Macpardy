//
//  EditorUndoLoggingTests.swift
//  MacpardyTests
//
//  The board editor logs where each edit was and its undo / redo, never the
//  text typed (#87).
//

import XCTest
@testable import Macpardy

@MainActor
final class EditorUndoLoggingTests: XCTestCase {

    func testEditsUndoAndRedoLogTheFieldNotTheText() {
        var draft = BoardDefaults.makeDraft()
        let manager = UndoManager()
        manager.groupsByEvent = false
        let controller = EditorUndoController(draft: draft)
        controller.apply = { draft = $0 }
        controller.reset(to: draft, undoManager: manager)

        let log = LogCapture.capture {
            draft.round1Categories[1].questions[2].clue = "A secret clue nobody may log"
            manager.beginUndoGrouping()
            controller.draftChanged(draft, undoManager: manager)
            manager.endUndoGrouping()

            draft.round1Categories[0].questions[0].isDailyDouble.toggle()
            manager.beginUndoGrouping()
            controller.draftChanged(draft, undoManager: manager)
            manager.endUndoGrouping()

            manager.undo()
            manager.redo()
        }

        XCTAssertEqual(log.messages, [
            "state: Editor edit: editClue r1.c1.q2.clue",
            "state: Editor edit: toggleDailyDouble r1.c0.q0.dd",
            "state: Editor undo: toggleDailyDouble r1.c0.q0.dd",
            "state: Editor redo: toggleDailyDouble r1.c0.q0.dd",
        ])
        XCTAssertFalse(log.messages.contains { $0.contains("secret") })
    }
}
