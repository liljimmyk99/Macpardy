//
//  LogRingBufferTests.swift
//  MacpardyTests
//

import XCTest
@testable import Macpardy

@MainActor
final class LogRingBufferTests: XCTestCase {

    func testKeepsEverythingUnderCapacity() {
        var buffer = LogRingBuffer<Int>(capacity: 5)
        buffer.append(contentsOf: [1, 2, 3])
        XCTAssertEqual(buffer.elements, [1, 2, 3])
        XCTAssertEqual(buffer.count, 3)
    }

    func testEvictsOldestFirstOnceFull() {
        var buffer = LogRingBuffer<Int>(capacity: 3)
        buffer.append(contentsOf: 1...7)
        XCTAssertEqual(buffer.elements, [5, 6, 7])
        XCTAssertEqual(buffer.count, 3)
    }

    func testEvictionAtExactlyCapacityWraps() {
        var buffer = LogRingBuffer<Int>(capacity: 3)
        buffer.append(contentsOf: [1, 2, 3])
        XCTAssertEqual(buffer.elements, [1, 2, 3])
        buffer.append(4)
        XCTAssertEqual(buffer.elements, [2, 3, 4])
    }

    func testRemoveAllResets() {
        var buffer = LogRingBuffer<Int>(capacity: 2)
        buffer.append(contentsOf: [1, 2, 3])
        buffer.removeAll()
        XCTAssertTrue(buffer.isEmpty)
        buffer.append(9)
        XCTAssertEqual(buffer.elements, [9])
    }

    func testLogCenterKeepsOnlyItsCapacity() {
        let center = LogCenter(store: LogFileStore(baseDirectory: FileManager.default.temporaryDirectory), capacity: 3)
        for index in 1...5 {
            center.record(LogEntry(level: .info, category: .buzzer, message: "line \(index)"))
        }
        XCTAssertEqual(center.entries.map(\.message), ["line 3", "line 4", "line 5"])
    }
}
