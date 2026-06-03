import ChessKit
import Foundation

@Observable
@MainActor
final class ChessPreviewGameModel {
  struct PendingPromotion {
    var move: Move
    var start: Square
    var end: Square
    var color: Piece.Color
  }

  var board = Board()
  var selectedSquare: Square?
  var isBoardFlipped = false
  var lastMove: ChessBoardMoveHighlight?
  var moves: [String] = []
  var pendingPromotion: PendingPromotion?
  private var startingPosition: Position = .standard
  private var initialSelectedSquare: Square?

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

  var pendingPromotionColor: Piece.Color? {
    pendingPromotion?.color
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
    board = Board(position: startingPosition)
    selectedSquare = initialSelectedSquare
    lastMove = nil
    moves = []
    pendingPromotion = nil
  }

  func flipBoard() {
    isBoardFlipped.toggle()
  }

  func load(position: Position, selectedSquare: Square? = nil) {
    startingPosition = position
    initialSelectedSquare = selectedSquare
    board = Board(position: position)
    self.selectedSquare = selectedSquare
    lastMove = nil
    moves = []
    isBoardFlipped = false
    pendingPromotion = nil
  }

  func choosePromotion(_ option: PromotionPieceOption) {
    guard let pendingPromotion else {
      return
    }

    let appliedMove = board.completePromotion(of: pendingPromotion.move, to: option.kind)

    self.pendingPromotion = nil
    selectedSquare = nil
    lastMove = ChessBoardMoveHighlight(start: pendingPromotion.start, end: pendingPromotion.end)
    moves.append("\(pendingPromotion.start.notation)\(pendingPromotion.end.notation)\(promotionCode(for: option.kind))")
    ChessSoundPlayer.shared.play(for: appliedMove)
  }

  func cancelPromotion() {
    reset()
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
    guard let initialMove = board.move(pieceAt: start, to: end) else {
      return
    }

    if case .promotion = board.state {
      if AppPreferences.autoPromoteToQueen {
        let appliedMove = board.completePromotion(of: initialMove, to: .queen)
        selectedSquare = nil
        lastMove = ChessBoardMoveHighlight(start: start, end: end)
        moves.append("\(start.notation)\(end.notation)q")
        ChessSoundPlayer.shared.play(for: appliedMove)
      } else {
        selectedSquare = nil
        pendingPromotion = PendingPromotion(
          move: initialMove,
          start: start,
          end: end,
          color: board.position.piece(at: end)?.color ?? .white
        )
      }
      return
    }

    selectedSquare = nil
    lastMove = ChessBoardMoveHighlight(start: start, end: end)
    moves.append("\(start.notation)\(end.notation)")
    ChessSoundPlayer.shared.play(for: initialMove)
  }

  private func promotionCode(for kind: Piece.Kind) -> String {
    switch kind {
    case .queen: "q"
    case .rook: "r"
    case .bishop: "b"
    case .knight: "n"
    default: "q"
    }
  }
}
