//
//  AppBuzzerLoggerTests.swift
//  MacpardyTests
//
//  Lines logged through the buzzer package's hook reach the app's log with
//  the right level, category, verbose prefix and team/remote filters (#100).
//

import BuzzerCore
import XCTest
@testable import Macpardy

@MainActor
final class AppBuzzerLoggerTests: XCTestCase {

    func testPlainLinesKeepTheirLevelTeamAndRemote() {
        let logger = AppBuzzerLogger()
        let log = LogCapture.capture {
            logger.info("Phone joined", team: "Blue", remote: "192.168.1.5")
            logger.warning("Heartbeat timeout", remote: "192.168.1.6")
        }

        XCTAssertEqual(log.messages, ["Phone joined", "Heartbeat timeout"])
        XCTAssertEqual(log.entries.map(\.level), [.info, .warning])
        XCTAssertEqual(log.entries.first?.teamName, "Blue")
        XCTAssertEqual(log.entries.map(\.remote), ["192.168.1.5", "192.168.1.6"])
        XCTAssertTrue(log.entries.allSatisfy { $0.category == .buzzer })
    }

    func testVerboseLinesGetTheAppsPrefixes() {
        let logger = AppBuzzerLogger()
        let log = LogCapture.capture {
            logger.state("tie window closed")
            logger.phone("buzz", team: "Red", remote: "10.0.0.2")
            logger.change("BuzzerEngine.mode", from: "armed", to: "disabled", reason: "correct")
        }

        XCTAssertEqual(log.messages, [
            "state: tie window closed",
            "phone: buzz",
            "state: BuzzerEngine.mode: 'armed' → 'disabled' (correct)",
        ])
        XCTAssertTrue(log.entries.allSatisfy { $0.level == .debug })
        XCTAssertEqual(log.entries[1].teamName, "Red")
        XCTAssertEqual(log.entries[1].remote, "10.0.0.2")
    }

    func testChangeLinesMatchTheAppsOwnFormat() {
        let viaPackage = LogCapture.capture {
            AppBuzzerLogger().change("Room.connectedCount", from: 2, to: 3, reason: "join")
        }
        let viaApp = LogCapture.capture {
            AppLogger.buzzer.change("Room.connectedCount", from: 2, to: 3, reason: "join")
        }
        XCTAssertEqual(viaPackage.messages, viaApp.messages)
    }

    func testEveryLevelMapsToTheSameAppLevel() {
        for level in BuzzerLogLevel.allCases {
            XCTAssertEqual(LogLevel(level).rawValue, level.rawValue)
        }
    }

    func testCategoryCanBeChosen() {
        let log = LogCapture.capture {
            AppBuzzerLogger(logger: AppLogger.network).notice("Wi-Fi changed")
        }
        XCTAssertEqual(log.entries.first?.category, .network)
        XCTAssertEqual(log.entries.first?.level, .notice)
    }
}
