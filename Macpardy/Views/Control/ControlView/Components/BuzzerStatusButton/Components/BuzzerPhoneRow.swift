//
//  BuzzerPhoneRow.swift
//  Macpardy
//
//  One team in the buzzer popover: phone status and Remove phone.
//

import SwiftUI

struct BuzzerPhoneRow: View {

    @Environment(BuzzerState.self) var buzzerState

    let team: Team

    private var isConnected: Bool { buzzerState.claimedTeamIDs.contains(team.id) }
    private var isDisconnected: Bool { buzzerState.disconnectedTeamIDs.contains(team.id) }

    var body: some View {
        HStack(spacing: 12) {
            Capsule()
                .fill(team.displayColor)
                .frame(width: 4, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(team.name)
                    .font(.body.weight(.semibold))
                status
            }

            Spacer()

            if isConnected {
                LoggedButton("control.team.remove_phone", log: "Buzzers popover › '\(team.name)' › Remove phone") {
                    Task { await buzzerState.removePhone(forTeam: team.id) }
                }
                .help("control.team.remove_phone.help")
            }
        }
        .padding(8)
        .background(
            isDisconnected ? Color.orange.opacity(0.12) : Color.clear,
            in: RoundedRectangle(cornerRadius: 8)
        )
    }

    @ViewBuilder
    private var status: some View {
        if isConnected {
            Label("control.buzzer.team.connected", systemImage: "iphone.gen3")
                .font(.caption)
                .foregroundStyle(.green)
        } else if isDisconnected {
            Label("control.team.disconnected", systemImage: "iphone.slash")
                .font(.caption)
                .foregroundStyle(.orange)
        } else {
            Label("control.buzzer.team.waiting", systemImage: "iphone")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    BuzzerPhoneRow(team: Team.sampleTeams[0])
        .environment(BuzzerState())
        .padding()
        .frame(width: 380)
}
