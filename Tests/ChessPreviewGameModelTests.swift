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

  func testPreviewGameWaitsForPromotionChoiceWhenAutoPromoteDisabled() {
    UserDefaults.standard.set(false, forKey: AppPreferences.autoPromoteToQueenKey)
    defer {
      UserDefaults.standard.removeObject(forKey: AppPreferences.autoPromoteToQueenKey)
    }

    let model = ChessPreviewGameModel()
    model.load(position: Position(fen: "4k3/P7/8/8/8/8/8/4K3 w - - 0 1")!)

    model.selectBoardSquare(Square("a7"))
    model.selectBoardSquare(Square("a8"))

    XCTAssertNotNil(model.pendingPromotion)
    XCTAssertEqual(model.moves, [])

    model.choosePromotion(.knight)

    XCTAssertNil(model.pendingPromotion)
    XCTAssertEqual(model.moves, ["a7a8n"])
    XCTAssertEqual(model.board.position.piece(at: Square("a8"))?.kind, .knight)
  }
}
