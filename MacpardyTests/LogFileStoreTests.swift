//
//  LogFileStoreTests.swift
//  MacpardyTests
//

import XCTest
@testable import Macpardy

@MainActor
final class LogFileStoreTests: XCTestCase {

    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LogFileStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    /// Writes a fake earlier run of `size` bytes started at `date`.
    @discardableResult
    private func makeRun(at date: Date, size: Int = 10) throws -> URL {
        let url = directory.appendingPathComponent(LogFileStore.fileName(for: date))
        try Data(repeating: 0x41, count: size).write(to: url)
        return url
    }

    private func date(_ secondsAfterEpoch: TimeInterval) -> Date {
        Date(timeIntervalSince1970: 1_800_000_000 + secondsAfterEpoch)
    }

    private func runFileNames() throws -> Set<String> {
        Set(try FileManager.default.contentsOfDirectory(atPath: directory.path))
    }

    // MARK: - File names

    func testFileNameRoundTripsWithoutColons() throws {
        let launch = Date(timeIntervalSince1970: 1_793_628_202) // 2026-11-02T14:03:22Z
        let name = LogFileStore.fileName(for: launch)
        XCTAssertEqual(name, "macpardy-20261102T140322Z.jsonl")
        XCTAssertFalse(name.contains(":"))
        XCTAssertEqual(LogFileStore.launchDate(fromFileName: name), launch)
        XCTAssertNil(LogFileStore.launchDate(fromFileName: "notes.txt"))
        XCTAssertNil(LogFileStore.launchDate(fromFileName: "macpardy-garbage.jsonl"))
    }

    // MARK: - Writing and reading

    func testJSONLinesRoundTripThroughTheStore() async throws {
        let store = LogFileStore(baseDirectory: directory, launchDate: date(0))
        let entries = [
            LogEntry(date: date(1), level: .info, category: .buzzer, message: "Join accepted", teamName: "Red", remote: "192.168.1.23"),
            LogEntry(date: date(1.25), level: .warning, category: .network, message: "Mac network changed: Wi-Fi (en0) → unavailable"),
        ]
        await store.append(contentsOf: entries)
        await store.flush()

        let runs = await store.listRuns()
        XCTAssertEqual(runs.count, 1)
        let run = try XCTUnwrap(runs.first)
        XCTAssertTrue(run.isCurrent)
        XCTAssertEqual(run.startedAt, date(0))
        let readBack = await store.readRun(run)
        XCTAssertEqual(readBack, entries)
    }

    func testReadingSkipsMalformedLines() throws {
        let good = LogEntry(date: date(0), level: .error, category: .storage, message: "ok")
        var data = try good.jsonLine(using: LogEntry.makeEncoder())
        data.append(Data("{not json\n{\"level\":\"info\"}\n".utf8))
        data.append(try good.jsonLine(using: LogEntry.makeEncoder()))
        XCTAssertEqual(LogEntry.decodeLines(data), [good, good])
    }

    func testRunCapStopsWritingAndLeavesANote() async throws {
        let store = LogFileStore(baseDirectory: directory, launchDate: date(0), maxTotalBytes: 10_000, maxRunBytes: 1_000)
        for index in 0..<50 {
            await store.append(LogEntry(level: .info, category: .control, message: "line \(index) " + String(repeating: "x", count: 40)))
        }
        await store.flush()
        let runs = await store.listRuns()
        let run = try XCTUnwrap(runs.first)
        let entries = await store.readRun(run)
        XCTAssertLessThan(entries.count, 50)
        XCTAssertTrue(entries.last?.message.contains("later lines from this run are not saved") ?? false)
        XCTAssertLessThan(run.byteCount, 1_300)
    }

    // MARK: - Retention

    func testStartPrunesByCountKeepingTheNewestRuns() async throws {
        for index in 0..<12 {
            try makeRun(at: date(TimeInterval(index * 60)))
        }
        let launch = date(100_000)
        let store = LogFileStore(baseDirectory: directory, launchDate: launch, maxRuns: 10)
        await store.start()

        let names = try runFileNames()
        XCTAssertEqual(names.count, 10, "9 earlier runs plus this one")
        XCTAssertTrue(names.contains(LogFileStore.fileName(for: launch)))
        // The three oldest went.
        for index in 0..<3 {
            XCTAssertFalse(names.contains(LogFileStore.fileName(for: date(TimeInterval(index * 60)))))
        }
        XCTAssertTrue(names.contains(LogFileStore.fileName(for: date(11 * 60))))
    }

    func testStartPrunesBySizeLeavingRoomForThisRun() async throws {
        // Five 400-byte runs; 2,000 total minus 1,000 reserved for this run leaves room for two.
        for index in 0..<5 {
            try makeRun(at: date(TimeInterval(index)), size: 400)
        }
        let store = LogFileStore(
            baseDirectory: directory,
            launchDate: date(1_000),
            maxRuns: 10,
            maxTotalBytes: 2_000,
            maxRunBytes: 1_000
        )
        await store.start()

        let names = try runFileNames()
        XCTAssertEqual(names, [
            LogFileStore.fileName(for: date(4)),
            LogFileStore.fileName(for: date(3)),
            LogFileStore.fileName(for: date(1_000)),
        ])
    }

    func testPruneNeverDeletesTheCurrentRunOrOtherFiles() async throws {
        try makeRun(at: date(0))
        try Data("keep me".utf8).write(to: directory.appendingPathComponent("notes.txt"))
        let store = LogFileStore(baseDirectory: directory, launchDate: date(500))
        await store.start()
        await store.append(LogEntry(level: .info, category: .control, message: "hi"))

        let deleted = await store.prune(keepingRuns: 0, maxBytes: 0)
        XCTAssertEqual(deleted.map(\.lastPathComponent), [LogFileStore.fileName(for: date(0))])
        XCTAssertEqual(try runFileNames(), ["notes.txt", LogFileStore.fileName(for: date(500))])
    }

    func testEmptyEarlierRunsAreDeleted() async throws {
        try makeRun(at: date(0), size: 0)
        try makeRun(at: date(10), size: 5)
        let store = LogFileStore(baseDirectory: directory, launchDate: date(20))
        await store.start()
        XCTAssertEqual(try runFileNames(), [
            LogFileStore.fileName(for: date(10)),
            LogFileStore.fileName(for: date(20)),
        ])
    }

    func testAllRunFilesAreOldestFirst() async throws {
        try makeRun(at: date(20))
        try makeRun(at: date(10))
        let store = LogFileStore(baseDirectory: directory, launchDate: date(30))
        await store.start()
        let files = await store.allRunFiles().map(\.lastPathComponent)
        XCTAssertEqual(files, [10, 20, 30].map { LogFileStore.fileName(for: date(TimeInterval($0))) })
    }
}
