//
//  DisconnectReasonTests.swift
//  MacpardyTests
//

import Network
import XCTest
@testable import Macpardy

@MainActor
final class DisconnectReasonTests: XCTestCase {

    // MARK: - Network errors

    func testPOSIXErrorsAreDescribedReadably() {
        XCTAssertEqual(DisconnectReason.describe(NWError.posix(.ECONNRESET)), "Connection reset by peer (POSIX 54)")
    }
}
