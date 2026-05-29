import ChessKit
import XCTest
@testable import Lichess_Board

@MainActor
final class ChessPreviewGameModelTests: XCTestCase {
  func testPreviewGameAllowsMultipleLegalMoves() {
    let model = ChessPreviewGameModel()

    model.selectBoardSquare(Square("e2"))
    model.selectBoardSquare(Square("e4"))
    model.selectBoardSquare(Square("e7"))
    model.selectBoardSquare(Square("e5"))

    XCTAssertEqual(model.moves, ["e2e4", "e7e5"])
    XCTAssertEqual(model.board.position.sideToMove, .white)
    XCTAssertEqual(model.board.position.piece(at: Square("e4"))?.kind, .pawn)
    XCTAssertEqual(model.board.position.piece(at: Square("e5"))?.kind, .pawn)
    XCTAssertNil(model.selectedSquare)
  }
}
