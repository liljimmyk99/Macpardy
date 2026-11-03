//
//  GameCommandAvailability.swift
//  Macpardy
//
//  Which Game menu actions apply in the current phase. The menu and the
//  Control toolbar both read this so they can't disagree.
//

struct GameCommandAvailability: Equatable {

    let phase: GamePhase
    let hasSelectedGame: Bool
    /// The Buzzers setting; off means no phones this game (#74).
    var buzzersEnabled = true

    var canReturnToBoard: Bool {
        hasSelectedGame && (phase == .question || phase == .answer)
    }

    var canGoToFinal: Bool { hasSelectedGame && phase == .board }

    var canAdvanceRound: Bool { hasSelectedGame && phase == .board }

    var canRevealAnswer: Bool {
        hasSelectedGame && (phase == .question || phase == .finalMacpardyQuestion)
    }

    /// The timer is on screen on a clue and during the Final question and answer.
    var canControlTimer: Bool {
        hasSelectedGame && (phase == .question || phase == .finalMacpardyQuestion || phase == .finalMacpardyAnswer)
    }

    var canShowDisplay: Bool { hasSelectedGame }

    var canOpenBuzzers: Bool { hasSelectedGame && buzzersEnabled }

    /// The join screen can go over any phase but setup, which already shows it (#83).
    var canShowJoinScreen: Bool { canOpenBuzzers && phase != .setup }
}
