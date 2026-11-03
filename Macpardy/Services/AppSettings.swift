//
//  AppSettings.swift
//  Macpardy
//
//  Keys, defaults and valid ranges for the preferences in the Settings
//  window. Values are read through an injectable `UserDefaults`, and every
//  read is clamped so a bad stored value can't reach the game.
//

import Foundation

nonisolated enum AppSettings {

    enum Key {
        static let questionTimerSeconds = "settings.game.questionTimerSeconds"
        static let responseSeconds = "settings.game.responseSeconds"
        static let defaultTeamCount = "settings.game.defaultTeamCount"
        static let teamNamePrefix = "settings.game.teamName."
        static let buzzerPort = "settings.buzzers.port"
        static let buzzersEnabled = "settings.buzzers.enabled"
        static let animationsEnabled = "settings.display.animationsEnabled"
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
    static let defaultBuzzerPort = 8472

    static func clampPort(_ value: Int) -> Int {
        min(max(value, portRange.lowerBound), portRange.upperBound)
    }

    static func buzzerPort(_ defaults: UserDefaults = .standard) -> UInt16 {
        guard let stored = defaults.object(forKey: Key.buzzerPort) as? Int else {
            return UInt16(defaultBuzzerPort)
        }
        return UInt16(clampPort(stored))
    }
}
