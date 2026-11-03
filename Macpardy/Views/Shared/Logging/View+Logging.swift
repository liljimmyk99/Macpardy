//
//  View+Logging.swift
//  Macpardy
//
//  View modifiers for the verbose log (#87): logged tap gestures, sheets and
//  alerts appearing and going away, and text fields committing.
//

import SwiftUI

extension View {

    /// `onTapGesture` that logs `tap: <log>` first.
    func onLoggedTapGesture(
        _ log: String,
        count: Int = 1,
        category: LogCategory = .control,
        perform action: @escaping () -> Void
    ) -> some View {
        // swiftlint:disable:next unlogged_tap - this is the logged wrapper itself
        onTapGesture(count: count) {
            UIActionLog.action(log, category: category)
            action()
        }
    }

    /// Logs `nav: <name> presented` / `nav: <name> dismissed` for a sheet,
    /// popover, alert, confirmation dialog or file picker. What the user chose
    /// is logged by the dialog's buttons or the picker's completion.
    func logPresentation(_ name: String, isPresented: Bool, category: LogCategory = .control) -> some View {
        onChange(of: isPresented) { _, presented in
            AppLogger.logger(for: category).nav("\(name) \(presented ? "presented" : "dismissed")")
        }
    }

    /// `app: window <name> opened` / `closed`, on a window's root view.
    func logWindowLifecycle(_ name: String, category: LogCategory = .control) -> some View {
        onAppear { AppLogger.logger(for: category).app("window \(name) opened") }
            .onDisappear { AppLogger.logger(for: category).app("window \(name) closed") }
    }

    /// Logs a text field's edit when it's committed: on Return, when the field
    /// loses focus, or when it goes away. Only the location and the new
    /// length are logged, never the text.
    func logCommit(_ name: String, text: String, category: LogCategory = .control) -> some View {
        modifier(OwnFocusLogCommit(name: name, text: text, category: category))
    }

    /// For a field that already tracks its own focus: pass whether it's focused.
    func logCommit(_ name: String, text: String, isFocused: Bool, category: LogCategory = .control) -> some View {
        modifier(LogCommitModifier(name: name, text: text, isFocused: isFocused, category: category))
    }
}

private struct OwnFocusLogCommit: ViewModifier {

    let name: String
    let text: String
    let category: LogCategory

    @FocusState private var isFocused: Bool

    func body(content: Content) -> some View {
        content
            .focused($isFocused)
            .modifier(LogCommitModifier(name: name, text: text, isFocused: isFocused, category: category))
    }
}

private struct LogCommitModifier: ViewModifier {

    let name: String
    let text: String
    let isFocused: Bool
    let category: LogCategory

    /// The text as of the last commit; nil until the field first appears.
    @State private var committed: String?

    func body(content: Content) -> some View {
        content
            .onSubmit(commit)
            .onChange(of: isFocused) { _, focused in
                if !focused { commit() }
            }
            .onAppear { committed = text }
            .onDisappear(perform: commit)
    }

    private func commit() {
        guard let committed, committed != text else { return }
        AppLogger.logger(for: category).state("\(name) edited (\(LogValue.length(of: committed)) → \(text.count))")
        self.committed = text
    }
}
