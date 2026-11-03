//
//  MacpardyMotion.swift
//  Macpardy
//
//  Timings and transitions for the Display window's animations. Whether
//  they run at all comes from `\.animationsEnabled`, which the Display sets
//  from the Settings toggle and macOS's Reduce Motion.
//

import SwiftUI

extension EnvironmentValues {
    @Entry var animationsEnabled = true
}

/// Where a round's board intro is up to: category titles appear one by one,
/// then the clue tiles turn over.
struct BoardReveal: Equatable {
    var categoriesShown: Int
    var cluesShown: Bool

    static let hidden = BoardReveal(categoriesShown: 0, cluesShown: false)
    static let complete = BoardReveal(categoriesShown: .max, cluesShown: true)
}

enum MacpardyMotion {

    // Board intro (the long one)
    static let categoryInterval: Duration = .milliseconds(800)
    static let pauseBeforeClues: Duration = .milliseconds(600)
    static let tileRowDelay = 0.12

    // Everything else is quick
    static let quick = Animation.easeInOut(duration: 0.3)
    static let flip = Animation.easeOut(duration: 0.5)
    static let scorePulse = Animation.easeOut(duration: 0.2)
    /// The host's arrow-key highlight moving between board tiles.
    static let tileHighlight = Animation.easeOut(duration: 0.12)

    static var categoryAppear: Animation { .spring(duration: 0.6, bounce: 0.35) }

    static func tileReveal(row: Int) -> Animation {
        .easeOut(duration: 0.4).delay(Double(row) * tileRowDelay)
    }

    /// A card turning to face the room, like a clue tile being picked.
    static func flipIn(animated: Bool) -> AnyTransition {
        guard animated else { return .identity }
        return .modifier(
            active: FlipEffect(angle: -90),
            identity: FlipEffect(angle: 0)
        )
        .animation(flip.delay(0.15))
    }
}

private struct FlipEffect: ViewModifier {
    let angle: Double

    func body(content: Content) -> some View {
        content
            .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.4)
            .opacity(angle == 0 ? 1 : 0)
    }
}
