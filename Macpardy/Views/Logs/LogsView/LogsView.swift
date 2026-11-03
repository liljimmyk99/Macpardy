//
//  LogsView.swift
//  Macpardy
//
//  The Logs window (#81): this run's log live, or an earlier run's saved
//  file, filtered by category, level, team and text.
//

import SwiftUI
import UniformTypeIdentifiers

struct LogsView: View {

    @Environment(LogCenter.self) var logCenter
    @Environment(GameState.self) var gameState
    @Environment(BuzzerState.self) var buzzerState

    @State var source: LogSource = .live
    /// Earlier runs, newest first.
    @State var previousRuns: [LogRun] = []
    /// The lines of the selected earlier run.
    @State var loadedEntries: [LogEntry] = []
    @State var filter = LogFilter()

    /// True while the list is scrolled to the bottom, so new lines keep it there.
    @State var isFollowingLatest = true
    @State var scrollPosition = ScrollPosition(edge: .bottom)

    @State var isPreparingExport = false
    @State var isExporting = false
    @State var exportDocument: LogArchiveDocument?
    @State var exportFileName = ""
    @State var exportError: String?

    var body: some View {
        logList
            .overlay { emptyState }
            .overlay(alignment: .bottomTrailing) { jumpToLatestButton }
            .toolbar { toolbarContent }
            .searchable(text: $filter.searchText, placement: .toolbar, prompt: Text("logs.search.prompt"))
            .navigationSubtitle(subtitle)
            .frame(minWidth: 760, minHeight: 360)
            .task { await reloadRuns() }
            .task(id: source) { await loadSelectedRun() }
            .fileExporter(
                isPresented: $isExporting,
                document: exportDocument,
                contentType: .zip,
                defaultFilename: exportFileName,
                onCompletion: exportFinished
            )
            .fileDialogMessage(Text("logs.export.privacy_note"))
            .alert(
                "logs.export.error.title",
                isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } }),
                presenting: exportError
            ) { _ in
                Button("common.ok") {}
            } message: { message in
                Text(message)
            }
    }
}

#Preview {
    LogsView()
        .environment(LogCenter.shared)
        .environment(GameState())
        .environment(BuzzerState())
}
