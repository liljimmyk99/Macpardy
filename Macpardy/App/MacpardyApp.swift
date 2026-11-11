//
//  MacpardyApp.swift
//  Macpardy
//
//  Created by Jimmy Kane on 7/15/26.
//

import AppKit
import BuzzerCore
import SwiftUI

/// Holds a quit while an edited board has unsaved changes, so the editor
/// can ask whether to save first.
final class MacpardyAppDelegate: NSObject, NSApplicationDelegate {

    /// The Control window. Closing it ends the app, taking every other window with it.
    weak var controlWindow: NSWindow?

    private var closeObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        closeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let window = note.object as? NSWindow else { return }
            MainActor.assumeIsolated {
                guard let self, window === self.controlWindow else { return }
                NSApp.terminate(nil)
            }
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let session = BoardEditorSession.shared
        guard session.hasUnsavedEdits else {
            AppLogger.control.app("quit requested (no unsaved edits → quitting)")
            return .terminateNow
        }

        // A prompt is already up (e.g. from closing the window); let the user answer it.
        guard session.requestClose(.quitApp) else {
            AppLogger.control.app("quit requested (a save prompt is already up → cancelled)")
            return .terminateCancel
        }
        AppLogger.control.app("quit requested (unsaved edits → prompt)")

        session.onQuitDecision = { proceed in
            sender.reply(toApplicationShouldTerminate: proceed)
        }
        session.editorWindow?.makeKeyAndOrderFront(nil)
        sender.activate()
        return .terminateLater
    }

    /// Right-clicking the Dock icon lists the open windows; choosing one brings it forward.
    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let windows = NSApp.windows
        let infos = windows.map {
            DockMenuBuilder.WindowInfo(
                title: $0.title,
                isVisible: $0.isVisible,
                isMiniaturized: $0.isMiniaturized,
                isKey: $0.isKeyWindow,
                isPanel: $0 is NSPanel
            )
        }
        let entries = DockMenuBuilder.entries(for: infos)
        guard !entries.isEmpty else { return nil }

        let menu = NSMenu()
        for entry in entries {
            let window = windows[entry.index]
            let item = ClosureMenuItem(title: entry.title) {
                AppLogger.control.debug("dock menu › activate window \(entry.title)")
                if window.isMiniaturized { window.deminiaturize(nil) }
                window.makeKeyAndOrderFront(nil)
                NSApp.activate()
            }
            item.state = entry.isKey ? .on : .off
            menu.addItem(item)
        }
        return menu
    }

    /// Writes the last log lines before the app exits (waits at most half a second).
    func applicationWillTerminate(_ notification: Notification) {
        AppLogger.control.info("Macpardy quitting")
        let done = DispatchSemaphore(value: 0)
        let store = LogCenter.shared.store
        Task.detached {
            // Give the line above a moment to reach the store, then write it out.
            try? await Task.sleep(for: .milliseconds(50))
            await store.flush()
            done.signal()
        }
        _ = done.wait(timeout: .now() + 0.5)
    }
}

/// A menu item that runs a closure when chosen.
private final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(title: String, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: "")
        target = self
    }

    required init(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    @objc private func run() { handler() }
}

@main
struct MacpardyApp: App {

    @NSApplicationDelegateAdaptor(MacpardyAppDelegate.self)
    private var appDelegate

    @State
    private var gameState = GameState()

    @State
    private var hasSelectedGame = false

    @State
    private var buzzerState = BuzzerState(fromSettings: .standard)

    @State
    private var editorSession = BoardEditorSession.shared

    @State
    private var boardOpenCoordinator = BoardOpenCoordinator()
    @State private var walkthroughCoordinator = WalkthroughCoordinator()

    @AppStorage(AppSettings.Key.buzzersEnabled)
    private var buzzersEnabled = AppSettings.defaultBuzzersEnabled

    @Environment(\.scenePhase) private var scenePhase

    init() {
        LogCenter.shared.start()
        AppLogger.control.info("\(SystemInfoReport.appDescription) launched on \(SystemInfoReport.osDescription)")
        AppLogger.control.app("launch \(SystemInfoReport.appDescription) \(SystemInfoReport.osDescription) \(SystemInfoReport.macModel)")
        SettingsChangeLog.shared.start()
    }

    private var buzzerTeams: [BuzzerTeam] {
        gameState.game.teams.map(BuzzerTeam.init(team:))
    }

