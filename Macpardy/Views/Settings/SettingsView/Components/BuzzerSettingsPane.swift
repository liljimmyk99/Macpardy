//
//  BuzzerSettingsPane.swift
//  Macpardy
//

import SwiftUI

struct BuzzerSettingsPane: View {

    @AppStorage(AppSettings.Key.buzzersEnabled)
    private var buzzersEnabled = AppSettings.defaultBuzzersEnabled

    @AppStorage(AppSettings.Key.buzzerPort)
    private var port = AppSettings.defaultBuzzerPort

    /// What's in the field while typing; committed (and clamped) on Return or when the field loses focus.
    @State private var draft = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        Form {
            Section {
                Toggle("settings.buzzers.enabled", isOn: $buzzersEnabled)
            } footer: {
                Text("settings.buzzers.enabled_footer")
            }

            Section {
                TextField("settings.buzzers.port", text: $draft)
                    .focused($isFocused)
                    .onSubmit(commit)
                    .onChange(of: isFocused) { _, focused in
                        if !focused { commit() }
                    }
                    .disabled(!buzzersEnabled)
                    .logCommit("Settings › Buzzers › Port", text: draft, isFocused: isFocused)
            } footer: {
                Text("settings.buzzers.port_footer \(AppSettings.portRange.lowerBound) \(AppSettings.portRange.upperBound)")
            }
        }
        .formStyle(.grouped)
        .onAppear { draft = String(AppSettings.clampPort(port)) }
    }

    private func commit() {
        let value = AppSettings.clampPort(Int(draft.trimmingCharacters(in: .whitespaces)) ?? port)
        port = value
        draft = String(value)
    }
}
