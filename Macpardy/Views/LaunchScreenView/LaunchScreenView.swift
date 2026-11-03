//
//  LaunchScreenView.swift
//  Macpardy
//
import OSLog
import SwiftUI
import UniformTypeIdentifiers

struct LaunchScreenView: View {

    @Environment(\.openWindow) var openWindow
    @Environment(BoardEditorSession.self) var editorSession
    var recents: RecentBoards = .shared

    @Binding var hasSelectedGame: Bool
    @State var showFileExporter: Bool = false
    @Binding var gameState: GameState

    @State var showResumeAlert: Bool = false
    @State var pendingSavedSnapshot: GameSnapshot?
    @State var showNewGameSheet: Bool = false
    @State var showEditImporter: Bool = false
    @State var loadErrorReport: BoardLoadReport?
    /// The auto-saved game, if any, offered in the resume banner.
    @State var savedSnapshot: GameSnapshot?
    @State var showDiscardConfirmation: Bool = false
    /// Which built-in game picker is open, if any.
    @State var pickerMode: GamePickerMode?
    /// What to do once the picker has finished closing (a file panel can't
    /// open while the sheet is still on screen).
    @State var afterPickerDismiss: (() -> Void)?

    var body: some View {
        VStack(spacing: 48) {
            launchTitle()
            actionTiles()

            if let savedSnapshot {
                ResumeGameBanner(
                    snapshot: savedSnapshot,
                    onResume: { resume(savedSnapshot) },
                    onDiscard: { showDiscardConfirmation = true }
                )
                .frame(maxWidth: 1020)
            }
        }
        .padding(48)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MacpardyTheme.boardBlue)
        .preferredColorScheme(.dark)
        .task {
            savedSnapshot = await GameSaveStore.shared.load()
        }
        .fileImporter(
            isPresented: $showEditImporter,
            allowedContentTypes: [.macpardyBoard, .json, .zip, .commaSeparatedText]
        ) { result in
            UIActionLog.filePicked("file importer 'Edit board'", result)
            handleEditPicked(result)
        }
        .logPresentation("file importer 'Edit board'", isPresented: showEditImporter)
        .sheet(item: $loadErrorReport) { report in
            BoardLoadErrorView(report: report)
        }
        .logPresentation("sheet 'Board load error'", isPresented: loadErrorReport != nil)
        .sheet(item: $pickerMode, onDismiss: {
            afterPickerDismiss?()
            afterPickerDismiss = nil
        }) { mode in
            builtInPicker(for: mode)
        }
        .logPresentation("sheet 'Built-in games' (\(pickerMode.map { "\($0)" } ?? "closed"))", isPresented: pickerMode != nil)
        .sheet(isPresented: $showNewGameSheet) {
            NewGameView(
                onBuildInEditor: {
                    showNewGameSheet = false
                    openWindow(id: "create-macpardy")
                },
                onPlay: { boards in
                    showNewGameSheet = false
                    gameState.loadGame(boards: boards)
                    hasSelectedGame = true
                }
            )
        }
        .logPresentation("sheet 'New game'", isPresented: showNewGameSheet)
        .alert("launch.alert.resume_title", isPresented: $showResumeAlert) {
            LoggedButton("launch.alert.resume_action", log: "alert 'Resume saved game?' › Resume") {
                if let snapshot = pendingSavedSnapshot {
                    resume(snapshot)
                }
            }
            LoggedButton("launch.alert.new_game_action", log: "alert 'Resume saved game?' › New game", role: .destructive) {
                discardSavedGame()
                pickerMode = .play
            }
            LoggedButton("common.cancel", log: "alert 'Resume saved game?' › Cancel", role: .cancel) {}
        } message: {
            Text("launch.alert.resume_message")
        }
        .logPresentation("alert 'Resume saved game?'", isPresented: showResumeAlert)
        .confirmationDialog("launch.resume.discard_confirm.title", isPresented: $showDiscardConfirmation) {
            LoggedButton("launch.resume.discard", log: "dialog 'Discard saved game?' › Discard", role: .destructive) {
                discardSavedGame()
            }
            LoggedButton("common.cancel", log: "dialog 'Discard saved game?' › Cancel", role: .cancel) {}
        } message: {
            Text("launch.resume.discard_confirm.message")
        }
        .logPresentation("dialog 'Discard saved game?'", isPresented: showDiscardConfirmation)
        .fileImporter(
            isPresented: $showFileExporter,
            allowedContentTypes: [.macpardyBoard, .json],
            onCompletion: { result in
                UIActionLog.filePicked("file importer 'Play board'", result)
                switch result {
                case .success(let URL):
                    AppLogger.database.info("Successfully Imported \(URL.lastPathComponent)")
                    loadGame(url: URL)
                case .failure(let error):
                    AppLogger.database.error("\(error.localizedDescription)")
                }
            }
        )
        .logPresentation("file importer 'Play board'", isPresented: showFileExporter)
    }
}

#Preview {
    LaunchScreenView(
        hasSelectedGame: .constant(false),
        gameState: .constant(GameState())
    )
    .environment(BoardEditorSession())
    .frame(width: 1200, height: 800)
}

/// Which action the built-in game picker is for.
enum GamePickerMode: Identifiable {
    case play
    case edit

    var id: Self { self }
}
