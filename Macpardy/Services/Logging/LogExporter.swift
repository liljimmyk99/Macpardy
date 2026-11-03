//
//  LogExporter.swift
//  Macpardy
//
//  Builds the "Export Logs…" zip (#81):
//
//    Macpardy-Logs-2026-11-02-1403.zip
//    ├── system-info.txt
//    ├── logs/macpardy-<launch>.log     one readable line per entry
//    └── raw/macpardy-<launch>.jsonl    the run files as stored
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers
import ZIPFoundation

nonisolated enum LogExporter {

    enum ExportError: Error {
        case archiveFailed
    }

    /// `Macpardy-Logs-2026-11-02-1403.zip`, in local time.
    static func archiveFileName(for date: Date, timeZone: TimeZone = .current) -> String {
        let stamp = date.formatted(
            .verbatim(
                "\(year: .defaultDigits)-\(month: .twoDigits)-\(day: .twoDigits)-\(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased))\(minute: .twoDigits)",
                timeZone: timeZone,
                calendar: Calendar(identifier: .gregorian)
            )
        )
        return "Macpardy-Logs-\(stamp).zip"
    }

    /// One `time level [category] message` line per entry.
    static func textLog(fromJSONLines data: Data) -> String {
        LogEntry.decodeLines(data).map(\.textLine).joined(separator: "\n") + "\n"
    }

    /// Zips `runFiles` (as text and raw JSON Lines) with `systemInfo`.
    static func makeArchive(runFiles: [URL], systemInfo: String) throws -> Data {
        var files: [(path: String, data: Data)] = [("system-info.txt", Data(systemInfo.utf8))]
        for url in runFiles {
            guard let raw = try? Data(contentsOf: url) else { continue }
            let base = url.deletingPathExtension().lastPathComponent
            files.append(("logs/\(base).log", Data(textLog(fromJSONLines: raw).utf8)))
            files.append(("raw/\(base).jsonl", raw))
        }

        let archive = try Archive(accessMode: .create)
        for file in files {
            let data = file.data
            try archive.addEntry(
                with: file.path,
                type: .file,
                uncompressedSize: Int64(data.count),
                compressionMethod: .deflate,
                provider: { position, size in
                    let start = Int(position)
                    return data.subdata(in: start..<min(start + size, data.count))
                }
            )
        }
        guard let data = archive.data else { throw ExportError.archiveFailed }
        return data
    }
}

/// The exported zip, for `.fileExporter`.
struct LogArchiveDocument: FileDocument {

    static var readableContentTypes: [UTType] { [.zip] }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
