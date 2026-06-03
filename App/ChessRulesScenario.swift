import ChessKit
import Foundation

struct ChessRulesScenario: Identifiable, Hashable {
  var id: String { title }
  var title: String
  var detail: String
  var initialFEN: String
  var focusSquare: Square?

  var position: Position {
    Position(fen: initialFEN) ?? .standard
  }

  static var defaults: [ChessRulesScenario] {
    [
      ChessRulesScenario(
        title: "Castle Kingside",
        detail: "Select the white king. Kingside and queenside castling should both be legal.",
        initialFEN: "r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1",
        focusSquare: Square("e1")
      ),
      ChessRulesScenario(
        title: "Castle Blocked",
        detail: "The bishop on f1 blocks kingside castling, so e1 to g1 should not appear.",
        initialFEN: "r3k2r/8/8/8/8/8/8/R3KB1R w KQkq - 0 1",
        focusSquare: Square("e1")
      ),
      ChessRulesScenario(
        title: "Castle Through Check",
        detail: "The rook on f8 attacks f1. Castling through that square must be illegal.",
        initialFEN: "5r1k/8/8/8/8/8/8/R3K2R w KQ - 0 1",
        focusSquare: Square("e1")
      ),
      ChessRulesScenario(
        title: "Check Response",
        detail: "White is in check from the rook on e2. Only legal escape moves should highlight.",
        initialFEN: "4k3/8/8/8/8/8/4r3/4K3 w - - 0 1",
        focusSquare: Square("e1")
      ),
      ChessRulesScenario(
        title: "En Passant",
        detail: "White can capture en passant from e5 to d6.",
        initialFEN: "4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 1",
        focusSquare: Square("e5")
      ),
      ChessRulesScenario(
        title: "En Passant Expired",
        detail: "The same pawn structure, but the en passant square is gone. e5 to d6 must be illegal.",
        initialFEN: "4k3/8/8/3pP3/8/8/8/4K3 w - - 0 1",
        focusSquare: Square("e5")
      ),
      ChessRulesScenario(
        title: "Promotion",
        detail: "Advance the pawn from a7. The app currently auto-promotes to a queen.",
        initialFEN: "4k3/P7/8/8/8/8/8/4K3 w - - 0 1",
        focusSquare: Square("a7")
      )
    ]
  }
}
