//
//  ControlView+Extension.swift
//  Macpardy
//
//  Created by Jimmy Kane on 10/10/26.
//

import SwiftUI

extension ControlView {
    /// What the Game menu and the toolbar offer in the current phase.
    var commandAvailability: GameCommandAvailability {
        GameCommandAvailability(phase: gameState.phase, hasSelectedGame: true, buzzersEnabled: buzzersEnabled)
    }

    /// The current round's title, e.g. "General Categories".
    var navigationTitleText: Text {
        if let board = gameState.game.currentBoard {
            Text(board.title)
        } else {
            Text(phaseNavigationTitle)
        }
    }

    /// Round progress on the board, the clue on a question, the phase everywhere else.
    var navigationSubtitleText: Text {
        switch gameState.phase {
        case .board:
            if let board = gameState.game.currentBoard {
                let cluesLeft = board.categories.reduce(0) { total, category in
                    total + category.questions.filter { !$0.hasBeenPlayed }.count
                }
                return Text("control.subtitle.board \(gameState.game.currentRound + 1) \(gameState.game.rounds.count) \(cluesLeft)")
            }
        case .question, .answer:
            if let question = gameState.currentQuestion {
                let category = gameState.currentCategoryTitle ?? ""
                if gameState.dailyDoubleTeamID != nil {
                    return Text("control.subtitle.daily_double \(category) \(gameState.dailyDoubleWager)")
                }
                return Text("control.subtitle.question \(category) \(question.value)")
            }
        default:
            break
        }
        return Text(phaseNavigationTitle)
    }

    /// What the bottom team strip offers, or nil to hide it where the phase has
    /// its own team controls.
    var teamStripMode: TeamScoreStripMode? {
        switch gameState.phase {
        case .board:
            .manual
        case .question, .answer:
            if gameState.dailyDoubleTeamID != nil {
                .clue(amount: gameState.dailyDoubleWager, dailyDoubleTeamID: gameState.dailyDoubleTeamID)
            } else {
                .clue(amount: gameState.currentQuestion?.value ?? 0, dailyDoubleTeamID: nil)
            }
        case .dailyDouble, .finalMacpardyCategory:
            .readOnly
        case .setup, .finalMacpardyQuestion, .finalMacpardyAnswer:
            nil
        }
    }

    /// Phases laid out to fill the window; the rest scroll.
    var fillsWindow: Bool {
        switch gameState.phase {
        case .setup, .board, .question, .answer: true
        case .dailyDouble, .finalMacpardyCategory, .finalMacpardyQuestion, .finalMacpardyAnswer: false
        }
    }

    private var phaseNavigationTitle: LocalizedStringKey {
        switch gameState.phase {
        case .setup: "control.nav_title.setup"
        case .board: "control.nav_title.board"
        case .question, .answer: "control.nav_title.question"
        case .dailyDouble: "control.nav_title.daily_double"
        case .finalMacpardyCategory: "control.nav_title.final_macpardy_category"
        case .finalMacpardyQuestion, .finalMacpardyAnswer: "control.nav_title.final_macpardy_question"
        }
    }
}
