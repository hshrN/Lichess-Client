import Foundation
import XCTest
@testable import Lichess_Board

final class LichessStreamEventTests: XCTestCase {
  func testDecodesGameStartEvent() throws {
    let data = Data(
      """
      {
        "type": "gameStart",
        "game": {
          "gameId": "xAVd6eJy",
          "color": "white",
          "lastMove": "",
          "speed": "rapid",
          "status": {
            "name": "started"
          },
          "opponent": {
            "id": "aaron",
            "username": "Aaron",
            "rating": 797
          },
          "isMyTurn": true,
          "secondsLeft": 300
        }
      }
      """.utf8
    )

    let envelope = try JSONDecoder().decode(EventEnvelope.self, from: data)
    let event = try JSONDecoder().decode(GameStartEvent.self, from: data)

    XCTAssertEqual(envelope.type, "gameStart")
    XCTAssertEqual(event.game.gameId, "xAVd6eJy")
    XCTAssertEqual(event.game.color, "white")
    XCTAssertEqual(event.game.speed, "rapid")
    XCTAssertEqual(event.game.status?.name, "started")
    XCTAssertEqual(event.game.opponent.username, "Aaron")
    XCTAssertEqual(event.game.opponent.rating, 797)
    XCTAssertTrue(event.game.isMyTurn)
    XCTAssertEqual(event.game.secondsLeft, 300)
  }

  func testDecodesGameFullEvent() throws {
    let data = Data(
      """
      {
        "type": "gameFull",
        "id": "BEOucQJo",
        "initialFen": "startpos",
        "speed": "rapid",
        "white": {
          "name": "Bobby",
          "rating": 1751
        },
        "black": {
          "name": "Mary",
          "rating": 1021
        },
        "clock": {
          "initial": 900000,
          "increment": 0
        },
        "state": {
          "type": "gameState",
          "moves": "d2d3",
          "wtime": 900000,
          "btime": 890000,
          "status": "started"
        }
      }
      """.utf8
    )

    let event = try JSONDecoder().decode(GameFullEvent.self, from: data)

    XCTAssertEqual(event.id, "BEOucQJo")
    XCTAssertEqual(event.initialFen, "startpos")
    XCTAssertEqual(event.white.name, "Bobby")
    XCTAssertEqual(event.black.rating, 1021)
    XCTAssertEqual(event.clock?.initial, 900000)
    XCTAssertEqual(event.clock?.increment, 0)
    XCTAssertEqual(event.state.moves, "d2d3")
    XCTAssertEqual(event.state.btime, 890000)
  }

  func testDecodesChatAndOpponentGoneEvents() throws {
    let chatData = Data(
      """
      {
        "type": "chatLine",
        "username": "mary",
        "text": "Good luck",
        "room": "player"
      }
      """.utf8
    )
    let goneData = Data(
      """
      {
        "type": "opponentGone",
        "gone": true,
        "claimWinInSeconds": 12,
        "claimDrawInSeconds": 0
      }
      """.utf8
    )

    let chat = try JSONDecoder().decode(ChatLineEvent.self, from: chatData)
    let gone = try JSONDecoder().decode(OpponentGoneEvent.self, from: goneData)

    XCTAssertEqual(chat.username, "mary")
    XCTAssertEqual(chat.text, "Good luck")
    XCTAssertEqual(chat.room, "player")
    XCTAssertTrue(gone.gone)
    XCTAssertEqual(gone.claimWinInSeconds, 12)
    XCTAssertEqual(gone.claimDrawInSeconds, 0)
  }

  func testDecodesChallengeEvent() throws {
    let data = Data(
      """
      {
        "type": "challenge",
        "challenge": {
          "id": "challenge-id",
          "rated": false,
          "challenger": {
            "name": "Bobby",
            "rating": 1751
          },
          "destUser": {
            "name": "Me",
            "rating": 1600
          },
          "timeControl": {
            "show": "10+5"
          }
        }
      }
      """.utf8
    )

    let event = try JSONDecoder().decode(ChallengeEvent.self, from: data)

    XCTAssertEqual(event.challenge.id, "challenge-id")
    XCTAssertFalse(event.challenge.rated)
    XCTAssertEqual(event.challenge.challenger.name, "Bobby")
    XCTAssertEqual(event.challenge.challenger.rating, 1751)
    XCTAssertEqual(event.challenge.destUser?.name, "Me")
    XCTAssertEqual(event.challenge.timeControl?.show, "10+5")
  }
}
