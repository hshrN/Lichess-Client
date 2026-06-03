import ChessKit
import Foundation

enum PromotionPieceOption: String, CaseIterable, Identifiable {
  case queen
  case rook
  case bishop
  case knight

  var id: String { rawValue }

  var title: String {
    switch self {
    case .queen: "Queen"
    case .rook: "Rook"
    case .bishop: "Bishop"
    case .knight: "Knight"
    }
  }

  var kind: Piece.Kind {
    switch self {
    case .queen: .queen
    case .rook: .rook
    case .bishop: .bishop
    case .knight: .knight
    }
  }
}
