//
//  NewGameView.swift
//  Macpardy
//

import OSLog
import SwiftUI
import UniformTypeIdentifiers

/// The "New Game" sheet: build a game in the editor, or import one from CSV.
struct NewGameView: View {

    @Environment(\.dismiss) private var dismiss

    /// Opens the game editor.
    let onBuildInEditor: () -> Void

    /// Starts a game with boards imported from CSV.
    let onPlay: ([MacpardyBoard]) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("new_game.title")
                .font(.largeTitle.bold())

            HStack(alignment: .top, spacing: 20) {
                BuildInEditorOption(onBuildInEditor: onBuildInEditor)
                CSVImportOption(onPlay: onPlay)
            }

            HStack {
                Spacer()
                Button("common.cancel", role: .cancel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding(24)
        .frame(minWidth: 820, minHeight: 520)
    }
}

// MARK: - Build in the editor

private struct BuildInEditorOption: View {

    let onBuildInEditor: () -> Void

    var body: some View {
        NewGameOptionCard(
            title: "new_game.editor.title",
            systemImage: "square.grid.3x3",
            description: "new_game.editor.description"
        ) {
            LargeButton(title: "new_game.editor.button", systemImage: "pencil", tint: .orange) {
                onBuildInEditor()
            }
        }
    }
}

// MARK: - Import from CSV

private struct CSVImportOption: View {

    let onPlay: ([MacpardyBoard]) -> Void

    @State private var templateDocument: CSVTemplateDocument?
    @State private var showTemplateExporter = false
    @State private var showCSVImporter = false

    @State private var issues: [CSVBoardImporter.Issue] = []
    /// Cells that still hold the template's default text, awaiting the user's decision.
    @State private var defaultTextWarnings: [CSVBoardImporter.Issue] = []
    @State private var importedTitle = ""
    @State private var jsonDocument: MacpardyJSONBoardDocument?
    @State private var showJSONExporter = false
    @State private var statusMessage: String?

    var body: some View {
        NewGameOptionCard(
            title: "new_game.csv.title",
            systemImage: "tablecells",
            description: "new_game.csv.description"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Button {
                        templateDocument = CSVTemplateDocument(data: CSVBoardTemplate.makeData())
                        showTemplateExporter = true
                    } label: {
                        Label("new_game.csv.download_template", systemImage: "arrow.down.doc")
                    }
                    .fileExporter(
                        isPresented: $showTemplateExporter,
                        document: templateDocument,
                        contentType: .commaSeparatedText,
                        defaultFilename: CSVBoardTemplate.suggestedFileName
                    ) { result in
                        handleTemplateSaved(result)
                    }

                    Button {
                        showCSVImporter = true
                    } label: {
                        Label("new_game.csv.upload", systemImage: "arrow.up.doc")
                    }
                    .buttonStyle(.borderedProminent)
                    .fileImporter(
                        isPresented: $showCSVImporter,
                        allowedContentTypes: [.commaSeparatedText, .plainText]
                    ) { result in
                        handleCSVPicked(result)
                    }
                }

                if let statusMessage {
                    Text(statusMessage)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                if jsonDocument != nil, !defaultTextWarnings.isEmpty {
                    DefaultTextWarningView(
                        warnings: defaultTextWarnings,
                        onCancel: {
                            jsonDocument = nil
                            defaultTextWarnings = []
                        },
                        onContinue: {
                            defaultTextWarnings = []
                        }
                    )
                } else if let jsonDocument {
                    ReadyToPlayView(title: importedTitle, boards: jsonDocument.boards) {
                        showJSONExporter = true
                    }
                    .fileExporter(
                        isPresented: $showJSONExporter,
                        document: jsonDocument,
                        contentType: .json,
                        defaultFilename: FileManagerService().defaultJSONFilename(for: importedTitle)
                    ) { result in
                        handleJSONSaved(result)
                    }
                }

                if !issues.isEmpty {
                    CSVIssueList(issues: issues)
                }
            }
        }
    }

