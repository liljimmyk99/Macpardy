//
//  LogFilterTests.swift
//  MacpardyTests
//

import XCTest
@testable import Macpardy

@MainActor
final class LogFilterTests: XCTestCase {

    private let entries = [
        LogEntry(level: .debug, category: .buzzer, message: "TCP connection from 192.168.1.23", remote: "192.168.1.23"),
        LogEntry(level: .info, category: .buzzer, message: "Claim accepted", teamName: "Red", remote: "192.168.1.23"),
        LogEntry(level: .warning, category: .buzzer, message: "Disconnected Blue", teamName: "Blue", remote: "192.168.1.40"),
        LogEntry(level: .info, category: .storage, message: "Saved boards"),
        LogEntry(level: .warning, category: .network, message: "Mac network changed: Wi-Fi (en0) → unavailable"),
    ]

    func testDefaultsToBuzzerAtInfoAndAbove() {
        let filter = LogFilter()
        XCTAssertEqual(filter.category, .buzzer)
        XCTAssertEqual(filter.apply(entries).map(\.message), ["Claim accepted", "Disconnected Blue"])
    }

    func testAllCategoriesAndMinimumLevel() {
        var filter = LogFilter(category: nil, minimumLevel: .warning)
        XCTAssertEqual(filter.apply(entries).count, 2)
        filter.minimumLevel = .debug
        XCTAssertEqual(filter.apply(entries).count, entries.count)
    }

    func testTeamFilter() {
        let filter = LogFilter(category: nil, minimumLevel: .debug, teamName: "Red")
        XCTAssertEqual(filter.apply(entries).map(\.message), ["Claim accepted"])
    }

    func testSearchMatchesMessageTeamAndAddress() {
        var filter = LogFilter(category: nil, minimumLevel: .debug)
        filter.searchText = "wi-fi"
        XCTAssertEqual(filter.apply(entries).count, 1)
        filter.searchText = "blue"
        XCTAssertEqual(filter.apply(entries).map(\.teamName), ["Blue"])
        filter.searchText = "192.168.1.40"
        XCTAssertEqual(filter.apply(entries).count, 1)
        filter.searchText = "   "
        XCTAssertEqual(filter.apply(entries).count, entries.count)
    }

    func testTeamNamesAreUniqueAndSorted() {
        XCTAssertEqual(LogFilter.teamNames(in: entries + entries), ["Blue", "Red"])
    }
}
