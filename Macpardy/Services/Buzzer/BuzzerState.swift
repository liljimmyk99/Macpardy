//
//  BuzzerState.swift
//  Macpardy
//
//  @Observable bridge between the buzzer room (and its server) and SwiftUI views.
//  Inject this into the environment via MacpardyApp.
//

import BuzzerCore
import Foundation
import Network

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

    private var wageringLimits: [UUID: Int]?
    private var wageringWagers: [UUID: Int] = [:]
    private var answeringWindow: FinalAnswerWindow = .closed
    private var answeringAnswers: [UUID: String] = [:]

    private var latestScores: [UUID: Int] = [:]
    private var latestMode: BuzzerMode = .disabled
    private var everClaimedTeamIDs: Set<UUID> = []
    private var latestTeams: [BuzzerTeam] = []
    private var server: BuzzerServer?
    /// The running server's room, which the game calls below go to.
    private var room: BuzzerRoom?
    private var eventObserverTask: Task<Void, Never>?
    private var pathMonitor: NWPathMonitor?
    private var lastPathDescription: String?

    // MARK: - Teams

    /// Pushes the app's current teams to the server (and remembers them for a
    /// server that has not started yet).
    func syncTeams(_ teams: [BuzzerTeam]) async {
        latestTeams = teams
        await room?.updateTeams(teams)
    }

    /// Pushes team scores to the server; they break ties between simultaneous buzzes.
    func syncScores(_ scores: [UUID: Int]) async {
        latestScores = scores
        await room?.updateScores(scores)
    }

    // MARK: - Buzzer control

    /// Sets up the buzzers for the screen being shown. Clears lockouts.
    func setMode(_ mode: BuzzerMode) async {
        log.change("BuzzerState.mode", from: latestMode, to: mode)
        latestMode = mode
        await room?.setBuzzerMode(mode)
    }

    /// Locks the team out for the question and re-arms the other teams.
    func teamAnsweredWrong(_ teamID: UUID) async {
        log.state("Buzzer lockout: \(teamLabel(teamID)) answered wrong; other teams re-armed", team: teamName(teamID))
        await room?.markWrong(teamID: teamID)
    }

    func teamAnsweredCorrect() async {
        log.state("Buzzers stopped: correct answer")
        await room?.markCorrect()
    }

    /// Starts the answering team's response countdown on every phone, or stops
    /// it when `teamID` is nil. Phones count down on their own.
    func setResponseTimer(teamID: UUID?, seconds: TimeInterval) async {
        if let teamID {
            log.state("Phones' response countdown started: \(teamLabel(teamID)), \(Int(seconds))s", team: teamName(teamID))
        } else {
            log.state("Phones' response countdown stopped")
        }
        await room?.setResponseTimer(teamID: teamID, seconds: seconds)
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
        await room?.openWagering(limits: limits, wagers: wagers)
    }

    func closeWagering() async {
        if wageringLimits != nil { log.state("Final wagering closed on phones") }
        wageringLimits = nil
        wageringWagers = [:]
        await room?.closeWagering()
    }

    /// Pushes a wager the host entered or edited (nil = cleared) to the team's phone.
    func hostSetWager(teamID: UUID, amount: Int?) async {
        log.change("\(teamLabel(teamID)) phone wager (host)", from: wageringWagers[teamID], to: amount, team: teamName(teamID))
        wageringWagers[teamID] = amount
        await room?.setWager(teamID: teamID, amount: amount)
    }

    // MARK: - Final Macpardy answers

    /// Opens (Final clue up), locks (correct response revealed) or closes Final
    /// answering on the phones. `answers` are the answers already stored in the game.
    func setAnswering(_ window: FinalAnswerWindow, answers: [UUID: String]) async {
        log.change("BuzzerState.finalAnswering", from: answeringWindow, to: window)
        answeringWindow = window
        answeringAnswers = window == .closed ? [:] : answers
        await room?.setAnswering(window, answers: answers)
    }

    /// Frees a team's slot and disconnects its phone with "Removed by host".
    func removePhone(forTeam teamID: UUID) async {
        log.state("Host removed the phone of \(teamLabel(teamID))", team: teamName(teamID))
        await room?.removePhone(forTeam: teamID)
    }

    // MARK: - Lifecycle

    /// Generates a new join code, resolves the local IP, and starts the server.
    /// Safe to call from a `Task { }` in a `.task` or `.onChange` modifier.
    /// Does nothing (beyond stopping a running server) while buzzers are
    /// turned off in Settings.
    func startServer() async {
        // Stop any existing server first.
        await stopServer()

        startError = nil

        guard AppSettings.buzzersEnabled() else {
            AppLogger.buzzer.info("Buzzer server not started: buzzers are turned off in Settings")
            return
        }

        // Resolve local IP before starting so the URL is ready immediately.
        let addresses = LocalNetworkInterfaces.current()
        guard let address = LocalNetworkInterfaces.preferred(from: addresses) else {
            startError = "No local network address found. Connect to Wi-Fi or Ethernet."
            let candidates = addresses.isEmpty ? "none" : addresses.map(\.description).joined(separator: ", ")
            AppLogger.network.error("Buzzer server not started: no usable local IPv4 address. Interfaces: \(candidates)")
            return
        }
        let ip = address.ip

        let code = JoinCodeGenerator.generate()
        let port = AppSettings.buzzerPort()
        guard let urls = Self.joinURLs(ip: ip, port: port, code: code) else {
            startError = "No local network address found. Connect to Wi-Fi or Ethernet."
            AppLogger.buzzer.error("Buzzer server not started: couldn't build a URL for \(ip)")
            return
        }
        let newRoom = BuzzerRoom(joinCode: code, logger: AppBuzzerLogger())
        let newServer = BuzzerServer(room: newRoom, port: port)

        do {
            try await newServer.start()
            self.server = newServer
            self.room = newRoom
            self.joinCode = code
            self.serverURL = urls.join
            self.baseURL = urls.base
            self.isRunning = true
            let others = addresses.filter { $0 != address }.map(\.description)
            AppLogger.buzzer.info(
                "Buzzer server started at \(urls.base.absoluteString) on \(address.interface)"
                    + (others.isEmpty ? "" : " (other interfaces: \(others.joined(separator: ", ")))")
            )
            startPathMonitor()

            await newRoom.updateTeams(latestTeams)
            await newRoom.updateScores(latestScores)
            await newRoom.setBuzzerMode(latestMode)
            if let limits = wageringLimits {
                await newRoom.openWagering(limits: limits, wagers: wageringWagers)
            }
            await newRoom.setAnswering(answeringWindow, answers: answeringAnswers)

            eventObserverTask = Task { [weak self, events = newRoom.events] in
                for await event in events {
                    guard let self else { return }
                    self.handle(event)
                }
            }
        } catch {
            startError = String(localized: "control.buzzer.error.start_failed \(Int(port)) \(error.localizedDescription)")
            AppLogger.buzzer.error("Failed to start the buzzer server on port \(port): \(error)")
        }
    }

    /// Stops the server and clears all state.
    func stopServer() async {
        stopPathMonitor()
        eventObserverTask?.cancel()
        eventObserverTask = nil
        firstBuzzTeamID = nil
        await server?.stop()
        server = nil
        room = nil
        isRunning = false
        joinCode = ""
        serverURL = nil
        baseURL = nil
        connectedClientCount = 0
        claimedTeamIDs = []
        everClaimedTeamIDs = []
        isJoinScreenOnDisplay = false
    }

    /// Broadcasts the current game phase to all connected phones.
    func broadcastPhase(_ phase: String) async {
        await room?.broadcast(.state(phase: phase))
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

    // MARK: - Join URLs

    /// The bare page address and the full join link for a server at `ip:port`.
    nonisolated static func joinURLs(ip: String, port: UInt16, code: String) -> (base: URL, join: URL)? {
        guard let base = URL(string: "http://\(ip):\(port)"),
              let join = URL(string: "http://\(ip):\(port)?code=\(code)") else { return nil }
        return (base, join)
    }

    // MARK: - Mac network changes

    /// Logs changes to the Mac's own network while the server runs. A Mac
    /// Wi-Fi blip drops every phone at once; this line makes that obvious.
    private func startPathMonitor() {
        stopPathMonitor()
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            let description = NetworkPathSummary.describe(path)
            Task { @MainActor in self?.pathChanged(to: description) }
        }
        monitor.start(queue: .global(qos: .utility))
        pathMonitor = monitor
    }

    private func stopPathMonitor() {
        pathMonitor?.cancel()
        pathMonitor = nil
        lastPathDescription = nil
    }

    private func pathChanged(to description: String) {
        guard pathMonitor != nil, description != lastPathDescription else { return }
        if let previous = lastPathDescription {
            AppLogger.network.warning("Mac network changed: \(previous) → \(description)")
        } else {
            AppLogger.network.info("Mac network: \(description)")
        }
        lastPathDescription = description
    }
}

extension BuzzerTeam {
    /// The phone-facing view of a game team. `claimed` is filled in by the server.
    init(team: Team) {
        self.init(id: team.id, name: team.name, color: team.color, claimed: false)
    }
}

