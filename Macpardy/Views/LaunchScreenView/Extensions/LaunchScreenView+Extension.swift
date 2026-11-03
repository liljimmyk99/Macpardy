//
//  LaunchScreenView+Extension.swift
//  Macpardy
//

import OSLog
import SwiftUI

extension LaunchScreenView {

    @ViewBuilder
    func launchTitle() -> some View {
        VStack(spacing: 12) {
            Text("launch.title")
                .font(MacpardyTheme.launchTitleFont)
                .foregroundStyle(MacpardyTheme.gold)
                .shadow(color: .black, radius: 0, x: 3, y: 3)
                .padding(.horizontal, 48)
                .padding(.vertical, 18)
                .background(MacpardyTheme.tileBlue)

            Text("launch.subtitle")
                .font(.title3)
                .foregroundStyle(MacpardyTheme.mutedText)
        }
    }

    @ViewBuilder
    func actionTiles() -> some View {
        HStack(alignment: .top, spacing: 6) {
            LaunchActionTile(
                title: "launch.tile.play",
                caption: "launch.tile.play.caption",
                systemImage: "play.fill",
                shortcut: .importBoard
            ) {
                handleOpenExistingGame()
            }

            LaunchActionTile(
                title: "launch.tile.new",
                caption: "launch.tile.new.caption",
                systemImage: "plus",
                shortcut: .newBoard
            ) {
                showNewGameSheet = true
            }

            LaunchActionTile(
                title: "launch.tile.edit",
                caption: "launch.tile.edit.caption",
                systemImage: "square.and.pencil",
                shortcut: nil
            ) {
                openPicker(.edit)
            }
        }
        // Sizes every tile to the tallest, so captions that wrap differently don't change them.
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: 1020)
    }

    /// Asks whether to resume first when an auto-save exists, since starting
    /// a new board replaces it.
    func handleOpenExistingGame() {
        Task {
            if let saved = await GameSaveStore.shared.load() {
                pendingSavedSnapshot = saved
                showResumeAlert = true
            } else {
                openPicker(.play)
            }
        }
    }

    /// Offers the built-in games before the file picker. With none to offer,
    /// goes straight to the file picker.
    func openPicker(_ mode: GamePickerMode) {
        if BundledGameLibrary.games().isEmpty {
            openFilePicker(for: mode)
        } else {
            pickerMode = mode
        }
    }

    func openFilePicker(for mode: GamePickerMode) {
        switch mode {
        case .play: showFileExporter = true
        case .edit: showEditImporter = true
        }
    }

    @ViewBuilder
    func builtInPicker(for mode: GamePickerMode) -> some View {
        BuiltInGamePicker(
            title: mode == .play ? "launch.picker.play_title" : "launch.picker.edit_title",
            games: BundledGameLibrary.games(),
            onSelect: { game in
                pickerMode = nil
                switch mode {
                case .play: playBuiltIn(game)
                case .edit: editBuiltIn(game)
                }
            },
            onLoadOwnFile: {
                afterPickerDismiss = { openFilePicker(for: mode) }
                pickerMode = nil
            },
            onCancel: { pickerMode = nil }
        )
    }

    /// Starts a built-in game the same way a loaded file starts.
    func playBuiltIn(_ game: BundledGame) {
        do {
            gameState.loadGame(boards: try BundledGameLibrary.boards(for: game))
            hasSelectedGame = true
        } catch {
            AppLogger.database.error("Can't play built-in \(game.id): \(String(describing: error))")
            loadErrorReport = BoardLoadReport(fileName: game.id, error: error)
        }
    }

    /// Opens a copy of a built-in game in the editor. Saving always asks
    /// where to put a new file, so the bundled original is never changed.
    func editBuiltIn(_ game: BundledGame) {
        do {
            let draft = try BundledGameLibrary.draft(for: game)
            editorSession.edit(draft, suggestedFilename: BundledGameLibrary.copyFilename(for: draft.trimmedTitle))
            openWindow(id: "create-macpardy")
        } catch {
            AppLogger.database.error("Can't edit built-in \(game.id): \(String(describing: error))")
            loadErrorReport = BoardLoadReport(fileName: game.id, error: error)
        }
    }

    func resume(_ snapshot: GameSnapshot) {
        gameState.restore(from: snapshot)
        hasSelectedGame = true
    }

    func discardSavedGame() {
        savedSnapshot = nil
        Task {
            await GameSaveStore.shared.clear()
        }
    }

    /// Loads a JSON, package, or CSV board and opens it in the editor.
    /// A bad file shows what's wrong and leaves the user here.
    func handleEditPicked(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            do {
                let data = try FileManagerService().readData(from: url)
                let draft = try BoardLoader.load(data: data, fileName: url.lastPathComponent)
                AppLogger.database.info("Opened \(url.lastPathComponent) for editing")
                recents.note(url)
                editorSession.edit(draft)
                openWindow(id: "create-macpardy")
            } catch {
                AppLogger.database.error("Can't edit \(url.lastPathComponent): \(String(describing: error))")
                loadErrorReport = BoardLoadReport(fileName: url.lastPathComponent, error: error)
            }
        case .failure(let error):
            AppLogger.database.error("Edit picker failed: \(error.localizedDescription)")
        }
    }

    func loadGame(url: URL) {
        Task {
            do {
                let boards = try await FileManagerService().readBoards(from: url)
                recents.note(url)
                gameState.loadGame(boards: boards)
                hasSelectedGame = true
            } catch {
                AppLogger.control.error("Failed to decode boards from JSON: \(error.localizedDescription)")
            }
        }
    }
}
