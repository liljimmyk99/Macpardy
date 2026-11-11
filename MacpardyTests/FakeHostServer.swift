//
//  FakeHostServer.swift
//  MacpardyTests
//
//  Stands in for a self-hosted buzzer server on the host protocol, so
//  `RemoteBuzzerBackend` can be tested without a network (#104).
//

import BuzzerCore
import BuzzerHostProtocol
import Foundation
@testable import Macpardy

@MainActor
final class FakeHostServer {

    let token = "test-host-token-0123456789"
    var roomCode = "ABC123"
    var resumeToken = "resume-1"
    var gracePeriod: TimeInterval = 30

    /// When false, `connect()` throws.
    var reachable = true
    /// Fail this many `connect()` calls, then work again.
    var failingConnects = 0
    /// Answers every `hello` with this error.
    var helloError: HostError.Code?
    /// Whether a resume token still names a room.
    var roomExists = true

    private(set) var urls: [URL] = []
    private(set) var hellos: [HostHello] = []
    private(set) var commands: [HostCommand] = []
    private(set) var sockets: [FakeHostSocket] = []

    var currentSocket: FakeHostSocket? { sockets.last }

    func clearCommands() { commands = [] }

    func makeSocket(url: URL) -> FakeHostSocket {
        urls.append(url)
        let socket = FakeHostSocket(server: self)
        sockets.append(socket)
        return socket
    }

    /// Sends an event to the Mac, as the server would.
    func push(_ event: HostEvent) {
        currentSocket?.deliver(event)
    }

    /// Cuts the connection without a close message, as a network drop does.
    func dropConnection() {
        currentSocket?.fail(URLError(.networkConnectionLost))
    }

    fileprivate func connect() throws {
        if failingConnects > 0 {
            failingConnects -= 1
            throw URLError(.cannotConnectToHost)
        }
        if !reachable { throw URLError(.cannotConnectToHost) }
    }

    fileprivate func received(_ text: String, from socket: FakeHostSocket) {
        guard let command = try? JSONDecoder().decode(HostCommand.self, from: Data(text.utf8)) else { return }
        switch command {
        case let .hello(hello):
            hellos.append(hello)
            socket.deliver(reply(to: hello))
        default:
            commands.append(command)
        }
    }

    private func reply(to hello: HostHello) -> HostEvent {
        if let helloError { return .error(HostError(helloError, message: "test")) }
        if hello.token != token { return .error(HostError(.badToken, message: "test")) }
        if hello.resumeToken != nil, !roomExists {
            return .error(HostError(.roomNotFound, message: "test"))
        }
        return .roomOpened(RoomOpened(
            code: roomCode,
            resumeToken: resumeToken,
            resumed: hello.resumeToken != nil,
            gracePeriod: gracePeriod
        ))
    }
}

@MainActor
final class FakeHostSocket: HostSocket {

    private unowned let server: FakeHostServer
    private let stream: AsyncThrowingStream<String, any Error>
    private let continuation: AsyncThrowingStream<String, any Error>.Continuation
    nonisolated(unsafe) private var iterator: AsyncThrowingStream<String, any Error>.AsyncIterator
    private(set) var isClosed = false

    init(server: FakeHostServer) {
        self.server = server
        (stream, continuation) = AsyncThrowingStream<String, any Error>.makeStream()
        iterator = stream.makeAsyncIterator()
    }

    func deliver(_ event: HostEvent) {
        guard let data = try? JSONEncoder().encode(event) else { return }
        continuation.yield(String(decoding: data, as: UTF8.self))
    }

    func fail(_ error: any Error) {
        continuation.finish(throwing: error)
    }

    func connect() async throws { try server.connect() }

    func send(_ text: String) async throws {
        if isClosed { throw URLError(.networkConnectionLost) }
        server.received(text, from: self)
    }

    func receive() async throws -> String {
        guard let text = try await iterator.next() else { throw URLError(.networkConnectionLost) }
        return text
    }

    func close() {
        isClosed = true
        continuation.finish(throwing: URLError(.cancelled))
    }
}

/// A clock the tests advance by "sleeping".
final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var current = Date(timeIntervalSince1970: 1_000_000)

    var now: Date { lock.withLock { current } }

    func advance(_ seconds: TimeInterval) {
        lock.withLock { current = current.addingTimeInterval(seconds) }
    }
}
