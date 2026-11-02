//
//  GameSnapshot.swift
//  Macpardy
//
//  Created by Jimmy Kane on 10/18/26.
//

import Foundation

struct GameSnapshot: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let savedAt: Date
    let game: Game
    let phase: GamePhase
    let currentQuestionID: UUID?
    let currentCategoryTitle: String?
    let dailyDoubleTeamID: UUID?
    let dailyDoubleWager: Int
    let finalMacpardyWagers: [UUID: Int]
    /// Final answers from phones (#80). Optional so saves from before it load.
    let finalMacpardyAnswers: [UUID: String]?
    /// The team whose Final answer the Display is showing (#80). Optional, as above.
    let finalMacpardyRevealedTeamID: UUID?

    init(
        schemaVersion: Int = GameSnapshot.currentSchemaVersion,
        savedAt: Date = Date(),
        game: Game,
        phase: GamePhase,
        currentQuestionID: UUID? = nil,
        currentCategoryTitle: String? = nil,
        dailyDoubleTeamID: UUID? = nil,
        dailyDoubleWager: Int = 0,
        finalMacpardyWagers: [UUID: Int] = [:],
        finalMacpardyAnswers: [UUID: String]? = nil,
        finalMacpardyRevealedTeamID: UUID? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.savedAt = savedAt
        self.game = game
        self.phase = phase
        self.currentQuestionID = currentQuestionID
        self.currentCategoryTitle = currentCategoryTitle
        self.dailyDoubleTeamID = dailyDoubleTeamID
        self.dailyDoubleWager = dailyDoubleWager
        self.finalMacpardyWagers = finalMacpardyWagers
        self.finalMacpardyAnswers = finalMacpardyAnswers
        self.finalMacpardyRevealedTeamID = finalMacpardyRevealedTeamID
    }

    init(from gameState: GameState) {
        self.schemaVersion = Self.currentSchemaVersion
        self.savedAt = Date()
        self.game = gameState.game
        self.phase = gameState.phase
        self.currentQuestionID = gameState.currentQuestion?.id
        self.currentCategoryTitle = gameState.currentCategoryTitle
        self.dailyDoubleTeamID = gameState.dailyDoubleTeamID
        self.dailyDoubleWager = gameState.dailyDoubleWager
        self.finalMacpardyWagers = gameState.finalMacpardyWagers
        self.finalMacpardyAnswers = gameState.finalMacpardyAnswers.isEmpty ? nil : gameState.finalMacpardyAnswers
        self.finalMacpardyRevealedTeamID = gameState.finalMacpardyRevealedTeamID
    }
}
