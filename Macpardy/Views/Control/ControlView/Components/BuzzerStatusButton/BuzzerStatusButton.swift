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

        LoggedButton(log: "Control › Toolbar › Buzzers") {
            buzzerState.isPopoverPresented.toggle()
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(title)
                if buzzerState.isJoinScreenOnDisplay {
                    // The room is looking at the join screen, not the game (#83).
                    Image(systemName: "tv")
                        .foregroundStyle(MacpardyTheme.gold)
                        .help("control.toolbar.buzzers.join_screen_on")
                }
            }
        }
        .help(Text("control.toolbar.buzzers.help") + Text(verbatim: " (\(AppShortcut.buzzers.glyph))"))
        .popover(isPresented: $buzzerState.isPopoverPresented, arrowEdge: .bottom) {
            popoverContent()
        }
        .logPresentation("popover 'Buzzers'", isPresented: buzzerState.isPopoverPresented)
    }
}

#Preview {
    BuzzerStatusButton()
        .environment(GameState())
        .environment(BuzzerState())
        .padding()
}
