//
//  WalkthroughView+Extension.swift
//  Macpardy
//

import AppKit
import SwiftUI

extension WalkthroughView {

    @ViewBuilder
    func footer() -> some View {
        HStack {
            if !step.isLast {
                LoggedButton("walkthrough.button.skip", log: "Walkthrough › Skip") {
                    onFinish()
                }
                .buttonStyle(.plain)
                .foregroundStyle(MacpardyTheme.mutedText)
            }

            Spacer()

            if let previous = step.previous {
                LoggedButton("walkthrough.button.back", log: "Walkthrough › Back") {
                    step = previous
                }
            }

            if let next = step.next {
                LoggedButton("walkthrough.button.next", log: "Walkthrough › Next") {
                    step = next
                }
                .buttonStyle(.borderedProminent)
                .tint(MacpardyTheme.gold)
                .foregroundStyle(.black)
                .keyboardShortcut(.defaultAction)
            } else {
                LoggedButton("walkthrough.button.done", log: "Walkthrough › Get started") {
                    onFinish()
                }
                .buttonStyle(.borderedProminent)
                .tint(MacpardyTheme.gold)
                .foregroundStyle(.black)
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    /// Opens System Settings > Network. The Firewall pane has no stable
    /// deep link across macOS versions, so this is the closest reliable one.
    func openFirewallSettings() {
        let network = URL(string: "x-apple.systempreferences:com.apple.Network-Settings.extension")
        let fallback = URL(string: "x-apple.systempreferences:")
        if let network, NSWorkspace.shared.open(network) { return }
        if let fallback { openURL(fallback) }
    }
}
