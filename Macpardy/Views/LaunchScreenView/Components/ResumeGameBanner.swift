//
//  ResumeGameBanner.swift
//  Macpardy
//
//  Offers the auto-saved game on the start screen: which round it was on and
//  how many teams, with Resume and Discard.
//

import SwiftUI

struct ResumeGameBanner: View {

    let snapshot: GameSnapshot
    let onResume: () -> Void
    let onDiscard: () -> Void

    private var roundTitle: String {
        snapshot.game.currentBoard?.title ?? ""
    }

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.title2)
                .foregroundStyle(MacpardyTheme.gold)

            VStack(alignment: .leading, spacing: 2) {
                Text("launch.resume.title")
                    .font(.headline)
                Text("launch.resume.detail \(roundTitle) \(snapshot.game.currentRound + 1) \(snapshot.game.rounds.count) \(snapshot.game.teams.count)")
                    .font(.subheadline)
                    .foregroundStyle(MacpardyTheme.mutedText)
            }

            Spacer()

            LoggedButton("launch.resume.discard", log: "Launch › Resume banner › Discard", role: .destructive, action: onDiscard)
                .buttonStyle(.borderless)

            LoggedButton("launch.alert.resume_action", log: "Launch › Resume banner › Resume", action: onResume)
                .buttonStyle(.borderedProminent)
                .tint(MacpardyTheme.gold)
                .foregroundStyle(MacpardyTheme.boardBlue)
                .controlSize(.large)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(MacpardyTheme.panelBlue, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(MacpardyTheme.tileHover)
        )
    }
}

#Preview {
    ResumeGameBanner(
        snapshot: GameSnapshot(
            game: Game(rounds: [MacpardyBoard.sample], teams: Team.sampleTeams),
            phase: .board
        ),
        onResume: {},
        onDiscard: {}
    )
    .frame(width: 900)
    .padding()
    .background(MacpardyTheme.boardBlue)
}
