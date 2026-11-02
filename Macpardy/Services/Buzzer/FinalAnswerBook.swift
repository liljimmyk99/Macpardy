//
//  FinalAnswerBook.swift
//  Macpardy
//
//  Validation and storage for Final Macpardy answers typed on phones (#80).
//  Like FinalWagerBook it has no networking: the server feeds it submissions
//  and reads back what each phone should show. The game state stays the
//  source of truth; the book is re-seeded from it whenever answering changes.
//

import Foundation

/// Whether phones can type a Final answer.
nonisolated enum FinalAnswerWindow: Equatable {
    /// Not in the Final clue or answer: phones show the buzzer.
    case closed
    /// The Final clue is up: phones can submit and change their answer.
    case open
    /// The correct response is revealed: answers are read-only.
    case locked
}

/// What a phone's answer screen shows.
nonisolated struct AnswerInfo: Equatable {
    /// True while the team can still submit or change its answer.
    let open: Bool
    /// The team's saved answer, if it sent one.
    let answer: String?
    /// Longest answer the server accepts, in characters.
    let maxLength: Int
}

/// An answer a phone submitted, handed to the app to store.
nonisolated struct AnswerSubmission: Equatable {
    let teamID: UUID
    let answer: String
}

/// Why a submitted answer was refused.
nonisolated enum AnswerRejectReason: String, Encodable, Equatable {
    case notOpen
    case empty
    case tooLong
}

nonisolated struct FinalAnswerBook {

    /// Longest answer accepted, in characters. Generous for a written response,
    /// short enough to read on the Display.
    static let maxLength = 200

    enum SubmitResult: Equatable {
        case accepted(String)
        case rejected(AnswerRejectReason)
    }

    private(set) var window: FinalAnswerWindow = .closed
    private var answers: [UUID: String] = [:]

    // MARK: - Host-driven transitions

    /// Opens, locks or closes answering, taking the answers stored in the game.
    mutating func set(_ window: FinalAnswerWindow, answers: [UUID: String]) {
        self.window = window
        self.answers = window == .closed ? [:] : answers
    }

    // MARK: - Phone input

    /// Saves a team's answer. While answering is open the latest submission
    /// wins, so a team can change its mind until the host reveals the response.
    /// Every team can answer, including ones excluded from wagering.
    mutating func submit(teamID: UUID, answer: String) -> SubmitResult {
        guard window == .open else { return .rejected(.notOpen) }
        let cleaned = Self.normalize(answer)
        guard !cleaned.isEmpty else { return .rejected(.empty) }
        guard cleaned.count <= Self.maxLength else { return .rejected(.tooLong) }
        answers[teamID] = cleaned
        return .accepted(cleaned)
    }

    /// Trims surrounding whitespace and folds line breaks into spaces, so an
    /// answer always fits on one line on the host's screen.
    static func normalize(_ answer: String) -> String {
        answer
            .components(separatedBy: .newlines)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Phone display

    /// Nil while answering is closed (the phone shows its buzzer).
    func info(for teamID: UUID) -> AnswerInfo? {
        guard window != .closed else { return nil }
        return AnswerInfo(open: window == .open, answer: answers[teamID], maxLength: Self.maxLength)
    }
}
