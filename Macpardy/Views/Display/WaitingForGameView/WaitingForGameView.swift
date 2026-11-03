//
//  WaitingForGameView.swift
//  Macpardy
//
//  What the Display shows while no game is selected: before the host picks
//  one, and after a game is completed (#82).
//

import SwiftUI

struct WaitingForGameView: View {

    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @AppStorage(AppSettings.Key.animationsEnabled)
    var animationsSetting = AppSettings.defaultAnimationsEnabled

    @State private var isPulsing = false

    private var animates: Bool {
        AppSettings.shouldAnimate(setting: animationsSetting, reduceMotion: reduceMotion)
    }

    var body: some View {
        VStack(spacing: 32) {
            Text("launch.title")
                .font(MacpardyTheme.launchTitleFont)
                .foregroundStyle(MacpardyTheme.gold)
                .shadow(color: .black, radius: 0, x: 3, y: 3)
                .padding(.horizontal, 48)
                .padding(.vertical, 18)
                .background(MacpardyTheme.tileBlue)

            Text("display.waiting_for_game")
                .font(.title)
                .foregroundStyle(.white.opacity(0.8))
                .opacity(isPulsing ? 0.45 : 1)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MacpardyTheme.boardBlue)
        .preferredColorScheme(.dark)
        .onAppear { updatePulse() }
        .onChange(of: animates) { _, _ in updatePulse() }
    }

    private func updatePulse() {
        guard animates else {
            withAnimation(nil) { isPulsing = false }
            return
        }
        withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
            isPulsing = true
        }
    }
}

#Preview {
    WaitingForGameView()
        .frame(width: 960, height: 540)
}
