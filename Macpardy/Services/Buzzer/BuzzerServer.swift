//
//  BuzzerServer.swift
//  Macpardy
//
//  The built-in buzzer server's transport: HTTP + WebSocket over
//  Network.framework. The rules (join, claims, heartbeat, buzzes, Final) live
//  in `BuzzerRoom` in BuzzerCore (#101); this hands it connections and
//  decoded messages, and the room answers through each `ClientSession`.
//
//  Responsibilities
//  ─────────────────
//  • Listens on the configured port (default BuzzerConstants.defaultPort) for incoming TCP connections
//  • Serves buzzer.html (from the BuzzerWebPage package) for plain HTTP GET / requests
//  • Handles WebSocket connections (manual RFC 6455 framing over plain TCP)
//  • Maps Network.framework errors and bad frames to a `DisconnectReason`
//  • Keeps App Nap and idle sleep off while running, so pings stay on time
//  • Starts and stops the room with the listener
//

import BuzzerCore
import BuzzerWebPage
import CommonCrypto
import Foundation
import Network
import OSLog

// MARK: - BuzzerServer

actor BuzzerServer {

    private enum ServerError: Error {
        case invalidPort
    }

    // MARK: - Public State

    /// The game's phones and rules. The app sends it game changes directly.
    nonisolated let room: BuzzerRoom

    /// The port the listener binds to.
    let port: UInt16

    // MARK: - Private State

    private var listener: NWListener?
    /// Holds off App Nap and idle system sleep while the server runs: a napping
    /// or sleeping Mac stops answering every phone at once.
    private var hostingActivity: NSObjectProtocol?

    /// The HTML payload loaded once from the bundle and cached.
    private let buzzerHTML: Data

    // MARK: - Init

    init(room: BuzzerRoom, port: UInt16 = BuzzerConstants.defaultPort) {
        self.room = room
        self.port = port

        // The page lives in the buzzer package, shared with the self-hosted server (#103).
        if let html = BuzzerWebPage.html {
            self.buzzerHTML = html
        } else {
            AppLogger.buzzer.error("buzzer.html not found in the BuzzerWebPage bundle — phones will get an error page")
            self.buzzerHTML = BuzzerWebPage.missingPage
        }
    }

    // MARK: - Lifecycle

    /// Starts the listener and waits until it is ready, then starts the room.
    /// Throws if the port is already in use or the listener otherwise fails to start.
    func start() async throws {
        let tcpParams = NWParameters.tcp
        tcpParams.allowLocalEndpointReuse = true

        guard let endpointPort = NWEndpoint.Port(rawValue: port) else {
            throw ServerError.invalidPort
        }

        let listener = try NWListener(using: tcpParams, on: endpointPort)
        self.listener = listener

        listener.newConnectionHandler = { [weak self] connection in
            guard let self else { return }
            Task { await self.handleNewConnection(connection) }
        }

        let portNumber = port
        let room = room
        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                // The handler can fire many times; resume the continuation only once.
                let resumed = OSAllocatedUnfairLock(initialState: false)
                listener.stateUpdateHandler = { state in
                    switch state {
                    case .ready:
                        AppLogger.buzzer.info("Listener ready on port \(portNumber)")
                        if resumed.withLock({ let was = $0; $0 = true; return !was }) {
                            continuation.resume()
                        }
                    case .failed(let error):
                        AppLogger.buzzer.error("Listener on port \(portNumber) failed: \(DisconnectReason.describe(error))")
                        if resumed.withLock({ let was = $0; $0 = true; return !was }) {
                            continuation.resume(throwing: error)
                        } else {
                            Task { await room.reportFailure(error.localizedDescription) }
                        }
                    case .waiting(let error):
                        // Not fatal: Network.framework retries when the network changes.
                        AppLogger.buzzer.warning("Listener on port \(portNumber) is waiting for the network: \(DisconnectReason.describe(error))")
                    case .cancelled:
                        AppLogger.buzzer.info("Listener on port \(portNumber) cancelled")
                    case .setup:
                        AppLogger.buzzer.debug("Listener on port \(portNumber) setting up")
                    @unknown default:
                        AppLogger.buzzer.debug("Listener on port \(portNumber) changed state: \(String(describing: state))")
                    }
                }
                listener.start(queue: .global(qos: .utility))
            }
        } catch {
            listener.cancel()
            self.listener = nil
            throw error
        }

        await room.start()
        hostingActivity = ProcessInfo.processInfo.beginActivity(
            options: .userInitiated,
            reason: "Hosting phone buzzers"
        )
    }

    /// Stops the room (joined phones get `sessionEnded`), then the listener.
    func stop() async {
        if let hostingActivity {
            ProcessInfo.processInfo.endActivity(hostingActivity)
            self.hostingActivity = nil
        }
        // Connections are independent of the listener, so cancelling it below
        // doesn't cut the room's `sessionEnded` sends short.
        let phoneCount = await room.stop()
        listener?.cancel()
        listener = nil
        AppLogger.buzzer.info("Buzzer server stopped (\(phoneCount) connection(s) closed)")
    }

    // MARK: - Connection Handling

    private func handleNewConnection(_ connection: NWConnection) {
        // Accumulate bytes until the full HTTP header block has arrived
        // (i.e. until we see \r\n\r\n) before deciding how to route the
        // connection. A single receive() is not guaranteed to deliver all
        // headers in one chunk, so we loop until the terminator is present.
        let remote = ClientSession.remoteAddress(of: connection) ?? "unknown address"
        AppLogger.buzzer.debug("TCP connection from \(remote)", remote: remote)
        connection.start(queue: .global(qos: .utility))
        accumulateHTTPHeaders(connection: connection, buffer: Data())
    }

    private nonisolated func accumulateHTTPHeaders(connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1,
                           maximumLength: 4096) { [weak self] data, _, _, error in
            guard let self, let chunk = data, !chunk.isEmpty, error == nil else {
                let remote = ClientSession.remoteAddress(of: connection) ?? "unknown address"
                let why = error.map { DisconnectReason.describe($0) } ?? "closed by the phone"
                AppLogger.buzzer.debug("Connection from \(remote) ended before a full request (\(why))", remote: remote)
                connection.cancel()
                return
            }

            var accumulated = buffer
            accumulated.append(chunk)

            // Keep reading until the header block terminator arrives.
            let terminator = Data("\r\n\r\n".utf8)
            guard accumulated.range(of: terminator) != nil else {
                if accumulated.count > 16_384 {
                    // Safety cap — real HTTP headers are never this large.
                    let remote = ClientSession.remoteAddress(of: connection) ?? "unknown address"
                    AppLogger.buzzer.warning("Request headers from \(remote) exceeded 16 KB; closing", remote: remote)
                    connection.cancel()
                    return
                }
                self.accumulateHTTPHeaders(connection: connection, buffer: accumulated)
                return
            }

            // Header names are case-insensitive and browsers put Upgrade well past
            // the first few hundred bytes, so inspect the whole header block.
            let headers = (String(bytes: accumulated, encoding: .utf8) ?? "").lowercased()
            let requestLine = headers.prefix(while: { $0 != "\r" }).split(separator: " ")
            let isGET = requestLine.first == "get"
            let path = requestLine.count > 1
                ? String(requestLine[1].prefix(while: { $0 != "?" }))
                : ""

            if isGET && path == "/ws" && headers.contains("upgrade: websocket") {
                Task { await self.upgradeToWebSocket(connection: connection, requestData: accumulated) }
            } else if isGET && (path == "/" || path == "/index.html") {
                let remote = ClientSession.remoteAddress(of: connection) ?? "unknown address"
                let browser = UserAgentSummary.shorten(Self.headerValue("user-agent", in: accumulated))
                AppLogger.buzzer.info("Page requested by \(remote) (\(browser))", remote: remote)
                Task { await self.serveHTTP(connection: connection) }
            } else if isGET {
                Task { await self.serveNotFound(connection: connection) }
            } else {
                let remote = ClientSession.remoteAddress(of: connection) ?? "unknown address"
                AppLogger.buzzer.warning("Unrecognized request from \(remote); closing", remote: remote)
                connection.cancel()
            }
        }
    }

    // MARK: - HTTP page serving

    private func serveHTTP(connection: NWConnection) {
        let body = buzzerHTML
        let header = "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n"
        var response = Data(header.utf8)
        response.append(body)

        connection.send(content: response, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private func serveNotFound(connection: NWConnection) {
        let response = "HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
        connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    // MARK: - WebSocket upgrade & session loop

    private func upgradeToWebSocket(connection: NWConnection, requestData: Data) {
        // Perform the WebSocket handshake manually: extract the Sec-WebSocket-Key
        // and respond with the RFC 6455 accept value.
        let remote = ClientSession.remoteAddress(of: connection) ?? "unknown address"
        let userAgent = Self.headerValue("user-agent", in: requestData)
        guard let key = Self.headerValue("sec-websocket-key", in: requestData),
              let acceptValue = Self.webSocketAccept(for: key) else {
            AppLogger.buzzer.warning(
                "WebSocket handshake from \(remote) failed: no Sec-WebSocket-Key header (\(UserAgentSummary.shorten(userAgent)))",
                remote: remote
            )
            connection.cancel()
            return
        }

        let upgradeResponse = "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: \(acceptValue)\r\n\r\n"

        connection.send(
            content: Data(upgradeResponse.utf8),
            completion: .contentProcessed { [weak self] error in
                guard let self, error == nil else {
                    let why = error.map { DisconnectReason.describe($0) } ?? "server shutting down"
                    AppLogger.buzzer.warning("WebSocket handshake with \(remote) failed: \(why)", remote: remote)
                    connection.cancel()
                    return
                }
                Task {
                    let session = ClientSession(connection: connection, userAgent: userAgent)
                    // Keep any frame bytes that arrived in the same read as the handshake.
                    if let end = requestData.range(of: Data("\r\n\r\n".utf8)) {
                        session.receiveBuffer = Data(requestData[end.upperBound...])
                    }
                    await self.room.connect(session)
                    await self.readWebSocketFrames(from: session)
                }
            }
        )
    }

    /// Tells the room the connection is gone and closes it.
    private func drop(_ session: ClientSession, reason: DisconnectReason) async {
        await room.disconnect(session.id, reason: reason)
        session.close()
    }

    /// Reads WebSocket frames in a loop until the connection closes or the
    /// room drops it.
    private func readWebSocketFrames(from session: ClientSession) async {
        // Frames that arrived together with the handshake.
        await processBuffer(of: session)

        while true {
            let (data, isComplete, error) = await withCheckedContinuation { continuation in
                session.connection.receive(
                    minimumIncompleteLength: 1,
                    maximumLength: 65536
                ) { data, _, isComplete, error in
                    continuation.resume(returning: (data, isComplete, error))
                }
            }

            if let data, !data.isEmpty {
                session.receiveBuffer.append(data)
                await processBuffer(of: session)
            }

            // Already removed (close frame, timeout, host, stop): that path logged why.
            guard await room.isConnected(session.id) else { return }
            if let error {
                await drop(session, reason: .networkError(DisconnectReason.describe(error)))
                return
            }
            if isComplete {
                await drop(session, reason: .connectionEnded)
                return
            }
        }
    }

    /// Parses every complete frame at the front of the session's buffer.
    private func processBuffer(of session: ClientSession) async {
        while await room.isConnected(session.id) {
            switch WebSocketFrameParser.parse(session.receiveBuffer) {
            case .incomplete:
                return
            case .invalid:
                await drop(session, reason: .invalidFrame)
                return
            case .frame(let frame, let consumed):
                session.receiveBuffer = Data(session.receiveBuffer.dropFirst(consumed))
                await handleWebSocketFrame(frame, from: session)
            }
        }
    }

    /// Dispatches a single parsed WebSocket frame.
    private func handleWebSocketFrame(_ frame: WebSocketFrame, from session: ClientSession) async {
        switch frame.opcode {
        case 0x0: // Continuation of a fragmented text message
            guard var fragments = session.fragmentBuffer else { return }
            fragments.append(frame.payload)
            if fragments.count > WebSocketFrameParser.maxPayload {
                session.fragmentBuffer = nil
                await drop(session, reason: .oversizedMessage)
            } else if frame.fin {
                session.fragmentBuffer = nil
                await room.receive(text: fragments, from: session.id)
            } else {
                session.fragmentBuffer = fragments
            }

        case 0x1: // Text frame
            if frame.fin {
                await room.receive(text: frame.payload, from: session.id)
            } else {
                session.fragmentBuffer = frame.payload
            }

        case 0x8: // Connection close
            await drop(session, reason: .phoneClosed(code: WebSocketCloseCode.fromPayload(frame.payload)))

        case 0x9: // Ping — respond with pong (opcode 0xA)
            session.sendControlFrame(opcode: 0xA, payload: frame.payload)

        case 0xA: // Pong — update heartbeat timestamp
            await room.receivedPong(from: session.id)

        default:
            break
        }
    }

    // MARK: - WebSocket Handshake Helpers

    /// The value of the first header called `name` (lowercase) in an HTTP
    /// request head, trimmed; nil when absent or empty.
    nonisolated static func headerValue(_ name: String, in data: Data) -> String? {
        guard let text = String(bytes: data, encoding: .utf8) else { return nil }
        let prefix = name.lowercased() + ":"
        for line in text.components(separatedBy: "\r\n") {
            if line.isEmpty { break }   // end of the header block
            if line.lowercased().hasPrefix(prefix) {
                let value = line.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces)
                return value.isEmpty ? nil : value
            }
        }
        return nil
    }

    /// Computes the RFC 6455 §4.2.2 accept value: base64(SHA-1(key + GUID))
    nonisolated static func webSocketAccept(for key: String) -> String? {
        let magic = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
        let combined = key + magic
        guard let data = combined.data(using: .utf8) else { return nil }
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA1($0.baseAddress, CC_LONG(data.count), &digest)
        }
        return Data(digest).base64EncodedString()
    }
}
