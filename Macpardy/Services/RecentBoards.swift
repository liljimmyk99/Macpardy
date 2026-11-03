//
//  RecentBoards.swift
//  Macpardy
//
//  The File > Open Recent list: newest first, no duplicates, capped.
//

import AppKit
import Foundation
import Observation

/// Where the recent list is kept between launches.
protocol RecentBoardsStorage {
    func load() -> [URL]
    func save(_ urls: [URL])
}

/// Keeps the list in the system's recent-documents store, so the sandbox
/// remembers access to each file across launches.
struct DocumentControllerRecentsStorage: RecentBoardsStorage {

    func load() -> [URL] {
        NSDocumentController.shared.recentDocumentURLs
    }

    func save(_ urls: [URL]) {
        let controller = NSDocumentController.shared
        controller.clearRecentDocuments(nil)
        // The controller shows the most recently noted file first.
        for url in urls.reversed() {
            controller.noteNewRecentDocumentURL(url)
        }
    }
}

@Observable
final class RecentBoards {

    static let shared = RecentBoards(storage: DocumentControllerRecentsStorage())

    static let limit = 10

    private(set) var urls: [URL]

    @ObservationIgnored
    private let storage: RecentBoardsStorage

    @ObservationIgnored
    private let limit: Int

    init(storage: RecentBoardsStorage, limit: Int = RecentBoards.limit) {
        self.storage = storage
        self.limit = limit
        self.urls = Array(storage.load().prefix(limit))
    }

    /// Moves `url` to the top of the list.
    func note(_ url: URL) {
        let url = url.standardizedFileURL
        var updated = urls.filter { $0.standardizedFileURL != url }
        updated.insert(url, at: 0)
        update(Array(updated.prefix(limit)))
    }

    /// Drops one entry, e.g. for a file that has gone missing.
    func remove(_ url: URL) {
        let url = url.standardizedFileURL
        update(urls.filter { $0.standardizedFileURL != url })
    }

    func clear() {
        update([])
    }

    private func update(_ updated: [URL]) {
        AppLogger.database.change("RecentBoards", from: urls.map(\.lastPathComponent), to: updated.map(\.lastPathComponent))
        urls = updated
        storage.save(updated)
    }
}
