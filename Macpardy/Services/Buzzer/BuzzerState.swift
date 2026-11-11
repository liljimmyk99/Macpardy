//
//  BuzzerState.swift
//  Macpardy
//
//  @Observable bridge between the buzzer backend (#102) and SwiftUI views.
//  Inject this into the environment via MacpardyApp.
//

import BuzzerCore
import Foundation

@Observable
final class BuzzerState {

    // MARK: - Published Properties

    /// The 6-character code phones must enter to join.
    private(set) var joinCode: String = ""

    /// Full join link (including `?code=`), encoded in the QR code and copied by
    /// the Copy button. Opening it joins straight away.
    private(set) var serverURL: URL?

    /// The page address without the code (`http://<ip>:<port>`), shown as text next
    /// to the Game PIN. Opening it shows the phone's Game PIN screen.
    private(set) var baseURL: URL?

    /// Number of phones that have authenticated with a valid join code.
    private(set) var connectedClientCount: Int = 0 {
        didSet { log.change("BuzzerState.joinedPhones", from: oldValue, to: connectedClientCount) }
    }

    /// Whether the server is currently running.
    private(set) var isRunning: Bool = false {
        didSet { log.change("BuzzerState.serverRunning", from: oldValue, to: isRunning) }
    }

    /// Whether the connection to an external server dropped and the app is retrying (#104).
    private(set) var isReconnecting: Bool = false {
        didSet { log.change("BuzzerState.reconnecting", from: oldValue, to: isReconnecting) }
    }

    /// Human-readable reason the server could not start (or stopped), if any.
    private(set) var startError: String?

    /// Teams that currently have a phone attached.
    private(set) var claimedTeamIDs: Set<UUID> = [] {
        didSet {
            guard oldValue != claimedTeamIDs else { return }
            for teamID in claimedTeamIDs.subtracting(oldValue) {
                log.state("Team claimed by a phone: \(teamLabel(teamID))", team: teamName(teamID))
            }
            for teamID in oldValue.subtracting(claimedTeamIDs) {
                log.state("Team lost its phone: \(teamLabel(teamID))", team: teamName(teamID))
            }
        }
    }

    /// Teams that had a phone at some point this session but have none now.
    /// Teams that never had a phone are not listed, so a game without buzzers
    /// shows no warnings.
    var disconnectedTeamIDs: Set<UUID> { everClaimedTeamIDs.subtracting(claimedTeamIDs) }

    /// The team that buzzed in first and is answering, if any.
    private(set) var firstBuzzTeamID: UUID? {
        didSet {
            log.change("BuzzerState.firstBuzz", from: oldValue.map(teamName), to: firstBuzzTeamID.map(teamName), team: firstBuzzTeamID.map(teamName))
        }
    }

    /// Called on the main actor when a phone submits a valid Final wager.
    var onWagerSubmitted: ((WagerSubmission) -> Void)?

    /// Called on the main actor when a phone saves a Final answer.
    var onAnswerSubmitted: ((AnswerSubmission) -> Void)?

    /// Whether the toolbar's Buzzers popover is open. Lives here so the Game menu can open it.
    var isPopoverPresented = false {
        didSet { log.change("BuzzerState.popoverPresented", from: oldValue, to: isPopoverPresented) }
    }

    /// Whether the Display shows the join screen (QR code, address, Game PIN) over
    /// the current phase (#83). Turned off when the phase changes or the server stops.
    var isJoinScreenOnDisplay = false {
        didSet { log.change("BuzzerState.joinScreenOnDisplay", from: oldValue, to: isJoinScreenOnDisplay) }
    }

    // MARK: - Private

    private let log = AppLogger.buzzer

    /// Where the server runs: the built-in one, or an external one (#104). When a factory is
    /// given, each `startServer()` asks it, so the choice in Settings applies to the next start.
    private var backend: any BuzzerBackend
    private let backendFactory: ((UserDefaults) -> any BuzzerBackend)?
    private let defaults: UserDefaults

    // The game's latest buzzer state, replayed into the backend by `resync()`.
    private var wageringLimits: [UUID: Int]?
    private var wageringWagers: [UUID: Int] = [:]
    private var answeringWindow: FinalAnswerWindow = .closed
    private var answeringAnswers: [UUID: String] = [:]
    private var latestScores: [UUID: Int] = [:]
    private var latestMode: BuzzerMode = .disabled
    private var latestTeams: [BuzzerTeam] = []

    private var everClaimedTeamIDs: Set<UUID> = []
    private var eventObserverTask: Task<Void, Never>?

