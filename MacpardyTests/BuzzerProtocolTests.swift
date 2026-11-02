//
//  BuzzerProtocolTests.swift
//  MacpardyTests
//

import XCTest
@testable import Macpardy

@MainActor
final class BuzzerProtocolTests: XCTestCase {

    func testJoinCodeLengthAndAlphabet() {
        let allowed = Set("ABCDEFGHJKMNPQRSTUVWXYZ23456789")
        for _ in 0..<200 {
            let code = JoinCodeGenerator.generate()
            XCTAssertEqual(code.count, 6)
            XCTAssertTrue(code.allSatisfy { allowed.contains($0) }, code)
        }
    }

    func testJoinMessageDecodes() throws {
        let json = Data(#"{"type":"join","version":1,"code":"AB3XYZ"}"#.utf8)
        let message = try JSONDecoder().decode(ClientMessage.self, from: json)
        guard case .join(let code, let version) = message else { return XCTFail("expected join") }
        XCTAssertEqual(code, "AB3XYZ")
        XCTAssertEqual(version, 1)
    }

    func testJoinWithoutVersionIsRejected() {
        let json = Data(#"{"type":"join","code":"AB3XYZ"}"#.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(ClientMessage.self, from: json))
    }

    func testPongDecodesAndUnknownTypeThrows() throws {
        let pong = try JSONDecoder().decode(ClientMessage.self, from: Data(#"{"type":"pong"}"#.utf8))
        guard case .pong = pong else { return XCTFail("expected pong") }
        XCTAssertThrowsError(
            try JSONDecoder().decode(ClientMessage.self, from: Data(#"{"type":"nope"}"#.utf8))
        )
    }

    func testBuzzDecodes() throws {
        let buzz = try JSONDecoder().decode(ClientMessage.self, from: Data(#"{"type":"buzz"}"#.utf8))
        guard case .buzz = buzz else { return XCTFail("expected buzz") }
    }

    func testBuzzerStateEncoding() throws {
        let data = try ServerMessage.buzzerState(.lockedOut).jsonData()
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["type"] as? String, "buzzerState")
        let payload = try XCTUnwrap(json["payload"] as? [String: Any])
        XCTAssertEqual(payload["state"] as? String, "lockedOut")
    }

    func testJoinAcceptedEncoding() throws {
        let id = UUID()
        let team = BuzzerTeam(id: id, name: "A", color: "blue", claimed: true)
        let data = try ServerMessage.joinAccepted(teams: [team]).jsonData()
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["type"] as? String, "joinAccepted")
        let payload = try XCTUnwrap(object["payload"] as? [String: Any])
        XCTAssertEqual(payload["version"] as? Int, BuzzerConstants.protocolVersion)
        let teams = try XCTUnwrap(payload["teams"] as? [[String: Any]])
        XCTAssertEqual(teams.first?["id"] as? String, id.uuidString)
        XCTAssertEqual(teams.first?["name"] as? String, "A")
        XCTAssertEqual(teams.first?["claimed"] as? Bool, true)
    }

    func testClaimDecodes() throws {
        let id = UUID()
        let json = Data(#"{"type":"claim","teamID":"\#(id.uuidString)"}"#.utf8)
        let message = try JSONDecoder().decode(ClientMessage.self, from: json)
        guard case .claim(let teamID) = message else { return XCTFail("expected claim") }
        XCTAssertEqual(teamID, id)
    }

    func testClaimWithBadTeamIDIsRejected() {
        let json = Data(#"{"type":"claim","teamID":"nope"}"#.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(ClientMessage.self, from: json))
    }

    func testClaimRejectedAndRemovedEncoding() throws {
        let rejected = try ServerMessage.claimRejected(reason: .taken).jsonData()
        let rejectedObject = try XCTUnwrap(JSONSerialization.jsonObject(with: rejected) as? [String: Any])
        XCTAssertEqual(rejectedObject["type"] as? String, "claimRejected")
        XCTAssertEqual((rejectedObject["payload"] as? [String: Any])?["reason"] as? String, "taken")

        let removed = try ServerMessage.removed.jsonData()
        let removedObject = try XCTUnwrap(JSONSerialization.jsonObject(with: removed) as? [String: Any])
        XCTAssertEqual(removedObject["type"] as? String, "removed")
        XCTAssertNil(removedObject["payload"])
    }

    // MARK: - Response timer (#59)

    func testResponseTimerEncoding() throws {
        let id = UUID()
        let info = ResponseTimerInfo(teamID: id, remaining: 3.2499, total: 5)
        let data = try ServerMessage.responseTimer(info).jsonData()
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["type"] as? String, "responseTimer")
        let payload = try XCTUnwrap(object["payload"] as? [String: Any])
        XCTAssertEqual(payload["teamID"] as? String, id.uuidString)
        XCTAssertEqual(try XCTUnwrap(payload["remaining"] as? Double), 3.2, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(payload["total"] as? Double), 5, accuracy: 0.0001)
    }

    func testResponseTimerStoppedHasNoPayload() throws {
        let data = try ServerMessage.responseTimerStopped.jsonData()
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["type"] as? String, "responseTimerStopped")
        XCTAssertNil(object["payload"])
    }

    // MARK: - Game PIN entry and session end (#61)

    func testProtocolVersionIsSeven() {
        XCTAssertEqual(BuzzerConstants.protocolVersion, 7)
    }

    func testJoinRejectedEncodesCodeAndReason() throws {
        let expected: [JoinRejectReason: (code: String, reason: String)] = [
            .invalidCode: ("invalidCode", "Invalid join code"),
            .rateLimited: ("rateLimited", "Too many attempts. Try again shortly."),
            .unsupportedVersion: ("unsupportedVersion", "Unsupported protocol version"),
        ]
        XCTAssertEqual(expected.count, JoinRejectReason.allCases.count)
        for (reason, values) in expected {
            let data = try ServerMessage.joinRejected(reason).jsonData()
            let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            XCTAssertEqual(object["type"] as? String, "joinRejected")
            let payload = try XCTUnwrap(object["payload"] as? [String: Any])
            XCTAssertEqual(payload["code"] as? String, values.code)
            XCTAssertEqual(payload["reason"] as? String, values.reason)
        }
    }

    func testSessionEndedHasNoPayload() throws {
        let data = try ServerMessage.sessionEnded.jsonData()
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["type"] as? String, "sessionEnded")
        XCTAssertNil(object["payload"])
    }

    // MARK: - Final answers (#80)

    func testSubmitAnswerDecodes() throws {
        let json = Data(#"{"type":"submitAnswer","answer":"What is Paris?"}"#.utf8)
        let message = try JSONDecoder().decode(ClientMessage.self, from: json)
        guard case .submitAnswer(let answer) = message else { return XCTFail("expected submitAnswer") }
        XCTAssertEqual(answer, "What is Paris?")
    }

    func testSubmitAnswerWithoutAnswerIsRejected() {
        let json = Data(#"{"type":"submitAnswer"}"#.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(ClientMessage.self, from: json))
    }

    func testAnswerInfoEncoding() throws {
        let data = try ServerMessage.answerInfo(AnswerInfo(open: true, answer: "Paris", maxLength: 200)).jsonData()
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["type"] as? String, "answerInfo")
        let payload = try XCTUnwrap(object["payload"] as? [String: Any])
        XCTAssertEqual(payload["open"] as? Bool, true)
        XCTAssertEqual(payload["answer"] as? String, "Paris")
        XCTAssertEqual(payload["maxLength"] as? Int, 200)
    }

    func testAnswerInfoOmitsMissingAnswer() throws {
        let data = try ServerMessage.answerInfo(AnswerInfo(open: false, answer: nil, maxLength: 200)).jsonData()
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let payload = try XCTUnwrap(object["payload"] as? [String: Any])
        XCTAssertEqual(payload["open"] as? Bool, false)
        XCTAssertNil(payload["answer"])
    }

    func testAnswerSavedRejectedAndClosedEncoding() throws {
        let saved = try XCTUnwrap(
            JSONSerialization.jsonObject(with: try ServerMessage.answerSaved(answer: "Paris").jsonData()) as? [String: Any]
        )
        XCTAssertEqual(saved["type"] as? String, "answerSaved")
        XCTAssertEqual((saved["payload"] as? [String: Any])?["answer"] as? String, "Paris")

        let rejected = try XCTUnwrap(
            JSONSerialization.jsonObject(with: try ServerMessage.answerRejected(.tooLong).jsonData()) as? [String: Any]
        )
        XCTAssertEqual(rejected["type"] as? String, "answerRejected")
        XCTAssertEqual((rejected["payload"] as? [String: Any])?["reason"] as? String, "tooLong")

        let closed = try XCTUnwrap(
            JSONSerialization.jsonObject(with: try ServerMessage.answerClosed.jsonData()) as? [String: Any]
        )
        XCTAssertEqual(closed["type"] as? String, "answerClosed")
        XCTAssertNil(closed["payload"])
    }
}
