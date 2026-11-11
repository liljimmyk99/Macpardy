//
//  HostSocket.swift
//  Macpardy
//
//  The WebSocket `RemoteBuzzerBackend` talks to a self-hosted server through (#104),
//  behind a protocol so tests can stand in for the server.
//

import Foundation

protocol HostSocket: AnyObject {
    /// Opens the connection. Throws when the server can't be reached.
    func connect() async throws
    func send(_ text: String) async throws
    /// The next text message. Throws when the connection ends.
    func receive() async throws -> String
    func close()
}

/// Makes a socket for a `wss://…/host` URL.
typealias HostSocketFactory = @MainActor (URL) -> any HostSocket

/// A `URLSessionWebSocketTask`.
final class URLSessionHostSocket: HostSocket {

    private let session: URLSession
    private let task: URLSessionWebSocketTask

    init(url: URL) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.waitsForConnectivity = false
        configuration.timeoutIntervalForRequest = 10
        session = URLSession(configuration: configuration)
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        task = session.webSocketTask(with: request)
        task.maximumMessageSize = BuzzerHostLimits.maxMessageSize
    }

    func connect() async throws {
        task.resume()
        // A ping that comes back proves the upgrade worked.
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            task.sendPing { error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            }
        }
    }

    func send(_ text: String) async throws {
        try await task.send(.string(text))
    }

    func receive() async throws -> String {
        switch try await task.receive() {
        case let .string(text): return text
        case let .data(data): return String(decoding: data, as: UTF8.self)
        @unknown default: return ""
        }
    }

    func close() {
        task.cancel(with: .goingAway, reason: nil)
        session.invalidateAndCancel()
    }
}

enum BuzzerHostLimits {
    /// The server reads up to 1 MB from the host; replies are small, but leave room.
    static let maxMessageSize = 1 << 20
}
