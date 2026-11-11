//
//  WalkthroughStepCard.swift
//  Macpardy
//

import SwiftUI

struct WalkthroughStepCard: View {

    let step: WalkthroughStep
    let onOpenFirewall: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: step.systemImage)
                .font(.system(size: 56))
                .foregroundStyle(MacpardyTheme.gold)
                .accessibilityHidden(true)

            Text(LocalizedStringKey(step.titleKey))
                .font(MacpardyTheme.titleFont)
                .foregroundStyle(.white)

            Text(LocalizedStringKey(step.bodyKey))
                .font(.title3)
                .foregroundStyle(MacpardyTheme.mutedText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if !step.tipKeys.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(step.tipKeys, id: \.self) { key in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(MacpardyTheme.gold)
                            Text(LocalizedStringKey(key))
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .foregroundStyle(.white)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(MacpardyTheme.panelBlue, in: RoundedRectangle(cornerRadius: 8))
            }

            if step.hasFirewallAction {
                LoggedButton(
                    "walkthrough.buzzers.open_settings",
                    systemImage: "gearshape",
                    log: "Walkthrough › Open network settings",
                    action: onOpenFirewall
                )
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
