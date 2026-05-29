import ChessKit
import XCTest
@testable import Lichess_Board

@MainActor
final class LichessClientModelTests: XCTestCase {
  func testConfirmedLocalMoveUpdatesBoardImmediately() {
    let model = LichessClientModel()
    model.hasLoadedGameState = true
    model.activeGame.myColor = "White"
    model.activeGame.moves = []
    model.activeGame.lastMove = ""
    model.board = Board()

    model.applyConfirmedLocalMoveForTesting("e2e4")

    XCTAssertEqual(model.activeGame.lastMove, "e2e4")
    XCTAssertEqual(model.activeGame.moves, ["e2e4"])
    XCTAssertEqual(model.board.position.piece(at: Square("e4"))?.kind, .pawn)
    XCTAssertNil(model.board.position.piece(at: Square("e2")))
    XCTAssertFalse(model.activeGame.isMyTurn)
  }
}
