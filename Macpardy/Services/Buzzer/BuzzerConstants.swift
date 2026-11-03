//
//  BuzzerConstants.swift
//  Macpardy
//
//  Central configuration for the embedded buzzer server.
//

import Foundation

nonisolated enum BuzzerConstants {
    /// TCP port the buzzer server listens on unless the host changes it in Settings.
    static let defaultPort = UInt16(AppSettings.defaultBuzzerPort)

    /// Seconds a joined phone can go without sending a pong before being
    /// disconnected. Long on purpose (#84): a phone's browser stops answering
    /// while it's in the background or the screen is locked, and a short Wi-Fi
    /// hiccup shouldn't cost a team its slot. A phone that really left is
    /// usually seen sooner, when its TCP connection closes.
    static let heartbeatTTL: TimeInterval = 60.0

    /// Seconds a socket gets to send a valid `join` before being closed.
    static let joinTTL: TimeInterval = 5.0

    /// Longest `device` id accepted in a `join`.
    static let maxDeviceIDLength = 64

    /// How often the server sends a ping to each connected client.
    static let pingInterval: TimeInterval = 2.0

    /// Current wire-protocol version sent in joinAccepted messages.
    /// v8 (#81): `join` may carry the phone's `diag` report.
    /// v9 (#84): `join` may carry a `device` id; a returning phone gets its team back.
    static let protocolVersion = 9

    /// Buzzes received within this long of the first one count as a tie.
    static let tieWindow: TimeInterval = 0.075

    /// Wrong join codes allowed from one address within `codeAttemptWindow`.
    static let maxCodeAttempts = 5
    static let codeAttemptWindow: TimeInterval = 60.0

    /// Team claim attempts allowed from one address within `claimAttemptWindow`.
    static let maxClaimAttempts = 10
    static let claimAttemptWindow: TimeInterval = 10.0

    /// How long an address stays blocked after exceeding an attempt limit.
    static let rateLimitLockout: TimeInterval = 30.0
}
