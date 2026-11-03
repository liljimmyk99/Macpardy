//
//  AppSettingsTests.swift
//  MacpardyTests
//

import XCTest
@testable import Macpardy

@MainActor
final class AppSettingsTests: XCTestCase {

    private var defaults: UserDefaults!
    private let suiteName = "AppSettingsTests"

    override func setUp() {
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testMissingKeysFallBackToDefaults() {
        XCTAssertEqual(AppSettings.questionTimerSeconds(defaults), 15)
        XCTAssertEqual(AppSettings.responseSeconds(defaults), 5)
        XCTAssertEqual(AppSettings.defaultTeamCount(defaults), 3)
        XCTAssertEqual(AppSettings.buzzerPort(defaults), 8472)
        XCTAssertNil(AppSettings.customTeamName(at: 0, defaults))
    }

    func testTimerClampsToRangeAndSteps() {
        XCTAssertEqual(AppSettings.clampQuestionTimerSeconds(1), 5)
        XCTAssertEqual(AppSettings.clampQuestionTimerSeconds(200), 60)
        XCTAssertEqual(AppSettings.clampQuestionTimerSeconds(22), 20)
        XCTAssertEqual(AppSettings.clampQuestionTimerSeconds(23), 25)
        defaults.set(999, forKey: AppSettings.Key.questionTimerSeconds)
        XCTAssertEqual(AppSettings.questionTimerSeconds(defaults), 60)
    }

    func testResponseSecondsClamp() {
        XCTAssertEqual(AppSettings.clampResponseSeconds(0), 3)
        XCTAssertEqual(AppSettings.clampResponseSeconds(99), 30)
        defaults.set(10, forKey: AppSettings.Key.responseSeconds)
        XCTAssertEqual(AppSettings.responseSeconds(defaults), 10)
    }

    func testTeamCountClampsToMax() {
        defaults.set(0, forKey: AppSettings.Key.defaultTeamCount)
        XCTAssertEqual(AppSettings.defaultTeamCount(defaults), 1)
        defaults.set(50, forKey: AppSettings.Key.defaultTeamCount)
        XCTAssertEqual(AppSettings.defaultTeamCount(defaults), Team.maxCount)
    }

    func testTeamNamesAreTrimmedCappedAndEmptyMeansDefault() {
        defaults.set("  Cats  ", forKey: AppSettings.Key.teamNamePrefix + "0")
        defaults.set("   ", forKey: AppSettings.Key.teamNamePrefix + "1")
        defaults.set(String(repeating: "x", count: 150), forKey: AppSettings.Key.teamNamePrefix + "2")
        XCTAssertEqual(AppSettings.customTeamName(at: 0, defaults), "Cats")
        XCTAssertNil(AppSettings.customTeamName(at: 1, defaults))
        XCTAssertEqual(AppSettings.customTeamName(at: 2, defaults)?.count, 100)
    }

    func testPortClampsToUnprivilegedRange() {
        XCTAssertEqual(AppSettings.clampPort(80), 1024)
        XCTAssertEqual(AppSettings.clampPort(70000), 65535)
        defaults.set(9000, forKey: AppSettings.Key.buzzerPort)
        XCTAssertEqual(AppSettings.buzzerPort(defaults), 9000)
    }

    func testBuzzersDefaultOnAndCanBeTurnedOff() {
        XCTAssertTrue(AppSettings.buzzersEnabled(defaults))
        defaults.set(false, forKey: AppSettings.Key.buzzersEnabled)
        XCTAssertFalse(AppSettings.buzzersEnabled(defaults))
    }

    func testAnimationsDefaultOnAndCanBeTurnedOff() {
        XCTAssertTrue(AppSettings.animationsEnabled(defaults))
        defaults.set(false, forKey: AppSettings.Key.animationsEnabled)
        XCTAssertFalse(AppSettings.animationsEnabled(defaults))
    }

    func testReduceMotionOverridesAnimationsSetting() {
        XCTAssertTrue(AppSettings.shouldAnimate(setting: true, reduceMotion: false))
        XCTAssertFalse(AppSettings.shouldAnimate(setting: true, reduceMotion: true))
        XCTAssertFalse(AppSettings.shouldAnimate(setting: false, reduceMotion: false))
    }
}
