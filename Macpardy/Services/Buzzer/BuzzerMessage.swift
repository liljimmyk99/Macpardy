//
//  BuzzerMessage.swift
//  Macpardy
//
//  Versioned JSON message protocol for the buzzer WebSocket connection.
//  All messages use a top-level `type` string field plus an optional `payload`.
//
//  Server → Phone: ServerMessage
//  Phone → Server: ClientMessage
//

import Foundation

// MARK: - Server → Phone

/// A team as shown in the phone's team picker.
nonisolated struct BuzzerTeam: Encodable, Equatable {
    let id: UUID
    let name: String
    let color: String
    /// True while a phone holds the team; the phone disables its Join button.
    let claimed: Bool
}

/// Why a `claim` was refused.
nonisolated enum ClaimRejectReason: String, Encodable {
    case taken
    case invalidTeam
    case rateLimited
}

/// Why a `join` was refused. Sent as `code` so the phone doesn't have to match
/// the English `reason` text.
nonisolated enum JoinRejectReason: String, Encodable, CaseIterable {
    /// The Game PIN doesn't match this session (wrong, or from a finished game).
    case invalidCode
    /// Too many wrong PINs from this address.
    case rateLimited
    /// The page speaks a different protocol version.
    case unsupportedVersion

    /// Human-readable text sent as `reason`, for logs and older pages.
    var message: String {
        switch self {
        case .invalidCode: "Invalid join code"
        case .rateLimited: "Too many attempts. Try again shortly."
        case .unsupportedVersion: "Unsupported protocol version"
        }
    }
}

/// The answering team's response countdown. Phones count down locally from
/// `remaining`; the server only sends start and stop events.
nonisolated struct ResponseTimerInfo: Equatable {
    let teamID: UUID
    /// Seconds left when the message was sent.
    let remaining: TimeInterval
    /// The full response time, in seconds.
    let total: TimeInterval
}

/// Messages sent by the server to a connected phone client.
nonisolated enum ServerMessage {
    /// Sent after a valid join code is received. Carries the teams (with claim
    /// flags) so the phone can render its team picker.
    case joinAccepted(teams: [BuzzerTeam])

    /// Sent when the join is refused. The server closes the connection after it;
    /// the phone goes back to its Game PIN screen.
    case joinRejected(JoinRejectReason)

    /// The server is ending this session (game completed, saved game resumed, or
    /// host left the game). The Game PIN no longer works; the phone returns to its
    /// Game PIN screen. The server closes the connection after it.
    case sessionEnded

    /// Broadcast whenever teams are added, renamed, removed, claimed or freed.
    case teams([BuzzerTeam])

    /// The phone now holds the team.
    case claimAccepted(teamID: UUID)

    /// The claim was refused; the phone stays on the team picker.
    case claimRejected(reason: ClaimRejectReason)

    /// The host removed this phone from its team. The server closes the
    /// connection afterwards and the phone must not reconnect on its own.
    case removed

    /// Heartbeat request. The phone must respond with a `pong` client message
    /// within `BuzzerConstants.heartbeatTTL` seconds or be disconnected.
    case ping

    /// Broadcast when the game phase changes so the phone can update its UI.
    case state(phase: String)

    /// What the phone's buzzer button should show. Sent to a single phone.
    case buzzerState(BuzzerPhoneState)

    /// Final Macpardy wagering is open; sent to a single phone. Ineligible
    /// teams get `eligible: false` and cannot wager.
    case wagerInfo(WagerInfo)

    /// A submitted wager was refused. The phone stays on the wager screen.
    case wagerRejected(WagerRejectReason)

    /// The team's wager is locked in (submitted, or set by the host).
    case wagerLocked(wager: Int)

    /// Wagering is over; the phone returns to the buzzer.
    case wagerClosed

    /// A team buzzed in and its response time is running. Broadcast.
    case responseTimer(ResponseTimerInfo)

    /// The response time ended early (host judged the answer) or was cancelled. Broadcast.
    case responseTimerStopped

    /// The Final answer screen: open for typing, or locked once the correct
    /// response is revealed. Sent to a single phone.
    case answerInfo(AnswerInfo)

    /// The team's answer was saved (it can still change it while answering is open).
    case answerSaved(answer: String)

    /// A submitted answer was refused. The phone stays on the answer screen.
    case answerRejected(AnswerRejectReason)

    /// Final answering is over; the phone returns to the buzzer.
    case answerClosed
}

extension ServerMessage: Encodable {
    private enum CodingKeys: String, CodingKey {
        case type, payload
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .joinAccepted(let teams):
            try container.encode("joinAccepted", forKey: .type)
            var payload = container.nestedContainer(keyedBy: PayloadKeys.self, forKey: .payload)
            try payload.encode(teams, forKey: .teams)
            try payload.encode(BuzzerConstants.protocolVersion, forKey: .version)

        case .joinRejected(let reason):
            try container.encode("joinRejected", forKey: .type)
            var payload = container.nestedContainer(keyedBy: PayloadKeys.self, forKey: .payload)
            try payload.encode(reason.message, forKey: .reason)
            try payload.encode(reason, forKey: .code)

        case .sessionEnded:
            try container.encode("sessionEnded", forKey: .type)

        case .teams(let teams):
            try container.encode("teams", forKey: .type)
            var payload = container.nestedContainer(keyedBy: PayloadKeys.self, forKey: .payload)
            try payload.encode(teams, forKey: .teams)

        case .claimAccepted(let teamID):
            try container.encode("claimAccepted", forKey: .type)
            var payload = container.nestedContainer(keyedBy: PayloadKeys.self, forKey: .payload)
            try payload.encode(teamID, forKey: .teamID)

