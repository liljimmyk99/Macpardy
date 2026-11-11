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

    @AppStorage(AppSettings.Key.buzzerServerMode)
    private var serverModeRaw = AppSettings.defaultBuzzerServerMode.rawValue

    @AppStorage(AppSettings.Key.externalServerURL)
    private var externalURL = ""

    /// What's in the field while typing; committed (and clamped) on Return or when the field loses focus.
    @State private var draft = ""
    @FocusState private var isFocused: Bool

    @State private var urlDraft = ""
    @FocusState private var isURLFocused: Bool

    /// Typed here, saved to the Keychain on commit. Never kept in `UserDefaults`, never logged.
    @State private var tokenDraft = ""
    @FocusState private var isTokenFocused: Bool
    @State private var hasSavedToken = false

    private let tokenStore: any HostTokenStore = KeychainHostTokenStore()

    private var mode: Binding<AppSettings.BuzzerServerMode> {
        Binding(
            get: { AppSettings.BuzzerServerMode(rawValue: serverModeRaw) ?? AppSettings.defaultBuzzerServerMode },
            set: { serverModeRaw = $0.rawValue }
        )
    }

    private var isExternal: Bool { mode.wrappedValue == .external }

    var body: some View {
        Form {
            Section {
                Toggle("settings.buzzers.enabled", isOn: $buzzersEnabled)
            } footer: {
                Text("settings.buzzers.enabled_footer")
            }

            Section {
                Picker("settings.buzzers.server_mode", selection: mode) {
                    Text("settings.buzzers.server_mode.built_in").tag(AppSettings.BuzzerServerMode.builtIn)
                    Text("settings.buzzers.server_mode.external").tag(AppSettings.BuzzerServerMode.external)
                }
                .pickerStyle(.radioGroup)
                .disabled(!buzzersEnabled)
                .onChange(of: serverModeRaw) { old, new in
                    AppLogger.control.nav("Settings › Buzzers › Server \(old) → \(new)")
                }
            } footer: {
                Text("settings.buzzers.server_mode_footer")
            }

            if isExternal {
                externalSection
            } else {
                builtInSection
            }
        }
        .formStyle(.grouped)
        .onAppear {
            draft = String(AppSettings.clampPort(port))
            urlDraft = externalURL
            hasSavedToken = tokenStore.hasToken
        }
    }

    private var builtInSection: some View {
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

    private var externalSection: some View {
        Section {
            TextField("settings.buzzers.external.url", text: $urlDraft, prompt: Text("settings.buzzers.external.url_prompt"))
                .focused($isURLFocused)
                .onSubmit(commitURL)
                .onChange(of: isURLFocused) { _, focused in
                    if !focused { commitURL() }
                }
                .disabled(!buzzersEnabled)
                .autocorrectionDisabled()
                .logCommit("Settings › Buzzers › Server URL", text: urlDraft, isFocused: isURLFocused)

            SecureField(
                "settings.buzzers.external.token",
                text: $tokenDraft,
                prompt: Text(hasSavedToken ? "settings.buzzers.external.token_saved" : "settings.buzzers.external.token_prompt")
            )
            .focused($isTokenFocused)
            .onSubmit(commitToken)
            .onChange(of: isTokenFocused) { _, focused in
                if !focused { commitToken() }
            }
            .disabled(!buzzersEnabled)

            if hasSavedToken {
                LoggedButton("settings.buzzers.external.remove_token", log: "Settings › Buzzers › Remove host token") {
                    tokenStore.setToken("")
                    tokenDraft = ""
                    hasSavedToken = false
                }
            }
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                if !urlDraft.isEmpty, AppSettings.externalServerURL(from: urlDraft) == nil {
                    Text("settings.buzzers.external.url_invalid")
                        .foregroundStyle(.red)
                }
                Text("settings.buzzers.external.footer")
            }
        }
    }

    private func commit() {
        let value = AppSettings.clampPort(Int(draft.trimmingCharacters(in: .whitespaces)) ?? port)
        port = value
        draft = String(value)
    }

    private func commitURL() {
        let trimmed = urlDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        urlDraft = trimmed
        externalURL = trimmed
    }

    /// Saves a newly typed token to the Keychain, then clears the field. An empty field leaves
    /// the saved token alone; use Remove to delete it.
    private func commitToken() {
        guard !tokenDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        tokenStore.setToken(tokenDraft)
        tokenDraft = ""
        hasSavedToken = tokenStore.hasToken
        AppLogger.control.state("Buzzer host token saved")
    }
}
