//
//  BuzzerReconnectingBanner.swift
//  Macpardy
//
//  Shown while the app is reconnecting to the external buzzer server (#104).
//

import SwiftUI

struct BuzzerReconnectingBanner: View {

    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text("control.buzzer.reconnecting")
                .font(.callout)
        }
        .foregroundStyle(.orange)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    BuzzerReconnectingBanner().padding()
}
