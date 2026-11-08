//
//  SystemInfoReport.swift
//  Macpardy
//
//  `system-info.txt` in exported logs (#81): app and Mac details plus the
//  buzzer server's state when the logs were exported.
//

import BuzzerCore
import Darwin
import Foundation

nonisolated enum SystemInfoReport {

    /// The live values the report needs, gathered on the main actor.
    struct Snapshot: Sendable {
        var exportedAt = Date()
        var buzzerPort: Int
        var serverRunning: Bool
        var joinedPhones: Int
        var teamCount: Int
        var addresses: [LocalNetworkInterfaces.Address]
    }

    static func make(_ snapshot: Snapshot) -> String {
        let preferred = LocalNetworkInterfaces.preferred(from: snapshot.addresses)
        let addresses = snapshot.addresses.isEmpty
            ? "  (none)"
            : snapshot.addresses.map { address in
                "  \(address.interface)  \(address.ip)\(address == preferred ? "  ← used for the join link" : "")"
            }.joined(separator: "\n")

        return """
        Macpardy log export
        Exported:         \(snapshot.exportedAt.formatted(.iso8601))
        Time zone:        \(TimeZone.current.identifier)

        App:              \(appDescription)
        macOS:            \(osDescription)
        Mac model:        \(macModel)

        Buzzer port:      \(snapshot.buzzerPort)
        Protocol version: \(BuzzerConstants.protocolVersion)
        Server running:   \(snapshot.serverRunning ? "yes" : "no")
        Phones joined:    \(snapshot.joinedPhones)
        Teams:            \(snapshot.teamCount)

        Local IPv4 addresses:
        \(addresses)

        """
    }

    /// "Macpardy 0.4.1 (1)".
    static var appDescription: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "Macpardy \(version) (\(build))"
    }

    /// "macOS 26.3 (Build 25D60)".
    static var osDescription: String {
        let version = ProcessInfo.processInfo.operatingSystemVersionString
        return "macOS \(version.replacingOccurrences(of: "Version ", with: ""))"
    }

    /// The hardware model identifier, e.g. "Mac15,6".
    static var macModel: String {
        var size = 0
        guard sysctlbyname("hw.model", nil, &size, nil, 0) == 0, size > 0 else { return "unknown" }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname("hw.model", &buffer, &size, nil, 0) == 0 else { return "unknown" }
        return String(cString: buffer)
    }
}
