//
//  SettingsChangeLog.swift
//  Macpardy
//
//  Logs every Settings change as `state: AppSettings.<name>: old → new` (#87).
//  The Settings panes write straight to UserDefaults (`@AppStorage`), so this
//  watches the stored values instead of each control. Team names are left to
//  their text fields, which log on commit rather than on every keystroke.
//

import Foundation

final class SettingsChangeLog {

    static let shared = SettingsChangeLog()

    /// The settings watched, by the name used in the log.
    nonisolated static let watched: [(name: String, read: @Sendable (UserDefaults) -> String)] = [
        ("questionTimerSeconds", { "\(AppSettings.questionTimerSeconds($0))s" }),
        ("responseSeconds", { "\(AppSettings.responseSeconds($0))s" }),
        ("defaultTeamCount", { "\(AppSettings.defaultTeamCount($0))" }),
        ("animationsEnabled", { "\(AppSettings.animationsEnabled($0))" }),
        ("buzzersEnabled", { "\(AppSettings.buzzersEnabled($0))" }),
        ("buzzerPort", { "\(AppSettings.buzzerPort($0))" }),
    ]

    private let defaults: UserDefaults
    private var values: [String: String] = [:]
    private var observer: NSObjectProtocol?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Takes the starting values and logs changes from here on.
    func start() {
        guard observer == nil else { return }
        values = Self.read(defaults)
        observer = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: defaults,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.check() }
        }
    }

    /// Logs whatever changed since the last check.
    func check() {
        let current = Self.read(defaults)
        for (name, _) in Self.watched {
            AppLogger.control.change("AppSettings.\(name)", from: LogLabel(values[name] ?? "none"), to: LogLabel(current[name] ?? "none"))
        }
        values = current
    }

    nonisolated static func read(_ defaults: UserDefaults) -> [String: String] {
        Dictionary(uniqueKeysWithValues: watched.map { ($0.name, $0.read(defaults)) })
    }
}
