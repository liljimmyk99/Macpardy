//
//  MacpardyTheme.swift
//  Macpardy
//

import SwiftUI

enum MacpardyTheme {

    // Colors live in Assets.xcassets (Theme/ and Team/); Tuist generates `MacpardyAsset`.
    static let boardBlue = MacpardyAsset.boardBlue.swiftUIColor
    static let tileBlue = MacpardyAsset.tileBlue.swiftUIColor
    static let tileIncomplete = MacpardyAsset.tileIncomplete.swiftUIColor
    static let tileHover = MacpardyAsset.tileHover.swiftUIColor
    static let tilePlayed = MacpardyAsset.tilePlayed.swiftUIColor
    static let panelBlue = MacpardyAsset.panelBlue.swiftUIColor
    static let gold = MacpardyAsset.gold.swiftUIColor
    static let warning = MacpardyAsset.warning.swiftUIColor
    static let mutedText = MacpardyAsset.mutedText.swiftUIColor
    static let clueBackground = MacpardyAsset.clueBackground.swiftUIColor
    static let controlBackground = Color(nsColor: .windowBackgroundColor)

    // Logs window: one color per level
    static let logDebug = MacpardyAsset.logDebug.swiftUIColor
    static let logInfo = MacpardyAsset.logInfo.swiftUIColor
    static let logNotice = MacpardyAsset.logNotice.swiftUIColor
    static let logWarning = MacpardyAsset.logWarning.swiftUIColor
    static let logError = MacpardyAsset.logError.swiftUIColor

    // SF Pro is the system font, so there are no font files to bundle; sizes live here.
    static let categoryFont = Font.system(size: 22, weight: .bold, design: .default)
    static let valueFont = Font.system(size: 36, weight: .bold, design: .default)
    static let clueFont = Font.system(size: 48, weight: .regular, design: .default)
    static let answerFont = Font.system(size: 56, weight: .bold, design: .default)
    static let titleFont = Font.system(size: 32, weight: .bold, design: .default)
    static let scoreFont = Font.system(size: 28, weight: .bold, design: .default)
    static let timerFont = Font.system(size: 72, weight: .bold, design: .monospaced)
    static let dailyDoubleFont = Font.system(size: 96, weight: .bold, design: .default)
    static let displayJoinCodeFont = Font.system(size: 72, weight: .black, design: .monospaced)
    static let displayJoinURLFont = Font.system(size: 28, weight: .semibold, design: .monospaced)

    // Control window
    static let controlCategoryFont = Font.system(size: 16, weight: .heavy, design: .default)
    static let controlValueFont = Font.system(size: 34, weight: .heavy, design: .default)
    static let controlTeamScoreFont = Font.system(size: 28, weight: .heavy, design: .default).monospacedDigit()
    static let badgeFont = Font.system(size: 10, weight: .heavy, design: .default)
    static let joinCodeFont = Font.system(size: 30, weight: .heavy, design: .monospaced)
    static let setupJoinCodeFont = Font.system(size: 48, weight: .black, design: .monospaced)
    static let controlClueFont = Font.system(size: 32, weight: .semibold, design: .default)
    static let controlResponseFont = Font.system(size: 22, weight: .heavy, design: .default)
    static let controlTimerFont = Font.system(size: 48, weight: .bold, design: .monospaced)

    // Start screen
    static let launchTitleFont = Font.system(size: 88, weight: .black, design: .default)
    static let launchTileIconFont = Font.system(size: 40, weight: .semibold, design: .default)
    static let shortcutFont = Font.system(size: 12, weight: .semibold, design: .monospaced)

    // Logs window
    static let logFont = Font.system(size: 12, weight: .regular, design: .monospaced)
    static let logMetaFont = Font.system(size: 11, weight: .medium, design: .monospaced)
}
