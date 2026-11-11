//
//  RemoteBuzzerBackendTests.swift
//  MacpardyTests
//
//  The external buzzer server backend (#104) against a fake host-protocol server.
//

import BuzzerCore
import BuzzerHostProtocol
import XCTest
@testable import Macpardy

@MainActor
final class RemoteBuzzerBackendTests: XCTestCase {

    private var defaults: UserDefaults!
    private let suiteName = "RemoteBuzzerBackendTests"
    private var server: FakeHostServer!
    private var tokenStore: InMemoryHostTokenStore!
    private var clock: TestClock!
    private var statuses: [BuzzerConnectionStatus] = []
    private var backend: RemoteBuzzerBackend!

    override func setUp() {
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set("https://buzz.example.org", forKey: AppSettings.Key.externalServerURL)
        server = FakeHostServer()
        tokenStore = InMemoryHostTokenStore(token: server.token)
        clock = TestClock()
        statuses = []
        backend = makeBackend()
    }

    override func tearDown() async throws {
        await backend.stop()
        defaults.removePersistentDomain(forName: suiteName)
    }

    private func makeBackend() -> RemoteBuzzerBackend {
        let clock = self.clock!
        let backend = RemoteBuzzerBackend(
            defaults: defaults,
            tokenStore: tokenStore,
            socketFactory: { [unowned self] url in server.makeSocket(url: url) },
            sleep: { seconds in
                clock.advance(seconds)
                await Task.yield()
            },
            now: { clock.now },
            clientName: "Macpardy/test"
        )
        backend.onStatusChange = { [unowned self] in statuses.append($0) }
        return backend
    }

    private func waitUntil(_ description: String, _ condition: () -> Bool) async {
        for _ in 0..<500 where !condition() { try? await Task.sleep(for: .milliseconds(5)) }
        XCTAssertTrue(condition(), "Timed out waiting for \(description)")
    }

    private func assertStartFails(_ expected: BuzzerBackendError, file: StaticString = #filePath, line: UInt = #line) async {
        do {
            _ = try await backend.start()
            XCTFail("Expected \(expected)", file: file, line: line)
        } catch let error as BuzzerBackendError {
            XCTAssertEqual(error.errorDescription, expected.errorDescription, file: file, line: line)
        } catch {
            XCTFail("Unexpected error \(error)", file: file, line: line)
        }
    }

    // MARK: - Opening a room

    func testStartOpensARoomAndBuildsURLsFromTheEnteredAddress() async throws {
        let session = try await backend.start()

        XCTAssertEqual(session.joinCode, "ABC123")
        XCTAssertEqual(session.baseURL.absoluteString, "https://buzz.example.org")
        XCTAssertEqual(session.joinURL.absoluteString, "https://buzz.example.org?code=ABC123")
        XCTAssertEqual(server.urls.map(\.absoluteString), ["wss://buzz.example.org/host"])
        let hello = try XCTUnwrap(server.hellos.first)
        XCTAssertEqual(hello.token, server.token)
        XCTAssertEqual(hello.version, BuzzerHostConstants.hostProtocolVersion)
        XCTAssertNil(hello.resumeToken)
        XCTAssertEqual(hello.client, "Macpardy/test")
    }

    func testAddressWithAPathKeepsItInBothURLs() async throws {
        defaults.set("buzz.example.org/macpardy/", forKey: AppSettings.Key.externalServerURL)
        let session = try await backend.start()

        XCTAssertEqual(server.urls.first?.absoluteString, "wss://buzz.example.org/macpardy/host")
        XCTAssertEqual(session.joinURL.absoluteString, "https://buzz.example.org/macpardy?code=ABC123")
    }

    // MARK: - Commands and events

