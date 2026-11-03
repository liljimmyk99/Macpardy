//
//  BoardNavigator.swift
//  Macpardy
//
//  Moves the board highlight with the arrow keys (#88). Played tiles are
//  skipped, so the highlight only ever lands on a clue the host can open.
//

import Foundation

/// A tile on the board: the category's column and the clue's row in it.
struct BoardPosition: Hashable {
    let column: Int
    let row: Int
}

enum BoardDirection {
    case up, down, left, right
}

enum BoardNavigator {

    /// Where the highlight goes after an arrow press from `position`.
    ///
    /// With nothing highlighted yet, the first open tile is picked. Up and down
    /// stay in the column; left and right go to the nearest column with an open
    /// tile, on the open row closest to the current one. When there's nowhere
    /// to go the highlight stays, unless it's on a played tile, in which case
    /// it moves to the nearest open one. Nil only when every tile is played.
    static func move(from position: BoardPosition?, _ direction: BoardDirection, on board: MacpardyBoard) -> BoardPosition? {
        guard let position, contains(position, on: board) else {
            return firstOpenTile(on: board)
        }
        if let target = target(from: position, direction, on: board) {
            return target
        }
        return isOpen(position, on: board) ? position : nearestOpenTile(to: position, on: board)
    }

    /// The top-left open tile, reading across each row in turn.
    static func firstOpenTile(on board: MacpardyBoard) -> BoardPosition? {
        openTiles(on: board).min { ($0.row, $0.column) < ($1.row, $1.column) }
    }

    static func isOpen(_ position: BoardPosition, on board: MacpardyBoard) -> Bool {
        question(at: position, on: board).map { !$0.hasBeenPlayed } ?? false
    }

    static func question(at position: BoardPosition, on board: MacpardyBoard) -> Question? {
        guard contains(position, on: board) else { return nil }
        return board.categories[position.column].questions[position.row]
    }

    // MARK: - Private

    private static func contains(_ position: BoardPosition, on board: MacpardyBoard) -> Bool {
        board.categories.indices.contains(position.column)
            && board.categories[position.column].questions.indices.contains(position.row)
    }

    private static func target(from position: BoardPosition, _ direction: BoardDirection, on board: MacpardyBoard) -> BoardPosition? {
        switch direction {
        case .up:
            return stride(from: position.row - 1, through: 0, by: -1)
                .map { BoardPosition(column: position.column, row: $0) }
                .first { isOpen($0, on: board) }
        case .down:
            let rowCount = board.categories[position.column].questions.count
            return (position.row + 1..<rowCount)
                .map { BoardPosition(column: position.column, row: $0) }
                .first { isOpen($0, on: board) }
        case .left:
            return stride(from: position.column - 1, through: 0, by: -1)
                .lazy
                .compactMap { closestOpenRow(in: $0, to: position.row, on: board) }
                .first
        case .right:
            return (position.column + 1..<board.categories.count)
                .lazy
                .compactMap { closestOpenRow(in: $0, to: position.row, on: board) }
                .first
        }
    }

    /// The open tile in `column` nearest to `row`; the upper one wins a tie.
    private static func closestOpenRow(in column: Int, to row: Int, on board: MacpardyBoard) -> BoardPosition? {
        board.categories[column].questions.indices
            .map { BoardPosition(column: column, row: $0) }
            .filter { isOpen($0, on: board) }
            .min { (abs($0.row - row), $0.row) < (abs($1.row - row), $1.row) }
    }

    private static func nearestOpenTile(to position: BoardPosition, on board: MacpardyBoard) -> BoardPosition? {
        func distance(_ tile: BoardPosition) -> Int {
            abs(tile.column - position.column) + abs(tile.row - position.row)
        }
        return openTiles(on: board).min {
            (distance($0), $0.row, $0.column) < (distance($1), $1.row, $1.column)
        }
    }

    private static func openTiles(on board: MacpardyBoard) -> [BoardPosition] {
        board.categories.indices.flatMap { column in
            board.categories[column].questions.indices.map { BoardPosition(column: column, row: $0) }
        }
        .filter { isOpen($0, on: board) }
    }
}
