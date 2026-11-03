//
//  DisplayBuzzerJoinPanel.swift
//  Macpardy
//
//  Big QR code, page address and Game PIN on the Display before the game starts,
//  so teams can scan from across the room or type the address and PIN.
//

import SwiftUI

struct DisplayBuzzerJoinPanel: View {

    /// Full link with `?code=`, encoded in the QR code so scanning joins straight away.
    let joinURL: URL
    /// The page address without the code, shown as text next to the Game PIN.
    let baseURL: URL
    let joinCode: String

    var body: some View {
        VStack(spacing: 28) {
            joinDetails
            // Chrome on Android can't reach the Mac until the phone allows it (#90).
            Label("display.setup.buzzer.android_tip", systemImage: "info.circle")
                .font(.title3)
                .foregroundStyle(MacpardyTheme.mutedText)
                .multilineTextAlignment(.center)
        }
    }

    private var joinDetails: some View {
        HStack(spacing: 48) {
            if let qrImage = QRCodeGenerator.image(from: joinURL.absoluteString, size: 600) {
                Image(nsImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .aspectRatio(1, contentMode: .fit)
                    .frame(maxWidth: 320, maxHeight: 320)
                    .padding(16)
                    // White quiet zone so phone cameras pick the code up on a dark board.
                    .background(.white, in: RoundedRectangle(cornerRadius: 16))
            }

            VStack(alignment: .leading, spacing: 20) {
                Text("display.setup.buzzer.scan")
                    .font(MacpardyTheme.titleFont)
                    .foregroundStyle(.white)

                VStack(alignment: .leading, spacing: 6) {
                    Text("display.setup.buzzer.or_visit")
                        .font(.title3)
                        .foregroundStyle(MacpardyTheme.mutedText)
                    Text(baseURL.absoluteString)
                        .font(MacpardyTheme.displayJoinURLFont)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .textSelection(.enabled)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("display.setup.buzzer.join_code")
                        .font(.title3)
                        .foregroundStyle(MacpardyTheme.mutedText)
                    Text(joinCode)
                        .font(MacpardyTheme.displayJoinCodeFont)
                        .foregroundStyle(MacpardyTheme.gold)
                        .tracking(10)
                }
            }
        }
    }
}

#Preview {
    DisplayBuzzerJoinPanel(
        joinURL: URL(string: "http://192.168.1.20:8472?code=ABC234")!,
        baseURL: URL(string: "http://192.168.1.20:8472")!,
        joinCode: "ABC234"
    )
        .padding()
        .background(MacpardyTheme.boardBlue)
}