    init(backend: any BuzzerBackend = EmbeddedBuzzerBackend(), defaults: UserDefaults = .standard) {
        self.backend = backend
        self.backendFactory = nil
        self.defaults = defaults
        observeStatus(of: backend)
    }

    /// The app's own: picks the built-in or the external backend from Settings at each start.
    init(fromSettings defaults: UserDefaults, tokenStore: any HostTokenStore = KeychainHostTokenStore()) {
        let factory: (UserDefaults) -> any BuzzerBackend = { defaults in
            switch AppSettings.buzzerServerMode(defaults) {
            case .builtIn: EmbeddedBuzzerBackend(defaults: defaults)
            case .external: RemoteBuzzerBackend(defaults: defaults, tokenStore: tokenStore)
            }
        }
        let initial = factory(defaults)
        self.backend = initial
        self.backendFactory = factory
        self.defaults = defaults
        observeStatus(of: initial)
    }

    private func observeStatus(of backend: any BuzzerBackend) {
        backend.onStatusChange = { [weak self] status in self?.handle(status) }
    }

    /// A connection change from an external backend (#104).
    private func handle(_ status: BuzzerConnectionStatus) {
        switch status {
        case .connected:
            let wasReconnecting = isReconnecting
            isReconnecting = false
            // The server may be a different room than before the drop: replay the game into it.
            if wasReconnecting { Task { await resync() } }
        case .reconnecting:
            guard isRunning else { return }
            isReconnecting = true
        case let .ended(reason):
            log.state("Buzzer room ended: \(reason)")
            isReconnecting = false
            startError = String(localized: "control.buzzer.error.room_ended")
            isRunning = false
        }
    }

    // MARK: - Teams

    /// Pushes the app's current teams to the phones (and remembers them for a
    /// server that has not started yet).
    func syncTeams(_ teams: [BuzzerTeam]) async {
        latestTeams = teams
        await backend.updateTeams(teams)
    }

    /// Pushes team scores to the server; they break ties between simultaneous buzzes.
    func syncScores(_ scores: [UUID: Int]) async {
        latestScores = scores
        await backend.updateScores(scores)
    }

    // MARK: - Buzzer control

    /// Sets up the buzzers for the screen being shown. Clears lockouts.
    func setMode(_ mode: BuzzerMode) async {
        log.change("BuzzerState.mode", from: latestMode, to: mode)
        latestMode = mode
        await backend.setBuzzerMode(mode)
    }

    /// Locks the team out for the question and re-arms the other teams.
    func teamAnsweredWrong(_ teamID: UUID) async {
        log.state("Buzzer lockout: \(teamLabel(teamID)) answered wrong; other teams re-armed", team: teamName(teamID))
        await backend.markWrong(teamID: teamID)
    }

    func teamAnsweredCorrect() async {
        log.state("Buzzers stopped: correct answer")
        await backend.markCorrect()
    }

    /// Starts the answering team's response countdown on every phone, or stops
    /// it when `teamID` is nil. Phones count down on their own.
    func setResponseTimer(teamID: UUID?, seconds: TimeInterval) async {
        if let teamID {
            log.state("Phones' response countdown started: \(teamLabel(teamID)), \(Int(seconds))s", team: teamName(teamID))
        } else {
            log.state("Phones' response countdown stopped")
        }
        await backend.setResponseTimer(teamID: teamID, seconds: seconds)
    }

    // MARK: - Final Macpardy wagers

    /// Opens wagering on the phones. `limits` maps each team to its max wager
    /// (its score); teams at zero or below are excluded.
    func openWagering(limits: [UUID: Int], wagers: [UUID: Int]) async {
        if limits != wageringLimits {
            let summary = limits.map { "\(teamLabel($0.key)) max $\($0.value)" }.sorted().joined(separator: ", ")
            log.state("Final wagering open on phones: \(summary)")
        }
        wageringLimits = limits
        wageringWagers = wagers
        await backend.openWagering(limits: limits, wagers: wagers)
    }

    func closeWagering() async {
        if wageringLimits != nil { log.state("Final wagering closed on phones") }
        wageringLimits = nil
        wageringWagers = [:]
        await backend.closeWagering()
    }

    /// Pushes a wager the host entered or edited (nil = cleared) to the team's phone.
    func hostSetWager(teamID: UUID, amount: Int?) async {
        log.change("\(teamLabel(teamID)) phone wager (host)", from: wageringWagers[teamID], to: amount, team: teamName(teamID))
        wageringWagers[teamID] = amount
        await backend.setWager(teamID: teamID, amount: amount)
    }

    // MARK: - Final Macpardy answers

