//
//  BuzzerJoinInfoView.swift
//  Macpardy
//
//  QR code, join code, copyable link and how many teams have a phone, on the
//  setup screen. The toolbar's buzzer popover shows a compact version.
//

import AppKit
import SwiftUI

struct BuzzerJoinInfoView: View {

    @Environment(GameState.self) var gameState
    @Environment(BuzzerState.self) var buzzerState

    private var teamsWithPhone: Int {
        gameState.game.teams.filter { buzzerState.claimedTeamIDs.contains($0.id) }.count
    }

    var body: some View {
        VStack(spacing: 18) {
            if buzzerState.isRunning, let url = buzzerState.serverURL, let baseURL = buzzerState.baseURL {
                if let qrImage = QRCodeGenerator.image(from: url.absoluteString, size: 200) {
                    Image(nsImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .frame(width: 200, height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                VStack(spacing: 4) {
                    Text("control.setup.buzzer.join_code")
                        .font(.caption.bold())
                        .foregroundStyle(MacpardyTheme.mutedText)
                    Text(buzzerState.joinCode)
                        .font(MacpardyTheme.setupJoinCodeFont)
                        .foregroundStyle(MacpardyTheme.gold)
                        .tracking(8)
                }

                LoggedButton(log: "Control › Setup › Copy join link") {
                    NSPasteboard.general.clearContents()
                    // Copies the full link (with the PIN) so it joins straight away.
                    NSPasteboard.general.setString(url.absoluteString, forType: .string)
                } label: {
                    HStack(spacing: 6) {
                        Text(baseURL.absoluteString)
                            .font(.system(.callout, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Image(systemName: "doc.on.doc")
                    }
                }
                .buttonStyle(.bordered)
                .help("control.setup.buzzer.copy_url")

                Text("control.setup.buzzer.teams_with_phone \(teamsWithPhone) \(gameState.game.teams.count)")
                    .font(.callout)
                    .foregroundStyle(MacpardyTheme.mutedText)
            } else if let error = buzzerState.startError {
                Label {
                    Text("control.setup.buzzer.error \(error)")
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                }
                .font(.callout)
                .foregroundStyle(.red)
            } else {
                ProgressView()
                    .padding(.vertical, 8)
                Text("control.setup.buzzer.starting")
                    .font(.callout)
                    .foregroundStyle(MacpardyTheme.mutedText)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    BuzzerJoinInfoView()
        .environment(GameState())
        .environment(BuzzerState())
        .padding()
        .frame(width: 380)
        .background(MacpardyTheme.panelBlue)
}
