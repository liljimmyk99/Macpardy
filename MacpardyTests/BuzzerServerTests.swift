//
//  BuzzerServerTests.swift
//  MacpardyTests
//

import XCTest
@testable import Macpardy

@MainActor
final class BuzzerServerTests: XCTestCase {

    func testHeaderValueIsCaseInsensitiveAndStopsAtTheBlankLine() {
        let request = Data("GET /ws HTTP/1.1\r\nHost: x\r\nUser-Agent:  Phone/1.0 \r\nSec-WebSocket-Key: abc==\r\n\r\nUser-Agent: body".utf8)
        XCTAssertEqual(BuzzerServer.headerValue("user-agent", in: request), "Phone/1.0")
        XCTAssertEqual(BuzzerServer.headerValue("sec-websocket-key", in: request), "abc==")
        XCTAssertNil(BuzzerServer.headerValue("origin", in: request))
    }
}
