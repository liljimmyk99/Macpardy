//
//  BundledGameLibrary.swift
//  Macpardy
//

import Foundation
import OSLog

/// A game shipped inside the app, listed by its title.
struct BundledGame: Identifiable, Equatable {
    /// The file name, e.g. `classic-game-1.json`.
    let id: String
    let title: String
}

/// The games that ship in the app bundle (`Resources/Games/*.json`).
///
/// They are plain board files in the same format as user boards and go
/// through `BoardLoader`, so they get the same parsing and validation.
/// Nothing here writes to the bundle: editing a built-in works on a copy.
enum BundledGameLibrary {

    /// Where the games live in the app bundle.
    static var bundledDirectory: URL? {
        Bundle.main.url(forResource: "Games", withExtension: nil)
    }

    /// Every game in `directory` that loads, sorted by title. A file that
    /// doesn't load is logged and left out.
    static func games(in directory: URL? = bundledDirectory) -> [BundledGame] {
        guard let directory else { return [] }
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )) ?? []

        return files
            .filter { $0.pathExtension.lowercased() == "json" }
            .compactMap { url -> BundledGame? in
                do {
                    let draft = try BoardLoader.load(data: Data(contentsOf: url), fileName: url.lastPathComponent)
                    return BundledGame(id: url.lastPathComponent, title: draft.trimmedTitle)
                } catch {
                    AppLogger.database.error("Skipping built-in game \(url.lastPathComponent): \(String(describing: error))")
                    return nil
                }
            }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    /// The game as an editor draft.
    ///
    /// - Throws: `BoardLoader.LoadError`, or a file error.
    static func draft(for game: BundledGame, in directory: URL? = bundledDirectory) throws -> BoardDraft {
        guard let directory else { throw CocoaError(.fileNoSuchFile) }
        let data = try Data(contentsOf: directory.appendingPathComponent(game.id))
        return try BoardLoader.load(data: data, fileName: game.id)
    }

    /// The game's boards, ready to play.
    static func boards(for game: BundledGame, in directory: URL? = bundledDirectory) throws -> [MacpardyBoard] {
        try draft(for: game, in: directory).makeBoards()
    }

    /// The suggested file name when a built-in is saved after editing,
    /// e.g. `Classic Game 1 copy.json`.
    static func copyFilename(for title: String) -> String {
        let cleaned = title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        return "\(cleaned.isEmpty ? "macpardy-game" : cleaned) copy.json"
    }
}
