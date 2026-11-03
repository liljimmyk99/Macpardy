//
//  LogsView+Extension.swift
//  Macpardy
//

import SwiftUI

extension LogsView {

    // MARK: - Data

    /// Every line of the selected source, before filtering.
    var sourceEntries: [LogEntry] {
        switch source {
        case .live: logCenter.entries
        case .run: loadedEntries
        }
    }

    var visibleEntries: [LogEntry] {
        filter.apply(sourceEntries)
    }

    var subtitle: Text {
        Text("logs.subtitle.count \(visibleEntries.count) \(sourceEntries.count)")
    }

    func reloadRuns() async {
        previousRuns = await logCenter.store.listRuns().filter { !$0.isCurrent }
    }

    func loadSelectedRun() async {
        guard case .run(let run) = source else {
            loadedEntries = []
            return
        }
        loadedEntries = await logCenter.store.readRun(run)
        // Keep the team filter only if that team appears in this run.
        if let team = filter.teamName, !LogFilter.teamNames(in: loadedEntries).contains(team) {
            filter.teamName = nil
        }
        scrollPosition.scrollTo(edge: .bottom)
        isFollowingLatest = true
    }

    // MARK: - List

    var logList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(visibleEntries) { entry in
                    LogRow(entry: entry)
                }
            }
            .textSelection(.enabled)
            .padding(.vertical, 6)
        }
        .scrollPosition($scrollPosition)
        .defaultScrollAnchor(.bottom)
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentOffset.y + geometry.containerSize.height >= geometry.contentSize.height - 24
        } action: { _, isAtBottom in
            isFollowingLatest = isAtBottom
        }
        .onChange(of: visibleEntries.last?.id) {
            if isFollowingLatest {
                scrollPosition.scrollTo(edge: .bottom)
            }
        }
    }

    @ViewBuilder
    var emptyState: some View {
        if visibleEntries.isEmpty {
            ContentUnavailableView(
                "logs.empty.title",
                systemImage: "doc.text.magnifyingglass",
                description: Text(sourceEntries.isEmpty ? "logs.empty.no_lines" : "logs.empty.filtered")
            )
        }
    }

    @ViewBuilder
    var jumpToLatestButton: some View {
        if !isFollowingLatest, !visibleEntries.isEmpty {
            Button("logs.button.jump_to_latest", systemImage: "arrow.down.to.line") {
                isFollowingLatest = true
                scrollPosition.scrollTo(edge: .bottom)
            }
            .buttonStyle(.borderedProminent)
            .padding(16)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Picker("logs.picker.run", selection: $source) {
                Text("logs.run.live").tag(LogSource.live)
                if !previousRuns.isEmpty {
                    Divider()
                    ForEach(previousRuns) { run in
                        Text(run.startedAt, format: .dateTime.year().month().day().hour().minute().second())
                            .tag(LogSource.run(run))
                    }
                }
            }
            .pickerStyle(.menu)
            .help("logs.picker.run.help")
        }

        ToolbarItemGroup {
            Picker("logs.picker.category", selection: $filter.category) {
                Text("logs.category.all").tag(LogCategory?.none)
                Divider()
                ForEach(LogCategory.allCases, id: \.self) { category in
                    Text(category.titleKey).tag(LogCategory?.some(category))
                }
            }
            .pickerStyle(.menu)
            .help("logs.picker.category")

            Picker("logs.picker.level", selection: $filter.minimumLevel) {
                ForEach(LogLevel.allCases, id: \.self) { level in
                    Text(level.titleKey).tag(level)
                }
            }
            .pickerStyle(.menu)
            .help("logs.picker.level.help")

            Picker("logs.picker.team", selection: $filter.teamName) {
                Text("logs.team.all").tag(String?.none)
                let names = LogFilter.teamNames(in: sourceEntries)
                if !names.isEmpty {
                    Divider()
                    ForEach(names, id: \.self) { name in
                        Text(verbatim: name).tag(String?.some(name))
                    }
                }
            }
            .pickerStyle(.menu)
            .help("logs.picker.team")

            Button {
                prepareExport()
            } label: {
                if isPreparingExport {
                    ProgressView().controlSize(.small)
                } else {
                    Label("logs.button.export", systemImage: "square.and.arrow.up")
                }
            }
            .disabled(isPreparingExport)
            .help("logs.button.export.help")
        }
    }

    // MARK: - Export

    func prepareExport() {
        isPreparingExport = true
        let snapshot = SystemInfoReport.Snapshot(
            buzzerPort: buzzerState.baseURL?.port ?? Int(AppSettings.buzzerPort()),
            serverRunning: buzzerState.isRunning,
            joinedPhones: buzzerState.connectedClientCount,
            teamCount: gameState.game.teams.count,
            addresses: LocalNetworkInterfaces.current()
        )
        let store = logCenter.store
        Task {
            defer { isPreparingExport = false }
            let files = await store.allRunFiles()
            do {
                let data = try await Task.detached(priority: .userInitiated) {
                    try LogExporter.makeArchive(runFiles: files, systemInfo: SystemInfoReport.make(snapshot))
                }.value
                exportDocument = LogArchiveDocument(data: data)
                exportFileName = LogExporter.archiveFileName(for: snapshot.exportedAt)
                isExporting = true
            } catch {
                AppLogger.database.error("Couldn't build the log export: \(error.localizedDescription)")
                exportError = error.localizedDescription
            }
        }
    }

    func exportFinished(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            AppLogger.database.info("Exported logs to \(url.lastPathComponent)")
        case .failure(let error):
            AppLogger.database.error("Couldn't save the log export: \(error.localizedDescription)")
            exportError = error.localizedDescription
        }
        exportDocument = nil
    }
}

// MARK: - Labels

extension LogCategory {
    /// A literal key per case: String Catalog lookup needs a fixed key,
    /// not one built by interpolating `rawValue` at runtime.
    var titleKey: LocalizedStringKey {
        switch self {
        case .control: "logs.category.control"
        case .display: "logs.category.display"
        case .storage: "logs.category.storage"
        case .buzzer: "logs.category.buzzer"
        case .network: "logs.category.network"
        }
    }
}

extension LogLevel {
    /// A literal key per case: String Catalog lookup needs a fixed key,
    /// not one built by interpolating `rawValue` at runtime.
    var titleKey: LocalizedStringKey {
        switch self {
        case .debug: "logs.level.debug"
        case .info: "logs.level.info"
        case .notice: "logs.level.notice"
        case .warning: "logs.level.warning"
        case .error: "logs.level.error"
        }
    }

    var color: Color {
        switch self {
        case .debug: MacpardyTheme.logDebug
        case .info: MacpardyTheme.logInfo
        case .notice: MacpardyTheme.logNotice
        case .warning: MacpardyTheme.logWarning
        case .error: MacpardyTheme.logError
        }
    }
}
