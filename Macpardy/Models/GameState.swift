//
//  GameState.swift
//  Macpardy
//
//  Created by Jimmy Kane on 7/15/26.
//
import Foundation

@Observable
final class GameState {
    var game: Game

    // UI State
    var currentQuestion: Question?
    var currentCategoryTitle: String?
    var timer = GameTimer(seconds: TimeInterval(AppSettings.questionTimerSeconds()))
    var phase: GamePhase = .setup
    /// True from the start of a round until its first clue is picked, so the
    /// Display plays the board intro (categories one by one, then the clues).
    /// Not saved: a resumed game shows its board straight away.
    var boardIntroPending = false

    // Buzz-in response (issue #59)
    /// Counts down the answering team's time after a phone buzz wins.
    let responseTimer = GameTimer(seconds: TimeInterval(AppSettings.responseSeconds()))
    /// The team that buzzed in and hasn't been judged yet.
    private(set) var answeringTeamID: UUID?

    /// How long a team has to answer after buzzing in (Settings > Game).
    var responseSeconds: TimeInterval { TimeInterval(AppSettings.responseSeconds(settings)) }

    /// Returns the question timer to the length set in Settings. Only a timer
    /// that starts afterwards is affected; one that is running is stopped by
    /// the reset like any other.
    func resetTimer() {
        timer.reset(seconds: TimeInterval(AppSettings.questionTimerSeconds(settings)))
    }

    // Daily Double State
    var dailyDoubleTeamID: UUID?
    var dailyDoubleWager: Int = 0

    // Final Macpardy State
    var finalMacpardyWagers: [UUID: Int] = [:]
    /// Answers typed on the phones (#80), by team. Missing means no answer.
    var finalMacpardyAnswers: [UUID: String] = [:]
    /// The team whose answer and wager the Display is showing, after the
    /// correct response is revealed. The host shows one team at a time.
    var finalMacpardyRevealedTeamID: UUID?

    /// Where timer lengths are read from (Settings). Tests swap in their own.
    @ObservationIgnored var settings: UserDefaults = .standard

    // Undo (Edit menu): set by the Control window.
    @ObservationIgnored var scoreUndoManager: UndoManager?

    // Persistence
    private var pendingSaveTask: Task<Void, Never>?
    var onSaveTriggered: ((GameSnapshot) -> Void)?

    init(rounds: [MacpardyBoard], currentRound: Int = 0, teams: [Team] = Team.defaultNewTeams, phase: GamePhase = .setup) {
        self.game = Game(
            rounds: rounds,
            currentRound: currentRound,
            teams: teams
        )
        self.phase = phase
    }

    convenience init() {
        self.init(
            rounds: [MacpardyBoard.sample],
            currentRound: 0,
            teams: Team.defaultNewTeams,
            phase: .setup
        )
    }

    convenience init(from snapshot: GameSnapshot) {
        self.init(
            rounds: snapshot.game.rounds,
            currentRound: snapshot.game.currentRound,
            teams: snapshot.game.teams,
            phase: snapshot.phase
        )
        self.dailyDoubleTeamID = snapshot.dailyDoubleTeamID
        self.dailyDoubleWager = snapshot.dailyDoubleWager
        self.finalMacpardyWagers = snapshot.finalMacpardyWagers
        self.finalMacpardyAnswers = snapshot.finalMacpardyAnswers ?? [:]
        self.finalMacpardyRevealedTeamID = snapshot.finalMacpardyRevealedTeamID
        self.currentCategoryTitle = snapshot.currentCategoryTitle
        if let qID = snapshot.currentQuestionID,
           snapshot.game.rounds.indices.contains(snapshot.game.currentRound) {
            let currentBoard = snapshot.game.rounds[snapshot.game.currentRound]
            for cat in currentBoard.categories {
                if let matched = cat.questions.first(where: { $0.id == qID }) {
                    self.currentQuestion = matched
                    break
                }
            }
        }
    }

