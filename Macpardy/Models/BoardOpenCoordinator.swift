//
//  BoardOpenCoordinator.swift
//  Macpardy
//

import Foundation
import Observation
import OSLog

/// Opens a board from anywhere: File > Import Board…, Open Recent, or a
/// double-click in Finder. It asks whether to play or edit the board, and
/// checks first before a game in progress is replaced.
///
/// Its state is shown at the root of the Control window (see
/// `BoardOpenDialogs`), so it works on the launch screen and during a game.
@Observable
final class BoardOpenCoordinator {

    /// A board that was picked and is waiting for Play or Edit.
    struct PendingBoard: Identifiable, Equatable {
        let id = UUID()
        let url: URL
    }

    /// Boards loaded for Play that are waiting for the user to agree to end the game.
    struct PendingReplacement {
        let boards: [MacpardyBoard]
        let url: URL
    }

    /// A board loaded for Edit that is waiting for the user to agree to
    /// replace what is already open in the editor.
    struct PendingEdit {
        let draft: BoardDraft
        let url: URL
    }

    var isImporterPresented = false
    var pendingBoard: PendingBoard? {
        didSet { log.change("BoardOpenCoordinator.pendingBoard", from: oldValue?.url.lastPathComponent, to: pendingBoard?.url.lastPathComponent) }
    }
    var pendingReplacement: PendingReplacement? {
        didSet { log.change("BoardOpenCoordinator.pendingReplacement", from: oldValue?.url.lastPathComponent, to: pendingReplacement?.url.lastPathComponent) }
    }
    var pendingEdit: PendingEdit? {
        didSet { log.change("BoardOpenCoordinator.pendingEdit", from: oldValue?.url.lastPathComponent, to: pendingEdit?.url.lastPathComponent) }
    }
    var loadError: BoardLoadReport?

    private let log = AppLogger.database

    @ObservationIgnored
    let recents: RecentBoards

    @ObservationIgnored
    let editorSession: BoardEditorSession

    /// Whether a game is in progress. Set by the app.
    @ObservationIgnored
    var isGameRunning: () -> Bool = { false }

    /// Ends any game in progress and starts one with `boards`. Set by the app.
    @ObservationIgnored
    var startGame: ([MacpardyBoard]) -> Void = { _ in }

    /// Shows the editor window once a draft is queued. Set by the Control window.
    @ObservationIgnored
    var showEditor: () -> Void = {}

    init(recents: RecentBoards = .shared, editorSession: BoardEditorSession = .shared) {
        self.recents = recents
        self.editorSession = editorSession
    }

    // MARK: - Choosing a file

    func requestImport() {
        log.state("Board import requested")
        isImporterPresented = true
    }

    func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            open(url: url)
        case .failure(let error):
            AppLogger.database.error("Import picker failed: \(error.localizedDescription)")
        }
    }

    /// Asks what to do with `url`: play it or edit it.
    func open(url: URL) {
        pendingBoard = PendingBoard(url: url)
    }

    // MARK: - Play

    func play(_ pending: PendingBoard) async {
        pendingBoard = nil
        do {
            let boards = try await Self.boardsForPlay(at: pending.url)
            if isGameRunning() {
                pendingReplacement = PendingReplacement(boards: boards, url: pending.url)
            } else {
                begin(boards, from: pending.url)
            }
        } catch {
            fail(pending.url, error)
        }
    }

    /// The user agreed to end the game in progress.
    func confirmReplacement(_ pending: PendingReplacement) {
        pendingReplacement = nil
        begin(pending.boards, from: pending.url)
    }

    private func begin(_ boards: [MacpardyBoard], from url: URL) {
        AppLogger.database.info("Opened \(url.lastPathComponent) to play")
        recents.note(url)
        startGame(boards)
    }

    // MARK: - Edit

    /// Opens the board in the editor. A game in progress is never touched.
    func edit(_ pending: PendingBoard) {
        pendingBoard = nil
        do {
            let draft = try Self.draft(at: pending.url)
            if editorSession.hasUnsavedEdits {
                pendingEdit = PendingEdit(draft: draft, url: pending.url)
            } else {
                open(draft, from: pending.url)
            }
        } catch {
            fail(pending.url, error)
        }
    }

    /// The user agreed to replace the editor's unsaved changes.
    func confirmEdit(_ pending: PendingEdit) {
        pendingEdit = nil
        open(pending.draft, from: pending.url)
    }

    private func open(_ draft: BoardDraft, from url: URL) {
        AppLogger.database.info("Opened \(url.lastPathComponent) for editing")
        recents.note(url)
        editorSession.edit(draft)
        showEditor()
    }

    // MARK: - Loading

    private func fail(_ url: URL, _ error: Error) {
        AppLogger.database.error("Can't open \(url.lastPathComponent): \(String(describing: error))")
        // A file that has moved or can't be read shouldn't stay in the menu.
        if !FileManager.default.isReadableFile(atPath: url.path) {
            recents.remove(url)
        }
        loadError = BoardLoadReport(fileName: url.lastPathComponent, error: error)
    }

    static func draft(at url: URL) throws -> BoardDraft {
        let data = try FileManagerService().readData(from: url)
        return try BoardLoader.load(data: data, fileName: url.lastPathComponent)
    }

    /// `.macpardy` and `.json` boards play as they always have. CSV and
    /// plain ZIP files go through the editor's loader first.
    static func boardsForPlay(at url: URL) async throws -> [MacpardyBoard] {
        switch url.pathExtension.lowercased() {
        case "csv", "zip":
            return try draft(at: url).makeBoards()
        default:
            return try await FileManagerService().readBoards(from: url)
        }
    }
}
