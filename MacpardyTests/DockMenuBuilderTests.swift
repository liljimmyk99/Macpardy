//
//  DockMenuBuilderTests.swift
//  MacpardyTests
//

import XCTest
@testable import Macpardy

@MainActor
final class DockMenuBuilderTests: XCTestCase {

    private func info(
        _ title: String, visible: Bool = true, mini: Bool = false, key: Bool = false, panel: Bool = false
    ) -> DockMenuBuilder.WindowInfo {
        .init(title: title, isVisible: visible, isMiniaturized: mini, isKey: key, isPanel: panel)
    }

    func testListsVisibleWindowsInOrder() {
        let entries = DockMenuBuilder.entries(for: [info("Control"), info("Display")])
        XCTAssertEqual(entries.map(\.title), ["Control", "Display"])
        XCTAssertEqual(entries.map(\.index), [0, 1])
    }

    func testSkipsUntitledPanelsAndHiddenWindows() {
        let entries = DockMenuBuilder.entries(for: [
            info(""), info("Open", panel: true), info("Hidden", visible: false), info("Logs")
        ])
        XCTAssertEqual(entries.map(\.title), ["Logs"])
        XCTAssertEqual(entries.first?.index, 3)
    }

    func testKeepsMinimizedWindowsAndMarksKey() {
        let entries = DockMenuBuilder.entries(for: [
            info("Control", key: true), info("Display", visible: false, mini: true)
        ])
        XCTAssertEqual(entries.map(\.isKey), [true, false])
        XCTAssertEqual(entries.map(\.isMiniaturized), [false, true])
    }
}