    func testCommandsBecomeHostMessages() async throws {
        _ = try await backend.start()
        let team = Team(name: "Blue")
        let buzzerTeam = BuzzerTeam(team: team)

        await backend.updateTeams([buzzerTeam])
        await backend.updateScores([team.id: 200])
        await backend.setBuzzerMode(.armed)
        await backend.markWrong(teamID: team.id)
        await backend.markCorrect()
        await backend.setResponseTimer(teamID: team.id, seconds: 5)
        await backend.openWagering(limits: [team.id: 400], wagers: [:])
        await backend.closeWagering()
        await backend.setWager(teamID: team.id, amount: 100)
        await backend.setAnswering(.open, answers: [team.id: "x"])
        await backend.removePhone(forTeam: team.id)
        await backend.broadcastPhase("question")

        XCTAssertEqual(server.commands, [
            .updateTeams([buzzerTeam]),
            .updateScores([team.id: 200]),
            .setBuzzerMode(.armed),
            .markWrong(teamID: team.id),
            .markCorrect,
            .setResponseTimer(teamID: team.id, seconds: 5),
            .openWagering(limits: [team.id: 400], wagers: [:]),
            .closeWagering,
            .setWager(teamID: team.id, amount: 100),
            .setAnswering(.open, answers: [team.id: "x"]),
            .removePhone(teamID: team.id),
            .broadcastPhase("question"),
        ])
    }

    func testServerEventsComeBackAsRoomEvents() async throws {
        let session = try await backend.start()
        var iterator = session.events.makeAsyncIterator()
        let teamID = UUID()

        server.push(.connectedCount(2))
        server.push(.claimedTeams([teamID]))
        server.push(.firstBuzz(teamID))
        server.push(.wager(WagerSubmission(teamID: teamID, amount: 50)))
        server.push(.answer(AnswerSubmission(teamID: teamID, answer: "What is Swift?")))

        let received = [await iterator.next(), await iterator.next(), await iterator.next(), await iterator.next(), await iterator.next()]
        XCTAssertEqual(received, [
            .connectedCount(2),
            .claimedTeams([teamID]),
            .firstBuzz(teamID),
            .wager(WagerSubmission(teamID: teamID, amount: 50)),
            .answer(AnswerSubmission(teamID: teamID, answer: "What is Swift?")),
        ])
    }

    func testPingIsAnsweredWithPong() async throws {
        _ = try await backend.start()
        server.push(.ping)
        await waitUntil("pong") { self.server.commands.contains(.pong) }
    }

    func testStopClosesTheRoomAndEndsTheEventStream() async throws {
        let session = try await backend.start()
        await backend.stop()

        XCTAssertTrue(server.commands.contains(.closeRoom))
        XCTAssertTrue(server.currentSocket?.isClosed == true)
        var iterator = session.events.makeAsyncIterator()
        let next = await iterator.next()
        XCTAssertNil(next)
        XCTAssertTrue(statuses.isEmpty, "A deliberate stop isn't a status change")
    }

    func testCommandsAfterStopAreDropped() async throws {
        _ = try await backend.start()
        await backend.stop()
        server.clearCommands()
        await backend.markCorrect()
        XCTAssertTrue(server.commands.isEmpty)
    }

    // MARK: - Errors

    func testErrorsFromTheServerAreMapped() async {
        let cases: [(HostError.Code, BuzzerBackendError)] = [
            (.badToken, .badToken),
            (.rateLimited, .rateLimited),
            (.unsupportedVersion, .unsupportedVersion),
            (.serverFull, .serverFull),
        ]
        for (code, expected) in cases {
            server.helloError = code
            await assertStartFails(expected)
            XCTAssertTrue(server.currentSocket?.isClosed == true)
        }
    }

    func testWrongTokenIsBadToken() async {
        tokenStore.setToken("not-the-token-at-all")
        await assertStartFails(.badToken)
    }

