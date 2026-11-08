//
//  ClientSession.swift
//  Macpardy
//
//  One phone's WebSocket over Network.framework: the connection, its frame
//  buffers, and sending. The phone's game state (joined, team, last pong)
//  lives in `BuzzerRoom`, which talks to it as a `BuzzerConnection` (#101).
//

import BuzzerCore
import Foundation
import Network

/// Marked `@unchecked Sendable` because its mutable buffers are only touched
/// from within the `BuzzerServer` actor, by the connection's read loop.
nonisolated final class ClientSession: BuzzerConnection, @unchecked Sendable {

    nonisolated let id = UUID()

    /// The underlying Network.framework connection for this client.
    nonisolated let connection: NWConnection

    /// Bytes received but not yet parsed into complete WebSocket frames.
    var receiveBuffer = Data()

    /// Payload of an in-progress fragmented text message (opcode 0x1 without FIN).
    var fragmentBuffer: Data?

    /// Remote address used to key rate limiting. Falls back to the session id
    /// when the endpoint is not an IP host/port pair.
    nonisolated let remoteKey: String

    /// The browser's User-Agent header from the WebSocket handshake, if sent.
    nonisolated let userAgent: String?

    /// First four characters of `id`, matching the room's log lines.
    nonisolated var shortID: String { String(id.uuidString.prefix(4)).lowercased() }

    nonisolated init(connection: NWConnection, userAgent: String? = nil) {
        self.connection = connection
        self.userAgent = userAgent
        self.remoteKey = Self.remoteAddress(of: connection) ?? id.uuidString
    }

    /// The connection's remote IP address, without any interface scope.
    nonisolated static func remoteAddress(of connection: NWConnection) -> String? {
        guard case .hostPort(let host, _) = connection.endpoint else { return nil }
        // Strip any interface scope ("fe80::1%en0") so one device maps to one key.
        return "\(host)".split(separator: "%").first.map(String.init) ?? "\(host)"
    }

    // MARK: - Sending

    /// Encodes `message` as JSON and sends it as a WebSocket text frame.
    nonisolated func send(_ message: ServerMessage, closeAfterSending: Bool) {
        guard let data = try? message.jsonData() else {
            AppLogger.buzzer.error("Couldn't encode a message for \(remoteKey) #\(shortID)", remote: remoteKey)
            return
        }
        connection.send(content: Self.frame(opcode: 0x1, payload: data), completion: .contentProcessed { [connection] error in
            if let error {
                AppLogger.buzzer.warning(
                    "Send to \(self.remoteKey) #\(self.shortID) failed: \(DisconnectReason.describe(error))",
                    remote: self.remoteKey
                )
            }
            if closeAfterSending {
                connection.cancel()
            }
        })
    }

    /// Sends a control frame (a pong) without waiting for it to go out.
    nonisolated func sendControlFrame(opcode: UInt8, payload: Data) {
        connection.send(content: Self.frame(opcode: opcode, payload: payload), completion: .idempotent)
    }

    /// Closes the connection. Network.framework has no close code to pick, so
    /// the reason isn't sent; the room has already logged it.
    nonisolated func close(reason: DisconnectReason) {
        close()
    }

    nonisolated func close() {
        connection.cancel()
    }

    /// A minimal unmasked WebSocket frame with FIN set. Server-to-client
    /// frames are never masked (RFC 6455 §5.1).
    nonisolated static func frame(opcode: UInt8, payload: Data) -> Data {
        var frame = Data()
        frame.append(0x80 | (opcode & 0x0F))
        let len = payload.count
        if len < 126 {
            frame.append(UInt8(len))
        } else if len < 65536 {
            frame.append(126)
            frame.append(UInt8(len >> 8))
            frame.append(UInt8(len & 0xFF))
        } else {
            frame.append(127)
            for shift in stride(from: 56, through: 0, by: -8) {
                frame.append(UInt8((len >> shift) & 0xFF))
            }
        }
        frame.append(contentsOf: payload)
        return frame
    }
}
