//
//  LocalNetworkInterfaces.swift
//  Macpardy
//
//  The Mac's IPv4 addresses, and which one phones should use to reach the
//  buzzer server. Also listed in exported logs (#81).
//

import Darwin
import Foundation

nonisolated enum LocalNetworkInterfaces {

    struct Address: Equatable, Sendable, CustomStringConvertible {
        /// BSD interface name, e.g. "en0".
        let interface: String
        let ip: String

        var description: String { "\(interface) \(ip)" }
    }

    /// VPN, bridge, AirDrop and similar interfaces phones can't reach.
    static let ignoredPrefixes = ["utun", "bridge", "awdl", "llw", "ap", "gif", "stf"]

    /// Every up, non-loopback IPv4 address, in system order.
    static func current() -> [Address] {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return [] }
        defer { freeifaddrs(ifaddr) }

        var addresses: [Address] = []
        var pointer = ifaddr
        while let interface = pointer {
            defer { pointer = interface.pointee.ifa_next }

            guard let addr = interface.pointee.ifa_addr else { continue }
            let flags = Int32(interface.pointee.ifa_flags)
            guard (flags & IFF_UP) != 0, (flags & IFF_LOOPBACK) == 0,
                  addr.pointee.sa_family == UInt8(AF_INET) else { continue }

            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard getnameinfo(
                addr, socklen_t(addr.pointee.sa_len),
                &hostname, socklen_t(hostname.count),
                nil, 0, NI_NUMERICHOST
            ) == 0 else { continue }

            addresses.append(Address(
                interface: String(cString: interface.pointee.ifa_name),
                ip: String(cString: hostname)
            ))
        }
        return addresses
    }

    /// The address phones can most likely reach: the first `en*` interface
    /// (Wi-Fi / Ethernet), else the first one that isn't ignored.
    static func preferred(from addresses: [Address]) -> Address? {
        addresses.first { $0.interface.hasPrefix("en") }
            ?? addresses.first { address in
                !ignoredPrefixes.contains { address.interface.hasPrefix($0) }
            }
    }
}
