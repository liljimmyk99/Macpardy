//
//  ClientSession.swift
//  Macpardy
//
//  Represents a single connected WebSocket client (one phone browser tab).
//

import BuzzerCore
import Foundation
import Network

/// Tracks the state of a single WebSocket client connection.
///
/// Marked `@unchecked Sendable` because its mutable state (`lastPong`,
/// `isAuthenticated`) is always mutated from within the `BuzzerServer` actor.
nonisolated final class ClientSession: Identifiable, @unchecked Sendable {

    nonisolated let id = UUID()

    /// The underlying Network.framework connection for this client.
    nonisolated let connection: NWConnection

    /// Timestamp of the last pong received from this client.
    /// Always mutated from within the BuzzerServer actor.
    var lastPong: Date = Date()

    /// Whether this client has successfully sent a valid join code.
    /// Always mutated from within the BuzzerServer actor.
    var isAuthenticated: Bool = false

    /// When the WebSocket handshake completed; used to evict clients that never join.
    let connectedAt = Date()

    /// Bytes received but not yet parsed into complete WebSocket frames.
    /// Always mutated from within the BuzzerServer actor.
    var receiveBuffer = Data()

    /// Payload of an in-progress fragmented text message (opcode 0x1 without FIN).
    var fragmentBuffer: Data?

    /// Remote address used to key rate limiting. Falls back to the session id
    /// when the endpoint is not an IP host/port pair.
    nonisolated let remoteKey: String

    /// The browser's User-Agent header from the WebSocket handshake, if sent.
    nonisolated let userAgent: String?

    /// The page's `device` id from its `join`, if it sent a usable one.
    /// Always mutated from within the BuzzerServer actor.
    var deviceID: String?

    /// The last team this phone held. Kept after the claim is released so the
    /// disconnect line can still name the team.
    var claimedTeamName: String?

    /// First four characters of `id`, to tell apart log lines from phones on
    /// the same address.
    nonisolated var shortID: String { String(id.uuidString.prefix(4)).lowercased() }

    /// How log lines name this phone: its team once it has claimed one,
    /// otherwise its address, plus `shortID`.
    var logLabel: String {
        if let claimedTeamName { "\(claimedTeamName) (\(remoteKey) #\(shortID))" } else { "\(remoteKey) #\(shortID)" }
    }

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
    nonisolated func send(_ message: ServerMessage, closeAfterSending: Bool = false) {
        guard let data = try? message.jsonData() else {
            AppLogger.buzzer.error("Couldn't encode a message for \(remoteKey) #\(shortID)", remote: remoteKey)
            return
        }
        var frame = Data()
        let len = data.count
        frame.append(0x81)   // FIN + opcode text (0x1)
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
        frame.append(contentsOf: data)
        connection.send(content: frame, completion: .contentProcessed { [connection] error in
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

    /// Closes the WebSocket connection cleanly.
    nonisolated func close() {
        connection.cancel()
    }
}
