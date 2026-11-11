//
//  RemoteBuzzerBackend.swift
//  Macpardy
//
//  The self-hosted buzzer server as seen by `BuzzerState` (#104). The Mac opens a WebSocket
//  to `wss://<server>/host`, authenticates with the host token (`hello`), and gets the Game
//  PIN back. Game changes go out as `HostCommand`s; the server's `HostEvent`s come back as
//  `BuzzerRoomEvent`s.
//
//  If the connection drops, the backend reconnects with backoff for as long as the server
//  keeps the room (its grace period), taking the room back with the resume token. It then
//  reports `.connected` and `BuzzerState` resyncs the game. When the grace period runs out
//  the room is reported as ended.
//
//  The host token only travels over `wss://` (loopback may use `ws://`, for trying a server
//  on this Mac) and is never logged.
//

import BuzzerCore
import BuzzerHostProtocol
import Foundation

final class RemoteBuzzerBackend: BuzzerBackend {

    var onStatusChange: ((BuzzerConnectionStatus) -> Void)?

    private let defaults: UserDefaults
    private let tokenStore: any HostTokenStore
    private let makeSocket: HostSocketFactory
    /// Waits between reconnect attempts. Injected so tests don't wait.
    private let sleep: @Sendable (TimeInterval) async -> Void
    private let now: () -> Date
    private let clientName: String

    private var socket: (any HostSocket)?
    private var runTask: Task<Void, Never>?
    private var watchdogTask: Task<Void, Never>?
    private var continuation: AsyncStream<BuzzerRoomEvent>.Continuation?

    private var hostURL: URL?
    private var hostToken = ""
    private var resumeToken: String?
    private var gracePeriod = BuzzerHostConstants.defaultGracePeriod
    private var isConnected = false
    private var lastReceived = Date()

    /// First wait between reconnect attempts, doubled up to `maxBackoff`.
    nonisolated static let initialBackoff: TimeInterval = 1
    nonisolated static let maxBackoff: TimeInterval = 5

    init(
        defaults: UserDefaults = .standard,
        tokenStore: any HostTokenStore = KeychainHostTokenStore(),
        socketFactory: @escaping HostSocketFactory = { URLSessionHostSocket(url: $0) },
        sleep: @escaping @Sendable (TimeInterval) async -> Void = { try? await Task.sleep(for: .seconds($0)) },
        now: @escaping () -> Date = Date.init,
        clientName: String = RemoteBuzzerBackend.defaultClientName
    ) {
        self.defaults = defaults
        self.tokenStore = tokenStore
        self.makeSocket = socketFactory
        self.sleep = sleep
        self.now = now
        self.clientName = clientName
    }

