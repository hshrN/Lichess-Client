import ChessKit
import Foundation
import XCTest
@testable import Lichess_Board

final class LichessParsingTests: XCTestCase {
  func testBotPlayerParserReadsRapidRating() throws {
    let data = Data(
      """
      {
        "id": "maia5",
        "username": "maia5",
        "title": "BOT",
        "perfs": {
          "rapid": {
            "rating": 1860
          }
        }
      }
      """.utf8
    )

    let bot = try LichessPlayerParser.parseBotPlayer(from: data)

    XCTAssertEqual(bot.id, "maia5")
    XCTAssertEqual(bot.username, "maia5")
    XCTAssertEqual(bot.title, "BOT")
    XCTAssertEqual(bot.rating, 1860)
    XCTAssertTrue(bot.online)
  }

  func testFollowedPlayerParserReadsNameOnlineAndRapidRating() throws {
    let data = Data(
      """
      {
        "id": "bobby",
        "name": "Bobby",
        "online": true,
        "perfs": {
          "rapid": {
            "rating": 1751
          }
        }
      }
      """.utf8
    )

    let player = try LichessPlayerParser.parseFollowedPlayer(from: data)

    XCTAssertEqual(player.id, "bobby")
    XCTAssertEqual(player.username, "Bobby")
    XCTAssertEqual(player.rapidRating, 1751)
    XCTAssertTrue(player.online)
    XCTAssertEqual(player.url, "https://lichess.org/@/Bobby")
  }

  func testPositionBuilderReplaysUciMovesFromStartPosition() throws {
    let result = LichessBoardPositionBuilder.build(
      initialFEN: "startpos",
      movesString: "e2e4 e7e5 g1f3"
    )

    XCTAssertEqual(result.moves, ["e2e4", "e7e5", "g1f3"])
    XCTAssertEqual(result.lastMove, "g1f3")
    XCTAssertEqual(result.board.position.sideToMove, .black)
    XCTAssertEqual(result.board.position.piece(at: Square("e4"))?.kind, .pawn)
    XCTAssertEqual(result.board.position.piece(at: Square("e5"))?.kind, .pawn)
    XCTAssertEqual(result.board.position.piece(at: Square("f3"))?.kind, .knight)
    XCTAssertNil(result.board.position.piece(at: Square("g1")))
  }

  func testPositionBuilderStartsFromCustomFen() throws {
    let result = LichessBoardPositionBuilder.build(
      initialFEN: "8/8/8/8/8/8/4P3/4K2k w - - 0 1",
      movesString: "e2e4"
    )

    XCTAssertEqual(result.lastMove, "e2e4")
    XCTAssertEqual(result.board.position.piece(at: Square("e4"))?.kind, .pawn)
    XCTAssertNil(result.board.position.piece(at: Square("e2")))
    XCTAssertEqual(result.board.position.sideToMove, .black)
  }

  func testPositionBuilderKeepsCustomFenAcrossLaterGameStateMoveLists() throws {
    let initialFEN = "8/8/8/8/8/8/4P3/4K2k w - - 0 1"
    let first = LichessBoardPositionBuilder.build(
      initialFEN: initialFEN,
      movesString: "e2e4"
    )
    let later = LichessBoardPositionBuilder.build(
      initialFEN: initialFEN,
      movesString: "e2e4 h1h2"
    )

    XCTAssertEqual(first.board.position.piece(at: Square("e4"))?.kind, .pawn)
    XCTAssertEqual(later.moves, ["e2e4", "h1h2"])
    XCTAssertEqual(later.board.position.piece(at: Square("e4"))?.kind, .pawn)
    XCTAssertEqual(later.board.position.piece(at: Square("h2"))?.kind, .king)
    XCTAssertNil(later.board.position.piece(at: Square("h1")))
  }

  func testPositionBuilderCompletesPromotionMoves() throws {
    let result = LichessBoardPositionBuilder.build(
      initialFEN: "4k3/P7/8/8/8/8/8/4K3 w - - 0 1",
      movesString: "a7a8q"
    )

    let promotedPiece = result.board.position.piece(at: Square("a8"))
    XCTAssertEqual(result.lastMove, "a7a8q")
    XCTAssertEqual(promotedPiece?.color, .white)
    XCTAssertEqual(promotedPiece?.kind, .queen)
  }
}