    func restore(from snapshot: GameSnapshot) {
        clearScoreUndo()
        self.game = snapshot.game
        self.phase = snapshot.phase
        self.dailyDoubleTeamID = snapshot.dailyDoubleTeamID
        self.dailyDoubleWager = snapshot.dailyDoubleWager
        self.finalMacpardyWagers = snapshot.finalMacpardyWagers
        self.finalMacpardyAnswers = snapshot.finalMacpardyAnswers ?? [:]
        self.finalMacpardyRevealedTeamID = snapshot.finalMacpardyRevealedTeamID
        self.currentCategoryTitle = snapshot.currentCategoryTitle
        self.currentQuestion = nil
        cancelResponse()
        if let qID = snapshot.currentQuestionID,
           game.rounds.indices.contains(game.currentRound) {
            let currentBoard = game.rounds[game.currentRound]
            for cat in currentBoard.categories {
                if let matched = cat.questions.first(where: { $0.id == qID }) {
                    self.currentQuestion = matched
                    break
                }
            }
        }
        self.resetTimer()
    }

    func startGame() {
        boardIntroPending = true
        phase = .board
        triggerSave()
    }

    func selectQuestion(_ question: Question, categoryTitle: String) {
        cancelResponse()
        boardIntroPending = false
        markQuestionPlayed(question)
        currentQuestion = question
        currentCategoryTitle = categoryTitle
        if question.isDailyDouble {
            dailyDoubleTeamID = game.teams.first?.id
            dailyDoubleWager = max(question.value, 1000)
            phase = .dailyDouble
        } else {
            dailyDoubleTeamID = nil
            dailyDoubleWager = 0
            phase = .question
            resetTimer()
        }
        triggerSave()
    }

    func submitDailyDoubleWager(teamID: UUID, wager: Int) {
        cancelResponse()
        dailyDoubleTeamID = teamID
        dailyDoubleWager = wager
        phase = .question
        resetTimer()
        triggerSave()
    }

    func revealAnswer() {
        cancelResponse()
        timer.stop()
        if phase == .finalMacpardyQuestion {
            phase = .finalMacpardyAnswer
        } else {
            phase = .answer
        }
        triggerSave()
    }

    func showBoard() {
        cancelResponse()
        phase = .board
        currentQuestion = nil
        currentCategoryTitle = nil
        dailyDoubleTeamID = nil
        dailyDoubleWager = 0
        finalMacpardyRevealedTeamID = nil
        triggerSave()
    }

    func showDailyDouble() {
        phase = .dailyDouble
        triggerSave()
    }

    func showFinalMacpardy(categoryTitle: String? = nil) {
        cancelResponse()
        // Look up final macpardy board if present
        if let fjBoard = game.rounds.first(where: { $0.round == .finalMacpardy }),
           let category = fjBoard.categories.first,
           let question = category.questions.first {
            currentCategoryTitle = category.title
            currentQuestion = question
        } else if let title = categoryTitle {
            currentCategoryTitle = title
            currentQuestion = Question(value: 0, clue: "Final Macpardy Clue", response: "Final Macpardy Response")
        } else {
            currentCategoryTitle = "Final Macpardy"
            currentQuestion = Question(value: 0, clue: "Final Macpardy Clue", response: "Final Macpardy Response")
        }

        // No wagers or answers yet; a missing wager means the team hasn't bet.
        finalMacpardyWagers = [:]
        finalMacpardyAnswers = [:]
        finalMacpardyRevealedTeamID = nil
        phase = .finalMacpardyCategory
        resetTimer()
        triggerSave()
    }

    /// Teams at zero or below can't win points, so they can't wager.
    func isFinalEligible(_ team: Team) -> Bool {
        team.score > 0
    }

    func maxFinalWager(for team: Team) -> Int {
        max(0, team.score)
    }

    /// Max wager per team (its score), used to validate wagers from phones.
    var finalWagerLimits: [UUID: Int] {
        Dictionary(uniqueKeysWithValues: game.teams.map { ($0.id, maxFinalWager(for: $0)) })
    }

    /// Sets a wager, clamped to the team's range. Ignored for excluded teams.
    @discardableResult
    func setFinalWager(teamID: UUID, amount: Int) -> Int? {
        guard let team = game.teams.first(where: { $0.id == teamID }), isFinalEligible(team) else { return nil }
        let clamped = min(max(0, amount), maxFinalWager(for: team))
        finalMacpardyWagers[teamID] = clamped
        triggerSave()
        return clamped
    }

    func clearFinalWager(teamID: UUID) {
        finalMacpardyWagers[teamID] = nil
        triggerSave()
    }

