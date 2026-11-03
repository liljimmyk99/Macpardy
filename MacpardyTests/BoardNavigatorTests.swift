//
//  BoardNavigatorTests.swift
//  MacpardyTests
//

import XCTest
@testable import Macpardy

@MainActor
final class BoardNavigatorTests: XCTestCase {

    /// A board of `columns` × `rows` clues with the given tiles already played.
    private func board(columns: Int = 3, rows: Int = 4, played: Set<BoardPosition> = []) -> MacpardyBoard {
        let categories = (0..<columns).map { column in
            Category(
                title: "C\(column)",
                questions: (0..<rows).map { row in
                    Question(
                        value: (row + 1) * 200,
                        clue: "clue",
                        response: "response",
                        hasBeenPlayed: played.contains(BoardPosition(column: column, row: row))
                    )
                }
            )
        }
        return MacpardyBoard(title: "Test", round: .macpardy, categories: categories)
    }

    private func at(_ column: Int, _ row: Int) -> BoardPosition {
        BoardPosition(column: column, row: row)
    }

    func testFirstPressPicksTheTopLeftOpenTile() {
        XCTAssertEqual(BoardNavigator.move(from: nil, .down, on: board()), at(0, 0))
        let played = board(played: [at(0, 0)])
        XCTAssertEqual(BoardNavigator.move(from: nil, .left, on: played), at(1, 0))
    }

    func testFirstOpenTileReadsAcrossRowsBeforeDown() {
        let played = board(played: [at(0, 0), at(1, 0), at(2, 0)])
        XCTAssertEqual(BoardNavigator.firstOpenTile(on: played), at(0, 1))
    }

    func testMovesOneStepInEachDirection() {
        let board = board()
        XCTAssertEqual(BoardNavigator.move(from: at(1, 1), .up, on: board), at(1, 0))
        XCTAssertEqual(BoardNavigator.move(from: at(1, 1), .down, on: board), at(1, 2))
        XCTAssertEqual(BoardNavigator.move(from: at(1, 1), .left, on: board), at(0, 1))
        XCTAssertEqual(BoardNavigator.move(from: at(1, 1), .right, on: board), at(2, 1))
    }

    func testStaysPutAtTheEdges() {
        let board = board()
        XCTAssertEqual(BoardNavigator.move(from: at(0, 0), .up, on: board), at(0, 0))
        XCTAssertEqual(BoardNavigator.move(from: at(0, 0), .left, on: board), at(0, 0))
        XCTAssertEqual(BoardNavigator.move(from: at(2, 3), .down, on: board), at(2, 3))
        XCTAssertEqual(BoardNavigator.move(from: at(2, 3), .right, on: board), at(2, 3))
    }

    func testSkipsPlayedTilesInAColumn() {
        let board = board(played: [at(0, 1), at(0, 2)])
        XCTAssertEqual(BoardNavigator.move(from: at(0, 0), .down, on: board), at(0, 3))
        XCTAssertEqual(BoardNavigator.move(from: at(0, 3), .up, on: board), at(0, 0))
    }

    func testSkipsFullyPlayedColumns() {
        let board = board(played: [at(1, 0), at(1, 1), at(1, 2), at(1, 3)])
        XCTAssertEqual(BoardNavigator.move(from: at(0, 2), .right, on: board), at(2, 2))
        XCTAssertEqual(BoardNavigator.move(from: at(2, 2), .left, on: board), at(0, 2))
    }

    func testSidewaysPicksTheClosestOpenRowPreferringTheUpperOne() {
        // Row 1 of column 1 is played, so rows 0 and 2 tie one step away.
        let board = board(played: [at(1, 1)])
        XCTAssertEqual(BoardNavigator.move(from: at(0, 1), .right, on: board), at(1, 0))
    }

    func testFromAPlayedTileMovesOnOrFallsBackToTheNearestOpenTile() {
        // After a clue is played the highlight sits on its (now blank) tile.
        let board = board(played: [at(0, 0), at(1, 0)])
        XCTAssertEqual(BoardNavigator.move(from: at(0, 0), .down, on: board), at(0, 1))
        XCTAssertEqual(BoardNavigator.move(from: at(0, 0), .up, on: board), at(0, 1), "nowhere to go up, so the nearest open tile")
    }

    func testOutOfRangePositionStartsAgain() {
        let small = board(columns: 2, rows: 2)
        XCTAssertEqual(BoardNavigator.move(from: at(5, 5), .up, on: small), at(0, 0))
    }

    func testNilWhenEveryTileIsPlayed() {
        let all = Set((0..<2).flatMap { column in (0..<2).map { at(column, $0) } })
        let board = board(columns: 2, rows: 2, played: all)
        XCTAssertNil(BoardNavigator.move(from: nil, .down, on: board))
        XCTAssertNil(BoardNavigator.move(from: at(0, 0), .right, on: board))
    }

    func testHandlesColumnsOfDifferentHeights() {
        var board = board(columns: 2, rows: 4)
        board.categories[1].questions.removeLast(2)
        XCTAssertEqual(BoardNavigator.move(from: at(0, 3), .right, on: board), at(1, 1))
    }
}
