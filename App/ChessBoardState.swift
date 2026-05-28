import ChessKit
import Foundation

struct ChessBoardMoveHighlight: Equatable {
  var start: Square
  var end: Square
}

struct ChessBoardState {
  var board: Board
  var selectedSquare: Square?
  var legalTargets: Set<Square>
  var lastMove: ChessBoardMoveHighlight?
  var checkedKingSquare: Square?
  var isFlipped: Bool

  var orderedSquares: [Square] {
    let ranks = isFlipped ? Array(1...8) : Array((1...8).reversed())
    let files = isFlipped ? Array(1...8).reversed() : Array(1...8)

    return ranks.flatMap { rank in
      files.map { file in
        Square("\(Square.File(file).rawValue)\(rank)")
      }
    }
  }

  func piece(at square: Square) -> Piece? {
    board.position.piece(at: square)
  }
}
