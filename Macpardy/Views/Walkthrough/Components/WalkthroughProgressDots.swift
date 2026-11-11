//
//  WalkthroughProgressDots.swift
//  Macpardy
//

import SwiftUI

struct WalkthroughProgressDots: View {

    let current: WalkthroughStep

    var body: some View {
        HStack(spacing: 8) {
            ForEach(WalkthroughStep.allCases) { step in
                Circle()
                    .fill(step.rawValue <= current.rawValue ? MacpardyTheme.gold : MacpardyTheme.tileBlue)
                    .frame(width: 8, height: 8)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("walkthrough.progress \(current.rawValue + 1) \(WalkthroughStep.allCases.count)"))
    }
}
