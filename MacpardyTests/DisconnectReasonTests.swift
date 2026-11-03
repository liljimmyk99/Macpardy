//
//  DisconnectReasonTests.swift
//  MacpardyTests
//

import Network
import XCTest
@testable import Macpardy

@MainActor
final class DisconnectReasonTests: XCTestCase {

    // MARK: - Close codes

    func testCloseCodeIsReadBigEndianFromThePayload() {
        XCTAssertEqual(DisconnectReason.closeCode(fromPayload: Data([0x03, 0xE9])), 1001)
        XCTAssertEqual(DisconnectReason.closeCode(fromPayload: Data([0x03, 0xE8]) + Data("bye".utf8)), 1000)
    }

    func testShortCloseFramesHaveNoCode() {
        XCTAssertNil(DisconnectReason.closeCode(fromPayload: Data()))
        XCTAssertNil(DisconnectReason.closeCode(fromPayload: Data([0x03])))
    }

    func testCloseCodeDescriptions() {
        XCTAssertEqual(DisconnectReason.describe(closeCode: nil), "no status code")
        XCTAssertEqual(DisconnectReason.describe(closeCode: 1001), "1001 going away: tab closed, reloaded or navigated away")
        XCTAssertEqual(DisconnectReason.describe(closeCode: 4321), "code 4321")
    }

    // MARK: - Descriptions

    func testEveryReasonHasADistinctDescription() {
        let reasons: [DisconnectReason] = [
            .phoneClosed(code: 1001),
            .phoneClosed(code: nil),
            .connectionEnded,
            .networkError("Connection reset by peer (POSIX 54)"),
            .heartbeatTimeout(sinceLastPong: 6.1),
            .neverJoined(after: 5.4),
            .invalidFrame,
            .oversizedMessage,
            .joinRejected(.invalidCode),
            .removedByHost,
            .serverStopped,
            .replacedByNewConnection,
        ]
        let descriptions = reasons.map(\.description)
        XCTAssertEqual(Set(descriptions).count, reasons.count)
        XCTAssertFalse(descriptions.contains(where: \.isEmpty))
    }

    func testDescriptionsCarryTheirDetails() {
        XCTAssertEqual(
            DisconnectReason.phoneClosed(code: 1001).description,
            "phone closed the connection (1001 going away: tab closed, reloaded or navigated away)"
        )
        XCTAssertTrue(DisconnectReason.heartbeatTimeout(sinceLastPong: 6.14).description.hasPrefix("no pong for 6.1s"))
        XCTAssertEqual(DisconnectReason.networkError("boom").description, "network error: boom")
        XCTAssertEqual(DisconnectReason.joinRejected(.rateLimited).description, "join rejected (rateLimited)")
        XCTAssertEqual(DisconnectReason.removedByHost.description, "removed by the host")
        XCTAssertEqual(DisconnectReason.serverStopped.description, "the buzzer server stopped")
    }

    func testExpectedEndingsAreInfoAndProblemsAreWarnings() {
        XCTAssertEqual(DisconnectReason.removedByHost.logLevel, .info)
        XCTAssertEqual(DisconnectReason.serverStopped.logLevel, .info)
        XCTAssertEqual(DisconnectReason.replacedByNewConnection.logLevel, .info)
        XCTAssertEqual(DisconnectReason.phoneClosed(code: 1001).logLevel, .info)
        XCTAssertEqual(DisconnectReason.phoneClosed(code: nil).logLevel, .warning)
        XCTAssertEqual(DisconnectReason.heartbeatTimeout(sinceLastPong: 6).logLevel, .warning)
        XCTAssertEqual(DisconnectReason.networkError("x").logLevel, .warning)
    }

    func testPOSIXErrorsAreDescribedReadably() {
        XCTAssertEqual(DisconnectReason.describe(NWError.posix(.ECONNRESET)), "Connection reset by peer (POSIX 54)")
    }

    // MARK: - Durations

    func testDurationFormatting() {
        XCTAssertEqual(LogDuration.format(0), "0s")
        XCTAssertEqual(LogDuration.format(41), "41s")
        XCTAssertEqual(LogDuration.format(720), "12m")
        XCTAssertEqual(LogDuration.format(723), "12m 3s")
        XCTAssertEqual(LogDuration.format(3_900), "1h 5m")
        XCTAssertEqual(LogDuration.format(7_200), "2h")
        XCTAssertEqual(LogDuration.seconds(6.14), "6.1s")
        XCTAssertEqual(LogDuration.seconds(90), "1m 30s")
    }
}
