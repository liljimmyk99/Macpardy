//
//  LogRow.swift
//  Macpardy
//
//  One log line: time, level, category, message.
//

import SwiftUI

struct LogRow: View {

    let entry: LogEntry

    private static let timeFormat = Date.VerbatimFormatStyle(
        format: "\(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)):\(minute: .twoDigits):\(second: .twoDigits).\(secondFraction: .fractional(3))",
        timeZone: .current,
        calendar: Calendar(identifier: .gregorian)
    )

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(entry.date, format: Self.timeFormat)
                .font(MacpardyTheme.logMetaFont)
                .foregroundStyle(.secondary)

            Image(systemName: entry.level.symbolName)
                .font(MacpardyTheme.logMetaFont)
                .foregroundStyle(entry.level.color)
                .frame(width: 14)
                .help(Text(entry.level.titleKey))

            Text(entry.category.titleKey)
                .font(MacpardyTheme.logMetaFont)
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .leading)

            Text(verbatim: entry.message)
                .font(MacpardyTheme.logFont)
                .foregroundStyle(entry.level >= .warning ? entry.level.color : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 2)
    }
}
