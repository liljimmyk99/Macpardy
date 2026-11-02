//
//  NetworkPathSummary.swift
//  Macpardy
//
//  Describes the Mac's network path for log lines (#81),
//  e.g. "Wi-Fi (en0)" or "unavailable".
//

import Foundation
import Network

nonisolated enum NetworkPathSummary {

    enum Kind: Sendable {
        case wifi, wiredEthernet, cellular, loopback, other
    }

    struct Interface: Equatable, Sendable {
        let name: String
        let kind: Kind
    }

    static func describe(_ path: NWPath) -> String {
        describe(
            isSatisfied: path.status == .satisfied,
            interfaces: path.availableInterfaces.map { Interface(name: $0.name, kind: kind(of: $0.type)) }
        )
    }

    /// "Wi-Fi (en0)", "Wi-Fi (en0), VPN/other (utun3)", or "unavailable".
    static func describe(isSatisfied: Bool, interfaces: [Interface]) -> String {
        let usable = interfaces.filter { $0.kind != .loopback }
        guard isSatisfied, !usable.isEmpty else { return "unavailable" }
        return usable.map { "\(label(for: $0.kind)) (\($0.name))" }.joined(separator: ", ")
    }

    private static func kind(of type: NWInterface.InterfaceType) -> Kind {
        switch type {
        case .wifi: .wifi
        case .wiredEthernet: .wiredEthernet
        case .cellular: .cellular
        case .loopback: .loopback
        default: .other
        }
    }

    private static func label(for kind: Kind) -> String {
        switch kind {
        case .wifi: "Wi-Fi"
        case .wiredEthernet: "Ethernet"
        case .cellular: "Cellular"
        case .loopback: "Loopback"
        case .other: "VPN/other"
        }
    }
}