    /// Teams that didn't wager bet everything they have; excluded teams bet 0.
    func applyFinalWagerDefaults() {
        for team in game.teams {
            if !isFinalEligible(team) {
                finalMacpardyWagers[team.id] = 0
            } else if finalMacpardyWagers[team.id] == nil {
                finalMacpardyWagers[team.id] = maxFinalWager(for: team)
            }
        }
    }

    func revealFinalMacpardyQuestion() {
        applyFinalWagerDefaults()
        phase = .finalMacpardyQuestion
        resetTimer()
        triggerSave()
    }

    // MARK: - Final answers (#80)

    /// Phones can type answers while the Final clue is up and its timer has
    /// time left. They lock when the timer runs out (and reopen if the host
    /// adds time or resets it) and stay locked once the correct response is
    /// revealed. Closed everywhere else.
    var finalAnswerWindow: FinalAnswerWindow {
        switch phase {
        case .finalMacpardyQuestion: timer.isExpired ? .locked : .open
        case .finalMacpardyAnswer: .locked
        default: .closed
        }
    }

    /// Stores an answer a phone sent. Ignored unless answering is open, so an
    /// answer that arrives after time runs out doesn't count.
    func setFinalAnswer(teamID: UUID, answer: String) {
        guard finalAnswerWindow == .open,
              game.teams.contains(where: { $0.id == teamID }) else { return }
        let cleaned = FinalAnswerBook.normalize(answer)
        guard !cleaned.isEmpty else { return }
        finalMacpardyAnswers[teamID] = String(cleaned.prefix(FinalAnswerBook.maxLength))
        triggerSave()
    }

    /// Shows a team's answer and wager on the Display (nil hides it). Only
    /// after the correct response is revealed, one team at a time.
    func revealFinalAnswer(teamID: UUID?) {
        guard phase == .finalMacpardyAnswer else { return }
        if let teamID, !game.teams.contains(where: { $0.id == teamID }) { return }
        finalMacpardyRevealedTeamID = teamID
        triggerSave()
    }

    /// The team the Display is spotlighting, if it still exists.
    var finalMacpardyRevealedTeam: Team? {
        guard phase == .finalMacpardyAnswer, let id = finalMacpardyRevealedTeamID else { return nil }
        return game.teams.first(where: { $0.id == id })
    }

    func adjustScore(for teamID: UUID, by amount: Int) {
        guard let team = game.teams.first(where: { $0.id == teamID }) else { return }
        let name = amount < 0 ? String(localized: "undo.deduct_points") : String(localized: "undo.award_points")
        setScore(for: teamID, to: team.score + amount, undoName: name)
    }

    func resetScore(for teamID: UUID) {
        setScore(for: teamID, to: 0, undoName: String(localized: "undo.reset_score"))
    }

    /// Sets a team's score and registers the step that puts it back. Only
    /// scores can be undone; moving between clues or rounds can't.
    private func setScore(for teamID: UUID, to newScore: Int, undoName: String) {
        guard let index = game.teams.firstIndex(where: { $0.id == teamID }) else { return }
        let previous = game.teams[index].score
        game.teams[index].score = newScore
        triggerSave()

        guard previous != newScore, let scoreUndoManager else { return }
        scoreUndoManager.registerUndo(withTarget: self) { state in
            // Registered while undoing, so it becomes the redo.
            state.setScore(for: teamID, to: previous, undoName: undoName)
        }
        scoreUndoManager.setActionName(undoName)
    }

    /// Forgets every score step, so an undo can't change a score from an
    /// earlier round or game.
    func clearScoreUndo() {
        scoreUndoManager?.removeAllActions(withTarget: self)
    }

    func advanceRound() {
        clearScoreUndo()
        // Find next non-final-macpardy board or next round index
        let nextRound = game.currentRound + 1
        if nextRound < game.rounds.count {
            if game.rounds[nextRound].round == .finalMacpardy {
                showFinalMacpardy()
            } else {
                game.currentRound = nextRound
                showBoard()
                boardIntroPending = true
            }
        }
        triggerSave()
    }

    func loadGame(boards: [MacpardyBoard]) {
        clearScoreUndo()
        self.game = Game(
            rounds: boards,
            currentRound: 0,
            teams: Team.defaultNewTeams
        )
        self.phase = .setup
        cancelResponse()
        self.currentQuestion = nil
        self.currentCategoryTitle = nil
        self.dailyDoubleTeamID = nil
        self.dailyDoubleWager = 0
        self.finalMacpardyWagers = [:]
        self.finalMacpardyAnswers = [:]
        self.finalMacpardyRevealedTeamID = nil
    }

