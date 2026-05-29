import ChessKit
import Foundation

struct LichessBoardPositionResult {
  var board: Board
  var moves: [String]
  var lastMove: String
  var lastAppliedMove: Move?
}

enum LichessBoardPositionBuilder {
  static func build(initialFEN: String?, movesString: String) -> LichessBoardPositionResult {
    let startingPosition: Position
    if let initialFEN, initialFEN != "startpos", let position = Position(fen: initialFEN) {
      startingPosition = position
    } else {
      startingPosition = .standard
    }

    var board = Board(position: startingPosition)
    let moves = movesString.split(separator: " ").map(String.init)
    var lastAppliedMove: Move?

    for move in moves {
      lastAppliedMove = apply(uciMove: move, to: &board) ?? lastAppliedMove
    }

    return LichessBoardPositionResult(
      board: board,
      moves: moves,
      lastMove: moves.last ?? "",
      lastAppliedMove: lastAppliedMove
    )
  }

  static func apply(uciMove: String, to board: inout Board) -> Move? {
    guard uciMove.count >= 4 else { return nil }

    let start = String(uciMove.prefix(2))
    let end = String(uciMove.dropFirst(2).prefix(2))
    let move = board.move(pieceAt: Square(start), to: Square(end))

    guard
      uciMove.count == 5,
      let move,
      case .promotion = board.state
    else {
      return move
    }

    let promotionCode = uciMove.suffix(1)
    let kind: Piece.Kind
    switch promotionCode {
    case "q": kind = .queen
    case "r": kind = .rook
    case "b": kind = .bishop
    case "n": kind = .knight
    default: kind = .queen
    }
    return board.completePromotion(of: move, to: kind)
  }

  static func outgoingMoveUCI(from start: Square, to end: Square, on board: Board) -> String? {
    var board = board
    let base = "\(start.notation)\(end.notation)"

    guard let move = board.move(pieceAt: start, to: end) else {
      return nil
    }

    guard case .promotion = board.state else {
      return base
    }

    _ = board.completePromotion(of: move, to: .queen)
    return "\(base)q"
  }
}
