import SwiftUI

extension TimerControlsView {
    func timerPlaybackControls() -> some View {
        HStack(spacing: 6) {
            LoggedButton("control.timer.adjustment.minus_5", log: "Control › Timer › −5s") {
                gameState.timer.addSeconds(-5)
            }
            .help(shortcutHelp("menu.game.timer.minus_5", .timerMinus5))

            if gameState.timer.isRunning {
                iconButton(
                    "pause.fill",
                    label: "control.timer.pause",
                    shortcut: .toggleTimer,
                    log: "Control › Timer › Pause"
                ) {
                    gameState.timer.stop()
                }
            } else {
                iconButton(
                    "play.fill",
                    label: "control.timer.start",
                    shortcut: .toggleTimer,
                    log: "Control › Timer › Start"
                ) {
                    gameState.timer.start()
                }
            }

            iconButton(
                "arrow.counterclockwise",
                label: "control.timer.reset",
                shortcut: .resetTimer,
                log: "Control › Timer › Reset"
            ) {
                gameState.resetTimer()
            }

            LoggedButton("control.timer.adjustment.plus_5", log: "Control › Timer › +5s") {
                gameState.timer.addSeconds(5)
            }
            .help(shortcutHelp("menu.game.timer.plus_5", .timerPlus5))
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }

    private func iconButton(
        _ systemImage: String,
        label: LocalizedStringKey,
        shortcut: AppShortcut,
        log: String,
        action: @escaping () -> Void
    ) -> some View {
        LoggedButton(log: log, action: action) {
            Image(systemName: systemImage)
                .frame(width: 28)
        }
        .accessibilityLabel(Text(label))
        .help(Text(label) + Text(verbatim: " (\(shortcut.glyph))"))
    }

    private func shortcutHelp(_ title: LocalizedStringKey, _ shortcut: AppShortcut) -> Text {
        Text(title) + Text(verbatim: " (\(shortcut.glyph))")
    }
}
