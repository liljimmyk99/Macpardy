//
//  WalkthroughCoordinator.swift
//  Macpardy
//
//  Lets the Help menu and the launch screen show the first-time walkthrough
//  (#76). The sheet itself lives on the launch screen.
//

import Foundation
import Observation

@Observable
final class WalkthroughCoordinator {

    /// Whether the walkthrough sheet is on screen.
    var isPresented = false

    /// Set by the app: the walkthrough can only open from the launch screen.
    @ObservationIgnored var isAvailable: () -> Bool = { true }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Opens it on the very first launch.
    func presentIfFirstRun() {
        guard !AppSettings.walkthroughSeen(defaults) else { return }
        isPresented = true
    }

    /// Opens it on request (Help menu, launch screen link).
    func request() {
        guard isAvailable() else { return }
        isPresented = true
    }

    /// Closes it, remembering that the host has seen it.
    func finish() {
        isPresented = false
        defaults.set(true, forKey: AppSettings.Key.walkthroughSeen)
    }
}
