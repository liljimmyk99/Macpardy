//
//  DisconnectReason.swift
//  Macpardy
//
//  Why the server dropped a phone's connection (#81), so each disconnect logs
//  one specific line instead of a generic "Client removed".
//

import Foundation
import Network

nonisolated enum DisconnectReason: Equatable, Sendable {
    /// The phone sent a WebSocket close frame, with its status code if it had one.
    case phoneClosed(code: UInt16?)
    /// The TCP connection ended without a WebSocket close frame.
    case connectionEnded
    /// Network.framework reported an error on the connection.
    case networkError(String)
    /// No pong within the heartbeat TTL.
    case heartbeatTimeout(sinceLastPong: TimeInterval)
    /// The socket connected but never sent a valid `join`.
    case neverJoined(after: TimeInterval)
    /// A frame that couldn't be parsed.
    case invalidFrame
    /// A fragmented message larger than the parser's limit.
    case oversizedMessage
    /// The `join` was refused.
    case joinRejected(JoinRejectReason)
    /// The host removed the phone from its team.
    case removedByHost
    /// The server stopped (game completed, resumed or left).
    case serverStopped

    var description: String {
        switch self {
        case .phoneClosed(let code):
            "phone closed the connection (\(Self.describe(closeCode: code)))"
        case .connectionEnded:
            "the connection ended without a WebSocket close (phone browser or network dropped it)"
        case .networkError(let detail):
            "network error: \(detail)"
        case .heartbeatTimeout(let since):
            "no pong for \(LogDuration.seconds(since)) (heartbeat timeout; phone locked, in the background, or off Wi-Fi)"
        case .neverJoined(let after):
            "never sent a join within \(LogDuration.seconds(after))"
        case .invalidFrame:
            "sent an invalid WebSocket frame"
        case .oversizedMessage:
            "sent a message larger than \(WebSocketFrameParser.maxPayload / 1024) KB"
        case .joinRejected(let reason):
            "join rejected (\(reason.rawValue))"
        case .removedByHost:
            "removed by the host"
        case .serverStopped:
            "the buzzer server stopped"
        }
    }

    /// Expected endings are `info`; ones that point at a problem are `warning`.
    var logLevel: LogLevel {
        switch self {
        case .removedByHost, .serverStopped, .joinRejected:
            .info
        case .phoneClosed(let code):
            code == 1000 || code == 1001 ? .info : .warning
        case .connectionEnded, .networkError, .heartbeatTimeout, .neverJoined, .invalidFrame, .oversizedMessage:
            .warning
        }
    }

    // MARK: - Close codes

    /// The status code at the start of a close frame's payload (RFC 6455 §5.5.1),
    /// or nil when the payload is too short to carry one.
    static func closeCode(fromPayload payload: Data) -> UInt16? {
        guard payload.count >= 2 else { return nil }
        let bytes = [UInt8](payload.prefix(2))
        return UInt16(bytes[0]) << 8 | UInt16(bytes[1])
    }

    static func describe(closeCode code: UInt16?) -> String {
        guard let code else { return "no status code" }
        let meaning: String? = switch code {
        case 1000: "normal closure"
        case 1001: "going away: tab closed, reloaded or navigated away"
        case 1002: "protocol error"
        case 1003: "unsupported data"
        case 1005: "no status code"
        case 1006: "abnormal closure"
        case 1007: "invalid payload"
        case 1008: "policy violation"
        case 1009: "message too big"
        case 1011: "internal error"
        default: nil
        }
        return meaning.map { "\(code) \($0)" } ?? "code \(code)"
    }

    // MARK: - Network errors

    /// A short description of a connection error, e.g.
    /// "Connection reset by peer (POSIX 54)".
    static func describe(_ error: NWError) -> String {
        switch error {
        case .posix(let code):
            "\(String(cString: strerror(code.rawValue))) (POSIX \(code.rawValue))"
        case .dns(let code):
            "DNS error \(code)"
        case .tls(let status):
            "TLS error \(status)"
        default:
            String(describing: error)
        }
    }
}

/// Durations for log lines.
nonisolated enum LogDuration {

    /// Seconds with one decimal under a minute ("6.1s"), else as `format`.
    static func seconds(_ interval: TimeInterval) -> String {
        guard interval < 60 else { return format(interval) }
        return String(format: "%.1fs", max(0, interval))
    }

    /// "41s", "12m 3s", "1h 5m".
    static func format(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 { return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h" }
        if minutes > 0 { return seconds > 0 ? "\(minutes)m \(seconds)s" : "\(minutes)m" }
        return "\(seconds)s"
    }
}