    /// Ends a finished game (#82): timers stop, nothing more is auto-saved,
    /// and the phase goes back to setup. The app then returns to the launch
    /// screen and clears the save.
    func endGame() {
        clearScoreUndo()
        pendingSaveTask?.cancel()
        pendingSaveTask = nil
        cancelResponse()
        timer.stop()
        phase = .setup
        currentQuestion = nil
        currentCategoryTitle = nil
        dailyDoubleTeamID = nil
        dailyDoubleWager = 0
        finalMacpardyRevealedTeamID = nil
        boardIntroPending = false
    }

    func addTeam(name: String = "", color: String = "blue") {
        guard game.teams.count < Team.maxCount else { return }
        let count = game.teams.count + 1
        let teamName = name.isEmpty ? String(localized: "team.default_name \(count)") : name
        let availableColors = ["blue", "red", "green", "yellow", "purple", "orange"]
        let chosenColor = availableColors[(count - 1) % availableColors.count]
        game.teams.append(Team(name: teamName, score: 0, color: chosenColor))
        triggerSave()
    }

    func removeTeam(at index: Int) {
        guard game.teams.indices.contains(index) else { return }
        game.teams.remove(at: index)
        triggerSave()
    }

    func removeTeam(id: UUID) {
        game.teams.removeAll(where: { $0.id == id })
        triggerSave()
    }

    func removeTeam(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) {
            if game.teams.indices.contains(index) {
                game.teams.remove(at: index)
            }
        }
        triggerSave()
    }

    // MARK: - Buzz-in response

    /// The answering team and its time left, while a team is answering.
    var responseCountdown: ResponseCountdown? {
        guard let answeringTeamID else { return nil }
        return ResponseCountdown(
            teamID: answeringTeamID,
            remainingTime: responseTimer.remainingTime,
            totalTime: responseTimer.startingTime
        )
    }

    /// Called when the phone buzzers report who is answering (nil when no one is).
    /// A buzz on a normal clue pauses the question timer and starts the team's
    /// response time. Daily Doubles and Final Macpardy have no buzzing.
    func teamBuzzedIn(_ teamID: UUID?) {
        guard let teamID else {
            // The buzzers stopped without the host judging this team
            // (e.g. another team was marked correct): drop the response.
            cancelResponse()
            return
        }
        guard teamID != answeringTeamID,
              phase == .question,
              dailyDoubleTeamID == nil else { return }

        answeringTeamID = teamID
        timer.stop()
        responseTimer.reset(seconds: responseSeconds)
        responseTimer.start()
    }

    /// The host marked a team correct or wrong on a normal clue. If that team
    /// was answering, its response time ends. Wrong resumes the question timer
    /// from where it paused so other teams can buzz; correct leaves it stopped.
    /// The host can judge before the response time runs out.
    func judgeResponse(teamID: UUID, isCorrect: Bool) {
        guard answeringTeamID == teamID else { return }
        cancelResponse()
        if !isCorrect, phase == .question, timer.remainingTime > 0 {
            timer.start()
        }
    }

    /// Stops and clears any response in progress without touching the question timer.
    func cancelResponse() {
        answeringTeamID = nil
        responseTimer.reset(seconds: responseSeconds)
    }

    private func markQuestionPlayed(_ question: Question) {
        guard let roundIndex = game.rounds.indices.first(where: { $0 == game.currentRound }) else { return }

        for categoryIndex in game.rounds[roundIndex].categories.indices {
            for questionIndex in game.rounds[roundIndex].categories[categoryIndex].questions.indices {
                if game.rounds[roundIndex].categories[categoryIndex].questions[questionIndex].id == question.id {
                    game.rounds[roundIndex].categories[categoryIndex].questions[questionIndex].hasBeenPlayed = true
                    return
                }
            }
        }
    }

    // MARK: - Persistence Triggers

    func triggerSave() {
        guard phase != .setup else { return }
        let snapshot = GameSnapshot(from: self)
        onSaveTriggered?(snapshot)

        pendingSaveTask?.cancel()
        pendingSaveTask = Task { [snapshot] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            try? await GameSaveStore.shared.save(snapshot)
        }
    }
}
