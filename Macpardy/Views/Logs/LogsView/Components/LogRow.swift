//
//  LogRow.swift
//  Macpardy
//
//  One log line: time, category, message.
//

import SwiftUI

struct LogRow: View {

    let entry: LogEntry

    private static let timeFormat = Date.VerbatimFormatStyle(
        format: "\(hour: .twoDigits(clock: .twelveHour, hourCycle: .oneBased)):\(minute: .twoDigits):\(second: .twoDigits) \(dayPeriod: .standard(.abbreviated))",
        timeZone: .current,
        calendar: Calendar(identifier: .gregorian)
    )

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(entry.date, format: Self.timeFormat)
                .font(MacpardyTheme.logMetaFont)
                .foregroundStyle(.secondary)
                .frame(width: 84, alignment: .leading)

            Text(entry.category.titleKey)
                .font(MacpardyTheme.logMetaFont)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: 90, alignment: .leading)

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
