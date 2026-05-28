import Foundation
import XCTest
@testable import Lichess_Board

final class LichessBoardAPITests: XCTestCase {
  var api: LichessBoardAPI!

  override func setUp() {
    super.setUp()
    api = LichessBoardAPI(accessToken: "test-token")
  }

  override func tearDown() {
    api = nil
    super.tearDown()
  }

  func testEventStreamRequestUsesBoardStreamHeaders() throws {
    let request = api.eventStreamRequest()

    XCTAssertEqual(request.url?.absoluteString, "https://lichess.org/api/stream/event")
    XCTAssertEqual(request.httpMethod, "GET")
    XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/x-ndjson")
    XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")
  }

  func testGameStreamRequestUsesGameId() throws {
    let request = api.gameStreamRequest(gameId: "abc123")

    XCTAssertEqual(request.url?.absoluteString, "https://lichess.org/api/board/game/stream/abc123")
    XCTAssertEqual(request.httpMethod, "GET")
    XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/x-ndjson")
  }

  func testRapidSeekRequestOmitsRandomColor() throws {
    let preset = SeekPreset(title: "Rapid 10+5", time: 10, increment: 5, days: nil, rated: false, color: .random)
    let request = api.seekRequest(preset: preset)
    let body = try formBody(from: request)

    XCTAssertEqual(request.url?.absoluteString, "https://lichess.org/api/board/seek")
    XCTAssertEqual(request.httpMethod, "POST")
    XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/x-www-form-urlencoded")
    XCTAssertEqual(body["rated"], "false")
    XCTAssertEqual(body["variant"], "standard")
    XCTAssertEqual(body["time"], "10")
    XCTAssertEqual(body["increment"], "5")
    XCTAssertNil(body["color"])
  }

  func testRapidSeekRequestIncludesExplicitColor() throws {
    let preset = SeekPreset(title: "Rapid 15+10", time: 15, increment: 10, days: nil, rated: true, color: .white)
    let request = api.seekRequest(preset: preset)
    let body = try formBody(from: request)

    XCTAssertEqual(body["rated"], "true")
    XCTAssertEqual(body["time"], "15")
    XCTAssertEqual(body["increment"], "10")
    XCTAssertEqual(body["color"], "white")
  }

  func testDirectChallengeUsesChallengeClockFields() throws {
    let preset = SeekPreset(title: "Rapid 10+5", time: 10, increment: 5, days: nil, rated: false, color: .black)
    let request = api.challengeRequest(username: "maia5", preset: preset)
    let body = try formBody(from: request)

    XCTAssertEqual(request.url?.absoluteString, "https://lichess.org/api/challenge/maia5")
    XCTAssertEqual(request.httpMethod, "POST")
    XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
    XCTAssertEqual(body["clock.limit"], "600")
    XCTAssertEqual(body["clock.increment"], "5")
    XCTAssertEqual(body["color"], "black")
    XCTAssertNil(body["time"])
    XCTAssertNil(body["increment"])
  }

  func testMoveRequestAddsOfferingDrawQuery() throws {
    let request = api.moveRequest(gameId: "abc123", move: "e2e4", offeringDraw: true)
    let components = try XCTUnwrap(URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false))

    XCTAssertEqual(components.path, "/api/board/game/abc123/move/e2e4")
    XCTAssertEqual(request.httpMethod, "POST")
    XCTAssertEqual(components.queryItems?.first(where: { $0.name == "offeringDraw" })?.value, "true")
  }

  func testChatRequestEncodesRoomAndText() throws {
    let request = api.chatRequest(gameId: "abc123", room: .player, text: "Good game")
    let body = try formBody(from: request)

    XCTAssertEqual(request.url?.absoluteString, "https://lichess.org/api/board/game/abc123/chat")
    XCTAssertEqual(request.httpMethod, "POST")
    XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/x-www-form-urlencoded")
    XCTAssertEqual(body["room"], "player")
    XCTAssertEqual(body["text"], "Good game")
  }

  func testGameActionRequestsArePosts() throws {
    let abort = api.abortRequest(gameId: "abc123")
    let resign = api.resignRequest(gameId: "abc123")

    XCTAssertEqual(abort.url?.absoluteString, "https://lichess.org/api/board/game/abc123/abort")
    XCTAssertEqual(abort.httpMethod, "POST")
    XCTAssertEqual(abort.value(forHTTPHeaderField: "Accept"), "application/json")
    XCTAssertEqual(resign.url?.absoluteString, "https://lichess.org/api/board/game/abc123/resign")
    XCTAssertEqual(resign.httpMethod, "POST")
  }

  func testBotOnlineRequestUsesNdjsonLimit() throws {
    let request = api.onlineBotsRequest(limit: 7)
    let components = try XCTUnwrap(URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false))

    XCTAssertEqual(components.path, "/api/bot/online")
    XCTAssertEqual(components.queryItems?.first(where: { $0.name == "nb" })?.value, "7")
    XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/x-ndjson")
  }

  func testChallengeDecisionRequests() throws {
    let accept = api.acceptChallengeRequest(challengeId: "challenge-id")
    let decline = api.declineChallengeRequest(challengeId: "challenge-id", reason: .tooFast)
    let declineBody = try formBody(from: decline)

    XCTAssertEqual(accept.url?.absoluteString, "https://lichess.org/api/challenge/challenge-id/accept")
    XCTAssertEqual(accept.httpMethod, "POST")
    XCTAssertEqual(decline.url?.absoluteString, "https://lichess.org/api/challenge/challenge-id/decline")
    XCTAssertEqual(decline.httpMethod, "POST")
    XCTAssertEqual(declineBody["reason"], "tooFast")
  }

  private func formBody(from request: URLRequest) throws -> [String: String] {
    let data = try XCTUnwrap(request.httpBody)
    let query = String(decoding: data, as: UTF8.self)
    var components = URLComponents()
    components.percentEncodedQuery = query
    let items = components.queryItems ?? []
    return Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
  }
}
