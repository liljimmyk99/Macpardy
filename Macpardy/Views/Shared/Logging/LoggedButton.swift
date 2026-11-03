//
//  LoggedButton.swift
//  Macpardy
//
//  A `Button` that logs the press before running its action (#87). Use it
//  instead of `Button` everywhere under Views/ (the `unlogged_tap` SwiftLint
//  rule checks), with a location such as "Control › Timer › Pause".
//

import SwiftUI

struct LoggedButton<Label: View>: View {

    let log: String
    var source: UIActionSource = .tap
    var category: LogCategory = .control
    var role: ButtonRole?
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    init(
        log: String,
        source: UIActionSource = .tap,
        category: LogCategory = .control,
        role: ButtonRole? = nil,
        action: @escaping () -> Void,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.log = log
        self.source = source
        self.category = category
        self.role = role
        self.action = action
        self.label = label
    }

    var body: some View {
        // swiftlint:disable:next unlogged_tap - this is the logged wrapper itself
        Button(role: role) {
            UIActionLog.action(log, source: source, category: category)
            action()
        } label: {
            label()
        }
    }
}

extension LoggedButton where Label == Text {

    init(
        _ titleKey: LocalizedStringKey,
        log: String,
        source: UIActionSource = .tap,
        category: LogCategory = .control,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) {
        self.init(log: log, source: source, category: category, role: role, action: action) {
            Text(titleKey)
        }
    }

    /// A title that isn't localized, such as a file name.
    init(
        verbatim title: String,
        log: String,
        source: UIActionSource = .tap,
        category: LogCategory = .control,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) {
        self.init(log: log, source: source, category: category, role: role, action: action) {
            Text(verbatim: title)
        }
    }
}

extension LoggedButton where Label == SwiftUI.Label<Text, Image> {

    init(
        _ titleKey: LocalizedStringKey,
        systemImage: String,
        log: String,
        source: UIActionSource = .tap,
        category: LogCategory = .control,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) {
        self.init(log: log, source: source, category: category, role: role, action: action) {
            SwiftUI.Label(titleKey, systemImage: systemImage)
        }
    }
}
