//
//  FakeBuzzerBackend.swift
//  MacpardyTests
//
//  A `BuzzerBackend` that records what `BuzzerState` sent and lets a test
//  push room events, for testing `BuzzerState` without a server (#102).
//

import BuzzerCore
import Foundation
@testable import Macpardy

@MainActor
final class FakeBuzzerBackend: BuzzerBackend {

    nonisolated enum Call: Equatable, Sendable {
        case start
        case stop
        case teams([BuzzerTeam])
        case scores([UUID: Int])
        case mode(BuzzerMode)
        case wrong(UUID)
        case correct
        case responseTimer(UUID?, TimeInterval)
        case openWagering(limits: [UUID: Int], wagers: [UUID: Int])
        case closeWagering
        case setWager(UUID, Int?)
        case answering(FinalAnswerWindow, [UUID: String])
        case removePhone(UUID)
        case phase(String)
    }

    nonisolated struct StartFailure: LocalizedError {
        var errorDescription: String? { "Port in use" }
    }

    /// Everything `BuzzerState` called, oldest first.
    private(set) var calls: [Call] = []

    /// When set, the next `start()` throws it.
    var startError: (any Error)?

    /// Game PINs handed out by successive starts.
    private var codes = ["AAAAAA", "BBBBBB", "CCCCCC", "DDDDDD"]
    private var continuation: AsyncStream<BuzzerRoomEvent>.Continuation?

    /// Calls since the last `start`.
    var callsSinceStart: [Call] {
        guard let index = calls.lastIndex(of: .start) else { return calls }
        return Array(calls[calls.index(after: index)...])
    }

    func clearCalls() { calls = [] }

    /// Pushes an event as if the room reported it.
    func emit(_ event: BuzzerRoomEvent) {
        continuation?.yield(event)
    }

    // MARK: - BuzzerBackend

    func start() async throws -> BuzzerBackendSession {
        calls.append(.start)
        if let startError {
            self.startError = nil
            throw startError
        }
        let code = codes.removeFirst()
        let (events, continuation) = AsyncStream<BuzzerRoomEvent>.makeStream()
        self.continuation = continuation
        return BuzzerBackendSession(
            joinCode: code,
            baseURL: URL(string: "http://192.168.1.20:8472")!,
            joinURL: URL(string: "http://192.168.1.20:8472?code=\(code)")!,
            events: events
        )
    }

    func stop() async {
        calls.append(.stop)
        continuation?.finish()
        continuation = nil
    }

    func updateTeams(_ teams: [BuzzerTeam]) async { calls.append(.teams(teams)) }
    func updateScores(_ scores: [UUID: Int]) async { calls.append(.scores(scores)) }
    func setBuzzerMode(_ mode: BuzzerMode) async { calls.append(.mode(mode)) }
    func markWrong(teamID: UUID) async { calls.append(.wrong(teamID)) }
    func markCorrect() async { calls.append(.correct) }
    func setResponseTimer(teamID: UUID?, seconds: TimeInterval) async { calls.append(.responseTimer(teamID, seconds)) }
    func openWagering(limits: [UUID: Int], wagers: [UUID: Int]) async {
        calls.append(.openWagering(limits: limits, wagers: wagers))
    }
    func closeWagering() async { calls.append(.closeWagering) }
    func setWager(teamID: UUID, amount: Int?) async { calls.append(.setWager(teamID, amount)) }
    func setAnswering(_ window: FinalAnswerWindow, answers: [UUID: String]) async {
        calls.append(.answering(window, answers))
    }
    func removePhone(forTeam teamID: UUID) async { calls.append(.removePhone(teamID)) }
    func broadcastPhase(_ phase: String) async { calls.append(.phase(phase)) }
}
