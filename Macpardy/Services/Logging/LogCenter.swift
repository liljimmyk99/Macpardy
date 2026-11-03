//
//  LogCenter.swift
//  Macpardy
//
//  Collects every log line written through `AppLogger` (#81). Lines arrive
//  from any thread through `submit(_:)` and are
//  • kept in memory (the current run's last `capacity` lines) for the Logs window, and
//  • forwarded, in order, to `LogFileStore` to be saved.
//

import Foundation
import Observation

@Observable
final class LogCenter {

    static let shared = LogCenter()

    /// How many of the current run's lines the Logs window can show.
    nonisolated static let capacity = 5_000

    /// The current run's latest lines, oldest first.
    private(set) var entries: [LogEntry] = []

    @ObservationIgnored let store: LogFileStore
    @ObservationIgnored private var buffer: LogRingBuffer<LogEntry>
    @ObservationIgnored private var uiTask: Task<Void, Never>?
    @ObservationIgnored private var fileTask: Task<Void, Never>?

    init(store: LogFileStore = .shared, capacity: Int = LogCenter.capacity) {
        self.store = store
        self.buffer = LogRingBuffer(capacity: capacity)
    }

    // MARK: - Intake (any thread)

    private nonisolated static let uiChannel = AsyncStream<LogEntry>.makeStream(
        bufferingPolicy: .bufferingNewest(LogCenter.capacity)
    )
    private nonisolated static let fileChannel = AsyncStream<LogEntry>.makeStream(
        bufferingPolicy: .bufferingNewest(20_000)
    )

    /// Hands a line to the shared center. Safe from any thread or actor.
    /// Lines logged before `start()` wait in the channels.
    nonisolated static func submit(_ entry: LogEntry) {
        uiChannel.continuation.yield(entry)
        fileChannel.continuation.yield(entry)
    }

    // MARK: - Lifecycle

    /// Starts draining submitted lines. Call once, at launch, on the shared center.
    func start() {
        guard uiTask == nil else { return }
        let store = store
        fileTask = Task.detached(priority: .utility) {
            await store.start()
            for await entry in LogCenter.fileChannel.stream {
                await store.append(entry)
            }
        }
        uiTask = Task { [weak self] in
            for await entry in LogCenter.uiChannel.stream {
                self?.record(entry)
            }
        }
    }

    /// Adds a line to the in-memory buffer the Logs window shows.
    func record(_ entry: LogEntry) {
        buffer.append(entry)
        entries = buffer.elements
    }

    /// Writes any lines still waiting to disk (before an export or quit).
    func flush() async {
        await store.flush()
    }
}
