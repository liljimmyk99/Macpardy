//
//  AppSettings.swift
//  Macpardy
//
//  Keys, defaults and valid ranges for the preferences in the Settings
//  window. Values are read through an injectable `UserDefaults`, and every
//  read is clamped so a bad stored value can't reach the game.
//

import BuzzerCore
import Foundation

nonisolated enum AppSettings {

    enum Key {
        static let questionTimerSeconds = "settings.game.questionTimerSeconds"
        static let responseSeconds = "settings.game.responseSeconds"
        static let defaultTeamCount = "settings.game.defaultTeamCount"
        static let teamNamePrefix = "settings.game.teamName."
        static let buzzerPort = "settings.buzzers.port"
        static let buzzersEnabled = "settings.buzzers.enabled"
        static let buzzerServerMode = "settings.buzzers.serverMode"
        static let externalServerURL = "settings.buzzers.externalServerURL"
        static let animationsEnabled = "settings.display.animationsEnabled"
        static let walkthroughSeen = "settings.general.walkthroughSeen"
    }

    // MARK: - Question timer

    static let questionTimerRange = 5...60
    static let questionTimerStep = 5
    static let defaultQuestionTimerSeconds = 15

    static func clampQuestionTimerSeconds(_ value: Int) -> Int {
        let clamped = min(max(value, questionTimerRange.lowerBound), questionTimerRange.upperBound)
        // Round to the nearest step (ties go up).
        let steps = (Double(clamped) / Double(questionTimerStep)).rounded(.toNearestOrAwayFromZero)
        return Int(steps) * questionTimerStep
    }

    static func questionTimerSeconds(_ defaults: UserDefaults = .standard) -> Int {
        guard let stored = defaults.object(forKey: Key.questionTimerSeconds) as? Int else {
            return defaultQuestionTimerSeconds
        }
        return clampQuestionTimerSeconds(stored)
    }

    // MARK: - Response timer

    static let responseRange = 3...30
    static let defaultResponseSeconds = 5

    static func clampResponseSeconds(_ value: Int) -> Int {
        min(max(value, responseRange.lowerBound), responseRange.upperBound)
    }

    static func responseSeconds(_ defaults: UserDefaults = .standard) -> Int {
        guard let stored = defaults.object(forKey: Key.responseSeconds) as? Int else {
            return defaultResponseSeconds
        }
        return clampResponseSeconds(stored)
    }

    // MARK: - Teams

    static let teamCountRange = 1...Team.maxCount
    static let defaultTeamCountValue = 3
    static let teamNameMaxLength = 100

    static func clampTeamCount(_ value: Int) -> Int {
        min(max(value, teamCountRange.lowerBound), teamCountRange.upperBound)
    }

    static func defaultTeamCount(_ defaults: UserDefaults = .standard) -> Int {
        guard let stored = defaults.object(forKey: Key.defaultTeamCount) as? Int else {
            return defaultTeamCountValue
        }
        return clampTeamCount(stored)
    }

    static func clampTeamName(_ value: String) -> String {
        String(value.trimmingCharacters(in: .whitespacesAndNewlines).prefix(teamNameMaxLength))
    }

    /// The name set for team `index` (0-based), or `nil` to use the built-in "Team N".
    static func customTeamName(at index: Int, _ defaults: UserDefaults = .standard) -> String? {
        guard let stored = defaults.string(forKey: Key.teamNamePrefix + String(index)) else { return nil }
        let name = clampTeamName(stored)
        return name.isEmpty ? nil : name
    }

    // MARK: - Animations

    static let defaultAnimationsEnabled = true

    static func animationsEnabled(_ defaults: UserDefaults = .standard) -> Bool {
        guard let stored = defaults.object(forKey: Key.animationsEnabled) as? Bool else {
            return defaultAnimationsEnabled
        }
        return stored
    }

    /// The Display animates only when the setting is on and macOS's
    /// Reduce Motion is off.
    static func shouldAnimate(setting: Bool, reduceMotion: Bool) -> Bool {
        setting && !reduceMotion
    }

    // MARK: - Walkthrough

    static let defaultWalkthroughSeen = false

    /// Whether the first-time walkthrough (#76) has been finished or skipped.
    static func walkthroughSeen(_ defaults: UserDefaults = .standard) -> Bool {
        guard let stored = defaults.object(forKey: Key.walkthroughSeen) as? Bool else {
            return defaultWalkthroughSeen
        }
        return stored
    }

    // MARK: - Buzzer server

    /// Off means a game without phones (#74): no server, no join code or QR.
    static let defaultBuzzersEnabled = true

    static func buzzersEnabled(_ defaults: UserDefaults = .standard) -> Bool {
        guard let stored = defaults.object(forKey: Key.buzzersEnabled) as? Bool else {
            return defaultBuzzersEnabled
        }
        return stored
    }

    static let portRange = 1024...65535
    /// The buzzer package owns the default port; Settings shows it as an `Int`.
    static let defaultBuzzerPort = Int(BuzzerConstants.defaultPort)

    static func clampPort(_ value: Int) -> Int {
        min(max(value, portRange.lowerBound), portRange.upperBound)
    }

    static func buzzerPort(_ defaults: UserDefaults = .standard) -> UInt16 {
        guard let stored = defaults.object(forKey: Key.buzzerPort) as? Int else {
            return UInt16(defaultBuzzerPort)
        }
        return UInt16(clampPort(stored))
    }

    // MARK: - External buzzer server (#104)

    /// Where the buzzer server runs. The host token lives in the Keychain, not here.
    enum BuzzerServerMode: String, CaseIterable, Sendable {
        case builtIn
        case external
    }

    static let defaultBuzzerServerMode = BuzzerServerMode.builtIn

    static func buzzerServerMode(_ defaults: UserDefaults = .standard) -> BuzzerServerMode {
        defaults.string(forKey: Key.buzzerServerMode).flatMap(BuzzerServerMode.init(rawValue:)) ?? defaultBuzzerServerMode
    }

    static func externalServerURLText(_ defaults: UserDefaults = .standard) -> String {
        defaults.string(forKey: Key.externalServerURL) ?? ""
    }

    /// The server address the host typed, as a base URL, or `nil` if it isn't usable. The host
    /// token must only travel encrypted, so `https://` (or `wss://`) is required; plain `http://`
    /// is accepted for loopback only, to try a server on the same Mac. A bare host name gets `https://`.
    static func externalServerURL(from text: String) -> URL? {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if !trimmed.contains("://") { trimmed = "https://" + trimmed }
        guard var components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased(),
              let host = components.host?.lowercased(), !host.isEmpty,
              components.user == nil, components.password == nil,
              components.query == nil, components.fragment == nil else { return nil }
        let isLoopback = host == "localhost" || host == "127.0.0.1" || host == "::1" || host.hasSuffix(".localhost")
        switch scheme {
        case "https", "wss": components.scheme = "https"
        case "http" where isLoopback, "ws" where isLoopback: components.scheme = "http"
        default: return nil
        }
        // Keep the path (the server may sit under one) without a trailing slash.
        while components.path.hasSuffix("/") { components.path.removeLast() }
        return components.url
    }

    static func externalServerURL(_ defaults: UserDefaults = .standard) -> URL? {
        externalServerURL(from: externalServerURLText(defaults))
    }
}
