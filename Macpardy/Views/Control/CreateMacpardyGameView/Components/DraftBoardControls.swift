//
//  DraftBoardControls.swift
//  Macpardy
//
//  Created by Jimmy Kane on 10/8/26.
//

import SwiftUI

struct DraftBoardControls: View {
    @Binding var currentRound: Int
    var unfilled: [UnfilledField] = []
    let saveGame: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            if currentRound > 0 {
                LoggedButton(previousRoundLabel, log: "Editor › Previous round") {
                    currentRound -= 1
                }
                .buttonStyle(.bordered)
            }

            if currentRound < 2 {
                LoggedButton(nextRoundLabel, log: "Editor › Next round") {
                    currentRound += 1
                }
                .buttonStyle(.bordered)
            }
            
            Spacer()

            UnfilledSummary(unfilled: unfilled)

            LoggedButton("create.button.save_game", log: "Editor › Save game") {
                saveGame()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.saveGame)
            .controlSize(.large)
        }
    }

    private var previousRoundLabel: LocalizedStringKey {
        switch currentRound {
        case 1: "create.draft.previous_round.macpardy"
        case 2: "create.draft.previous_round.double_macpardy"
        default: "create.draft.previous_round"
        }
    }

    private var nextRoundLabel: LocalizedStringKey {
        switch currentRound {
        case 0: "create.draft.next_round.double_macpardy"
        case 1: "create.draft.next_round.final_macpardy"
        default: "create.draft.next_round"
        }
    }
}

/// The running count of fields that still have default text.
private struct UnfilledSummary: View {

    let unfilled: [UnfilledField]

    var body: some View {
        if unfilled.isEmpty {
            Label("create.unfilled.none", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.secondary)
        } else {
            Label {
                Text("create.unfilled.count \(unfilled.count)")
            } icon: {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(MacpardyTheme.warning)
            }
            .help(breakdown)
        }
    }

    private var breakdown: String {
        let game = unfilled.filter { $0.round == nil }.count
        let parts = [
            game > 0 ? String(localized: "create.unfilled.breakdown.game \(game)") : nil,
            String(localized: "create.unfilled.breakdown.round1 \(unfilled.fieldCount(inRound: 0))"),
            String(localized: "create.unfilled.breakdown.round2 \(unfilled.fieldCount(inRound: 1))"),
            String(localized: "create.unfilled.breakdown.final \(unfilled.fieldCount(inRound: 2))"),
        ].compactMap { $0 }
        return parts.joined(separator: " · ")
    }
}
