//
//  DisconnectReason+Network.swift
//  Macpardy
//
//  Describes Network.framework errors for `DisconnectReason.networkError` and
//  the transport's own log lines. `DisconnectReason` itself is in BuzzerCore,
//  which can't import Network.
//

import BuzzerCore
import Foundation
import Network

extension DisconnectReason {

    /// A short description of a connection error, e.g.
    /// "Connection reset by peer (POSIX 54)".
    nonisolated static func describe(_ error: NWError) -> String {
        switch error {
        case .posix(let code):
            "\(String(cString: strerror(code.rawValue))) (POSIX \(code.rawValue))"
        case .dns(let code):
            "DNS error \(code)"
        case .tls(let status):
            "TLS error \(status)"
        default:
            String(describing: error)
        }
    }
}
