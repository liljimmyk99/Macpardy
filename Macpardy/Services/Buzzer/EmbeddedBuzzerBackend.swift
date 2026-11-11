//
//  EmbeddedBuzzerBackend.swift
//  Macpardy
//
//  The built-in buzzer server (#102): a `BuzzerRoom` behind the
//  Network.framework transport (`BuzzerServer`), for phones on the same
//  network as the Mac.
//
//  Responsibilities
//  ─────────────────
//  • Picks the Mac's local IPv4 address and builds the page and join URLs
//  • Generates the Game PIN (a self-hosted server will own its own)
//  • Reads the port from Settings
//  • Starts / stops the room and its listener
//  • Logs changes to the Mac's own network while running
//

import BuzzerCore
import Foundation
import Network

final class EmbeddedBuzzerBackend: BuzzerBackend {

    /// The built-in server is always reachable; nothing to report.
    var onStatusChange: ((BuzzerConnectionStatus) -> Void)?

    private let defaults: UserDefaults
    private var server: BuzzerServer?
    /// The running server's room, which the game calls below go to.
    private var room: BuzzerRoom?
    private var pathMonitor: NWPathMonitor?
    private var lastPathDescription: String?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Lifecycle

    func start() async throws -> BuzzerBackendSession {
        await stop()

        // Resolve the local IP before starting so the URL is ready immediately.
        let addresses = LocalNetworkInterfaces.current()
        guard let address = LocalNetworkInterfaces.preferred(from: addresses) else {
            let candidates = addresses.isEmpty ? "none" : addresses.map(\.description).joined(separator: ", ")
            AppLogger.network.error("Buzzer server not started: no usable local IPv4 address. Interfaces: \(candidates)")
            throw BuzzerBackendError.noLocalAddress
        }
        let ip = address.ip

        let code = JoinCodeGenerator.generate()
        let port = AppSettings.buzzerPort(defaults)
        guard let urls = Self.joinURLs(ip: ip, port: port, code: code) else {
            AppLogger.buzzer.error("Buzzer server not started: couldn't build a URL for \(ip)")
            throw BuzzerBackendError.noLocalAddress
        }
        let newRoom = BuzzerRoom(joinCode: code, logger: AppBuzzerLogger())
        let newServer = BuzzerServer(room: newRoom, port: port)

        do {
            try await newServer.start()
        } catch {
            AppLogger.buzzer.error("Failed to start the buzzer server on port \(port): \(error)")
            throw BuzzerBackendError.listenerFailed(port: port, underlying: error)
        }

        server = newServer
        room = newRoom
        let others = addresses.filter { $0 != address }.map(\.description)
        AppLogger.buzzer.info(
            "Buzzer server started at \(urls.base.absoluteString) on \(address.interface)"
                + (others.isEmpty ? "" : " (other interfaces: \(others.joined(separator: ", ")))")
        )
        startPathMonitor()
        return BuzzerBackendSession(joinCode: code, baseURL: urls.base, joinURL: urls.join, events: newRoom.events)
    }

    func stop() async {
        stopPathMonitor()
        await server?.stop()
        server = nil
        room = nil
    }

    // MARK: - Game → phones

    func updateTeams(_ teams: [BuzzerTeam]) async { await room?.updateTeams(teams) }
    func updateScores(_ scores: [UUID: Int]) async { await room?.updateScores(scores) }
    func setBuzzerMode(_ mode: BuzzerMode) async { await room?.setBuzzerMode(mode) }
    func markWrong(teamID: UUID) async { await room?.markWrong(teamID: teamID) }
    func markCorrect() async { await room?.markCorrect() }

    func setResponseTimer(teamID: UUID?, seconds: TimeInterval) async {
        await room?.setResponseTimer(teamID: teamID, seconds: seconds)
    }

    func openWagering(limits: [UUID: Int], wagers: [UUID: Int]) async {
        await room?.openWagering(limits: limits, wagers: wagers)
    }

    func closeWagering() async { await room?.closeWagering() }
    func setWager(teamID: UUID, amount: Int?) async { await room?.setWager(teamID: teamID, amount: amount) }

    func setAnswering(_ window: FinalAnswerWindow, answers: [UUID: String]) async {
        await room?.setAnswering(window, answers: answers)
    }

    func removePhone(forTeam teamID: UUID) async { await room?.removePhone(forTeam: teamID) }
    func broadcastPhase(_ phase: String) async { await room?.broadcast(.state(phase: phase)) }

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
