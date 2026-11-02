//
//  LocalNetworkInterfacesTests.swift
//  MacpardyTests
//

import XCTest
@testable import Macpardy

@MainActor
final class LocalNetworkInterfacesTests: XCTestCase {

    private typealias Address = LocalNetworkInterfaces.Address

    func testPrefersEnInterfaces() {
        let addresses = [
            Address(interface: "utun3", ip: "10.8.0.2"),
            Address(interface: "bridge100", ip: "192.168.64.1"),
            Address(interface: "en0", ip: "192.168.1.10"),
            Address(interface: "en5", ip: "192.168.2.10"),
        ]
        XCTAssertEqual(LocalNetworkInterfaces.preferred(from: addresses)?.ip, "192.168.1.10")
    }

    func testFallsBackToAnyInterfaceThatIsNotIgnored() {
        let addresses = [
            Address(interface: "utun3", ip: "10.8.0.2"),
            Address(interface: "awdl0", ip: "169.254.1.1"),
            Address(interface: "pdp_ip0", ip: "10.20.30.40"),
        ]
        XCTAssertEqual(LocalNetworkInterfaces.preferred(from: addresses)?.interface, "pdp_ip0")
    }

    func testNoUsableInterface() {
        XCTAssertNil(LocalNetworkInterfaces.preferred(from: []))
        XCTAssertNil(LocalNetworkInterfaces.preferred(from: [Address(interface: "utun0", ip: "10.0.0.1")]))
    }

    func testPathSummary() {
        typealias Interface = NetworkPathSummary.Interface
        XCTAssertEqual(
            NetworkPathSummary.describe(isSatisfied: true, interfaces: [Interface(name: "en0", kind: .wifi)]),
            "Wi-Fi (en0)"
        )
        XCTAssertEqual(
            NetworkPathSummary.describe(
                isSatisfied: true,
                interfaces: [Interface(name: "lo0", kind: .loopback), Interface(name: "en5", kind: .wiredEthernet), Interface(name: "utun3", kind: .other)]
            ),
            "Ethernet (en5), VPN/other (utun3)"
        )
        XCTAssertEqual(NetworkPathSummary.describe(isSatisfied: false, interfaces: [Interface(name: "en0", kind: .wifi)]), "unavailable")
        XCTAssertEqual(NetworkPathSummary.describe(isSatisfied: true, interfaces: []), "unavailable")
    }
}
