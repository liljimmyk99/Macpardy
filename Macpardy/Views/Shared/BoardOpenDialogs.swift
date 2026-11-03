//
//  BoardOpenDialogs.swift
//  Macpardy
//
//  The file picker, Play / Edit choice, confirmations and error sheet for
//  `BoardOpenCoordinator`. Applied at the root of the Control window.
//

import SwiftUI
import UniformTypeIdentifiers

struct BoardOpenDialogs: ViewModifier {

    @Bindable var coordinator: BoardOpenCoordinator

    @Environment(\.openWindow) private var openWindow

    private func isPresented<T>(_ keyPath: ReferenceWritableKeyPath<BoardOpenCoordinator, T?>) -> Binding<Bool> {
        Binding(
            get: { coordinator[keyPath: keyPath] != nil },
            set: { if !$0 { coordinator[keyPath: keyPath] = nil } }
        )
    }

    func body(content: Content) -> some View {
        content
            .onAppear {
                coordinator.showEditor = { openWindow(id: "create-macpardy") }
            }
            .fileImporter(
                isPresented: $coordinator.isImporterPresented,
                allowedContentTypes: [.macpardyBoard, .json, .zip, .commaSeparatedText]
            ) { result in
                UIActionLog.filePicked("file importer 'Import board'", result)
                coordinator.handleImport(result)
            }
            .logPresentation("file importer 'Import board'", isPresented: coordinator.isImporterPresented)
            .confirmationDialog(
                "board_open.choice.title",
                isPresented: isPresented(\.pendingBoard),
                presenting: coordinator.pendingBoard
            ) { pending in
                LoggedButton("board_open.choice.play", log: "dialog 'Play or edit?' › Play") {
                    Task { await coordinator.play(pending) }
                }
                LoggedButton("board_open.choice.edit", log: "dialog 'Play or edit?' › Edit") {
                    coordinator.edit(pending)
                }
                LoggedButton("common.cancel", log: "dialog 'Play or edit?' › Cancel", role: .cancel) {}
            } message: { pending in
                Text("board_open.choice.message \(pending.url.lastPathComponent)")
            }
            .logPresentation("dialog 'Play or edit?'", isPresented: coordinator.pendingBoard != nil)
            .confirmationDialog(
                "board_open.replace.title",
                isPresented: isPresented(\.pendingReplacement),
                presenting: coordinator.pendingReplacement
            ) { pending in
                LoggedButton("board_open.replace.confirm", log: "dialog 'End the current game?' › End game", role: .destructive) {
                    coordinator.confirmReplacement(pending)
                }
                LoggedButton("common.cancel", log: "dialog 'End the current game?' › Cancel", role: .cancel) {}
            } message: { _ in
                Text("board_open.replace.message")
            }
            .logPresentation("dialog 'End the current game?'", isPresented: coordinator.pendingReplacement != nil)
            .confirmationDialog(
                "board_open.discard_edits.title",
                isPresented: isPresented(\.pendingEdit),
                presenting: coordinator.pendingEdit
            ) { pending in
                LoggedButton("board_open.discard_edits.confirm", log: "dialog 'Discard editor changes?' › Discard", role: .destructive) {
                    coordinator.confirmEdit(pending)
                }
                LoggedButton("common.cancel", log: "dialog 'Discard editor changes?' › Cancel", role: .cancel) {}
            } message: { _ in
                Text("board_open.discard_edits.message")
            }
            .logPresentation("dialog 'Discard editor changes?'", isPresented: coordinator.pendingEdit != nil)
            .sheet(item: $coordinator.loadError) { report in
                BoardLoadErrorView(report: report)
            }
            .logPresentation("sheet 'Board load error'", isPresented: coordinator.loadError != nil)
    }
}

extension View {
    func boardOpenDialogs(_ coordinator: BoardOpenCoordinator) -> some View {
        modifier(BoardOpenDialogs(coordinator: coordinator))
    }
}
