import SwiftUI

extension SetupControlView {

    /// One cell of the 2 × 2 team grid.
    private enum TeamSlot: Identifiable {
        case team(Team)
        case add
        case empty(Int)

        var id: String {
            switch self {
            case .team(let team): team.id.uuidString
            case .add: "add"
            case .empty(let index): "empty-\(index)"
            }
        }
    }

    /// Teams, then an Add Team card while there's room, padded to a full grid
    /// so cards keep the same size as teams come and go.
    private var teamSlots: [TeamSlot] {
        var slots = gameState.game.teams.map(TeamSlot.team)
        if slots.count < Team.maxCount {
            slots.append(.add)
        }
        while slots.count < Team.maxCount {
            slots.append(.empty(slots.count))
        }
        return slots
    }

    func sectionHeader(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .textCase(.uppercase)
            .font(MacpardyTheme.controlCategoryFont)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .background(MacpardyTheme.tileBlue)
    }

    func teamGrid() -> some View {
        let slots = teamSlots
        let rows = stride(from: 0, to: slots.count, by: 2).map { Array(slots[$0..<min($0 + 2, slots.count)]) }

        return VStack(spacing: 4) {
            ForEach(rows.indices, id: \.self) { rowIndex in
                HStack(spacing: 4) {
                    ForEach(rows[rowIndex]) { slot in
                        teamSlotView(slot)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func teamSlotView(_ slot: TeamSlot) -> some View {
        switch slot {
        case .team(let team):
            TeamSetupCard(team: team)
        case .add:
            LoggedButton(log: "Control › Setup › Add team") {
                gameState.addTeam()
            } label: {
                VStack(spacing: 10) {
                    Image(systemName: "plus")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(MacpardyTheme.gold)
                    Text("control.setup.button.add_team")
                        .font(.headline)
                        .foregroundStyle(MacpardyTheme.mutedText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .overlay(
                    Rectangle()
                        .strokeBorder(MacpardyTheme.tileHover, style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                )
            }
            .buttonStyle(.plain)
        case .empty:
            Color.clear
        }
    }

    /// Shown in place of the join info when buzzers are turned off in Settings.
    func buzzersOffNotice() -> some View {
        VStack(spacing: 12) {
            Image(systemName: "iphone.slash")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(MacpardyTheme.mutedText)
            Text("control.setup.no_buzzers.message")
                .font(.headline)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text("control.setup.no_buzzers.hint")
                .font(.callout)
                .foregroundStyle(MacpardyTheme.mutedText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
    }

    func startGameButton() -> some View {
        LoggedButton(log: "Control › Setup › Start game") {
            gameState.startGame()
        } label: {
            Label("control.setup.button.start_game", systemImage: "play.fill")
                .font(.title3.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .tint(MacpardyTheme.gold)
        .foregroundStyle(MacpardyTheme.boardBlue)
        .controlSize(.extraLarge)
    }
}
