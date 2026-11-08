//
//  BuzzerServerTests.swift
//  MacpardyTests
//
//  The Network.framework transport: header parsing, the handshake and framing,
//  and a real phone-style WebSocket session against a running server (#101).
//

import BuzzerCore
import XCTest
@testable import Macpardy

@MainActor
final class BuzzerServerTests: XCTestCase {

    // MARK: - Pure helpers

    func testHeaderValueIsCaseInsensitiveAndStopsAtTheBlankLine() {
        let request = Data("GET /ws HTTP/1.1\r\nHost: x\r\nUser-Agent:  Phone/1.0 \r\nSec-WebSocket-Key: abc==\r\n\r\nUser-Agent: body".utf8)
        XCTAssertEqual(BuzzerServer.headerValue("user-agent", in: request), "Phone/1.0")
        XCTAssertEqual(BuzzerServer.headerValue("sec-websocket-key", in: request), "abc==")
        XCTAssertNil(BuzzerServer.headerValue("origin", in: request))
    }

    func testWebSocketAcceptMatchesTheRFCExample() {
        // RFC 6455 §1.3.
        XCTAssertEqual(BuzzerServer.webSocketAccept(for: "dGhlIHNhbXBsZSBub25jZQ=="), "s3pPLMBiTxaQ9kYGzzhZRbK+xOo=")
    }

    func testFramesUseTheShortestLengthEncoding() {
        let short = ClientSession.frame(opcode: 0x1, payload: Data(repeating: 0x61, count: 5))
        XCTAssertEqual(Array(short.prefix(2)), [0x81, 5])
        XCTAssertEqual(short.count, 2 + 5)

        let medium = ClientSession.frame(opcode: 0x1, payload: Data(repeating: 0x61, count: 300))
        XCTAssertEqual(Array(medium.prefix(4)), [0x81, 126, 0x01, 0x2C])
        XCTAssertEqual(medium.count, 4 + 300)

        let long = ClientSession.frame(opcode: 0xA, payload: Data(repeating: 0x61, count: 70_000))
        XCTAssertEqual(Array(long.prefix(2)), [0x8A, 127])
        XCTAssertEqual(long.count, 10 + 70_000)
        XCTAssertEqual(Array(long[2..<10]), [0, 0, 0, 0, 0, 0x01, 0x11, 0x70])
    }

    // MARK: - Real transport

    func testServesTheBuzzerPageAnd404sEverythingElse() async throws {
        let (server, port) = try await startServer(room: BuzzerRoom(joinCode: "PAGE01"))

        let (page, pageResponse) = try await URLSession.shared.data(from: URL(string: "http://127.0.0.1:\(port)/")!)
        let (_, missingResponse) = try await URLSession.shared.data(from: URL(string: "http://127.0.0.1:\(port)/nope")!)
        await server.stop()

        XCTAssertEqual((pageResponse as? HTTPURLResponse)?.statusCode, 200)
        XCTAssertEqual((pageResponse as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Type"), "text/html; charset=utf-8")
        XCTAssertTrue(String(decoding: page, as: UTF8.self).contains("<html"))
        XCTAssertEqual((missingResponse as? HTTPURLResponse)?.statusCode, 404)
    }

    func testPhoneJoinsOverAWebSocketAndIsToldWhenTheServerStops() async throws {
        let room = BuzzerRoom(joinCode: "JOIN42")
        let (server, port) = try await startServer(room: room)
        let socket = URLSession.shared.webSocketTask(with: URL(string: "ws://127.0.0.1:\(port)/ws")!)
        socket.resume()
        defer { socket.cancel() }

        try await socket.send(.string(#"{"type":"join","code":"JOIN42","version":\#(BuzzerConstants.protocolVersion),"device":"test-tab"}"#))
        let accepted = try await nextMessage(from: socket)
        XCTAssertEqual(accepted["type"] as? String, "joinAccepted")

        // A WebSocket ping frame gets a pong back.
        try await withTimeout { try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            socket.sendPing { error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            }
        } }

        await server.stop()
        let ended = try await nextMessage(from: socket)
        XCTAssertEqual(ended["type"] as? String, "sessionEnded")

        var events: [BuzzerRoomEvent] = []
        for await event in room.events { events.append(event) }
        XCTAssertTrue(events.contains(.connectedCount(1)))
    }

    func testWrongPINIsRejectedOverTheWire() async throws {
        let (server, port) = try await startServer(room: BuzzerRoom(joinCode: "RIGHT1"))
        let socket = URLSession.shared.webSocketTask(with: URL(string: "ws://127.0.0.1:\(port)/ws")!)
        socket.resume()
        defer { socket.cancel() }

        try await socket.send(.string(#"{"type":"join","code":"WRONG1","version":\#(BuzzerConstants.protocolVersion)}"#))
        let rejected = try await nextMessage(from: socket)
        await server.stop()

        XCTAssertEqual(rejected["type"] as? String, "joinRejected")
        XCTAssertEqual((rejected["payload"] as? [String: Any])?["code"] as? String, "invalidCode")
    }

    // MARK: - Helpers

    /// Starts a server on a free high port.
    private func startServer(room: BuzzerRoom) async throws -> (BuzzerServer, UInt16) {
        var lastError: Error?
        for _ in 0..<5 {
            let port = UInt16.random(in: 49_152...60_000)
            let server = BuzzerServer(room: room, port: port)
            do {
                try await server.start()
                return (server, port)
            } catch {
                lastError = error
            }
        }
        throw lastError ?? URLError(.cannotConnectToHost)
    }

    /// The next JSON message from the server, skipping heartbeat pings.
    private func nextMessage(from socket: URLSessionWebSocketTask) async throws -> [String: Any] {
        while true {
            let message = try await withTimeout { try await socket.receive() }
            guard case .string(let text) = message,
                  let json = try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any] else {
                XCTFail("Expected a JSON text message")
                return [:]
            }
            if json["type"] as? String != "ping" { return json }
        }
    }

    private func withTimeout<T: Sendable>(
        seconds: Double = 5,
        _ operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(for: .seconds(seconds))
                throw URLError(.timedOut)
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}
