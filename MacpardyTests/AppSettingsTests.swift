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

    // MARK: - External buzzer server (#104)

    func testBuzzerServerModeDefaultsToBuiltInAndPersists() {
        XCTAssertEqual(AppSettings.buzzerServerMode(defaults), .builtIn)
        defaults.set(AppSettings.BuzzerServerMode.external.rawValue, forKey: AppSettings.Key.buzzerServerMode)
        XCTAssertEqual(AppSettings.buzzerServerMode(defaults), .external)
        defaults.set("nonsense", forKey: AppSettings.Key.buzzerServerMode)
        XCTAssertEqual(AppSettings.buzzerServerMode(defaults), .builtIn)
    }

    func testExternalServerURLRequiresEncryptionExceptOnLoopback() {
        XCTAssertEqual(AppSettings.externalServerURL(from: "https://buzz.example.org")?.absoluteString, "https://buzz.example.org")
        XCTAssertEqual(AppSettings.externalServerURL(from: "  buzz.example.org/ ")?.absoluteString, "https://buzz.example.org")
        XCTAssertEqual(AppSettings.externalServerURL(from: "wss://buzz.example.org/a/")?.absoluteString, "https://buzz.example.org/a")
        XCTAssertEqual(AppSettings.externalServerURL(from: "http://localhost:8472")?.absoluteString, "http://localhost:8472")
        XCTAssertEqual(AppSettings.externalServerURL(from: "http://127.0.0.1:8472")?.absoluteString, "http://127.0.0.1:8472")

        XCTAssertNil(AppSettings.externalServerURL(from: "http://buzz.example.org"))
        XCTAssertNil(AppSettings.externalServerURL(from: "ftp://buzz.example.org"))
        XCTAssertNil(AppSettings.externalServerURL(from: "https://user:pw@buzz.example.org"))
        XCTAssertNil(AppSettings.externalServerURL(from: "https://buzz.example.org?x=1"))
        XCTAssertNil(AppSettings.externalServerURL(from: ""))
        XCTAssertNil(AppSettings.externalServerURL(from: "https://"))
    }

    func testTheHostTokenIsNeverStoredInUserDefaults() {
        let store = InMemoryHostTokenStore()
        store.setToken("a-very-secret-token")
        defaults.set("https://buzz.example.org", forKey: AppSettings.Key.externalServerURL)
        XCTAssertEqual(store.token(), "a-very-secret-token")
        XCTAssertFalse(defaults.dictionaryRepresentation().values.contains { "\($0)".contains("a-very-secret-token") })
        store.setToken("  ")
        XCTAssertNil(store.token())
    }

    func testSettingsChangeLogShowsTheHostButNeverTheToken() {
        let log = LogCapture.capture {
            let changes = SettingsChangeLog(defaults: defaults)
            changes.start()
            defaults.set(AppSettings.BuzzerServerMode.external.rawValue, forKey: AppSettings.Key.buzzerServerMode)
            defaults.set("https://buzz.example.org/secret-path", forKey: AppSettings.Key.externalServerURL)
            changes.check()
        }
        XCTAssertTrue(log.messages.contains("state: AppSettings.buzzerServerMode: builtIn → external"))
        XCTAssertTrue(log.messages.contains("state: AppSettings.externalServerHost: none → buzz.example.org"))
        XCTAssertFalse(log.messages.contains { $0.contains("secret-path") })
    }
}