    private var teamScores: [UUID: Int] {
        Dictionary(uniqueKeysWithValues: gameState.game.teams.map { ($0.id, $0.score) })
    }

    /// Buzzers arm on a normal question, are off (and can't be pressed) on a
    /// Daily Double, and are otherwise disabled.
    private var buzzerMode: BuzzerMode {
        switch gameState.phase {
        case .question where gameState.dailyDoubleTeamID == nil: .armed
        case .question, .dailyDouble: .unavailable
        default: .disabled
        }
    }

    /// Opens wagering on the phones while the Final category is shown, closes it otherwise.
    private func syncWagering() async {
        if gameState.phase == .finalMacpardyCategory {
            await buzzerState.openWagering(
                limits: gameState.finalWagerLimits,
                wagers: gameState.finalMacpardyWagers
            )
        } else {
            await buzzerState.closeWagering()
        }
    }

    /// Opens Final answering on the phones while the clue is up, locks it once
    /// the correct response is revealed, and closes it everywhere else (#80).
    private func syncAnswering() async {
        await buzzerState.setAnswering(
            gameState.finalAnswerWindow,
            answers: gameState.finalMacpardyAnswers
        )
    }

    /// Starts a game from `boards`, ending the one in progress first: the
    /// buzzer server and sounds stop exactly as when a game is left, then
    /// the server restarts for the new game.
    private func startGame(with boards: [MacpardyBoard]) {
        guard hasSelectedGame else {
            gameState.loadGame(boards: boards)
            hasSelectedGame = true
            return
        }
        Task {
            hasSelectedGame = false
            SoundPlayer.shared.stopAll()
            await buzzerState.stopServer()
            // Let the change to `hasSelectedGame` reach its handler before the game starts again.
            await Task.yield()
            gameState.loadGame(boards: boards)
            hasSelectedGame = true
        }
    }

    /// Finishes the game (#82): the save is cleared and the Control window
    /// goes back to the launch screen, which stops the buzzer server (phones
    /// see "Game over") and the sounds. The Display shows its waiting screen.
    private func completeGame() {
        AppLogger.control.info("Game completed")
        // Both change together, so neither window draws the setup phase in between.
        gameState.endGame()
        hasSelectedGame = false
        // Started before the launch screen appears and looks for a save to resume.
        Task { await GameSaveStore.shared.clear() }
    }

    /// Starts a game the user just edited and saved. Ignored while a game is
    /// in progress, like boards opened from Finder.
    private func playEditedBoards(_ boards: [MacpardyBoard]) {
        guard !hasSelectedGame else {
            AppLogger.control.info("Ignoring edited board: a game is in progress")
            return
        }
        gameState.loadGame(boards: boards)
        hasSelectedGame = true
    }

