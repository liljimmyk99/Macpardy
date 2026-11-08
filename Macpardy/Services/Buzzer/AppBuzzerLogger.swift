//
//  AppBuzzerLogger.swift
//  Macpardy
//
//  Connects the buzzer package's logging hook to `AppLogger` (#100), so lines
//  logged by BuzzerCore land in the system log and the Logs window, with their
//  team and remote filters, like the app's own buzzer lines.
//

import BuzzerCore
import Foundation

nonisolated struct AppBuzzerLogger: BuzzerLogging {

    private let logger: MacpardyLogger

    init(logger: MacpardyLogger = AppLogger.buzzer) {
        self.logger = logger
    }

    func log(_ level: BuzzerLogLevel, _ message: String, kind: BuzzerLogKind, team: String?, remote: String?) {
        logger.log(LogLevel(level), kind.prefix + message, team: team, remote: remote)
    }
}

extension LogLevel {
    nonisolated init(_ level: BuzzerLogLevel) {
        switch level {
        case .debug: self = .debug
        case .info: self = .info
        case .notice: self = .notice
        case .warning: self = .warning
        case .error: self = .error
        }
    }
}
