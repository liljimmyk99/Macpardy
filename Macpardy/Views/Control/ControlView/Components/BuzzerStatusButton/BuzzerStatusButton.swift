//
//  BuzzerStatusButton.swift
//  Macpardy
//
//  Toolbar button showing the join code and how many teams have a phone.
//  Opens a popover with join info and each team's phone.
//

import SwiftUI

struct BuzzerStatusButton: View {

    @Environment(GameState.self) var gameState
    @Environment(BuzzerState.self) var buzzerState
    @Environment(\.openWindow) var openWindow

    var body: some View {
        @Bindable var buzzerState = buzzerState

        Button {
            buzzerState.isPopoverPresented.toggle()
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(title)
            }
        }
        .help(Text("control.toolbar.buzzers.help") + Text(verbatim: " (\(AppShortcut.buzzers.glyph))"))
        .popover(isPresented: $buzzerState.isPopoverPresented, arrowEdge: .bottom) {
            popoverContent()
        }
    }
}

#Preview {
    BuzzerStatusButton()
        .environment(GameState())
        .environment(BuzzerState())
        .padding()
}
