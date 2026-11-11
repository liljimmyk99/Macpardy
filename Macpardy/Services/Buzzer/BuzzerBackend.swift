//
//  BuzzerBackend.swift
//  Macpardy
//
//  Where the buzzer server runs, as seen by `BuzzerState` (#102). The built-in
//  server is `EmbeddedBuzzerBackend`; a self-hosted server (#104) will be a
//  second implementation. `BuzzerState` keeps the game's latest buzzer state
//  and replays it into a backend after `start()` (its resync step), so a
//  backend only forwards commands and reports `BuzzerRoomEvent`s.
//

import BuzzerCore
import Foundation

/// What a backend hands back once phones can join.
nonisolated struct BuzzerBackendSession: Sendable {
    /// The Game PIN phones enter. The backend owns it: the app generates it for the
    /// built-in server, a self-hosted server will send its own.
    let joinCode: String
    /// The page address without the code, shown as text next to the Game PIN.
    let baseURL: URL
    /// The full join link (with `?code=`), for the QR code and Copy.
    let joinURL: URL
    /// Everything the room reports, in order. Finishes when the backend stops.
    let events: AsyncStream<BuzzerRoomEvent>
}

/// Whether the backend can reach its server right now. Only a remote backend ever leaves
/// `.connected` (#104).
nonisolated enum BuzzerConnectionStatus: Equatable, Sendable {
    /// Running. After a drop this is reported again once the room is taken back; `BuzzerState`
    /// then resyncs.
    case connected
    /// The connection dropped and the backend is retrying within the server's grace period.
    case reconnecting
    /// The room is gone for good (grace period over, or the server closed it).
    case ended(reason: String)
}

/// A buzzer server the app can start, stop and send game changes to.
///
/// Calls arrive on the main actor from `BuzzerState`. Commands sent while the
/// backend isn't running are dropped; `BuzzerState` resyncs after `start()`.
protocol BuzzerBackend: AnyObject {

    /// Called on the main actor when the connection to the server changes (#104).
    var onStatusChange: ((BuzzerConnectionStatus) -> Void)? { get set }

    // MARK: Lifecycle

    /// Starts a new session with a new Game PIN. Throws when phones can't be
    /// reached (no network, port in use, …); the error's `localizedDescription`
    /// is shown to the host.
    func start() async throws -> BuzzerBackendSession

    /// Ends the session: joined phones get `sessionEnded`, then the server stops.
    /// Safe to call when not running.
    func stop() async

    // MARK: Game → phones

    func updateTeams(_ teams: [BuzzerTeam]) async
    func updateScores(_ scores: [UUID: Int]) async
    func setBuzzerMode(_ mode: BuzzerMode) async
    func markWrong(teamID: UUID) async
    func markCorrect() async
    func setResponseTimer(teamID: UUID?, seconds: TimeInterval) async
    func openWagering(limits: [UUID: Int], wagers: [UUID: Int]) async
    func closeWagering() async
    func setWager(teamID: UUID, amount: Int?) async
    func setAnswering(_ window: FinalAnswerWindow, answers: [UUID: String]) async
    func removePhone(forTeam teamID: UUID) async
    func broadcastPhase(_ phase: String) async
}

/// Why a backend couldn't start.
nonisolated enum BuzzerBackendError: LocalizedError {
    /// The Mac has no IPv4 address phones on the network could use.
    case noLocalAddress
    /// The listener couldn't open the port.
    case listenerFailed(port: UInt16, underlying: any Error)
    /// External server (#104): no valid server URL or no host token in Settings.
    case notConfigured
    /// The server refused the host token.
    case badToken
    /// Too many wrong tokens from this Mac; try again later.
    case rateLimited
    /// The app and the server don't speak the same host protocol version.
    case unsupportedVersion
    /// The server has no room for another game.
    case serverFull
    /// Taking a room back after a drop: the server no longer has it.
    case roomNotFound
    /// The server couldn't be reached or didn't answer.
    case unreachable(underlying: String)

    var errorDescription: String? {
        switch self {
        case .noLocalAddress:
            String(localized: "control.buzzer.error.no_local_address")
        case let .listenerFailed(port, underlying):
            String(localized: "control.buzzer.error.start_failed \(Int(port)) \(underlying.localizedDescription)")
        case .notConfigured:
            String(localized: "control.buzzer.error.not_configured")
        case .badToken:
            String(localized: "control.buzzer.error.bad_token")
        case .rateLimited:
            String(localized: "control.buzzer.error.rate_limited")
        case .unsupportedVersion:
            String(localized: "control.buzzer.error.unsupported_version")
        case .serverFull:
            String(localized: "control.buzzer.error.server_full")
        case .roomNotFound:
            String(localized: "control.buzzer.error.room_ended")
        case let .unreachable(underlying):
            String(localized: "control.buzzer.error.unreachable \(underlying)")
        }
    }
}
