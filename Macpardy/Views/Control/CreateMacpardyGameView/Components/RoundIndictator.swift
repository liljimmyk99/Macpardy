//
//  RoundIndictator.swift
//  Macpardy
//
//  Created by Jimmy Kane on 10/6/26.
//
import SwiftUI
struct RoundIndictator: View {
    @Binding var currentRound: Int
    
    var body: some View {
        HStack(spacing: 12) {
            Text("create.round_label")
                .font(.headline)
                .foregroundStyle(.primary)

            LoggedButton(log: "Editor › Round picker › R1") {
                currentRound = 0
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "1.circle.fill")
                        .imageScale(.medium)
                    Text("round.macpardy")
                        .fontWeight(currentRound == 0 ? .bold : .regular)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(currentRound == 0 ? MacpardyTheme.tileBlue : Color.clear)
                .foregroundStyle(currentRound == 0 ? MacpardyTheme.gold : .secondary)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(currentRound == 0 ? MacpardyTheme.gold : Color.gray.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            LoggedButton(log: "Editor › Round picker › R2") {
                currentRound = 1
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "2.circle.fill")
                        .imageScale(.medium)
                    Text("round.double_macpardy")
                        .fontWeight(currentRound == 1 ? .bold : .regular)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(currentRound == 1 ? MacpardyTheme.tileBlue : Color.clear)
                .foregroundStyle(currentRound == 1 ? MacpardyTheme.gold : .secondary)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(currentRound == 1 ? MacpardyTheme.gold : Color.gray.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            LoggedButton(log: "Editor › Round picker › Final") {
                currentRound = 2
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "flag.checkered")
                        .imageScale(.medium)
                    Text("round.final_macpardy")
                        .fontWeight(currentRound == 2 ? .bold : .regular)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(currentRound == 2 ? MacpardyTheme.tileBlue : Color.clear)
                .foregroundStyle(currentRound == 2 ? MacpardyTheme.gold : .secondary)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(currentRound == 2 ? MacpardyTheme.gold : Color.gray.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }
}
