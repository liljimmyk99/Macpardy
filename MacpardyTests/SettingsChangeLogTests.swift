//
//  SettingsChangeLogTests.swift
//  MacpardyTests
//

import XCTest
@testable import Macpardy

@MainActor
final class SettingsChangeLogTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "SettingsChangeLogTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testChangedSettingsAreLoggedOldToNew() {
        let settingsLog = SettingsChangeLog(defaults: defaults)
        settingsLog.start()

        let log = LogCapture.capture {
            defaults.set(20, forKey: AppSettings.Key.questionTimerSeconds)
            defaults.set(false, forKey: AppSettings.Key.buzzersEnabled)
            settingsLog.check()
        }

        XCTAssertEqual(log.messages, [
            "state: AppSettings.questionTimerSeconds: 15s → 20s",
            "state: AppSettings.buzzersEnabled: true → false",
        ])
    }

    func testAnUnrelatedChangeLogsNothing() {
        let settingsLog = SettingsChangeLog(defaults: defaults)
        settingsLog.start()

        let log = LogCapture.capture {
            defaults.set("x", forKey: "NSWindow Frame Control")
            // A team name is logged by its text field on commit, not here.
            defaults.set("Blue", forKey: AppSettings.Key.teamNamePrefix + "0")
            settingsLog.check()
        }

        XCTAssertTrue(log.entries.isEmpty)
    }
}