    var body: some Scene {

        Window("Control", id: "control") {
            Group {
                if hasSelectedGame {
                    ControlView()
                        .environment(gameState)
                        .environment(buzzerState)
                        .environment(\.completeGame, completeGame)
                } else {
                    LaunchScreenView(hasSelectedGame: $hasSelectedGame, gameState: $gameState)
                        .environment(buzzerState)
                        .environment(editorSession)
                        .environment(walkthroughCoordinator)
                }
            }
            .boardOpenDialogs(boardOpenCoordinator)
            .background(WindowCloseGuard(shouldClose: { true }, onWindow: { appDelegate.controlWindow = $0 }))
            .onAppear {
                boardOpenCoordinator.isGameRunning = { hasSelectedGame }
                walkthroughCoordinator.isAvailable = { !hasSelectedGame }
                boardOpenCoordinator.startGame = { boards in startGame(with: boards) }
            }
            // Double-clicking a .macpardy board in Finder opens it here.
            .onOpenURL { url in
                AppLogger.control.app("asked to open \(url.lastPathComponent) (Finder)")
                boardOpenCoordinator.open(url: url)
            }
            .logWindowLifecycle("Control")
        }
        .defaultSize(width: 1200, height: 900)
        .onChange(of: scenePhase) { old, new in
            AppLogger.control.app("scenePhase \(old) → \(new)")
        }
        .onChange(of: hasSelectedGame) { old, selected in
            AppLogger.control.change("App.hasSelectedGame", from: old, to: selected)
            AppLogger.control.nav("Control shows \(selected ? "the game" : "the launch screen")")
            if selected {
                Task {
                    await buzzerState.syncTeams(buzzerTeams)
                    await buzzerState.syncScores(teamScores)
                    await buzzerState.setMode(buzzerMode)
                    await syncWagering()
                    await syncAnswering()
                    buzzerState.onWagerSubmitted = { submission in
                        gameState.setFinalWager(teamID: submission.teamID, amount: submission.amount)
                    }
                    buzzerState.onAnswerSubmitted = { submission in
                        gameState.setFinalAnswer(teamID: submission.teamID, answer: submission.answer)
                    }
                    await buzzerState.startServer()
                }
                SoundPlayer.shared.handle(phase: gameState.phase)
            } else {
                SoundPlayer.shared.stopAll()
                Task { await buzzerState.stopServer() }
            }
        }
        // Keyed on the phone-facing fields only, so score changes don't re-sync.
        .onChange(of: buzzerTeams) { _, teams in
            Task { await buzzerState.syncTeams(teams) }
        }
        .onChange(of: teamScores) { _, scores in
            Task {
                await buzzerState.syncScores(scores)
                // Max wagers follow scores while the Final category is up.
                if gameState.phase == .finalMacpardyCategory { await syncWagering() }
            }
        }
        // "Play now" after saving an edited board.
        .onChange(of: editorSession.boardsToPlay) { _, boards in
            guard let boards else { return }
            editorSession.boardsToPlay = nil
            playEditedBoards(boards)
        }
        // Turning buzzers off mid-game drops the phones; turning them on starts a fresh session (#74).
        .onChange(of: buzzersEnabled) { _, enabled in
            guard hasSelectedGame else { return }
            Task {
                if enabled {
                    await buzzerState.startServer()
                } else {
                    await buzzerState.stopServer()
                }
            }
        }
        .onChange(of: buzzerMode) { _, mode in
            Task { await buzzerState.setMode(mode) }
        }
        // A phone buzz pauses the question timer and starts the response timer (#59).
        .onChange(of: buzzerState.firstBuzzTeamID) { _, teamID in
            gameState.teamBuzzedIn(teamID)
        }
        // Phones count the response time down themselves from start / stop events.
        .onChange(of: gameState.answeringTeamID) { _, teamID in
            Task { await buzzerState.setResponseTimer(teamID: teamID, seconds: gameState.responseSeconds) }
        }
        // Wagering is open exactly while the Final category is displayed.
        .onChange(of: gameState.phase) { _, phase in
            // The join screen covers one screen only; the next phase shows normally (#83).
            buzzerState.isJoinScreenOnDisplay = false
            Task { await syncWagering() }
            SoundPlayer.shared.handle(phase: phase)
        }
        // Answering is open while the Final clue is up and its timer has time
        // left; it locks when time runs out or the response is revealed.
        .onChange(of: gameState.finalAnswerWindow) { _, _ in
            Task { await syncAnswering() }
        }
        .commands {
            FileCommands(coordinator: boardOpenCoordinator)
            HelpCommands(walkthrough: walkthroughCoordinator)
            GameCommands(
                gameState: gameState,
                buzzerState: buzzerState,
                hasSelectedGame: hasSelectedGame,
                buzzersEnabled: buzzersEnabled
            )
        }

        Window("Display", id: "display") {
            Group {
                if hasSelectedGame {
                    PresentationView()
                        .environment(gameState)
                        .environment(buzzerState)
                } else {
                    WaitingForGameView()
                }
            }
            .logWindowLifecycle("Display", category: .display)
        }
        .defaultSize(width: 1920, height: 1080)
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled)

        Settings {
            SettingsView()
                .logWindowLifecycle("Settings")
        }

        Window("shortcuts.window.title", id: "shortcuts") {
            KeyboardShortcutsView()
                .windowFullScreenBehavior(.disabled)
                .logWindowLifecycle("Keyboard Shortcuts")
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled)

        Window("logs.window.title", id: "logs") {
            LogsView()
                .environment(LogCenter.shared)
                .environment(gameState)
                .environment(buzzerState)
                .logWindowLifecycle("Logs")
        }
        .defaultSize(width: 1000, height: 640)
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled)

        Window("Create Macpardy Game", id: "create-macpardy") {
            CreateMacpardyGameView()
                .environment(editorSession)
                .windowFullScreenBehavior(.disabled)
                .logWindowLifecycle("Board editor")
        }
        .defaultSize(width: 1400, height: 820)
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled)
    }
}
