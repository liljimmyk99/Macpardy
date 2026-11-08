//
//  LogExporterTests.swift
//  MacpardyTests
//

import BuzzerCore
import XCTest
import ZIPFoundation
@testable import Macpardy

@MainActor
final class LogExporterTests: XCTestCase {

    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LogExporterTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testArchiveFileName() {
        let date = Date(timeIntervalSince1970: 1_793_628_202) // 2026-11-02T14:03:22Z
        XCTAssertEqual(
            LogExporter.archiveFileName(for: date, timeZone: TimeZone(identifier: "UTC")!),
            "Macpardy-Logs-2026-11-02-1403.zip"
        )
    }

    func testTextLogHasOneLinePerEntry() throws {
        let encoder = LogEntry.makeEncoder()
        var data = Data()
        for message in ["first", "second"] {
            data.append(try LogEntry(level: .warning, category: .buzzer, message: message).jsonLine(using: encoder))
        }
        let lines = LogExporter.textLog(fromJSONLines: data).split(separator: "\n")
        XCTAssertEqual(lines.count, 2)
        XCTAssertTrue(lines[0].hasSuffix("warning [buzzer] first"), String(lines[0]))
        XCTAssertTrue(lines[1].hasSuffix("warning [buzzer] second"), String(lines[1]))
    }

    func testArchiveHoldsSystemInfoTextLogsAndRawRuns() throws {
        // Whole milliseconds: the log stores times to the millisecond.
        let entry = LogEntry(
            date: Date(timeIntervalSince1970: 1_800_000_000.25),
            level: .info,
            category: .buzzer,
            message: "Join accepted from 192.168.1.23 #ab12"
        )
        let run = directory.appendingPathComponent(LogFileStore.fileName(for: Date(timeIntervalSince1970: 1_800_000_000)))
        try entry.jsonLine(using: LogEntry.makeEncoder()).write(to: run)

        let data = try LogExporter.makeArchive(runFiles: [run], systemInfo: "App: Macpardy test\n")
        let archive = try Archive(data: data, accessMode: .read)
        let base = run.deletingPathExtension().lastPathComponent
        let paths = Set(archive.map(\.path))
        XCTAssertEqual(paths, ["system-info.txt", "logs/\(base).log", "raw/\(base).jsonl"])

        func contents(_ path: String) throws -> String {
            var out = Data()
            _ = try archive.extract(try XCTUnwrap(archive[path])) { out.append($0) }
            return String(decoding: out, as: UTF8.self)
        }
        XCTAssertEqual(try contents("system-info.txt"), "App: Macpardy test\n")
        XCTAssertTrue(try contents("logs/\(base).log").contains("info    [buzzer] Join accepted from 192.168.1.23 #ab12"))
        XCTAssertEqual(LogEntry.decodeLines(Data(try contents("raw/\(base).jsonl").utf8)), [entry])
    }

    func testSystemInfoListsBuzzerAndAddresses() {
        let report = SystemInfoReport.make(.init(
            buzzerPort: 8472,
            serverRunning: true,
            joinedPhones: 2,
            teamCount: 3,
            addresses: [.init(interface: "en0", ip: "192.168.1.10"), .init(interface: "utun3", ip: "10.0.0.2")]
        ))
        XCTAssertTrue(report.contains("Buzzer port:      8472"))
        XCTAssertTrue(report.contains("Protocol version: \(BuzzerConstants.protocolVersion)"))
        XCTAssertTrue(report.contains("Server running:   yes"))
        XCTAssertTrue(report.contains("Teams:            3"))
        XCTAssertTrue(report.contains("en0  192.168.1.10  ← used for the join link"))
        XCTAssertTrue(report.contains("utun3  10.0.0.2\n"))
        XCTAssertTrue(report.contains("Mac model:"))
    }
}
