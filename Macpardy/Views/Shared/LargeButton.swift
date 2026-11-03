//
//  LargeButton.swift
//  Macpardy
//

import SwiftUI

struct LargeButton: View {

    let title: LocalizedStringKey
    var systemImage: String?
    var tint: Color = .accentColor
    /// Where the press is logged, e.g. "Control › Final › Reveal answer".
    let log: String
    let action: () -> Void

    init(title: LocalizedStringKey, systemImage: String? = nil, tint: Color = .accentColor, log: String, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
        self.log = log
        self.action = action
    }

    init(_ title: LocalizedStringKey, systemImage: String? = nil, tint: Color = .accentColor, log: String, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
        self.log = log
        self.action = action
    }

    init(stringLiteral title: String, systemImage: String? = nil, tint: Color = .accentColor, log: String, action: @escaping () -> Void) {
        self.title = LocalizedStringKey(title)
        self.systemImage = systemImage
        self.tint = tint
        self.log = log
        self.action = action
    }

    var body: some View {
        LoggedButton(log: log, action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .buttonStyle(.borderedProminent)
        .tint(tint)
    }
}

#Preview {
    LargeButton(title: "display.preview.reveal_answer", systemImage: "eye", log: "Preview") {}
        .padding()
}
