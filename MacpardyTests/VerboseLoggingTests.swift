//
//  VerboseLoggingTests.swift
//  MacpardyTests
//
//  The `.debug` lines that reconstruct a run from its log (#87): the
//  `old → new` helper, safe one-line descriptions, and the key glyphs.
//

import AppKit
import XCTest
@testable import Macpardy

@MainActor
final class VerboseLoggingTests: XCTestCase {

    func testChangeLogsOldAndNewWithAReason() throws {
        let log = LogCapture.capture {
            AppLogger.control.change("GameState.phase", from: GamePhase.board, to: .question, reason: "tile")
        }
        let entry = try XCTUnwrap(log.entries.first)
        XCTAssertEqual(entry.message, "state: GameState.phase: board → question (tile)")
        XCTAssertEqual(entry.level, .debug)
        XCTAssertEqual(entry.category, .control)
    }

    func testChangeSkipsAValueThatDidNotChange() {
        let log = LogCapture.capture {
            AppLogger.control.change("Score", from: 400, to: 400)
        }
        XCTAssertTrue(log.entries.isEmpty)
    }

    func testOptionalsAndStringsAreDescribed() {
        XCTAssertEqual(LogValue.describe(Optional<Int>.none as Any), "none")
        XCTAssertEqual(LogValue.describe(Optional(5) as Any), "5")
        XCTAssertEqual(LogValue.describe("Blue"), "'Blue'")
        XCTAssertEqual(LogValue.describe(Optional(GamePhase.dailyDouble) as Any), "dailyDouble")
    }

    func testPrefixHelpersTagTheirLines() {
        let log = LogCapture.capture {
            AppLogger.control.tap("Control › Timer › Pause")
            AppLogger.control.menu("Game › Reveal answer")
            AppLogger.control.shortcut("⌘R", "Game › Reveal answer")
            AppLogger.control.nav("sheet 'New game' presented")
            AppLogger.control.app("launch")
            AppLogger.buzzer.phone("buzz", team: "Blue", remote: "10.0.0.2")
        }
        XCTAssertEqual(log.messages, [
            "tap: Control › Timer › Pause",
            "menu: Game › Reveal answer",
            "shortcut: ⌘R Game › Reveal answer",
            "nav: sheet 'New game' presented",
            "app: launch",
            "phone: buzz",
        ])
        XCTAssertTrue(log.entries.allSatisfy { $0.level == .debug })
        XCTAssertEqual(log.entries.last?.teamName, "Blue")
        XCTAssertEqual(log.entries.last?.remote, "10.0.0.2")
    }

    func testQuestionDescriptionNeverHasTheClueOrResponse() {
        let question = Question(value: 400, clue: "This river is the longest", response: "What is the Nile?", isDailyDouble: true)
        let text = question.logDescription
        XCTAssertTrue(text.hasPrefix("$400 DD #"))
        XCTAssertFalse(text.contains("river"))
        XCTAssertFalse(text.contains("Nile"))
    }

    func testRoundAndTeamDescriptions() {
        XCTAssertEqual(MacpardyRound.macpardy.logDescription, "R1")
        XCTAssertEqual(MacpardyRound.finalMacpardy.logDescription, "Final")
        XCTAssertEqual(Team(name: "Blue", score: 400).logDescription, "'Blue' $400")
        XCTAssertEqual(BoardPosition(column: 2, row: 0).logDescription, "C3 row 1")
    }

    func testKeyGlyphFromAKeyPress() throws {
        let event = try XCTUnwrap(NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.command, .shift],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "B",
            charactersIgnoringModifiers: "b",
            isARepeat: false,
            keyCode: 11
        ))
        XCTAssertEqual(UIActionLog.glyph(for: event), "⇧⌘B")
    }

    func testActionWithoutAKeyPressLogsItsSource() {
        // Tests run without a current key event, so the source decides the prefix.
        let log = LogCapture.capture {
            UIActionLog.action("Control › Timer › Pause")
            UIActionLog.action("Game › Reveal answer", source: .menu)
        }
        XCTAssertEqual(log.messages, ["tap: Control › Timer › Pause", "menu: Game › Reveal answer"])
    }

    func testFilePickerResultsNameTheFileOnly() {
        let log = LogCapture.capture {
            UIActionLog.filePicked("file importer 'Import board'", .success(URL(fileURLWithPath: "/Users/someone/Trivia.macpardy")))
            UIActionLog.filesPicked("file importer 'Images'", .success([]))
        }
        XCTAssertEqual(log.messages, [
            "nav: file importer 'Import board' → picked Trivia.macpardy",
            "nav: file importer 'Images' → cancelled",
        ])
    }
}
