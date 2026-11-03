//
//  VerboseLogging.swift
//  Macpardy
//
//  The `.debug` lines that let a run be reconstructed from its log alone (#87):
//  every tap, menu command, shortcut, window or sheet change, phone action and
//  model state change. Each starts with a searchable prefix:
//
//    tap:       a button or tap gesture          state:  a model value changed
//    menu:      a menu bar command               nav:    a window, sheet, alert or picker
//    shortcut:  a keyboard shortcut              app:    app lifecycle
//    phone:     something a phone did
//
//  Content rule: log IDs, titles, team names, scores, wagers and file names,
//  never clue text, answer text, typed editor text or Final answers. For typed
//  text, log only that it changed and its length.
//

import Foundation
import Synchronization

extension AppLogger {
    /// The logger for a category, for helpers that take one as a parameter.
    nonisolated static func logger(for category: LogCategory) -> MacpardyLogger {
        switch category {
        case .control: control
        case .display: display
        case .storage: database
        case .buzzer: buzzer
        case .network: network
        }
    }
}

nonisolated extension MacpardyLogger {

    /// Logs `state: <field>: <old> → <new> (<reason>)`, or nothing when the value didn't change.
    func change<T: Equatable>(
        _ field: String,
        from old: T,
        to new: T,
        reason: String? = nil,
        team: String? = nil
    ) {
        guard old != new else { return }
        let suffix = reason.map { " (\($0))" } ?? ""
        debug("state: \(field): \(LogValue.describe(old)) → \(LogValue.describe(new))\(suffix)", team: team)
    }

    /// A state line that isn't a single `old → new` value, e.g. "Editor undo: editClue r1.c2.q3.clue".
    func state(_ message: String, team: String? = nil) {
        debug("state: \(message)", team: team)
    }

    func tap(_ message: String) {
        debug("tap: \(message)")
    }

    func menu(_ message: String) {
        debug("menu: \(message)")
    }

    /// `shortcut: ⌘R Reveal answer`.
    func shortcut(_ keys: String, _ message: String) {
        debug("shortcut: \(keys) \(message)")
    }

    func nav(_ message: String) {
        debug("nav: \(message)")
    }

    func app(_ message: String) {
        debug("app: \(message)")
    }

    func phone(_ message: String, team: String? = nil, remote: String? = nil) {
        debug("phone: \(message)", team: team, remote: remote)
    }
}

// MARK: - Safe descriptions

/// A model that has a one-line form safe to log: IDs and titles, never clue or answer text.
nonisolated protocol LogDescribable {
    var logDescription: String { get }
}

nonisolated enum LogValue {

    /// `logDescription` for `LogDescribable` values, "none" for nil, else `String(describing:)`.
    static func describe(_ value: Any) -> String {
        if let describable = value as? LogDescribable { return describable.logDescription }
        let mirror = Mirror(reflecting: value)
        if mirror.displayStyle == .optional {
            guard let wrapped = mirror.children.first?.value else { return "none" }
            return describe(wrapped)
        }
        if let text = value as? String { return "'\(text)'" }
        return String(describing: value)
    }

    /// "length 12", for typed text that must not be logged.
    static func length(of text: String) -> String {
        "length \(text.count)"
    }
}

/// Text already formatted for the log ("Team 2 'Blue'"), logged as-is
/// rather than quoted like other strings.
nonisolated struct LogLabel: Equatable, LogDescribable {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var logDescription: String { text }
}

extension GamePhase: nonisolated LogDescribable {
    /// The case name, e.g. `finalMacpardyQuestion`.
    nonisolated var logDescription: String {
        switch self {
        case .setup: "setup"
        case .board: "board"
        case .question: "question"
        case .answer: "answer"
        case .dailyDouble: "dailyDouble"
        case .finalMacpardyCategory: "finalMacpardyCategory"
        case .finalMacpardyQuestion: "finalMacpardyQuestion"
        case .finalMacpardyAnswer: "finalMacpardyAnswer"
        }
    }
}

extension MacpardyRound: nonisolated LogDescribable {
    /// "R1", "R2" or "Final".
    nonisolated var logDescription: String {
        switch self {
        case .macpardy: "R1"
        case .doubleMacpardy: "R2"
        case .finalMacpardy: "Final"
        }
    }
}

extension Question: nonisolated LogDescribable {
    /// "$400 DD #1A2B3C4D". The value and id only: without its board a clue has
    /// no location, and its text is never logged. `GameState` adds the round
    /// and category.
    nonisolated var logDescription: String {
        "$\(value)\(isDailyDouble ? " DD" : "") #\(id.uuidString.prefix(8))"
    }
}

extension Category: nonisolated LogDescribable {
    /// "'Rivers' (5 clues)".
    nonisolated var logDescription: String {
        "'\(title)' (\(questions.count) clues)"
    }
}

extension Team: nonisolated LogDescribable {
    /// "'Blue' $400". `GameState` adds the team's number.
    nonisolated var logDescription: String {
        "'\(name)' $\(score)"
    }
}

extension BoardPosition: nonisolated LogDescribable {
    /// "C3 row 2", 1-based.
    nonisolated var logDescription: String {
        "C\(column + 1) row \(row + 1)"
    }
}

// MARK: - Test capture

#if DEBUG
/// Collects the entries logged inside `capture(_:)`, so tests can check what
/// was logged. Debug builds only; `LogCenter.submit` checks it.
nonisolated final class LogCapture: Sendable {

    @TaskLocal static var current: LogCapture?

    private let storage = Mutex<[LogEntry]>([])

    var entries: [LogEntry] { storage.withLock { $0 } }
    var messages: [String] { entries.map(\.message) }

    func record(_ entry: LogEntry) {
        storage.withLock { $0.append(entry) }
    }

    /// Runs `body` and returns what it logged.
    static func capture(_ body: () throws -> Void) rethrows -> LogCapture {
        let capture = LogCapture()
        try $current.withValue(capture) { try body() }
        return capture
    }

    static func capture(_ body: () async throws -> Void) async rethrows -> LogCapture {
        let capture = LogCapture()
        try await $current.withValue(capture) { try await body() }
        return capture
    }
}
#endif