    nonisolated static var defaultClientName: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        return "Macpardy/\(version)"
    }

    // MARK: - Lifecycle

    func start() async throws -> BuzzerBackendSession {
        await stop()

        guard let baseURL = AppSettings.externalServerURL(defaults),
              let token = tokenStore.token(), !token.isEmpty,
              let url = Self.hostURL(for: baseURL) else {
            AppLogger.buzzer.error("External buzzer server not started: the server URL or host token isn't set")
            throw BuzzerBackendError.notConfigured
        }
        hostURL = url
        hostToken = token
        resumeToken = nil

        AppLogger.buzzer.info("Connecting to the external buzzer server at \(baseURL.host ?? "?")")
        let (opened, newSocket) = try await open(resumeToken: nil)

        guard let join = Self.joinURL(base: baseURL, code: opened.code) else {
            newSocket.close()
            throw BuzzerBackendError.unreachable(underlying: "bad server URL")
        }
        resumeToken = opened.resumeToken
        gracePeriod = Self.clampedGrace(opened.gracePeriod)
        socket = newSocket
        isConnected = true
        lastReceived = now()

        let (events, newContinuation) = AsyncStream<BuzzerRoomEvent>.makeStream()
        continuation = newContinuation
        AppLogger.buzzer.info("External buzzer room open (grace period \(Int(gracePeriod))s)")

        runTask = Task { [weak self] in await self?.run(first: newSocket) }
        startWatchdog()
        return BuzzerBackendSession(joinCode: opened.code, baseURL: baseURL, joinURL: join, events: events)
    }

    func stop() async {
        runTask?.cancel()
        runTask = nil
        watchdogTask?.cancel()
        watchdogTask = nil
        if isConnected, let socket {
            try? await socket.send(Self.encode(.closeRoom))
        }
        socket?.close()
        socket = nil
        isConnected = false
        continuation?.finish()
        continuation = nil
        resumeToken = nil
        hostToken = ""
    }

    // MARK: - Game → phones

    func updateTeams(_ teams: [BuzzerTeam]) async { await send(.updateTeams(teams)) }
    func updateScores(_ scores: [UUID: Int]) async { await send(.updateScores(scores)) }
    func setBuzzerMode(_ mode: BuzzerMode) async { await send(.setBuzzerMode(mode)) }
    func markWrong(teamID: UUID) async { await send(.markWrong(teamID: teamID)) }
    func markCorrect() async { await send(.markCorrect) }

    func setResponseTimer(teamID: UUID?, seconds: TimeInterval) async {
        await send(.setResponseTimer(teamID: teamID, seconds: seconds))
    }

    func openWagering(limits: [UUID: Int], wagers: [UUID: Int]) async {
        await send(.openWagering(limits: limits, wagers: wagers))
    }

    func closeWagering() async { await send(.closeWagering) }
    func setWager(teamID: UUID, amount: Int?) async { await send(.setWager(teamID: teamID, amount: amount)) }

    func setAnswering(_ window: FinalAnswerWindow, answers: [UUID: String]) async {
        await send(.setAnswering(window, answers: answers))
    }

    func removePhone(forTeam teamID: UUID) async { await send(.removePhone(teamID: teamID)) }
    func broadcastPhase(_ phase: String) async { await send(.broadcastPhase(phase)) }

    /// Commands sent while the connection is down are dropped; `BuzzerState` resyncs afterwards.
    private func send(_ command: HostCommand) async {
        guard isConnected, let socket else { return }
        do {
            try await socket.send(Self.encode(command))
        } catch {
            AppLogger.buzzer.debug("Host command '\(command.logDescription)' not sent: \(error.localizedDescription)")
        }
    }

    // MARK: - URLs

    /// `https://host/base` → `wss://host/base/host`.
    nonisolated static func hostURL(for base: URL) -> URL? {
        guard var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else { return nil }
        components.scheme = components.scheme == "http" ? "ws" : "wss"
        components.path += BuzzerHostConstants.hostPath
        return components.url
    }

    /// The link phones open: the entered address with `?code=`.
    nonisolated static func joinURL(base: URL, code: String) -> URL? {
        URL(string: base.absoluteString + "?code=\(code)")
    }

    nonisolated static func clampedGrace(_ seconds: TimeInterval) -> TimeInterval {
        min(max(seconds, BuzzerHostConstants.gracePeriodRange.lowerBound), BuzzerHostConstants.gracePeriodRange.upperBound)
    }

    // MARK: - Connecting

    /// Opens a socket, sends `hello` and waits for the room. Throws a `BuzzerBackendError`.
    private func open(resumeToken: String?) async throws -> (RoomOpened, any HostSocket) {
        guard let hostURL else { throw BuzzerBackendError.notConfigured }
        let candidate = makeSocket(hostURL)
        do {
            let opened = try await Self.withTimeout(BuzzerHostConstants.helloTimeout) { [self] in
                try await candidate.connect()
                let hello = HostHello(token: hostToken, resumeToken: resumeToken, client: clientName)
                try await candidate.send(Self.encode(.hello(hello)))
                return try await awaitRoomOpened(on: candidate)
            }
            return (opened, candidate)
        } catch {
            candidate.close()
            throw Self.mapped(error)
        }
    }

    private func awaitRoomOpened(on socket: any HostSocket) async throws -> RoomOpened {
        while true {
            let text = try await socket.receive()
            guard let event = Self.decode(text) else { continue }
            switch event {
            case let .roomOpened(opened):
                guard BuzzerHostConstants.isSupported(version: opened.hostProtocolVersion) else {
                    throw BuzzerBackendError.unsupportedVersion
                }
                return opened
            case let .error(error) where error.code.isFatal:
                throw Self.error(for: error.code)
            case .ping:
                try await socket.send(Self.encode(.pong))
            default:
                continue
            }
        }
    }

    private nonisolated static func error(for code: HostError.Code) -> BuzzerBackendError {
        switch code {
        case .badToken: .badToken
        case .rateLimited: .rateLimited
        case .unsupportedVersion: .unsupportedVersion
        case .serverFull: .serverFull
        case .roomNotFound: .roomNotFound
        case .helloRequired, .badMessage: .unreachable(underlying: "unexpected reply from the server")
        }
    }

    private nonisolated static func mapped(_ error: any Error) -> BuzzerBackendError {
        if let known = error as? BuzzerBackendError { return known }
        return .unreachable(underlying: error.localizedDescription)
    }

    private nonisolated static func withTimeout<T: Sendable>(
        _ seconds: TimeInterval,
        _ operation: @escaping @MainActor @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(for: .seconds(seconds))
                throw BuzzerBackendError.unreachable(underlying: "no answer from the server")
            }
            defer { group.cancelAll() }
            return try await group.next()!
        }
    }

    // MARK: - Receiving and reconnecting

    private func run(first: any HostSocket) async {
        var current = first
        while !Task.isCancelled {
            guard await listen(on: current) else { return }
            guard let next = await reconnect() else { return }
            current = next
        }
    }

    /// Reads until the connection drops (true) or the room ends (false).
    private func listen(on socket: any HostSocket) async -> Bool {
        while true {
            let text: String
            do {
                text = try await socket.receive()
            } catch {
                guard !Task.isCancelled else { return false }
                AppLogger.buzzer.warning("Lost the connection to the external buzzer server: \(error.localizedDescription)")
                return true
            }
            guard !Task.isCancelled else { return false }
            lastReceived = now()
            guard let event = Self.decode(text) else {
                AppLogger.buzzer.debug("Ignored an unreadable message from the buzzer server")
                continue
            }
            AppLogger.buzzer.debug("Buzzer server → host: \(event.logDescription)")
            switch event {
            case .ping:
                try? await socket.send(Self.encode(.pong))
            case let .roomClosed(reason):
                finish(reason: "server closed the room (\(reason))")
                return false
            case let .error(error) where error.code.isFatal:
                finish(reason: "server error \(error.code.rawValue)")
                return false
            default:
                if let roomEvent = event.roomEvent { continuation?.yield(roomEvent) }
            }
        }
    }

    /// Retries with backoff until the room is taken back, or gives up (nil) when the grace
    /// period is over or the server refuses.
    private func reconnect() async -> (any HostSocket)? {
        isConnected = false
        socket?.close()
        socket = nil
        onStatusChange?(.reconnecting)

        let deadline = now().addingTimeInterval(gracePeriod)
        var delay = Self.initialBackoff
        var attempt = 0
        while !Task.isCancelled {
            await sleep(delay)
            guard !Task.isCancelled else { return nil }
            guard now() < deadline else { break }
            attempt += 1
            do {
                let (opened, newSocket) = try await open(resumeToken: resumeToken)
                guard !Task.isCancelled else { newSocket.close(); return nil }
                guard opened.resumed else {
                    // A fresh room has a new PIN, which the phones don't know.
                    newSocket.close()
                    finish(reason: "the server didn't have the room any more")
                    return nil
                }
                resumeToken = opened.resumeToken
                socket = newSocket
                isConnected = true
                lastReceived = now()
                AppLogger.buzzer.info("Took the external buzzer room back (attempt \(attempt))")
                onStatusChange?(.connected)
                return newSocket
            } catch let BuzzerBackendError.unreachable(reason) {
                AppLogger.buzzer.debug("Reconnect attempt \(attempt) failed: \(reason)")
                delay = min(delay * 2, Self.maxBackoff)
            } catch {
                finish(reason: "reconnect refused: \(error.localizedDescription)")
                return nil
            }
        }
        guard !Task.isCancelled else { return nil }
        finish(reason: "grace period over")
        return nil
    }

    private func finish(reason: String) {
        AppLogger.buzzer.warning("External buzzer room ended: \(reason)")
        isConnected = false
        socket?.close()
        socket = nil
        continuation?.finish()
        continuation = nil
        watchdogTask?.cancel()
        onStatusChange?(.ended(reason: reason))
    }

    /// The server pings every few seconds; a connection that has gone quiet for the host TTL
    /// is treated as dropped even if it looks open.
    private func startWatchdog() {
        watchdogTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(BuzzerHostConstants.pingInterval))
                guard let self, !Task.isCancelled else { return }
                if isConnected, now().timeIntervalSince(lastReceived) > BuzzerHostConstants.hostTTL {
                    AppLogger.buzzer.warning("No message from the buzzer server for \(Int(BuzzerHostConstants.hostTTL))s; reconnecting")
                    socket?.close()
                }
            }
        }
    }

    // MARK: - Wire

    private nonisolated static func encode(_ command: HostCommand) throws -> String {
        String(decoding: try JSONEncoder().encode(command), as: UTF8.self)
    }

    private nonisolated static func decode(_ text: String) -> HostEvent? {
        try? JSONDecoder().decode(HostEvent.self, from: Data(text.utf8))
    }
}
