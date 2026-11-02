//
//  AppLogger.swift
//  Macpardy
//
//  Created by Jimmy Kane on 9/20/26.
//
//  The app's loggers, one per category. Each line goes to the unified system
//  log (Console.app) and to `LogCenter`, which shows it in the Logs window and
//  saves it to this run's log file (#81).
//

import Foundation
import OSLog

nonisolated enum AppLogger {
    public static let control = MacpardyLogger(category: .control)
    public static let display = MacpardyLogger(category: .display)
    public static let database = MacpardyLogger(category: .storage)
    public static let buzzer = MacpardyLogger(category: .buzzer)
    /// The Mac's own network (interfaces, Wi-Fi changes).
    public static let network = MacpardyLogger(category: .network)
}

/// Logs to `os.Logger` and to the app's own log. Messages are written
/// unredacted (`privacy: .public`): the log stays on this Mac unless the user
/// exports it, and redacted lines can't diagnose a phone that dropped.
nonisolated struct MacpardyLogger: Sendable {

    private static let subsystem = Bundle.main.bundleIdentifier ?? "Macpardy"

    let category: LogCategory
    private let logger: Logger

    init(category: LogCategory) {
        self.category = category
        self.logger = Logger(subsystem: Self.subsystem, category: category.osLogCategory)
    }

    /// - Parameters:
    ///   - team: The team the line is about, for the Logs window's team filter.
    ///   - remote: The phone's IP address, when the line is about one phone.
    func debug(_ message: String, team: String? = nil, remote: String? = nil) {
        logger.debug("\(message, privacy: .public)")
        emit(.debug, message, team: team, remote: remote)
    }

    func info(_ message: String, team: String? = nil, remote: String? = nil) {
        logger.info("\(message, privacy: .public)")
        emit(.info, message, team: team, remote: remote)
    }

    func notice(_ message: String, team: String? = nil, remote: String? = nil) {
        logger.notice("\(message, privacy: .public)")
        emit(.notice, message, team: team, remote: remote)
    }

    func warning(_ message: String, team: String? = nil, remote: String? = nil) {
        logger.warning("\(message, privacy: .public)")
        emit(.warning, message, team: team, remote: remote)
    }

    func error(_ message: String, team: String? = nil, remote: String? = nil) {
        logger.error("\(message, privacy: .public)")
        emit(.error, message, team: team, remote: remote)
    }

    /// Logs at a level chosen at run time.
    func log(_ level: LogLevel, _ message: String, team: String? = nil, remote: String? = nil) {
        switch level {
        case .debug: debug(message, team: team, remote: remote)
        case .info: info(message, team: team, remote: remote)
        case .notice: notice(message, team: team, remote: remote)
        case .warning: warning(message, team: team, remote: remote)
        case .error: error(message, team: team, remote: remote)
        }
    }

    private func emit(_ level: LogLevel, _ message: String, team: String?, remote: String?) {
        LogCenter.submit(LogEntry(
            level: level,
            category: category,
            message: message,
            teamName: team,
            remote: remote
        ))
    }
}
