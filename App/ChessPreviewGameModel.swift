import ChessKit
import Foundation

@Observable
@MainActor
final class ChessPreviewGameModel {
  var board = Board()
  var selectedSquare: Square?
  var isBoardFlipped = false
  var lastMove: ChessBoardMoveHighlight?
  var moves: [String] = []

  var chessBoardState: ChessBoardState {
    ChessBoardState(
      board: board,
      selectedSquare: selectedSquare,
      legalTargets: selectedSquare.map { Set(board.legalMoves(forPieceAt: $0)) } ?? [],
      lastMove: lastMove,
      checkedKingSquare: checkedKingSquare,
      isFlipped: isBoardFlipped
    )
  }

  var sideToMoveLabel: String {
    board.position.sideToMove == .white ? "White to move" : "Black to move"
  }

  var statusDetail: String {
    switch board.state {
    case .active:
      sideToMoveLabel
    case .check(let color):
      "\(color.description.capitalized) in check"
    case .checkmate(let color):
      "\(color.description.capitalized) is checkmated"
    case .draw:
      "Draw"
    case .promotion:
      "Choose promotion"
    }
  }

  var canReset: Bool {
    !moves.isEmpty
  }

  var moveCountLabel: String {
    "\(moves.count) move\(moves.count == 1 ? "" : "s")"
  }

  func selectBoardSquare(_ square: Square) {
    if selectedSquare == square {
      selectedSquare = nil
      return
    }

    if let start = selectedSquare {
      let legalTargets = Set(board.legalMoves(forPieceAt: start))
      if legalTargets.contains(square) {
        applyMove(from: start, to: square)
        return
      }
    }

    if canSelectPiece(at: square) {
      selectedSquare = square
    } else {
      selectedSquare = nil
    }
  }

  func reset() {
    board = Board()
    selectedSquare = nil
    lastMove = nil
    moves = []
  }

  func flipBoard() {
    isBoardFlipped.toggle()
  }

  private var checkedKingSquare: Square? {
    switch board.state {
    case .check(let color), .checkmate(let color):
      board.position.pieces.first { $0.kind == .king && $0.color == color }?.square ?? nil
    case .active, .draw, .promotion:
      nil
    }
  }

  private func canSelectPiece(at square: Square) -> Bool {
    guard let piece = board.position.piece(at: square) else {
      return false
    }
    return piece.color == board.position.sideToMove
  }

  private func applyMove(from start: Square, to end: Square) {
    let initialMove = board.move(pieceAt: start, to: end)
    var appliedMove = initialMove

    if case .promotion = board.state,
       let initialMove {
      appliedMove = board.completePromotion(of: initialMove, to: .queen)
    }

    guard let appliedMove else {
      return
    }

    selectedSquare = nil
    lastMove = ChessBoardMoveHighlight(start: start, end: end)
    moves.append("\(start.notation)\(end.notation)")
    ChessSoundPlayer.shared.play(for: appliedMove)
  }
}