    private func handleTemplateSaved(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            AppLogger.database.info("Saved CSV template to \(url.lastPathComponent)")
            statusMessage = String(localized: "new_game.csv.template_saved \(url.lastPathComponent)")
        case .failure(let error):
            if (error as? CocoaError)?.code != .userCancelled {
                statusMessage = String(localized: "new_game.csv.save_failed \(error.localizedDescription)")
            }
            AppLogger.database.error("Failed to save CSV template: \(error.localizedDescription)")
        }
    }

    private func handleCSVPicked(_ result: Result<URL, Error>) {
        jsonDocument = nil
        issues = []
        defaultTextWarnings = []
        statusMessage = nil

        switch result {
        case .success(let url):
            let title = url.deletingPathExtension().lastPathComponent
            do {
                let data = try FileManagerService().readData(from: url)
                let boards = try CSVBoardImporter.importBoards(from: data, title: title)
                defaultTextWarnings = CSVBoardImporter.defaultTextWarnings(from: data)
                importedTitle = title
                jsonDocument = MacpardyJSONBoardDocument(boards: boards)
                AppLogger.database.info("Imported CSV \(url.lastPathComponent)")
            } catch let error as CSVBoardImporter.ImportError {
                issues = error.issues
                AppLogger.database.info("CSV \(url.lastPathComponent) has \(error.issues.count) problem(s)")
            } catch {
                statusMessage = String(localized: "new_game.csv.read_failed \(error.localizedDescription)")
                AppLogger.database.error("Failed to read CSV: \(error.localizedDescription)")
            }
        case .failure(let error):
            AppLogger.database.error("CSV picker failed: \(error.localizedDescription)")
        }
    }

    private func handleJSONSaved(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            AppLogger.database.info("Saved imported board to \(url.lastPathComponent)")
            if let boards = jsonDocument?.boards {
                onPlay(boards)
            }
        case .failure(let error):
            if (error as? CocoaError)?.code != .userCancelled {
                statusMessage = String(localized: "new_game.csv.save_failed \(error.localizedDescription)")
            }
            AppLogger.database.error("Failed to save imported board: \(error.localizedDescription)")
        }
    }
}

// MARK: - Components

private struct NewGameOptionCard<Content: View>: View {

    let title: LocalizedStringKey
    let systemImage: String
    let description: LocalizedStringKey
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.title2.bold())
            Text(description)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            content
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(MacpardyTheme.boardBlue.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(MacpardyTheme.gold.opacity(0.4), lineWidth: 1.5)
        )
    }
}

/// Shown once a CSV has imported cleanly.
private struct ReadyToPlayView: View {

    let title: String
    let boards: [MacpardyBoard]
    let onSaveAndPlay: () -> Void

    private var clueCount: Int {
        boards.reduce(0) { $0 + $1.categories.reduce(0) { $0 + $1.questions.count } }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text("new_game.csv.ready \(title) \(clueCount)")
            } icon: {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
            Text("new_game.csv.ready_detail")
                .font(.callout)
                .foregroundStyle(.secondary)
            LargeButton(title: "new_game.csv.save_and_play", systemImage: "play.fill") {
                onSaveAndPlay()
            }
        }
    }
}

/// Shown when an imported CSV still has the template's default text: the
/// user can go back and edit it, or continue anyway.
private struct DefaultTextWarningView: View {

    let warnings: [CSVBoardImporter.Issue]
    let onCancel: () -> Void
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CSVIssueList(issues: warnings, isWarning: true)
            HStack {
                Button("common.cancel", role: .cancel, action: onCancel)
                Button("new_game.csv.continue_anyway", action: onContinue)
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}

/// Lists every problem in an uploaded CSV with the row and column to fix.
/// With `isWarning`, lists cells that are allowed but worth a second look.
struct CSVIssueList: View {

    let issues: [CSVBoardImporter.Issue]
    var isWarning = false

    private var tint: Color { isWarning ? MacpardyTheme.warning : .red }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                if isWarning {
                    Text("new_game.csv.warning_title \(issues.count)")
                } else {
                    Text("new_game.csv.errors_title \(issues.count)")
                }
            } icon: {
                Image(systemName: isWarning ? "exclamationmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(tint)
            }
            .font(.headline)

            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(issues) { issue in
                        VStack(alignment: .leading, spacing: 2) {
                            if let location = issue.location {
                                Text(location)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            Text(issue.message)
                                .textSelection(.enabled)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(tint.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
            .frame(minHeight: 120, maxHeight: 260)
        }
    }
}

#Preview {
    NewGameView(onBuildInEditor: {}, onPlay: { _ in })
}
