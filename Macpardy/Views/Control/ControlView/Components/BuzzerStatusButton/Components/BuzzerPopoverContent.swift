import AppKit
import SwiftUI

extension BuzzerStatusButton {
    func popoverContent() -> some View {
        VStack(alignment: .leading, spacing: 0) {
            joinHeader()
                .padding(16)

            Divider()

            VStack(spacing: 2) {
                ForEach(gameState.game.teams) { team in
                    BuzzerPhoneRow(team: team)
                }
            }
            .padding(8)

            Text("control.buzzer.popover.remove_note")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 16)

            // Why a phone dropped: opens the Logs window on the Buzzer filter (#81).
            Button("control.buzzer.popover.view_logs", systemImage: "doc.text.magnifyingglass") {
                openWindow(id: "logs")
            }
            .buttonStyle(.link)
            .font(.caption)
            .padding([.horizontal, .bottom], 16)
            .padding(.top, 8)
        }
        .frame(width: 380)
    }

    @ViewBuilder
    private func joinHeader() -> some View {
        if buzzerState.isRunning, let url = buzzerState.serverURL, let baseURL = buzzerState.baseURL {
            HStack(alignment: .top, spacing: 16) {
                if let qrImage = QRCodeGenerator.image(from: url.absoluteString, size: 112) {
                    Image(nsImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .frame(width: 112, height: 112)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("control.setup.buzzer.join_code")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(buzzerState.joinCode)
                        .font(MacpardyTheme.joinCodeFont)
                        .foregroundStyle(MacpardyTheme.gold)
                        .tracking(5)

                    Button {
                        NSPasteboard.general.clearContents()
                        // Copies the full link (with the PIN) so it joins straight away.
                        NSPasteboard.general.setString(url.absoluteString, forType: .string)
                    } label: {
                        HStack(spacing: 6) {
                            Text(baseURL.absoluteString)
                                .font(.system(.caption, design: .monospaced))
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Image(systemName: "doc.on.doc")
                                .font(.caption)
                        }
                    }
                    .buttonStyle(.bordered)
                    .help("control.setup.buzzer.copy_url")
                }
            }
        } else if let error = buzzerState.startError {
            Label {
                Text("control.setup.buzzer.error \(error)")
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
            }
            .font(.callout)
            .foregroundStyle(.red)
        } else {
            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                Text("control.setup.buzzer.starting")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
