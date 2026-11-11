//
//  WalkthroughView.swift
//  Macpardy
//
//  The first-time walkthrough sheet (#76): one page per topic with Back,
//  Next and Skip.
//

import SwiftUI

struct WalkthroughView: View {

    @Environment(\.openURL) var openURL

    /// Called when the host finishes or skips.
    let onFinish: () -> Void

    @State var step: WalkthroughStep = .welcome

    var body: some View {
        VStack(spacing: 24) {
            WalkthroughProgressDots(current: step)

            WalkthroughStepCard(step: step) {
                openFirewallSettings()
            }
            .id(step)
            .transition(.opacity)

            footer()
        }
        .padding(32)
        .frame(width: 560, height: 620)
        .background(MacpardyTheme.boardBlue)
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: 0.2), value: step)
    }
}

#Preview {
    WalkthroughView(onFinish: {})
}