        case .claimRejected(let reason):
            try container.encode("claimRejected", forKey: .type)
            var payload = container.nestedContainer(keyedBy: PayloadKeys.self, forKey: .payload)
            try payload.encode(reason, forKey: .reason)

        case .removed:
            try container.encode("removed", forKey: .type)

        case .ping:
            try container.encode("ping", forKey: .type)

        case .state(let phase):
            try container.encode("state", forKey: .type)
            var payload = container.nestedContainer(keyedBy: PayloadKeys.self, forKey: .payload)
            try payload.encode(phase, forKey: .phase)

        case .buzzerState(let state):
            try container.encode("buzzerState", forKey: .type)
            var payload = container.nestedContainer(keyedBy: PayloadKeys.self, forKey: .payload)
            try payload.encode(state, forKey: .state)

        case .wagerInfo(let info):
            try container.encode("wagerInfo", forKey: .type)
            var payload = container.nestedContainer(keyedBy: PayloadKeys.self, forKey: .payload)
            try payload.encode(info.eligible, forKey: .eligible)
            try payload.encode(info.max, forKey: .max)
            try payload.encodeIfPresent(info.wager, forKey: .wager)

        case .wagerRejected(let reason):
            try container.encode("wagerRejected", forKey: .type)
            var payload = container.nestedContainer(keyedBy: PayloadKeys.self, forKey: .payload)
            try payload.encode(reason, forKey: .reason)

        case .wagerLocked(let wager):
            try container.encode("wagerLocked", forKey: .type)
            var payload = container.nestedContainer(keyedBy: PayloadKeys.self, forKey: .payload)
            try payload.encode(wager, forKey: .wager)

        case .wagerClosed:
            try container.encode("wagerClosed", forKey: .type)

        case .responseTimer(let info):
            try container.encode("responseTimer", forKey: .type)
            var payload = container.nestedContainer(keyedBy: PayloadKeys.self, forKey: .payload)
            try payload.encode(info.teamID, forKey: .teamID)
            // Tenths are plenty for a countdown the phone animates itself.
            try payload.encode((info.remaining * 10).rounded() / 10, forKey: .remaining)
            try payload.encode(info.total, forKey: .total)

        case .responseTimerStopped:
            try container.encode("responseTimerStopped", forKey: .type)

        case .answerInfo(let info):
            try container.encode("answerInfo", forKey: .type)
            var payload = container.nestedContainer(keyedBy: PayloadKeys.self, forKey: .payload)
            try payload.encode(info.open, forKey: .open)
            try payload.encode(info.maxLength, forKey: .maxLength)
            try payload.encodeIfPresent(info.answer, forKey: .answer)

        case .answerSaved(let answer):
            try container.encode("answerSaved", forKey: .type)
            var payload = container.nestedContainer(keyedBy: PayloadKeys.self, forKey: .payload)
            try payload.encode(answer, forKey: .answer)

        case .answerRejected(let reason):
            try container.encode("answerRejected", forKey: .type)
            var payload = container.nestedContainer(keyedBy: PayloadKeys.self, forKey: .payload)
            try payload.encode(reason, forKey: .reason)

        case .answerClosed:
            try container.encode("answerClosed", forKey: .type)
        }
    }

    private enum PayloadKeys: String, CodingKey {
        case teams, version, reason, phase, teamID, state, eligible, max, wager, remaining, total, code
        case open, maxLength, answer
    }
}

// MARK: - Phone → Server

/// Messages sent by a phone client to the server.
nonisolated enum ClientMessage {
    /// First message a phone sends after the WebSocket connection opens.
    /// `version` must match `BuzzerConstants.protocolVersion`. `diag` is the
    /// phone's optional report on how its previous connection ended (v8).
    case join(code: String, version: Int, diag: PhoneDisconnectReport?)

    /// Asks to take a team. Only valid after a successful `join`.
    case claim(teamID: UUID)

    /// Response to a `ping`. Resets the client's heartbeat TTL.
    case pong

    /// The phone's buzzer button was pressed. Only valid once a team is claimed.
    case buzz

    /// Final Macpardy wager. Only the first valid submission counts.
    case submitWager(amount: Int)

    /// Final Macpardy answer. The latest submission counts while answering is open.
    case submitAnswer(answer: String)
}

extension ClientMessage: Decodable {
    private enum CodingKeys: String, CodingKey {
        case type, code, version, teamID, amount, answer, diag
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type_ = try container.decode(String.self, forKey: .type)
        switch type_ {
        case "join":
            let code = try container.decode(String.self, forKey: .code)
            let version = try container.decode(Int.self, forKey: .version)
            // Optional and best-effort: a malformed report never fails the join.
            let diag = (try? container.decodeIfPresent(PhoneDisconnectReport.self, forKey: .diag))
                .flatMap { $0.isEmpty ? nil : $0 }
            self = .join(code: code, version: version, diag: diag)
        case "claim":
            self = .claim(teamID: try container.decode(UUID.self, forKey: .teamID))
        case "pong":
            self = .pong
        case "buzz":
            self = .buzz
        case "submitWager":
            self = .submitWager(amount: try container.decode(Int.self, forKey: .amount))
        case "submitAnswer":
            self = .submitAnswer(answer: try container.decode(String.self, forKey: .answer))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown client message type: \(type_)"
            )
        }
    }
}

// MARK: - Helpers

extension ServerMessage {
    /// Encodes the message to a UTF-8 JSON `Data` blob ready for transmission.
    nonisolated func jsonData() throws -> Data {
        try JSONEncoder().encode(self)
    }
}
