//
//  MacpardyApp.swift
//  Macpardy
//
//  Created by Jimmy Kane on 7/15/26.
//

import AppKit
import OSLog
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
        guard session.hasUnsavedEdits else { return .terminateNow }

        // A prompt is already up (e.g. from closing the window); let the user answer it.
        guard session.requestClose(.quitApp) else { return .terminateCancel }

        session.onQuitDecision = { proceed in
            sender.reply(toApplicationShouldTerminate: proceed)
        }
        session.editorWindow?.makeKeyAndOrderFront(nil)
        sender.activate()
        return .terminateLater
    }
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
    private var buzzerState = BuzzerState()

    @State
    private var editorSession = BoardEditorSession.shared

    @State
    private var boardOpenCoordinator = BoardOpenCoordinator()

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
                } else {
                    LaunchScreenView(hasSelectedGame: $hasSelectedGame, gameState: $gameState)
                        .environment(buzzerState)
                        .environment(editorSession)
                }
            }
            .boardOpenDialogs(boardOpenCoordinator)
            .background(WindowCloseGuard(shouldClose: { true }, onWindow: { appDelegate.controlWindow = $0 }))
            .onAppear {
                boardOpenCoordinator.isGameRunning = { hasSelectedGame }
                boardOpenCoordinator.startGame = { boards in startGame(with: boards) }
            }
            // Double-clicking a .macpardy board in Finder opens it here.
            .onOpenURL { url in
                boardOpenCoordinator.open(url: url)
            }
        }
        .defaultSize(width: 1200, height: 900)
        .onChange(of: hasSelectedGame) { _, selected in
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
        // Wagering is open exactly while the Final category is displayed;
        // answering while the Final clue is up (locked once the response is shown).
        .onChange(of: gameState.phase) { _, phase in
            Task {
                await syncWagering()
                await syncAnswering()
            }
            SoundPlayer.shared.handle(phase: phase)
        }
        .commands {
            FileCommands(coordinator: boardOpenCoordinator)
            HelpCommands()
            GameCommands(gameState: gameState, buzzerState: buzzerState, hasSelectedGame: hasSelectedGame)
        }

        Window("Display", id: "display") {
            if hasSelectedGame {
                PresentationView()
                    .environment(gameState)
                    .environment(buzzerState)
            }
        }
        .defaultSize(width: 1920, height: 1080)
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled)

        Settings {
            SettingsView()
        }

        Window("shortcuts.window.title", id: "shortcuts") {
            KeyboardShortcutsView()
                .windowFullScreenBehavior(.disabled)
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled)

        Window("Create Macpardy Game", id: "create-macpardy") {
            CreateMacpardyGameView()
                .environment(editorSession)
                .windowFullScreenBehavior(.disabled)
        }
        .defaultSize(width: 1400, height: 820)
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled)
    }
}
