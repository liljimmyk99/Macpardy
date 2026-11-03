//
//  GameSaveStore.swift
//  Macpardy
//
//  Created by Jimmy Kane on 10/18/26.
//

import Foundation
import OSLog

actor GameSaveStore {
    static let shared = GameSaveStore()

    private let fileManager: FileManager
    private let saveFileName: String = "saved_game.json"
    private let directoryName: String = "Macpardy"
    private let baseDirectory: URL?

    /// - Parameter baseDirectory: Where to keep the save. Defaults to
    ///   Application Support/Macpardy; tests pass a temporary directory.
    init(fileManager: FileManager = .default, baseDirectory: URL? = nil) {
        self.fileManager = fileManager
        self.baseDirectory = baseDirectory
    }

    private var applicationSupportDirectory: URL? {
        if let baseDirectory { return baseDirectory }
        guard let url = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        return url.appendingPathComponent(directoryName, isDirectory: true)
    }

    private var saveFileURL: URL? {
        applicationSupportDirectory?.appendingPathComponent(saveFileName)
    }

    func save(_ snapshot: GameSnapshot) async throws {
        guard let directory = applicationSupportDirectory, let fileURL = saveFileURL else {
            throw CocoaError(.fileNoSuchFile)
        }

        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snapshot)

        // Write atomically using a temporary file in the same directory, then replace item
        let tempURL = directory.appendingPathComponent(UUID().uuidString + ".tmp")
        try data.write(to: tempURL, options: .atomic)

        _ = try? fileManager.removeItem(at: fileURL)
        try fileManager.moveItem(at: tempURL, to: fileURL)
        AppLogger.database.state("Game auto-saved (\(data.count) bytes, phase \(snapshot.phase.logDescription))")
    }

    func load() async -> GameSnapshot? {
        guard let fileURL = saveFileURL, fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let snapshot = try decoder.decode(GameSnapshot.self, from: data)

            guard snapshot.schemaVersion == GameSnapshot.currentSchemaVersion else {
                AppLogger.database.warning("Saved game has unsupported schema version \(snapshot.schemaVersion). Discarding.")
                await clear()
                return nil
            }

            AppLogger.database.state("Saved game found (\(data.count) bytes, phase \(snapshot.phase.logDescription))")
            return snapshot
        } catch {
            AppLogger.database.error("Failed to decode saved game or file corrupted: \(error.localizedDescription). Discarding.")
            await clear()
            return nil
        }
    }

    func clear() async {
        guard let fileURL = saveFileURL, fileManager.fileExists(atPath: fileURL.path) else {
            return
        }
        do {
            try fileManager.removeItem(at: fileURL)
            AppLogger.database.state("Saved game cleared")
        } catch {
            AppLogger.database.error("Failed to clear saved game: \(error.localizedDescription)")
        }
    }
}
