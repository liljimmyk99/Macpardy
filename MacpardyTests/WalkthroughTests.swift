//
//  WalkthroughTests.swift
//  MacpardyTests
//

import XCTest
@testable import Macpardy

@MainActor
final class WalkthroughTests: XCTestCase {

    private var defaults: UserDefaults!
    private let suiteName = "WalkthroughTests"

    override func setUp() {
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
    }

    // MARK: - Steps

    func testStepsRunFromWelcomeToCreate() {
        XCTAssertEqual(WalkthroughStep.allCases.first, .welcome)
        XCTAssertEqual(WalkthroughStep.allCases.last, .createBoard)
    }

    func testNavigationStopsAtBothEnds() {
        XCTAssertNil(WalkthroughStep.welcome.previous)
        XCTAssertEqual(WalkthroughStep.welcome.next, .startGame)
        XCTAssertNil(WalkthroughStep.createBoard.next)
        XCTAssertTrue(WalkthroughStep.welcome.isFirst)
        XCTAssertTrue(WalkthroughStep.createBoard.isLast)
    }

    func testEveryKeyExistsInTheStringCatalog() throws {
        // The catalog is compiled into the app, so read the source file.
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Macpardy/Localizable.xcstrings")
        let data = try Data(contentsOf: url)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try XCTUnwrap(json["strings"] as? [String: Any])
        for step in WalkthroughStep.allCases {
            for key in [step.titleKey, step.bodyKey] + step.tipKeys {
                XCTAssertNotNil(strings[key], "Missing string: \(key)")
            }
        }
    }

    func testOnlyBuzzerStepHasFirewallAction() {
        XCTAssertEqual(WalkthroughStep.allCases.filter(\.hasFirewallAction), [.connectBuzzers])
    }

    // MARK: - Coordinator

    func testFirstRunPresentsOnceThenStaysClosed() {
        let coordinator = WalkthroughCoordinator(defaults: defaults)
        XCTAssertFalse(AppSettings.walkthroughSeen(defaults))

        coordinator.presentIfFirstRun()
        XCTAssertTrue(coordinator.isPresented)

        coordinator.finish()
        XCTAssertFalse(coordinator.isPresented)
        XCTAssertTrue(AppSettings.walkthroughSeen(defaults))

        coordinator.presentIfFirstRun()
        XCTAssertFalse(coordinator.isPresented)
    }

    func testRequestOpensEvenAfterSeenButNotWhenUnavailable() {
        let coordinator = WalkthroughCoordinator(defaults: defaults)
        coordinator.finish()

        coordinator.isAvailable = { false }
        coordinator.request()
        XCTAssertFalse(coordinator.isPresented)

        coordinator.isAvailable = { true }
        coordinator.request()
        XCTAssertTrue(coordinator.isPresented)
    }
}