    func testUnreachableServer() async {
        server.reachable = false
        do {
            _ = try await backend.start()
            XCTFail("Expected an error")
        } catch let BuzzerBackendError.unreachable(reason) {
            XCTAssertFalse(reason.isEmpty)
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    func testMissingAddressOrTokenIsNotConfigured() async {
        tokenStore.setToken("")
        await assertStartFails(.notConfigured)

        tokenStore.setToken(server.token)
        defaults.set("http://buzz.example.org", forKey: AppSettings.Key.externalServerURL)
        await assertStartFails(.notConfigured)
        XCTAssertTrue(server.urls.isEmpty, "Nothing should connect without a usable https address")
    }

    func testErrorsHaveLocalizedDescriptions() {
        let errors: [BuzzerBackendError] = [
            .notConfigured, .badToken, .rateLimited, .unsupportedVersion, .serverFull, .roomNotFound,
            .unreachable(underlying: "offline"),
        ]
        for error in errors {
            let text = error.errorDescription ?? ""
            XCTAssertFalse(text.isEmpty)
            XCTAssertFalse(text.hasPrefix("control.buzzer.error"), "Missing string for \(error)")
        }
    }

    // MARK: - Drop and resume

    func testDropReconnectsWithTheResumeTokenAndReportsStatus() async throws {
        let session = try await backend.start()
        var iterator = session.events.makeAsyncIterator()

        server.dropConnection()
        await waitUntil("reconnect") { self.statuses == [.reconnecting, .connected] }

        XCTAssertEqual(server.hellos.count, 2)
        XCTAssertEqual(server.hellos.last?.resumeToken, "resume-1")
        XCTAssertEqual(server.urls.count, 2)

        // The same event stream keeps working, and commands flow again.
        server.push(.connectedCount(3))
        let event = await iterator.next()
        XCTAssertEqual(event, .connectedCount(3))
        await backend.markCorrect()
        XCTAssertTrue(server.commands.contains(.markCorrect))
    }

    func testCommandsWhileDownAreDropped() async throws {
        _ = try await backend.start()
        server.reachable = false
        server.dropConnection()
        await waitUntil("reconnecting") { self.statuses.contains(.reconnecting) }

        await backend.markCorrect()
        XCTAssertFalse(server.commands.contains(.markCorrect))
    }

    func testReconnectRetriesWithBackoffUntilTheServerAnswers() async throws {
        _ = try await backend.start()
        server.failingConnects = 3
        server.dropConnection()

        await waitUntil("reconnect") { self.statuses.last == .connected }
        XCTAssertEqual(statuses, [.reconnecting, .connected])
        XCTAssertEqual(server.urls.count, 5, "the first connection, three failures, then the one that worked")
    }

    func testGracePeriodExpiryEndsTheRoom() async throws {
        server.gracePeriod = 30
        let session = try await backend.start()
        server.reachable = false
        server.dropConnection()

        await waitUntil("room ended") {
            if case .ended = self.statuses.last { return true }
            return false
        }
        XCTAssertEqual(statuses.first, .reconnecting)
        XCTAssertGreaterThanOrEqual(clock.now.timeIntervalSince(Date(timeIntervalSince1970: 1_000_000)), 30)

        var iterator = session.events.makeAsyncIterator()
        let next = await iterator.next()
        XCTAssertNil(next, "The event stream finishes when the room ends")
    }

    func testRoomGoneOnTheServerEndsItAtOnce() async throws {
        _ = try await backend.start()
        server.roomExists = false
        server.dropConnection()

        await waitUntil("room ended") {
            if case .ended = self.statuses.last { return true }
            return false
        }
        XCTAssertEqual(server.hellos.count, 2, "Only one resume attempt")
    }

    func testServerClosingTheRoomEndsItWithoutReconnecting() async throws {
        _ = try await backend.start()
        server.push(.roomClosed(reason: "shutdown"))

        await waitUntil("room ended") {
            if case .ended = self.statuses.last { return true }
            return false
        }
        XCTAssertEqual(server.hellos.count, 1)
    }

    // MARK: - Privacy

    func testTheHostTokenIsNeverLogged() async throws {
        let log = await LogCapture.capture {
            _ = try? await backend.start()
            server.dropConnection()
            await waitUntil("reconnect") { self.statuses.last == .connected }
            tokenStore.setToken("another-secret-token-9876")
            await backend.stop()
        }
        XCTAssertFalse(log.messages.isEmpty)
        for secret in [server.token, "another-secret-token-9876", server.resumeToken] {
            XCTAssertFalse(log.messages.contains { $0.contains(secret) }, "Logged a secret")
        }
    }
}
