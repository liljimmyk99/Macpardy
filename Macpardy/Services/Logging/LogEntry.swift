//
//  LogEntry.swift
//  Macpardy
//
//  One line in the app's own log (#81). Written as JSON Lines by
//  `LogFileStore` and shown in the Logs window.
//

import Foundation

/// How serious a log line is. Ordered from least to most severe.
nonisolated enum LogLevel: String, Codable, CaseIterable, Comparable, Sendable {
    case debug, info, notice, warning, error

    static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rank < rhs.rank
    }

    private var rank: Int {
        switch self {
        case .debug: 0
        case .info: 1
        case .notice: 2
        case .warning: 3
        case .error: 4
        }
    }
}

/// The part of the app a log line comes from. The raw values are also the
/// `os.Logger` category names (capitalized) and the `[category]` in exports.
nonisolated enum LogCategory: String, Codable, CaseIterable, Sendable {
    case control, display, storage, buzzer, network

    /// Category name used for `os.Logger`, as Console.app shows it.
    var osLogCategory: String {
        switch self {
        case .control: "Control"
        case .display: "Display"
        case .storage: "Storage"
        case .buzzer: "Buzzer"
        case .network: "Network"
        }
    }
}

nonisolated struct LogEntry: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let date: Date
    let level: LogLevel
    let category: LogCategory
    let message: String
    /// The team a buzzer line is about, for the Logs window's team filter.
    let teamName: String?
    /// The phone's IP address, when the line is about one phone.
    let remote: String?

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        level: LogLevel,
        category: LogCategory,
        message: String,
        teamName: String? = nil,
        remote: String? = nil
    ) {
        self.id = id
        self.date = date
        self.level = level
        self.category = category
        self.message = message
        self.teamName = teamName
        self.remote = remote
    }
}

// MARK: - JSON Lines

extension LogEntry {

    nonisolated static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(date.formatted(LogEntry.timestampStyle))
        }
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }

    nonisolated static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let text = try container.decode(String.self)
            return try Date(text, strategy: LogEntry.timestampStyle)
        }
        return decoder
    }

    /// ISO 8601 with milliseconds, so entries within one second keep their order.
    nonisolated static let timestampStyle = Date.ISO8601FormatStyle(includingFractionalSeconds: true)

    /// One JSON object followed by a newline.
    nonisolated func jsonLine(using encoder: JSONEncoder) throws -> Data {
        var data = try encoder.encode(self)
        data.append(0x0A)
        return data
    }

    /// Decodes every valid line of a JSON Lines file. Lines that don't decode
    /// (a run cut off mid-write, a hand-edited file) are skipped.
    nonisolated static func decodeLines(_ data: Data) -> [LogEntry] {
        let decoder = makeDecoder()
        return data.split(separator: 0x0A).compactMap { line in
            try? decoder.decode(LogEntry.self, from: Data(line))
        }
    }
}

// MARK: - Plain text

extension LogEntry {

    /// `2026-11-02 14:03:22.123 info [buzzer] message`, used in exported `.log` files.
    nonisolated var textLine: String {
        let time = date.formatted(
            .verbatim(
                "\(year: .defaultDigits)-\(month: .twoDigits)-\(day: .twoDigits) \(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)):\(minute: .twoDigits):\(second: .twoDigits).\(secondFraction: .fractional(3))",
                timeZone: .current,
                calendar: Calendar(identifier: .gregorian)
            )
        )
        let level = level.rawValue.padding(toLength: 7, withPad: " ", startingAt: 0)
        return "\(time) \(level) [\(category.rawValue)] \(message)"
    }
}
