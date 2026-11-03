//
//  SettingsView.swift
//  Macpardy
//
//  The Settings window (⌘,). Changes apply as they are made.
//

import SwiftUI

struct SettingsView: View {

    @State private var tab = "sound"

    var body: some View {
        TabView(selection: $tab) {
            SoundSettingsPane()
                .tabItem { Label("settings.tab.sound", systemImage: "speaker.wave.2") }
                .tag("sound")

            GameSettingsPane()
                .tabItem { Label("settings.tab.game", systemImage: "gamecontroller") }
                .tag("game")

            BuzzerSettingsPane()
                .tabItem { Label("settings.tab.buzzers", systemImage: "iphone.radiowaves.left.and.right") }
                .tag("buzzers")
        }
        .onChange(of: tab) { old, new in
            AppLogger.control.nav("Settings tab \(old) → \(new)")
        }
        .frame(width: 450)
        .scenePadding()
    }
}

#Preview {
    SettingsView()
}