    /// Opens (Final clue up), locks (correct response revealed) or closes Final
    /// answering on the phones. `answers` are the answers already stored in the game.
    func setAnswering(_ window: FinalAnswerWindow, answers: [UUID: String]) async {
        log.change("BuzzerState.finalAnswering", from: answeringWindow, to: window)
        answeringWindow = window
        answeringAnswers = window == .closed ? [:] : answers
        await backend.setAnswering(window, answers: answers)
    }

    /// Frees a team's slot and disconnects its phone with "Removed by host".
    func removePhone(forTeam teamID: UUID) async {
        log.state("Host removed the phone of \(teamLabel(teamID))", team: teamName(teamID))
        await backend.removePhone(forTeam: teamID)
    }

    // MARK: - Lifecycle

    /// Starts a new session on the backend (new Game PIN), then resyncs it.
    /// Safe to call from a `Task { }` in a `.task` or `.onChange` modifier.
    /// Does nothing (beyond stopping a running server) while buzzers are
    /// turned off in Settings.
    func startServer() async {
        // Stop any existing server first.
        await stopServer()

        startError = nil

        if let backendFactory, AppSettings.buzzersEnabled(defaults) {
            backend = backendFactory(defaults)
            observeStatus(of: backend)
        }

        guard AppSettings.buzzersEnabled(defaults) else {
            log.info("Buzzer server not started: buzzers are turned off in Settings")
            return
        }

        let session: BuzzerBackendSession
        do {
            session = try await backend.start()
        } catch {
            // The backend logged the details.
            startError = error.localizedDescription
            return
        }

        joinCode = session.joinCode
        serverURL = session.joinURL
        baseURL = session.baseURL
        isRunning = true

        await resync()

        eventObserverTask = Task { [weak self, events = session.events] in
            for await event in events {
                guard let self else { return }
                self.handle(event)
            }
        }
    }

    /// Stops the server and clears all state.
    func stopServer() async {
        eventObserverTask?.cancel()
        eventObserverTask = nil
        firstBuzzTeamID = nil
        await backend.stop()
        isReconnecting = false
        isRunning = false
        joinCode = ""
        serverURL = nil
        baseURL = nil
        connectedClientCount = 0
        claimedTeamIDs = []
        everClaimedTeamIDs = []
        isJoinScreenOnDisplay = false
    }

    /// Sends the game's current buzzer state to a freshly started backend:
    /// teams, scores, buzzer mode, Final wagering (when open) and answering.
    /// Also runs when the Mac takes its room back on a self-hosted server (#104).
    func resync() async {
        await backend.updateTeams(latestTeams)
        await backend.updateScores(latestScores)
        await backend.setBuzzerMode(latestMode)
        if let limits = wageringLimits {
            await backend.openWagering(limits: limits, wagers: wageringWagers)
        }
        await backend.setAnswering(answeringWindow, answers: answeringAnswers)
    }

    /// Broadcasts the current game phase to all connected phones.
    func broadcastPhase(_ phase: String) async {
        await backend.broadcastPhase(phase)
    }

    /// Applies one thing the room reported.
    private func handle(_ event: BuzzerRoomEvent) {
        switch event {
        case .claimedTeams(let claimed):
            claimedTeamIDs = claimed
            everClaimedTeamIDs.formUnion(claimed)
        case .firstBuzz(let teamID):
            firstBuzzTeamID = teamID
        case .wager(let submission):
            log.state("Final wager from phone: \(teamLabel(submission.teamID)) $\(submission.amount)", team: teamName(submission.teamID))
            wageringWagers[submission.teamID] = submission.amount
            onWagerSubmitted?(submission)
        case .answer(let submission):
            // Length only: Final answers are never logged.
            log.state(
                "Final answer from phone: \(teamLabel(submission.teamID)) (\(LogValue.length(of: submission.answer)))",
                team: teamName(submission.teamID)
            )
            answeringAnswers[submission.teamID] = submission.answer
            onAnswerSubmitted?(submission)
        case .connectedCount(let count):
            connectedClientCount = count
        case .failed(let message):
            // The listener failed after it started.
            startError = message
            isRunning = false
        }
    }

    /// A team's name, for the log's team filter.
    private func teamName(_ teamID: UUID) -> String {
        latestTeams.first { $0.id == teamID }?.name ?? "Unknown team"
    }

    /// A team's name quoted, for log messages.
    private func teamLabel(_ teamID: UUID) -> String {
        "'\(teamName(teamID))'"
    }
}

extension BuzzerTeam {
    /// The phone-facing view of a game team. `claimed` is filled in by the server.
    init(team: Team) {
        self.init(id: team.id, name: team.name, color: team.color, claimed: false)
    }
}

