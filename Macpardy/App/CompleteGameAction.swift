//
//  CompleteGameAction.swift
//  Macpardy
//
//  Lets the Control window finish a game without owning the app's
//  "a game is selected" state (#82).
//

import SwiftUI

extension EnvironmentValues {
    /// Ends the game in progress and sends the Control window back to the
    /// launch screen. `MacpardyApp` sets it; elsewhere it does nothing.
    @Entry var completeGame: () -> Void = {}
}
