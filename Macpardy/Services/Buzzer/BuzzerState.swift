//
//  BuzzerState.swift
//  Macpardy
//
//  @Observable bridge between the BuzzerServer actor and SwiftUI views.
//  Inject this into the environment via MacpardyApp.
//

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
    private(set) var connectedClientCount: Int = 0

    /// Whether the server is currently running.
    private(set) var isRunning: Bool = false

    /// Human-readable reason the server could not start (or stopped), if any.
    private(set) var startError: String?

    /// Teams that currently have a phone attached.
    private(set) var claimedTeamIDs: Set<UUID> = []

    /// Teams that had a phone at some point this session but have none now.
    /// Teams that never had a phone are not listed, so a game without buzzers
    /// shows no warnings.
    var disconnectedTeamIDs: Set<UUID> { everClaimedTeamIDs.subtracting(claimedTeamIDs) }

    /// The team that buzzed in first and is answering, if any.
    private(set) var firstBuzzTeamID: UUID?

    /// Called on the main actor when a phone submits a valid Final wager.
    var onWagerSubmitted: ((WagerSubmission) -> Void)?

    /// Called on the main actor when a phone saves a Final answer.
    var onAnswerSubmitted: ((AnswerSubmission) -> Void)?

    /// Whether the toolbar's Buzzers popover is open. Lives here so the Game menu can open it.
    var isPopoverPresented = false

    /// Whether the Display shows the join screen (QR code, address, Game PIN) over
    /// the current phase (#83). Turned off when the phase changes or the server stops.
    var isJoinScreenOnDisplay = false

    // MARK: - Private

    private var wagerObserverTask: Task<Void, Never>?
    private var wageringLimits: [UUID: Int]?
    private var wageringWagers: [UUID: Int] = [:]
    private var answerObserverTask: Task<Void, Never>?
    private var answeringWindow: FinalAnswerWindow = .closed
    private var answeringAnswers: [UUID: String] = [:]

    private var latestScores: [UUID: Int] = [:]
    private var latestMode: BuzzerMode = .disabled
    private var firstBuzzObserverTask: Task<Void, Never>?
    private var everClaimedTeamIDs: Set<UUID> = []
    private var latestTeams: [BuzzerTeam] = []
    private var server: BuzzerServer?
    private var countObserverTask: Task<Void, Never>?
    private var claimedObserverTask: Task<Void, Never>?
    private var failureObserverTask: Task<Void, Never>?
    private var pathMonitor: NWPathMonitor?
    private var lastPathDescription: String?

    // MARK: - Teams

    /// Pushes the app's current teams to the server (and remembers them for a
    /// server that has not started yet).
    func syncTeams(_ teams: [BuzzerTeam]) async {
        latestTeams = teams
        await server?.updateTeams(teams)
    }

    /// Pushes team scores to the server; they break ties between simultaneous buzzes.
    func syncScores(_ scores: [UUID: Int]) async {
        latestScores = scores
        await server?.updateScores(scores)
    }

    // MARK: - Buzzer control

    /// Sets up the buzzers for the screen being shown. Clears lockouts.
    func setMode(_ mode: BuzzerMode) async {
        latestMode = mode
        await server?.setBuzzerMode(mode)
    }

    /// Locks the team out for the question and re-arms the other teams.
    func teamAnsweredWrong(_ teamID: UUID) async {
        await server?.markWrong(teamID: teamID)
    }

    func teamAnsweredCorrect() async {
        await server?.markCorrect()
    }

    /// Starts the answering team's response countdown on every phone, or stops
    /// it when `teamID` is nil. Phones count down on their own.
    func setResponseTimer(teamID: UUID?, seconds: TimeInterval) async {
        await server?.setResponseTimer(teamID: teamID, seconds: seconds)
    }

    // MARK: - Final Macpardy wagers

    /// Opens wagering on the phones. `limits` maps each team to its max wager
    /// (its score); teams at zero or below are excluded.
    func openWagering(limits: [UUID: Int], wagers: [UUID: Int]) async {
        wageringLimits = limits
        wageringWagers = wagers
        await server?.openWagering(limits: limits, wagers: wagers)
    }

    func closeWagering() async {
        wageringLimits = nil
        wageringWagers = [:]
        await server?.closeWagering()
    }

    /// Pushes a wager the host entered or edited (nil = cleared) to the team's phone.
    func hostSetWager(teamID: UUID, amount: Int?) async {
        wageringWagers[teamID] = amount
        await server?.setWager(teamID: teamID, amount: amount)
    }

    // MARK: - Final Macpardy answers

    /// Opens (Final clue up), locks (correct response revealed) or closes Final
    /// answering on the phones. `answers` are the answers already stored in the game.
    func setAnswering(_ window: FinalAnswerWindow, answers: [UUID: String]) async {
        answeringWindow = window
        answeringAnswers = window == .closed ? [:] : answers
        await server?.setAnswering(window, answers: answers)
    }

    /// Frees a team's slot and disconnects its phone with "Removed by host".
    func removePhone(forTeam teamID: UUID) async {
        await server?.removePhone(forTeam: teamID)
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
        let newServer = BuzzerServer(joinCode: code, port: port)

        do {
            try await newServer.start()
            self.server = newServer
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

            await newServer.updateTeams(latestTeams)
            await newServer.updateScores(latestScores)
            await newServer.setBuzzerMode(latestMode)
            if let limits = wageringLimits {
                await newServer.openWagering(limits: limits, wagers: wageringWagers)
            }
            await newServer.setAnswering(answeringWindow, answers: answeringAnswers)

            wagerObserverTask = Task { [weak self, stream = newServer.wagerStream] in
                for await submission in stream {
                    guard let self else { return }
                    self.wageringWagers[submission.teamID] = submission.amount
                    self.onWagerSubmitted?(submission)
                }
            }

            answerObserverTask = Task { [weak self, stream = newServer.answerStream] in
                for await submission in stream {
                    guard let self else { return }
                    self.answeringAnswers[submission.teamID] = submission.answer
                    self.onAnswerSubmitted?(submission)
                }
            }

            firstBuzzObserverTask = Task { [weak self, stream = newServer.firstBuzzStream] in
                for await teamID in stream {
                    guard let self else { return }
                    self.firstBuzzTeamID = teamID
                }
            }

            // Track which teams have a phone attached.
            claimedObserverTask = Task { [weak self, stream = newServer.claimedTeamsStream] in
                for await claimed in stream {
                    guard let self else { return }
                    self.claimedTeamIDs = claimed
                    self.everClaimedTeamIDs.formUnion(claimed)
                }
            }

            // Observe connected-client count changes from the server.
            countObserverTask = Task { [weak self, stream = newServer.connectedCountStream] in
                for await count in stream {
                    guard let self else { return }
                    self.connectedClientCount = count
                }
            }

            // Surface listener failures that happen after startup.
            failureObserverTask = Task { [weak self, stream = newServer.listenerFailureStream] in
                for await message in stream {
                    guard let self else { return }
                    self.startError = message
                    self.isRunning = false
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
        countObserverTask?.cancel()
        countObserverTask = nil
        claimedObserverTask?.cancel()
        claimedObserverTask = nil
        failureObserverTask?.cancel()
        failureObserverTask = nil
        firstBuzzObserverTask?.cancel()
        firstBuzzObserverTask = nil
        wagerObserverTask?.cancel()
        wagerObserverTask = nil
        answerObserverTask?.cancel()
        answerObserverTask = nil
        firstBuzzTeamID = nil
        await server?.stop()
        server = nil
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
        await server?.broadcast(.state(phase: phase))
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

