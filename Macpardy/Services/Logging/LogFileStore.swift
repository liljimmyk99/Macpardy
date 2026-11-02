//
//  LogFileStore.swift
//  Macpardy
//
//  Persists the app's log (#81): one JSON Lines file per launch in
//  Application Support/Macpardy/Logs, named after the launch time.
//
//  • Appends through a FileHandle, batching writes and flushing at most about
//    once a second (or sooner when the batch gets large).
//  • On launch, deletes the oldest runs so at most `maxRuns` files and
//    `maxTotalBytes` remain, counting the room the new run may use.
//  • Caps a single run at `maxRunBytes`; past that, lines are dropped.
//
//  Never logs through `AppLogger`: that would feed its own output back in.
//

import Foundation
import OSLog

/// One launch's log file.
nonisolated struct LogRun: Identifiable, Hashable, Sendable {
    let url: URL
    let startedAt: Date
    let byteCount: Int
    /// The run this app launch is writing.
    let isCurrent: Bool

    var id: URL { url }
}

actor LogFileStore {

    static let shared = LogFileStore()

    nonisolated static let defaultMaxRuns = 10
    nonisolated static let defaultMaxTotalBytes = 20 * 1024 * 1024
    nonisolated static let defaultMaxRunBytes = 5 * 1024 * 1024

    /// Pending lines are written once they reach this size, without waiting for the timer.
    private static let flushThresholdBytes = 64 * 1024
    private static let fileNamePrefix = "macpardy-"
    private static let fileExtension = "jsonl"

    /// Problems with the log files themselves go straight to the system log.
    private static let selfLog = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Macpardy", category: "Logging")

    private let fileManager: FileManager
    private let baseDirectory: URL?
    private let launchDate: Date
    let maxRuns: Int
    let maxTotalBytes: Int
    let maxRunBytes: Int

    private let encoder = LogEntry.makeEncoder()
    private var didStart = false
    private var handle: FileHandle?
    private(set) var currentRunURL: URL?
    private var pending = Data()
    private var bytesWritten = 0
    private var reachedRunCap = false
    private var flushTask: Task<Void, Never>?

    /// - Parameters:
    ///   - baseDirectory: Where the run files go. Defaults to
    ///     Application Support/Macpardy/Logs; tests pass a temporary directory.
    ///   - launchDate: Names this run's file.
    init(
        fileManager: FileManager = .default,
        baseDirectory: URL? = nil,
        launchDate: Date = Date(),
        maxRuns: Int = LogFileStore.defaultMaxRuns,
        maxTotalBytes: Int = LogFileStore.defaultMaxTotalBytes,
        maxRunBytes: Int = LogFileStore.defaultMaxRunBytes
    ) {
        self.fileManager = fileManager
        self.baseDirectory = baseDirectory
        self.launchDate = launchDate
        self.maxRuns = max(1, maxRuns)
        self.maxTotalBytes = maxTotalBytes
        self.maxRunBytes = min(maxRunBytes, maxTotalBytes)
    }

    var directory: URL? {
        if let baseDirectory { return baseDirectory }
        return fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Macpardy", isDirectory: true)
            .appendingPathComponent("Logs", isDirectory: true)
    }

    // MARK: - Lifecycle

    /// Prunes old runs and opens this run's file. Called once; `append` calls it if needed.
    func start() {
        guard !didStart else { return }
        didStart = true
        guard let directory else { return }
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            // Leave room for this run: one file and up to `maxRunBytes`.
            prune(keepingRuns: maxRuns - 1, maxBytes: maxTotalBytes - maxRunBytes)

            let url = directory.appendingPathComponent(Self.fileName(for: launchDate))
            if !fileManager.fileExists(atPath: url.path) {
                fileManager.createFile(atPath: url.path, contents: nil)
            }
            let handle = try FileHandle(forWritingTo: url)
            bytesWritten = Int(try handle.seekToEnd())
            self.handle = handle
            currentRunURL = url
        } catch {
            Self.selfLog.error("Can't open the log file: \(String(describing: error), privacy: .public)")
        }
    }

    // MARK: - Writing

    func append(_ entry: LogEntry) {
        append(contentsOf: [entry])
    }

    func append(contentsOf entries: [LogEntry]) {
        start()
        guard handle != nil, !reachedRunCap else { return }
        for entry in entries {
            guard let line = try? entry.jsonLine(using: encoder) else { continue }
            if bytesWritten + pending.count + line.count > maxRunBytes {
                capReached(at: entry.date)
                break
            }
            pending.append(line)
        }
        if pending.count >= Self.flushThresholdBytes {
            flush()
        } else if !pending.isEmpty, flushTask == nil {
            flushTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(1))
                await self?.flush()
            }
        }
    }

    /// Writes pending lines to disk now.
    func flush() {
        flushTask?.cancel()
        flushTask = nil
        guard let handle, !pending.isEmpty else { return }
        do {
            try handle.write(contentsOf: pending)
            bytesWritten += pending.count
        } catch {
            Self.selfLog.error("Can't write the log file: \(String(describing: error), privacy: .public)")
        }
        pending.removeAll(keepingCapacity: true)
    }

    private func capReached(at date: Date) {
        reachedRunCap = true
        let note = LogEntry(
            date: date,
            level: .warning,
            category: .control,
            message: "Log file reached \(maxRunBytes / 1024 / 1024) MB; later lines from this run are not saved"
        )
        if let line = try? note.jsonLine(using: encoder) {
            pending.append(line)
        }
    }

    // MARK: - Reading

    /// Every retained run, newest first.
    func listRuns() -> [LogRun] {
        flush()
        guard let directory,
              let urls = try? fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.fileSizeKey],
                options: [.skipsHiddenFiles]
              ) else { return [] }

        return urls.compactMap { url -> LogRun? in
            guard let startedAt = Self.launchDate(fromFileName: url.lastPathComponent) else { return nil }
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            return LogRun(
                url: url,
                startedAt: startedAt,
                byteCount: size,
                isCurrent: url.lastPathComponent == currentRunURL?.lastPathComponent
            )
        }
        .sorted { $0.startedAt > $1.startedAt }
    }

    func readRun(_ run: LogRun) -> [LogEntry] {
        flush()
        guard let data = try? Data(contentsOf: run.url) else { return [] }
        return LogEntry.decodeLines(data)
    }

    /// Every retained run file, oldest first, with this run's pending lines written.
    func allRunFiles() -> [URL] {
        listRuns().reversed().map(\.url)
    }

    // MARK: - Retention

    /// Deletes the oldest runs (other than the current one) until at most
    /// `keepingRuns` remain and they add up to at most `maxBytes`. Empty runs
    /// (a launch that logged nothing, e.g. a unit-test host) are always deleted.
    /// Returns the deleted files.
    @discardableResult
    func prune(keepingRuns: Int, maxBytes: Int) -> [URL] {
        let previous = listRuns().filter { !$0.isCurrent }
        var kept = 0
        var keptBytes = 0
        var deleted: [URL] = []
        for run in previous {
            if run.byteCount > 0, kept < keepingRuns, keptBytes + run.byteCount <= maxBytes {
                kept += 1
                keptBytes += run.byteCount
            } else {
                do {
                    try fileManager.removeItem(at: run.url)
                    deleted.append(run.url)
                } catch {
                    Self.selfLog.error("Can't delete old log \(run.url.lastPathComponent, privacy: .public): \(String(describing: error), privacy: .public)")
                }
            }
        }
        return deleted
    }

    // MARK: - File names

    /// `macpardy-20261102T140322Z.jsonl`: ISO 8601 basic format, so no colons.
    nonisolated static func fileName(for date: Date) -> String {
        "\(fileNamePrefix)\(date.formatted(fileDateStyle)).\(fileExtension)"
    }

    nonisolated static func launchDate(fromFileName name: String) -> Date? {
        guard name.hasPrefix(fileNamePrefix), name.hasSuffix(".\(fileExtension)") else { return nil }
        let stamp = name.dropFirst(fileNamePrefix.count).dropLast(fileExtension.count + 1)
        return try? Date(String(stamp), strategy: fileDateStyle)
    }

    private nonisolated static let fileDateStyle = Date.ISO8601FormatStyle(
        dateSeparator: .omitted,
        dateTimeSeparator: .standard,
        timeSeparator: .omitted,
        timeZone: .gmt
    )
}
