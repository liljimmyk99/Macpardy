//
//  WalkthroughStep.swift
//  Macpardy
//
//  The pages of the first-time walkthrough (#76). Pure data and navigation
//  rules, so they can be tested without a view.
//

import Foundation

nonisolated enum WalkthroughStep: Int, CaseIterable, Identifiable {
    case welcome
    case startGame
    case connectBuzzers
    case runGame
    case createBoard

    var id: Int { rawValue }

    var systemImage: String {
        switch self {
        case .welcome: "sparkles.tv"
        case .startGame: "play.circle.fill"
        case .connectBuzzers: "iphone.radiowaves.left.and.right"
        case .runGame: "rectangle.grid.3x2.fill"
        case .createBoard: "square.and.pencil"
        }
    }

    /// Localization key stems: `walkthrough.<stem>.title` and `.body`.
    var keyStem: String {
        switch self {
        case .welcome: "walkthrough.welcome"
        case .startGame: "walkthrough.start_game"
        case .connectBuzzers: "walkthrough.buzzers"
        case .runGame: "walkthrough.run_game"
        case .createBoard: "walkthrough.create"
        }
    }

    var titleKey: String { keyStem + ".title" }
    var bodyKey: String { keyStem + ".body" }

    /// Extra bullet keys shown under the body (`.tip1`, `.tip2`, …).
    var tipKeys: [String] {
        let count: Int
        switch self {
        case .welcome: count = 0
        case .startGame: count = 3
        case .connectBuzzers: count = 4
        case .runGame: count = 3
        case .createBoard: count = 2
        }
        return (0..<count).map { "\(keyStem).tip\($0 + 1)" }
    }

    /// Only the buzzer page has an action: opening the macOS firewall settings.
    var hasFirewallAction: Bool { self == .connectBuzzers }

    var isFirst: Bool { self == Self.allCases.first }
    var isLast: Bool { self == Self.allCases.last }

    var next: WalkthroughStep? { Self(rawValue: rawValue + 1) }
    var previous: WalkthroughStep? { Self(rawValue: rawValue - 1) }
}
