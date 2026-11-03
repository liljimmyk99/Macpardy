//
//  LogFilter.swift
//  Macpardy
//
//  What the Logs window shows: which run, category, level, team and text.
//

import Foundation

/// Where the Logs window reads its lines from.
nonisolated enum LogSource: Hashable, Sendable {
    /// This launch, updating live.
    case live
    /// An earlier launch's saved file.
    case run(LogRun)
}

nonisolated struct LogFilter: Equatable, Sendable {

    /// nil shows every category, so the window opens with both the
    /// buzzer server's logs and the application's own logs visible.
    var category: LogCategory? = nil
    var minimumLevel: LogLevel = .info
    var searchText = ""
    /// nil shows every team (and lines about no team).
    var teamName: String?

    func matches(_ entry: LogEntry) -> Bool {
        if let category, entry.category != category { return false }
        if entry.level < minimumLevel { return false }
        if let teamName, entry.teamName != teamName { return false }
        let query = searchText.trimmingCharacters(in: .whitespaces)
        if !query.isEmpty {
            let haystacks = [entry.message, entry.teamName, entry.remote].compactMap { $0 }
            if !haystacks.contains(where: { $0.localizedStandardContains(query) }) { return false }
        }
        return true
    }

    func apply(_ entries: [LogEntry]) -> [LogEntry] {
        entries.filter(matches)
    }

    /// Team names that appear in `entries`, sorted, for the team filter.
    static func teamNames(in entries: [LogEntry]) -> [String] {
        Set(entries.compactMap(\.teamName)).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }
}
