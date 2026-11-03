//
//  BoardPackage.swift
//  Macpardy
//

import Foundation
import OSLog
import UniformTypeIdentifiers
import ZIPFoundation

extension UTType {
    /// A `.macpardy` board package. Declared in the app's Info.plist.
    nonisolated static let macpardyBoard = UTType(exportedAs: "jbkiv.macpardy.board", conformingTo: .data)
}

/// Reads and writes board files.
///
/// Package format (`.macpardy`), a zip archive containing:
/// ```
/// board.json      { "formatVersion": 2, "title": "…", "boards": [MacpardyBoard] }
/// images/<file>   one file per question image, referenced from board.json
/// ```
/// A question references its image with `"image": { "path": "images/<file>" }`.
/// A package with only `board.json` is valid. `title` is the game's name; it's
/// optional, and files saved before games had their own name don't have it.
///
/// Legacy boards (format 1) are a plain `.json` file holding `[MacpardyBoard]`.
/// They, and a bare `board.json` in the new shape, still open directly.
nonisolated enum BoardPackage {

    static let formatVersion = 2

    static let fileExtension = "macpardy"

    static let boardFileName = "board.json"

    static let imagesDirectory = "images"

    /// Images bigger than this inside a package are treated as missing.
    static let maxImageEntryBytes = 25 * 1024 * 1024

    /// `board.json` bigger than this is rejected.
    static let maxBoardEntryBytes = 10 * 1024 * 1024

    enum PackageError: Error, Equatable {
        case missingBoardFile
        case unsupportedFormatVersion(Int)
        case archiveUnreadable
        case archiveWriteFailed
    }

    struct BoardFile: Codable {
        let formatVersion: Int
        let boards: [MacpardyBoard]
        /// The game's name. Absent in older files; ignored by older apps.
        var title: String? = nil
    }

    /// A game read from disk: its boards and, if the file has one, its name.
    struct GameFile: Equatable {
        var boards: [MacpardyBoard]
        var title: String?
    }

    // MARK: - Reading

    /// Reads a package, a new-style `board.json`, or a legacy `.json` board.
    static func read(_ data: Data) throws -> [MacpardyBoard] {
        try readGame(data).boards
    }

    /// Like `read`, but keeps the game's title.
    static func readGame(_ data: Data) throws -> GameFile {
        if isZip(data) {
            return try readPackage(data)
        }
        return try decodeGameJSON(data)
    }

    static func isZip(_ data: Data) -> Bool {
        data.starts(with: [0x50, 0x4B, 0x03, 0x04]) || data.starts(with: [0x50, 0x4B, 0x05, 0x06])
    }

    /// Decodes either the versioned `BoardFile` shape or a legacy `[MacpardyBoard]`.
    static func decodeBoardJSON(_ data: Data) throws -> [MacpardyBoard] {
        try decodeGameJSON(data).boards
    }

    /// Like `decodeBoardJSON`, but keeps the game's title.
    static func decodeGameJSON(_ data: Data) throws -> GameFile {
        let decoder = JSONDecoder()
        // A top-level array is a legacy board. Decode it directly so a broken
        // one reports the field that's wrong rather than "expected an object".
        if startsWithArray(data) {
            return GameFile(boards: try decoder.decode([MacpardyBoard].self, from: data), title: nil)
        }
        let file = try decoder.decode(BoardFile.self, from: data)
        guard file.formatVersion <= formatVersion else {
            throw PackageError.unsupportedFormatVersion(file.formatVersion)
        }
        return GameFile(boards: file.boards, title: file.title)
    }

    /// Whether the first non-whitespace character is `[` (skipping a UTF-8 BOM).
    private static func startsWithArray(_ data: Data) -> Bool {
        let whitespace: Set<UInt8> = [0x20, 0x09, 0x0A, 0x0D, 0xEF, 0xBB, 0xBF]
        return data.first { !whitespace.contains($0) } == UInt8(ascii: "[")
    }

    private static func readPackage(_ data: Data) throws -> GameFile {
        let archive: Archive
        do {
            archive = try Archive(data: data, accessMode: .read)
        } catch {
            throw PackageError.archiveUnreadable
        }

        guard let boardEntry = archive[boardFileName] else {
            throw PackageError.missingBoardFile
        }
        guard boardEntry.uncompressedSize <= UInt64(maxBoardEntryBytes),
              let boardData = extract(boardEntry, from: archive, limit: maxBoardEntryBytes) else {
            throw PackageError.archiveUnreadable
        }

        var game = try decodeGameJSON(boardData)
        resolveImages(in: &game.boards) { path in
            guard isSafeImagePath(path) else {
                AppLogger.database.warning("Ignoring unsafe image path \(path)")
                return nil
            }
            guard let entry = archive[path] else {
                AppLogger.database.warning("Board image missing: \(path)")
                return nil
            }
            guard entry.uncompressedSize <= UInt64(maxImageEntryBytes) else {
                AppLogger.database.warning("Board image too large: \(path)")
                return nil
            }
            return extract(entry, from: archive, limit: maxImageEntryBytes)
        }
        return game
    }

    /// Extracts an entry, giving up if it inflates past `limit` (the header's
    /// declared size can't be trusted).
    private static func extract(_ entry: Entry, from archive: Archive, limit: Int) -> Data? {
        var output = Data()
        do {
            _ = try archive.extract(entry, skipCRC32: false) { chunk in
                guard output.count + chunk.count <= limit else { throw PackageError.archiveUnreadable }
                output.append(chunk)
            }
            return output
        } catch {
            AppLogger.database.error("Failed to extract \(entry.path): \(error.localizedDescription)")
            return nil
        }
    }

    /// Only `images/<name>` paths with no traversal are allowed.
    static func isSafeImagePath(_ path: String) -> Bool {
        let components = path.split(separator: "/", omittingEmptySubsequences: false)
        return components.count == 2
            && components[0] == Substring(imagesDirectory)
            && !components[1].isEmpty
            && components[1] != "."
            && components[1] != ".."
            && !path.contains("\\")
    }

    // MARK: - Writing

    /// Writes boards as a zip package. Image paths are reassigned from each
    /// question's ID so they're unique; questions whose image has no data
    /// lose the reference.
    static func write(_ boards: [MacpardyBoard], title: String? = nil) throws -> Data {
        var boards = boards
        var images: [(path: String, data: Data)] = []

        for b in boards.indices {
            for c in boards[b].categories.indices {
                for q in boards[b].categories[c].questions.indices {
                    let question = boards[b].categories[c].questions[q]
                    guard let image = question.image else { continue }
                    guard let data = image.data else {
                        boards[b].categories[c].questions[q].image = nil
                        continue
                    }
                    let ext = ImageImporter.fileExtension(for: data)
                    let path = "\(imagesDirectory)/\(question.id.uuidString.lowercased()).\(ext)"
                    boards[b].categories[c].questions[q].image = QuestionImage(path: path, data: data)
                    images.append((path: path, data: data))
                }
            }
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.userInfo[.omitQuestionImageData] = true
        let boardData = try encoder.encode(BoardFile(formatVersion: formatVersion, boards: boards, title: title))

        return try makeArchive(entries: [(path: boardFileName, data: boardData)] + images)
    }

    /// Builds a zip in memory. `board.json` is deflated; images are stored
    /// as-is since they're already compressed.
    static func makeArchive(entries: [(path: String, data: Data)]) throws -> Data {
        do {
            let archive = try Archive(accessMode: .create)
            for entry in entries {
                let compression: CompressionMethod = entry.path == boardFileName ? .deflate : .none
                try add(entry.data, at: entry.path, compression: compression, to: archive)
            }
            guard let data = archive.data else { throw PackageError.archiveWriteFailed }
            return data
        } catch let error as PackageError {
            throw error
        } catch {
            AppLogger.database.error("Failed to write board package: \(error.localizedDescription)")
            throw PackageError.archiveWriteFailed
        }
    }

    private static func add(_ data: Data, at path: String, compression: CompressionMethod, to archive: Archive) throws {
        try archive.addEntry(
            with: path,
            type: .file,
            uncompressedSize: Int64(data.count),
            compressionMethod: compression,
            provider: { position, size in
                let start = Int(position)
                return data.subdata(in: start..<min(start + size, data.count))
            }
        )
    }

    // MARK: - Helpers

    /// Replaces each image's data using `load(path)`. A `nil` result keeps the
    /// reference with no data, which the display shows as a placeholder.
    static func resolveImages(in boards: inout [MacpardyBoard], load: (String) -> Data?) {
        for b in boards.indices {
            for c in boards[b].categories.indices {
                for q in boards[b].categories[c].questions.indices {
                    guard let path = boards[b].categories[c].questions[q].image?.path else { continue }
                    boards[b].categories[c].questions[q].image?.data = load(path)
                }
            }
        }
    }
}
