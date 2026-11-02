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

    /// Seconds a client can go without sending a pong before being disconnected.
    static let heartbeatTTL: TimeInterval = 5.0

    /// How often the server sends a ping to each connected client.
    static let pingInterval: TimeInterval = 2.0

    /// Current wire-protocol version sent in joinAccepted messages.
    static let protocolVersion = 7

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
