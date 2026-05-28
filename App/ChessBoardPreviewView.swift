import ChessKit
import SwiftUI

struct ChessBoardPreviewView: View {
  @State private var isFlipped = false
  @State private var selectedSquare: Square?

  private var board = Board()

  var body: some View {
    VStack(spacing: 14) {
      ChessBoardView(
        state: previewState,
        isInteractionEnabled: true,
        syncingMessage: nil
      ) { square in
        selectedSquare = selectedSquare == square ? nil : square
      }

      Button("Flip Board", systemImage: "arrow.triangle.2.circlepath") {
        isFlipped.toggle()
      }
      .buttonStyle(.bordered)
    }
  }

  private var previewState: ChessBoardState {
    ChessBoardState(
      board: board,
      selectedSquare: selectedSquare,
      legalTargets: selectedSquare.map { Set(board.legalMoves(forPieceAt: $0)) } ?? [],
      lastMove: ChessBoardMoveHighlight(start: .e2, end: .e4),
      checkedKingSquare: nil,
      isFlipped: isFlipped
    )
  }
}
