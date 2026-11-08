//
//  DisconnectReasonTests.swift
//  MacpardyTests
//
//  The app's Network.framework error text. The rest of `DisconnectReason`
//  is tested in BuzzerCore.
//

import BuzzerCore
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
